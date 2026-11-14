// Security-rule tests (PLAN Section 6): run with `npm run test:rules`.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, getDocs, collection, serverTimestamp, setDoc, addDoc } from 'firebase/firestore';
import { ref, uploadBytes, getBytes } from 'firebase/storage';

let env;

const scan = (uid, id, extra = {}) => ({
  scan_id: id,
  user_id: uid,
  item_name: 'Water bottle',
  contains_plastic: true,
  plastic_type: 'PET',
  resin_code: 1,
  confidence: 0.93,
  state: 'high',
  model_version: 'mobilenetv3-v1',
  llm_used: false,
  user_verified: false,
  in_collection: false,
  image_path: null,
  created_at: '2026-11-14T10:00:00Z',
  updated_at: '2026-11-14T10:00:00Z',
  ...extra,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-plasticlens',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
    storage: { rules: readFileSync('storage.rules', 'utf8') },
  });
});

after(async () => env?.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
});

describe('users and scans', () => {
  test('owner can create profile and scans', async () => {
    const db = env.authenticatedContext('alice').firestore();
    await assertSucceeds(setDoc(doc(db, 'users/alice'), { display_name: 'Alice', email: 'a@x.com', created_at: serverTimestamp(), photo_backup: false }));
    await assertSucceeds(setDoc(doc(db, 'users/alice/scans/s1'), scan('alice', 's1')));
    await assertSucceeds(getDoc(doc(db, 'users/alice/scans/s1')));
    await assertSucceeds(deleteDoc(doc(db, 'users/alice/scans/s1')));
  });

  test("a user cannot read or write another user's data", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users/alice'), { display_name: 'Alice' });
      await setDoc(doc(ctx.firestore(), 'users/alice/scans/s1'), scan('alice', 's1'));
      await setDoc(doc(ctx.firestore(), 'user_progress/alice'), { points: 10 });
    });
    const bob = env.authenticatedContext('bob').firestore();
    await assertFails(getDoc(doc(bob, 'users/alice')));
    await assertFails(getDoc(doc(bob, 'users/alice/scans/s1')));
    await assertFails(getDocs(collection(bob, 'users/alice/scans')));
    await assertFails(getDoc(doc(bob, 'user_progress/alice')));
    await assertFails(setDoc(doc(bob, 'users/alice/scans/s2'), scan('alice', 's2')));
    await assertFails(setDoc(doc(bob, 'users/alice/scans/s3'), scan('bob', 's3')));
    await assertFails(deleteDoc(doc(bob, 'users/alice/scans/s1')));
  });

  test('signed-out users cannot access private data', async () => {
    const anon = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(anon, 'users/alice')));
    await assertFails(setDoc(doc(anon, 'users/alice/scans/s1'), scan('alice', 's1')));
  });

  test('scan fields are validated', async () => {
    const db = env.authenticatedContext('alice').firestore();
    const bad = [
      scan('alice', 's1', { plastic_type: 'NYLON' }),
      scan('alice', 's1', { confidence: 1.5 }),
      scan('alice', 's1', { state: 'certain' }),
      scan('alice', 's1', { item_name: '' }),
      scan('alice', 's1', { item_name: 'x'.repeat(81) }),
      scan('alice', 's1', { resin_code: 9 }),
      scan('alice', 's1', { scan_id: 'other' }),
      scan('alice', 's1', { image_path: 'scans/bob/s1.jpg' }),
      scan('alice', 's1', { is_admin: true }),
    ];
    for (const data of bad) await assertFails(setDoc(doc(db, 'users/alice/scans/s1'), data));
    await assertSucceeds(setDoc(doc(db, 'users/alice/scans/s1'), scan('alice', 's1', { image_path: 'scans/alice/s1.jpg', second_opinion: 'note' })));
  });

  test('progress is owner-only and validated', async () => {
    const db = env.authenticatedContext('alice').firestore();
    await assertSucceeds(setDoc(doc(db, 'user_progress/alice'), { points: 40, current_streak: 2, best_streak: 3, badges: ['first_scan'], updated_at: serverTimestamp() }));
    await assertFails(setDoc(doc(db, 'user_progress/alice'), { points: -5, current_streak: 0, best_streak: 0, badges: [] }));
    await assertFails(setDoc(doc(db, 'user_progress/alice'), { points: 1, current_streak: 0, best_streak: 0, badges: [], admin: true }));
  });
});

describe('shared content and feedback', () => {
  test('anyone reads materials; only admins write', async () => {
    const anon = env.unauthenticatedContext().firestore();
    const user = env.authenticatedContext('alice').firestore();
    const admin = env.authenticatedContext('root', { admin: true }).firestore();
    await assertSucceeds(getDoc(doc(anon, 'plastic_types/PET')));
    await assertFails(setDoc(doc(user, 'plastic_types/PET'), { material: 'PET' }));
    await assertSucceeds(setDoc(doc(admin, 'plastic_types/PET'), { material: 'PET' }));
    await assertFails(setDoc(doc(user, 'achievements/first_scan'), { title: 'x' }));
  });

  test('users submit their own feedback; only admins read it', async () => {
    const alice = env.authenticatedContext('alice').firestore();
    const admin = env.authenticatedContext('root', { admin: true }).firestore();
    const fb = { user_id: 'alice', scan_id: 's1', predicted: 'PET', corrected: 'PP', confidence: 0.6, model_version: 'v1', created_at: serverTimestamp(), status: 'new' };
    await assertSucceeds(addDoc(collection(alice, 'feedback'), fb));
    await assertFails(addDoc(collection(alice, 'feedback'), { ...fb, user_id: 'bob' }));
    await assertFails(addDoc(collection(alice, 'feedback'), { ...fb, corrected: 'banana' }));
    await assertFails(getDocs(collection(alice, 'feedback')));
    await assertSucceeds(getDocs(collection(admin, 'feedback')));
  });
});

describe('storage', () => {
  const jpg = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);

  test('owner can upload and read own photos; others cannot', async () => {
    const alice = env.authenticatedContext('alice').storage();
    const bob = env.authenticatedContext('bob').storage();
    await assertSucceeds(uploadBytes(ref(alice, 'scans/alice/s1.jpg'), jpg, { contentType: 'image/jpeg' }));
    await assertSucceeds(getBytes(ref(alice, 'scans/alice/s1.jpg')));
    await assertFails(getBytes(ref(bob, 'scans/alice/s1.jpg')));
    await assertFails(uploadBytes(ref(bob, 'scans/alice/s2.jpg'), jpg, { contentType: 'image/jpeg' }));
  });

  test('only images under 5 MB are accepted', async () => {
    const alice = env.authenticatedContext('alice').storage();
    await assertFails(uploadBytes(ref(alice, 'scans/alice/s1.txt'), jpg, { contentType: 'text/plain' }));
    await assertFails(uploadBytes(ref(alice, 'scans/alice/big.jpg'), new Uint8Array(5 * 1024 * 1024 + 1), { contentType: 'image/jpeg' }));
  });
});

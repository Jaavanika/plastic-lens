import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plastic_lens/models/scan_record.dart';
import 'package:plastic_lens/services/auth_service.dart';
import 'package:plastic_lens/services/cloud_sync.dart';
import 'package:plastic_lens/services/local_db.dart';
import 'package:plastic_lens/services/scan_store.dart';

import 'helpers.dart';

/// Section 8 "done when": scans made offline appear in Firestore after
/// reconnecting, with no duplicates.
void main() {
  late FakeFirebaseFirestore fs;
  late ScanStore store;
  late FakeAuth auth;
  late StreamController<bool> online;
  late CloudSync sync;

  Future<int> remoteCount() async => (await fs.collection('users').doc('u1').collection('scans').get()).size;

  setUp(() async {
    fs = FakeFirebaseFirestore();
    store = ScanStore(InMemoryScanStorage([]));
    await store.load();
    auth = FakeAuth(const AppUser(uid: 'u1', email: 'a@b.c'));
    online = StreamController<bool>();
    sync = CloudSync(store: store, auth: auth, localDb: InMemorySyncState(), firestore: fs, storage: MockFirebaseStorage(), onlineChanges: online.stream);
    await sync.start();
    await pumpEventQueue();
  });

  tearDown(() => online.close());

  test('offline scans sync once when back online, without duplicates', () async {
    online.add(false);
    await pumpEventQueue();
    await store.save(scan('s1', type: 'PET'));
    await store.save(scan('s2', type: 'PP'));
    await pumpEventQueue();
    expect(await remoteCount(), 0);
    expect(store.scans.every((s) => s.syncStatus == SyncStatus.pending), isTrue);

    online.add(true);
    await pumpEventQueue(times: 50);
    expect(await remoteCount(), 2);
    expect(store.scans.every((s) => s.syncStatus == SyncStatus.synced), isTrue);

    // Syncing again (or editing) never creates extra documents.
    await sync.syncNow();
    final s1 = store.byId('s1')!..itemName = 'Renamed bottle';
    await store.save(s1);
    await pumpEventQueue(times: 50);
    expect(await remoteCount(), 2);
    final doc = await fs.collection('users').doc('u1').collection('scans').doc('s1').get();
    expect(doc['item_name'], 'Renamed bottle');
  });

  test('deletes made offline are applied after reconnecting', () async {
    await store.save(scan('s1', type: 'PET'));
    await pumpEventQueue(times: 50);
    expect(await remoteCount(), 1);

    online.add(false);
    await pumpEventQueue();
    await store.delete('s1');
    await pumpEventQueue();
    expect(await remoteCount(), 1);

    online.add(true);
    await pumpEventQueue(times: 50);
    expect(await remoteCount(), 0);
  });

  test('signing in on a new phone pulls remote scans', () async {
    await fs.collection('users').doc('u2').collection('scans').doc('r1').set(scan('r1', type: 'HDPE').toFirestore('u2'));
    auth.user = const AppUser(uid: 'u2');
    await pumpEventQueue(times: 50);
    expect(store.byId('r1')?.plasticType, 'HDPE');
    expect(store.byId('r1')?.syncStatus, SyncStatus.synced);
  });

  test('account deletion removes all cloud data', () async {
    await store.save(scan('s1', type: 'PET'));
    await pumpEventQueue(times: 50);
    await fs.collection('users').doc('u1').set({'email': 'a@b.c'});
    await sync.deleteCloudData('u1');
    expect(await remoteCount(), 0);
    expect((await fs.collection('users').doc('u1').get()).exists, isFalse);
  });
}

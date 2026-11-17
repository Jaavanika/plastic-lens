import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AppUser {
  const AppUser({required this.uid, this.email, this.displayName, this.photoUrl});
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  String get label => (displayName?.isNotEmpty ?? false) ? displayName! : (email ?? 'PlasticLens user');
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class AuthService extends ChangeNotifier {
  /// False when Firebase is not configured; the app then runs local-only.
  bool get available;
  AppUser? get user;
  bool get signedIn => user != null;

  /// Firebase ID token for calls to the FastAPI backend.
  Future<String?> idToken();

  Future<void> signInWithEmail(String email, String password);
  Future<void> register(String name, String email, String password);
  Future<void> signInWithGoogle();
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();

  /// [deleteCloudData] removes Firestore/Storage data before the account.
  Future<void> deleteAccount(Future<void> Function(String uid) deleteCloudData);
}

/// Used when Firebase is not configured: everything stays on the device.
class LocalOnlyAuth extends AuthService {
  @override
  bool get available => false;
  @override
  AppUser? get user => null;
  @override
  Future<String?> idToken() async => null;

  Never _unavailable() => throw AuthException('Accounts are not set up in this build of PlasticLens.');

  @override
  Future<void> signInWithEmail(String email, String password) async => _unavailable();
  @override
  Future<void> register(String name, String email, String password) async => _unavailable();
  @override
  Future<void> signInWithGoogle() async => _unavailable();
  @override
  Future<void> sendPasswordReset(String email) async => _unavailable();
  @override
  Future<void> signOut() async {}
  @override
  Future<void> deleteAccount(Future<void> Function(String uid) deleteCloudData) async {}
}

class FirebaseAuthService extends AuthService {
  FirebaseAuthService({fb.FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? fb.FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance {
    _sub = _auth.authStateChanges().listen((u) {
      _user = u == null ? null : AppUser(uid: u.uid, email: u.email, displayName: u.displayName, photoUrl: u.photoURL);
      notifyListeners();
    });
    final u = _auth.currentUser;
    if (u != null) _user = AppUser(uid: u.uid, email: u.email, displayName: u.displayName, photoUrl: u.photoURL);
  }

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db;
  late final StreamSubscription<fb.User?> _sub;
  AppUser? _user;
  bool _googleReady = false;

  @override
  bool get available => true;
  @override
  AppUser? get user => _user;

  @override
  Future<String?> idToken() async => _auth.currentUser?.getIdToken();

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw AuthException('Sign-in cancelled.');
      throw AuthException('Google sign-in failed (${e.code.name}).');
    }
  }

  String _message(fb.FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'That email address does not look right.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Email or password is incorrect.',
        'email-already-in-use' => 'An account already exists for that email.',
        'weak-password' => 'Please choose a password with at least 6 characters.',
        'network-request-failed' => 'No internet connection. Try again when you are online.',
        'too-many-requests' => 'Too many attempts. Please wait a moment and try again.',
        'requires-recent-login' => 'For your security, please sign out, sign in again, then retry.',
        _ => e.message ?? 'Authentication failed (${e.code}).',
      };

  /// Creates `users/{uid}` on first sign-in (identification spec §10).
  Future<void> _ensureUserDoc(fb.User u) async {
    final ref = _db.collection('users').doc(u.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'display_name': u.displayName ?? '',
        'email': u.email,
        'created_at': FieldValue.serverTimestamp(),
        'photo_backup': false,
      });
    }
  }

  @override
  Future<void> signInWithEmail(String email, String password) => _guard(() async {
        final cred = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
        await _ensureUserDoc(cred.user!);
      });

  @override
  Future<void> register(String name, String email, String password) => _guard(() async {
        final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
        await cred.user!.updateDisplayName(name.trim());
        await cred.user!.reload();
        // authStateChanges fired before the name was set; refresh the user.
        final u = _auth.currentUser!;
        _user = AppUser(uid: u.uid, email: u.email, displayName: u.displayName, photoUrl: u.photoURL);
        notifyListeners();
        await _ensureUserDoc(u);
      });

  @override
  Future<void> signInWithGoogle() => _guard(() async {
        if (!_googleReady) {
          await GoogleSignIn.instance.initialize();
          _googleReady = true;
        }
        final account = await GoogleSignIn.instance.authenticate();
        final token = account.authentication.idToken;
        final cred = await _auth.signInWithCredential(fb.GoogleAuthProvider.credential(idToken: token));
        await _ensureUserDoc(cred.user!);
      });

  @override
  Future<void> sendPasswordReset(String email) => _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    if (_googleReady) await GoogleSignIn.instance.signOut();
  }

  @override
  Future<void> deleteAccount(Future<void> Function(String uid) deleteCloudData) => _guard(() async {
        final u = _auth.currentUser;
        if (u == null) return;
        // Firebase only deletes accounts with a recent sign-in (~5 min).
        // Check first, so cloud data is never deleted while the account stays.
        final lastSignIn = u.metadata.lastSignInTime;
        if (lastSignIn == null || DateTime.now().difference(lastSignIn) > const Duration(minutes: 4)) {
          throw AuthException('For your security, sign out and sign in again, then delete your account within a few minutes.');
        }
        await deleteCloudData(u.uid);
        await u.delete();
        if (_googleReady) await GoogleSignIn.instance.signOut();
      });

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

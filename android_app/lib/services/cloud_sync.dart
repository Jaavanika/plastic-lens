import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/plastic_type.dart';
import '../models/scan_record.dart';
import 'auth_service.dart';
import 'feedback_service.dart';
import 'local_db.dart';
import 'progress_service.dart';
import 'scan_store.dart';

/// Keeps local scans and Firestore `users/{uid}/scans` in step.
///
/// Scans are written locally first (sync_status = pending) and pushed when
/// the user is signed in and online. Scan ids are UUIDs used as document
/// ids, so retries overwrite instead of duplicating.
class CloudSync extends ChangeNotifier {
  CloudSync({
    required this.store,
    required this.auth,
    required this.localDb,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    Stream<bool>? onlineChanges,
  })  : _fs = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _onlineChanges = onlineChanges ??
            Connectivity().onConnectivityChanged.map((r) => r.isNotEmpty && !r.contains(ConnectivityResult.none));

  final ScanStore store;
  final AuthService auth;
  final SyncStateStore localDb;
  final FirebaseFirestore _fs;
  final FirebaseStorage _storage;
  final Stream<bool> _onlineChanges;

  StreamSubscription<bool>? _onlineSub;
  bool _online = true;
  bool _busy = false;
  bool backupPhotos = false;
  DateTime? lastSync;
  String? lastError;
  String? _lastUid;

  bool get busy => _busy;
  int get pendingCount => store.scans.where((s) => s.syncStatus == SyncStatus.pending).length;

  static const _pushTimeout = Duration(seconds: 20);

  Future<void> start() async {
    backupPhotos = await localDb.getSetting('photo_backup') == 'true';
    store.onChanged = (scan) => unawaited(_pushOne(scan));
    store.onDeleted = (id) => unawaited(_deleteRemote(id));
    auth.addListener(_onAuthChanged);
    _onlineSub = _onlineChanges.listen((online) {
      final cameOnline = online && !_online;
      _online = online;
      if (cameOnline) unawaited(syncNow());
    });
    _onAuthChanged();
  }

  void _onAuthChanged() {
    final uid = auth.user?.uid;
    if (uid != null && uid != _lastUid) unawaited(syncNow());
    _lastUid = uid;
    notifyListeners();
  }

  Future<void> setBackupPhotos(bool value) async {
    backupPhotos = value;
    await localDb.setSetting('photo_backup', '$value');
    notifyListeners();
    if (value) unawaited(syncNow());
  }

  CollectionReference<Map<String, dynamic>> _scans(String uid) =>
      _fs.collection('users').doc(uid).collection('scans');

  /// Pull remote scans, then push everything pending (and pending deletes).
  Future<void> syncNow() async {
    final uid = auth.user?.uid;
    if (uid == null || _busy) return;
    _busy = true;
    lastError = null;
    notifyListeners();
    try {
      await _pull(uid);
      for (final id in await localDb.tombstones()) {
        await _deleteRemote(id);
      }
      for (final s in store.scans.where((s) => s.syncStatus == SyncStatus.pending).toList()) {
        await _pushOne(s);
      }
      lastSync = DateTime.now();
    } catch (e) {
      lastError = 'Sync failed: $e';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _pull(String uid) async {
    final snap = await _scans(uid).get().timeout(_pushTimeout);
    for (final doc in snap.docs) {
      final remote = ScanRecord.fromFirestore(doc.data());
      final local = store.byId(remote.id);
      final remoteNewer = local != null &&
          local.syncStatus == SyncStatus.synced &&
          (remote.updatedAt ?? remote.createdAt).isAfter(local.updatedAt ?? local.createdAt);
      if (local == null) {
        await store.save(remote, fromSync: true);
      } else if (remoteNewer) {
        local
          ..itemName = remote.itemName
          ..containsPlastic = remote.containsPlastic
          ..plasticType = remote.plasticType
          ..resinCode = remote.resinCode
          ..userVerified = remote.userVerified
          ..inCollection = remote.inCollection
          ..remoteImagePath = remote.remoteImagePath
          ..updatedAt = remote.updatedAt;
        await store.save(local, fromSync: true);
      }
    }
  }

  Future<void> _pushOne(ScanRecord scan) async {
    final uid = auth.user?.uid;
    if (uid == null || !_online) return;
    try {
      if (backupPhotos && scan.remoteImagePath == null && scan.imagePath.isNotEmpty && File(scan.imagePath).existsSync()) {
        final path = 'scans/$uid/${scan.id}.jpg';
        await _storage.ref(path).putFile(File(scan.imagePath), SettableMetadata(contentType: 'image/jpeg')).timeout(const Duration(seconds: 60));
        scan.remoteImagePath = path;
      }
      await _scans(uid).doc(scan.id).set(scan.toFirestore(uid)).timeout(_pushTimeout);
      await store.markSynced(scan);
    } catch (e) {
      lastError = 'Could not sync “${scan.itemName}”: $e';
      notifyListeners();
    }
  }

  Future<void> _deleteRemote(String id) async {
    final uid = auth.user?.uid;
    if (uid == null) return;
    if (!_online) {
      await localDb.addTombstone(id);
      return;
    }
    try {
      await _scans(uid).doc(id).delete().timeout(_pushTimeout);
      try {
        await _storage.ref('scans/$uid/$id.jpg').delete();
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') rethrow;
      }
      await localDb.removeTombstone(id);
    } catch (_) {
      await localDb.addTombstone(id);
    }
  }

  /// Account deletion: every Firestore document and Storage image of [uid].
  ///
  /// Photos go first, so a failure cannot leave scans deleted but images
  /// behind. Storage is only contacted when photos were ever backed up:
  /// it is optional (not enabled on the free Spark plan) and calls fail
  /// when no bucket exists.
  Future<void> deleteCloudData(String uid) async {
    final scans = await _scans(uid).get();
    final hasPhotos = backupPhotos || scans.docs.any((d) => d.data()['image_path'] != null);
    if (hasPhotos) {
      final images = await _storage.ref('scans/$uid').listAll();
      for (final item in images.items) {
        await item.delete();
      }
    }
    WriteBatch batch = _fs.batch();
    var n = 0;
    for (final d in scans.docs) {
      batch.delete(d.reference);
      if (++n % 400 == 0) {
        await batch.commit();
        batch = _fs.batch();
      }
    }
    batch.delete(_fs.collection('user_progress').doc(uid));
    batch.delete(_fs.collection('users').doc(uid));
    await batch.commit();
  }

  String? _lastProgress;

  /// Mirror points / streak / badges to `user_progress/{uid}`.
  Future<void> pushProgress(Progress p) async {
    final uid = auth.user?.uid;
    if (uid == null || !_online) return;
    final data = p.toFirestore();
    final key = '$uid:$data';
    if (key == _lastProgress) return;
    try {
      await _fs.collection('user_progress').doc(uid).set({...data, 'updated_at': FieldValue.serverTimestamp()}).timeout(_pushTimeout);
      _lastProgress = key;
    } catch (_) {
      // Retried on the next change; progress is always recomputable locally.
    }
  }

  /// Newer material records published by admins, if any.
  Future<List<PlasticType>> fetchMaterials() async {
    final snap = await _fs.collection('plastic_types').get().timeout(_pushTimeout);
    return snap.docs.map((d) => PlasticType.fromJson(d.data())).toList();
  }

  @override
  void dispose() {
    _onlineSub?.cancel();
    auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}

/// Stores "Correct the material" submissions in Firestore `feedback`.
class FirestoreFeedbackService implements FeedbackService {
  FirestoreFeedbackService(this.auth, [FirebaseFirestore? fs]) : _fs = fs ?? FirebaseFirestore.instance;
  final AuthService auth;
  final FirebaseFirestore _fs;

  @override
  Future<void> submitCorrection({required ScanRecord scan, required String? predicted, required String corrected}) async {
    final uid = auth.user?.uid;
    if (uid == null) return;
    try {
      await _fs.collection('feedback').add({
        'user_id': uid,
        'scan_id': scan.id,
        'predicted': predicted,
        'corrected': corrected,
        'confidence': scan.confidence,
        'model_version': scan.modelVersion,
        'created_at': FieldValue.serverTimestamp(),
        'status': 'new',
      }).timeout(const Duration(seconds: 20));
    } catch (_) {
      // Feedback is best-effort; Firestore keeps the write queued offline.
    }
  }
}

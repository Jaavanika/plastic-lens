import 'dart:io';

import 'package:flutter/services.dart';
import 'package:plastic_lens/app.dart';
import 'package:plastic_lens/models/classification.dart';
import 'package:plastic_lens/models/scan_record.dart';
import 'package:plastic_lens/services/auth_service.dart';
import 'package:plastic_lens/services/classifier_service.dart';
import 'package:plastic_lens/services/learning_service.dart';
import 'package:plastic_lens/services/material_repository.dart';
import 'package:plastic_lens/services/progress_service.dart';
import 'package:plastic_lens/services/scan_store.dart';
import 'package:plastic_lens/utils/dummy_data.dart';

// Synchronous reads: async file I/O never completes inside testWidgets' fake zone.
MaterialRepository loadMaterials() =>
    MaterialRepository.fromJsonString(File('assets/data/plastic_types.json').readAsStringSync());

/// Signed-in user without Firebase, for sync and UI tests.
class FakeAuth extends AuthService {
  FakeAuth([this._user]);
  AppUser? _user;
  @override
  bool get available => true;
  @override
  AppUser? get user => _user;
  set user(AppUser? u) {
    _user = u;
    notifyListeners();
  }

  @override
  Future<String?> idToken() async => _user == null ? null : 'token';
  @override
  Future<void> signInWithEmail(String email, String password) async => user = AppUser(uid: 'u1', email: email);
  @override
  Future<void> register(String name, String email, String password) async => user = AppUser(uid: 'u1', email: email, displayName: name);
  @override
  Future<void> signInWithGoogle() async => user = const AppUser(uid: 'u1');
  @override
  Future<void> sendPasswordReset(String email) async {}
  @override
  Future<void> signOut() async => user = null;
  @override
  Future<void> deleteAccount(Future<void> Function(String uid) deleteCloudData) async {
    await deleteCloudData(_user!.uid);
    user = null;
  }
}

Future<AppServices> buildServices({List<ScanRecord>? scans, AuthService? auth}) async {
  final store = ScanStore(InMemoryScanStorage(scans ?? dummyScans()));
  await store.load();
  final (lessons, quiz) = await LearningService.loadContent(_FileBundle());
  final done = <String, DateTime>{};
  final learning = LearningService(lessons: lessons, quiz: quiz, load: () async => Map.of(done), save: (id, at) async => done[id] = at);
  await learning.init();
  final progress = ProgressService(await ProgressService.loadCalculator(_FileBundle()));
  void recompute() => progress.update(store.scans, learning.done);
  recompute();
  store.addListener(recompute);
  learning.addListener(recompute);
  return AppServices(
    materials: loadMaterials(),
    store: store,
    classifier: FakeClassifier(delay: Duration.zero),
    auth: auth ?? LocalOnlyAuth(),
    learning: learning,
    progress: progress,
    wipeLocal: () async => store.clearLocal(),
  );
}

ScanRecord scan(String id, {String? type, ResultState state = ResultState.high, DateTime? at, bool verified = false, bool saved = false}) =>
    ScanRecord(
      id: id,
      itemName: 'Item $id',
      containsPlastic: state == ResultState.nonPlastic ? false : true,
      plasticType: state == ResultState.nonPlastic ? null : type,
      resinCode: null,
      confidence: 0.9,
      state: state,
      modelVersion: 'test',
      imagePath: '',
      createdAt: at ?? DateTime(2026, 11, 14, 10),
      userVerified: verified,
      inCollection: saved,
    );

/// Reads assets straight from disk, synchronously (see note at the top).
class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(File(key).readAsBytesSync());
  @override
  Future<String> loadString(String key, {bool cache = true}) async => File(key).readAsStringSync();
}

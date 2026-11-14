import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'services/auth_service.dart';
import 'services/cloud_sync.dart';
import 'services/enrich_service.dart';
import 'services/learning_service.dart';
import 'services/local_db.dart';
import 'services/material_repository.dart';
import 'services/onnx_classifier.dart';
import 'services/progress_service.dart';
import 'services/scan_store.dart';

/// Firebase is optional: without android/app/google-services.json the app
/// runs fully offline with local storage only. The native side reports
/// whether the config exists, because initializeApp() hangs without it.
Future<bool> _initFirebase() async {
  try {
    final configured = await const MethodChannel('plasticlens/config').invokeMethod<bool>('hasFirebaseConfig');
    if (configured != true) {
      debugPrint('No google-services.json: running local-only');
      return false;
    }
    await Firebase.initializeApp();
    return true;
  } catch (e) {
    debugPrint('Firebase not configured, running local-only: $e');
    return false;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebase = await _initFirebase();

  final db = await LocalDb.open();
  final materials = await MaterialRepository.load();
  final store = ScanStore(SqliteScanStorage(db));
  await store.load();

  final classifier = OnnxClassifier();
  unawaited(classifier.warmUp().catchError((Object e) => debugPrint('$e')));

  final auth = firebase ? FirebaseAuthService() : LocalOnlyAuth();
  final sync = firebase ? CloudSync(store: store, auth: auth, localDb: db) : null;
  await sync?.start();
  if (sync != null) {
    unawaited(sync.fetchMaterials().then(materials.merge).catchError((Object _) {}));
  }

  final (lessons, quiz) = await LearningService.loadContent();
  final learning = LearningService(lessons: lessons, quiz: quiz, load: db.lessonsDone, save: db.markLessonDone);
  await learning.init();

  final progress = ProgressService(await ProgressService.loadCalculator());
  void recompute() {
    progress.update(store.scans, learning.done);
    sync?.pushProgress(progress.progress);
  }
  recompute();
  store.addListener(recompute);
  learning.addListener(recompute);

  Future<void> wipeLocal() async {
    await db.wipe();
    await store.clearLocal();
    await learning.init();
    try {
      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/scans');
      if (dir.existsSync()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  runApp(PlasticLensApp(
    services: AppServices(
      materials: materials,
      store: store,
      classifier: classifier,
      auth: auth,
      learning: learning,
      progress: progress,
      sync: sync,
      feedback: firebase ? FirestoreFeedbackService(auth) : null,
      enrich: firebase ? HttpEnrichService(HttpEnrichService.configuredUrl) : null,
      wipeLocal: wipeLocal,
      guestMode: await db.getSetting('guest_mode') == 'true',
      setGuestMode: (v) => db.setSetting('guest_mode', '$v'),
    ),
  ));
}

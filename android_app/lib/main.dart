import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'services/classifier_service.dart';
import 'services/material_repository.dart';
import 'services/scan_store.dart';
import 'utils/dummy_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final materials = await MaterialRepository.load();
  final store = ScanStore(InMemoryScanStorage(dummyScans()));
  await store.load();
  runApp(PlasticLensApp(materials: materials, store: store, classifier: FakeClassifier()));
}

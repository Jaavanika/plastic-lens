import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'services/classifier_service.dart';
import 'services/feedback_service.dart';
import 'services/material_repository.dart';
import 'services/scan_store.dart';
import 'theme.dart';

class PlasticLensApp extends StatelessWidget {
  const PlasticLensApp({
    super.key,
    required this.materials,
    required this.store,
    required this.classifier,
    this.feedback,
  });

  final MaterialRepository materials;
  final ScanStore store;
  final ClassifierService classifier;
  final FeedbackService? feedback;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: materials),
        Provider.value(value: classifier),
        Provider<FeedbackService>.value(value: feedback ?? NoopFeedbackService()),
        ChangeNotifierProvider.value(value: store),
      ],
      child: MaterialApp(
        title: 'PlasticLens',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const HomeShell(),
      ),
    );
  }
}

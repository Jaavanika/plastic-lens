import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'screens/profile_screen.dart';
import 'screens/sign_in_screen.dart';
import 'services/auth_service.dart';
import 'services/classifier_service.dart';
import 'services/cloud_sync.dart';
import 'services/enrich_service.dart';
import 'services/feedback_service.dart';
import 'services/learning_service.dart';
import 'services/material_repository.dart';
import 'services/progress_service.dart';
import 'services/scan_store.dart';
import 'theme.dart';

/// Everything the widget tree needs; built in main.dart (or by tests).
class AppServices {
  AppServices({
    required this.materials,
    required this.store,
    required this.classifier,
    required this.auth,
    required this.learning,
    required this.progress,
    required this.wipeLocal,
    this.sync,
    FeedbackService? feedback,
    EnrichService? enrich,
    this.guestMode = false,
    this.setGuestMode,
  })  : feedback = feedback ?? NoopFeedbackService(),
        enrich = enrich ?? const DisabledEnrichService();

  final MaterialRepository materials;
  final ScanStore store;
  final ClassifierService classifier;
  final AuthService auth;
  final LearningService learning;
  final ProgressService progress;
  final CloudSync? sync;
  final FeedbackService feedback;
  final EnrichService enrich;
  final LocalWipe wipeLocal;
  final bool guestMode;
  final Future<void> Function(bool)? setGuestMode;
}

class PlasticLensApp extends StatelessWidget {
  const PlasticLensApp({super.key, required this.services});
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final s = services;
    return MultiProvider(
      providers: [
        Provider.value(value: s.materials),
        Provider.value(value: s.classifier),
        Provider.value(value: s.feedback),
        Provider.value(value: s.enrich),
        Provider<LocalWipe>.value(value: s.wipeLocal),
        ChangeNotifierProvider.value(value: s.store),
        ChangeNotifierProvider<AuthService>.value(value: s.auth),
        ChangeNotifierProvider.value(value: s.learning),
        ChangeNotifierProvider.value(value: s.progress),
        ChangeNotifierProvider<CloudSync?>.value(value: s.sync),
      ],
      child: MaterialApp(
        title: 'PlasticLens',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: _AuthGate(initialGuest: s.guestMode, setGuestMode: s.setGuestMode),
      ),
    );
  }
}

/// First launch with accounts available: offer sign-in or guest mode.
class _AuthGate extends StatefulWidget {
  const _AuthGate({required this.initialGuest, this.setGuestMode});
  final bool initialGuest;
  final Future<void> Function(bool)? setGuestMode;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late bool _guest = widget.initialGuest;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.available || auth.signedIn || _guest) return const HomeShell();
    return SignInScreen(onContinueAsGuest: () {
      widget.setGuestMode?.call(true);
      setState(() => _guest = true);
    });
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../services/progress_service.dart';
import '../widgets/progress_widgets.dart';
import 'collection_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'scanner_screen.dart';

/// Bottom navigation: Home, Scan, Collection, History, Profile.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  ProgressService? _progress;

  void _go(int i) => setState(() => _index = i);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = context.read<ProgressService>();
    if (p != _progress) {
      _progress?.removeListener(_celebrate);
      _progress = p..addListener(_celebrate);
    }
  }

  @override
  void dispose() {
    _progress?.removeListener(_celebrate);
    super.dispose();
  }

  void _celebrate() {
    final p = _progress!;
    for (final id in p.newlyUnlocked) {
      final a = p.achievements.firstWhere((a) => a.id == id);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          Icon(achievementIcon(a.icon), color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(child: Text('Badge unlocked: ${a.title}')),
        ]),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AchievementsScreen())),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pages are rebuilt on switch (no IndexedStack) so the camera is only
    // open while the Scan tab is visible.
    final page = switch (_index) {
      0 => HomeScreen(onOpenScanner: () => _go(1), onOpenHistory: () => _go(3), onOpenCollection: () => _go(2)),
      1 => const ScannerScreen(),
      2 => CollectionScreen(
          header: ProgressSummary(
            onTapBadges: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AchievementsScreen())),
          ),
        ),
      3 => const HistoryScreen(),
      _ => const ProfileScreen(),
    };
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: Scaffold(
        body: page,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _go,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.photo_camera_outlined), selectedIcon: Icon(Icons.photo_camera), label: 'Scan'),
            NavigationDestination(icon: Icon(Icons.collections_bookmark_outlined), selectedIcon: Icon(Icons.collections_bookmark), label: 'Collection'),
            NavigationDestination(icon: Icon(Icons.history), label: 'History'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

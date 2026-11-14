import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../services/progress_service.dart';

const _icons = <String, IconData>{
  'photo_camera': Icons.photo_camera,
  'visibility': Icons.visibility,
  'workspace_premium': Icons.workspace_premium,
  'category': Icons.category,
  'fact_check': Icons.fact_check,
  'collections_bookmark': Icons.collections_bookmark,
  'school': Icons.school,
  'quiz': Icons.quiz,
  'local_fire_department': Icons.local_fire_department,
  'whatshot': Icons.whatshot,
};

IconData achievementIcon(String name) => _icons[name] ?? Icons.emoji_events;

/// Points · streak · badges summary row.
class ProgressSummary extends StatelessWidget {
  const ProgressSummary({super.key, this.onTapBadges});
  final VoidCallback? onTapBadges;

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<ProgressService>();
    final p = svc.progress;
    final t = Theme.of(context).textTheme;
    Widget stat(IconData icon, String value, String label, Color color) => Expanded(
          child: Column(children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(value, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text(label, style: t.bodySmall),
          ]),
        );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTapBadges,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(children: [
            stat(Icons.stars_rounded, '${p.points}', 'points', Colors.amber.shade700),
            stat(Icons.local_fire_department, '${p.currentStreak}', 'day streak', Colors.deepOrange),
            stat(Icons.emoji_events, '${p.unlocked.length}/${svc.achievements.length}', 'badges', Theme.of(context).colorScheme.primary),
          ]),
        ),
      ),
    );
  }
}

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<ProgressService>();
    final p = svc.progress;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Badges')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        const ProgressSummary(),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text('Points come from reliable scans, verifying the material, lessons and the quiz. '
              'Unsure results never earn points. Best streak: ${p.bestStreak} days.',
              style: Theme.of(context).textTheme.bodySmall),
        ),
        for (final a in svc.achievements)
          Builder(builder: (context) {
            final got = p.unlocked.contains(a.id);
            final value = (p.metrics[a.metric] ?? 0).clamp(0, a.target);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: got ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                  child: Icon(achievementIcon(a.icon), color: got ? scheme.primary : scheme.outline),
                ),
                title: Text(a.title, style: TextStyle(fontWeight: got ? FontWeight.w700 : FontWeight.normal)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.description),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: value / a.target, minHeight: 6, borderRadius: BorderRadius.circular(6)),
                ]),
                trailing: got ? Icon(Icons.check_circle, color: scheme.primary) : Text('$value/${a.target}'),
              ),
            );
          }),
      ]),
    );
  }
}

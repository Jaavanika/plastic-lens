import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../services/classifier_service.dart';
import '../services/scan_store.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScanStore>();
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const AppLogo(size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Guest', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  Text('Sign in to back up your scans', style: t.bodySmall),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _Stat(label: 'Scans', value: '${store.scans.length}'),
          _Stat(label: 'Polymers', value: '${store.polymersFound.length}/6'),
          _Stat(label: 'Saved', value: '${store.collection.length}'),
        ]),
        const SectionTitle('Settings'),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('Delete scans on this device'),
              onTap: () => _confirmClear(context),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About PlasticLens'),
              onTap: () => showAbout(context),
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete all scans?'),
        content: const Text('This removes every scan and photo stored on this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<ScanStore>().clearLocal();
      if (context.mounted) showSnack(context, 'Scans deleted');
    }
  }
}

void showAbout(BuildContext context) {
  final model = context.read<ClassifierService>().modelVersion;
  showAboutDialog(
    context: context,
    applicationName: 'PlasticLens',
    applicationVersion: '1.0.0 · model $model',
    applicationIcon: const AppLogo(size: 40),
    children: const [
      Text('PlasticLens estimates the likely plastic type from a photo. It is a visual estimate, '
          'not a laboratory analysis. Always check the resin code on the item and your local recycling rules.'),
      SizedBox(height: 12),
      Text('Training data: PlasticWaste-DB by S. C. Sarkar, J. J. Bushra and M. S. Hossain (Mendeley Data, '
          'doi:10.17632/tvfx5dspf3.1, CC BY 4.0), and TrashNet by G. Thung and M. Yang (MIT licence). '
          'Images were cropped and resized for training.'),
      SizedBox(height: 12),
      Text('PlasticLens is an independent project and is not affiliated with any other plastic scanner app.'),
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(children: [
              Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      );
}

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../services/material_repository.dart';
import '../services/scan_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'scan_flow.dart';
import 'result_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenScanner, required this.onOpenHistory, required this.onOpenCollection});
  final VoidCallback onOpenScanner;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenCollection;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScanStore>();
    final materials = context.read<MaterialRepository>();
    final t = Theme.of(context).textTheme;
    final recent = store.scans.take(3).toList();
    final found = store.polymersFound.length;
    final tip = materials.all[DateTime.now().day % materials.all.length];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const _Header(),
            const SizedBox(height: 16),
            _HeroCard(onScan: onOpenScanner, onUpload: () => pickFromGallery(context)),
            SectionTitle('Recent scans',
                trailing: recent.isEmpty ? null : TextButton(onPressed: onOpenHistory, child: const Text('See all'))),
            if (recent.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No scans yet. Scan your first plastic item to start your collection.'),
                ),
              )
            else
              ...recent.map((s) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: ScanImage(path: s.imagePath, size: 48),
                      title: Text(s.itemName),
                      subtitle: Text(stateLabel(s.state, verified: s.userVerified)),
                      trailing: s.plasticType == null
                          ? Text(scanMaterialLabel(s))
                          : PolymerChip(code: s.plasticType!),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultScreen(scanId: s.id))),
                    ),
                  )),
            const SectionTitle('Your collection'),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onOpenCollection,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$found of 6 polymer types found', style: t.titleSmall),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: found / 6, minHeight: 8, borderRadius: BorderRadius.circular(8)),
                    const SizedBox(height: 10),
                    Text('${store.collection.length} items saved', style: t.bodySmall),
                  ]),
                ),
              ),
            ),
            const SectionTitle('Did you know?'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  PolymerChip(code: tip.code, resinCode: tip.resinCode),
                  const SizedBox(width: 12),
                  Expanded(child: Text(tip.fact)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(children: [
      const AppLogo(size: 40),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PlasticLens', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text('Know your plastic. Recycle it right.', style: t.bodySmall),
        ]),
      ),
    ]);
  }
}

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [AppColors.green, AppColors.ocean], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Icon(Icons.center_focus_strong_rounded, color: Colors.white, size: size * 0.6),
      );
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onScan, required this.onUpload});
  final VoidCallback onScan;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [AppColors.deepOcean, AppColors.ocean, AppColors.green], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('What is it made of?', style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Photograph a plastic item to find its likely type and how to recycle it.',
            style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.deepOcean),
              onPressed: onScan,
              icon: const Icon(Icons.photo_camera_rounded),
              label: const Text('Scan plastic'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
              onPressed: onUpload,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Upload'),
            ),
          ),
        ]),
      ]),
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../services/material_repository.dart';
import '../services/scan_store.dart';
import '../widgets/common.dart';
import 'material_details_screen.dart';
import 'result_screen.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key, this.header});

  /// Optional widget above the polymer grid (points/streak, Section 9).
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScanStore>();
    final materials = context.read<MaterialRepository>().all;
    final found = store.polymersFound;
    final saved = store.collection;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My collection')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        ?header,
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${found.length} of 6 polymer types found', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: found.length / 6, minHeight: 10, borderRadius: BorderRadius.circular(8)),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.1,
                children: [
                  for (final m in materials)
                    _PolymerTile(code: m.code, resin: m.resinCode, found: found.contains(m.code)),
                ],
              ),
            ]),
          ),
        ),
        SectionTitle('Saved items (${saved.length})'),
        if (saved.isEmpty)
          const EmptyState(
            icon: Icons.bookmark_border,
            title: 'Nothing saved yet',
            message: 'Tap “Save” on a result to add the item to your collection.',
          )
        else
          for (final m in materials)
            if (saved.any((s) => s.plasticType == m.code)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                child: PolymerChip(code: m.code, resinCode: m.resinCode),
              ),
              for (final s in saved.where((s) => s.plasticType == m.code))
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: ScanImage(path: s.imagePath, size: 48),
                    title: Text(s.itemName),
                    subtitle: Text(stateLabel(s.state, verified: s.userVerified)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultScreen(scanId: s.id))),
                  ),
                ),
            ],
        if (saved.any((s) => s.plasticType == null)) ...[
          const Padding(padding: EdgeInsets.fromLTRB(4, 8, 4, 4), child: Text('Other')),
          for (final s in saved.where((s) => s.plasticType == null))
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: ScanImage(path: s.imagePath, size: 48),
                title: Text(s.itemName),
                subtitle: Text(scanMaterialLabel(s)),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultScreen(scanId: s.id))),
              ),
            ),
        ],
      ]),
    );
  }
}

class _PolymerTile extends StatelessWidget {
  const _PolymerTile({required this.code, required this.resin, required this.found});
  final String code;
  final int resin;
  final bool found;

  @override
  Widget build(BuildContext context) {
    final c = colorForPolymer(code);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$code ${found ? 'found' : 'not found yet'}',
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MaterialDetailsScreen(code: code))),
        child: Container(
          decoration: BoxDecoration(
            color: found ? c.withValues(alpha: 0.15) : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: found ? c : Colors.transparent, width: 1.5),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('♲ $resin', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: found ? c : scheme.outline)),
            Text(code, style: TextStyle(fontWeight: FontWeight.w700, color: found ? c : scheme.outline)),
            Icon(found ? Icons.check_circle : Icons.lock_outline, size: 16, color: found ? c : scheme.outline),
          ]),
        ),
      ),
    );
  }
}

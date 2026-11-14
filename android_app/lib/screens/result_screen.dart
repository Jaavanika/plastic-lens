import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/classification.dart';
import '../models/plastic_type.dart';
import '../models/scan_record.dart';
import '../services/feedback_service.dart';
import '../services/material_repository.dart';
import '../services/scan_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'material_details_screen.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.scanId, this.justScanned = false, this.probabilities});
  final String scanId;
  final bool justScanned;

  /// Full model output; only available straight after a scan.
  final List<MapEntry<String, double>>? probabilities;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScanStore>();
    final scan = store.byId(scanId);
    if (scan == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('This scan was deleted.')));
    }
    final materials = context.read<MaterialRepository>();
    final material = materials.byCode(scan.plasticType);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
        actions: [
          IconButton(
            tooltip: 'Delete scan',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, scan),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            AspectRatio(aspectRatio: 4 / 3, child: ScanImage(path: scan.imagePath, radius: 20)),
            const SizedBox(height: 12),
            _StateBanner(scan: scan),
            const SizedBox(height: 12),
            _DetailsCard(scan: scan, material: material),
            if (scan.secondOpinion != null && !scan.secondOpinion!.startsWith('A printed resin code'))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.travel_explore),
                    title: const Text('Online second opinion'),
                    subtitle: Text(scan.secondOpinion!),
                  ),
                ),
              ),
            if (probabilities != null && scan.state == ResultState.medium && !scan.userVerified)
              _Alternatives(probabilities: probabilities!),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _correctMaterial(context, scan),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Correct material'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    scan.inCollection = !scan.inCollection;
                    await store.save(scan);
                    if (context.mounted) {
                      showSnack(context, scan.inCollection ? 'Saved to your collection' : 'Removed from collection');
                    }
                  },
                  icon: Icon(scan.inCollection ? Icons.bookmark : Icons.bookmark_add_outlined),
                  label: Text(scan.inCollection ? 'In collection' : 'Save'),
                ),
              ),
            ]),
            if (scan.state == ResultState.low && justScanned) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Try another photo'),
              ),
            ],
            if (material != null) _MaterialPanel(material: material, caveat: materials.caveat),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ScanRecord scan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this scan?'),
        content: const Text('It will be removed from your history and collection.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      Navigator.of(context).pop();
      await context.read<ScanStore>().delete(scan.id);
    }
  }

  Future<void> _correctMaterial(BuildContext context, ScanRecord scan) async {
    final materials = context.read<MaterialRepository>();
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('What is it really made of? Check the resin code (♲ number) printed on the item.'),
          ),
          for (final m in materials.all)
            ListTile(
              leading: PolymerChip(code: m.code, resinCode: m.resinCode),
              title: Text(m.fullName),
              selected: scan.plasticType == m.code,
              onTap: () => Navigator.pop(c, m.code),
            ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Not plastic'),
            selected: scan.containsPlastic == false,
            onTap: () => Navigator.pop(c, nonPlasticLabel),
          ),
        ]),
      ),
    );
    if (choice == null || !context.mounted) return;
    final store = context.read<ScanStore>();
    final feedback = context.read<FeedbackService>();
    final predicted = scan.plasticType ?? (scan.containsPlastic == false ? nonPlasticLabel : null);
    final m = materials.byCode(choice);
    scan
      ..plasticType = m?.code
      ..resinCode = m?.resinCode
      ..containsPlastic = choice != nonPlasticLabel
      ..userVerified = true;
    await store.save(scan);
    if (predicted != choice) {
      await feedback.submitCorrection(scan: scan, predicted: predicted, corrected: choice);
    }
    if (context.mounted) showSnack(context, 'Thanks! Your correction helps improve PlasticLens.');
  }
}

class _StateBanner extends StatelessWidget {
  const _StateBanner({required this.scan});
  final ScanRecord scan;

  @override
  Widget build(BuildContext context) {
    final fromPrintedCode = scan.secondOpinion != null && scan.secondOpinion!.startsWith('A printed resin code') && scan.plasticType != null;
    final (IconData icon, String title, String body) = scan.userVerified
        ? (Icons.verified_outlined, 'Verified by you', 'You confirmed the material of this item.')
        : fromPrintedCode
            ? (Icons.recycling, '♲${scan.resinCode} printed on the item: ${scan.plasticType}', scan.secondOpinion!)
            : switch (scan.state) {
            ResultState.high => (
                Icons.check_circle_outline,
                'Likely ${scan.plasticType}',
                'This is a visual estimate, not a lab test. Check for a ♲ resin code on the item to confirm.'
              ),
            ResultState.medium => (
                Icons.help_outline,
                'Possibly ${scan.plasticType}. Please verify',
                'The model is not very sure. Check the resin code on the item, or try a clearer photo.'
              ),
            ResultState.low => (
                Icons.report_gmailerrorred,
                'Unable to identify reliably',
                'Try another photo: one item, good light, plain background. Or set the material yourself.'
              ),
            ResultState.nonPlastic => (
                Icons.do_not_disturb_on_outlined,
                'No plastic detected',
                'This looks like glass, paper, cardboard or metal. If it is plastic, correct it below.'
              ),
          };
    final color = stateColor(scan.state, verified: scan.userVerified || fromPrintedCode);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(body, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ]),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.scan, required this.material});
  final ScanRecord scan;
  final PlasticType? material;

  @override
  Widget build(BuildContext context) {
    final presence = switch (scan.containsPlastic) { true => 'Yes', false => 'No', null => 'Unsure' };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(children: [
          _Row(
            label: 'Object',
            value: Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(child: Text(scan.itemName, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600))),
              IconButton(
                tooltip: 'Rename',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit, size: 18),
                onPressed: () => _rename(context),
              ),
            ]),
          ),
          const Divider(height: 1),
          _Row(label: 'Plastic presence', value: Text(presence, style: const TextStyle(fontWeight: FontWeight.w600))),
          const Divider(height: 1),
          _Row(
            label: 'Plastic type',
            value: material == null
                ? const Text('—', style: TextStyle(fontWeight: FontWeight.w600))
                : Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    PolymerChip(code: material!.code, resinCode: material!.resinCode),
                    const SizedBox(height: 4),
                    Text(material!.fullName, style: Theme.of(context).textTheme.bodySmall),
                  ]),
          ),
          const Divider(height: 1),
          _Row(
            label: 'Confidence',
            value: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${(scan.confidence * 100).toStringAsFixed(1)} %', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(stateLabel(scan.state, verified: scan.userVerified),
                  style: TextStyle(color: stateColor(scan.state, verified: scan.userVerified), fontSize: 12)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Confidence is the model’s own estimate from the photo, not a laboratory measurement. '
              'Scanned ${DateFormat.yMMMd().add_jm().format(scan.createdAt)} · model ${scan.modelVersion}'
              '${scan.llmUsed ? ' · object named by online check' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: scan.itemName);
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Name this item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Water bottle'),
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, controller.text), child: const Text('Save')),
        ],
      ),
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !context.mounted) return;
    scan.itemName = trimmed;
    await context.read<ScanStore>().save(scan);
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(width: 16),
          Expanded(child: Align(alignment: Alignment.centerRight, child: value)),
        ]),
      );
}

class _Alternatives extends StatelessWidget {
  const _Alternatives({required this.probabilities});
  final List<MapEntry<String, double>> probabilities;

  @override
  Widget build(BuildContext context) {
    final top = probabilities.take(3).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Closest matches', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final e in top)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(width: 92, child: Text(e.key == nonPlasticLabel ? 'Not plastic' : e.key)),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: e.value,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                      color: colorForPolymer(e.key),
                    ),
                  ),
                  SizedBox(width: 52, child: Text('${(e.value * 100).round()} %', textAlign: TextAlign.end)),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}

class _MaterialPanel extends StatelessWidget {
  const _MaterialPanel({required this.material, required this.caveat});
  final PlasticType material;
  final String caveat;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        margin: EdgeInsets.zero,
        color: colorForPolymer(material.code).withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${material.code}: ${material.fullName}', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(material.description),
            const SizedBox(height: 12),
            Text('How to recycle', style: t.titleSmall),
            const SizedBox(height: 4),
            for (final g in material.recyclingGuidance.take(3))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('•  '),
                  Expanded(child: Text(g)),
                ]),
              ),
            const SizedBox(height: 8),
            Text(caveat, style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MaterialDetailsScreen(code: material.code)),
                ),
                icon: const Icon(Icons.arrow_forward),
                label: Text('More about ${material.code}'),
              ),
            ),
            Row(children: [
              const Icon(Icons.eco_outlined, color: AppColors.green, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(material.ecoTip, style: t.bodySmall)),
            ]),
          ]),
        ),
      ),
    );
  }
}

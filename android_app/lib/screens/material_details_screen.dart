import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../services/material_repository.dart';
import '../widgets/common.dart';

class MaterialDetailsScreen extends StatelessWidget {
  const MaterialDetailsScreen({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<MaterialRepository>();
    final m = repo.byCode(code);
    final t = Theme.of(context).textTheme;
    if (m == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Material not found')));
    }
    final color = colorForPolymer(m.code);

    Widget bullets(List<String> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final i in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(top: 7), child: Icon(Icons.circle, size: 6, color: color)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(i)),
                ]),
              ),
          ],
        );

    Widget section(String title, Widget child, {IconData? icon}) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (icon != null) ...[Icon(icon, size: 20, color: color), const SizedBox(width: 8)],
                Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              child,
            ]),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(m.code)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Text('${m.resinCode}', style: t.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.fullName, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  Text('Resin identification code ${m.resinCode}', style: t.bodySmall),
                ]),
              ),
            ]),
          ),
          section('About', Text(m.description), icon: Icons.info_outline),
          section('Properties', bullets(m.properties), icon: Icons.science_outlined),
          section('Typical uses', bullets(m.commonItems), icon: Icons.shopping_bag_outlined),
          section('How to recycle', bullets(m.recyclingGuidance), icon: Icons.recycling),
          section(
            'Recyclability',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                for (var i = 1; i <= 5; i++)
                  Icon(i <= m.recyclabilityRating ? Icons.recycling : Icons.recycling_outlined,
                      color: i <= m.recyclabilityRating ? color : Theme.of(context).disabledColor, size: 22),
                const SizedBox(width: 8),
                Text('${m.recyclabilityRating}/5'),
              ]),
              const SizedBox(height: 8),
              Text(m.recyclabilityNote),
              const SizedBox(height: 8),
              Text(repo.caveat, style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
            ]),
            icon: Icons.place_outlined,
          ),
          if (m.otherMaterials.isNotEmpty) section('Often combined with', bullets(m.otherMaterials), icon: Icons.layers_outlined),
          section('Did you know?', Text(m.fact), icon: Icons.lightbulb_outline),
          section('Eco tip', Text(m.ecoTip), icon: Icons.eco_outlined),
          if (m.sources.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('Sources: ${m.sources.join('; ')}', style: t.bodySmall),
            ),
        ]),
      ),
    );
  }
}

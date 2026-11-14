import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../models/classification.dart';
import '../models/scan_record.dart';
import '../theme.dart';

const polymerColors = {
  'PET': Color(0xFF0B6E99),
  'HDPE': Color(0xFF00897B),
  'PVC': Color(0xFFB0413E),
  'LDPE': Color(0xFF7E57C2),
  'PP': Color(0xFFC77C02),
  'PS': Color(0xFF6D6875),
};

Color colorForPolymer(String? code) =>
    polymerColors[code] ?? AppColors.neutral;

/// Small rounded badge: "♲ 1  PET".
class PolymerChip extends StatelessWidget {
  const PolymerChip({super.key, required this.code, this.resinCode, this.large = false});
  final String code;
  final int? resinCode;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = colorForPolymer(code);
    final style = (large
            ? Theme.of(context).textTheme.titleMedium
            : Theme.of(context).textTheme.labelLarge)
        ?.copyWith(color: c, fontWeight: FontWeight.w700);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 12 : 8, vertical: large ? 6 : 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(
        resinCode == null ? code : '♲ $resinCode  $code',
        style: style,
      ),
    );
  }
}

/// Shows a scan photo, or a placeholder when the file is missing.
class ScanImage extends StatelessWidget {
  const ScanImage({super.key, required this.path, this.size, this.radius = 12, this.fit = BoxFit.cover});
  final String path;
  final double? size;
  final double radius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    final hasFile = path.isNotEmpty && file.existsSync();
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: hasFile
            ? Image.file(file, fit: fit, cacheWidth: size == null ? null : (size! * 3).round(),
                errorBuilder: (_, _, _) => _placeholder(scheme))
            : _placeholder(scheme),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Icon(Icons.image_outlined, color: scheme.onSurfaceVariant),
      );
}

String stateLabel(ResultState s, {bool verified = false}) {
  if (verified) return 'Verified by you';
  return switch (s) {
    ResultState.high => 'High confidence',
    ResultState.medium => 'Please verify',
    ResultState.low => 'Unsure',
    ResultState.nonPlastic => 'No plastic',
  };
}

Color stateColor(ResultState s, {bool verified = false}) {
  if (verified) return AppColors.high;
  return switch (s) {
    ResultState.high => AppColors.high,
    ResultState.medium => AppColors.medium,
    ResultState.low => AppColors.low,
    ResultState.nonPlastic => AppColors.neutral,
  };
}

/// Short label for list rows.
String scanMaterialLabel(ScanRecord s) {
  if (s.plasticType != null) return s.plasticType!;
  if (s.containsPlastic == false) return 'Non-plastic';
  return 'Unsure';
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Row(children: [
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          ?trailing,
        ]),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: t.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message, style: t.bodyMedium, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

import 'package:material_ui/material_ui.dart';

/// PlasticLens palette: recycling green + ocean blue.
class AppColors {
  static const green = Color(0xFF2E7D4F);
  static const ocean = Color(0xFF0B6E99);
  static const deepOcean = Color(0xFF06425C);
  static const sand = Color(0xFFF4F1E8);

  // Result-state colours.
  static const high = Color(0xFF2E7D4F);
  static const medium = Color(0xFFB7791F);
  static const low = Color(0xFFB3261E);
  static const neutral = Color(0xFF5F6B73);
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.green,
    brightness: brightness,
  ).copyWith(
    secondary: brightness == Brightness.light
        ? AppColors.ocean
        : const Color(0xFF7FCBEF),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: scheme.surfaceContainerLow,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

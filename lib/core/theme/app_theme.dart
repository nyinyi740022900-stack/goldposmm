import 'package:flutter/material.dart';

/// Central theme tokens for the app. Frontend/UX workstream owns this file.
///
/// Uses Material 3 with a seed color tuned for retail (calm teal/green,
/// readable on cheap panels). Typography falls back to the platform's
/// Myanmar-capable font (Noto Sans Myanmar / Pyidaungsu) when locale is `my`.
class AppTheme {
  const AppTheme._();

  static const Color _seed = Color(0xFF00695C); // teal 800

  // Spacing scale — use these instead of magic numbers for consistency.
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 24;
  static const double space6 = 32;

  static const double radius = 12;

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52), // big tap targets
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        filled: true,
      ),
    );
  }
}

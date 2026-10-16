import 'package:flutter/material.dart';

/// Tasky's design language: "Aurora dusk" — deep indigo skies, aurora
/// gradients, warm coral accents. Distinctive, calm, and never a generic
/// chatbot clone.
class AppTheme {
  static const Color primary = Color(0xFF6C4CF1);
  static const Color primaryDeep = Color(0xFF4A2FD6);
  static const Color accent = Color(0xFFFF6B6B);
  static const Color amber = Color(0xFFFFB020);
  static const Color mint = Color(0xFF2DD4BF);

  static const List<Color> heroGradient = [
    Color(0xFF2A1B5E),
    Color(0xFF6C4CF1),
    Color(0xFFB16CEA),
  ];

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: primary,
      secondary: accent,
      surface: Colors.white,
      surfaceContainerHighest: Color(0xFFF1EDFF),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF7F5FF),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: primary.withValues(alpha: 0.10)),
        ),
        color: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.18)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999)),
        backgroundColor: primary.withValues(alpha: 0.10),
        labelStyle: const TextStyle(color: primaryDeep, fontSize: 12),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: Color(0xFF9D86FF),
      secondary: accent,
      surface: Color(0xFF1C1830),
      surfaceContainerHighest: Color(0xFF262044),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF12101F),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
              color: const Color(0xFF9D86FF).withValues(alpha: 0.16)),
        ),
        color: const Color(0xFF1C1830),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1C1830),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
              color: const Color(0xFF9D86FF).withValues(alpha: 0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
              color: const Color(0xFF9D86FF).withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: Color(0xFF9D86FF), width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999)),
        backgroundColor:
            const Color(0xFF9D86FF).withValues(alpha: 0.14),
        labelStyle:
            const TextStyle(color: Color(0xFFCDBFFF), fontSize: 12),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF9D86FF),
        foregroundColor: Color(0xFF12101F),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

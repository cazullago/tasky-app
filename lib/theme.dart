import 'package:flutter/material.dart';

/// Tasky brand: warm, friendly, premium — deliberately NOT a chatbot look.
class TaskyColors {
  static const Color teal = Color(0xFF0E7C6B);
  static const Color tealDeep = Color(0xFF0A5A4E);
  static const Color tealBright = Color(0xFF35C9B4);
  static const Color amber = Color(0xFFF0A93B);
  static const Color amberSoft = Color(0xFFFFF3DC);
  static const Color ink = Color(0xFF201C15);
  static const Color inkSoft = Color(0xFF6B6357);
  static const Color paper = Color(0xFFFAF7F1);
  static const Color cardLight = Colors.white;

  static const Color bgDark = Color(0xFF141210);
  static const Color cardDark = Color(0xFF1F1C17);
  static const Color inkDark = Color(0xFFF5F1E8);
  static const Color inkSoftDark = Color(0xFFA79E8D);
}

ThemeData taskyTheme(Brightness b) {
  final bool dark = b == Brightness.dark;
  final scheme = ColorScheme(
    brightness: b,
    primary: dark ? TaskyColors.tealBright : TaskyColors.teal,
    onPrimary: Colors.white,
    secondary: TaskyColors.amber,
    onSecondary: TaskyColors.ink,
    surface: dark ? TaskyColors.cardDark : TaskyColors.cardLight,
    onSurface: dark ? TaskyColors.inkDark : TaskyColors.ink,
    background: dark ? TaskyColors.bgDark : TaskyColors.paper,
    onBackground: dark ? TaskyColors.inkDark : TaskyColors.ink,
    error: const Color(0xFFD64545),
    onError: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.background,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.background,
      foregroundColor: scheme.onBackground,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: scheme.onBackground,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF2A2620) : const Color(0xFFF1ECE1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: dark ? TaskyColors.inkSoftDark : TaskyColors.inkSoft),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: scheme.surface,
      selectedItemColor: scheme.primary,
      unselectedItemColor: dark ? TaskyColors.inkSoftDark : TaskyColors.inkSoft,
      type: BottomNavigationBarType.fixed,
      elevation: 12,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
    ),
    textTheme: (dark ? ThemeData.dark() : ThemeData.light()).textTheme.apply(
          bodyColor: scheme.onBackground,
          displayColor: scheme.onBackground,
        ),
  );
}

/// Soft premium card shadow used across the app.
BoxDecoration taskyCardDeco(BuildContext context, {double radius = 20}) {
  final t = Theme.of(context);
  final dark = t.brightness == Brightness.dark;
  return BoxDecoration(
    color: t.cardColor,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(dark ? 0.35 : 0.06),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

/// Friendly greeting based on the time of day.
String dayGreeting() {
  final h = DateTime.now().hour;
  if (h < 5) return 'Up late';
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

import 'package:flutter/material.dart';

abstract final class Palette {
  static const pink = Color(0xFFF06FA0);
  static const pinkSoft = Color(0xFFFCE4EE);
  static const lavender = Color(0xFFB79CF0);
  static const lavenderSoft = Color(0xFFEFE7FD);
  static const mint = Color(0xFF8FDCC2);
  static const peach = Color(0xFFFFC4A8);
  static const cream = Color(0xFFFFF8F1);
  static const ink = Color(0xFF4A3B5C);
  static const inkSoft = Color(0xFF8C7C9E);

  static const backdrop = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFE3EE), Color(0xFFEDE4FF), Color(0xFFE3F7F0)],
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.pink,
    primary: Palette.pink,
    secondary: Palette.lavender,
    surface: Palette.cream,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Palette.cream,
    textTheme: base.textTheme.apply(bodyColor: Palette.ink, displayColor: Palette.ink),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}

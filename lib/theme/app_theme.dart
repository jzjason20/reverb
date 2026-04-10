import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const surface = Color(0xFFF7F2EA);
  const accent = Color(0xFFCC5C3B);
  const deepInk = Color(0xFF18211E);

  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.light,
    surface: surface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: surface,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: deepInk,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: deepInk,
      ),
      titleLarge: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: deepInk,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: deepInk,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.4,
        color: Color(0xFF495652),
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.35,
        color: Color(0xFF66756F),
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: const Color(0xFF18211E),
      backgroundColor: const Color(0xFFE7DED1),
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        color: Color(0xFF18211E),
      ),
      secondaryLabelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

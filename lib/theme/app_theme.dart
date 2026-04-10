import 'package:flutter/material.dart';

class AppTheme {
  static const _accent = Color(0xFFCC5C3B);

  static ThemeData get lightTemplate {
    const surface = Color(0xFFF7F2EA);
    const background = Color(0xFFF4EFE8);
    const primaryText = Color(0xFF18211E);
    const secondaryText = Color(0xFF495652);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accent,
        brightness: Brightness.light,
        surface: background,
        surfaceContainer: surface,
      ),
      scaffoldBackgroundColor: background,
      textTheme: _buildTextTheme(primaryText, secondaryText),
      chipTheme: _buildChipTheme(primaryText, const Color(0xFFE7DED1)),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0x1F000000), width: 1),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }

  static ThemeData get darkTemplate {
    const surface = Color(0xFF1E1E1E);
    const background = Color(0xFF121212);
    const primaryText = Color(0xFFF5F5F5);
    const secondaryText = Color(0xFFA0A0A0);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accent,
        brightness: Brightness.dark,
        surface: background,
        surfaceContainer: surface,
      ),
      scaffoldBackgroundColor: background,
      textTheme: _buildTextTheme(primaryText, secondaryText),
      chipTheme: _buildChipTheme(primaryText, const Color(0xFF2C2C2C)),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0x1FFFFFFF), width: 1),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }

  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return TextTheme(
      headlineMedium: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: primary,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: secondary),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.35,
        color: secondary.withValues(alpha: 0.8),
      ),
    );
  }

  static ChipThemeData _buildChipTheme(Color primaryText, Color bg) {
    return ChipThemeData(
      selectedColor: primaryText,
      backgroundColor: bg,
      labelStyle: TextStyle(fontWeight: FontWeight.w600, color: primaryText),
      secondaryLabelStyle: TextStyle(fontWeight: FontWeight.w600, color: bg),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

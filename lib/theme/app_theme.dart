import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const _accent = Color(0xFF171717);

  static ThemeData get lightTemplate {
    const surface = Color(0xFFF9F9F9);
    const background = Color(0xFFFFFFFF);
    const primaryText = Color(0xFF171717);
    const secondaryText = Color(0xFF666666);

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
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        _buildTextTheme(primaryText, secondaryText),
      ),
      dividerColor: const Color(0x14000000),
      chipTheme: _buildChipTheme(primaryText, surface),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x1F000000), width: 1),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF171717),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }

  static ThemeData get darkTemplate {
    const surface = Color(0xFF1E1E1E);
    const background = Color(0xFF171717);
    const primaryText = Color(0xFFF5F5F5);
    const secondaryText = Color(0xFF9A9A9A);

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
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        _buildTextTheme(primaryText, secondaryText),
      ),
      dividerColor: const Color(0x1FFFFFFF),
      chipTheme: _buildChipTheme(primaryText, const Color(0xFF242424)),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x1FFFFFFF), width: 1),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF171717),
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
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.2,
        letterSpacing: 0.4,
        color: secondary,
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
      selectedColor: bg,
      backgroundColor: Colors.transparent,
      labelStyle: TextStyle(fontWeight: FontWeight.w600, color: primaryText),
      secondaryLabelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      side: BorderSide(color: primaryText.withValues(alpha: 0.2)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

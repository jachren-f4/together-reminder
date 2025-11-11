import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Minimal Black & White Color System
  static const Color primaryBlack = Color(0xFF1A1A1A);
  static const Color primaryWhite = Color(0xFFFFFEFD);
  static const Color backgroundGray = Color(0xFFFAFAFA);

  // Legacy colors (kept for compatibility during migration)
  static const Color accentGreen = Color(0xFF22c55e);
  static const Color accentOrange = Color(0xFFf59e0b);

  // Background colors
  static const Color backgroundStart = backgroundGray;
  static const Color backgroundEnd = backgroundGray;
  static const Color cardBackground = primaryWhite;

  // Border and text colors
  static const Color borderLight = Color(0xFFF0F0F0);
  static const Color textPrimary = primaryBlack;
  static const Color textSecondary = Color(0xFF6E6E6E);
  static const Color textTertiary = Color(0xFFAAAAAA);

  // No gradients - solid colors only
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryBlack, primaryBlack],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [backgroundGray, backgroundGray],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient timeButtonGradient = LinearGradient(
    colors: [backgroundGray, backgroundGray],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Typography - Playfair Display for headlines, Inter for body
  static TextStyle get headlineFont => GoogleFonts.playfairDisplay();
  static TextStyle get bodyFont => GoogleFonts.inter();

  // Theme data
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.inter().fontFamily,
      primaryColor: primaryBlack,
      scaffoldBackgroundColor: backgroundGray,
      colorScheme: const ColorScheme.light(
        primary: primaryBlack,
        secondary: textSecondary,
        surface: cardBackground,
        onPrimary: primaryWhite,
        onSurface: textPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlack,
          foregroundColor: primaryWhite,
          elevation: 0,
          shadowColor: primaryBlack.withAlpha((0.15 * 255).round()),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundGray,
          foregroundColor: primaryBlack,
          side: const BorderSide(color: borderLight, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: primaryWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderLight, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderLight, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryBlack, width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
        hintStyle: GoogleFonts.inter(
          color: textTertiary,
          fontSize: 16,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shadowColor: Colors.black.withAlpha((0.06 * 255).round()),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      textTheme: TextTheme(
        // Headlines - Playfair Display
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 36,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        displaySmall: GoogleFonts.playfairDisplay(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.4,
        ),
        headlineLarge: GoogleFonts.playfairDisplay(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        headlineSmall: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
        // Body text - Inter
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textSecondary,
        ),
      ),
    );
  }
}

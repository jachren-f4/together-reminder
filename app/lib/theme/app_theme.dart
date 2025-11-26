import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:togetherremind/config/theme_config.dart';
import 'package:togetherremind/config/brand/brand_loader.dart';

class AppTheme {
  // ============================================
  // Colors delegated to BrandConfig
  // ============================================
  // These getters allow existing code to continue using AppTheme.colorName
  // while the actual values come from the current brand configuration.

  // Primary colors
  static Color get primaryBlack => BrandLoader().colors.primary;
  static Color get primaryWhite => BrandLoader().colors.textOnPrimary;
  static Color get backgroundGray => BrandLoader().colors.background;

  // Legacy accent colors (kept for compatibility)
  static Color get accentGreen => BrandLoader().colors.accentGreen;
  static Color get accentOrange => BrandLoader().colors.accentOrange;

  // Background colors
  static Color get backgroundStart => BrandLoader().colors.background;
  static Color get backgroundEnd => BrandLoader().colors.background;
  static Color get cardBackground => BrandLoader().colors.surface;

  // Border and text colors
  static Color get borderLight => BrandLoader().colors.borderLight;
  static Color get textPrimary => BrandLoader().colors.textPrimary;
  static Color get textSecondary => BrandLoader().colors.textSecondary;
  static Color get textTertiary => BrandLoader().colors.textTertiary;

  // No gradients - solid colors only (delegated to BrandConfig)
  static LinearGradient get primaryGradient => BrandLoader().colors.primaryGradient;
  static LinearGradient get backgroundGradient => BrandLoader().colors.backgroundGradient;
  static LinearGradient get timeButtonGradient => BrandLoader().colors.backgroundGradient;

  // Typography - Configurable serif for headlines, Inter for body
  static TextStyle get headlineFont => ThemeConfig().serifFont;
  static TextStyle get bodyFont => GoogleFonts.inter();

  // Theme data
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.inter().fontFamily,
      primaryColor: primaryBlack,
      scaffoldBackgroundColor: backgroundGray,
      colorScheme: ColorScheme.light(
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
          side: BorderSide(color: borderLight, width: 2),
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
          borderSide: BorderSide(color: borderLight, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderLight, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryBlack, width: 2),
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
        // Headlines - Configurable serif font (default: Georgia)
        displayLarge: ThemeConfig().serifFont.copyWith(
          fontSize: 36,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: ThemeConfig().serifFont.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        displaySmall: ThemeConfig().serifFont.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.4,
        ),
        headlineLarge: ThemeConfig().serifFont.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        headlineMedium: ThemeConfig().serifFont.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        headlineSmall: ThemeConfig().serifFont.copyWith(
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

import 'package:flutter/material.dart';

/// Us 2.0 specific design tokens
///
/// These values are extracted from the HTML mockup CSS variables.
/// Use BrandLoader().colors for cross-brand compatible colors,
/// and this class for Us2-specific styling that doesn't exist in other brands.
class Us2Theme {
  // ============================================
  // Colors (from HTML :root CSS variables)
  // ============================================

  // Background gradient
  static const bgGradientStart = Color(0xFFFFD1C1);
  static const bgGradientEnd = Color(0xFFFFF5F0);

  // Primary brand colors
  static const primaryBrandPink = Color(0xFFFF5E62);
  static const gradientAccentStart = Color(0xFFFF6B6B);
  static const gradientAccentEnd = Color(0xFFFF9F43);

  // Card and surface colors
  static const cardSalmon = Color(0xFFFF7B6B);
  static const cardSalmonDark = Color(0xFFFF6B5B);
  static const cream = Color(0xFFFFF8F0);
  static const beige = Color(0xFFF5E6D8);

  // Text colors
  static const textDark = Color(0xFF2D2D2D);
  static const textMedium = Color(0xFF6B6B6B);
  static const textLight = Color(0xFF9B9B9B);

  // Glow effects
  static const glowPink = Color(0xCCFF6B6B); // 80% opacity
  static const glowOrange = Color(0x99FF9F43); // 60% opacity

  // ============================================
  // Linked Game Colors (from HTML mockup)
  // ============================================

  // Grid frame - gold beveled
  static const goldLight = Color(0xFFF5E6D0);
  static const goldMid = Color(0xFFE8D5B8);
  static const goldDark = Color(0xFFD4B896);
  static const goldBorder = Color(0xFFC9A875);

  // Cells
  static const cellCream = Color(0xFFFFFBF5);
  static const cellBorder = Color(0xFFE8DDD0);
  static const voidDark = Color(0xFF4A2C2A);
  static const letterPink = Color(0xFFE91E63);

  // Letter tiles
  static const tileGoldLight = Color(0xFFFFE8A0);
  static const tileGoldDark = Color(0xFFD4A855);
  static const tileText = Color(0xFF5D4E37);

  // ============================================
  // Typography (from HTML CSS)
  // ============================================

  static const fontLogo = 'Pacifico';
  static const fontHeading = 'Playfair Display';
  static const fontBody = 'Nunito';

  // Logo styling
  static const logoFontSize = 52.0;
  static const logoHeartSize = 20.0;

  // Day label styling
  static const dayLabelFontSize = 22.0;

  // Section header styling
  static const sectionHeaderFontSize = 18.0;
  static const sectionHeaderLetterSpacing = 2.0;

  // Quest card styling
  static const questTitleFontSize = 20.0;
  static const questDescriptionFontSize = 14.0;

  // ============================================
  // Gradients
  // ============================================

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgGradientStart, bgGradientEnd],
  );

  static const accentGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [gradientAccentStart, gradientAccentEnd],
  );

  static const connectionBarGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [gradientAccentStart, gradientAccentEnd],
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [cardSalmon, cardSalmonDark],
  );

  static const buttonGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.white, cream],
  );

  // Linked game gradients
  static const gridFrameGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [goldLight, goldMid, goldDark],
  );

  static const letterTileGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [tileGoldLight, tileGoldDark],
  );

  static const voidCellGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5D3A3A), voidDark],
  );

  static const clueCellGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFDF8), Color(0xFFFFF5E6)],
  );

  static const answerCellGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFFFF8F8)],
  );

  // ============================================
  // Shadows
  // ============================================

  static List<Shadow> get logoGlowShadows => [
        Shadow(
          blurRadius: 20,
          color: glowPink.withOpacity(0.8),
          offset: Offset.zero,
        ),
        Shadow(
          blurRadius: 40,
          color: glowOrange.withOpacity(0.5),
          offset: Offset.zero,
        ),
        Shadow(
          blurRadius: 60,
          color: glowPink.withOpacity(0.3),
          offset: Offset.zero,
        ),
        Shadow(
          blurRadius: 80,
          color: glowOrange.withOpacity(0.2),
          offset: Offset.zero,
        ),
      ];

  static List<BoxShadow> get cardGlowShadow => [
        BoxShadow(
          color: glowPink.withOpacity(0.3),
          blurRadius: 15,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get buttonGlowShadow => [
        BoxShadow(
          color: glowPink.withOpacity(0.5),
          blurRadius: 15,
          spreadRadius: 2,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get buttonHoverGlowShadow => [
        BoxShadow(
          color: glowPink.withOpacity(0.7),
          blurRadius: 25,
          spreadRadius: 4,
          offset: const Offset(0, 6),
        ),
      ];

  // Linked game shadows
  static List<BoxShadow> get gridFrameShadow => [
        const BoxShadow(
          color: Color(0x26000000), // 15% black
          blurRadius: 20,
          offset: Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get letterTileShadow => [
        const BoxShadow(
          color: Color(0x33000000), // 20% black
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
        const BoxShadow(
          color: Color(0x1A000000), // 10% black
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get scoreBadgeShadow => [
        BoxShadow(
          color: glowPink.withOpacity(0.3),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  // ============================================
  // Dimensions
  // ============================================

  // Avatar dimensions
  static const avatarWidth = 140.0;
  static const avatarHeight = 175.0;
  static const avatarBorderRadius = 20.0;

  // Connection bar dimensions
  static const connectionBarHeight = 80.0;
  static const connectionBarBorderRadius = 16.0;
  static const progressHeartSize = 44.0;

  // Quest card dimensions
  static const questCardBorderRadius = 20.0;
  static const questImageHeight = 180.0;
  static const questButtonBorderRadius = 25.0;

  // Bottom nav dimensions
  static const bottomNavHeight = 70.0;

  // ============================================
  // Animation durations (in milliseconds)
  // ============================================

  static const sparkleAnimationDuration = 1500;
  static const buttonPressAnimationDuration = 150;
  static const hoverAnimationDuration = 200;

  // ============================================
  // Text Styles
  // ============================================

  static TextStyle get logoStyle => TextStyle(
        fontFamily: fontLogo,
        fontSize: logoFontSize,
        color: Colors.white,
        shadows: logoGlowShadows,
      );

  static TextStyle get dayLabelStyle => const TextStyle(
        fontFamily: fontHeading,
        fontSize: dayLabelFontSize,
        fontStyle: FontStyle.italic,
        color: textDark,
      );

  static TextStyle get sectionHeaderStyle => const TextStyle(
        fontFamily: fontHeading,
        fontSize: sectionHeaderFontSize,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
        letterSpacing: sectionHeaderLetterSpacing,
        color: textDark,
      );

  static TextStyle get questTitleStyle => const TextStyle(
        fontFamily: fontHeading,
        fontSize: questTitleFontSize,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  static TextStyle get questDescriptionStyle => TextStyle(
        fontFamily: fontBody,
        fontSize: questDescriptionFontSize,
        fontStyle: FontStyle.italic,
        color: Colors.white.withOpacity(0.9),
      );

  static TextStyle get buttonTextStyle => const TextStyle(
        fontFamily: fontBody,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: primaryBrandPink,
      );

  static TextStyle get avatarBadgeStyle => const TextStyle(
        fontFamily: fontBody,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        color: textDark,
      );
}

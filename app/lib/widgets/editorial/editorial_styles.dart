import 'package:flutter/material.dart';
import '../../config/brand/brand_loader.dart';
import '../../config/brand/brand_colors.dart';

/// Editorial design system - uses BrandLoader for white-label compatibility
///
/// Color mapping from editorial concept to BrandColors:
/// - ink (black) → textPrimary
/// - paper (white) → surface
/// - inkLight (gray) → borderLight
/// - inkMuted (#666) → textSecondary
///
/// Usage:
/// ```dart
/// Container(
///   decoration: BoxDecoration(
///     color: EditorialStyles.paper,
///     border: Border.all(color: EditorialStyles.ink, width: EditorialStyles.borderWidth),
///   ),
/// )
/// ```
class EditorialStyles {
  EditorialStyles._(); // Prevent instantiation

  // ============================================
  // Colors (via BrandLoader)
  // ============================================

  static BrandColors get _colors => BrandLoader().colors;

  /// Primary ink color (black) - for text, borders, fills
  static Color get ink => _colors.textPrimary;

  /// Paper color (white) - for backgrounds
  static Color get paper => _colors.surface;

  /// Light ink color - for subtle borders, dividers
  static Color get inkLight => _colors.borderLight;

  /// Muted ink color - for secondary text, descriptions
  static Color get inkMuted => _colors.textSecondary;

  /// Shadow color
  static Color get shadowColor => _colors.shadow;

  // ============================================
  // Borders
  // ============================================

  /// Standard border width for editorial elements
  static const double borderWidth = 2.0;

  /// Thin border width for dividers
  static const double borderWidthThin = 1.0;

  /// Standard border side
  static BorderSide get border => BorderSide(color: ink, width: borderWidth);

  /// Thin border side (for dividers between items)
  static BorderSide get borderThin => BorderSide(color: inkLight, width: borderWidthThin);

  /// Full border for containers
  static Border get fullBorder => Border.all(color: ink, width: borderWidth);

  // ============================================
  // Shadows (sharp offset, editorial style)
  // ============================================

  /// Standard card shadow (8px offset)
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: shadowColor,
      offset: const Offset(8, 8),
      blurRadius: 0,
    ),
  ];

  /// Small card shadow (6px offset)
  static List<BoxShadow> get cardShadowSmall => [
    BoxShadow(
      color: shadowColor,
      offset: const Offset(6, 6),
      blurRadius: 0,
    ),
  ];

  /// Subtle shadow (4px offset)
  static List<BoxShadow> get cardShadowSubtle => [
    BoxShadow(
      color: shadowColor.withValues(alpha: 0.08),
      offset: const Offset(4, 4),
      blurRadius: 0,
    ),
  ];

  // ============================================
  // Typography
  // ============================================

  /// Get the serif font family from brand config
  static String? get _serifFontFamily =>
      BrandLoader().config.typography.defaultSerifFont.getFontFamily();

  /// Large headline (32px) - for screen titles
  static TextStyle get headline => TextStyle(
    fontFamily: _serifFontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w400,
    color: ink,
    letterSpacing: -0.5,
    height: 1.2,
  );

  /// Medium headline (28px) - for section titles
  static TextStyle get headlineMedium => TextStyle(
    fontFamily: _serifFontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w400,
    color: ink,
    height: 1.25,
  );

  /// Small headline (24px) - for card titles
  static TextStyle get headlineSmall => TextStyle(
    fontFamily: _serifFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w400,
    color: ink,
    height: 1.3,
  );

  /// Question text (22px) - for quiz questions
  static TextStyle get questionText => TextStyle(
    fontFamily: _serifFontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w400,
    color: ink,
    height: 1.35,
  );

  /// Statement text (20px, italic) - for affirmation statements
  static TextStyle get statementText => TextStyle(
    fontFamily: _serifFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    color: ink,
    height: 1.4,
  );

  /// Body text (16px) - for descriptions
  static TextStyle get bodyText => TextStyle(
    fontFamily: _serifFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: ink,
    height: 1.5,
  );

  /// Body text italic - for hints, descriptions
  static TextStyle get bodyTextItalic => TextStyle(
    fontFamily: _serifFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    color: inkMuted,
    height: 1.5,
  );

  /// Small body text (14px) - for option text
  static TextStyle get bodySmall => TextStyle(
    fontFamily: _serifFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: ink,
    height: 1.4,
  );

  /// Uppercase label (11px) - for badges, section headers
  static TextStyle get labelUppercase => TextStyle(
    fontFamily: _serifFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    color: ink,
  );

  /// Small uppercase label (10px) - for card labels
  static TextStyle get labelUppercaseSmall => TextStyle(
    fontFamily: _serifFontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    color: inkMuted,
  );

  /// Counter text (13px bold) - for "3 of 10"
  static TextStyle get counterText => TextStyle(
    fontFamily: _serifFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: ink,
  );

  /// Score large (48px bold) - for result scores
  static TextStyle get scoreLarge => TextStyle(
    fontFamily: _serifFontFamily,
    fontSize: 48,
    fontWeight: FontWeight.w700,
    color: ink,
  );

  /// Score medium (24px) - for stat values
  static TextStyle get scoreMedium => TextStyle(
    fontFamily: _serifFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: ink,
  );

  // ============================================
  // Spacing
  // ============================================

  /// Standard padding for screen content
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 20);

  /// Header padding
  static const EdgeInsets headerPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 14);

  /// Card padding
  static const EdgeInsets cardPadding = EdgeInsets.all(20);

  /// Compact card padding
  static const EdgeInsets cardPaddingCompact = EdgeInsets.symmetric(horizontal: 16, vertical: 14);

  /// Footer padding
  static const EdgeInsets footerPadding = EdgeInsets.all(16);

  // ============================================
  // Button styles
  // ============================================

  /// Primary button decoration (filled black)
  static BoxDecoration get primaryButtonDecoration => BoxDecoration(
    color: ink,
    border: fullBorder,
  );

  /// Secondary button decoration (outlined)
  static BoxDecoration get secondaryButtonDecoration => BoxDecoration(
    color: paper,
    border: fullBorder,
  );

  /// Primary button text style
  static TextStyle get primaryButtonText => TextStyle(
    fontFamily: _serifFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 1,
    color: paper,
  );

  /// Secondary button text style
  static TextStyle get secondaryButtonText => TextStyle(
    fontFamily: _serifFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 1,
    color: ink,
  );

  /// Disabled button decoration
  static BoxDecoration get disabledButtonDecoration => BoxDecoration(
    color: _colors.disabled,
    border: Border.all(color: _colors.disabled, width: borderWidth),
  );

  /// Disabled button text style
  static TextStyle get disabledButtonText => TextStyle(
    fontFamily: _serifFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 1,
    color: inkMuted,
  );
}

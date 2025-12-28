import 'package:flutter/material.dart';

/// Brand-specific color palette
///
/// Each brand defines its own colors. The color system uses semantic naming
/// to ensure consistent usage across the app regardless of the actual colors.
class BrandColors {
  // Primary palette
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color background;
  final Color surface;

  // Text hierarchy
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnPrimary;

  // Accent colors
  final Color accentGreen;
  final Color accentOrange;

  // UI elements
  final Color border;
  final Color borderLight;
  final Color divider;
  final Color shadow;
  final Color overlay;

  // Semantic colors
  final Color success;
  final Color error;
  final Color warning;
  final Color info;

  // Interactive states
  final Color disabled;
  final Color highlight;
  final Color selected;

  // Brand-specific gradients (optional - defaults to solid colors)
  final List<Color>? _backgroundGradientColors;
  final List<Color>? _accentGradientColors;
  final List<Color>? _progressGradientColors;

  // Glow effects (optional - for brands with glow styling)
  final Color? glowPrimary;
  final Color? glowSecondary;

  // Card-specific colors (optional - defaults to surface/primary)
  final Color? cardBackground;
  final Color? cardBackgroundDark;
  final Color? ribbonBackground;

  const BrandColors({
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnPrimary,
    required this.accentGreen,
    required this.accentOrange,
    required this.border,
    required this.borderLight,
    required this.divider,
    required this.shadow,
    required this.overlay,
    required this.success,
    required this.error,
    required this.warning,
    required this.info,
    required this.disabled,
    required this.highlight,
    required this.selected,
    // Optional gradient/glow properties
    List<Color>? backgroundGradientColors,
    List<Color>? accentGradientColors,
    List<Color>? progressGradientColors,
    this.glowPrimary,
    this.glowSecondary,
    this.cardBackground,
    this.cardBackgroundDark,
    this.ribbonBackground,
  })  : _backgroundGradientColors = backgroundGradientColors,
        _accentGradientColors = accentGradientColors,
        _progressGradientColors = progressGradientColors;

  /// Computed gradients
  /// Uses custom gradient colors if provided, otherwise defaults to solid colors.
  LinearGradient get primaryGradient => LinearGradient(
    colors: [primary, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Background gradient (vertical, top to bottom)
  /// Us 2.0: Peach gradient. Others: Solid background color.
  LinearGradient get backgroundGradient => LinearGradient(
    colors: _backgroundGradientColors ?? [background, background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Accent gradient (horizontal, for connection bar, buttons)
  /// Us 2.0: Pink to orange. Others: Solid primary color.
  LinearGradient get accentGradient => LinearGradient(
    colors: _accentGradientColors ?? [primary, primary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Progress gradient (horizontal, for progress bars)
  /// Us 2.0: Pink to orange with white. Others: Solid accent.
  LinearGradient get progressGradient => LinearGradient(
    colors: _progressGradientColors ?? [accentGreen, accentGreen],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Whether this brand uses gradient styling
  bool get hasGradientStyling =>
      _backgroundGradientColors != null ||
      _accentGradientColors != null ||
      glowPrimary != null;

  /// Get card background with fallback
  Color get effectiveCardBackground => cardBackground ?? surface;

  /// Get card background dark with fallback
  Color get effectiveCardBackgroundDark => cardBackgroundDark ?? primary;

  /// Get ribbon background with fallback
  Color get effectiveRibbonBackground => ribbonBackground ?? highlight;
}

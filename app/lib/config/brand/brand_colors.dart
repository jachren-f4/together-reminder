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
  });

  /// Computed gradients (matching current AppTheme pattern)
  /// Solid color gradients for consistency with current design
  LinearGradient get primaryGradient => LinearGradient(
    colors: [primary, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  LinearGradient get backgroundGradient => LinearGradient(
    colors: [background, background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

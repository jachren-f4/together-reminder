import 'package:togetherremind/config/theme_config.dart';

/// Brand-specific typography configuration
///
/// Each brand can specify its preferred fonts. The existing ThemeConfig
/// system handles the actual font rendering.
class BrandTypography {
  /// Default serif font for headlines
  final SerifFont defaultSerifFont;

  /// Body font family name (e.g., 'Inter', 'Roboto')
  final String bodyFontFamily;

  const BrandTypography({
    required this.defaultSerifFont,
    required this.bodyFontFamily,
  });
}

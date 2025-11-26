import 'brand_colors.dart';
import 'brand_typography.dart';
import 'brand_assets.dart';
import 'content_paths.dart';
import 'firebase_config.dart';

/// Enumeration of all supported brands
///
/// Each brand corresponds to a separate App Store listing with
/// distinct content, visuals, and backend configuration.
enum Brand {
  togetherRemind,
  holyCouples,
  // Future brands:
  // spicyCouples,
}

/// Complete brand configuration
///
/// This class combines all brand-specific settings into a single
/// configuration object. Each brand has its own instance defined
/// in the BrandRegistry.
class BrandConfig {
  // ============================================
  // Identity
  // ============================================

  /// Brand identifier (used in code and asset paths)
  final Brand brand;

  /// Display name shown to users
  final String appName;

  /// App tagline/subtitle
  final String appTagline;

  /// Android bundle identifier
  final String bundleIdAndroid;

  /// iOS bundle identifier
  final String bundleIdIOS;

  // ============================================
  // Visual Design
  // ============================================

  /// Color palette for this brand
  final BrandColors colors;

  /// Typography configuration
  final BrandTypography typography;

  /// Asset paths
  final BrandAssets assets;

  // ============================================
  // Content
  // ============================================

  /// Paths to JSON content files
  final ContentPaths content;

  // ============================================
  // Backend
  // ============================================

  /// Firebase project configuration
  final BrandFirebaseConfig firebase;

  /// API base URL (for Supabase/Next.js API)
  final String apiBaseUrl;

  const BrandConfig({
    required this.brand,
    required this.appName,
    required this.appTagline,
    required this.bundleIdAndroid,
    required this.bundleIdIOS,
    required this.colors,
    required this.typography,
    required this.assets,
    required this.content,
    required this.firebase,
    required this.apiBaseUrl,
  });

  /// Get the brand ID string (for asset paths, etc.)
  String get brandId {
    switch (brand) {
      case Brand.togetherRemind:
        return 'togetherremind';
      case Brand.holyCouples:
        return 'holycouples';
    }
  }
}

import 'package:flutter/material.dart';
import 'package:togetherremind/config/theme_config.dart';
import 'brand_config.dart';
import 'brand_colors.dart';
import 'brand_typography.dart';
import 'brand_assets.dart';
import 'content_paths.dart';
import 'firebase_config.dart';

/// Registry of all brand configurations
///
/// This class contains the static definitions for each supported brand.
/// To add a new brand:
/// 1. Add the brand to the Brand enum in brand_config.dart
/// 2. Create a static const definition below
/// 3. Add it to the _brands map
class BrandRegistry {
  /// Get configuration for a specific brand
  static BrandConfig get(Brand brand) {
    final config = _brands[brand];
    if (config == null) {
      throw ArgumentError('No configuration found for brand: ${brand.name}');
    }
    return config;
  }

  /// Map of all brand configurations
  static final Map<Brand, BrandConfig> _brands = {
    Brand.togetherRemind: _togetherRemindConfig,
  };

  // ========================================
  // TogetherRemind (Original Brand)
  // ========================================

  static final _togetherRemindConfig = BrandConfig(
    brand: Brand.togetherRemind,
    appName: 'TogetherRemind',
    appTagline: 'Stay connected with your partner',
    bundleIdAndroid: 'com.togetherremind.togetherremind',
    bundleIdIOS: 'com.togetherremind.togetherremind2',
    colors: const BrandColors(
      // Primary palette (from current AppTheme)
      primary: Color(0xFF1A1A1A),        // primaryBlack
      primaryLight: Color(0xFF3A3A3A),
      primaryDark: Color(0xFF000000),
      background: Color(0xFFFAFAFA),      // backgroundGray
      surface: Color(0xFFFFFEFD),         // primaryWhite / cardBackground

      // Text hierarchy
      textPrimary: Color(0xFF1A1A1A),     // primaryBlack
      textSecondary: Color(0xFF6E6E6E),
      textTertiary: Color(0xFFAAAAAA),
      textOnPrimary: Color(0xFFFFFEFD),   // primaryWhite

      // Accent colors (legacy)
      accentGreen: Color(0xFF22c55e),
      accentOrange: Color(0xFFf59e0b),

      // UI elements
      border: Color(0xFF1A1A1A),
      borderLight: Color(0xFFF0F0F0),
      divider: Color(0xFFE5E5E5),
      shadow: Color(0x26000000),          // black with 15% opacity
      overlay: Color(0x80000000),         // black with 50% opacity

      // Semantic colors
      success: Color(0xFF22c55e),         // green
      error: Color(0xFFef4444),           // red
      warning: Color(0xFFf59e0b),         // orange
      info: Color(0xFF3b82f6),            // blue

      // Interactive states
      disabled: Color(0xFFCCCCCC),
      highlight: Color(0xFFF5F5F5),
      selected: Color(0xFFE8E8E8),
    ),
    typography: const BrandTypography(
      defaultSerifFont: SerifFont.georgia,
      bodyFontFamily: 'Inter',
    ),
    assets: const BrandAssets('togetherremind'),
    content: const ContentPaths('togetherremind'),
    firebase: const BrandFirebaseConfig(
      projectId: 'togetherremind',
      storageBucket: 'togetherremind.firebasestorage.app',
      databaseURL: 'https://togetherremind-default-rtdb.firebaseio.com',
      messagingSenderId: '725871129285',
      // Android
      androidApiKey: 'AIzaSyDpkSTQ6PwEYtKQuzMe_GJt6x2fESNGM04',
      androidAppId: '1:725871129285:android:fbf78b68b07590f327f6ac',
      // iOS
      iosApiKey: 'AIzaSyBolavJ_1dNiEZ42dLd7OmANLCcKTvyPJg',
      iosAppId: '1:725871129285:ios:9b09ef0e56448b1727f6ac',
      iosBundleId: 'com.togetherremind.togetherremind',
      // Web
      webApiKey: 'AIzaSyCh97osauFB0ljuBr5MU5QfHX6Zx3XOZ80',
      webAppId: '1:725871129285:web:5c82d5e18390e80c27f6ac',
      webAuthDomain: 'togetherremind.firebaseapp.com',
    ),
    apiBaseUrl: 'https://api.togetherremind.com',
  );

  // ========================================
  // Holy Couples (Future Brand - Template)
  // ========================================
  // Uncomment and customize when ready to add this brand
  /*
  static final _holyCouplesConfig = BrandConfig(
    brand: Brand.holyCouples,
    appName: 'Holy Couples',
    appTagline: 'Grow together in faith and love',
    bundleIdAndroid: 'com.togetherremind.holycouples',
    bundleIdIOS: 'com.togetherremind.holycouples',
    colors: const BrandColors(
      primary: Color(0xFF4A5568),        // Warm slate gray
      primaryLight: Color(0xFF718096),
      primaryDark: Color(0xFF2D3748),
      background: Color(0xFFFAF9F7),     // Warm cream
      surface: Color(0xFFFFFFF0),        // Ivory

      textPrimary: Color(0xFF2D3748),
      textSecondary: Color(0xFF718096),
      textTertiary: Color(0xFFA0AEC0),
      textOnPrimary: Color(0xFFFFFFF0),

      accentGreen: Color(0xFF38A169),
      accentOrange: Color(0xFFD69E2E),   // Gold

      border: Color(0xFF4A5568),
      borderLight: Color(0xFFE2E8F0),
      divider: Color(0xFFE2E8F0),
      shadow: Color(0x26000000),
      overlay: Color(0x80000000),

      success: Color(0xFF38A169),
      error: Color(0xFFE53E3E),
      warning: Color(0xFFD69E2E),
      info: Color(0xFF3182CE),

      disabled: Color(0xFFCBD5E0),
      highlight: Color(0xFFF7FAFC),
      selected: Color(0xFFEDF2F7),
    ),
    typography: const BrandTypography(
      defaultSerifFont: SerifFont.libreBaskerville,
      bodyFontFamily: 'Inter',
    ),
    assets: const BrandAssets('holycouples'),
    content: const ContentPaths('holycouples'),
    firebase: const BrandFirebaseConfig(
      // TODO: Set up separate Firebase project for Holy Couples
      projectId: 'holycouples-prod',
      storageBucket: 'holycouples-prod.firebasestorage.app',
      databaseURL: 'https://holycouples-prod-default-rtdb.firebaseio.com',
      messagingSenderId: 'TODO',
      androidApiKey: 'TODO',
      androidAppId: 'TODO',
      iosApiKey: 'TODO',
      iosAppId: 'TODO',
      iosBundleId: 'com.togetherremind.holycouples',
      webApiKey: 'TODO',
      webAppId: 'TODO',
      webAuthDomain: 'holycouples-prod.firebaseapp.com',
    ),
    apiBaseUrl: 'https://api.holycouples.com',
  );
  */
}

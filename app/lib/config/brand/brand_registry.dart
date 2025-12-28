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
    Brand.holyCouples: _holyCouplesConfig,
    Brand.us2: _us2Config,
  };

  // ========================================
  // TogetherRemind (Original Brand)
  // ========================================

  static final _togetherRemindConfig = BrandConfig(
    brand: Brand.togetherRemind,
    appName: 'Liia',
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
    supabaseUrl: 'https://naqzdqdncdzxpxbdysgq.supabase.co',
    supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5hcXpkcWRuY2R6eHB4YmR5c2dxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzI2MjM1MTAsImV4cCI6MjA0ODE5OTUxMH0.placeholder', // TODO: Replace with real key
  );

  // ========================================
  // Holy Couples (Test Brand)
  // ========================================
  // Uses TogetherRemind Firebase for testing multi-brand system
  // TODO: Create separate Firebase project when ready for production

  static final _holyCouplesConfig = BrandConfig(
    brand: Brand.holyCouples,
    appName: 'Holy Couples',
    appTagline: 'Grow together in faith and love',
    bundleIdAndroid: 'com.togetherremind.holycouples',
    bundleIdIOS: 'com.togetherremind.holycouples',
    colors: const BrandColors(
      // Deep blue/purple spiritual palette
      primary: Color(0xFF4338CA),        // Indigo-700
      primaryLight: Color(0xFF6366F1),   // Indigo-500
      primaryDark: Color(0xFF312E81),    // Indigo-900
      background: Color(0xFFFAF5FF),     // Soft lavender
      surface: Color(0xFFFFFBF0),        // Warm ivory

      textPrimary: Color(0xFF1E1B4B),    // Indigo-950
      textSecondary: Color(0xFF6B7280),  // Gray-500
      textTertiary: Color(0xFF9CA3AF),   // Gray-400
      textOnPrimary: Color(0xFFFFFBF0),  // Warm ivory

      accentGreen: Color(0xFF059669),    // Emerald-600
      accentOrange: Color(0xFFD97706),   // Amber-600 (gold)

      border: Color(0xFF4338CA),         // Indigo-700
      borderLight: Color(0xFFE5E7EB),    // Gray-200
      divider: Color(0xFFE5E7EB),        // Gray-200
      shadow: Color(0x26312E81),         // Indigo shadow
      overlay: Color(0x80312E81),        // Indigo overlay

      success: Color(0xFF059669),        // Emerald-600
      error: Color(0xFFDC2626),          // Red-600
      warning: Color(0xFFD97706),        // Amber-600
      info: Color(0xFF4338CA),           // Indigo-700

      disabled: Color(0xFFD1D5DB),       // Gray-300
      highlight: Color(0xFFF5F3FF),      // Violet-50
      selected: Color(0xFFEDE9FE),       // Violet-100
    ),
    typography: const BrandTypography(
      defaultSerifFont: SerifFont.libreBaskerville,
      bodyFontFamily: 'Inter',
    ),
    assets: const BrandAssets('holycouples'),
    content: const ContentPaths('holycouples'),
    // Using TogetherRemind Firebase for testing (will be separate in production)
    firebase: const BrandFirebaseConfig(
      projectId: 'togetherremind',
      storageBucket: 'togetherremind.firebasestorage.app',
      databaseURL: 'https://togetherremind-default-rtdb.firebaseio.com',
      messagingSenderId: '725871129285',
      androidApiKey: 'AIzaSyDpkSTQ6PwEYtKQuzMe_GJt6x2fESNGM04',
      androidAppId: '1:725871129285:android:fbf78b68b07590f327f6ac',
      iosApiKey: 'AIzaSyBolavJ_1dNiEZ42dLd7OmANLCcKTvyPJg',
      iosAppId: '1:725871129285:ios:9b09ef0e56448b1727f6ac',
      iosBundleId: 'com.togetherremind.holycouples',
      webApiKey: 'AIzaSyCh97osauFB0ljuBr5MU5QfHX6Zx3XOZ80',
      webAppId: '1:725871129285:web:5c82d5e18390e80c27f6ac',
      webAuthDomain: 'togetherremind.firebaseapp.com',
    ),
    apiBaseUrl: 'https://api.togetherremind.com', // Using same API for testing
    // Using TogetherRemind Supabase for testing (create separate project for production)
    supabaseUrl: 'https://naqzdqdncdzxpxbdysgq.supabase.co',
    supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5hcXpkcWRuY2R6eHB4YmR5c2dxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzI2MjM1MTAsImV4cCI6MjA0ODE5OTUxMH0.placeholder', // TODO: Replace with real key for production
  );

  // ========================================
  // Us 2.0 (Warm Coral/Pink Brand)
  // ========================================
  // Warm, inviting coral/pink palette with gradient styling
  // Features glow effects, sparkle animations, gradient backgrounds

  static final _us2Config = BrandConfig(
    brand: Brand.us2,
    appName: 'Us 2.0',
    appTagline: 'Grow closer together',
    bundleIdAndroid: 'com.togetherremind.us2',
    bundleIdIOS: 'com.togetherremind.us2',
    colors: const BrandColors(
      // Warm coral/pink palette (from HTML mockup)
      primary: Color(0xFFFF5E62),        // Primary brand pink
      primaryLight: Color(0xFFFF6B6B),   // Gradient accent start
      primaryDark: Color(0xFFFF9F43),    // Gradient accent end (orange)
      background: Color(0xFFFFF5F0),     // Light peach
      surface: Color(0xFFFFF8F0),        // Cream

      textPrimary: Color(0xFF2D2D2D),    // Dark gray (near black)
      textSecondary: Color(0xFF6B6B6B),  // Medium gray
      textTertiary: Color(0xFF9B9B9B),   // Light gray
      textOnPrimary: Color(0xFFFFFFFF),  // White

      accentGreen: Color(0xFF22C55E),    // Green for success states
      accentOrange: Color(0xFFFF9F43),   // Orange (matches gradient end)

      border: Color(0xFFFF5E62),         // Brand pink
      borderLight: Color(0xFFFFE4DB),    // Light peach
      divider: Color(0xFFF0E8E4),        // Warm gray
      shadow: Color(0x26FF5E62),         // Pink shadow (15% opacity)
      overlay: Color(0x80000000),        // Black overlay

      success: Color(0xFF22C55E),        // Green
      error: Color(0xFFEF4444),          // Red
      warning: Color(0xFFF59E0B),        // Amber
      info: Color(0xFFFF5E62),           // Brand pink

      disabled: Color(0xFFD4D4D4),       // Gray
      highlight: Color(0xFFFFF5F0),      // Light peach
      selected: Color(0xFFFFE4DB),       // Peach

      // Us 2.0 specific gradients (from HTML CSS variables)
      backgroundGradientColors: [
        Color(0xFFFFD1C1),  // --bg-gradient-start: peach
        Color(0xFFFFF5F0),  // --bg-gradient-end: light peach
      ],
      accentGradientColors: [
        Color(0xFFFF6B6B),  // --gradient-accent-start: pink
        Color(0xFFFF9F43),  // --gradient-accent-end: orange
      ],
      progressGradientColors: [
        Color(0xFFFFFFFF),  // White start
        Color(0xFFFFF8F0),  // Cream end
      ],

      // Glow effects
      glowPrimary: Color(0xCCFF6B6B),    // Pink glow (80% opacity)
      glowSecondary: Color(0x99FF9F43),  // Orange glow (60% opacity)

      // Card-specific colors
      cardBackground: Color(0xFFFF7B6B), // --card-salmon
      cardBackgroundDark: Color(0xFFFF6B5B), // Darker salmon
      ribbonBackground: Color(0xFFF5E6D8), // --beige
    ),
    typography: const BrandTypography(
      defaultSerifFont: SerifFont.georgia,
      bodyFontFamily: 'Inter',
    ),
    assets: const BrandAssets('us2'),
    content: const ContentPaths('us2'),
    // Using TogetherRemind Firebase for testing (will be separate in production)
    firebase: const BrandFirebaseConfig(
      projectId: 'togetherremind',
      storageBucket: 'togetherremind.firebasestorage.app',
      databaseURL: 'https://togetherremind-default-rtdb.firebaseio.com',
      messagingSenderId: '725871129285',
      androidApiKey: 'AIzaSyDpkSTQ6PwEYtKQuzMe_GJt6x2fESNGM04',
      androidAppId: '1:725871129285:android:fbf78b68b07590f327f6ac',
      iosApiKey: 'AIzaSyBolavJ_1dNiEZ42dLd7OmANLCcKTvyPJg',
      iosAppId: '1:725871129285:ios:9b09ef0e56448b1727f6ac',
      iosBundleId: 'com.togetherremind.us2',
      webApiKey: 'AIzaSyCh97osauFB0ljuBr5MU5QfHX6Zx3XOZ80',
      webAppId: '1:725871129285:web:5c82d5e18390e80c27f6ac',
      webAuthDomain: 'togetherremind.firebaseapp.com',
    ),
    apiBaseUrl: 'https://api.togetherremind.com', // Using same API for testing
    supabaseUrl: 'https://naqzdqdncdzxpxbdysgq.supabase.co',
    supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5hcXpkcWRuY2R6eHB4YmR5c2dxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzI2MjM1MTAsImV4cCI6MjA0ODE5OTUxMH0.placeholder', // TODO: Replace with real key for production
  );
}

/// Brand-specific asset paths
///
/// Each brand has its own directory of assets. This class provides
/// type-safe access to asset paths.
class BrandAssets {
  final String _brandId;

  const BrandAssets(this._brandId);

  /// Base path for this brand's assets
  String get _brandPath => 'assets/brands/$_brandId';

  // ============================================
  // Animations (brand-specific)
  // ============================================

  String get pokeSendAnimation => '$_brandPath/animations/poke_send.json';
  String get pokeReceiveAnimation => '$_brandPath/animations/poke_receive.json';
  String get pokeMutualAnimation => '$_brandPath/animations/poke_mutual.json';

  // ============================================
  // Images
  // ============================================

  String get questImagesPath => '$_brandPath/images/quests';
  String questImage(String imageName) => '$questImagesPath/$imageName';

  // ============================================
  // Shared assets (same for all brands)
  // ============================================

  static const String sharedSoundsPath = 'assets/shared/sounds';
  static const String sharedAnimationsPath = 'assets/shared/animations';
  static const String sharedGfxPath = 'assets/shared/gfx';

  // Navigation icons (shared)
  static const String homeIcon = '$sharedGfxPath/home.png';
  static const String homeIconFilled = '$sharedGfxPath/home_filled.png';
  static const String activitiesIcon = '$sharedGfxPath/activities.png';
  static const String activitiesIconFilled = '$sharedGfxPath/activities_filled.png';
  static const String inboxIcon = '$sharedGfxPath/inbox.png';
  static const String inboxIconFilled = '$sharedGfxPath/inbox_filled.png';
  static const String profileIcon = '$sharedGfxPath/profile.png';
  static const String profileIconFilled = '$sharedGfxPath/profile_filled.png';
  static const String settingsIcon = '$sharedGfxPath/settings.png';
  static const String settingsIconFilled = '$sharedGfxPath/settings_filled.png';
}

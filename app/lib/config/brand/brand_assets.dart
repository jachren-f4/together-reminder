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

  // ============================================
  // Sound assets (shared)
  // ============================================

  /// Get path to a sound file
  /// [soundId] format: 'category/filename' (without extension)
  /// Example: 'ui/tap_soft' -> 'assets/shared/sounds/ui/tap_soft.mp3'
  static String soundPath(String soundId) => '$sharedSoundsPath/$soundId.mp3';

  // UI sounds
  static String get tapSoftSound => soundPath('ui/tap_soft');
  static String get tapLightSound => soundPath('ui/tap_light');
  static String get toggleOnSound => soundPath('ui/toggle_on');
  static String get toggleOffSound => soundPath('ui/toggle_off');

  // Celebration sounds
  static String get confettiBurstSound => soundPath('celebration/confetti_burst');
  static String get sparkleSound => soundPath('celebration/sparkle');
  static String get chimeSuccessSound => soundPath('celebration/chime_success');

  // Feedback sounds
  static String get successSound => soundPath('feedback/success');
  static String get errorSound => soundPath('feedback/error');
  static String get warningSound => soundPath('feedback/warning');

  // Game sounds
  static String get cardFlipSound => soundPath('games/card_flip');
  static String get matchFoundSound => soundPath('games/match_found');
  static String get wordFoundSound => soundPath('games/word_found');
  static String get letterTypeSound => soundPath('games/letter_type');
  static String get answerSelectSound => soundPath('games/answer_select');

  // Navigation icons (shared)
  static const String homeIcon = '$sharedGfxPath/home.png';
  static const String homeIconFilled = '$sharedGfxPath/home_filled.png';
  static const String activitiesIcon = '$sharedGfxPath/activities.png';
  static const String activitiesIconFilled = '$sharedGfxPath/activities_filled.png';

  // Journal icons (coral notebook with heart)
  static const String journalIcon = '$sharedGfxPath/journal.png';
  static const String journalIconFilled = '$sharedGfxPath/journal_filled.png';

  // Legacy inbox icons - deprecated, use journal icons instead
  @Deprecated('Use journalIcon instead')
  static const String inboxIcon = '$sharedGfxPath/inbox.png';
  @Deprecated('Use journalIconFilled instead')
  static const String inboxIconFilled = '$sharedGfxPath/inbox_filled.png';

  static const String profileIcon = '$sharedGfxPath/profile.png';
  static const String profileIconFilled = '$sharedGfxPath/profile_filled.png';
  static const String settingsIcon = '$sharedGfxPath/settings.png';
  static const String settingsIconFilled = '$sharedGfxPath/settings_filled.png';
}

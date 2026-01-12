/// RevenueCat configuration for in-app purchases
///
/// API keys are public and safe to include in client code.
/// They can only be used to fetch offerings and make purchases - not for admin operations.
class RevenueCatConfig {
  RevenueCatConfig._();

  /// iOS public API key from RevenueCat dashboard
  /// Found at: RevenueCat > Project > API Keys > Us 2.0 (App Store)
  static const String iosApiKey = 'appl_uMIdJjxUexRmzWrJQEoohTzaIEK';

  /// Android public API key from RevenueCat dashboard (for future use)
  static const String androidApiKey = 'PASTE_YOUR_ANDROID_API_KEY_HERE';

  /// Entitlement identifier for premium access
  /// Must match the entitlement ID in RevenueCat dashboard
  static const String premiumEntitlement = 'Us 2.0 Pro';

  /// Default offering identifier
  static const String defaultOffering = 'default';

  /// Product identifiers
  static const String weeklyProductId = 'weekly';
  static const String monthlyProductId = 'us2_premium_monthly';

  /// Check if RevenueCat is configured
  static bool get isConfigured =>
      iosApiKey.isNotEmpty &&
      !iosApiKey.contains('PASTE');
}

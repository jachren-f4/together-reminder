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

  /// Check if an entitlement key matches our premium entitlement
  ///
  /// RevenueCat sometimes returns entitlement names with different Unicode
  /// characters (e.g., U+2024 ONE DOT LEADER instead of U+002E FULL STOP).
  /// This method handles those variations by normalizing the comparison.
  static bool isPremiumEntitlement(String key) {
    // Normalize both strings: lowercase, remove spaces, replace common period variants
    final normalizedKey = _normalizeForComparison(key);
    final normalizedExpected = _normalizeForComparison(premiumEntitlement);

    // Direct match after normalization
    if (normalizedKey == normalizedExpected) return true;

    // Fallback: check for key parts (handles unexpected character variations)
    // "Us 2.0 Pro" normalized becomes "us20pro"
    return normalizedKey.contains('us2') &&
           normalizedKey.contains('pro') &&
           normalizedKey.length < 15; // Sanity check to avoid false positives
  }

  /// Normalize a string for comparison by:
  /// - Converting to lowercase
  /// - Removing whitespace
  /// - Replacing common period-like Unicode characters with nothing
  static String _normalizeForComparison(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '') // Remove whitespace
        .replaceAll('.', '') // ASCII period U+002E
        .replaceAll('․', '') // ONE DOT LEADER U+2024
        .replaceAll('‥', '') // TWO DOT LEADER U+2025
        .replaceAll('…', '') // HORIZONTAL ELLIPSIS U+2026
        .replaceAll('·', '') // MIDDLE DOT U+00B7
        .replaceAll('•', ''); // BULLET U+2022
  }

  /// Find the premium entitlement from a map of entitlements
  /// Returns the matching key if found, null otherwise
  static String? findPremiumEntitlementKey(Map<String, dynamic> entitlements) {
    for (final key in entitlements.keys) {
      if (isPremiumEntitlement(key)) {
        return key;
      }
    }
    return null;
  }
}

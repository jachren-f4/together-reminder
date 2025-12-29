/// Centralized app version constant
///
/// Update this when incrementing the build number in pubspec.yaml
/// Format: major.minor.patch+buildNumber
///
/// IMPORTANT: Keep this in sync with pubspec.yaml version
class AppVersion {
  /// Current app version (matches pubspec.yaml)
  static const String version = '1.0.0';

  /// Current build number (matches pubspec.yaml)
  static const int buildNumber = 29;

  /// Full version string for display
  static String get fullVersion => '$version+$buildNumber';

  /// Display version for UI (e.g., "V1.0.0 (28)")
  static String get displayVersion => 'V$version ($buildNumber)';
}

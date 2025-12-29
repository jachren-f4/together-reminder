import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available bottom navigation styles for Us 2.0 brand
enum Us2NavStyle {
  /// Default - solid icons with gradient active state
  standard,
  /// v2 - macOS dock-style with glassmorphism and magnification
  dock,
  /// v3 - pill expand with animated labels
  pill,
}

/// Service to manage the bottom navigation style preference
///
/// Extends ChangeNotifier so MainScreen can listen and rebuild when style changes.
class NavStyleService extends ChangeNotifier {
  static const String _navStyleKey = 'us2_nav_style';
  static NavStyleService? _instance;
  static Us2NavStyle _currentStyle = Us2NavStyle.pill;

  NavStyleService._();

  static NavStyleService get instance {
    _instance ??= NavStyleService._();
    return _instance!;
  }

  /// Get the current nav style
  Us2NavStyle get currentStyle => _currentStyle;

  /// Initialize the service (call during app startup)
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to pill style (index 2) if no preference saved
    final styleIndex = prefs.getInt(_navStyleKey) ?? Us2NavStyle.pill.index;
    _currentStyle = Us2NavStyle.values[styleIndex.clamp(0, Us2NavStyle.values.length - 1)];
  }

  /// Set the nav style and notify listeners
  Future<void> setStyle(Us2NavStyle style) async {
    _currentStyle = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_navStyleKey, style.index);
    notifyListeners(); // Trigger MainScreen rebuild
  }

  /// Get display name for a style
  String getStyleDisplayName(Us2NavStyle style) {
    switch (style) {
      case Us2NavStyle.standard:
        return 'Standard';
      case Us2NavStyle.dock:
        return 'Dock (macOS)';
      case Us2NavStyle.pill:
        return 'Pill Expand';
    }
  }
}

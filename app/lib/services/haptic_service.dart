import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/logger.dart';

/// Types of haptic feedback available in the app
enum HapticType {
  /// Light tap - button press, UI feedback
  light,

  /// Medium impact - selection confirmed
  medium,

  /// Heavy impact - important action, achievement
  heavy,

  /// Success pattern - medium then light (achievement unlocked)
  success,

  /// Warning pattern - double heavy (error, invalid action)
  warning,

  /// Selection click - toggle, checkbox
  selection,
}

/// Centralized haptic feedback service
///
/// Provides unified haptic patterns across the app with user preference toggle.
/// Automatically disabled on web platform.
class HapticService {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();

  static const String _prefsKey = 'haptic_enabled';
  bool _isEnabled = true;
  bool _isInitialized = false;

  /// Whether haptic feedback is currently enabled
  bool get isEnabled => _isEnabled && !kIsWeb;

  /// Initialize the service and load user preference
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final box = Hive.box('app_metadata');
      _isEnabled = box.get(_prefsKey, defaultValue: true) as bool;
      _isInitialized = true;
      Logger.debug('HapticService initialized, enabled: $_isEnabled', service: 'haptic');
    } catch (e) {
      Logger.error('Failed to initialize HapticService', error: e, service: 'haptic');
      _isEnabled = true; // Default to enabled
      _isInitialized = true;
    }
  }

  /// Set haptic feedback enabled/disabled
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    try {
      final box = Hive.box('app_metadata');
      await box.put(_prefsKey, enabled);
      Logger.debug('HapticService enabled set to: $enabled', service: 'haptic');
    } catch (e) {
      Logger.error('Failed to save haptic preference', error: e, service: 'haptic');
    }
  }

  /// Trigger haptic feedback of the specified type
  ///
  /// Does nothing if haptics are disabled or on web platform.
  Future<void> trigger(HapticType type) async {
    if (!isEnabled) return;

    try {
      switch (type) {
        case HapticType.light:
          await HapticFeedback.lightImpact();

        case HapticType.medium:
          await HapticFeedback.mediumImpact();

        case HapticType.heavy:
          await HapticFeedback.heavyImpact();

        case HapticType.success:
          // Medium then light for achievement feel
          await HapticFeedback.mediumImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.lightImpact();

        case HapticType.warning:
          // Double heavy for attention/error
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 50));
          await HapticFeedback.heavyImpact();

        case HapticType.selection:
          await HapticFeedback.selectionClick();
      }
    } catch (e) {
      // Silently fail - haptics are non-critical
      Logger.debug('Haptic feedback failed: $e', service: 'haptic');
    }
  }

  /// Convenience method for light tap feedback
  Future<void> tap() => trigger(HapticType.light);

  /// Convenience method for medium selection feedback
  Future<void> select() => trigger(HapticType.medium);

  /// Convenience method for success/achievement feedback
  Future<void> success() => trigger(HapticType.success);

  /// Convenience method for error/warning feedback
  Future<void> warning() => trigger(HapticType.warning);

  /// Convenience method for toggle/checkbox feedback
  Future<void> toggle() => trigger(HapticType.selection);

  /// Triple pulse for special moments (like mutual poke)
  Future<void> triplePulse() async {
    if (!isEnabled) return;

    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.heavyImpact();
    } catch (e) {
      Logger.debug('Triple pulse haptic failed: $e', service: 'haptic');
    }
  }
}

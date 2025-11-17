import 'package:flutter/foundation.dart';

/// Centralized logging service with level-based logging and per-service verbosity control
///
/// Usage:
/// ```dart
/// import '../utils/logger.dart';
///
/// Logger.debug('Processing data', service: 'quiz');
/// Logger.info('User logged in');
/// Logger.warn('Slow network detected');
/// Logger.error('Failed to load data', error);
/// Logger.success('Quest completed');
/// ```
class Logger {
  // Global toggle for all debug/info/success logs (respects kDebugMode)
  static const bool _enableDebug = kDebugMode;
  static const bool _enableInfo = kDebugMode;
  static const bool _enableSuccess = kDebugMode;

  // ============================================================================
  // PER-SERVICE VERBOSITY CONTROL
  // ============================================================================
  //
  // PHILOSOPHY: All services DISABLED by default to prevent log flooding
  //
  // WHY: Clean logs make debugging easier and prevent AI coding agent context
  // window pollution. Only enable the specific services you're actively working on.
  //
  // HOW TO USE:
  // 1. Find the service category you're working on below
  // 2. Change its value from `false` to `true`
  // 3. Run your debug build - only those logs will appear
  // 4. Remember: error() ALWAYS logs regardless of these settings
  //
  // EXAMPLES:
  // - Working on quiz feature? Enable 'quiz' and 'quest'
  // - Debugging Firebase sync? Enable 'storage' and 'notification'
  // - Adding new game? Enable that game's service only
  //
  // ============================================================================

  static const Map<String, bool> _serviceVerbosity = {
    // === CRITICAL CORE (Enable when debugging core infrastructure) ===
    'storage': false,           // Hive local persistence operations (20 uses)
    'notification': false,      // FCM/APNs push notifications, tokens (13 uses)
    'lovepoint': false,         // Love Points awards, tier progression (11 uses)

    // === MAJOR FEATURES (Enable when working on these features) ===
    'quiz': false,              // Classic quiz gameplay, scoring, sync (36 uses)
    'you_or_me': false,         // You or Me dual-session game (32 uses)
    'pairing': false,           // QR/Remote device pairing (19 uses - stable, rarely needed)

    // === MINOR FEATURES (Enable only when developing specific feature) ===
    'reminder': false,          // Send reminder functionality (9 uses)
    'poke': false,              // Poke send/receive interactions (7 uses)
    'daily_pulse': false,       // Daily Pulse synchronized activities (14 uses)
    'affirmation': false,       // Affirmation quiz variant (5 uses)
    'memory_flip': false,       // Memory Flip card matching game (5 uses)
    'word_ladder': false,       // Word Ladder game screens (7 uses)
    'ladder': false,            // Word Ladder service backend (2 uses - confusing name, consider consolidating)
    'quest': false,             // Daily quest sync, generation, completion, Firebase operations (47 uses)

    // === INFRASTRUCTURE/DEBUG (Rarely needed - only for deep debugging) ===
    'debug': false,             // Debug menu operations, device detection (38 uses)
    'mock': false,              // Mock data injection for testing (6 uses)
    'word_validation': false,   // Word dictionary initialization (2 uses)
    'home': false,              // Home screen operations (1 use)
    'arena': false,             // Arena/tier system (1 use)
  };

  /// Log debug information (only in debug mode)
  /// Use for detailed flow tracking and development debugging
  static void debug(String message, {String? service}) {
    if (_enableDebug && _shouldLog(service)) {
      print('🔍 ${_timestamp()} $message');
    }
  }

  /// Log informational messages (only in debug mode)
  /// Use for important app state changes that aren't errors
  static void info(String message, {String? service}) {
    if (_enableInfo && _shouldLog(service)) {
      print('ℹ️  ${_timestamp()} $message');
    }
  }

  /// Log warnings (only in debug mode)
  /// Use for recoverable issues or unexpected but handled situations
  static void warn(String message, {String? service}) {
    if (_enableDebug && _shouldLog(service)) {
      print('⚠️  ${_timestamp()} $message');
    }
  }

  /// Log errors (always logs, even in production)
  /// Use for failures, exceptions, and critical issues
  /// Optionally include error object and stack trace
  static void error(String message, {dynamic error, StackTrace? stackTrace, String? service}) {
    print('❌ ${_timestamp()} $message${error != null ? ': $error' : ''}');

    // In debug mode, print stack trace if provided
    if (kDebugMode && stackTrace != null) {
      print(stackTrace);
    }

    // TODO: In production, send to Crashlytics or remote error reporting
    // if (!kDebugMode) {
    //   FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message);
    // }
  }

  /// Log success messages (only in debug mode)
  /// Use for confirming operations completed successfully
  static void success(String message, {String? service}) {
    if (_enableSuccess && _shouldLog(service)) {
      print('✅ ${_timestamp()} $message');
    }
  }

  /// Check if logging should occur for a specific service
  /// Returns true if no service specified or if service verbosity is enabled
  static bool _shouldLog(String? service) {
    if (service == null) return true;
    return _serviceVerbosity[service] ?? true;
  }

  /// Generate timestamp string (HH:MM:SS format)
  /// Useful for debugging timing issues
  static String _timestamp() {
    final now = DateTime.now();
    final time = now.toString().split(' ')[1];
    return time.substring(0, 8); // HH:MM:SS
  }
}

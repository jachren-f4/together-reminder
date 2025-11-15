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

  // Per-service verbosity flags for focused debugging
  // Set to false to suppress debug logs for specific noisy services
  static const Map<String, bool> _serviceVerbosity = {
    'quiz': true,
    'notification': true,
    'reminder': true,
    'poke': true,
    'pairing': true,
    'storage': true,
    'ladder': true,
    'memory': true,
    'lovepoint': true,
    'quest': true,
    'affirmation': true,
    'mock': false,  // Suppress mock data logs by default
    'debug': true,
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

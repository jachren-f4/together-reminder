# Logger Service Documentation

**Location:** `lib/utils/logger.dart`
**Purpose:** Centralized logging with level-based filtering and per-service verbosity control
**Replaces:** Direct `print()` statements throughout the codebase

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Log Levels](#log-levels)
3. [Per-Service Verbosity](#per-service-verbosity)
4. [Features](#features)
5. [Migration Guide](#migration-guide)
6. [Best Practices](#best-practices)
7. [Future Enhancements](#future-enhancements)

---

## Quick Start

### Basic Usage

```dart
import '../utils/logger.dart';

// Debug information (only in debug mode)
Logger.debug('Processing quiz answers', service: 'quiz');

// Informational messages (only in debug mode)
Logger.info('User paired successfully', service: 'pairing');

// Warnings (only in debug mode)
Logger.warn('Network response slow', service: 'network');

// Errors (always logs, even in production)
Logger.error('Failed to load session', error: e, service: 'quiz');

// Success messages (only in debug mode)
Logger.success('Quest completed', service: 'quest');
```

### With Error Objects and Stack Traces

```dart
try {
  // ... some operation
} catch (e, stackTrace) {
  // Error with exception object
  Logger.error('Failed to sync data', error: e, service: 'sync');

  // Error with both exception and stack trace
  Logger.error('Critical failure', error: e, stackTrace: stackTrace, service: 'critical');
}
```

---

## Log Levels

### `Logger.debug()`
**When to use:** Detailed flow tracking, development debugging
**Visibility:** Only in debug mode (`kDebugMode`)
**Example:**
```dart
Logger.debug('Entering calculateMatchScore()', service: 'quiz');
Logger.debug('Processing ${items.length} items', service: 'data');
```

### `Logger.info()`
**When to use:** Important state changes, non-error notifications
**Visibility:** Only in debug mode (`kDebugMode`)
**Example:**
```dart
Logger.info('Firebase already initialized', service: 'init');
Logger.info('Badge already earned: $badgeName', service: 'quiz');
```

### `Logger.warn()`
**When to use:** Recoverable issues, unexpected but handled situations
**Visibility:** Only in debug mode (`kDebugMode`)
**Example:**
```dart
Logger.warn('User not found, skipping sync', service: 'sync');
Logger.warn('Network timeout, retrying...', service: 'network');
```

### `Logger.error()`
**When to use:** Failures, exceptions, critical issues
**Visibility:** **Always logs** (both debug and production)
**Example:**
```dart
Logger.error('Failed to load quiz session', error: e, service: 'quiz');
Logger.error('Critical: Cannot initialize database', error: e, stackTrace: stackTrace);
```

### `Logger.success()`
**When to use:** Confirming operations completed successfully (use sparingly)
**Visibility:** Only in debug mode (`kDebugMode`)
**Example:**
```dart
Logger.success('Quest sync completed', service: 'quest');
Logger.success('Pairing successful', service: 'pairing');
```

---

## Per-Service Verbosity

### Controlling Verbosity

Edit `lib/utils/logger.dart` to enable/disable logging for specific services:

```dart
static const Map<String, bool> _serviceVerbosity = {
  'quiz': true,           // Enable quiz service logs
  'notification': true,   // Enable notification logs
  'poke': true,          // Enable poke service logs
  'mock': false,         // Disable mock data logs (too verbose)
  'pairing': true,       // Enable pairing logs
  'storage': false,      // Disable storage logs (too verbose)
};
```

### Service Name Conventions

| Service Parameter | Files Using It |
|-------------------|----------------|
| `'quiz'` | quiz_service.dart |
| `'notification'` | notification_service.dart |
| `'reminder'` | reminder_service.dart |
| `'poke'` | poke_service.dart |
| `'pairing'` | dev_pairing_service.dart, remote_pairing_service.dart |
| `'ladder'` | ladder_service.dart |
| `'memory'` | memory_flip_service.dart |
| `'quest'` | daily_quest_service.dart, quest_sync_service.dart |
| `'lovepoint'` | love_point_service.dart |
| `'storage'` | storage_service.dart |
| `'mock'` | mock_data_service.dart |
| `'debug'` | dev_config.dart |

### Example: Focusing on Quiz Debugging

```dart
// In lib/utils/logger.dart
static const Map<String, bool> _serviceVerbosity = {
  'quiz': true,           // Enable - debugging quiz issues
  'notification': false,  // Disable - too noisy
  'poke': false,          // Disable - working fine
  'pairing': true,        // Enable - related to quiz flow
  // ... etc
};
```

Now only quiz and pairing logs will appear, making debugging easier.

---

## Features

### 1. Automatic Debug/Production Filtering

```dart
// In production (kDebugMode = false):
Logger.debug('Details');  // ❌ Not logged
Logger.info('State change');  // ❌ Not logged
Logger.warn('Issue');  // ❌ Not logged
Logger.error('Failure', error: e);  // ✅ Logged
Logger.success('Done');  // ❌ Not logged

// In debug mode (kDebugMode = true):
Logger.debug('Details');  // ✅ Logged
Logger.info('State change');  // ✅ Logged
Logger.warn('Issue');  // ✅ Logged
Logger.error('Failure', error: e);  // ✅ Logged
Logger.success('Done');  // ✅ Logged
```

### 2. Timestamps

All logs include timestamps in `HH:MM:SS` format:

```
🔍 14:32:18 Processing quiz answers
❌ 14:32:19 Failed to load session: Exception: Not found
✅ 14:32:20 Quest completed
```

Useful for debugging timing issues and performance bottlenecks.

### 3. Error Object Support

```dart
// Simple error message
Logger.error('Operation failed', service: 'quiz');
// Output: ❌ 14:32:18 Operation failed

// Error with exception object
Logger.error('Operation failed', error: e, service: 'quiz');
// Output: ❌ 14:32:18 Operation failed: Exception: Network timeout

// Error with stack trace (only shows in debug mode)
Logger.error('Critical error', error: e, stackTrace: stackTrace, service: 'quiz');
// Output: ❌ 14:32:18 Critical error: Exception: ...
//         #0  QuizService.loadSession (package:togetherremind/...)
//         #1  ...
```

### 4. Emoji Prefixes

Each log level has a distinct emoji for easy scanning:

- 🔍 `debug()` - Magnifying glass for detailed inspection
- ℹ️ `info()` - Information symbol
- ⚠️ `warn()` - Warning triangle
- ❌ `error()` - Red X for errors
- ✅ `success()` - Green checkmark for success

---

## Migration Guide

### From `print()` to `Logger`

**Before:**
```dart
print('❌ Error loading quiz: $e');
print('✅ Quiz completed successfully');
print('🔍 Debug: User ID = $userId');
```

**After:**
```dart
Logger.error('Error loading quiz', error: e, service: 'quiz');
Logger.success('Quiz completed successfully', service: 'quiz');
Logger.debug('User ID = $userId', service: 'quiz');
```

### Common Patterns

| Old Pattern | New Pattern |
|-------------|-------------|
| `print('❌ Error: $message');` | `Logger.error(message, service: 'X');` |
| `print('❌ Failed: $e');` | `Logger.error('Failed', error: e, service: 'X');` |
| `print('⚠️ Warning: $msg');` | `Logger.warn(msg, service: 'X');` |
| `print('✅ Success: $msg');` | `Logger.success(msg, service: 'X');` |
| `print('ℹ️ Info: $msg');` | `Logger.info(msg, service: 'X');` |
| `print('🔍 Debug: $msg');` | `Logger.debug(msg, service: 'X');` |

### Batch Migration Script

For migrating multiple files, a bash script can help:

```bash
#!/bin/bash
file="$1"
service="$2"

# Add import if not present
if ! grep -q "logger.dart" "$file"; then
    # Add after last import
    sed -i "/^import/a import '../utils/logger.dart';" "$file"
fi

# Replace patterns (escape special chars appropriately)
sed -i "s/print('❌ \(.*\): \$e');/Logger.error('\1', error: e, service: '$service');/g" "$file"
sed -i "s/print('⚠️  \(.*\)');/Logger.warn('\1', service: '$service');/g" "$file"
sed -i "s/print('✅ \(.*\)');/Logger.success('\1', service: '$service');/g" "$file"
# ... etc
```

---

## Best Practices

### 1. Always Specify Service Name

✅ **Good:**
```dart
Logger.error('Failed to load', error: e, service: 'quiz');
```

❌ **Bad:**
```dart
Logger.error('Failed to load', error: e);  // Missing service name
```

**Why:** Service names enable per-service verbosity control and make logs easier to filter.

### 2. Use Appropriate Log Levels

✅ **Good:**
```dart
Logger.error('Database connection failed', error: e, service: 'db');  // Real error
Logger.warn('User not found, using defaults', service: 'config');    // Recoverable issue
Logger.debug('Loop iteration $i of $total', service: 'processing');  // Detailed flow
```

❌ **Bad:**
```dart
Logger.error('User not found, using defaults');  // Not actually an error
Logger.debug('Critical database failure');        // This is an error, not debug!
```

### 3. Don't Overuse Success Logs

✅ **Good:**
```dart
// Only log completion of significant operations
Logger.success('Pairing completed', service: 'pairing');
Logger.success('Quest sync finished', service: 'quest');
```

❌ **Bad:**
```dart
// Too verbose - every small step
Logger.success('Validated input');
Logger.success('Saved to storage');
Logger.success('Updated UI');
```

### 4. Include Context in Error Messages

✅ **Good:**
```dart
Logger.error('Failed to load quiz session $sessionId', error: e, service: 'quiz');
Logger.error('Cannot sync quest completion for user $userId', error: e, service: 'quest');
```

❌ **Bad:**
```dart
Logger.error('Failed', error: e, service: 'quiz');  // Too vague
Logger.error('Error occurred');                      // No context at all
```

### 5. Use Stack Traces for Critical Errors

✅ **Good:**
```dart
try {
  await initializeDatabase();
} catch (e, stackTrace) {
  // Critical startup error - include stack trace
  Logger.error('Database initialization failed', error: e, stackTrace: stackTrace);
  rethrow;
}
```

❌ **Bad:**
```dart
try {
  final user = await loadUser();
} catch (e, stackTrace) {
  // Minor error - stack trace is overkill
  Logger.error('User not found', stackTrace: stackTrace);  // Too noisy
}
```

---

## Future Enhancements

### 1. Remote Error Reporting (Crashlytics)

The Logger is designed to integrate with Firebase Crashlytics:

```dart
static void error(String message, {dynamic error, StackTrace? stackTrace, String? service}) {
  print('❌ ${_timestamp()} $message${error != null ? ': $error' : ''}');

  // TODO: Implement remote error reporting
  if (!kDebugMode && error != null) {
    FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message);
  }
}
```

### 2. Log File Persistence

For debugging production issues, logs could be saved locally:

```dart
static void _writeToFile(String level, String message) {
  if (!kDebugMode) {
    final logFile = File('${appDocDir}/logs/${DateTime.now().toIso8601String()}.log');
    logFile.writeAsStringSync('[$level] ${_timestamp()} $message\n', mode: FileMode.append);
  }
}
```

### 3. Remote Verbosity Control

Service verbosity could be controlled remotely via Firebase Remote Config:

```dart
static Future<void> syncVerbosityFromRemoteConfig() async {
  final remoteConfig = FirebaseRemoteConfig.instance;
  await remoteConfig.fetchAndActivate();

  // Override local verbosity with remote settings
  _serviceVerbosity = remoteConfig.getString('logger_verbosity');
}
```

### 4. Log Analytics

Track error frequencies to identify problem areas:

```dart
static void error(String message, {...}) {
  // ... existing error logging

  // Track error analytics
  FirebaseAnalytics.instance.logEvent(
    name: 'app_error',
    parameters: {'service': service, 'message': message},
  );
}
```

---

## Summary

The Logger service provides:

✅ **Centralized logging** - One service for all logging needs
✅ **Environment-aware** - Auto-filters debug logs in production
✅ **Per-service control** - Disable noisy services individually
✅ **Timestamps** - Track timing and performance
✅ **Error context** - Supports error objects and stack traces
✅ **Future-ready** - Designed for Crashlytics integration

**Migration Status:** 168 of 264 print statements migrated (64% complete)
**Location:** `lib/utils/logger.dart`
**Documentation:** See CLAUDE.md section "9. Logger Service"

---

**Last Updated:** 2025-11-15

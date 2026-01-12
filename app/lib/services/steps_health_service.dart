import 'dart:io';
import 'package:health/health.dart';
import '../models/steps_data.dart';
import '../utils/logger.dart';
import 'storage_service.dart';

/// Service for integrating with Apple HealthKit to read step data.
/// This feature is iOS-only - Android users will not see the Steps Together feature.
class StepsHealthService {
  static final StepsHealthService _instance = StepsHealthService._internal();
  factory StepsHealthService() => _instance;
  StepsHealthService._internal();

  final Health _health = Health();
  final StorageService _storage = StorageService();

  bool _isInitialized = false;

  /// Check if the current platform supports Steps Together (iOS only)
  static bool get isSupported => Platform.isIOS;

  /// Initialize the health service
  Future<void> init() async {
    if (!isSupported) {
      Logger.debug('Steps feature not supported on this platform (iOS only)', service: 'steps');
      return;
    }

    if (_isInitialized) return;

    try {
      // Configure health package
      await _health.configure();
      _isInitialized = true;
      Logger.info('StepsHealthService initialized', service: 'steps');
    } catch (e, stackTrace) {
      Logger.error('Failed to initialize StepsHealthService',
          error: e, stackTrace: stackTrace, service: 'steps');
    }
  }

  /// Request permission to read step data from HealthKit
  /// Returns true if permission was granted, false otherwise
  Future<bool> requestPermission() async {
    if (!isSupported) {
      Logger.warn('Cannot request health permission on non-iOS platform', service: 'steps');
      return false;
    }

    if (!_isInitialized) {
      await init();
    }

    try {
      // Define the types we want to read
      final types = [HealthDataType.STEPS];
      final permissions = [HealthDataAccess.READ];

      // Request authorization
      final granted = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );

      if (granted) {
        Logger.success('HealthKit permission granted for steps', service: 'steps');

        // Update connection status
        var connection = _storage.getStepsConnection() ?? StepsConnection();
        connection.isConnected = true;
        connection.connectedAt = DateTime.now();
        connection.permissionDenied = false;
        await _storage.saveStepsConnection(connection);
      } else {
        Logger.warn('HealthKit permission denied', service: 'steps');

        // Mark permission as denied
        var connection = _storage.getStepsConnection() ?? StepsConnection();
        connection.permissionDenied = true;
        await _storage.saveStepsConnection(connection);
      }

      return granted;
    } catch (e, stackTrace) {
      Logger.error('Error requesting HealthKit permission',
          error: e, stackTrace: stackTrace, service: 'steps');
      return false;
    }
  }

  /// Check if HealthKit permission has been granted
  Future<bool> hasPermission() async {
    if (!isSupported) return false;
    if (!_isInitialized) await init();

    try {
      final types = [HealthDataType.STEPS];
      final permissions = [HealthDataAccess.READ];

      return await _health.hasPermissions(types, permissions: permissions) ?? false;
    } catch (e) {
      Logger.error('Error checking HealthKit permission', error: e, service: 'steps');
      return false;
    }
  }

  /// Get step count for today
  Future<int> getTodaySteps() async {
    if (!isSupported) return 0;
    if (!_isInitialized) await init();

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    return await _getStepsForRange(startOfDay, now);
  }

  /// Get step count for yesterday
  Future<int> getYesterdaySteps() async {
    if (!isSupported) return 0;
    if (!_isInitialized) await init();

    final now = DateTime.now();
    final startOfYesterday = DateTime(now.year, now.month, now.day - 1);
    final endOfYesterday = DateTime(now.year, now.month, now.day);

    return await _getStepsForRange(startOfYesterday, endOfYesterday);
  }

  /// Get step count for a specific date
  Future<int> getStepsForDate(DateTime date) async {
    if (!isSupported) return 0;
    if (!_isInitialized) await init();

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return await _getStepsForRange(startOfDay, endOfDay);
  }

  /// Internal method to get steps for a date range
  Future<int> _getStepsForRange(DateTime start, DateTime end) async {
    try {
      final steps = await _health.getTotalStepsInInterval(start, end);
      final stepCount = steps ?? 0;

      Logger.debug('Got $stepCount steps for ${start.toIso8601String()} to ${end.toIso8601String()}',
          service: 'steps');

      return stepCount;
    } catch (e, stackTrace) {
      Logger.error('Error getting steps', error: e, stackTrace: stackTrace, service: 'steps');
      return 0;
    }
  }

  /// Sync today's steps to local storage
  /// Set [skipPermissionCheck] to true when called immediately after granting permission
  /// (avoids race condition where hasPermission() returns false briefly after grant)
  Future<StepsDay?> syncTodaySteps({bool skipPermissionCheck = false}) async {
    if (!isSupported) return null;

    if (!skipPermissionCheck) {
      // Check our stored connection status first (more reliable than hasPermission())
      // iOS doesn't reliably report permission status, so we trust our stored flag
      final connection = _storage.getStepsConnection();
      if (connection == null || !connection.isConnected) {
        Logger.warn('Cannot sync steps - not connected to HealthKit', service: 'steps');
        return null;
      }
    }

    try {
      final steps = await getTodaySteps();
      final now = DateTime.now();
      final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Get or create today's step data
      var stepsDay = _storage.getStepsDay(dateKey);
      if (stepsDay == null) {
        stepsDay = StepsDay(
          dateKey: dateKey,
          userSteps: steps,
          lastSync: now,
        );
      } else {
        stepsDay.userSteps = steps;
        stepsDay.lastSync = now;
      }

      await _storage.saveStepsDay(stepsDay);
      Logger.info('Synced today\'s steps: $steps (total combined: ${stepsDay.combinedSteps})',
          service: 'steps');

      return stepsDay;
    } catch (e, stackTrace) {
      Logger.error('Error syncing today\'s steps', error: e, stackTrace: stackTrace, service: 'steps');
      return null;
    }
  }

  /// Sync yesterday's steps to local storage (for claim calculation)
  /// Set [skipPermissionCheck] to true when called immediately after granting permission
  /// (avoids race condition where hasPermission() returns false briefly after grant)
  Future<StepsDay?> syncYesterdaySteps({bool skipPermissionCheck = false}) async {
    if (!isSupported) return null;

    if (!skipPermissionCheck) {
      // Check our stored connection status first (more reliable than hasPermission())
      // iOS doesn't reliably report permission status, so we trust our stored flag
      final connection = _storage.getStepsConnection();
      if (connection == null || !connection.isConnected) {
        Logger.warn('Cannot sync yesterday\'s steps - not connected to HealthKit', service: 'steps');
        return null;
      }
    }

    try {
      final steps = await getYesterdaySteps();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final dateKey = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      // Calculate claim expiry (48 hours after end of yesterday)
      final endOfYesterday = DateTime(yesterday.year, yesterday.month, yesterday.day + 1);
      final claimExpiry = endOfYesterday.add(const Duration(hours: 48));

      // Get or create yesterday's step data
      var stepsDay = _storage.getStepsDay(dateKey);
      if (stepsDay == null) {
        stepsDay = StepsDay(
          dateKey: dateKey,
          userSteps: steps,
          lastSync: DateTime.now(),
          claimExpiresAt: claimExpiry,
        );
      } else {
        stepsDay.userSteps = steps;
        stepsDay.lastSync = DateTime.now();
        // FIX: Ensure claimExpiresAt is set even on existing entries
        // This handles the case where updatePartnerSteps() created the entry first
        if (stepsDay.claimExpiresAt == null) {
          stepsDay.claimExpiresAt = claimExpiry;
        }
      }

      // Calculate earned LP
      stepsDay.earnedLP = StepsDay.calculateLP(stepsDay.combinedSteps);

      await _storage.saveStepsDay(stepsDay);
      Logger.info('Synced yesterday\'s steps: $steps (combined: ${stepsDay.combinedSteps}, LP: ${stepsDay.earnedLP})',
          service: 'steps');

      return stepsDay;
    } catch (e, stackTrace) {
      Logger.error('Error syncing yesterday\'s steps', error: e, stackTrace: stackTrace, service: 'steps');
      return null;
    }
  }

  /// Get the current connection status
  StepsConnection getConnectionStatus() {
    return _storage.getStepsConnection() ?? StepsConnection();
  }

  /// Update partner's connection status (called from Firebase sync)
  Future<void> updatePartnerConnection({
    required bool connected,
    DateTime? connectedAt,
  }) async {
    var connection = _storage.getStepsConnection() ?? StepsConnection();
    connection.partnerConnected = connected;
    connection.partnerConnectedAt = connectedAt;
    await _storage.saveStepsConnection(connection);

    Logger.debug('Updated partner connection status: $connected', service: 'steps');
  }

  /// Update partner's steps for a specific date (called from Firebase sync)
  Future<void> updatePartnerSteps({
    required String dateKey,
    required int steps,
    required DateTime syncTime,
  }) async {
    var stepsDay = _storage.getStepsDay(dateKey);
    if (stepsDay == null) {
      // Create new entry if it doesn't exist
      // Calculate claim expiry for yesterday's date (48 hours after end of that day)
      DateTime? claimExpiry;
      if (dateKey == yesterdayDateKey) {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final endOfYesterday = DateTime(yesterday.year, yesterday.month, yesterday.day + 1);
        claimExpiry = endOfYesterday.add(const Duration(hours: 48));
      }

      stepsDay = StepsDay(
        dateKey: dateKey,
        partnerSteps: steps,
        lastSync: DateTime.now(),
        partnerLastSync: syncTime,
        claimExpiresAt: claimExpiry,
      );
    } else {
      stepsDay.partnerSteps = steps;
      stepsDay.partnerLastSync = syncTime;
      // FIX: Ensure claimExpiresAt is set for yesterday if missing
      if (dateKey == yesterdayDateKey && stepsDay.claimExpiresAt == null) {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final endOfYesterday = DateTime(yesterday.year, yesterday.month, yesterday.day + 1);
        stepsDay.claimExpiresAt = endOfYesterday.add(const Duration(hours: 48));
      }
    }

    // Recalculate earned LP
    stepsDay.earnedLP = StepsDay.calculateLP(stepsDay.combinedSteps);

    await _storage.saveStepsDay(stepsDay);
    Logger.debug('Updated partner steps for $dateKey: $steps (combined: ${stepsDay.combinedSteps})',
        service: 'steps');
  }

  /// Get today's step data (user + partner combined)
  StepsDay? getTodayStepsData() {
    return _storage.getTodaySteps();
  }

  /// Get yesterday's step data (for claiming)
  StepsDay? getYesterdayStepsData() {
    return _storage.getYesterdaySteps();
  }

  /// Check if there's a claimable reward from yesterday
  bool hasClaimableReward() {
    final yesterday = _storage.getYesterdaySteps();
    return yesterday?.canClaim ?? false;
  }

  /// Mark a day's reward as claimed
  Future<void> markAsClaimed(String dateKey, {String? claimedByUserId}) async {
    final stepsDay = _storage.getStepsDay(dateKey);
    if (stepsDay != null) {
      stepsDay.claimed = true;
      if (claimedByUserId != null) {
        stepsDay.claimedByUserId = claimedByUserId;
      }
      await _storage.updateStepsDay(stepsDay);
      Logger.success('Marked $dateKey steps reward as claimed', service: 'steps');
    }
  }

  /// Mark that the auto-claim overlay was shown for a day
  Future<void> markOverlayShown(String dateKey) async {
    final stepsDay = _storage.getStepsDay(dateKey);
    if (stepsDay != null) {
      stepsDay.overlayShownAt = DateTime.now();
      await _storage.updateStepsDay(stepsDay);
      Logger.debug('Marked $dateKey overlay as shown', service: 'steps');
    }
  }

  /// Mark a day's reward as claimed (called from server sync)
  /// Prevents double-claiming when partner claims first
  void markAsClaimedFromSync(
    String dateKey, {
    String? claimedByUserId,
    int? lpEarned,
  }) {
    final stepsDay = _storage.getStepsDay(dateKey);
    if (stepsDay != null) {
      final wasAlreadyClaimed = stepsDay.claimed;
      stepsDay.claimed = true;
      if (claimedByUserId != null) {
        stepsDay.claimedByUserId = claimedByUserId;
      }
      if (lpEarned != null) {
        stepsDay.earnedLP = lpEarned;
      }
      _storage.updateStepsDay(stepsDay);
      if (!wasAlreadyClaimed) {
        Logger.debug('Marked $dateKey as claimed from server sync (by: $claimedByUserId)', service: 'steps');
      }
    }
  }

  /// Generate a date key for a given date
  static String dateKeyFor(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get today's date key
  static String get todayDateKey => dateKeyFor(DateTime.now());

  /// Get yesterday's date key
  static String get yesterdayDateKey =>
      dateKeyFor(DateTime.now().subtract(const Duration(days: 1)));
}

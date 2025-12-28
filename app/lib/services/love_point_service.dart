import '../models/love_point_transaction.dart';
import 'storage_service.dart';
import 'general_activity_streak_service.dart';
import 'api_client.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import '../widgets/foreground_notification_banner.dart';
import '../utils/logger.dart';

class LovePointService {
  static final StorageService _storage = StorageService();
  static final ApiClient _apiClient = ApiClient();

  // BuildContext for showing foreground notifications
  static BuildContext? _appContext;

  // Callback for triggering UI updates when LP changes
  static VoidCallback? _onLPChanged;

  // Vacation Arena Thresholds
  static const Map<int, Map<String, dynamic>> arenas = {
    1: {'name': 'Cozy Cabin', 'emoji': '🏕️', 'min': 0, 'max': 1000, 'floor': 0},
    2: {
      'name': 'Beach Villa',
      'emoji': '🏖️',
      'min': 1000,
      'max': 2500,
      'floor': 1000
    },
    3: {
      'name': 'Yacht Getaway',
      'emoji': '⛵',
      'min': 2500,
      'max': 5000,
      'floor': 2500
    },
    4: {
      'name': 'Mountain Penthouse',
      'emoji': '🏔️',
      'min': 5000,
      'max': 10000,
      'floor': 5000
    },
    5: {
      'name': 'Castle Retreat',
      'emoji': '🏰',
      'min': 10000,
      'max': 999999,
      'floor': 10000
    },
  };

  /// Award Love Points to the current user (local only)
  ///
  /// NOTE: In the new server-authoritative model, LP is awarded by the server
  /// when games complete. This method is kept for local transaction tracking.
  static Future<void> awardPoints({
    required int amount,
    required String reason,
    String? relatedId,
    int multiplier = 1,
  }) async {
    try {
      final user = _storage.getUser();
      if (user == null) {
        Logger.warn('No user found, cannot award points', service: 'lovepoint');
        return;
      }

      final actualAmount = amount * multiplier;

      // Create transaction record
      final transaction = LovePointTransaction(
        id: const Uuid().v4(),
        amount: actualAmount,
        reason: reason,
        timestamp: DateTime.now(),
        relatedId: relatedId,
        multiplier: multiplier,
      );

      await _storage.saveTransaction(transaction);

      // Update user's total LP
      final newTotal = user.lovePoints + actualAmount;
      user.lovePoints = newTotal;
      user.lastActivityDate = DateTime.now();

      // Check for tier upgrade
      final newTier = _calculateTier(newTotal);
      final previousTier = user.arenaTier;

      if (newTier > previousTier) {
        user.arenaTier = newTier;
        user.floor = arenas[newTier]!['floor'] as int;
        Logger.success('Tier upgraded to ${arenas[newTier]!['name']}!', service: 'lovepoint');
      }

      // Save using the storage service to properly handle Hive transactions
      await _storage.saveUser(user);

      Logger.info('Awarded $actualAmount LP for $reason (Total: ${user.lovePoints})', service: 'lovepoint');
    } catch (e, stackTrace) {
      Logger.error('Error awarding points', error: e, stackTrace: stackTrace, service: 'lovepoint');
      rethrow;
    }
  }

  /// Calculate tier based on LP total
  static int _calculateTier(int lovePoints) {
    for (int tier = 5; tier >= 1; tier--) {
      if (lovePoints >= arenas[tier]!['min']) {
        return tier;
      }
    }
    return 1; // Default to Cabin
  }

  /// Get current tier information
  static Map<String, dynamic> getCurrentTierInfo() {
    final user = _storage.getUser();
    if (user == null) return arenas[1]!;
    return arenas[user.arenaTier]!;
  }

  /// Get next tier information (null if at max tier)
  static Map<String, dynamic>? getNextTierInfo() {
    final user = _storage.getUser();
    if (user == null || user.arenaTier >= 5) return null;
    return arenas[user.arenaTier + 1];
  }

  /// Get progress to next tier (0.0 to 1.0)
  static double getProgressToNextTier() {
    final user = _storage.getUser();
    if (user == null || user.arenaTier >= 5) return 1.0;

    final currentTier = arenas[user.arenaTier]!;
    final nextTier = arenas[user.arenaTier + 1]!;

    final currentMin = currentTier['min'] as int;
    final nextMin = nextTier['min'] as int;
    final range = nextMin - currentMin;
    final progress = user.lovePoints - currentMin;

    return (progress / range).clamp(0.0, 1.0);
  }

  /// Get floor protection amount
  static int getFloorProtection() {
    final user = _storage.getUser();
    if (user == null) return 0;
    return user.floor;
  }

  /// Check if LP can be deducted (respects floor)
  static bool canDeductPoints(int amount) {
    final user = _storage.getUser();
    if (user == null) return false;
    return (user.lovePoints - amount) >= user.floor;
  }

  /// Get LP statistics
  static Map<String, dynamic> getStats() {
    final user = _storage.getUser();
    final streakService = GeneralActivityStreakService();

    if (user == null) {
      return {
        'total': 0,
        'tier': 1,
        'floor': 0,
        'progressToNext': 0.0,
        'streak': 0,
      };
    }

    return {
      'total': user.lovePoints,
      'tier': user.arenaTier,
      'floor': user.floor,
      'progressToNext': getProgressToNextTier(),
      'currentArena': getCurrentTierInfo(),
      'nextArena': getNextTierInfo(),
      'streak': streakService.getCurrentStreak(),
    };
  }

  /// Set app context for showing foreground notifications
  static void setAppContext(BuildContext context) {
    _appContext = context;
  }

  /// Register callback for LP changes (for real-time UI updates)
  /// Use this in screens that need to update when LP changes
  static void setLPChangeCallback(VoidCallback? callback) {
    _onLPChanged = callback;
  }

  /// Trigger LP change callback (exposed for testing)
  ///
  /// This is used internally after LP sync and can be called in tests
  /// to verify callback behavior.
  @visibleForTesting
  static void notifyLPChanged() {
    _onLPChanged?.call();
  }

  // ============================================================================
  // SERVER-AUTHORITATIVE LP SYNC (Replaces Firebase RTDB)
  // ============================================================================

  /// Sync total LP from server response to local storage
  ///
  /// Call this when API returns totalLp (e.g., from game status endpoint).
  /// This ensures local Hive storage matches server state.
  static Future<void> syncTotalLP(int serverTotalLp) async {
    try {
      final user = _storage.getUser();
      if (user == null) {
        Logger.warn('No user found, cannot sync LP', service: 'lovepoint');
        return;
      }

      final localLp = user.lovePoints;
      if (localLp == serverTotalLp) {
        // Already in sync
        return;
      }

      Logger.info('Syncing LP: local=$localLp -> server=$serverTotalLp', service: 'lovepoint');

      // Update local storage to match server
      user.lovePoints = serverTotalLp;

      // Recalculate tier based on new LP
      final newTier = _calculateTier(serverTotalLp);
      if (newTier != user.arenaTier) {
        user.arenaTier = newTier;
        user.floor = arenas[newTier]!['floor'] as int;
        Logger.info('Tier updated to ${arenas[newTier]!['name']}', service: 'lovepoint');
      }

      await _storage.saveUser(user);

      // Show notification if LP increased during active session
      // Skip notification if localLp was 0 (fresh login/reinstall - just restoring state)
      final lpDiff = serverTotalLp - localLp;
      if (lpDiff > 0 && localLp > 0 && _appContext != null && _appContext!.mounted) {
        ForegroundNotificationBanner.show(
          _appContext!,
          title: 'Love Points Synced!',
          message: '+$lpDiff LP',
          emoji: '🤍',
        );
      }

      // Trigger UI update callback
      notifyLPChanged();

      Logger.success('LP synced successfully: $serverTotalLp', service: 'lovepoint');
    } catch (e, stackTrace) {
      Logger.error('Error syncing LP', error: e, stackTrace: stackTrace, service: 'lovepoint');
    }
  }

  /// Fetch LP from game status API and sync to local storage
  ///
  /// Call this on home screen load to ensure LP is up to date.
  static Future<void> fetchAndSyncFromServer() async {
    try {
      final response = await _apiClient.get('/api/sync/game/status');

      if (!response.success) {
        Logger.error('Failed to fetch game status for LP sync', service: 'lovepoint');
        return;
      }

      final data = response.data;
      if (data == null) return;

      final totalLp = data['totalLp'] as int?;
      if (totalLp != null) {
        await syncTotalLP(totalLp);
      }
    } catch (e) {
      Logger.error('Error fetching LP from server', error: e, service: 'lovepoint');
    }
  }

  // ============================================================================
  // LP DAILY RESET STATUS
  // ============================================================================

  /// Fetch LP grant status for all content types
  ///
  /// Returns which activities have already earned LP today and when reset occurs.
  /// Use this on intro screens to show accurate reward information.
  static Future<LpDailyStatus?> fetchLpStatus() async {
    try {
      final response = await _apiClient.get('/api/sync/lp/status');

      if (!response.success) {
        Logger.error('Failed to fetch LP status', service: 'lovepoint');
        return null;
      }

      final data = response.data;
      if (data == null) return null;

      return LpDailyStatus.fromJson(data);
    } catch (e) {
      Logger.error('Error fetching LP status', error: e, service: 'lovepoint');
      return null;
    }
  }

  /// Check if LP has been earned today for a specific content type
  ///
  /// Convenience method for intro screens.
  /// [contentType] should be one of: classic_quiz, affirmation_quiz, you_or_me, linked, word_search
  static Future<LpContentStatus> checkLpStatus(String contentType) async {
    final status = await fetchLpStatus();
    if (status == null) {
      // Default to showing reward (fail open)
      return LpContentStatus(
        alreadyGrantedToday: false,
        canPlayMore: true,
        resetInMs: 0,
      );
    }

    final contentStatus = status.status[contentType];
    return LpContentStatus(
      alreadyGrantedToday: contentStatus?.alreadyGrantedToday ?? false,
      canPlayMore: contentStatus?.canPlayMore ?? true,
      resetInMs: status.resetInMs,
    );
  }
}

/// LP grant status for all content types
class LpDailyStatus {
  final Map<String, LpContentTypeStatus> status;
  final int resetInMs;
  final String resetAt;

  LpDailyStatus({
    required this.status,
    required this.resetInMs,
    required this.resetAt,
  });

  factory LpDailyStatus.fromJson(Map<String, dynamic> json) {
    final statusMap = <String, LpContentTypeStatus>{};
    final rawStatus = json['status'] as Map<String, dynamic>? ?? {};

    for (final entry in rawStatus.entries) {
      statusMap[entry.key] = LpContentTypeStatus.fromJson(entry.value);
    }

    return LpDailyStatus(
      status: statusMap,
      resetInMs: json['resetInMs'] ?? 0,
      resetAt: json['resetAt'] ?? '',
    );
  }

  /// Format reset time as human-readable string (e.g., "5h 30m")
  String get resetTimeFormatted {
    if (resetInMs <= 0) return 'now';

    final hours = resetInMs ~/ (1000 * 60 * 60);
    final minutes = (resetInMs % (1000 * 60 * 60)) ~/ (1000 * 60);

    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }
}

/// Status for a single content type
class LpContentTypeStatus {
  final bool alreadyGrantedToday;
  final bool canPlayMore;

  LpContentTypeStatus({
    required this.alreadyGrantedToday,
    required this.canPlayMore,
  });

  factory LpContentTypeStatus.fromJson(Map<String, dynamic> json) {
    return LpContentTypeStatus(
      alreadyGrantedToday: json['alreadyGrantedToday'] ?? false,
      canPlayMore: json['canPlayMore'] ?? true,
    );
  }
}

/// Simple status for a specific content type (used by intro screens)
class LpContentStatus {
  final bool alreadyGrantedToday;
  final bool canPlayMore;
  final int resetInMs;

  LpContentStatus({
    required this.alreadyGrantedToday,
    required this.canPlayMore,
    required this.resetInMs,
  });

  /// Format reset time as human-readable string
  String get resetTimeFormatted {
    if (resetInMs <= 0) return 'now';

    final hours = resetInMs ~/ (1000 * 60 * 60);
    final minutes = (resetInMs % (1000 * 60 * 60)) ~/ (1000 * 60);

    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }
}

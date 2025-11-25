import '../models/love_point_transaction.dart';
import 'storage_service.dart';
import 'general_activity_streak_service.dart';
import 'api_client.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../widgets/foreground_notification_banner.dart';
import '../utils/logger.dart';
import '../config/dev_config.dart';
import 'dart:async';

class LovePointService {
  static final StorageService _storage = StorageService();
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();
  static final ApiClient _apiClient = ApiClient(); // Supabase API Client

  // BuildContext for showing foreground notifications
  static BuildContext? _appContext;

  // Callback for triggering UI updates when LP changes
  static VoidCallback? _onLPChanged;

  // Phase 4: Supabase polling for LP awards
  static Timer? _pollingTimer;
  static DateTime? _lastPollTime;
  static const Duration _pollingInterval = Duration(seconds: 10);

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

  /// Award Love Points to the current user
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
        // TODO: Show tier upgrade animation/notification in Phase 2
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
  /// DO NOT call startListeningForLPAwards() again - that creates duplicate listeners!
  static void setLPChangeCallback(VoidCallback? callback) {
    _onLPChanged = callback;
  }

  /// Award Love Points to BOTH users in a couple (for shared activities)
  /// This syncs the award to Firebase so both apps can apply it
  /// Uses relatedId as the Firebase key for atomic deduplication:
  /// - onChildAdded listener only fires ONCE per unique child path
  /// - Even if both devices write to same path, listener triggers only once
  ///
  /// PHASE 4: When useSupabaseForLovePoints is TRUE, uses Supabase-only path
  static Future<void> awardPointsToBothUsers({
    required String userId1,
    required String userId2,
    required int amount,
    required String reason,
    String? relatedId,
    int multiplier = 1,
  }) async {
    // PHASE 4: Supabase-only path (flag-gated)
    if (DevConfig.useSupabaseForLovePoints) {
      return _awardPointsToBothUsersSupabase(
        userId1: userId1,
        userId2: userId2,
        amount: amount,
        reason: reason,
        relatedId: relatedId,
        multiplier: multiplier,
      );
    }

    // OLD PATH: Firebase + Supabase dual-write (default)
    try {
      final actualAmount = amount * multiplier;

      // Generate couple ID (sorted for consistency)
      final sortedIds = [userId1, userId2]..sort();
      final coupleId = '${sortedIds[0]}_${sortedIds[1]}';

      // Use relatedId as the Firebase key for automatic deduplication
      // If relatedId is null, generate a random key (no deduplication)
      final awardKey = relatedId ?? const Uuid().v4();

      // 1. Write LP award to Firebase (Primary)
      // If both devices write to same key, Firebase onChildAdded only fires once
      await _database.child('lp_awards/$coupleId/$awardKey').set({
        'users': [userId1, userId2],
        'amount': actualAmount,
        'reason': reason,
        'relatedId': relatedId,
        'multiplier': multiplier,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      Logger.info('LP award synced to Firebase: $actualAmount LP for both users ($reason)', service: 'lovepoint');

      // 2. Write to Supabase (Secondary - Dual Write)
      _syncLPAwardToSupabase(
        awardId: awardKey,
        amount: amount,
        reason: reason,
        relatedId: relatedId,
        multiplier: multiplier,
        partnerId: userId2 == userId1 ? userId2 : (userId1 == _storage.getUser()?.id ? userId2 : userId1),
      ).catchError((e) {
        Logger.error('Supabase dual-write failed (awardLP)', error: e, service: 'lovepoint');
      });

    } catch (e) {
      Logger.error('Error syncing LP award to Firebase', error: e, service: 'lovepoint');
    }
  }

  /// Sync LP award to Supabase (Dual-Write Implementation)
  static Future<void> _syncLPAwardToSupabase({
    required String awardId,
    required int amount,
    required String reason,
    String? relatedId,
    int multiplier = 1,
    required String partnerId,
  }) async {
    try {
      Logger.debug('🚀 Attempting dual-write to Supabase (awardLP)...', service: 'lovepoint');

      final response = await _apiClient.post('/api/sync/love-points', body: {
        'id': awardId,
        'amount': amount,
        'reason': reason,
        'relatedId': relatedId,
        'multiplier': multiplier,
        'partnerId': partnerId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (response.success) {
        Logger.debug('✅ Supabase dual-write successful!', service: 'lovepoint');
      } else {
        Logger.error('Supabase dual-write failed: ${response.error}', service: 'lovepoint');
      }
    } catch (e) {
      Logger.error('Supabase dual-write exception', error: e, service: 'lovepoint');
    }
  }

  /// Start listening for LP awards from Firebase
  /// Call this once on app start
  ///
  /// [onLPChanged] - Optional callback to trigger UI updates when LP changes
  ///
  /// PHASE 4: When useSupabaseForLovePoints is TRUE, uses Supabase polling
  static void startListeningForLPAwards({
    required String currentUserId,
    required String partnerUserId,
    VoidCallback? onLPChanged,
  }) {
    try {
      // Store callback for UI updates
      if (onLPChanged != null) {
        _onLPChanged = onLPChanged;
      }

      // PHASE 4: Supabase polling path (flag-gated)
      if (DevConfig.useSupabaseForLovePoints) {
        _startSupabasePollingForLPAwards(currentUserId);
        return;
      }

      // OLD PATH: Firebase listener (default)
      // Generate couple ID
      final sortedIds = [currentUserId, partnerUserId]..sort();
      final coupleId = '${sortedIds[0]}_${sortedIds[1]}';

      // Listen for new LP awards
      _database.child('lp_awards/$coupleId').onChildAdded.listen((event) {
        if (event.snapshot.value != null) {
          _handleLPAward(event.snapshot, currentUserId);
        }
      });

      Logger.info('Listening for LP awards for couple: $coupleId', service: 'lovepoint');
    } catch (e) {
      Logger.error('Error setting up LP award listener', error: e, service: 'lovepoint');
    }
  }

  /// Handle LP award from Firebase
  static Future<void> _handleLPAward(DataSnapshot snapshot, String currentUserId) async {
    try {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final users = List<String>.from(data['users'] ?? []);

      // Check if this award is for the current user
      if (!users.contains(currentUserId)) return;

      final awardId = snapshot.key;
      final amount = data['amount'] as int;
      final reason = data['reason'] as String;
      final relatedId = data['relatedId'] as String?;
      final multiplier = data['multiplier'] as int? ?? 1;

      // Check if we've already applied this award (prevent duplicates)
      final appliedAwards = _storage.getAppliedLPAwards();
      if (appliedAwards.contains(awardId)) {
        Logger.debug('LP award $awardId already applied, skipping', service: 'lovepoint');
        return;
      }

      // Apply the LP award locally (await the future)
      await awardPoints(
        amount: amount,
        reason: reason,
        relatedId: relatedId,
        multiplier: multiplier,
      );

      // Mark as applied
      _storage.markLPAwardAsApplied(awardId!);

      Logger.success('Applied LP award from Firebase: +$amount LP ($reason)', service: 'lovepoint');

      // Show foreground notification banner
      if (_appContext != null && _appContext!.mounted) {
        ForegroundNotificationBanner.show(
          _appContext!,
          title: 'Love Points Earned!',
          message: '+$amount LP',
          emoji: '💰',
        );
      }

      // Trigger UI update callback (for real-time LP counter updates)
      _onLPChanged?.call();
    } catch (e, stackTrace) {
      Logger.error('Error handling LP award', error: e, stackTrace: stackTrace, service: 'lovepoint');
    }
  }

  // ============================================================================
  // PHASE 4: SUPABASE-ONLY METHODS (Flag-gated)
  // ============================================================================

  /// Award Love Points to BOTH users - Supabase-only implementation
  /// Used when DevConfig.useSupabaseForLovePoints is TRUE
  static Future<void> _awardPointsToBothUsersSupabase({
    required String userId1,
    required String userId2,
    required int amount,
    required String reason,
    String? relatedId,
    int multiplier = 1,
  }) async {
    try {
      final awardKey = relatedId ?? const Uuid().v4();
      final actualAmount = amount * multiplier;

      // Write to Supabase API (single source of truth)
      final response = await _apiClient.post('/api/sync/love-points', body: {
        'id': awardKey,
        'amount': amount,
        'reason': reason,
        'relatedId': relatedId,
        'multiplier': multiplier,
        'partnerId': userId2 == userId1 ? userId2 : (userId1 == _storage.getUser()?.id ? userId2 : userId1),
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (response.success) {
        Logger.info('LP award synced to Supabase: $actualAmount LP for both users ($reason)', service: 'lovepoint');
      } else {
        Logger.error('Supabase LP award failed: ${response.error}', service: 'lovepoint');
      }
    } catch (e) {
      Logger.error('Error syncing LP award to Supabase', error: e, service: 'lovepoint');
    }
  }

  /// Start polling Supabase for new LP awards
  /// Used when DevConfig.useSupabaseForLovePoints is TRUE
  static void _startSupabasePollingForLPAwards(String currentUserId) {
    // Cancel existing timer if any
    _pollingTimer?.cancel();

    // Initialize last poll time to now (avoid fetching old awards)
    _lastPollTime = DateTime.now();

    Logger.info('Starting Supabase polling for LP awards (10s interval)', service: 'lovepoint');

    // Poll immediately, then every 10 seconds
    _pollSupabaseForLPAwards(currentUserId);

    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      _pollSupabaseForLPAwards(currentUserId);
    });
  }

  /// Poll Supabase API for new LP awards
  static Future<void> _pollSupabaseForLPAwards(String currentUserId) async {
    try {
      // Fetch recent LP awards from Supabase
      final response = await _apiClient.get('/api/sync/love-points');

      if (!response.success) {
        Logger.error('Failed to fetch LP awards from Supabase', service: 'lovepoint');
        return;
      }

      final data = response.data;
      if (data == null) return;

      final transactions = data['transactions'] as List<dynamic>?;
      if (transactions == null || transactions.isEmpty) return;

      // Process new awards (since last poll)
      for (final award in transactions) {
        final awardId = award['id'] as String;
        final createdAt = DateTime.parse(award['created_at'] as String);

        // Skip awards older than last poll
        if (_lastPollTime != null && createdAt.isBefore(_lastPollTime!)) {
          continue;
        }

        // Check if already applied
        final appliedAwards = _storage.getAppliedLPAwards();
        if (appliedAwards.contains(awardId)) {
          continue;
        }

        // Apply the award
        final amount = award['amount'] as int;
        final reason = award['reason'] as String;
        final relatedId = award['related_id'] as String?;
        final multiplier = award['multiplier'] as int? ?? 1;

        await awardPoints(
          amount: amount,
          reason: reason,
          relatedId: relatedId,
          multiplier: multiplier,
        );

        // Mark as applied
        _storage.markLPAwardAsApplied(awardId);

        Logger.success('Applied LP award from Supabase: +$amount LP ($reason)', service: 'lovepoint');

        // Show foreground notification banner
        if (_appContext != null && _appContext!.mounted) {
          ForegroundNotificationBanner.show(
            _appContext!,
            title: 'Love Points Earned!',
            message: '+$amount LP',
            emoji: '💰',
          );
        }

        // Trigger UI update callback
        _onLPChanged?.call();
      }

      // Update last poll time
      _lastPollTime = DateTime.now();

    } catch (e) {
      Logger.error('Error polling Supabase for LP awards', error: e, service: 'lovepoint');
    }
  }

  /// Stop Supabase polling (cleanup method)
  static void stopSupabasePolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    Logger.info('Stopped Supabase polling for LP awards', service: 'lovepoint');
  }
}

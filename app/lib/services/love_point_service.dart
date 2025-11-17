import '../models/user.dart';
import '../models/love_point_transaction.dart';
import 'storage_service.dart';
import 'general_activity_streak_service.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/foreground_notification_banner.dart';
import '../utils/logger.dart';

class LovePointService {
  static final StorageService _storage = StorageService();
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // BuildContext for showing foreground notifications
  static BuildContext? _appContext;

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

  /// Award Love Points to BOTH users in a couple (for shared activities)
  /// This syncs the award to Firebase so both apps can apply it
  /// Uses relatedId as the Firebase key for atomic deduplication:
  /// - onChildAdded listener only fires ONCE per unique child path
  /// - Even if both devices write to same path, listener triggers only once
  static Future<void> awardPointsToBothUsers({
    required String userId1,
    required String userId2,
    required int amount,
    required String reason,
    String? relatedId,
    int multiplier = 1,
  }) async {
    try {
      final actualAmount = amount * multiplier;

      // Generate couple ID (sorted for consistency)
      final sortedIds = [userId1, userId2]..sort();
      final coupleId = '${sortedIds[0]}_${sortedIds[1]}';

      // Use relatedId as the Firebase key for automatic deduplication
      // If relatedId is null, generate a random key (no deduplication)
      final awardKey = relatedId ?? const Uuid().v4();

      // Write LP award to Firebase
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
    } catch (e) {
      Logger.error('Error syncing LP award to Firebase', error: e, service: 'lovepoint');
    }
  }

  /// Start listening for LP awards from Firebase
  /// Call this once on app start
  static void startListeningForLPAwards({
    required String currentUserId,
    required String partnerUserId,
  }) {
    try {
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
    } catch (e, stackTrace) {
      Logger.error('Error handling LP award', error: e, stackTrace: stackTrace, service: 'lovepoint');
    }
  }
}

import '../models/user.dart';
import '../models/love_point_transaction.dart';
import 'storage_service.dart';
import 'package:uuid/uuid.dart';

class LovePointService {
  static final StorageService _storage = StorageService();

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
    final user = _storage.getUser();
    if (user == null) {
      print('❌ No user found, cannot award points');
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
      print('🎉 Tier upgraded to ${arenas[newTier]!['name']}!');
      // TODO: Show tier upgrade animation/notification in Phase 2
    }

    await user.save();

    print(
        '💰 Awarded $actualAmount LP for $reason (Total: ${user.lovePoints})');
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
    if (user == null) {
      return {
        'total': 0,
        'tier': 1,
        'floor': 0,
        'progressToNext': 0.0,
      };
    }

    return {
      'total': user.lovePoints,
      'tier': user.arenaTier,
      'floor': user.floor,
      'progressToNext': getProgressToNextTier(),
      'currentArena': getCurrentTierInfo(),
      'nextArena': getNextTierInfo(),
    };
  }
}

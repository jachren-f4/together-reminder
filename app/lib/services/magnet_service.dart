import '../models/magnet_collection.dart';
import '../models/cooldown_status.dart';
import 'storage_service.dart';
import 'api_client.dart';
import '../utils/logger.dart';
import 'package:flutter/material.dart';

/// Service for managing Magnet Collection data and syncing with server
class MagnetService {
  static final MagnetService _instance = MagnetService._internal();
  factory MagnetService() => _instance;
  MagnetService._internal();

  final StorageService _storage = StorageService();
  final ApiClient _apiClient = ApiClient();

  // Callback for triggering UI updates when magnets/cooldowns change
  static VoidCallback? _onMagnetsChanged;

  /// Register callback for magnet changes (for real-time UI updates)
  static void setMagnetsChangeCallback(VoidCallback? callback) {
    _onMagnetsChanged = callback;
  }

  /// Notify listeners that magnets have changed
  void _notifyMagnetsChanged() {
    _onMagnetsChanged?.call();
  }

  /// Get cached magnet collection from local storage
  MagnetCollection? getCachedCollection() {
    return _storage.getMagnetCollection();
  }

  /// Get cached cooldown collection from local storage
  CooldownCollection? getCachedCooldowns() {
    return _storage.getCooldownCollection();
  }

  /// Fetch magnet collection from server and sync to local storage
  ///
  /// Returns the updated MagnetCollection or null on error.
  Future<MagnetCollection?> fetchAndSync() async {
    try {
      final response = await _apiClient.get('/api/magnets');

      if (!response.success) {
        Logger.error('Failed to fetch magnet collection', service: 'magnet');
        return getCachedCollection();
      }

      final data = response.data;
      if (data == null) return getCachedCollection();

      // Parse magnet collection
      final collection = MagnetCollection.fromJson(data);

      // Parse cooldowns if present
      final cooldownsData = data['cooldowns'] as Map<String, dynamic>?;
      if (cooldownsData != null) {
        final cooldowns = CooldownCollection.fromJson({'cooldowns': cooldownsData});
        await _storage.saveCooldownCollection(cooldowns);
      }

      // Save to local storage
      await _storage.saveMagnetCollection(collection);

      _notifyMagnetsChanged();

      Logger.info(
        'Synced magnets: ${collection.unlockedCount}/${collection.totalMagnets} '
        '(${collection.currentLp} LP)',
        service: 'magnet',
      );

      return collection;
    } catch (e, stackTrace) {
      Logger.error('Error fetching magnet collection', error: e, stackTrace: stackTrace, service: 'magnet');
      return getCachedCollection();
    }
  }

  /// Check if a specific activity is on cooldown
  bool isOnCooldown(ActivityType activityType) {
    final cooldowns = getCachedCooldowns();
    if (cooldowns == null) return false;
    return cooldowns.getStatus(activityType).isOnCooldown;
  }

  /// Get cooldown status for a specific activity
  CooldownStatus? getCooldownStatus(ActivityType activityType) {
    final cooldowns = getCachedCooldowns();
    if (cooldowns == null) return null;
    return cooldowns.getStatus(activityType);
  }

  /// Get remaining plays in batch for an activity
  int getRemainingPlays(ActivityType activityType) {
    final cooldowns = getCachedCooldowns();
    if (cooldowns == null) return 2; // Default batch size
    return cooldowns.getStatus(activityType).remainingInBatch;
  }

  /// Get formatted cooldown remaining time (e.g., "6h 24m")
  String? getFormattedCooldownTime(ActivityType activityType) {
    final cooldowns = getCachedCooldowns();
    if (cooldowns == null) return null;
    return cooldowns.getStatus(activityType).formattedRemaining;
  }

  /// Detect if a magnet was unlocked after LP change
  ///
  /// Returns the newly unlocked magnet ID or null if no unlock
  int? detectUnlock(int oldLp, int newLp) {
    final oldMagnets = calculateMagnets(oldLp);
    final newMagnets = calculateMagnets(newLp);

    if (newMagnets > oldMagnets) {
      return oldMagnets + 1; // Return the first newly unlocked magnet
    }
    return null;
  }

  /// Calculate number of magnets unlocked for given LP
  ///
  /// Mirrors api/lib/magnets/calculator.ts logic
  /// Public so LovePointService can use it for celebration tracking
  int calculateMagnets(int totalLp) {
    int cumulativeLp = 0;
    int magnetsUnlocked = 0;

    for (int i = 1; i <= 30; i++) {
      cumulativeLp += _getLpRequirement(i);
      if (totalLp >= cumulativeLp) {
        magnetsUnlocked = i;
      } else {
        break;
      }
    }

    return magnetsUnlocked;
  }

  /// Get LP requirement for a specific magnet number
  ///
  /// Progressive: 600 for magnets 1-3, +100 every 3 magnets
  int _getLpRequirement(int magnetNumber) {
    final tier = (magnetNumber - 1) ~/ 3;
    return 600 + (tier * 100);
  }

  /// Get LP required for next magnet (for progress bar)
  int getLpForNextMagnet(int unlockedCount) {
    if (unlockedCount >= 30) return 0;
    return _getLpRequirement(unlockedCount + 1);
  }

  /// Get progress percentage to next magnet
  double getProgressToNextMagnet(MagnetCollection collection) {
    if (collection.allUnlocked) return 1.0;
    if (collection.lpForNextMagnet == 0) return 0.0;
    return (collection.lpProgressToNext / collection.lpForNextMagnet).clamp(0.0, 1.0);
  }
}

import 'package:flutter/foundation.dart';
import '../models/steps_data.dart';
import 'storage_service.dart';
import 'steps_health_service.dart';

/// Debug service for testing Steps Together without real HealthKit data.
/// Only active in debug mode. Allows simulating various step counts and states.
class StepsDebugService {
  static final StepsDebugService _instance = StepsDebugService._internal();
  factory StepsDebugService() => _instance;
  StepsDebugService._internal();

  final StorageService _storage = StorageService();

  /// Whether mock data mode is active
  bool _useMockData = false;
  bool get useMockData => _useMockData && kDebugMode;

  /// Mock step values
  int _mockUserSteps = 0;
  int _mockPartnerSteps = 0;

  int get mockUserSteps => _mockUserSteps;
  int get mockPartnerSteps => _mockPartnerSteps;
  int get mockCombinedSteps => _mockUserSteps + _mockPartnerSteps;

  /// Calculate current tier based on combined steps
  String get currentTierName {
    final combined = mockCombinedSteps;
    if (combined >= 20000) return '20K (Max)';
    if (combined >= 18000) return '18K';
    if (combined >= 16000) return '16K';
    if (combined >= 14000) return '14K';
    if (combined >= 12000) return '12K';
    if (combined >= 10000) return '10K';
    return 'Below 10K';
  }

  /// Calculate LP for current combined steps
  int get currentLP => StepsDay.calculateLP(mockCombinedSteps);

  /// Enable mock data mode
  void enableMockData() {
    _useMockData = true;
  }

  /// Disable mock data mode and clear mock values
  void disableMockData() {
    _useMockData = false;
    _mockUserSteps = 0;
    _mockPartnerSteps = 0;
  }

  /// Set mock user steps
  void setMockUserSteps(int steps) {
    _mockUserSteps = steps.clamp(0, 25000);
  }

  /// Set mock partner steps
  void setMockPartnerSteps(int steps) {
    _mockPartnerSteps = steps.clamp(0, 25000);
  }

  /// Apply preset: Below 10K threshold
  void applyPresetBelowThreshold() {
    _mockUserSteps = 4000;
    _mockPartnerSteps = 3000;
    _useMockData = true;
  }

  /// Apply preset: At 10K threshold (minimum LP)
  void applyPresetAt10K() {
    _mockUserSteps = 5000;
    _mockPartnerSteps = 5000;
    _useMockData = true;
  }

  /// Apply preset: At 14K (mid tier)
  void applyPresetAt14K() {
    _mockUserSteps = 8000;
    _mockPartnerSteps = 6000;
    _useMockData = true;
  }

  /// Apply preset: Max tier (20K+)
  void applyPresetMaxTier() {
    _mockUserSteps = 12000;
    _mockPartnerSteps = 10000;
    _useMockData = true;
  }

  /// Write mock data to storage for today
  Future<void> applyMockDataToStorage() async {
    if (!kDebugMode) return;

    final now = DateTime.now();
    final dateKey = StepsHealthService.todayDateKey;

    // Create or update today's step data
    var stepsDay = _storage.getStepsDay(dateKey);
    if (stepsDay == null) {
      stepsDay = StepsDay(
        dateKey: dateKey,
        userSteps: _mockUserSteps,
        partnerSteps: _mockPartnerSteps,
        lastSync: now,
        partnerLastSync: now,
      );
    } else {
      stepsDay.userSteps = _mockUserSteps;
      stepsDay.partnerSteps = _mockPartnerSteps;
      stepsDay.lastSync = now;
      stepsDay.partnerLastSync = now;
    }

    // Calculate earned LP
    stepsDay.earnedLP = StepsDay.calculateLP(stepsDay.combinedSteps);

    await _storage.saveStepsDay(stepsDay);
  }

  /// Write mock yesterday data for testing auto-claim
  Future<void> applyMockYesterdayData({
    int userSteps = 8000,
    int partnerSteps = 6000,
    bool claimed = false,
    String? claimedByUserId,
  }) async {
    if (!kDebugMode) return;

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateKey = StepsHealthService.yesterdayDateKey;
    final endOfYesterday = DateTime(yesterday.year, yesterday.month, yesterday.day + 1);
    final claimExpiry = endOfYesterday.add(const Duration(hours: 48));

    var stepsDay = _storage.getStepsDay(dateKey);
    if (stepsDay == null) {
      stepsDay = StepsDay(
        dateKey: dateKey,
        userSteps: userSteps,
        partnerSteps: partnerSteps,
        lastSync: yesterday,
        partnerLastSync: yesterday,
        claimExpiresAt: claimExpiry,
        claimed: claimed,
        claimedByUserId: claimedByUserId,
      );
    } else {
      stepsDay.userSteps = userSteps;
      stepsDay.partnerSteps = partnerSteps;
      stepsDay.partnerLastSync = yesterday;
      stepsDay.claimExpiresAt = claimExpiry;
      stepsDay.claimed = claimed;
      stepsDay.claimedByUserId = claimedByUserId;
      stepsDay.overlayShownAt = null; // Reset to allow overlay to show
    }

    stepsDay.earnedLP = StepsDay.calculateLP(stepsDay.combinedSteps);

    await _storage.saveStepsDay(stepsDay);
  }

  /// Generate mock week history data
  Future<void> generateMockWeekHistory() async {
    if (!kDebugMode) return;

    final now = DateTime.now();

    // Generate data for last 7 days
    final weekData = [
      // Today - in progress
      {'daysAgo': 0, 'user': _mockUserSteps > 0 ? _mockUserSteps : 7500, 'partner': _mockPartnerSteps > 0 ? _mockPartnerSteps : 6700, 'claimed': false},
      // Yesterday - claimable
      {'daysAgo': 1, 'user': 11000, 'partner': 11100, 'claimed': true},
      // 2 days ago
      {'daysAgo': 2, 'user': 8500, 'partner': 8000, 'claimed': true},
      // 3 days ago
      {'daysAgo': 3, 'user': 6500, 'partner': 6800, 'claimed': true},
      // 4 days ago - missed
      {'daysAgo': 4, 'user': 4000, 'partner': 3500, 'claimed': false},
      // 5 days ago - missed
      {'daysAgo': 5, 'user': 5000, 'partner': 3000, 'claimed': false},
      // 6 days ago
      {'daysAgo': 6, 'user': 9000, 'partner': 7500, 'claimed': true},
    ];

    for (final data in weekData) {
      final daysAgo = data['daysAgo'] as int;
      final date = now.subtract(Duration(days: daysAgo));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final userSteps = data['user'] as int;
      final partnerSteps = data['partner'] as int;
      final claimed = data['claimed'] as bool;

      final endOfDay = DateTime(date.year, date.month, date.day + 1);
      final claimExpiry = endOfDay.add(const Duration(hours: 48));

      final stepsDay = StepsDay(
        dateKey: dateKey,
        userSteps: userSteps,
        partnerSteps: partnerSteps,
        lastSync: date,
        partnerLastSync: date,
        claimExpiresAt: claimExpiry,
        claimed: claimed,
        earnedLP: StepsDay.calculateLP(userSteps + partnerSteps),
      );

      await _storage.saveStepsDay(stepsDay);
    }

    _useMockData = true;
  }

  /// Reset today's step data
  Future<void> resetTodayData() async {
    if (!kDebugMode) return;

    final dateKey = StepsHealthService.todayDateKey;
    final stepsDay = _storage.getStepsDay(dateKey);
    if (stepsDay != null) {
      stepsDay.userSteps = 0;
      stepsDay.partnerSteps = 0;
      stepsDay.earnedLP = 0;
      await _storage.updateStepsDay(stepsDay);
    }

    _mockUserSteps = 0;
    _mockPartnerSteps = 0;
  }

  /// Reset yesterday's data for testing auto-claim
  Future<void> resetYesterdayData() async {
    if (!kDebugMode) return;

    final dateKey = StepsHealthService.yesterdayDateKey;
    final stepsDay = _storage.getStepsDay(dateKey);
    if (stepsDay != null) {
      stepsDay.claimed = false;
      stepsDay.claimedByUserId = null;
      stepsDay.overlayShownAt = null;
      await _storage.updateStepsDay(stepsDay);
    }
  }

  /// Clear all mock data
  Future<void> clearAllMockData() async {
    _useMockData = false;
    _mockUserSteps = 0;
    _mockPartnerSteps = 0;
    // Note: This doesn't delete from storage, just resets mock state
  }

  /// Get mock data for display in debug menu
  Map<String, dynamic> getDebugInfo() {
    return {
      'useMockData': _useMockData,
      'userSteps': _mockUserSteps,
      'partnerSteps': _mockPartnerSteps,
      'combinedSteps': mockCombinedSteps,
      'currentTier': currentTierName,
      'currentLP': currentLP,
    };
  }
}

import 'dart:io';
import '../models/steps_data.dart';
import '../utils/logger.dart';
import 'storage_service.dart';
import 'steps_health_service.dart';
import 'steps_sync_service.dart';

/// Determines the current state of the Steps Together feature for UI rendering.
/// This service consolidates all the checks needed to decide which screen/card to show.
enum StepsFeatureState {
  /// Platform doesn't support this feature (Android)
  notSupported,

  /// User hasn't connected Apple Health yet, partner hasn't either
  neitherConnected,

  /// User hasn't connected, but partner has
  partnerConnected,

  /// User connected, waiting for partner
  waitingForPartner,

  /// Both connected, showing today's progress
  tracking,

  /// Yesterday's reward is ready to claim
  claimReady,
}

/// Service to determine the current state of the Steps Together feature.
class StepsFeatureService {
  static final StepsFeatureService _instance = StepsFeatureService._internal();
  factory StepsFeatureService() => _instance;
  StepsFeatureService._internal();

  final StorageService _storage = StorageService();
  final StepsHealthService _healthService = StepsHealthService();
  final StepsSyncService _syncService = StepsSyncService();

  bool _isInitialized = false;

  /// Initialize the Steps feature with couple and user IDs
  Future<void> initialize({
    required String coupleId,
    required String userId,
  }) async {
    if (_isInitialized) return;
    if (!isSupported) return;

    // Initialize health service
    await _healthService.init();

    // Initialize sync service
    _syncService.initialize(coupleId: coupleId, userId: userId);

    // Load partner data from Firebase
    await _syncService.loadPartnerDataFromFirebase();

    // Start listening for updates
    _syncService.startListening();

    _isInitialized = true;
    Logger.info('StepsFeatureService initialized', service: 'steps');
  }

  /// Dispose of resources
  void dispose() {
    _syncService.dispose();
    _isInitialized = false;
  }

  /// Check if the Steps feature should be shown on this platform
  bool get isSupported => Platform.isIOS;

  /// Get the current feature state for UI rendering
  StepsFeatureState getCurrentState() {
    // Platform check first
    if (!isSupported) {
      return StepsFeatureState.notSupported;
    }

    final connection = _storage.getStepsConnection();

    // Check if user is connected
    final userConnected = connection?.isConnected ?? false;
    final partnerConnected = connection?.partnerConnected ?? false;

    // Check for claimable reward (takes priority over other states)
    final yesterday = _storage.getYesterdaySteps();
    if (yesterday != null && yesterday.canClaim) {
      return StepsFeatureState.claimReady;
    }

    // Connection states
    if (!userConnected && !partnerConnected) {
      return StepsFeatureState.neitherConnected;
    }

    if (!userConnected && partnerConnected) {
      return StepsFeatureState.partnerConnected;
    }

    if (userConnected && !partnerConnected) {
      return StepsFeatureState.waitingForPartner;
    }

    // Both connected - tracking state
    return StepsFeatureState.tracking;
  }

  /// Get today's step data for display
  StepsDay? getTodayData() {
    return _storage.getTodaySteps();
  }

  /// Get yesterday's step data for claim display
  StepsDay? getYesterdayData() {
    return _storage.getYesterdaySteps();
  }

  /// Get the connection status
  StepsConnection getConnectionStatus() {
    return _storage.getStepsConnection() ?? StepsConnection();
  }

  /// Calculate projected LP from today's steps
  int getProjectedLP() {
    final today = _storage.getTodaySteps();
    if (today == null) return 0;
    return StepsDay.calculateLP(today.combinedSteps);
  }

  /// Check if there's a claimable reward
  bool hasClaimableReward() {
    final yesterday = _storage.getYesterdaySteps();
    return yesterday?.canClaim ?? false;
  }

  /// Get the claimable reward amount
  int getClaimableRewardAmount() {
    final yesterday = _storage.getYesterdaySteps();
    if (yesterday == null || !yesterday.canClaim) return 0;
    return yesterday.earnedLP;
  }

  /// Request HealthKit permission and update state
  Future<bool> connectHealthKit() async {
    if (!isSupported) return false;

    final granted = await _healthService.requestPermission();
    if (granted) {
      Logger.success('HealthKit connected successfully', service: 'steps');

      // Sync initial step data locally
      // IMPORTANT: skipPermissionCheck=true to avoid race condition where
      // hasPermission() returns false immediately after permission grant
      await _healthService.syncTodaySteps(skipPermissionCheck: true);
      await _healthService.syncYesterdaySteps(skipPermissionCheck: true);

      // Sync to Firebase
      await _syncService.syncConnectionStatus();
      await _syncService.syncStepsToFirebase();
      await _syncService.syncYesterdayToFirebase();
    }
    return granted;
  }

  /// Sync step data from HealthKit and to Firebase
  Future<void> syncSteps() async {
    if (!isSupported) return;

    // Full sync: HealthKit -> Local -> Firebase
    await _syncService.performFullSync();
  }

  /// Mark yesterday's reward as claimed
  Future<void> claimReward() async {
    final yesterday = _storage.getYesterdaySteps();
    if (yesterday != null && yesterday.canClaim) {
      await _healthService.markAsClaimed(yesterday.dateKey);
      await _syncService.markClaimedInFirebase(yesterday.dateKey);
    }
  }

  /// Get step progress as a percentage (0.0 to 1.0+)
  double getTodayProgress() {
    final today = _storage.getTodaySteps();
    if (today == null) return 0.0;
    return today.combinedSteps / 20000;
  }

  /// Get user's individual progress (0.0 to 1.0)
  double getUserProgress() {
    final today = _storage.getTodaySteps();
    if (today == null) return 0.0;
    return (today.userSteps / 20000).clamp(0.0, 1.0);
  }

  /// Get partner's individual progress (0.0 to 1.0)
  double getPartnerProgress() {
    final today = _storage.getTodaySteps();
    if (today == null) return 0.0;
    return (today.partnerSteps / 20000).clamp(0.0, 1.0);
  }
}

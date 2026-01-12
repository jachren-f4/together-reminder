import '../models/steps_data.dart';
import '../utils/logger.dart';
import 'storage_service.dart';
import 'steps_health_service.dart';
import 'steps_sync_service.dart';
import 'api_client.dart';

/// Result of checking for auto-claimable steps reward.
class StepsAutoClaimResult {
  /// Whether there's a reward to show an overlay for
  final bool shouldShowOverlay;

  /// Whether the current user is the claimer (vs partner already claimed)
  final bool isCurrentUserClaimer;

  /// The steps data for yesterday
  final StepsDay? stepsDay;

  /// Partner's name for display
  final String? partnerName;

  /// Error message if auto-claim failed
  final String? error;

  const StepsAutoClaimResult({
    required this.shouldShowOverlay,
    this.isCurrentUserClaimer = false,
    this.stepsDay,
    this.partnerName,
    this.error,
  });

  /// No reward to show
  static const noReward = StepsAutoClaimResult(shouldShowOverlay: false);
}

/// Service for handling automatic steps reward claiming.
///
/// Flow:
/// 1. On app launch, check if yesterday's steps qualify for a reward
/// 2. If not already claimed, auto-claim via API
/// 3. Show celebration overlay (different message if partner claimed)
/// 4. Mark overlay as shown to prevent duplicate displays
class StepsAutoClaimService {
  static final StepsAutoClaimService _instance = StepsAutoClaimService._internal();
  factory StepsAutoClaimService() => _instance;
  StepsAutoClaimService._internal();

  final StorageService _storage = StorageService();
  final StepsHealthService _healthService = StepsHealthService();
  final StepsSyncService _syncService = StepsSyncService();
  final ApiClient _apiClient = ApiClient();

  /// Check if there's a steps reward that should trigger an auto-claim overlay.
  /// This should be called on app launch after steps data is synced.
  ///
  /// Returns a result indicating whether to show an overlay and the relevant data.
  Future<StepsAutoClaimResult> checkAndClaimIfNeeded() async {
    // Platform check
    if (!StepsHealthService.isSupported) {
      Logger.debug('Steps auto-claim: Not iOS, skipping', service: 'steps');
      return StepsAutoClaimResult.noReward;
    }

    // Check if user/partner are available
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    if (user == null || partner == null) {
      Logger.debug('Steps auto-claim: No user/partner in storage', service: 'steps');
      return StepsAutoClaimResult.noReward;
    }

    // Try to initialize sync service for API calls
    if (!_syncService.isInitialized && !_syncService.tryAutoInitialize()) {
      Logger.warn('Steps auto-claim: Could not initialize sync service', service: 'steps');
      return StepsAutoClaimResult.noReward;
    }

    // Sync latest data from server first
    await _syncService.loadPartnerDataFromServer();

    // Get yesterday's step data
    final yesterday = _storage.getYesterdaySteps();
    if (yesterday == null) {
      Logger.debug('Steps auto-claim: No yesterday data', service: 'steps');
      return StepsAutoClaimResult.noReward;
    }

    // Check if overlay was already shown
    if (yesterday.overlayShownAt != null) {
      Logger.debug('Steps auto-claim: Overlay already shown for ${yesterday.dateKey}', service: 'steps');
      return StepsAutoClaimResult.noReward;
    }

    // Check basic eligibility
    if (yesterday.combinedSteps < 10000) {
      Logger.debug('Steps auto-claim: Combined steps ${yesterday.combinedSteps} < 10,000', service: 'steps');
      return StepsAutoClaimResult.noReward;
    }

    // Check if expired
    if (yesterday.isExpired) {
      Logger.debug('Steps auto-claim: Reward expired', service: 'steps');
      return StepsAutoClaimResult.noReward;
    }

    // Check if partner data is available
    if (yesterday.partnerLastSync == null) {
      Logger.debug('Steps auto-claim: No partner sync data yet', service: 'steps');
      return StepsAutoClaimResult.noReward;
    }

    // Calculate LP if not set
    if (yesterday.earnedLP == 0) {
      yesterday.earnedLP = StepsDay.calculateLP(yesterday.combinedSteps);
      await _storage.updateStepsDay(yesterday);
    }

    // Check if already claimed
    if (yesterday.claimed) {
      // Partner already claimed - show "partner claimed for you" overlay
      final isPartnerClaimer = yesterday.wasClaimedByPartner(user.id);
      Logger.info(
        'Steps auto-claim: Already claimed by ${isPartnerClaimer ? "partner" : "user"}, showing overlay',
        service: 'steps',
      );

      return StepsAutoClaimResult(
        shouldShowOverlay: true,
        isCurrentUserClaimer: !isPartnerClaimer,
        stepsDay: yesterday,
        partnerName: partner.name,
      );
    }

    // Not claimed yet - perform auto-claim
    Logger.info('Steps auto-claim: Claiming reward for ${yesterday.dateKey}', service: 'steps');

    try {
      final response = await _apiClient.post('/api/sync/steps', body: {
        'operation': 'claim',
        'dateKey': yesterday.dateKey,
        'combinedSteps': yesterday.combinedSteps,
        'lpEarned': yesterday.earnedLP,
      });

      if (response.success) {
        final data = response.data;
        final alreadyClaimed = data?['alreadyClaimed'] == true;

        // Mark as claimed locally
        await _healthService.markAsClaimed(
          yesterday.dateKey,
          claimedByUserId: alreadyClaimed ? null : user.id,
        );

        // Reload yesterday data
        final updatedYesterday = _storage.getYesterdaySteps();

        if (alreadyClaimed) {
          // Race condition - partner claimed first
          Logger.info('Steps auto-claim: Partner claimed first (race condition)', service: 'steps');
          return StepsAutoClaimResult(
            shouldShowOverlay: true,
            isCurrentUserClaimer: false,
            stepsDay: updatedYesterday ?? yesterday,
            partnerName: partner.name,
          );
        }

        // Successfully claimed by current user
        Logger.success('Steps auto-claim: Successfully claimed ${yesterday.earnedLP} LP', service: 'steps');
        return StepsAutoClaimResult(
          shouldShowOverlay: true,
          isCurrentUserClaimer: true,
          stepsDay: updatedYesterday ?? yesterday,
          partnerName: partner.name,
        );
      } else {
        Logger.error('Steps auto-claim: API error - ${response.error}', service: 'steps');
        return StepsAutoClaimResult(
          shouldShowOverlay: false,
          error: response.error,
        );
      }
    } catch (e, stackTrace) {
      Logger.error('Steps auto-claim: Exception during claim', error: e, stackTrace: stackTrace, service: 'steps');
      return StepsAutoClaimResult(
        shouldShowOverlay: false,
        error: e.toString(),
      );
    }
  }

  /// Mark the overlay as shown for yesterday's date.
  /// Call this after the overlay is dismissed.
  Future<void> markOverlayShown() async {
    final yesterday = _storage.getYesterdaySteps();
    if (yesterday != null) {
      await _healthService.markOverlayShown(yesterday.dateKey);
    }
  }
}

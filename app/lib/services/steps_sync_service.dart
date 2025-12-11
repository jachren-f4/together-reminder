import 'dart:async';
import '../utils/logger.dart';
import 'storage_service.dart';
import 'steps_health_service.dart';
import 'api_client.dart';

/// Service for synchronizing step data between partners via Supabase API.
///
/// Architecture (Supabase-only):
/// - POST /api/sync/steps - sync steps data (connection, daily steps, claims)
/// - GET /api/sync/steps - fetch partner's step data
/// - Polling for partner updates (60s interval on Steps screen)
///
/// Data structure:
/// - steps_daily table: user_id, date_key, steps, last_sync_at
/// - steps_rewards table: couple_id, date_key, claimed_by, combined_steps, lp_earned
class StepsSyncService {
  static final StepsSyncService _instance = StepsSyncService._internal();
  factory StepsSyncService() => _instance;
  StepsSyncService._internal();

  final StorageService _storage = StorageService();
  final StepsHealthService _healthService = StepsHealthService();
  final ApiClient _apiClient = ApiClient();

  Timer? _pollingTimer;
  String? _currentCoupleId;
  String? _currentUserId;

  /// Check if the service is initialized
  bool get isInitialized => _currentCoupleId != null && _currentUserId != null;

  /// Initialize sync service with couple and user IDs
  void initialize({
    required String coupleId,
    required String userId,
  }) {
    _currentCoupleId = coupleId;
    _currentUserId = userId;
    Logger.debug('StepsSyncService initialized for couple: $coupleId, user: $userId', service: 'steps');
  }

  /// Try to auto-initialize from stored user/partner data
  /// Returns true if initialization succeeded, false otherwise
  bool tryAutoInitialize() {
    if (isInitialized) return true;

    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user == null || partner == null) {
      Logger.warn('Cannot auto-initialize StepsSyncService - no user or partner in storage', service: 'steps');
      return false;
    }

    // Generate couple ID using sorted user IDs (same logic as other services)
    final coupleId = generateCoupleId(user.id, partner.id);
    _currentCoupleId = coupleId;
    _currentUserId = user.id;

    Logger.info('StepsSyncService auto-initialized from storage for user: ${user.id}', service: 'steps');
    return true;
  }

  /// Start polling for partner's step updates
  void startPolling({Duration interval = const Duration(seconds: 60)}) {
    if (_currentCoupleId == null || _currentUserId == null) {
      Logger.warn('Cannot start polling - StepsSyncService not initialized', service: 'steps');
      return;
    }

    stopPolling();

    _pollingTimer = Timer.periodic(interval, (_) {
      loadPartnerDataFromServer();
    });

    Logger.debug('Started steps polling with ${interval.inSeconds}s interval', service: 'steps');
  }

  /// Stop polling
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    Logger.debug('StepsSyncService polling stopped', service: 'steps');
  }

  /// Sync user's connection status to Supabase
  Future<void> syncConnectionStatus() async {
    if (_currentCoupleId == null || _currentUserId == null) {
      Logger.warn('Cannot sync connection - not initialized', service: 'steps');
      return;
    }

    final connection = _storage.getStepsConnection();
    if (connection == null) return;

    try {
      final response = await _apiClient.post('/api/sync/steps', body: {
        'operation': 'connection',
        'isConnected': connection.isConnected,
        'connectedAt': connection.connectedAt?.toIso8601String(),
      });

      if (response.success) {
        Logger.debug('Synced connection status to Supabase: ${connection.isConnected}', service: 'steps');
      } else {
        Logger.warn('Failed to sync connection status: ${response.error}', service: 'steps');
      }
    } catch (e, stackTrace) {
      Logger.error('Error syncing connection status', error: e, stackTrace: stackTrace, service: 'steps');
    }
  }

  /// Sync user's steps to Supabase
  Future<void> syncStepsToServer() async {
    if (_currentCoupleId == null || _currentUserId == null) {
      Logger.warn('Cannot sync steps - not initialized', service: 'steps');
      return;
    }

    // Get today's local step data
    final today = _storage.getTodaySteps();
    if (today == null) {
      Logger.debug('No local steps to sync', service: 'steps');
      return;
    }

    try {
      final response = await _apiClient.post('/api/sync/steps', body: {
        'operation': 'steps',
        'dateKey': today.dateKey,
        'steps': today.userSteps,
        'lastSyncAt': DateTime.now().toIso8601String(),
      });

      if (response.success) {
        Logger.debug('Synced ${today.userSteps} steps to Supabase for ${today.dateKey}', service: 'steps');
      } else {
        Logger.warn('Failed to sync steps: ${response.error}', service: 'steps');
      }
    } catch (e, stackTrace) {
      Logger.error('Error syncing steps to Supabase', error: e, stackTrace: stackTrace, service: 'steps');
    }
  }

  /// Sync yesterday's steps to Supabase (for claim eligibility)
  Future<void> syncYesterdayToServer() async {
    if (_currentCoupleId == null || _currentUserId == null) {
      Logger.warn('Cannot sync yesterday - not initialized', service: 'steps');
      return;
    }

    // Get yesterday's local step data
    final yesterday = _storage.getYesterdaySteps();
    if (yesterday == null) {
      Logger.debug('No yesterday steps to sync', service: 'steps');
      return;
    }

    try {
      final response = await _apiClient.post('/api/sync/steps', body: {
        'operation': 'steps',
        'dateKey': yesterday.dateKey,
        'steps': yesterday.userSteps,
        'lastSyncAt': DateTime.now().toIso8601String(),
      });

      if (response.success) {
        Logger.debug('Synced ${yesterday.userSteps} steps to Supabase for ${yesterday.dateKey}', service: 'steps');
      } else {
        Logger.warn('Failed to sync yesterday steps: ${response.error}', service: 'steps');
      }
    } catch (e, stackTrace) {
      Logger.error('Error syncing yesterday to Supabase', error: e, stackTrace: stackTrace, service: 'steps');
    }
  }

  /// Full sync: read from HealthKit, push to Supabase, and fetch partner data
  /// Returns true if sync completed successfully, false if initialization failed
  Future<bool> performFullSync() async {
    if (!StepsHealthService.isSupported) {
      Logger.debug('Steps sync skipped - not iOS', service: 'steps');
      return false;
    }

    // Try to auto-initialize if not already initialized
    if (!isInitialized && !tryAutoInitialize()) {
      Logger.warn('performFullSync aborted - cannot initialize StepsSyncService', service: 'steps');
      return false;
    }

    // 1. Sync from HealthKit to local storage
    await _healthService.syncTodaySteps();
    await _healthService.syncYesterdaySteps();

    // 2. Sync from local storage to Supabase
    await syncStepsToServer();
    await syncYesterdayToServer();
    await syncConnectionStatus();

    // 3. Fetch partner's data from Supabase (CRITICAL: without this, partner steps never update!)
    await loadPartnerDataFromServer();

    Logger.info('Full steps sync completed', service: 'steps');
    return true;
  }

  /// Mark a day's reward as claimed in Supabase
  Future<void> markClaimedInServer(String dateKey) async {
    if (_currentCoupleId == null || _currentUserId == null) {
      Logger.warn('Cannot mark claimed - not initialized', service: 'steps');
      return;
    }

    try {
      final yesterday = _storage.getYesterdaySteps();

      final response = await _apiClient.post('/api/sync/steps', body: {
        'operation': 'claim',
        'dateKey': dateKey,
        'combinedSteps': yesterday?.combinedSteps ?? 0,
        'lpEarned': yesterday?.earnedLP ?? 0,
      });

      if (response.success) {
        final data = response.data;
        if (data != null && data['alreadyClaimed'] == true) {
          Logger.debug('Steps claim already recorded in Supabase', service: 'steps');
        } else {
          Logger.debug('Marked $dateKey as claimed in Supabase', service: 'steps');
        }
      } else {
        Logger.warn('Failed to mark claimed: ${response.error}', service: 'steps');
      }
    } catch (e, stackTrace) {
      Logger.error('Error marking claimed in Supabase', error: e, stackTrace: stackTrace, service: 'steps');
    }
  }

  /// Load partner's data from Supabase (initial load on app start)
  Future<void> loadPartnerDataFromServer() async {
    if (_currentCoupleId == null || _currentUserId == null) {
      Logger.warn('Cannot load partner data - not initialized', service: 'steps');
      return;
    }

    try {
      final response = await _apiClient.get('/api/sync/steps');

      if (!response.success || response.data == null) {
        Logger.debug('No partner steps data from server', service: 'steps');
        return;
      }

      final data = response.data as Map<String, dynamic>;

      // Handle partner connection status
      final partnerConnected = data['partnerConnected'] as bool? ?? false;
      final partnerConnectedAtStr = data['partnerConnectedAt'] as String?;
      DateTime? partnerConnectedAt;
      if (partnerConnectedAtStr != null) {
        partnerConnectedAt = DateTime.tryParse(partnerConnectedAtStr);
      }

      _healthService.updatePartnerConnection(
        connected: partnerConnected,
        connectedAt: partnerConnectedAt,
      );

      // Handle partner steps for today
      final todayDateKey = StepsHealthService.todayDateKey;
      final todaySteps = data['partnerTodaySteps'] as int?;
      if (todaySteps != null) {
        _healthService.updatePartnerSteps(
          dateKey: todayDateKey,
          steps: todaySteps,
          syncTime: DateTime.now(),
        );
      }

      // Handle partner steps for yesterday
      final yesterdayDateKey = StepsHealthService.yesterdayDateKey;
      final yesterdaySteps = data['partnerYesterdaySteps'] as int?;
      if (yesterdaySteps != null) {
        _healthService.updatePartnerSteps(
          dateKey: yesterdayDateKey,
          steps: yesterdaySteps,
          syncTime: DateTime.now(),
        );
      }

      // Handle claim status
      final claimedBy = data['yesterdayClaimedBy'] as String?;
      if (claimedBy != null) {
        _healthService.markAsClaimedFromSync(yesterdayDateKey);
      }

      Logger.info('Loaded partner data from Supabase', service: 'steps');
    } catch (e, stackTrace) {
      Logger.error('Error loading partner data', error: e, stackTrace: stackTrace, service: 'steps');
    }
  }

  /// Generate couple ID from two user IDs (consistent ordering)
  static String generateCoupleId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  /// Dispose of resources
  void dispose() {
    stopPolling();
    _currentCoupleId = null;
    _currentUserId = null;
  }

  // ============================================================================
  // DEPRECATED METHODS (kept for backward compatibility)
  // ============================================================================

  /// @deprecated Use startPolling() instead
  void startListening() {
    startPolling();
  }

  /// @deprecated Use stopPolling() instead
  void stopListening() {
    stopPolling();
  }

  /// @deprecated Use syncStepsToServer() instead
  Future<void> syncStepsToFirebase() async {
    return syncStepsToServer();
  }

  /// @deprecated Use syncYesterdayToServer() instead
  Future<void> syncYesterdayToFirebase() async {
    return syncYesterdayToServer();
  }

  /// @deprecated Use markClaimedInServer() instead
  Future<void> markClaimedInFirebase(String dateKey) async {
    return markClaimedInServer(dateKey);
  }

  /// @deprecated Use loadPartnerDataFromServer() instead
  Future<void> loadPartnerDataFromFirebase() async {
    return loadPartnerDataFromServer();
  }

  /// @deprecated Server handles cleanup automatically
  Future<void> cleanupOldData() async {
    // No-op - server handles its own cleanup
    Logger.debug('cleanupOldData() is deprecated - server handles cleanup', service: 'steps');
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/logger.dart';
import 'storage_service.dart';
import 'user_profile_service.dart';
import 'quest_initialization_service.dart';
import 'love_point_service.dart';
import 'unlock_service.dart';
import 'home_polling_service.dart';
import 'notification_service.dart';

/// Bootstrap state machine for app initialization
///
/// Represents the sequential phases of app startup:
/// - initial: Not started yet
/// - restoring: Restoring user/partner data from server
/// - syncing: Syncing quests, LP, and unlock state
/// - polling: Polling for latest completion status
/// - ready: All done - safe to show MainScreen
/// - error: Something failed (show error UI with retry)
enum BootstrapState {
  initial,
  restoring,
  syncing,
  polling,
  ready,
  error,
}

/// Centralized service for app initialization before showing MainScreen
///
/// This service consolidates all initialization logic that was previously
/// scattered across AuthWrapper, HomeScreen, PairingScreen, etc.
///
/// Benefits:
/// - Single debugging point for all startup issues
/// - Clear state machine - easy to understand app readiness
/// - No race conditions - sequential phases with dependencies
/// - Better UX - loading screen with progress messages
///
/// Usage:
/// ```dart
/// // In AuthWrapper build():
/// if (!AppBootstrapService.instance.isReady) {
///   AppBootstrapService.instance.bootstrap();
///   return LoadingScreen(state: AppBootstrapService.instance.state);
/// }
/// return MainScreen();
/// ```
class AppBootstrapService extends ChangeNotifier {
  static final AppBootstrapService _instance = AppBootstrapService._internal();
  static AppBootstrapService get instance => _instance;
  AppBootstrapService._internal();

  // Dependencies
  final StorageService _storage = StorageService();
  final UserProfileService _profileService = UserProfileService();
  final UnlockService _unlockService = UnlockService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // State
  BootstrapState _state = BootstrapState.initial;
  String? _errorMessage;
  bool _isBootstrapping = false;

  /// Current bootstrap state
  BootstrapState get state => _state;

  /// Error message if state is [BootstrapState.error]
  String? get errorMessage => _errorMessage;

  /// Whether bootstrap has completed successfully
  bool get isReady => _state == BootstrapState.ready;

  /// Whether bootstrap is currently in progress
  bool get isBootstrapping => _isBootstrapping;

  /// Bootstrap the app for an authenticated, paired user
  ///
  /// This method is idempotent - calling it multiple times is safe.
  /// Returns immediately if already ready or currently bootstrapping.
  ///
  /// Phases:
  /// 1. Restore user/partner from server (handles device switching)
  /// 2. Sync quests, LP, and unlock state in parallel
  /// 3. Poll for latest completion status
  Future<void> bootstrap() async {
    // Skip if already ready or in progress
    if (_state == BootstrapState.ready) {
      Logger.debug('Bootstrap: already ready, skipping', service: 'bootstrap');
      return;
    }

    if (_isBootstrapping) {
      Logger.debug('Bootstrap: already in progress, skipping', service: 'bootstrap');
      return;
    }

    _isBootstrapping = true;
    _errorMessage = null;

    try {
      // Phase 1: Restore user and partner from server
      _setState(BootstrapState.restoring);
      await _restoreUserAndPartner();

      // Phase 2: Sync quests, LP, and unlock state in parallel
      _setState(BootstrapState.syncing);
      await Future.wait([
        _syncQuests(),
        _syncLovePoints(),
        _fetchUnlockState(),
      ]);

      // Phase 3: Poll for latest completion status
      _setState(BootstrapState.polling);
      await _pollCompletionStatus();

      // Done!
      _setState(BootstrapState.ready);
      Logger.success('Bootstrap completed successfully', service: 'bootstrap');
    } catch (e, stackTrace) {
      Logger.error('Bootstrap failed', error: e, stackTrace: stackTrace, service: 'bootstrap');
      _errorMessage = e.toString();
      _setState(BootstrapState.error);
    } finally {
      _isBootstrapping = false;
    }
  }

  /// Reset bootstrap state (call on logout)
  ///
  /// This allows bootstrap to run again on the next login.
  void reset() {
    Logger.debug('Bootstrap: resetting state', service: 'bootstrap');
    _state = BootstrapState.initial;
    _errorMessage = null;
    _isBootstrapping = false;
    notifyListeners();
  }

  /// Retry bootstrap after an error
  Future<void> retry() async {
    if (_state != BootstrapState.error) return;

    Logger.debug('Bootstrap: retrying after error', service: 'bootstrap');
    _state = BootstrapState.initial;
    _errorMessage = null;
    await bootstrap();
  }

  // ============================================================================
  // Private Methods
  // ============================================================================

  void _setState(BootstrapState newState) {
    if (_state != newState) {
      Logger.debug('Bootstrap: $_state → $newState', service: 'bootstrap');
      _state = newState;
      notifyListeners();
    }
  }

  /// Phase 1: Restore user and partner from server
  ///
  /// Handles device switching - ensures local storage has correct user/partner.
  Future<void> _restoreUserAndPartner() async {
    try {
      // Check if user already exists locally
      final localUser = _storage.getUser();
      final localPartner = _storage.getPartner();

      if (localUser != null && localPartner != null) {
        Logger.debug('Bootstrap: user and partner already in local storage', service: 'bootstrap');
        // Still fetch to ensure data is fresh and handle name changes
        await _profileService.getProfile();
        return;
      }

      // Fetch from server
      Logger.debug('Bootstrap: fetching user/partner from server', service: 'bootstrap');
      final result = await _profileService.getProfile();

      // Save coupleId to secure storage if paired
      if (result.isPaired && result.coupleId != null) {
        await _secureStorage.write(key: 'couple_id', value: result.coupleId);
        Logger.debug('Bootstrap: saved coupleId ${result.coupleId}', service: 'bootstrap');
      }

      // Sync push token to server (await to ensure it completes)
      await NotificationService.syncTokenToServer();

      Logger.debug(
        'Bootstrap: restored user=${result.user.name}, partner=${result.partner?.name}',
        service: 'bootstrap',
      );
    } catch (e) {
      Logger.error('Bootstrap: failed to restore user/partner', error: e, service: 'bootstrap');
      // Don't rethrow - we might still have local data
      // Let subsequent phases fail if data is truly missing
    }
  }

  /// Phase 2a: Sync daily quests
  Future<void> _syncQuests() async {
    try {
      final questService = QuestInitializationService();
      final result = await questService.ensureQuestsInitialized();

      Logger.debug(
        'Bootstrap: quests synced - ${result.questCount} quests, status=${result.status}',
        service: 'bootstrap',
      );
    } catch (e) {
      Logger.error('Bootstrap: failed to sync quests', error: e, service: 'bootstrap');
      // Don't rethrow - quests not syncing shouldn't block the entire app
    }
  }

  /// Phase 2b: Sync Love Points from server
  Future<void> _syncLovePoints() async {
    try {
      await LovePointService.fetchAndSyncFromServer();
      Logger.debug('Bootstrap: LP synced', service: 'bootstrap');
    } catch (e) {
      Logger.error('Bootstrap: failed to sync LP', error: e, service: 'bootstrap');
      // Don't rethrow - LP not syncing shouldn't block the entire app
    }
  }

  /// Phase 2c: Fetch unlock state
  Future<void> _fetchUnlockState() async {
    try {
      await _unlockService.getUnlockState(forceRefresh: true);
      Logger.debug('Bootstrap: unlock state fetched', service: 'bootstrap');
    } catch (e) {
      Logger.error('Bootstrap: failed to fetch unlock state', error: e, service: 'bootstrap');
      // Don't rethrow - unlock state not fetching shouldn't block the entire app
    }
  }

  /// Phase 3: Poll for latest completion status
  ///
  /// This ensures quests show correct completion state immediately.
  Future<void> _pollCompletionStatus() async {
    try {
      await HomePollingService().pollNow();
      Logger.debug('Bootstrap: polled completion status', service: 'bootstrap');
    } catch (e) {
      Logger.error('Bootstrap: poll failed', error: e, service: 'bootstrap');
      // Don't rethrow - polling failure shouldn't block the entire app
    }
  }

  // ============================================================================
  // Debug/Testing
  // ============================================================================

  /// Get human-readable status message for current state
  String get statusMessage {
    switch (_state) {
      case BootstrapState.initial:
        return 'Starting...';
      case BootstrapState.restoring:
        return 'Restoring your data...';
      case BootstrapState.syncing:
        return 'Syncing quests...';
      case BootstrapState.polling:
        return 'Almost ready...';
      case BootstrapState.ready:
        return 'Ready!';
      case BootstrapState.error:
        return 'Something went wrong';
    }
  }
}

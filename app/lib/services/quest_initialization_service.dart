import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/logger.dart';
import '../models/daily_quest.dart';
import 'storage_service.dart';
import 'quest_sync_service.dart';
import 'daily_quest_service.dart';
import 'quest_type_manager.dart';
import 'quest_utilities.dart';
import 'couple_preferences_service.dart';
import 'steps_feature_service.dart';

/// Status of quest initialization operation
enum QuestInitStatus {
  /// Quests were synced from server or generated successfully
  success,

  /// Quests already existed locally for today
  alreadyExists,

  /// Cannot initialize - no user or partner paired yet
  notPaired,

  /// Network error during sync (may still have local quests)
  networkError,

  /// Unexpected error occurred
  unknownError,
}

/// Result of quest initialization operation
class QuestInitResult {
  final QuestInitStatus status;
  final int questCount;
  final String? errorMessage;

  /// Whether quests were newly synced/generated (not already existing)
  final bool wasNewlyInitialized;

  const QuestInitResult({
    required this.status,
    this.questCount = 0,
    this.errorMessage,
    this.wasNewlyInitialized = false,
  });

  bool get isSuccess =>
      status == QuestInitStatus.success ||
      status == QuestInitStatus.alreadyExists;

  @override
  String toString() =>
      'QuestInitResult(status: $status, questCount: $questCount, wasNewlyInitialized: $wasNewlyInitialized)';
}

/// Centralized service for initializing daily quests
///
/// Handles syncing/generating quests from server. Called by AppBootstrapService
/// as part of the app initialization flow.
///
/// The service is idempotent - safe to call multiple times. If quests already
/// exist locally for today, it returns [QuestInitStatus.alreadyExists] without
/// making any network calls.
///
/// Also initializes related services:
/// - CouplePreferencesService (for "who goes first" settings)
/// - StepsFeatureService (iOS only)
class QuestInitializationService {
  final StorageService _storage;

  QuestInitializationService({StorageService? storage})
      : _storage = storage ?? StorageService();

  /// Ensures daily quests are initialized for today
  ///
  /// This method is idempotent - calling it multiple times is safe and efficient.
  ///
  /// Flow:
  /// 1. Validate user and partner exist (return [notPaired] if not)
  /// 2. Check if local quests exist for today (return [alreadyExists] if so)
  /// 3. Try to sync from server
  /// 4. If server has no quests, generate new ones
  /// 5. Return success with quest count
  ///
  /// Also initializes related services:
  /// - CouplePreferencesService (for "who goes first" settings)
  /// - StepsFeatureService (iOS only)
  Future<QuestInitResult> ensureQuestsInitialized() async {
    try {
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      // Step 1: Validate user and partner exist
      if (user == null || partner == null) {
        Logger.debug('Quest init skipped - not paired yet', service: 'quest-init');
        return const QuestInitResult(
          status: QuestInitStatus.notPaired,
          errorMessage: 'User or partner not found',
        );
      }

      // Step 2: Check if quests already exist locally
      var existingQuests = _storage.getTodayQuests();
      final questsAlreadyExisted = existingQuests.isNotEmpty;
      final needsMetadataRefresh = questsAlreadyExisted && _questsNeedMetadataRefresh(existingQuests);

      if (questsAlreadyExisted && !needsMetadataRefresh) {
        Logger.debug(
          'Quest init: ${existingQuests.length} quests already exist locally with metadata',
          service: 'quest-init',
        );
      } else {
        if (needsMetadataRefresh) {
          Logger.debug(
            'Quest init: ${existingQuests.length} quests exist but missing metadata - syncing...',
            service: 'quest-init',
          );
        }

        // Initialize related services (moved from main.dart)
        if (!questsAlreadyExisted) {
          await _initializeRelatedServices(user.id, partner.pushToken);
        }

        // Step 3: Try to sync from server (also refreshes metadata for existing quests)
        Logger.debug('Attempting to sync quests from server...', service: 'quest-init');

        final questService = DailyQuestService(storage: _storage);
        final syncService = QuestSyncService(storage: _storage);
        final questTypeManager = QuestTypeManager(
          storage: _storage,
          questService: questService,
          syncService: syncService,
        );

        final synced = await syncService.syncTodayQuests(
          currentUserId: user.id,
          partnerUserId: partner.pushToken,
        );

        if (synced) {
          existingQuests = questService.getTodayQuests();
          Logger.success(
            'Quests synced from server: ${existingQuests.length} quests',
            service: 'quest-init',
          );
        } else {
          // Step 4: No quests on server - generate new ones
          Logger.debug('No quests on server - generating new ones...', service: 'quest-init');
          existingQuests = await questTypeManager.generateDailyQuests(
            currentUserId: user.id,
            partnerUserId: partner.pushToken,
          );
          Logger.success(
            'Quests generated: ${existingQuests.length} quests',
            service: 'quest-init',
          );
        }
      }

      // Note: Polling for completion status is now handled by AppBootstrapService
      // which calls this service then polls afterwards

      return QuestInitResult(
        status: questsAlreadyExisted ? QuestInitStatus.alreadyExists : QuestInitStatus.success,
        questCount: existingQuests.length,
        wasNewlyInitialized: !questsAlreadyExisted,
      );
    } catch (e, stackTrace) {
      Logger.error(
        'Quest initialization failed',
        error: e,
        stackTrace: stackTrace,
        service: 'quest-init',
      );

      // Check if we have any local quests despite the error
      final localQuests = _storage.getTodayQuests();
      if (localQuests.isNotEmpty) {
        return QuestInitResult(
          status: QuestInitStatus.networkError,
          questCount: localQuests.length,
          errorMessage: e.toString(),
        );
      }

      return QuestInitResult(
        status: QuestInitStatus.unknownError,
        errorMessage: e.toString(),
      );
    }
  }

  /// Initialize related services that depend on having a partner
  ///
  /// This logic was previously in main.dart's _initializeDailyQuests()
  Future<void> _initializeRelatedServices(String userId, String partnerToken) async {
    try {
      // Start listening for couple preference updates
      CouplePreferencesService.startListening();
      Logger.debug('Couple preferences listener initialized', service: 'quest-init');

      // Initialize Steps Together feature (iOS only)
      if (!kIsWeb && Platform.isIOS) {
        final coupleId = QuestUtilities.generateCoupleId(userId, partnerToken);
        await StepsFeatureService().initialize(
          coupleId: coupleId,
          userId: userId,
        );
        Logger.debug('Steps feature service initialized', service: 'quest-init');

        // Sync steps on initialization
        await StepsFeatureService().syncSteps();
        Logger.debug('Initial steps sync completed', service: 'quest-init');
      }
    } catch (e) {
      // Don't fail quest initialization if related services fail
      Logger.error('Failed to initialize related services', error: e, service: 'quest-init');
    }
  }

  /// Check if any quests are missing metadata (quizName)
  ///
  /// Used to determine if we need to sync from server even though
  /// quests exist locally, to populate quiz titles/descriptions.
  bool _questsNeedMetadataRefresh(List<DailyQuest> quests) {
    for (final quest in quests) {
      // Quiz-type quests should have a quizName
      if (quest.type == QuestType.quiz &&
          (quest.quizName == null || quest.quizName!.isEmpty)) {
        return true;
      }
    }
    return false;
  }
}

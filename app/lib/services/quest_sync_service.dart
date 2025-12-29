import '../models/daily_quest.dart';
import '../models/quiz_progression_state.dart';
import '../services/storage_service.dart';
import '../services/quest_utilities.dart';
import '../services/api_client.dart';
import '../utils/logger.dart';

/// Service for synchronizing daily quests via Supabase API
///
/// Uses "first user creates, second user loads" pattern to ensure
/// both partners get identical daily quests.
///
/// Architecture (Supabase-only):
/// - First device generates quests → POST /api/sync/daily-quests
/// - Second device loads quests → GET /api/sync/daily-quests
/// - Quest completion → handled by game-specific APIs
class QuestSyncService {
  final StorageService _storage;
  final ApiClient _apiClient = ApiClient();

  QuestSyncService({
    required StorageService storage,
  }) : _storage = storage;

  /// Sync today's quests from Supabase or indicate new ones need generation
  ///
  /// Returns true if sync was successful (quests exist locally or were loaded)
  /// Returns false if quests need to be generated
  Future<bool> syncTodayQuests({
    required String currentUserId,
    required String partnerUserId,
  }) async {
    try {
      final dateKey = QuestUtilities.getTodayDateKey();

      Logger.debug('🔄 Quest Sync Check (Supabase):', service: 'quest');
      Logger.debug('   Date Key: $dateKey', service: 'quest');

      // Server handles race conditions with ON CONFLICT DO NOTHING
      // No need for arbitrary delays - both devices can safely try to upload

      // Try to fetch from Supabase
      Logger.debug('   📡 Checking Supabase for existing quests...', service: 'quest');
      final response = await _apiClient.get('/api/sync/daily-quests?date=$dateKey');

      if (response.success && response.data != null) {
        final questsData = response.data['quests'] as List?;

        if (questsData != null && questsData.isNotEmpty) {
          // Quests exist in Supabase - validate local quests match
          final supabaseQuestIds = questsData.map((q) => q['id'] as String).toSet();
          final localQuests = _storage.getTodayQuests();

          if (localQuests.isNotEmpty) {
            final localQuestIds = localQuests.map((q) => q.id).toSet();

            if (supabaseQuestIds.difference(localQuestIds).isEmpty &&
                localQuestIds.difference(supabaseQuestIds).isEmpty) {
              // Quest IDs match - update metadata from enriched API response
              // This ensures quiz titles/descriptions are populated even for existing quests
              Logger.debug('   ✅ Local quests match Supabase, updating metadata...', service: 'quest');
              await _updateLocalQuestsWithMetadata(questsData, dateKey);
              return true;
            } else {
              // Quest IDs don't match - replace with Supabase
              Logger.debug('   ⚠️  Local quest IDs don\'t match Supabase!', service: 'quest');
              Logger.debug('   Supabase IDs: $supabaseQuestIds', service: 'quest');
              Logger.debug('   Local IDs: $localQuestIds', service: 'quest');
              Logger.debug('   🔄 Replacing local quests with Supabase quests...', service: 'quest');

              // Clear local quests
              for (final quest in localQuests) {
                await quest.delete();
              }
            }
          }

          // Load quests from Supabase
          Logger.debug('   ✅ Loading quests from Supabase...', service: 'quest');
          await _loadQuestsFromSupabase(questsData, dateKey);
          return true;
        }
      }

      // No quests in Supabase yet
      final localQuests = _storage.getTodayQuests();
      if (localQuests.isNotEmpty) {
        // Local quests exist but not in Supabase - try to upload them
        // This handles the case where initial upload failed
        Logger.debug('   ⚠️  Local quests exist but not in Supabase - attempting upload...', service: 'quest');
        try {
          await saveQuestsToSupabase(
            quests: localQuests,
            currentUserId: currentUserId,
            partnerUserId: partnerUserId,
          );
          Logger.debug('   ✅ Successfully uploaded local quests to Supabase', service: 'quest');
        } catch (e) {
          Logger.warn('   ⚠️  Failed to upload local quests: $e', service: 'quest');
          // Continue anyway - local quests will work for this device
        }
        return true;
      } else {
        // No quests anywhere - need to generate
        Logger.debug('   ⚠️  No quests in Supabase or locally - will generate new ones', service: 'quest');
        return false;
      }
    } catch (e) {
      Logger.error('Error syncing quests from Supabase', error: e, service: 'quest');
      return false;
    }
  }

  /// Save generated quests to Supabase
  ///
  /// The API returns enriched quests with quiz metadata (title, description).
  /// We update local quests with this metadata so the home screen shows it immediately.
  Future<void> saveQuestsToSupabase({
    required List<DailyQuest> quests,
    required String currentUserId,
    required String partnerUserId,
    QuizProgressionState? progressionState,
  }) async {
    try {
      final dateKey = QuestUtilities.getTodayDateKey();

      Logger.debug('🚀 Saving quests to Supabase...', service: 'quest');

      final response = await _apiClient.post('/api/sync/daily-quests', body: {
        'dateKey': dateKey,
        'quests': quests.map((q) => ({
          'id': q.id,
          'questType': _getQuestTypeString(q.type),
          'contentId': q.contentId,
          'sortOrder': q.sortOrder,
          'isSideQuest': q.isSideQuest,
          'formatType': q.formatType,
          'quizName': q.quizName,
        })).toList(),
      });

      if (response.success) {
        Logger.success('Saved ${quests.length} quests to Supabase', service: 'quest');

        // Update local quests with enriched metadata from API response
        final enrichedQuests = response.data?['quests'] as List?;
        if (enrichedQuests != null) {
          await _updateLocalQuestsWithMetadata(enrichedQuests, dateKey);
        }
      } else {
        Logger.error('Failed to save quests to Supabase: ${response.error}', service: 'quest');
        throw Exception('Failed to save quests to Supabase');
      }
    } catch (e) {
      Logger.error('Error saving quests to Supabase', error: e, service: 'quest');
      rethrow;
    }
  }

  /// Update local quests with enriched metadata from API response
  Future<void> _updateLocalQuestsWithMetadata(
    List<dynamic> enrichedQuests,
    String dateKey,
  ) async {
    for (final questData in enrichedQuests) {
      final questMap = questData as Map<String, dynamic>;
      final questId = questMap['id'] as String;
      final metadata = questMap['metadata'] as Map<String, dynamic>?;

      if (metadata == null) continue;

      final quizName = metadata['quizName'] as String?;
      final quizDescription = metadata['quizDescription'] as String?;

      // Update local quest with enriched metadata
      final localQuest = _storage.getDailyQuest(questId);
      if (localQuest != null) {
        bool updated = false;

        if (quizName != null && (localQuest.quizName == null || localQuest.quizName!.isEmpty)) {
          localQuest.quizName = quizName;
          updated = true;
        }
        if (quizDescription != null && (localQuest.description == null || localQuest.description!.isEmpty)) {
          localQuest.description = quizDescription;
          updated = true;
        }

        if (updated) {
          await _storage.saveDailyQuest(localQuest);
          Logger.debug('Updated quest $questId with metadata: $quizName', service: 'quest');
        }
      }
    }
  }

  /// Load quests from Supabase API response
  Future<void> _loadQuestsFromSupabase(
    List<dynamic> questsData,
    String dateKey,
  ) async {
    try {
      final now = DateTime.now();
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      for (final questData in questsData) {
        final questMap = questData as Map<String, dynamic>;
        final questId = questMap['id'] as String;

        // Check if quest already exists locally with completion data
        final existingQuest = _storage.getDailyQuest(questId);
        if (existingQuest != null &&
            (existingQuest.status == 'completed' ||
             (existingQuest.userCompletions?.isNotEmpty ?? false))) {
          // Preserve existing quest with completion data - don't overwrite
          Logger.debug(
            'Preserving existing quest $questId with status=${existingQuest.status}',
            service: 'quest',
          );
          continue;
        }

        // Parse metadata
        final metadata = questMap['metadata'] as Map<String, dynamic>?;
        final formatType = metadata?['formatType'] as String? ?? 'classic';
        final quizName = metadata?['quizName'] as String?;
        final quizDescription = metadata?['quizDescription'] as String?;

        // Parse quest type from string
        final questTypeStr = questMap['quest_type'] as String;
        final questType = _parseQuestType(questTypeStr);

        // Create DailyQuest from Supabase data
        final quest = DailyQuest(
          id: questId,
          dateKey: dateKey,
          questType: questType,
          contentId: questMap['content_id'] as String,
          createdAt: now,
          expiresAt: endOfDay,
          status: 'pending',
          sortOrder: questMap['sort_order'] as int,
          isSideQuest: questMap['is_side_quest'] as bool? ?? false,
          formatType: formatType,
          quizName: quizName,
          description: quizDescription,
          userCompletions: null,
        );

        // Save locally
        await _storage.saveDailyQuest(quest);
      }

      Logger.success('Loaded ${questsData.length} quests from Supabase', service: 'quest');
    } catch (e) {
      Logger.error('Error loading quests from Supabase', error: e, service: 'quest');
      rethrow;
    }
  }

  /// Parse quest type string to int (for DailyQuest model)
  int _parseQuestType(String questTypeStr) {
    // Map quest type strings to their int values
    // These match the QuestType enum values
    // Support both snake_case (database) and camelCase (legacy) formats
    switch (questTypeStr.toLowerCase()) {
      case 'quiz':
        return 1; // QuestType.quiz
      case 'you_or_me':
      case 'youorme': // camelCase lowercase
        return 3; // QuestType.youOrMe
      case 'linked':
        return 4; // QuestType.linked
      case 'word_search':
      case 'wordsearch': // camelCase lowercase
        return 5; // QuestType.wordSearch
      case 'steps':
        return 6; // QuestType.steps
      default:
        Logger.warn('Unknown quest type: $questTypeStr, defaulting to quiz', service: 'quest');
        return 1; // Default to quiz
    }
  }

  /// Get quest type string from QuestType enum
  String _getQuestTypeString(QuestType type) {
    return type.name; // Returns 'quiz', 'youOrMe', etc.
  }

  /// Mark quest as completed for current user in Supabase
  Future<void> markQuestCompleted({
    required String questId,
    required String currentUserId,
    required String partnerUserId,
  }) async {
    try {
      Logger.debug('Marking quest $questId as completed in Supabase', service: 'quest');

      final response = await _apiClient.post('/api/sync/daily-quests/completion', body: {
        'quest_id': questId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (response.success) {
        Logger.success('Quest $questId marked as completed', service: 'quest');
      } else {
        Logger.error('Failed to mark quest completed: ${response.error}', service: 'quest');
      }
    } catch (e) {
      Logger.error('Error marking quest completed in Supabase', error: e, service: 'quest');
    }
  }

  /// Load quiz progression state from Supabase
  /// Note: Quiz progression is now managed server-side via branch_progression table
  Future<QuizProgressionState?> loadProgressionState({
    required String currentUserId,
    required String partnerUserId,
  }) async {
    // Progression state is now handled server-side
    // Local cache is populated when quests are loaded
    final coupleId = QuestUtilities.generateCoupleId(currentUserId, partnerUserId);
    return _storage.getQuizProgressionState(coupleId);
  }

  /// Save quiz progression state
  /// Note: Quiz progression is now managed server-side
  Future<void> saveProgressionState(QuizProgressionState state) async {
    // Save locally for caching purposes
    await _storage.saveQuizProgressionState(state);
    Logger.debug('Saved progression state locally', service: 'quest');
  }

  /// Clean up old quest data (local only - server handles its own cleanup)
  Future<void> cleanupOldQuests({
    required String currentUserId,
    required String partnerUserId,
  }) async {
    // Local cleanup only - server handles database cleanup
    try {
      final allQuests = _storage.dailyQuestsBox.values.toList();
      final now = DateTime.now();

      for (final quest in allQuests) {
        if (now.difference(quest.createdAt).inDays > 7) {
          await quest.delete();
          Logger.debug('Cleaned up old quest: ${quest.id}', service: 'quest');
        }
      }
    } catch (e) {
      Logger.error('Error cleaning up old quests', error: e, service: 'quest');
    }
  }
}

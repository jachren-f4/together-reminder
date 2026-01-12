import '../models/daily_quest.dart';
import '../models/quiz_progression_state.dart';
import '../models/quiz_session.dart';
import '../models/branch_progression_state.dart';
import '../services/storage_service.dart';
import '../services/daily_quest_service.dart';
import '../services/quest_sync_service.dart';
import '../services/quest_utilities.dart';
import '../services/quiz_service.dart';
import '../services/quiz_question_bank.dart';
import '../services/affirmation_quiz_bank.dart';
import '../services/you_or_me_service.dart';
import '../services/branch_progression_service.dart';
import '../services/branch_manifest_service.dart';
import '../services/api_client.dart';
import '../utils/logger.dart';

/// Interface for quest providers
///
/// Each quest type (quiz, game, etc.) implements this interface
abstract class QuestProvider {
  /// The quest type this provider handles
  QuestType get questType;

  /// Generate a quest for the given date
  ///
  /// Returns the content ID for the generated quest
  /// [coupleId] is used for branch progression tracking
  Future<String?> generateQuest({
    required String dateKey,
    required String currentUserId,
    required String partnerUserId,
    required String coupleId,
    QuizProgressionState? progressionState,
  });

  /// Validate that a quest can be completed
  ///
  /// Returns true if the quest is valid and can be marked as completed
  Future<bool> validateCompletion({
    required String contentId,
    required String userId,
  });
}

/// Configuration for quiz track mapping
class TrackConfig {
  final String? categoryFilter;
  final int? difficulty;
  final String formatType;

  TrackConfig({
    this.categoryFilter,
    this.difficulty,
    this.formatType = 'classic',
  });
}

/// Quest provider for quiz-based quests
///
/// REUSES existing QuizService and question bank
/// Maps track progression to category/tier filters
/// Loads content from the appropriate branch based on progression
class QuizQuestProvider implements QuestProvider {
  final StorageService _storage;
  final QuizService _quizService;
  final BranchProgressionService _branchService;

  QuizQuestProvider({
    required StorageService storage,
    QuizService? quizService,
    BranchProgressionService? branchService,
  })  : _storage = storage,
        _quizService = quizService ?? QuizService(),
        _branchService = branchService ?? BranchProgressionService();

  @override
  QuestType get questType => QuestType.quiz;

  /// Map track/position to quiz configuration
  /// Positions 1 and 3 in each track are affirmations (50% distribution)
  TrackConfig _getTrackConfig(int track, int position) {
    // Track 0: Relationship Foundation (tier 1, lighter topics)
    // Pattern: Classic, Affirmation, Classic, Affirmation
    if (track == 0) {
      switch (position) {
        case 0:
          return TrackConfig(categoryFilter: 'favorites', difficulty: 1);
        case 1:
          // Affirmation: Trust and early connection
          return TrackConfig(
            categoryFilter: 'trust',
            formatType: 'affirmation',
          );
        case 2:
          return TrackConfig(categoryFilter: 'personality', difficulty: 1);
        case 3:
          // Affirmation: Emotional support and shared moments
          return TrackConfig(
            categoryFilter: 'emotional_support',
            formatType: 'affirmation',
          );
      }
    }

    // Track 1: Communication & Conflict (tier 2-3, deeper categories)
    // Pattern: Classic, Affirmation, Classic, Affirmation
    if (track == 1) {
      switch (position) {
        case 0:
          return TrackConfig(categoryFilter: 'communication', difficulty: 2);
        case 1:
          // Affirmation: Trust (already progressed from Track 0)
          return TrackConfig(
            categoryFilter: 'trust',
            formatType: 'affirmation',
          );
        case 2:
          return TrackConfig(categoryFilter: 'preferences', difficulty: 2);
        case 3:
          // Affirmation: Emotional support (deeper questions)
          return TrackConfig(
            categoryFilter: 'emotional_support',
            formatType: 'affirmation',
          );
      }
    }

    // Track 2: Future & Growth (tier 3-4, advanced categories)
    // Pattern: Classic, Affirmation, Classic, Affirmation
    if (track == 2) {
      switch (position) {
        case 0:
          return TrackConfig(categoryFilter: 'future', difficulty: 3);
        case 1:
          // Affirmation: Trust (most advanced)
          return TrackConfig(
            categoryFilter: 'trust',
            formatType: 'affirmation',
          );
        case 2:
          return TrackConfig(categoryFilter: 'growth', difficulty: 3);
        case 3:
          // Affirmation: Emotional support (most advanced)
          return TrackConfig(
            categoryFilter: 'emotional_support',
            formatType: 'affirmation',
          );
      }
    }

    // Fallback
    return TrackConfig(categoryFilter: 'favorites', difficulty: 1);
  }

  @override
  Future<String?> generateQuest({
    required String dateKey,
    required String currentUserId,
    required String partnerUserId,
    required String coupleId,
    QuizProgressionState? progressionState,
  }) async {
    try {
      // Use progression state to determine which quiz to assign
      if (progressionState == null) {
        Logger.debug('No progression state provided, cannot generate quiz quest', service: 'quest');
        return null;
      }

      // Get configuration for current track/position
      final config = _getTrackConfig(
        progressionState.currentTrack,
        progressionState.currentPosition,
      );

      Logger.debug('Generating quiz quest: Track ${progressionState.currentTrack}, '
          'Position ${progressionState.currentPosition}, '
          'Category: ${config.categoryFilter}, Difficulty: ${config.difficulty}', service: 'quest');

      // SERVER-AUTHORITATIVE: Return semantic key instead of creating session locally.
      // The session will be created on-demand when the user opens the quiz.
      // Format: "quiz:{formatType}:{dateKey}" - this allows the API to create/return
      // the same session for both partners without race conditions.
      final semanticKey = 'quiz:${config.formatType}:$dateKey';
      Logger.debug('Generated semantic key for quiz: $semanticKey', service: 'quest');

      return semanticKey;
    } catch (e) {
      Logger.error('Error generating quiz quest', error: e, service: 'quest');
      return null;
    }
  }

  @override
  Future<bool> validateCompletion({
    required String contentId,
    required String userId,
  }) async {
    try {
      QuizSession? session;

      // Handle semantic key format (quiz:{formatType}:{dateKey})
      if (contentId.startsWith('quiz:')) {
        final parts = contentId.split(':');
        if (parts.length >= 3) {
          final formatType = parts[1];
          final dateKey = parts[2];
          // Find session by date and format
          session = _findSessionByDateAndFormat(dateKey, formatType);
        }
      } else {
        // Traditional UUID lookup
        session = _storage.getQuizSession(contentId);
      }

      if (session == null) {
        Logger.debug('Quiz session not found: $contentId', service: 'quest');
        return false;
      }

      // Check if user has answered all questions
      final userAnswers = session.answers?[userId];
      if (userAnswers == null || userAnswers.isEmpty) {
        Logger.debug('User $userId has not answered quiz $contentId', service: 'quest');
        return false;
      }

      // Must have answered all questions
      if (userAnswers.length < session.questionIds.length) {
        Logger.debug('User $userId has not answered all questions in quiz $contentId', service: 'quest');
        return false;
      }

      return true;
    } catch (e) {
      Logger.error('Error validating quiz completion', error: e, service: 'quest');
      return false;
    }
  }

  /// Find session by date and format type from local storage
  QuizSession? _findSessionByDateAndFormat(String dateKey, String formatType) {
    final allSessions = _storage.getAllQuizSessions();
    for (final session in allSessions) {
      final sessionDate = session.createdAt.toIso8601String().substring(0, 10);
      if (sessionDate == dateKey && session.formatType == formatType) {
        return session;
      }
    }
    return null;
  }
}

/// Quest provider for You or Me game quests
class YouOrMeQuestProvider implements QuestProvider {
  final YouOrMeService _youOrMeService;
  final BranchProgressionService _branchService;

  YouOrMeQuestProvider({
    YouOrMeService? youOrMeService,
    BranchProgressionService? branchService,
  })  : _youOrMeService = youOrMeService ?? YouOrMeService(),
        _branchService = branchService ?? BranchProgressionService();

  @override
  QuestType get questType => QuestType.youOrMe;

  @override
  Future<String?> generateQuest({
    required String dateKey,
    required String currentUserId,
    required String partnerUserId,
    required String coupleId,
    QuizProgressionState? progressionState,
  }) async {
    try {
      // Load content from the appropriate branch
      final branch = await _branchService.getCurrentBranch(
        coupleId: coupleId,
        activityType: BranchableActivityType.youOrMe,
      );
      Logger.debug('Loading You or Me content from branch: $branch', service: 'quest');
      await _youOrMeService.loadQuestionsWithBranch(branch);

      // Create single shared You or Me session (both users will use same ID)
      final session = await _youOrMeService.generateSession(
        userId: currentUserId,
        partnerId: partnerUserId,
        questId: null, // Will be set by DailyQuest
      );

      Logger.debug('Generated You or Me session: ${session.id} (shared by both users)', service: 'quest');
      return session.id;
    } catch (e) {
      Logger.error('Error generating You or Me quest', error: e, service: 'quest');
      return null;
    }
  }

  @override
  Future<bool> validateCompletion({
    required String contentId,
    required String userId,
  }) async {
    try {
      final session = await _youOrMeService.getSession(contentId);
      if (session == null) {
        Logger.debug('You or Me session not found: $contentId', service: 'quest');
        return false;
      }

      // Check if user has answered all 10 questions
      return session.hasUserAnswered(userId);
    } catch (e) {
      Logger.error('Error validating You or Me completion', error: e, service: 'quest');
      return false;
    }
  }
}

/// Manager for coordinating quest generation across different quest types
///
/// Uses the provider pattern to support multiple quest types
/// Manages branch progression for branchable activity types
class QuestTypeManager {
  final StorageService _storage;
  final DailyQuestService _questService;
  final QuestSyncService _syncService;
  final BranchProgressionService _branchService;
  final Map<QuestType, QuestProvider> _providers = {};
  final ApiClient _apiClient = ApiClient();

  QuestTypeManager({
    required StorageService storage,
    required DailyQuestService questService,
    required QuestSyncService syncService,
    BranchProgressionService? branchService,
  })  : _storage = storage,
        _questService = questService,
        _syncService = syncService,
        _branchService = branchService ?? BranchProgressionService() {
    // Register default providers
    registerProvider(QuizQuestProvider(storage: storage, branchService: _branchService));
    registerProvider(YouOrMeQuestProvider(branchService: _branchService));
  }

  /// Register a quest provider
  void registerProvider(QuestProvider provider) {
    _providers[provider.questType] = provider;
    Logger.debug('Registered quest provider for ${provider.questType.name}', service: 'quest');
  }

  /// Generate daily quests for today
  ///
  /// Returns the list of generated quests
  Future<List<DailyQuest>> generateDailyQuests({
    required String currentUserId,
    required String partnerUserId,
  }) async {
    try {
      final dateKey = QuestUtilities.getTodayDateKey();
      final coupleId = QuestUtilities.generateCoupleId(currentUserId, partnerUserId);

      Logger.debug('🆔 Quest Generation:', service: 'quest');
      Logger.debug('   Current User ID: $currentUserId', service: 'quest');
      Logger.debug('   Partner User ID: $partnerUserId', service: 'quest');
      Logger.debug('   Couple ID: $coupleId', service: 'quest');
      Logger.debug('   Date Key: $dateKey', service: 'quest');

      // Check if quests already exist
      if (_questService.hasTodayQuests()) {
        Logger.debug('Daily quests already exist for $dateKey', service: 'quest');
        return _questService.getTodayQuests();
      }

      // Get or create progression state
      var progressionState = _storage.getQuizProgressionState(coupleId);

      if (progressionState == null) {
        // First time - create initial state
        progressionState = QuizProgressionState.initial(coupleId);
        await _storage.saveQuizProgressionState(progressionState);

        // Save to Firebase
        await _syncService.saveProgressionState(progressionState);
      } else {
        // Load latest from Firebase
        final firebaseState = await _syncService.loadProgressionState(
          currentUserId: currentUserId,
          partnerUserId: partnerUserId,
        );
        if (firebaseState != null) {
          progressionState = firebaseState;
        }
      }

      // Generate 3 daily quests: 1 Classic + 1 Affirmation + 1 You or Me
      // Use local variables for iteration - don't modify progression until completion
      int track = progressionState.currentTrack;
      int position = progressionState.currentPosition;

      final quests = <DailyQuest>[];

      for (int i = 0; i < 3; i++) {
        // Determine quest type and format for this slot
        late final QuestType questType;
        String? forcedFormatType;
        switch (i) {
          case 0:
            questType = QuestType.quiz;
            forcedFormatType = 'classic';
            break;
          case 1:
            questType = QuestType.quiz;
            forcedFormatType = 'affirmation';
            break;
          case 2:
            questType = QuestType.youOrMe;
            forcedFormatType = null;
            break;
        }

        // Find appropriate position for requested format type
        // Track pattern: [Classic (0), Affirmation (1), Classic (2), Affirmation (3)]
        int targetPosition = position;
        if (forcedFormatType == 'classic') {
          // Positions 0,2 are classic in each track
          if (position % 2 != 0) {
            targetPosition = (position + 1) % 4;
          }
        } else if (forcedFormatType == 'affirmation') {
          // Positions 1,3 are affirmation in each track
          if (position % 2 != 1) {
            targetPosition = (position + 1) % 4;
          }
        }

        Logger.debug('🎯 Generating quest ${i + 1}/3... (Track $track, Position $targetPosition, Format: ${forcedFormatType ?? 'youOrMe'})', service: 'quest');

        // Create a temporary progression state for quiz quests
        final tempState = questType == QuestType.quiz
            ? QuizProgressionState(
                coupleId: progressionState.coupleId,
                currentTrack: track,
                currentPosition: targetPosition,
                completedQuizzes: progressionState.completedQuizzes,
                createdAt: progressionState.createdAt,
                lastCompletedAt: progressionState.lastCompletedAt,
                totalQuizzesCompleted: progressionState.totalQuizzesCompleted,
                hasCompletedAllTracks: progressionState.hasCompletedAllTracks,
              )
            : null;

        final contentId = await _generateQuestContent(
          questType: questType,
          currentUserId: currentUserId,
          partnerUserId: partnerUserId,
          coupleId: coupleId,
          progressionState: tempState,
        );

        if (contentId != null) {
          Logger.debug('✅ Quest ${i + 1} content created: $contentId', service: 'quest');

          // Get format type and quiz name from quiz session (for quiz quests only)
          // For youOrMe quests, use 'youOrMe' as formatType (matches API 'you_or_me' after normalization)
          String formatType = forcedFormatType ?? (questType == QuestType.youOrMe ? 'youOrMe' : 'classic');
          String? quizName;
          String? imagePath;
          String? description;
          if (questType == QuestType.quiz) {
            final session = _storage.getQuizSession(contentId);
            if (session != null) {
              quizName = session.quizName; // Extract quiz name for display
              imagePath = session.imagePath; // Extract image path for carousel
              description = session.description; // Extract description for carousel
            }
          }

          // Get current branch for this quest type (for manifest lookups)
          String? branch;
          BranchableActivityType? activityType;
          try {
            if (questType == QuestType.quiz) {
              activityType = formatType == 'affirmation'
                  ? BranchableActivityType.affirmation
                  : BranchableActivityType.classicQuiz;
            } else if (questType == QuestType.youOrMe) {
              activityType = BranchableActivityType.youOrMe;
            }
            if (activityType != null) {
              branch = await BranchProgressionService().getCurrentBranch(
                coupleId: coupleId,
                activityType: activityType,
              );
              Logger.debug('📂 Quest ${i + 1} branch: $branch', service: 'quest');

              // Try to get manifest data (image and quizName for classic quizzes)
              if (branch != null) {
                final manifest = await BranchManifestService().getManifest(
                  activityType: activityType,
                  branch: branch,
                );

                // Use manifest image if available
                if (manifest.imagePath != null && manifest.imagePath!.isNotEmpty) {
                  imagePath = manifest.imagePath;
                  Logger.debug('🖼️ Quest ${i + 1} using manifest image: $imagePath', service: 'quest');
                }
              }
            }
          } catch (e) {
            Logger.debug('⚠️ Could not get branch for quest ${i + 1}: $e', service: 'quest');
          }

          final quest = DailyQuest.create(
            dateKey: dateKey,
            type: questType,
            contentId: contentId,
            sortOrder: i,
            isSideQuest: false,
            formatType: formatType,
            quizName: quizName,
            imagePath: imagePath,
            description: description,
            branch: branch,
          );

          await _storage.saveDailyQuest(quest);
          quests.add(quest);
          Logger.debug('💾 Quest ${i + 1} saved to storage', service: 'quest');

          // Advance position after generating classic quiz (once per day)
          // This ensures we move through the track positions over time
          if (i == 0) {
            position++;
            if (position >= 4) {
              track++;
              position = 0;
            }
            Logger.debug('📈 Position advanced to Track $track, Position $position for next day', service: 'quest');
          }
        } else {
          Logger.debug('❌ Quest ${i + 1} generation failed - contentId is null', service: 'quest');
        }
      }

      // Don't save progression advancement here - it will be saved when quests are completed
      Logger.debug('ℹ️  Progression state NOT advanced (waiting for quest completion)', service: 'quest');

      // Save quests to Supabase (for partner to load)
      await _syncQuestsToSupabase(
        quests: quests,
        dateKey: dateKey,
      );

      Logger.debug('Generated ${quests.length} daily quests for $dateKey (synced to Supabase)', service: 'quest');

      return quests;
    } catch (e) {
      Logger.error('Error generating daily quests', error: e, service: 'quest');
      return [];
    }
  }

  /// Generate content for a specific quest type
  Future<String?> _generateQuestContent({
    required QuestType questType,
    required String currentUserId,
    required String partnerUserId,
    required String coupleId,
    QuizProgressionState? progressionState,
  }) async {
    final provider = _providers[questType];

    if (provider == null) {
      Logger.error('No provider registered for quest type: ${questType.name}', service: 'quest');
      return null;
    }

    final dateKey = QuestUtilities.getTodayDateKey();

    return await provider.generateQuest(
      dateKey: dateKey,
      currentUserId: currentUserId,
      partnerUserId: partnerUserId,
      coupleId: coupleId,
      progressionState: progressionState,
    );
  }

  /// Complete a quest and validate
  Future<bool> completeQuest({
    required DailyQuest quest,
    required String userId,
  }) async {
    try {
      // Validate completion using provider
      final provider = _providers[quest.type];

      if (provider == null) {
        Logger.error('No provider for quest type: ${quest.type.name}', service: 'quest');
        return false;
      }

      final isValid = await provider.validateCompletion(
        contentId: quest.contentId,
        userId: userId,
      );

      if (!isValid) {
        Logger.debug('Quest completion validation failed', service: 'quest');
        return false;
      }

      // Mark as completed in quest service
      return await _questService.completeQuestForUser(
        questId: quest.id,
        userId: userId,
      );
    } catch (e) {
      Logger.error('Error completing quest', error: e, service: 'quest');
      return false;
    }
  }

  /// Advance quiz progression after completing a quiz quest
  Future<void> advanceQuizProgression({
    required String currentUserId,
    required String partnerUserId,
    required int track,
    required int position,
  }) async {
    try {
      final coupleId = QuestUtilities.generateCoupleId(currentUserId, partnerUserId);
      var progressionState = _storage.getQuizProgressionState(coupleId);

      if (progressionState == null) {
        Logger.debug('No progression state found', service: 'quest');
        return;
      }

      // Mark quiz as completed
      progressionState.completeQuiz(track, position);

      // Save locally and to Firebase
      await _storage.updateQuizProgressionState(progressionState);
      await _syncService.saveProgressionState(progressionState);

      Logger.debug('Advanced quiz progression to Track ${progressionState.currentTrack}, Position ${progressionState.currentPosition}', service: 'quest');
    } catch (e) {
      Logger.error('Error advancing quiz progression', error: e, service: 'quest');
    }
  }

  /// Get current quiz progression state
  QuizProgressionState? getProgressionState(String coupleId) {
    return _storage.getQuizProgressionState(coupleId);
  }

  /// Advance branch progression after completing a branchable quest.
  ///
  /// Call this after a quest is completed to advance to the next branch
  /// for the next quest of the same activity type.
  ///
  /// [quest] - The completed quest
  /// [coupleId] - The couple's ID for progression tracking
  Future<void> advanceBranchProgression({
    required DailyQuest quest,
    required String coupleId,
  }) async {
    try {
      // Determine which activity type to advance based on quest type and format
      BranchableActivityType? activityType;

      switch (quest.type) {
        case QuestType.quiz:
          // Distinguish between classic quiz and affirmation
          activityType = quest.formatType == 'affirmation'
              ? BranchableActivityType.affirmation
              : BranchableActivityType.classicQuiz;
          break;
        case QuestType.youOrMe:
          activityType = BranchableActivityType.youOrMe;
          break;
        case QuestType.linked:
          activityType = BranchableActivityType.linked;
          break;
        case QuestType.wordSearch:
          activityType = BranchableActivityType.wordSearch;
          break;
        default:
          // Not a branchable quest type (deprecated types, etc.)
          Logger.debug(
            'Quest type ${quest.type.name} is not branchable, skipping branch advancement',
            service: 'quest',
          );
          return;
      }

      await _branchService.completeActivity(
        coupleId: coupleId,
        activityType: activityType,
      );

      Logger.info(
        'Advanced branch progression for ${activityType.name}',
        service: 'quest',
      );
    } catch (e) {
      Logger.error('Error advancing branch progression', error: e, service: 'quest');
      // Don't rethrow - branch progression failure shouldn't block quest completion
    }
  }

  /// Sync quests to Supabase (dual-write)
  Future<void> _syncQuestsToSupabase({
    required List<DailyQuest> quests,
    required String dateKey,
  }) async {
    try {
      final response = await _apiClient.post('/api/sync/daily-quests', body: {
        'quests': quests.map((q) => ({
          'id': q.id,
          'questType': q.type.name,
          'contentId': q.contentId,
          'sortOrder': q.sortOrder,
          'isSideQuest': q.isSideQuest,
          'formatType': q.formatType,
          'quizName': q.quizName,
        })).toList(),
        'dateKey': dateKey,
      });

      if (response.success) {
        Logger.debug('Daily quests synced to Supabase', service: 'quest');

        // Update local quests with enriched metadata from API response
        final enrichedQuests = response.data?['quests'] as List?;
        if (enrichedQuests != null) {
          await _updateLocalQuestsWithMetadata(enrichedQuests);
        }
      } else {
        Logger.error('Failed to sync daily quests to Supabase: ${response.error}', service: 'quest');
      }
    } catch (e) {
      Logger.error('Error syncing daily quests to Supabase', error: e, service: 'quest');
    }
  }

  /// Update local quests with enriched metadata from API response
  Future<void> _updateLocalQuestsWithMetadata(List<dynamic> enrichedQuests) async {
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
}

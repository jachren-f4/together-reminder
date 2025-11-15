import 'package:flutter/foundation.dart';
import '../models/daily_quest.dart';
import '../models/quiz_progression_state.dart';
import '../models/quiz_session.dart';
import '../services/storage_service.dart';
import '../services/daily_quest_service.dart';
import '../services/quest_sync_service.dart';
import '../services/quest_utilities.dart';
import '../services/quiz_service.dart';

/// Interface for quest providers
///
/// Each quest type (quiz, game, etc.) implements this interface
abstract class QuestProvider {
  /// The quest type this provider handles
  QuestType get questType;

  /// Generate a quest for the given date
  ///
  /// Returns the content ID for the generated quest
  Future<String?> generateQuest({
    required String dateKey,
    required String currentUserId,
    required String partnerUserId,
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
class QuizQuestProvider implements QuestProvider {
  final StorageService _storage;
  final QuizService _quizService;

  QuizQuestProvider({
    required StorageService storage,
    QuizService? quizService,
  })  : _storage = storage,
        _quizService = quizService ?? QuizService();

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
    QuizProgressionState? progressionState,
  }) async {
    try {
      // Use progression state to determine which quiz to assign
      if (progressionState == null) {
        debugPrint('No progression state provided, cannot generate quiz quest');
        return null;
      }

      // Get configuration for current track/position
      final config = _getTrackConfig(
        progressionState.currentTrack,
        progressionState.currentPosition,
      );

      debugPrint('Generating quiz quest: Track ${progressionState.currentTrack}, '
          'Position ${progressionState.currentPosition}, '
          'Category: ${config.categoryFilter}, Difficulty: ${config.difficulty}');

      // Use existing QuizService to create session
      // Skip active check to allow multiple daily quest quizzes
      final session = await _quizService.startQuizSession(
        formatType: config.formatType,
        categoryFilter: config.categoryFilter,
        difficulty: config.difficulty,
        skipActiveCheck: true, // Allow generating 3 daily quests
        isDailyQuest: true, // Mark as daily quest to prevent duplication in inbox
      );

      debugPrint('Created quiz session: ${session.id}');

      // Return session ID as contentId
      return session.id;
    } catch (e) {
      debugPrint('Error generating quiz quest: $e');
      return null;
    }
  }

  @override
  Future<bool> validateCompletion({
    required String contentId,
    required String userId,
  }) async {
    try {
      // Check if quiz session exists and is completed
      final session = _storage.getQuizSession(contentId);

      if (session == null) {
        debugPrint('Quiz session not found: $contentId');
        return false;
      }

      // Check if user has answered all questions
      final userAnswers = session.answers?[userId];
      if (userAnswers == null || userAnswers.isEmpty) {
        debugPrint('User $userId has not answered quiz $contentId');
        return false;
      }

      // Must have answered all questions
      if (userAnswers.length < session.questionIds.length) {
        debugPrint('User $userId has not answered all questions in quiz $contentId');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error validating quiz completion: $e');
      return false;
    }
  }
}

/// Manager for coordinating quest generation across different quest types
///
/// Uses the provider pattern to support multiple quest types
class QuestTypeManager {
  final StorageService _storage;
  final DailyQuestService _questService;
  final QuestSyncService _syncService;
  final Map<QuestType, QuestProvider> _providers = {};

  QuestTypeManager({
    required StorageService storage,
    required DailyQuestService questService,
    required QuestSyncService syncService,
  })  : _storage = storage,
        _questService = questService,
        _syncService = syncService {
    // Register default providers
    registerProvider(QuizQuestProvider(storage: storage));
  }

  /// Register a quest provider
  void registerProvider(QuestProvider provider) {
    _providers[provider.questType] = provider;
    debugPrint('Registered quest provider for ${provider.questType.name}');
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

      debugPrint('🆔 Quest Generation:');
      debugPrint('   Current User ID: $currentUserId');
      debugPrint('   Partner User ID: $partnerUserId');
      debugPrint('   Couple ID: $coupleId');
      debugPrint('   Date Key: $dateKey');

      // Check if quests already exist
      if (_questService.hasTodayQuests()) {
        debugPrint('Daily quests already exist for $dateKey');
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

      // Generate 3 quiz-based daily quests
      // Use local variables for iteration - don't modify progression until completion
      int track = progressionState.currentTrack;
      int position = progressionState.currentPosition;

      final quests = <DailyQuest>[];

      for (int i = 0; i < 3; i++) {
        debugPrint('🎯 Generating quest ${i + 1}/3... (Track $track, Position $position)');

        // Create a temporary progression state for this quest
        final tempState = QuizProgressionState(
          coupleId: progressionState.coupleId,
          currentTrack: track,
          currentPosition: position,
          completedQuizzes: progressionState.completedQuizzes,
          createdAt: progressionState.createdAt,
          lastCompletedAt: progressionState.lastCompletedAt,
          totalQuizzesCompleted: progressionState.totalQuizzesCompleted,
          hasCompletedAllTracks: progressionState.hasCompletedAllTracks,
        );

        final contentId = await _generateQuestContent(
          questType: QuestType.quiz,
          currentUserId: currentUserId,
          partnerUserId: partnerUserId,
          progressionState: tempState,
        );

        if (contentId != null) {
          debugPrint('✅ Quest ${i + 1} content created: $contentId');

          // Get format type and quiz name from quiz session
          String formatType = 'classic';
          String? quizName;
          final session = _storage.getQuizSession(contentId);
          if (session != null) {
            if (session.formatType != null) {
              formatType = session.formatType!;
            }
            quizName = session.quizName; // Extract quiz name for display
          }

          final quest = DailyQuest.create(
            dateKey: dateKey,
            type: QuestType.quiz,
            contentId: contentId,
            sortOrder: i,
            isSideQuest: false,
            formatType: formatType,
            quizName: quizName,
          );

          await _storage.saveDailyQuest(quest);
          quests.add(quest);
          debugPrint('💾 Quest ${i + 1} saved to storage');

          // Advance local variables for next quest generation
          if (i < 2) {
            position++;
            if (position >= 4) {
              track++;
              position = 0;
            }
            debugPrint('📈 Will generate next quest at Track $track, Position $position');
          }
        } else {
          debugPrint('❌ Quest ${i + 1} generation failed - contentId is null');
        }
      }

      // Don't save progression advancement here - it will be saved when quests are completed
      debugPrint('ℹ️  Progression state NOT advanced (waiting for quest completion)');

      // Save quests to Firebase (for partner to load)
      await _syncService.saveQuestsToFirebase(
        quests: quests,
        currentUserId: currentUserId,
        partnerUserId: partnerUserId,
        progressionState: progressionState,
      );

      debugPrint('Generated ${quests.length} daily quests for $dateKey (synced to Firebase)');

      return quests;
    } catch (e) {
      debugPrint('Error generating daily quests: $e');
      return [];
    }
  }

  /// Generate content for a specific quest type
  Future<String?> _generateQuestContent({
    required QuestType questType,
    required String currentUserId,
    required String partnerUserId,
    QuizProgressionState? progressionState,
  }) async {
    final provider = _providers[questType];

    if (provider == null) {
      debugPrint('No provider registered for quest type: ${questType.name}');
      return null;
    }

    final dateKey = QuestUtilities.getTodayDateKey();

    return await provider.generateQuest(
      dateKey: dateKey,
      currentUserId: currentUserId,
      partnerUserId: partnerUserId,
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
        debugPrint('No provider for quest type: ${quest.type.name}');
        return false;
      }

      final isValid = await provider.validateCompletion(
        contentId: quest.contentId,
        userId: userId,
      );

      if (!isValid) {
        debugPrint('Quest completion validation failed');
        return false;
      }

      // Mark as completed in quest service
      return await _questService.completeQuestForUser(
        questId: quest.id,
        userId: userId,
      );
    } catch (e) {
      debugPrint('Error completing quest: $e');
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
        debugPrint('No progression state found');
        return;
      }

      // Mark quiz as completed
      progressionState.completeQuiz(track, position);

      // Save locally and to Firebase
      await _storage.updateQuizProgressionState(progressionState);
      await _syncService.saveProgressionState(progressionState);

      debugPrint('Advanced quiz progression to Track ${progressionState.currentTrack}, Position ${progressionState.currentPosition}');
    } catch (e) {
      debugPrint('Error advancing quiz progression: $e');
    }
  }

  /// Get current quiz progression state
  QuizProgressionState? getProgressionState(String coupleId) {
    return _storage.getQuizProgressionState(coupleId);
  }
}

import 'package:flutter/material.dart';
import '../models/base_session.dart';
import '../models/quest_type_config.dart';
import '../models/daily_quest.dart';
import '../models/quiz_session.dart';
import '../models/you_or_me.dart';
import '../services/storage_service.dart';
import '../services/quiz_service.dart';
import '../services/you_or_me_service.dart';
import '../screens/unified_results_screen.dart';
import '../screens/you_or_me_game_screen.dart';
import '../utils/logger.dart';

/// Centralized navigation service for all quest types
/// Handles routing based on session state and quest type configuration
class QuestNavigationService {
  final StorageService _storage;
  final QuizService _quizService;
  final YouOrMeService _youOrMeService;

  QuestNavigationService({
    StorageService? storage,
    QuizService? quizService,
    YouOrMeService? youOrMeService,
  })  : _storage = storage ?? StorageService(),
        _quizService = quizService ?? QuizService(),
        _youOrMeService = youOrMeService ?? YouOrMeService();

  /// Launch quest from quest card tap
  /// Routes to appropriate screen based on session state
  Future<void> launchQuest(BuildContext context, DailyQuest quest) async {
    try {
      final config = QuestTypeConfigRegistry.get(quest.formatType);
      if (config == null) {
        Logger.error('Unknown quest type: ${quest.formatType}', service: 'navigation');
        throw Exception('Unknown quest type: ${quest.formatType}');
      }

      // Fetch session (tries local first, then Firebase)
      final session = await _getSession(quest);
      if (session == null) {
        Logger.error('Session not found for quest: ${quest.id}', service: 'navigation');
        throw Exception('Session not found: ${quest.contentId}');
      }

      final user = _storage.getUser();
      if (user == null) {
        Logger.error('No user found', service: 'navigation');
        return;
      }

      Logger.debug('Launching quest: ${quest.id}, formatType: ${quest.formatType}, session: ${session.id}', service: 'navigation');

      // Route based on state
      if (_isCompleted(session, quest)) {
        Logger.debug('Quest completed, navigating to results', service: 'navigation');
        await navigateToResults(context, session, config);
      } else if (_hasUserAnswered(session, user.id)) {
        Logger.debug('User answered, navigating to waiting', service: 'navigation');
        await navigateToWaiting(context, session, config);
      } else if (_hasUserStartedAnswering(session, user.id)) {
        // User started but hasn't finished - resume mid-game (skip intro)
        Logger.debug('User started answering, resuming game mid-progress', service: 'navigation');
        await _navigateToResumeGame(context, session, user.id);
      } else {
        Logger.debug('User not answered, navigating to intro (branch: ${quest.branch})', service: 'navigation');
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => config.introBuilder(session, branch: quest.branch),
          ),
        );
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to launch quest', error: e, stackTrace: stackTrace, service: 'navigation');
      rethrow;
    }
  }

  /// Navigate to waiting screen
  /// Uses the quest-type-specific waiting screen (Editorial design)
  Future<void> navigateToWaiting(
    BuildContext context,
    BaseSession session,
    QuestTypeConfig config,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => config.waitingBuilder(session),
      ),
    );
  }

  /// Navigate to results screen
  Future<void> navigateToResults(
    BuildContext context,
    BaseSession session,
    QuestTypeConfig config,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnifiedResultsScreen(
          session: session,
          config: config.resultsConfig,
          contentBuilder: config.resultsContentBuilder,
        ),
      ),
    );
  }

  /// Get session for quest (handles different session types)
  /// Tries local storage first, then fetches from Firebase if needed
  Future<BaseSession?> _getSession(DailyQuest quest) async {
    if (quest.formatType == 'youorme') {
      // Try local first
      var session = _storage.getYouOrMeSession(quest.contentId);
      if (session != null) return session;

      // Fetch from Firebase
      final user = _storage.getUser();
      if (user == null) return null;
      return await _youOrMeService.getUserSessionFromPaired(quest.contentId, user.id);
    } else {
      // Classic, Affirmation, and other quiz types
      // QuizService.getSession() handles local + Firebase fetch
      return await _quizService.getSession(quest.contentId);
    }
  }

  /// Check if quest/session is completed
  bool _isCompleted(BaseSession session, DailyQuest quest) {
    // Check both session completion and quest completion
    // (session might be complete but quest not marked complete yet)
    return session.isCompleted;
  }

  /// Check if user has answered
  bool _hasUserAnswered(BaseSession session, String userId) {
    if (session is QuizSession) {
      return session.hasUserAnswered(userId);
    } else if (session is YouOrMeSession) {
      return session.hasUserAnswered(userId);
    }
    return false;
  }

  /// Check if user has started but not finished answering (for mid-game resume)
  bool _hasUserStartedAnswering(BaseSession session, String userId) {
    if (session is YouOrMeSession) {
      return session.hasUserStartedAnswering(userId);
    }
    // TODO: Add support for other session types if needed
    return false;
  }

  /// Navigate directly to game screen for resuming mid-progress
  Future<void> _navigateToResumeGame(
    BuildContext context,
    BaseSession session,
    String userId,
  ) async {
    if (session is YouOrMeSession) {
      final answerCount = session.getUserAnswerCount(userId);
      final existingAnswers = session.answers?[userId] ?? [];

      Logger.info(
        'Resuming You or Me at question ${answerCount + 1}/${session.questions.length}',
        service: 'navigation',
      );

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => YouOrMeGameScreen(
            session: session,
            initialQuestionIndex: answerCount,
            existingAnswers: existingAnswers,
          ),
        ),
      );
    }
    // TODO: Add support for other session types if needed
  }
}

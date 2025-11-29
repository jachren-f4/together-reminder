import '../models/quiz_match.dart';
import '../services/unified_game_service.dart';
import '../utils/logger.dart';

/// Core service for Classic and Affirmation quizzes
///
/// Now uses UnifiedGameService under the hood.
/// Maintains backward compatibility with existing screens.
class QuizMatchService {
  static final QuizMatchService _instance = QuizMatchService._internal();
  factory QuizMatchService() => _instance;
  QuizMatchService._internal();

  final UnifiedGameService _unifiedService = UnifiedGameService();

  /// Callback for state updates during polling
  void Function(QuizMatchGameState)? _onStateUpdate;

  /// Get or create quiz match for today
  ///
  /// [quizType] - 'classic' or 'affirmation'
  Future<QuizMatchGameState> getOrCreateMatch(String quizType) async {
    try {
      final gameType = quizType == 'affirmation'
          ? GameType.affirmation
          : GameType.classic;

      final response = await _unifiedService.startGame(gameType);

      // Convert to legacy format
      return _convertToGameState(response);
    } catch (e) {
      Logger.error('Failed to get/create quiz match', error: e, service: 'quiz');
      rethrow;
    }
  }

  /// Poll match state by ID (for waiting screens)
  Future<QuizMatchGameState> pollMatchState(String matchId, {String quizType = 'classic'}) async {
    try {
      final gameType = quizType == 'affirmation'
          ? GameType.affirmation
          : GameType.classic;

      final response = await _unifiedService.getMatchState(
        gameType: gameType,
        matchId: matchId,
      );

      return _convertToGameState(response);
    } catch (e) {
      Logger.error('Failed to poll quiz match state', error: e, service: 'quiz');
      rethrow;
    }
  }

  /// Submit answers for quiz
  ///
  /// [matchId] - The match ID
  /// [answers] - Array of answer indices
  /// [quizType] - 'classic' or 'affirmation'
  Future<QuizMatchSubmitResult> submitAnswers({
    required String matchId,
    required List<int> answers,
    String quizType = 'classic',
  }) async {
    try {
      final gameType = quizType == 'affirmation'
          ? GameType.affirmation
          : GameType.classic;

      final response = await _unifiedService.submitAnswers(
        gameType: gameType,
        matchId: matchId,
        answers: answers,
      );

      return QuizMatchSubmitResult(
        success: response.success,
        bothAnswered: response.bothAnswered ?? false,
        isCompleted: response.state.isCompleted,
        matchPercentage: response.result?.matchPercentage,
        lpEarned: response.result?.lpEarned,
      );
    } catch (e) {
      Logger.error('Failed to submit quiz answers', error: e, service: 'quiz');
      rethrow;
    }
  }

  /// Start polling for match updates
  ///
  /// [matchId] - Match to poll
  /// [onUpdate] - Callback when state changes
  /// [intervalSeconds] - Polling interval (default 5s)
  /// [quizType] - 'classic' or 'affirmation'
  void startPolling(
    String matchId, {
    required void Function(QuizMatchGameState) onUpdate,
    int intervalSeconds = 5,
    String quizType = 'classic',
  }) {
    _onStateUpdate = onUpdate;
    stopPolling();

    Logger.info('Starting polling for quiz match: $matchId', service: 'quiz');

    final gameType = quizType == 'affirmation'
        ? GameType.affirmation
        : GameType.classic;

    _unifiedService.startPolling(
      gameType: gameType,
      matchId: matchId,
      onUpdate: (response) {
        final state = _convertToGameState(response);
        _onStateUpdate?.call(state);
      },
      intervalSeconds: intervalSeconds,
    );
  }

  /// Stop polling
  void stopPolling() {
    _unifiedService.stopPolling();
    _onStateUpdate = null;
  }

  /// Dispose resources
  void dispose() {
    stopPolling();
  }

  /// Convert unified API response to legacy QuizMatchGameState
  QuizMatchGameState _convertToGameState(GamePlayResponse response) {
    final match = QuizMatch(
      id: response.match.id,
      quizId: response.match.quizId,
      quizType: response.match.quizType,
      branch: response.match.branch,
      status: response.match.status,
      player1Answers: response.result?.userAnswers ?? [],
      player2Answers: response.result?.partnerAnswers ?? [],
      matchPercentage: response.result?.matchPercentage,
      player1Id: '',  // Not needed for UI
      player2Id: '',  // Not needed for UI
      date: response.match.date,
      createdAt: DateTime.tryParse(response.match.createdAt) ?? DateTime.now(),
      completedAt: response.match.completedAt != null
          ? DateTime.tryParse(response.match.completedAt!)
          : null,
    );

    ServerQuiz? quiz;
    if (response.quiz != null) {
      quiz = ServerQuiz(
        quizId: response.quiz!.id,
        title: response.quiz!.name,
        branch: response.match.branch,
        questions: response.quiz!.questions.map((q) => ServerQuizQuestion(
          id: q.id,
          text: q.text,
          choices: q.choices,
          category: q.category ?? '',
        )).toList(),
      );
    }

    return QuizMatchGameState(
      match: match,
      quiz: quiz,
      hasUserAnswered: response.state.userAnswered,
      hasPartnerAnswered: response.state.partnerAnswered,
      isCompleted: response.state.isCompleted,
      canAnswer: response.state.canSubmit,
    );
  }
}

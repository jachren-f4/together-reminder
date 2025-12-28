import '../models/you_or_me_match.dart';
import '../services/unified_game_service.dart';
import '../utils/logger.dart';

/// Core service for You-or-Me game
///
/// Uses UnifiedGameService for match management.
/// Bulk submission - both partners answer all questions at once.
class YouOrMeMatchService {
  static final YouOrMeMatchService _instance = YouOrMeMatchService._internal();
  factory YouOrMeMatchService() => _instance;
  YouOrMeMatchService._internal();

  final UnifiedGameService _unifiedService = UnifiedGameService();

  /// Callback for state updates during polling
  void Function(YouOrMeGameState)? _onStateUpdate;

  /// Get or create You-or-Me match for today
  ///
  /// Uses UnifiedGameService under the hood.
  Future<YouOrMeGameState> getOrCreateMatch() async {
    try {
      final response = await _unifiedService.startGame(GameType.you_or_me);
      return _convertToGameState(response);
    } catch (e) {
      Logger.error('Failed to get/create You-or-Me match',
          error: e, service: 'you_or_me');
      rethrow;
    }
  }

  /// Poll match state by ID (for waiting screens)
  Future<YouOrMeGameState> pollMatchState(String matchId) async {
    try {
      final response = await _unifiedService.getMatchState(
        gameType: GameType.you_or_me,
        matchId: matchId,
      );
      return _convertToGameState(response);
    } catch (e) {
      Logger.error('Failed to poll You-or-Me match state',
          error: e, service: 'you_or_me');
      rethrow;
    }
  }

  /// Submit all answers at once (bulk submission)
  ///
  /// Uses unified game API (POST /api/sync/game/you_or_me/play).
  /// [matchId] - The match ID
  /// [answers] - List of answers: 'you' (0) or 'me' (1)
  Future<YouOrMeBulkSubmitResult> submitAllAnswers({
    required String matchId,
    required List<String> answers,
  }) async {
    try {
      // Convert string answers to indices: 'you' = 0, 'me' = 1
      final answerIndices = answers.map((a) => a == 'me' ? 1 : 0).toList();

      final response = await _unifiedService.submitAnswers(
        gameType: GameType.you_or_me,
        matchId: matchId,
        answers: answerIndices,
      );

      return YouOrMeBulkSubmitResult(
        success: response.success,
        bothAnswered: response.bothAnswered ?? false,
        isCompleted: response.state.isCompleted,
        matchPercentage: response.result?.matchPercentage,
        lpEarned: response.result?.lpEarned,
        userAnswers: answers,
        partnerAnswers: response.result?.partnerAnswers
            .map((i) => i == 1 ? 'me' : 'you')
            .toList(),
      );
    } catch (e) {
      Logger.error('Failed to submit You-or-Me answers',
          error: e, service: 'you_or_me');
      rethrow;
    }
  }

  /// Start polling for match updates
  ///
  /// [matchId] - Match to poll
  /// [onUpdate] - Callback when state changes
  /// [intervalSeconds] - Polling interval (default 10s)
  void startPolling(
    String matchId, {
    required void Function(YouOrMeGameState) onUpdate,
    int intervalSeconds = 10,
  }) {
    _onStateUpdate = onUpdate;
    stopPolling();

    Logger.info('Starting polling for You-or-Me match: $matchId',
        service: 'you_or_me');

    _unifiedService.startPolling(
      gameType: GameType.you_or_me,
      matchId: matchId,
      onUpdate: (response) {
        final state = _convertToGameState(response);
        _onStateUpdate?.call(state);
      },
      intervalSeconds: intervalSeconds,
    );
  }

  /// Stop polling
  /// [matchId] - If provided, only stops polling for that specific match
  void stopPolling({String? matchId}) {
    _unifiedService.stopPolling(matchId: matchId);
    // UnifiedGameService now manages callbacks per matchId, so we just delegate
  }

  /// Dispose resources
  void dispose() {
    stopPolling();
  }

  /// Convert unified API response to legacy YouOrMeGameState
  YouOrMeGameState _convertToGameState(GamePlayResponse response) {
    // Use server-provided match percentage directly (server handles answer inversion)
    // Convert percentage to match count for display: matchCount = (percentage / 100) * totalQuestions
    final totalQuestions = response.quiz?.questions.length ?? 10;
    final matchPercentage = response.result?.matchPercentage ?? 0;
    final matchCount = ((matchPercentage / 100) * totalQuestions).round();

    final match = YouOrMeMatch(
      id: response.match.id,
      quizId: response.match.quizId,
      branch: response.match.branch,
      status: response.match.status,
      player1Answers: [], // You-or-me uses string answers, handled separately
      player2Answers: [],
      player1AnswerCount: 0, // Will be derived from state
      player2AnswerCount: 0,
      currentTurnUserId: null, // Not directly in unified response
      turnNumber: 1,
      player1Score: matchCount, // Derived from server's matchPercentage
      player2Score: matchCount, // Both see the same match count
      player1Id: '',
      player2Id: '',
      date: response.match.date,
      createdAt: DateTime.tryParse(response.match.createdAt) ?? DateTime.now(),
      completedAt: response.match.completedAt != null
          ? DateTime.tryParse(response.match.completedAt!)
          : null,
    );

    ServerYouOrMeQuiz? quiz;
    if (response.quiz != null) {
      quiz = ServerYouOrMeQuiz(
        quizId: response.quiz!.id,
        title: response.quiz!.name,
        description: response.quiz!.description,
        branch: response.match.branch,
        questions: response.quiz!.questions.map((q) => ServerYouOrMeQuestion(
          id: q.id,
          prompt: q.text.split('\n').first, // First line is prompt
          content: q.text.split('\n').length > 1 ? q.text.split('\n')[1] : q.text,
        )).toList(),
        totalQuestions: response.quiz!.questions.length,
      );
    }

    // Calculate answer counts from state
    final myAnswerCount = response.state.userAnswered ? 10 : 0; // Simplified
    final partnerAnswerCount = response.state.partnerAnswered ? 10 : 0;

    // Extract result data for completed matches (needed for results screen)
    List<String>? userAnswers;
    List<String>? partnerAnswers;
    if (response.result != null) {
      // Convert int answers (0=you, 1=me) to string format
      userAnswers = response.result!.userAnswers
          .map((i) => i == 1 ? 'me' : 'you')
          .toList();
      partnerAnswers = response.result!.partnerAnswers
          .map((i) => i == 1 ? 'me' : 'you')
          .toList();
    }

    final gameState = YouOrMeGameState(
      match: match,
      quiz: quiz,
      isMyTurn: response.state.isMyTurn ?? false,
      canPlay: response.state.canSubmit,
      currentQuestion: 0, // Will be determined by UI
      myAnswerCount: myAnswerCount,
      partnerAnswerCount: partnerAnswerCount,
      myScore: matchCount, // Use calculated match count
      partnerScore: matchCount, // Both see the same match count
      isCompleted: response.state.isCompleted,
      totalQuestions: response.quiz?.questions.length ?? 10,
      matchPercentage: response.result?.matchPercentage,
      userAnswers: userAnswers,
      partnerAnswers: partnerAnswers,
    );

    return gameState;
  }
}

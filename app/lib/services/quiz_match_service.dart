import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../models/quiz_match.dart';
import '../services/auth_service.dart';
import '../utils/logger.dart';

/// Core service for Classic and Affirmation quizzes
///
/// API-first architecture following LinkedService pattern:
/// - Server is single source of truth
/// - Server provides quiz content (questions)
/// - No local quiz generation
/// - Simple 10-second polling for sync
class QuizMatchService {
  static final QuizMatchService _instance = QuizMatchService._internal();
  factory QuizMatchService() => _instance;
  QuizMatchService._internal();

  final AuthService _authService = AuthService();

  /// Polling timer for waiting screens
  Timer? _pollTimer;

  /// Callback for state updates during polling
  void Function(QuizMatchGameState)? _onStateUpdate;

  /// Get API base URL
  String get _apiBaseUrl => SupabaseConfig.apiUrl;

  /// Make API request with authentication headers
  Future<Map<String, dynamic>> _apiRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('$_apiBaseUrl$path');
    final headers = await _authService.getAuthHeaders();
    headers['Content-Type'] = 'application/json';

    http.Response response;

    try {
      switch (method) {
        case 'GET':
          response = await http.get(url, headers: headers);
          break;
        case 'POST':
          response = await http.post(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : '{}',
          );
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'API request failed');
      }
    } catch (e) {
      Logger.error('API request failed: $method $path',
          error: e, service: 'quiz');
      rethrow;
    }
  }

  /// Get local date in YYYY-MM-DD format
  String _getLocalDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Get or create quiz match for today
  ///
  /// This is the main entry point. Server handles:
  /// - Creating match if none exists for today
  /// - Returning existing active match
  /// - Providing quiz content (questions)
  /// - All game state calculation
  ///
  /// [quizType] - 'classic' or 'affirmation'
  Future<QuizMatchGameState> getOrCreateMatch(String quizType) async {
    try {
      final response = await _apiRequest(
        'POST',
        '/api/sync/quiz-match',
        body: {
          'localDate': _getLocalDate(),
          'quizType': quizType,
        },
      );

      final matchData = response['match'];
      final quizData = response['quiz'];
      final gameStateData = response['gameState'];

      final match = QuizMatch.fromJson(matchData);
      final quiz = quizData != null ? ServerQuiz.fromJson(quizData) : null;

      return QuizMatchGameState(
        match: match,
        quiz: quiz,
        hasUserAnswered: gameStateData['hasUserAnswered'] ?? false,
        hasPartnerAnswered: gameStateData['hasPartnerAnswered'] ?? false,
        isCompleted: gameStateData['isCompleted'] ?? false,
        canAnswer: gameStateData['canAnswer'] ?? false,
      );
    } catch (e) {
      Logger.error('Failed to get/create quiz match from API',
          error: e, service: 'quiz');
      rethrow;
    }
  }

  /// Poll match state by ID (for waiting screens)
  Future<QuizMatchGameState> pollMatchState(String matchId) async {
    try {
      final response = await _apiRequest(
        'GET',
        '/api/sync/quiz-match?matchId=$matchId',
      );

      final matchData = response['match'];
      final quizData = response['quiz'];
      final gameStateData = response['gameState'];

      final match = QuizMatch.fromJson(matchData);
      final quiz = quizData != null ? ServerQuiz.fromJson(quizData) : null;

      return QuizMatchGameState(
        match: match,
        quiz: quiz,
        hasUserAnswered: gameStateData['hasUserAnswered'] ?? false,
        hasPartnerAnswered: gameStateData['hasPartnerAnswered'] ?? false,
        isCompleted: gameStateData['isCompleted'] ?? false,
        canAnswer: gameStateData['canAnswer'] ?? false,
      );
    } catch (e) {
      Logger.error('Failed to poll quiz match state', error: e, service: 'quiz');
      rethrow;
    }
  }

  /// Submit answers for quiz
  ///
  /// [matchId] - The match ID
  /// [answers] - Array of answer indices
  Future<QuizMatchSubmitResult> submitAnswers({
    required String matchId,
    required List<int> answers,
  }) async {
    // DEBUG: Log what we're submitting
    print('🔵 [QUIZ DEBUG] submitAnswers called');
    print('🔵 [QUIZ DEBUG] matchId: "$matchId" (length: ${matchId.length})');
    print('🔵 [QUIZ DEBUG] answers: $answers');

    try {
      final response = await _apiRequest(
        'POST',
        '/api/sync/quiz-match/submit',
        body: {
          'matchId': matchId,
          'answers': answers,
        },
      );

      print('🟢 [QUIZ DEBUG] submitAnswers response: $response');
      return QuizMatchSubmitResult.fromJson(response);
    } catch (e) {
      print('🔴 [QUIZ DEBUG] submitAnswers error: $e');
      Logger.error('Failed to submit quiz answers', error: e, service: 'quiz');
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
    required void Function(QuizMatchGameState) onUpdate,
    int intervalSeconds = 10,
  }) {
    _onStateUpdate = onUpdate;
    stopPolling(); // Stop any existing polling

    Logger.info('Starting polling for quiz match: $matchId', service: 'quiz');

    _pollTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) async {
        try {
          final state = await pollMatchState(matchId);
          _onStateUpdate?.call(state);

          // Stop polling if completed
          if (state.isCompleted) {
            Logger.info('Match completed, stopping polling', service: 'quiz');
            stopPolling();
          }
        } catch (e) {
          Logger.error('Polling error', error: e, service: 'quiz');
        }
      },
    );
  }

  /// Stop polling
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _onStateUpdate = null;
  }

  /// Dispose resources
  void dispose() {
    stopPolling();
  }
}

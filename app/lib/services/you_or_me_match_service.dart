import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../models/you_or_me_match.dart';
import '../services/auth_service.dart';
import '../utils/logger.dart';

/// Core service for You-or-Me game
///
/// API-first architecture following LinkedService pattern:
/// - Server is single source of truth
/// - Server provides quiz content (questions)
/// - Turn-based with server-managed currentTurnUserId
/// - Simple 10-second polling for sync
class YouOrMeMatchService {
  static final YouOrMeMatchService _instance = YouOrMeMatchService._internal();
  factory YouOrMeMatchService() => _instance;
  YouOrMeMatchService._internal();

  final AuthService _authService = AuthService();

  /// Polling timer for waiting screens
  Timer? _pollTimer;

  /// Callback for state updates during polling
  void Function(YouOrMeGameState)? _onStateUpdate;

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
          error: e, service: 'you_or_me');
      rethrow;
    }
  }

  /// Get local date in YYYY-MM-DD format
  String _getLocalDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Get or create You-or-Me match for today
  ///
  /// This is the main entry point. Server handles:
  /// - Creating match if none exists for today
  /// - Returning existing active match
  /// - Providing quiz content (questions)
  /// - Turn management
  Future<YouOrMeGameState> getOrCreateMatch() async {
    try {
      final response = await _apiRequest(
        'POST',
        '/api/sync/you-or-me-match',
        body: {
          'localDate': _getLocalDate(),
        },
      );

      final matchData = response['match'];
      final quizData = response['quiz'];
      final gameStateData = response['gameState'];

      final match = YouOrMeMatch.fromJson(matchData);
      final quiz = quizData != null ? ServerYouOrMeQuiz.fromJson(quizData) : null;

      return YouOrMeGameState(
        match: match,
        quiz: quiz,
        isMyTurn: gameStateData['isMyTurn'] ?? false,
        canPlay: gameStateData['canPlay'] ?? false,
        currentQuestion: gameStateData['currentQuestion'] ?? 0,
        myAnswerCount: gameStateData['myAnswerCount'] ?? 0,
        partnerAnswerCount: gameStateData['partnerAnswerCount'] ?? 0,
        myScore: gameStateData['myScore'] ?? 0,
        partnerScore: gameStateData['partnerScore'] ?? 0,
        isCompleted: gameStateData['isCompleted'] ?? false,
        totalQuestions: gameStateData['totalQuestions'] ?? 10,
      );
    } catch (e) {
      Logger.error('Failed to get/create You-or-Me match from API',
          error: e, service: 'you_or_me');
      rethrow;
    }
  }

  /// Poll match state by ID (for waiting screens)
  Future<YouOrMeGameState> pollMatchState(String matchId) async {
    try {
      final response = await _apiRequest(
        'GET',
        '/api/sync/you-or-me-match?matchId=$matchId',
      );

      final matchData = response['match'];
      final quizData = response['quiz'];
      final gameStateData = response['gameState'];

      final match = YouOrMeMatch.fromJson(matchData);
      final quiz = quizData != null ? ServerYouOrMeQuiz.fromJson(quizData) : null;

      return YouOrMeGameState(
        match: match,
        quiz: quiz,
        isMyTurn: gameStateData['isMyTurn'] ?? false,
        canPlay: gameStateData['canPlay'] ?? false,
        currentQuestion: gameStateData['currentQuestion'] ?? 0,
        myAnswerCount: gameStateData['myAnswerCount'] ?? 0,
        partnerAnswerCount: gameStateData['partnerAnswerCount'] ?? 0,
        myScore: gameStateData['myScore'] ?? 0,
        partnerScore: gameStateData['partnerScore'] ?? 0,
        isCompleted: gameStateData['isCompleted'] ?? false,
        totalQuestions: gameStateData['totalQuestions'] ?? 10,
      );
    } catch (e) {
      Logger.error('Failed to poll You-or-Me match state',
          error: e, service: 'you_or_me');
      rethrow;
    }
  }

  /// Submit a single answer for the current question
  ///
  /// [matchId] - The match ID
  /// [questionIndex] - Which question this answer is for
  /// [answer] - 'you' or 'me'
  Future<YouOrMeSubmitResult> submitAnswer({
    required String matchId,
    required int questionIndex,
    required String answer,
  }) async {
    try {
      final response = await _apiRequest(
        'POST',
        '/api/sync/you-or-me-match/submit',
        body: {
          'matchId': matchId,
          'questionIndex': questionIndex,
          'answer': answer,
        },
      );

      return YouOrMeSubmitResult.fromJson(response);
    } catch (e) {
      Logger.error('Failed to submit You-or-Me answer',
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
    stopPolling(); // Stop any existing polling

    Logger.info('Starting polling for You-or-Me match: $matchId',
        service: 'you_or_me');

    _pollTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) async {
        try {
          final state = await pollMatchState(matchId);
          _onStateUpdate?.call(state);

          // Stop polling if completed
          if (state.isCompleted) {
            Logger.info('Match completed, stopping polling',
                service: 'you_or_me');
            stopPolling();
          }
        } catch (e) {
          Logger.error('Polling error', error: e, service: 'you_or_me');
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

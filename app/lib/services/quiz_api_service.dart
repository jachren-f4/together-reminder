import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../models/quiz_session.dart';
import '../models/quiz_question.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../utils/logger.dart';

/// Quiz game state returned from API
class QuizGameState {
  final QuizSession session;
  final bool hasUserAnswered;
  final bool hasPartnerAnswered;
  final bool isCompleted;
  final bool isWaitingForPartner;
  final bool canAnswer;

  QuizGameState({
    required this.session,
    required this.hasUserAnswered,
    required this.hasPartnerAnswered,
    required this.isCompleted,
    required this.isWaitingForPartner,
    required this.canAnswer,
  });
}

/// Submit result from API
class QuizSubmitResult {
  final bool success;
  final bool bothAnswered;
  final bool isCompleted;
  final int? matchPercentage;
  final int? lpEarned;
  final int? alignmentMatches;
  final Map<String, int>? predictionScores;
  final Map<String, List<int>> answers;
  final Map<String, List<int>> predictions;

  QuizSubmitResult({
    required this.success,
    required this.bothAnswered,
    required this.isCompleted,
    this.matchPercentage,
    this.lpEarned,
    this.alignmentMatches,
    this.predictionScores,
    required this.answers,
    required this.predictions,
  });

  factory QuizSubmitResult.fromJson(Map<String, dynamic> json) {
    return QuizSubmitResult(
      success: json['success'] ?? false,
      bothAnswered: json['bothAnswered'] ?? false,
      isCompleted: json['isCompleted'] ?? false,
      matchPercentage: json['matchPercentage'],
      lpEarned: json['lpEarned'],
      alignmentMatches: json['alignmentMatches'],
      predictionScores: json['predictionScores'] != null
          ? Map<String, int>.from(json['predictionScores'])
          : null,
      answers: _parseAnswersMap(json['answers']),
      predictions: _parseAnswersMap(json['predictions']),
    );
  }

  static Map<String, List<int>> _parseAnswersMap(dynamic data) {
    if (data == null) return {};
    if (data is! Map) return {};
    return Map<String, List<int>>.from(
      data.map((k, v) => MapEntry(k.toString(), List<int>.from(v ?? []))),
    );
  }
}

/// API-first service for Quiz (Classic, Affirmation, Speed Round, Would You Rather)
///
/// Mirrors the LinkedService architecture:
/// - Server is single source of truth
/// - All sessions created server-side
/// - Local caching for offline support
class QuizApiService {
  final StorageService _storage = StorageService();
  final AuthService _authService = AuthService();

  /// Polling timer for waiting screens
  Timer? _pollTimer;

  /// Callback for state updates during polling
  void Function(QuizGameState)? _onStateUpdate;

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
        case 'PATCH':
          response = await http.patch(
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

  /// Create or get quiz session for today
  ///
  /// [formatType] - 'classic', 'affirmation', 'speed_round', 'would_you_rather'
  /// [questions] - Array of question objects
  /// [quizName] - Display name (for affirmation quizzes)
  /// [category] - Category (for affirmation quizzes)
  /// [dailyQuestId] - Link to daily quest
  Future<QuizGameState> createOrGetSession({
    required String formatType,
    required List<Map<String, dynamic>> questions,
    String? quizName,
    String? category,
    String? dailyQuestId,
  }) async {
    try {
      final response = await _apiRequest(
        'POST',
        '/api/sync/quiz',
        body: {
          'date': _getLocalDate(),
          'formatType': formatType,
          'questions': questions,
          'quizName': quizName,
          'category': category,
          'dailyQuestId': dailyQuestId,
        },
      );

      final sessionData = response['session'];
      final session = _parseSessionFromApi(sessionData);

      // Cache locally
      await _storage.saveQuizSession(session);

      return QuizGameState(
        session: session,
        hasUserAnswered: sessionData['hasUserAnswered'] ?? false,
        hasPartnerAnswered: false, // Will be computed from answers
        isCompleted: sessionData['isCompleted'] ?? false,
        isWaitingForPartner: false,
        canAnswer: !(sessionData['hasUserAnswered'] ?? false) &&
            !(sessionData['isCompleted'] ?? false),
      );
    } catch (e) {
      Logger.error('Failed to create/get quiz session',
          error: e, service: 'quiz');

      // Fall back to cached session if available
      final cached = _storage.getActiveQuizSession();
      if (cached != null) {
        Logger.warn('Using cached session (offline mode)', service: 'quiz');
        return QuizGameState(
          session: cached,
          hasUserAnswered: false,
          hasPartnerAnswered: false,
          isCompleted: false,
          isWaitingForPartner: false,
          canAnswer: true,
        );
      }

      rethrow;
    }
  }

  /// Get existing session by date and format type
  Future<QuizGameState?> getSession({
    required String formatType,
    String? date,
  }) async {
    try {
      final queryDate = date ?? _getLocalDate();
      final response = await _apiRequest(
        'GET',
        '/api/sync/quiz?date=$queryDate&formatType=$formatType',
      );

      final sessionData = response['session'];
      final session = _parseSessionFromApi(sessionData);

      // Cache locally
      await _storage.saveQuizSession(session);

      return QuizGameState(
        session: session,
        hasUserAnswered: sessionData['hasUserAnswered'] ?? false,
        hasPartnerAnswered: false,
        isCompleted: sessionData['isCompleted'] ?? false,
        isWaitingForPartner: false,
        canAnswer: !(sessionData['hasUserAnswered'] ?? false) &&
            !(sessionData['isCompleted'] ?? false),
      );
    } catch (e) {
      if (e.toString().contains('NO_SESSION') ||
          e.toString().contains('No session found')) {
        return null;
      }
      Logger.error('Failed to get quiz session', error: e, service: 'quiz');
      rethrow;
    }
  }

  /// Poll session state by ID (for waiting screens)
  Future<QuizGameState> pollSessionState(String sessionId) async {
    try {
      final response = await _apiRequest(
        'GET',
        '/api/sync/quiz/$sessionId',
      );

      final sessionData = response['session'];
      final stateData = response['state'];
      final session = _parseSessionFromApi(sessionData);

      // Update cache
      await _storage.saveQuizSession(session);

      return QuizGameState(
        session: session,
        hasUserAnswered: stateData['hasUserAnswered'] ?? false,
        hasPartnerAnswered: stateData['hasPartnerAnswered'] ?? false,
        isCompleted: stateData['isCompleted'] ?? false,
        isWaitingForPartner: stateData['isWaitingForPartner'] ?? false,
        canAnswer: stateData['canAnswer'] ?? false,
      );
    } catch (e) {
      Logger.error('Failed to poll quiz session', error: e, service: 'quiz');
      rethrow;
    }
  }

  /// Submit answers for quiz
  ///
  /// [sessionId] - The session ID
  /// [answers] - Array of answer indices
  /// [predictions] - Optional predictions for Would You Rather
  Future<QuizSubmitResult> submitAnswers({
    required String sessionId,
    required List<int> answers,
    List<int>? predictions,
  }) async {
    try {
      final body = <String, dynamic>{
        'sessionId': sessionId,
        'answers': answers,
      };

      if (predictions != null) {
        body['predictions'] = predictions;
      }

      final response = await _apiRequest(
        'POST',
        '/api/sync/quiz/submit',
        body: body,
      );

      return QuizSubmitResult.fromJson(response);
    } catch (e) {
      Logger.error('Failed to submit quiz answers', error: e, service: 'quiz');
      rethrow;
    }
  }

  /// Start polling for session updates
  ///
  /// [sessionId] - Session to poll
  /// [onUpdate] - Callback when state changes
  /// [intervalSeconds] - Polling interval (default 10s)
  void startPolling(
    String sessionId, {
    required void Function(QuizGameState) onUpdate,
    int intervalSeconds = 10,
  }) {
    _onStateUpdate = onUpdate;
    stopPolling(); // Stop any existing polling

    Logger.info('Starting polling for session: $sessionId', service: 'quiz');

    _pollTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) async {
        try {
          final state = await pollSessionState(sessionId);
          _onStateUpdate?.call(state);

          // Stop polling if completed
          if (state.isCompleted) {
            Logger.info('Session completed, stopping polling', service: 'quiz');
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

  /// Parse session from API response and save questions to local storage
  QuizSession _parseSessionFromApi(Map<String, dynamic> data) {
    final answers = _parseAnswersMap(data['answers']);
    final predictions = _parseAnswersMap(data['predictions']);
    final predictionScores = data['predictionScores'] != null
        ? Map<String, int>.from(
            (data['predictionScores'] as Map).map(
              (k, v) => MapEntry(k.toString(), v as int),
            ),
          )
        : <String, int>{};

    // Parse questions and save to local storage
    final questions = (data['questions'] as List?)
            ?.map((q) => q as Map<String, dynamic>)
            .toList() ??
        [];
    final questionIds = questions.map((q) => q['id']?.toString() ?? '').toList();

    // CRITICAL FIX: Save questions to local storage so partner device can access them
    // Without this, getSessionQuestions() fails on the partner's device because
    // they don't have the questions in their local Hive storage
    for (final qData in questions) {
      final question = QuizQuestion(
        id: qData['id']?.toString() ?? '',
        question: qData['text']?.toString() ?? '',
        options: (qData['choices'] as List?)?.map((c) => c.toString()).toList() ?? [],
        correctAnswerIndex: 0, // Not used for couple quizzes
        category: qData['category']?.toString() ?? 'general',
      );
      _storage.saveQuizQuestion(question);
    }

    final session = QuizSession(
      id: data['id'] ?? '',
      questionIds: questionIds,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
      expiresAt: data['expiresAt'] != null
          ? DateTime.parse(data['expiresAt'])
          : DateTime.now().add(const Duration(hours: 24)),
      status: data['status'] ?? 'waiting_for_answers',
      initiatedBy: data['initiatedBy'] ?? '',
      subjectUserId: data['subjectUserId'] ?? data['initiatedBy'] ?? '',
      formatType: data['formatType'] ?? 'classic',
      quizName: data['quizName'],
      category: data['category'],
      isDailyQuest: data['isDailyQuest'] ?? false,
      dailyQuestId: data['dailyQuestId'] ?? '',
      answers: answers,
    );

    session.matchPercentage = data['matchPercentage'];
    session.lpEarned = data['lpEarned'];
    session.alignmentMatches = data['alignmentMatches'];
    session.predictionScores = predictionScores;
    session.predictions = predictions;
    session.completedAt = data['completedAt'] != null
        ? DateTime.parse(data['completedAt'])
        : null;

    return session;
  }

  /// Parse answers map from API response
  Map<String, List<int>> _parseAnswersMap(dynamic data) {
    if (data == null) return {};
    if (data is! Map) return {};
    return Map<String, List<int>>.from(
      data.map((k, v) => MapEntry(k.toString(), List<int>.from(v ?? []))),
    );
  }

  /// Update daily quest content_id in Supabase
  /// Called when local session ID is updated to match server-generated ID
  Future<void> updateDailyQuestContentId(String questId, String newContentId) async {
    await _apiRequest(
      'PATCH',
      '/api/sync/daily-quests',
      body: {
        'questId': questId,
        'contentId': newContentId,
      },
    );
  }

  /// Dispose resources
  void dispose() {
    stopPolling();
  }
}

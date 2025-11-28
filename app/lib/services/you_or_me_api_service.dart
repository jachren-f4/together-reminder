import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../models/you_or_me.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../utils/logger.dart';

/// You or Me game state returned from API
class YouOrMeGameState {
  final YouOrMeSession session;
  final int userAnswerCount;
  final int partnerAnswerCount;
  final int totalQuestions;
  final bool userComplete;
  final bool partnerComplete;
  final bool isCompleted;
  final bool isWaitingForPartner;
  final bool canAnswer;
  final int userProgressPercent;
  final int partnerProgressPercent;

  YouOrMeGameState({
    required this.session,
    required this.userAnswerCount,
    required this.partnerAnswerCount,
    required this.totalQuestions,
    required this.userComplete,
    required this.partnerComplete,
    required this.isCompleted,
    required this.isWaitingForPartner,
    required this.canAnswer,
    required this.userProgressPercent,
    required this.partnerProgressPercent,
  });
}

/// Submit result from You or Me API
class YouOrMeSubmitResult {
  final bool success;
  final int userAnswerCount;
  final int partnerAnswerCount;
  final int totalQuestions;
  final bool userComplete;
  final bool partnerComplete;
  final bool isCompleted;
  final int? lpEarned;
  final Map<String, List<YouOrMeAnswer>> answers;

  YouOrMeSubmitResult({
    required this.success,
    required this.userAnswerCount,
    required this.partnerAnswerCount,
    required this.totalQuestions,
    required this.userComplete,
    required this.partnerComplete,
    required this.isCompleted,
    this.lpEarned,
    required this.answers,
  });

  factory YouOrMeSubmitResult.fromJson(Map<String, dynamic> json) {
    return YouOrMeSubmitResult(
      success: json['success'] ?? false,
      userAnswerCount: json['userAnswerCount'] ?? 0,
      partnerAnswerCount: json['partnerAnswerCount'] ?? 0,
      totalQuestions: json['totalQuestions'] ?? 10,
      userComplete: json['userComplete'] ?? false,
      partnerComplete: json['partnerComplete'] ?? false,
      isCompleted: json['isCompleted'] ?? false,
      lpEarned: json['lpEarned'],
      answers: _parseAnswersMap(json['answers']),
    );
  }

  static Map<String, List<YouOrMeAnswer>> _parseAnswersMap(dynamic data) {
    if (data == null) return {};
    if (data is! Map) return {};

    final result = <String, List<YouOrMeAnswer>>{};
    for (final entry in data.entries) {
      final userId = entry.key.toString();
      final answersList = entry.value as List?;
      if (answersList != null) {
        result[userId] = answersList.map((a) {
          if (a is Map) {
            return YouOrMeAnswer(
              questionId: a['questionId']?.toString() ?? '',
              questionPrompt: a['questionPrompt']?.toString() ?? '',
              questionContent: a['questionContent']?.toString() ?? '',
              answerValue: a['answerValue'] == true,
              answeredAt: a['answeredAt'] != null
                  ? DateTime.parse(a['answeredAt'])
                  : DateTime.now(),
            );
          }
          return YouOrMeAnswer(
            questionId: '',
            questionPrompt: '',
            questionContent: '',
            answerValue: false,
            answeredAt: DateTime.now(),
          );
        }).toList();
      }
    }
    return result;
  }
}

/// API-first service for You or Me game
///
/// Mirrors the LinkedService architecture:
/// - Server is single source of truth
/// - Incremental answer submission (one at a time or bulk)
/// - Local caching for offline support
class YouOrMeApiService {
  final StorageService _storage = StorageService();
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

  /// Create or get You or Me session for today
  ///
  /// [questions] - Array of question objects with id, prompt, content, category
  /// [questId] - Link to daily quest
  /// [branch] - Content branch
  Future<YouOrMeGameState> createOrGetSession({
    required List<YouOrMeQuestion> questions,
    String? questId,
    String? branch,
  }) async {
    try {
      final response = await _apiRequest(
        'POST',
        '/api/sync/you-or-me',
        body: {
          'date': _getLocalDate(),
          'questions': questions.map((q) => q.toMap()).toList(),
          'questId': questId,
          'branch': branch,
        },
      );

      final sessionData = response['session'];
      final session = _parseSessionFromApi(sessionData);

      // Cache locally
      await _storage.saveYouOrMeSession(session);

      final userAnswerCount = sessionData['userAnswerCount'] ?? 0;
      final partnerAnswerCount = sessionData['partnerAnswerCount'] ?? 0;
      final totalQuestions = sessionData['totalQuestions'] ?? questions.length;
      final userComplete = sessionData['hasUserCompleted'] ?? false;
      final partnerComplete = sessionData['hasPartnerCompleted'] ?? false;

      return YouOrMeGameState(
        session: session,
        userAnswerCount: userAnswerCount,
        partnerAnswerCount: partnerAnswerCount,
        totalQuestions: totalQuestions,
        userComplete: userComplete,
        partnerComplete: partnerComplete,
        isCompleted: sessionData['isCompleted'] ?? false,
        isWaitingForPartner: userComplete && !partnerComplete,
        canAnswer: !userComplete && !(sessionData['isCompleted'] ?? false),
        userProgressPercent: totalQuestions > 0
            ? ((userAnswerCount / totalQuestions) * 100).round()
            : 0,
        partnerProgressPercent: totalQuestions > 0
            ? ((partnerAnswerCount / totalQuestions) * 100).round()
            : 0,
      );
    } catch (e) {
      Logger.error('Failed to create/get You or Me session',
          error: e, service: 'you_or_me');

      // Fall back to cached session if available
      // Try to find a session for today
      final cached = _findTodaySession();
      if (cached != null) {
        Logger.warn('Using cached session (offline mode)', service: 'you_or_me');
        return YouOrMeGameState(
          session: cached,
          userAnswerCount: 0,
          partnerAnswerCount: 0,
          totalQuestions: cached.questions.length,
          userComplete: false,
          partnerComplete: false,
          isCompleted: false,
          isWaitingForPartner: false,
          canAnswer: true,
          userProgressPercent: 0,
          partnerProgressPercent: 0,
        );
      }

      rethrow;
    }
  }

  /// Get existing session by date
  Future<YouOrMeGameState?> getSession({String? date}) async {
    try {
      final queryDate = date ?? _getLocalDate();
      final response = await _apiRequest(
        'GET',
        '/api/sync/you-or-me?date=$queryDate',
      );

      final sessionData = response['session'];
      final session = _parseSessionFromApi(sessionData);

      // Cache locally
      await _storage.saveYouOrMeSession(session);

      final userAnswerCount = sessionData['userAnswerCount'] ?? 0;
      final partnerAnswerCount = sessionData['partnerAnswerCount'] ?? 0;
      final totalQuestions = sessionData['totalQuestions'] ?? 10;
      final userComplete = sessionData['hasUserCompleted'] ?? false;
      final partnerComplete = sessionData['hasPartnerCompleted'] ?? false;

      return YouOrMeGameState(
        session: session,
        userAnswerCount: userAnswerCount,
        partnerAnswerCount: partnerAnswerCount,
        totalQuestions: totalQuestions,
        userComplete: userComplete,
        partnerComplete: partnerComplete,
        isCompleted: sessionData['isCompleted'] ?? false,
        isWaitingForPartner: userComplete && !partnerComplete,
        canAnswer: !userComplete && !(sessionData['isCompleted'] ?? false),
        userProgressPercent: totalQuestions > 0
            ? ((userAnswerCount / totalQuestions) * 100).round()
            : 0,
        partnerProgressPercent: totalQuestions > 0
            ? ((partnerAnswerCount / totalQuestions) * 100).round()
            : 0,
      );
    } catch (e) {
      if (e.toString().contains('NO_SESSION') ||
          e.toString().contains('No session found')) {
        return null;
      }
      Logger.error('Failed to get You or Me session',
          error: e, service: 'you_or_me');
      rethrow;
    }
  }

  /// Poll session state by ID (for waiting screens)
  Future<YouOrMeGameState> pollSessionState(String sessionId) async {
    try {
      final response = await _apiRequest(
        'GET',
        '/api/sync/you-or-me/$sessionId',
      );

      final sessionData = response['session'];
      final stateData = response['state'];
      final session = _parseSessionFromApi(sessionData);

      // Update cache
      await _storage.saveYouOrMeSession(session);

      final progressData = stateData['progress'] ?? {};

      return YouOrMeGameState(
        session: session,
        userAnswerCount: stateData['userAnswerCount'] ?? 0,
        partnerAnswerCount: stateData['partnerAnswerCount'] ?? 0,
        totalQuestions: stateData['totalQuestions'] ?? 10,
        userComplete: stateData['userComplete'] ?? false,
        partnerComplete: stateData['partnerComplete'] ?? false,
        isCompleted: stateData['isCompleted'] ?? false,
        isWaitingForPartner: stateData['isWaitingForPartner'] ?? false,
        canAnswer: stateData['canAnswer'] ?? false,
        userProgressPercent: progressData['user'] ?? 0,
        partnerProgressPercent: progressData['partner'] ?? 0,
      );
    } catch (e) {
      Logger.error('Failed to poll You or Me session',
          error: e, service: 'you_or_me');
      rethrow;
    }
  }

  /// Submit a single answer
  ///
  /// [sessionId] - The session ID
  /// [answer] - Single answer object
  Future<YouOrMeSubmitResult> submitAnswer({
    required String sessionId,
    required YouOrMeAnswer answer,
  }) async {
    try {
      final response = await _apiRequest(
        'POST',
        '/api/sync/you-or-me/submit',
        body: {
          'sessionId': sessionId,
          'answer': {
            'questionId': answer.questionId,
            'questionPrompt': answer.questionPrompt,
            'questionContent': answer.questionContent,
            'answerValue': answer.answerValue,
            'answeredAt': answer.answeredAt.toIso8601String(),
          },
        },
      );

      return YouOrMeSubmitResult.fromJson(response);
    } catch (e) {
      Logger.error('Failed to submit You or Me answer',
          error: e, service: 'you_or_me');
      rethrow;
    }
  }

  /// Submit multiple answers at once
  ///
  /// [sessionId] - The session ID
  /// [answers] - List of answer objects
  Future<YouOrMeSubmitResult> submitAnswers({
    required String sessionId,
    required List<YouOrMeAnswer> answers,
  }) async {
    try {
      final response = await _apiRequest(
        'POST',
        '/api/sync/you-or-me/submit',
        body: {
          'sessionId': sessionId,
          'answers': answers
              .map((a) => {
                    'questionId': a.questionId,
                    'questionPrompt': a.questionPrompt,
                    'questionContent': a.questionContent,
                    'answerValue': a.answerValue,
                    'answeredAt': a.answeredAt.toIso8601String(),
                  })
              .toList(),
        },
      );

      return YouOrMeSubmitResult.fromJson(response);
    } catch (e) {
      Logger.error('Failed to submit You or Me answers',
          error: e, service: 'you_or_me');
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
    required void Function(YouOrMeGameState) onUpdate,
    int intervalSeconds = 10,
  }) {
    _onStateUpdate = onUpdate;
    stopPolling(); // Stop any existing polling

    Logger.info('Starting polling for session: $sessionId',
        service: 'you_or_me');

    _pollTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) async {
        try {
          final state = await pollSessionState(sessionId);
          _onStateUpdate?.call(state);

          // Stop polling if completed
          if (state.isCompleted) {
            Logger.info('Session completed, stopping polling',
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

  /// Find today's session from local storage
  YouOrMeSession? _findTodaySession() {
    final today = _getLocalDate();
    final box = _storage.youOrMeSessionsBox;

    for (final session in box.values) {
      // Check if session was created today
      final sessionDate =
          '${session.createdAt.year}-${session.createdAt.month.toString().padLeft(2, '0')}-${session.createdAt.day.toString().padLeft(2, '0')}';
      if (sessionDate == today) {
        return session;
      }
    }
    return null;
  }

  /// Parse session from API response
  YouOrMeSession _parseSessionFromApi(Map<String, dynamic> data) {
    // Parse questions
    final questionsData = data['questions'] as List? ?? [];
    final questions = questionsData.map((q) {
      if (q is Map<String, dynamic>) {
        return YouOrMeQuestion.fromMap(q);
      }
      return YouOrMeQuestion(
        id: '',
        prompt: '',
        content: '',
        category: '',
      );
    }).toList();

    // Parse answers
    final answersMap = <String, List<YouOrMeAnswer>>{};
    final answersData = data['answers'];
    if (answersData != null && answersData is Map) {
      for (final entry in answersData.entries) {
        final userId = entry.key.toString();
        final answersList = entry.value as List?;
        if (answersList != null) {
          answersMap[userId] = answersList.map((a) {
            if (a is Map) {
              return YouOrMeAnswer(
                questionId: a['questionId']?.toString() ?? '',
                questionPrompt: a['questionPrompt']?.toString() ?? '',
                questionContent: a['questionContent']?.toString() ?? '',
                answerValue: a['answerValue'] == true,
                answeredAt: a['answeredAt'] != null
                    ? DateTime.parse(a['answeredAt'])
                    : DateTime.now(),
              );
            }
            return YouOrMeAnswer(
              questionId: '',
              questionPrompt: '',
              questionContent: '',
              answerValue: false,
              answeredAt: DateTime.now(),
            );
          }).toList();
        }
      }
    }

    return YouOrMeSession(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      partnerId: data['partnerId'] ?? '',
      coupleId: data['coupleId'] ?? '',
      questId: data['questId'],
      questions: questions,
      answers: answersMap,
      status: data['status'] ?? 'in_progress',
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
      initiatedBy: data['initiatedBy'] ?? '',
      subjectUserId: data['subjectUserId'] ?? '',
      lpEarned: data['lpEarned'],
      completedAt: data['completedAt'] != null
          ? DateTime.parse(data['completedAt'])
          : null,
    );
  }

  /// Dispose resources
  void dispose() {
    stopPolling();
  }
}

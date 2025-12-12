import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../services/auth_service.dart';
import '../services/love_point_service.dart';
import '../utils/logger.dart';

/// Unified game types
enum GameType {
  classic,
  affirmation,
  you_or_me,
}

extension GameTypeExtension on GameType {
  String get apiPath {
    switch (this) {
      case GameType.classic:
        return 'classic';
      case GameType.affirmation:
        return 'affirmation';
      case GameType.you_or_me:
        return 'you_or_me';
    }
  }
}

/// Match data from unified game API
class GameMatch {
  final String id;
  final String quizId;
  final String quizType;
  final String branch;
  final String status;
  final String date;
  final String createdAt;
  final String? completedAt;

  GameMatch({
    required this.id,
    required this.quizId,
    required this.quizType,
    required this.branch,
    required this.status,
    required this.date,
    required this.createdAt,
    this.completedAt,
  });

  bool get isCompleted => status == 'completed';

  factory GameMatch.fromJson(Map<String, dynamic> json) {
    return GameMatch(
      id: json['id'] ?? '',
      quizId: json['quizId'] ?? '',
      quizType: json['quizType'] ?? '',
      branch: json['branch'] ?? '',
      status: json['status'] ?? 'active',
      date: json['date'] ?? '',
      createdAt: json['createdAt'] ?? '',
      completedAt: json['completedAt'],
    );
  }
}

/// Game state from unified API
class GameState {
  final bool canSubmit;
  final bool userAnswered;
  final bool partnerAnswered;
  final bool isCompleted;
  final bool? isMyTurn;

  GameState({
    required this.canSubmit,
    required this.userAnswered,
    required this.partnerAnswered,
    required this.isCompleted,
    this.isMyTurn,
  });

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      canSubmit: json['canSubmit'] ?? false,
      userAnswered: json['userAnswered'] ?? false,
      partnerAnswered: json['partnerAnswered'] ?? false,
      isCompleted: json['isCompleted'] ?? false,
      isMyTurn: json['isMyTurn'],
    );
  }
}

/// Game result from unified API
class GameResult {
  final int matchPercentage;
  final int lpEarned;
  final List<int> userAnswers;
  final List<int> partnerAnswers;
  final int? userScore;
  final int? partnerScore;

  GameResult({
    required this.matchPercentage,
    required this.lpEarned,
    required this.userAnswers,
    required this.partnerAnswers,
    this.userScore,
    this.partnerScore,
  });

  factory GameResult.fromJson(Map<String, dynamic> json) {
    return GameResult(
      matchPercentage: json['matchPercentage'] ?? 0,
      lpEarned: json['lpEarned'] ?? 0,
      userAnswers: List<int>.from(json['userAnswers'] ?? []),
      partnerAnswers: List<int>.from(json['partnerAnswers'] ?? []),
      userScore: json['userScore'],
      partnerScore: json['partnerScore'],
    );
  }
}

/// Quiz question from server
class GameQuestion {
  final String id;
  final String text;
  final List<String> choices;
  final String? category;

  GameQuestion({
    required this.id,
    required this.text,
    required this.choices,
    this.category,
  });

  factory GameQuestion.fromJson(Map<String, dynamic> json) {
    return GameQuestion(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      choices: List<String>.from(json['choices'] ?? []),
      category: json['category'],
    );
  }
}

/// Quiz data from unified API
class GameQuiz {
  final String id;
  final String name;
  final List<GameQuestion> questions;

  GameQuiz({
    required this.id,
    required this.name,
    required this.questions,
  });

  factory GameQuiz.fromJson(Map<String, dynamic> json) {
    return GameQuiz(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      questions: (json['questions'] as List?)
              ?.map((q) => GameQuestion.fromJson(q))
              .toList() ??
          [],
    );
  }
}

/// Play response from unified API
class GamePlayResponse {
  final bool success;
  final GameMatch match;
  final GameState state;
  final GameQuiz? quiz;
  final GameResult? result;
  final bool isNew;
  final bool? bothAnswered;

  GamePlayResponse({
    required this.success,
    required this.match,
    required this.state,
    this.quiz,
    this.result,
    required this.isNew,
    this.bothAnswered,
  });

  factory GamePlayResponse.fromJson(Map<String, dynamic> json) {
    return GamePlayResponse(
      success: json['success'] ?? false,
      match: GameMatch.fromJson(json['match'] ?? {}),
      state: GameState.fromJson(json['state'] ?? {}),
      quiz: json['quiz'] != null ? GameQuiz.fromJson(json['quiz']) : null,
      result: json['result'] != null ? GameResult.fromJson(json['result']) : null,
      isNew: json['isNew'] ?? false,
      bothAnswered: json['bothAnswered'],
    );
  }
}

/// Game status item from status endpoint
class GameStatusItem {
  final String type;
  final String matchId;
  final String quizId;
  final String branch;
  final String status;
  final bool userAnswered;
  final bool partnerAnswered;
  final bool canSubmit;
  final bool? isMyTurn;
  final bool isCompleted;
  final String createdAt;
  final String? completedAt;
  final int? matchPercentage;
  final int? lpEarned;

  GameStatusItem({
    required this.type,
    required this.matchId,
    required this.quizId,
    required this.branch,
    required this.status,
    required this.userAnswered,
    required this.partnerAnswered,
    required this.canSubmit,
    this.isMyTurn,
    required this.isCompleted,
    required this.createdAt,
    this.completedAt,
    this.matchPercentage,
    this.lpEarned,
  });

  factory GameStatusItem.fromJson(Map<String, dynamic> json) {
    return GameStatusItem(
      type: json['type'] ?? '',
      matchId: json['matchId'] ?? '',
      quizId: json['quizId'] ?? '',
      branch: json['branch'] ?? '',
      status: json['status'] ?? 'active',
      userAnswered: json['userAnswered'] ?? false,
      partnerAnswered: json['partnerAnswered'] ?? false,
      canSubmit: json['canSubmit'] ?? false,
      isMyTurn: json['isMyTurn'],
      isCompleted: json['isCompleted'] ?? false,
      createdAt: json['createdAt'] ?? '',
      completedAt: json['completedAt'],
      matchPercentage: json['matchPercentage'],
      lpEarned: json['lpEarned'],
    );
  }
}

/// Status response from unified API
class GameStatusResponse {
  final bool success;
  final List<GameStatusItem> games;
  final int totalLp;
  final String userId;
  final String partnerId;
  final String date;

  GameStatusResponse({
    required this.success,
    required this.games,
    required this.totalLp,
    required this.userId,
    required this.partnerId,
    required this.date,
  });

  factory GameStatusResponse.fromJson(Map<String, dynamic> json) {
    return GameStatusResponse(
      success: json['success'] ?? false,
      games: (json['games'] as List?)
              ?.map((g) => GameStatusItem.fromJson(g))
              .toList() ??
          [],
      totalLp: json['totalLp'] ?? 0,
      userId: json['userId'] ?? '',
      partnerId: json['partnerId'] ?? '',
      date: json['date'] ?? '',
    );
  }
}

/// Unified Game Service
///
/// Single service for all game types using the new unified API:
/// - POST /api/sync/game/{type}/play - Start/submit games
/// - GET /api/sync/game/status - Poll for all game statuses
class UnifiedGameService {
  static final UnifiedGameService _instance = UnifiedGameService._internal();
  factory UnifiedGameService() => _instance;
  UnifiedGameService._internal();

  final AuthService _authService = AuthService();

  /// Polling timer for waiting screens
  Timer? _pollTimer;

  /// Currently polling match ID (to prevent other screens from killing active polling)
  String? _currentPollingMatchId;

  /// Callback for state updates during polling
  void Function(GamePlayResponse)? _onStateUpdate;

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
      Logger.error('API request failed: $method $path', error: e, service: 'game');
      rethrow;
    }
  }

  /// Get local date in YYYY-MM-DD format
  String _getLocalDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ============================================================================
  // PLAY ENDPOINT - Start/Submit games
  // ============================================================================

  /// Start a new game (get questions)
  ///
  /// [gameType] - Type of game (classic, affirmation, you_or_me)
  Future<GamePlayResponse> startGame(GameType gameType) async {
    try {
      final response = await _apiRequest(
        'POST',
        '/api/sync/game/${gameType.apiPath}/play',
        body: {
          'localDate': _getLocalDate(),
        },
      );

      return GamePlayResponse.fromJson(response);
    } catch (e) {
      Logger.error('Failed to start game', error: e, service: 'game');
      rethrow;
    }
  }

  /// Submit answers to an existing game
  ///
  /// [gameType] - Type of game
  /// [matchId] - The match ID
  /// [answers] - Array of answer indices
  Future<GamePlayResponse> submitAnswers({
    required GameType gameType,
    required String matchId,
    required List<int> answers,
  }) async {
    try {
      final response = await _apiRequest(
        'POST',
        '/api/sync/game/${gameType.apiPath}/play',
        body: {
          'matchId': matchId,
          'answers': answers,
        },
      );

      final gameResponse = GamePlayResponse.fromJson(response);

      // Sync LP immediately when game completes (fixes delay for completing device)
      if (gameResponse.state.isCompleted) {
        await LovePointService.fetchAndSyncFromServer();
      }

      return gameResponse;
    } catch (e) {
      Logger.error('Failed to submit answers', error: e, service: 'game');
      rethrow;
    }
  }

  /// Start game AND submit answers in one call
  ///
  /// [gameType] - Type of game
  /// [answers] - Array of answer indices
  Future<GamePlayResponse> startAndSubmit({
    required GameType gameType,
    required List<int> answers,
  }) async {
    try {
      final response = await _apiRequest(
        'POST',
        '/api/sync/game/${gameType.apiPath}/play',
        body: {
          'localDate': _getLocalDate(),
          'answers': answers,
        },
      );

      final gameResponse = GamePlayResponse.fromJson(response);

      // Sync LP immediately when game completes (fixes delay for completing device)
      if (gameResponse.state.isCompleted) {
        await LovePointService.fetchAndSyncFromServer();
      }

      return gameResponse;
    } catch (e) {
      Logger.error('Failed to start and submit', error: e, service: 'game');
      rethrow;
    }
  }

  /// Get current state of an existing match
  ///
  /// [gameType] - Type of game
  /// [matchId] - The match ID
  Future<GamePlayResponse> getMatchState({
    required GameType gameType,
    required String matchId,
  }) async {
    try {
      final response = await _apiRequest(
        'POST',
        '/api/sync/game/${gameType.apiPath}/play',
        body: {
          'matchId': matchId,
        },
      );

      return GamePlayResponse.fromJson(response);
    } catch (e) {
      Logger.error('Failed to get match state', error: e, service: 'game');
      rethrow;
    }
  }

  // ============================================================================
  // STATUS ENDPOINT - Poll for game statuses
  // ============================================================================

  /// Get status of all games for a date
  ///
  /// [date] - Date in YYYY-MM-DD format (defaults to today)
  /// [gameType] - Optional filter by game type
  Future<GameStatusResponse> getGameStatus({
    String? date,
    GameType? gameType,
  }) async {
    try {
      String path = '/api/sync/game/status';
      final queryParams = <String>[];

      if (date != null) {
        queryParams.add('date=$date');
      }
      if (gameType != null) {
        queryParams.add('type=${gameType.apiPath}');
      }

      if (queryParams.isNotEmpty) {
        path += '?${queryParams.join('&')}';
      }

      final response = await _apiRequest('GET', path);
      final statusResponse = GameStatusResponse.fromJson(response);

      // Sync LP from server to local storage
      await LovePointService.syncTotalLP(statusResponse.totalLp);

      return statusResponse;
    } catch (e) {
      Logger.error('Failed to get game status', error: e, service: 'game');
      rethrow;
    }
  }

  // ============================================================================
  // POLLING
  // ============================================================================

  /// Start polling for match updates
  ///
  /// [gameType] - Type of game
  /// [matchId] - Match to poll
  /// [onUpdate] - Callback when state changes
  /// [intervalSeconds] - Polling interval (default 5s for waiting screens)
  void startPolling({
    required GameType gameType,
    required String matchId,
    required void Function(GamePlayResponse) onUpdate,
    int intervalSeconds = 5,
  }) {
    Logger.info('🎯 UnifiedGameService.startPolling called for match: $matchId, gameType: ${gameType.apiPath}', service: 'quiz');

    // Stop any previous polling first (cancels timer but we'll set callback after)
    _pollTimer?.cancel();
    _pollTimer = null;

    // Track which match is being polled
    _currentPollingMatchId = matchId;

    // Set callback AFTER stopping previous timer (stopPolling() clears the callback)
    _onStateUpdate = onUpdate;

    Logger.info('🎯 Callback set, starting timer with interval ${intervalSeconds}s', service: 'quiz');

    // Immediate poll
    _pollOnce(gameType, matchId);

    // Set up periodic polling
    _pollTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => _pollOnce(gameType, matchId),
    );
    print('🎯 TIMER CREATED: _pollTimer is now ${_pollTimer != null ? "active" : "NULL"}, interval=${intervalSeconds}s, matchId=$matchId');
  }

  void _pollOnce(GameType gameType, String matchId) async {
    // Use Logger.error for critical debug info so it shows in release builds
    print('🎯 POLL: starting for match $matchId (timer active: ${_pollTimer != null})');
    try {
      final state = await getMatchState(gameType: gameType, matchId: matchId);
      print('🎯 POLL: got state - isCompleted=${state.state.isCompleted}, userAnswered=${state.state.userAnswered}, partnerAnswered=${state.state.partnerAnswered}');

      if (_onStateUpdate != null) {
        print('🎯 POLL: firing callback');
        _onStateUpdate?.call(state);
      } else {
        print('🎯 POLL ERROR: callback is NULL - cannot notify waiting screen!');
      }

      // Stop polling if completed
      if (state.state.isCompleted) {
        print('🎯 POLL: match completed, stopping polling');
        stopPolling(force: true);
      }
    } catch (e) {
      print('🎯 POLL ERROR: $e');
    }
  }

  /// Stop polling
  /// [matchId] - If provided, only stops polling if this matches the current polling match
  /// [force] - If true, stops polling regardless of match ID
  /// Returns true if polling was actually stopped, false if ignored
  bool stopPolling({String? matchId, bool force = false}) {
    // Only stop if:
    // 1. force is true (explicit stop request)
    // 2. matchId matches current polling match
    // 3. No matchId provided AND no current polling (cleanup case)
    if (force || matchId == _currentPollingMatchId || (matchId == null && _currentPollingMatchId == null)) {
      print('🛑 STOP POLLING: Stopping (matchId=$matchId, current=$_currentPollingMatchId, force=$force)');
      _pollTimer?.cancel();
      _pollTimer = null;
      _onStateUpdate = null;
      _currentPollingMatchId = null;
      return true;
    } else {
      print('🔵 STOP POLLING IGNORED: Request for $matchId but currently polling $_currentPollingMatchId');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    stopPolling(force: true);
  }
}

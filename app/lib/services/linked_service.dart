import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../models/linked.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../utils/logger.dart';

/// Game state returned from API
class LinkedGameState {
  final LinkedMatch match;
  final LinkedPuzzle? puzzle;
  final bool isMyTurn;
  final bool canPlay;
  final int myScore;
  final int partnerScore;
  final int myVision;
  final int partnerVision;
  final int progressPercent;

  LinkedGameState({
    required this.match,
    this.puzzle,
    required this.isMyTurn,
    required this.canPlay,
    required this.myScore,
    required this.partnerScore,
    required this.myVision,
    required this.partnerVision,
    required this.progressPercent,
  });
}

/// Core service for Linked game logic
///
/// API-first architecture: Server is single source of truth.
/// No local puzzle generation - all matches created server-side.
class LinkedService {
  final StorageService _storage = StorageService();
  final AuthService _authService = AuthService();

  static const int _completionPoints = 30;

  /// Get API base URL - uses centralized config
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
          error: e, service: 'linked');
      rethrow;
    }
  }

  /// Get local date in YYYY-MM-DD format for cooldown check
  String _getLocalDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Get or create active match from API
  ///
  /// This is the main entry point. Server handles:
  /// - Creating match if none exists
  /// - Returning existing active match
  /// - All game state calculation (turns, scores, etc.)
  ///
  /// Throws [LinkedCooldownActiveException] if puzzle cooldown is active.
  Future<LinkedGameState> getOrCreateMatch() async {
    try {
      final response = await _apiRequest(
        'POST',
        '/api/sync/linked',
        body: {'localDate': _getLocalDate()},
      );

      // Check for cooldown response
      if (response['code'] == 'COOLDOWN_ACTIVE') {
        throw LinkedCooldownActiveException(response['message'] ?? 'Next puzzle available tomorrow');
      }

      final matchData = response['match'];
      final puzzleData = response['puzzle'];
      final gameStateData = response['gameState'];

      final match = _parseMatchFromApi(matchData);
      final puzzle = puzzleData != null ? LinkedPuzzle.fromJson(puzzleData) : null;

      // Cache locally
      await _storage.saveLinkedMatch(match);

      return LinkedGameState(
        match: match,
        puzzle: puzzle,
        isMyTurn: gameStateData['isMyTurn'] ?? false,
        canPlay: gameStateData['canPlay'] ?? false,
        myScore: gameStateData['myScore'] ?? 0,
        partnerScore: gameStateData['partnerScore'] ?? 0,
        myVision: gameStateData['myVision'] ?? 2,
        partnerVision: gameStateData['partnerVision'] ?? 2,
        progressPercent: gameStateData['progressPercent'] ?? 0,
      );
    } catch (e) {
      Logger.error('Failed to get/create match from API',
          error: e, service: 'linked');

      // Fall back to cached match if available (read-only mode)
      final cached = _storage.getActiveLinkedMatch();
      if (cached != null) {
        Logger.warn('Using cached match (offline mode)', service: 'linked');
        return LinkedGameState(
          match: cached,
          puzzle: null,
          isMyTurn: false,
          canPlay: false,
          myScore: 0,
          partnerScore: 0,
          myVision: 0,
          partnerVision: 0,
          progressPercent: cached.progressPercent,
        );
      }

      rethrow;
    }
  }

  /// Poll match state by ID (for 10-second polling during partner's turn)
  Future<LinkedGameState> pollMatchState(String matchId) async {
    try {
      final response =
          await _apiRequest('GET', '/api/sync/linked/$matchId');

      final matchData = response['match'];
      final puzzleData = response['puzzle'];
      final gameStateData = response['gameState'];

      final match = _parseMatchFromApi(matchData);
      final puzzle = puzzleData != null ? LinkedPuzzle.fromJson(puzzleData) : null;

      // Update cache
      await _storage.saveLinkedMatch(match);

      return LinkedGameState(
        match: match,
        puzzle: puzzle,
        isMyTurn: gameStateData['isMyTurn'] ?? false,
        canPlay: gameStateData['canPlay'] ?? false,
        myScore: gameStateData['myScore'] ?? 0,
        partnerScore: gameStateData['partnerScore'] ?? 0,
        myVision: gameStateData['myVision'] ?? 2,
        partnerVision: gameStateData['partnerVision'] ?? 2,
        progressPercent: gameStateData['progressPercent'] ?? 0,
      );
    } catch (e) {
      Logger.error('Failed to poll match state', error: e, service: 'linked');
      rethrow;
    }
  }

  /// Refresh game state from API (wrapper for getOrCreateMatch)
  Future<LinkedGameState> refreshGameState() async {
    return getOrCreateMatch();
  }

  /// Parse match from API response
  LinkedMatch _parseMatchFromApi(Map<String, dynamic> data) {
    final boardState = data['boardState'] is Map
        ? Map<String, String>.from(
            (data['boardState'] as Map).map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            ),
          )
        : <String, String>{};

    final currentRack = data['currentRack'] is List
        ? List<String>.from(data['currentRack'])
        : <String>[];

    return LinkedMatch(
      matchId: data['matchId'] ?? '',
      puzzleId: data['puzzleId'] ?? '',
      status: data['status'] ?? 'active',
      boardState: boardState,
      currentRack: currentRack,
      currentTurnUserId: data['currentTurnUserId'],
      turnNumber: data['turnNumber'] ?? 1,
      player1Score: data['player1Score'] ?? 0,
      player2Score: data['player2Score'] ?? 0,
      player1Vision: data['player1Vision'] ?? 2,
      player2Vision: data['player2Vision'] ?? 2,
      lockedCellCount: data['lockedCellCount'] ?? 0,
      totalAnswerCells: data['totalAnswerCells'] ?? 0,
      completedAt: data['completedAt'] != null
          ? DateTime.parse(data['completedAt'])
          : null,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
      coupleId: data['coupleId'],
      player1Id: data['player1Id'],
      player2Id: data['player2Id'],
      winnerId: data['winnerId'],
    );
  }

  /// Submit turn with placements
  Future<LinkedTurnResult> submitTurn(
    String matchId,
    List<LinkedDraftPlacement> placements,
  ) async {
    try {
      final response = await _apiRequest(
        'POST',
        '/api/sync/linked/submit',
        body: {
          'matchId': matchId,
          'placements': placements.map((p) => p.toJson()).toList(),
        },
      );

      return LinkedTurnResult.fromJson(response);
    } catch (e) {
      Logger.error('Failed to submit turn', error: e, service: 'linked');
      throw Exception('Failed to submit turn: $e');
    }
  }

  /// Use hint power-up
  /// [remainingRack] - letters still available after draft placements
  Future<LinkedHintResult> useHint(String matchId, {List<String>? remainingRack}) async {
    try {
      final body = <String, dynamic>{
        'matchId': matchId,
      };
      if (remainingRack != null && remainingRack.isNotEmpty) {
        body['remainingRack'] = remainingRack;
      }

      final response = await _apiRequest(
        'POST',
        '/api/sync/linked/hint',
        body: body,
      );

      return LinkedHintResult.fromJson(response);
    } catch (e) {
      Logger.error('Failed to use hint', error: e, service: 'linked');
      throw Exception('Failed to use hint: $e');
    }
  }

  /// Get card state for match
  LinkedCardState getCardState(LinkedMatch match, String userId) {
    return match.getCardState(userId);
  }

  /// Get progress percentage
  double getProgressPercentage(LinkedMatch match) {
    return match.progressPercentage;
  }

  /// Format score for display
  String formatScore(int score) {
    return score.toString();
  }

  /// Calculate Love Points reward for completing a puzzle
  int getCompletionPoints() {
    return _completionPoints;
  }

  /// Check if game is complete
  bool isGameComplete(LinkedMatch match) {
    return match.isCompleted;
  }

  /// Get time until next puzzle (for countdown)
  Duration? getTimeUntilNextPuzzle() {
    // For now, puzzles are persistent until completion
    // Future: implement daily/weekly rotation
    return null;
  }

  /// Format time remaining for countdown display
  String formatTimeRemaining(Duration? duration) {
    if (duration == null) return '';

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return 'Soon';
    }
  }
}

/// Exception thrown when puzzle cooldown is active (next puzzle tomorrow)
class LinkedCooldownActiveException implements Exception {
  final String message;
  LinkedCooldownActiveException(this.message);

  @override
  String toString() => message;
}


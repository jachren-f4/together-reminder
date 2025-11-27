import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../models/word_search.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../utils/logger.dart';

/// Core service for Word Search game logic
///
/// API-first architecture: Server is single source of truth.
/// No local puzzle generation - all matches created server-side.
class WordSearchService {
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
      } else if (response.statusCode == 403) {
        final error = jsonDecode(response.body);
        throw NotYourTurnException(error['message'] ?? 'Not your turn');
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'API request failed');
      }
    } catch (e) {
      if (e is NotYourTurnException) rethrow;
      Logger.error('API request failed: $method $path',
          error: e, service: 'word_search');
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
  /// Throws [CooldownActiveException] if puzzle cooldown is active.
  Future<WordSearchGameState> getOrCreateMatch() async {
    try {
      final response = await _apiRequest(
        'POST',
        '/api/sync/word-search',
        body: {'localDate': _getLocalDate()},
      );

      // Check for cooldown response
      if (response['code'] == 'COOLDOWN_ACTIVE') {
        throw CooldownActiveException(response['message'] ?? 'Next puzzle available tomorrow');
      }

      final currentUserId = await _authService.getUserId();

      final gameState = WordSearchGameState.fromJson(response, currentUserId ?? '');

      // Cache locally
      await _storage.saveWordSearchMatch(gameState.match);

      return gameState;
    } catch (e) {
      Logger.error('Failed to get/create match from API',
          error: e, service: 'word_search');

      // Fall back to cached match if available (read-only mode)
      final cached = _storage.getActiveWordSearchMatch();
      if (cached != null) {
        Logger.warn('Using cached match (offline mode)', service: 'word_search');
        return WordSearchGameState(
          match: cached,
          puzzle: null,
          isMyTurn: false,
          canPlay: false,
          wordsRemainingThisTurn: 0,
          myWordsFound: 0,
          partnerWordsFound: 0,
          myScore: 0,
          partnerScore: 0,
          myHints: 0,
          partnerHints: 0,
          progressPercent: cached.progressPercentInt,
        );
      }

      rethrow;
    }
  }

  /// Poll match state (for 10-second polling during partner's turn)
  Future<WordSearchGameState> pollMatchState(String matchId) async {
    try {
      final response =
          await _apiRequest('GET', '/api/sync/word-search/$matchId');
      final currentUserId = await _authService.getUserId();

      final gameState = WordSearchGameState.fromJson(response, currentUserId ?? '');

      // Update cache
      await _storage.saveWordSearchMatch(gameState.match);

      return gameState;
    } catch (e) {
      Logger.error('Failed to poll match state', error: e, service: 'word_search');
      rethrow;
    }
  }

  /// Refresh game state from API (wrapper for getOrCreateMatch)
  Future<WordSearchGameState> refreshGameState() async {
    return getOrCreateMatch();
  }

  /// Submit a found word
  ///
  /// Returns result with validation status, points, and turn state
  Future<WordSearchSubmitResult> submitWord({
    required String matchId,
    required String word,
    required List<GridPosition> positions,
  }) async {
    try {
      final response = await _apiRequest(
        'POST',
        '/api/sync/word-search/submit',
        body: {
          'matchId': matchId,
          'word': word.toUpperCase(),
          'positions': positions.map((p) => p.toJson()).toList(),
        },
      );

      return WordSearchSubmitResult.fromJson(response);
    } catch (e) {
      if (e is NotYourTurnException) rethrow;
      Logger.error('Failed to submit word', error: e, service: 'word_search');
      throw Exception('Failed to submit word: $e');
    }
  }

  /// Use hint to reveal first letter position of a random unfound word
  Future<WordSearchHintResult> useHint(String matchId) async {
    try {
      final response = await _apiRequest(
        'POST',
        '/api/sync/word-search/hint',
        body: {'matchId': matchId},
      );

      return WordSearchHintResult.fromJson(response);
    } catch (e) {
      Logger.error('Failed to use hint', error: e, service: 'word_search');
      throw Exception('Failed to use hint: $e');
    }
  }

  /// Get card state for match
  WordSearchCardState getCardState(WordSearchMatch match, String userId) {
    return match.getCardState(userId);
  }

  /// Get progress percentage (0.0 to 1.0)
  double getProgressPercentage(WordSearchMatch match) {
    return match.progressPercent;
  }

  /// Format word count for display (e.g., "3/12")
  String formatProgress(WordSearchMatch match) {
    return '${match.totalWordsFound}/12';
  }

  /// Calculate Love Points reward for completing a puzzle
  int getCompletionPoints() {
    return _completionPoints;
  }

  /// Check if game is complete
  bool isGameComplete(WordSearchMatch match) {
    return match.isCompleted;
  }

  /// Check if it's user's turn
  bool isMyTurn(WordSearchMatch match, String userId) {
    return match.currentTurnUserId == userId;
  }

  /// Get remaining words needed this turn
  int getWordsRemainingThisTurn(WordSearchMatch match) {
    return match.wordsRemainingThisTurn;
  }

  /// Get cached active match (for quick UI display)
  WordSearchMatch? getCachedActiveMatch() {
    return _storage.getActiveWordSearchMatch();
  }

  /// Get all cached matches
  List<WordSearchMatch> getAllCachedMatches() {
    return _storage.getAllWordSearchMatches();
  }

  /// Clear local match cache
  Future<void> clearMatchCache(String matchId) async {
    await _storage.deleteWordSearchMatch(matchId);
  }
}

/// Exception thrown when trying to play on opponent's turn
class NotYourTurnException implements Exception {
  final String message;
  NotYourTurnException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when puzzle cooldown is active (next puzzle tomorrow)
class CooldownActiveException implements Exception {
  final String message;
  CooldownActiveException(this.message);

  @override
  String toString() => message;
}

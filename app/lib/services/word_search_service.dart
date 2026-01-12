import '../models/word_search.dart';
import '../exceptions/game_exceptions.dart';
import '../utils/logger.dart';
import 'side_quest_service_base.dart';

/// Core service for Word Search game logic
///
/// API-first architecture: Server is single source of truth.
/// No local puzzle generation - all matches created server-side.
class WordSearchService extends SideQuestServiceBase {
  static const int _completionPoints = 30;

  @override
  String get serviceName => 'word_search';

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
      final response = await apiRequest(
        'POST',
        '/api/sync/word-search',
      );

      // Check for cooldown response
      checkCooldownResponse(response);

      final currentUserId = await getCurrentUserId();

      final gameState = WordSearchGameState.fromJson(response, currentUserId ?? '');

      // Cache locally
      await storage.saveWordSearchMatch(gameState.match);

      return gameState;
    } on GameException {
      rethrow;
    } catch (e) {
      Logger.error('Failed to get/create match from API',
          error: e, service: serviceName);

      // Fall back to cached match if available (read-only mode)
      final cached = storage.getActiveWordSearchMatch();
      if (cached != null) {
        Logger.warn('Using cached match (offline mode)', service: serviceName);
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
          progressPercent: cached.progressPercent,  // Uses int (0-100) getter now
        );
      }

      rethrow;
    }
  }

  /// Poll match state (for polling during partner's turn)
  Future<WordSearchGameState> pollMatchState(String matchId) async {
    try {
      final response = await apiRequest('GET', '/api/sync/word-search/$matchId');
      final currentUserId = await getCurrentUserId();

      final gameState = WordSearchGameState.fromJson(response, currentUserId ?? '');

      // Update cache
      await storage.saveWordSearchMatch(gameState.match);

      return gameState;
    } catch (e) {
      Logger.error('Failed to poll match state', error: e, service: serviceName);
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
      final response = await apiRequest(
        'POST',
        '/api/sync/word-search/submit',
        body: {
          'matchId': matchId,
          'word': word.toUpperCase(),
          'positions': positions.map((p) => p.toJson()).toList(),
        },
      );

      return WordSearchSubmitResult.fromJson(response);
    } on NotYourTurnException {
      rethrow;
    } catch (e) {
      Logger.error('Failed to submit word', error: e, service: serviceName);
      throw Exception('Failed to submit word: $e');
    }
  }

  /// Use hint to reveal first letter position of a random unfound word
  Future<WordSearchHintResult> useHint(String matchId) async {
    try {
      final response = await apiRequest(
        'POST',
        '/api/sync/word-search/hint',
        body: {'matchId': matchId},
      );

      return WordSearchHintResult.fromJson(response);
    } catch (e) {
      Logger.error('Failed to use hint', error: e, service: serviceName);
      throw Exception('Failed to use hint: $e');
    }
  }

  /// Get card state for match
  WordSearchCardState getCardState(WordSearchMatch match, String userId) {
    return match.getCardState(userId);
  }

  /// Get progress percentage (0.0 to 1.0)
  double getProgressPercentage(WordSearchMatch match) {
    return match.progressPercentage;
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
    return storage.getActiveWordSearchMatch();
  }

  /// Get all cached matches
  List<WordSearchMatch> getAllCachedMatches() {
    return storage.getAllWordSearchMatches();
  }

  /// Clear local match cache
  Future<void> clearMatchCache(String matchId) async {
    await storage.deleteWordSearchMatch(matchId);
  }
}

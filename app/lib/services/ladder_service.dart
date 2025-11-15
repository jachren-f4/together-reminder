import 'package:uuid/uuid.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/ladder_session.dart';
import '../models/word_pair.dart';
import '../models/user.dart';
import '../models/love_point_transaction.dart';
import 'storage_service.dart';
import 'word_validation_service.dart';
import 'word_pair_bank.dart';
import '../utils/logger.dart';

class LadderService {
  static const _uuid = Uuid();
  final StorageService _storage = StorageService();
  final WordValidationService _validator = WordValidationService.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // LP Award Constants
  static const int lpPerMove = 10;
  static const int lpCompletion = 30;
  static const int lpOptimalBonus = 10;
  static const int lpInvalidPenalty = -2;

  /// Initialize the Word Ladder service
  /// Must be called after StorageService.init() and before using other methods
  Future<void> initialize() async {
    await _validator.initialize();
  }

  /// Create initial 3 ladders when user first opens Word Ladder
  /// Alternating first turns: A, B, A pattern
  Future<List<LadderSession>> createInitialLadders() async {
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user == null || partner == null) {
      throw StateError('User and partner must be paired');
    }

    // Check if initial ladders already exist
    final existingCount = _storage.getActiveLadderCount();
    if (existingCount >= 3) {
      return _storage.getActiveLadders();
    }

    final wordPairs = WordPairBank.getInitialPairs();
    final List<LadderSession> sessions = [];

    // Alternate first turns: user, partner, user
    final turnOrder = [user.id, partner.pushToken, user.id];

    for (int i = 0; i < 3; i++) {
      final pair = wordPairs[i];
      final session = LadderSession(
        id: _uuid.v4(),
        wordPairId: pair.id,
        startWord: pair.startWord,
        endWord: pair.endWord,
        wordChain: [pair.startWord],
        status: 'active',
        createdAt: DateTime.now(),
        currentTurn: turnOrder[i],
        language: pair.language,
        optimalSteps: pair.optimalSteps,
        lastAction: 'created',
      );

      await _storage.saveLadderSession(session);
      sessions.add(session);

      // Notify partner if it's their turn
      if (session.currentTurn != user.id) {
        await _sendLadderNotification(
          session: session,
          type: 'ladder_created',
        );
      }
    }

    return sessions;
  }

  /// Make a move in a ladder session
  /// Returns MoveResult with success, LP earned, and any errors
  Future<MoveResult> makeMove({
    required String sessionId,
    required String newWord,
  }) async {
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user == null || partner == null) {
      return MoveResult(
        success: false,
        errorMessage: 'User and partner must be paired',
      );
    }

    final session = _storage.getLadderSession(sessionId);
    if (session == null) {
      return MoveResult(
        success: false,
        errorMessage: 'Ladder session not found',
      );
    }

    // Verify it's the user's turn
    if (session.currentTurn != user.id) {
      return MoveResult(
        success: false,
        errorMessage: 'Not your turn',
      );
    }

    // Validate the move
    final validationResult = _validator.validateMove(
      currentWord: session.currentWord,
      newWord: newWord.toUpperCase(),
      language: session.language,
      wordChain: session.wordChain,
    );

    if (!validationResult.isValid) {
      // Apply penalty for invalid word
      await _awardLovePoints(
        userId: user.id,
        amount: lpInvalidPenalty,
        reason: 'Invalid word attempt',
        sessionId: sessionId,
      );

      return MoveResult(
        success: false,
        errorMessage: validationResult.errorMessage ?? 'Invalid move',
        lpEarned: lpInvalidPenalty,
      );
    }

    // Valid move - update session
    session.wordChain.add(newWord.toUpperCase());
    session.lastAction = 'move';

    // Clear yield state if this was a yielded ladder
    if (session.isYielded) {
      session.yieldedBy = null;
      session.yieldedAt = null;
    }

    // Check if ladder is completed
    if (newWord.toUpperCase() == session.endWord) {
      return await _completeLadder(session);
    }

    // Switch turn to partner
    session.currentTurn = partner.pushToken;
    await _storage.updateLadderSession(session);

    // Award LP for valid move
    final lpEarned = lpPerMove;
    await _awardLovePoints(
      userId: user.id,
      amount: lpEarned,
      reason: 'Word Ladder move',
      sessionId: sessionId,
    );

    // Notify partner of new move
    await _sendLadderNotification(
      session: session,
      type: 'ladder_move',
    );

    return MoveResult(
      success: true,
      lpEarned: lpEarned,
      message: 'Great move! +$lpEarned LP',
    );
  }

  /// Complete a ladder session and award LP
  Future<MoveResult> _completeLadder(LadderSession session) async {
    final user = _storage.getUser();
    if (user == null) {
      return MoveResult(success: false, errorMessage: 'User not found');
    }

    session.status = 'completed';
    session.completedAt = DateTime.now();
    await _storage.updateLadderSession(session);

    // Calculate LP: move + completion + optional bonus
    int totalLp = lpPerMove + lpCompletion;

    // Check for optimal steps bonus
    if (session.optimalSteps != null && session.stepCount <= session.optimalSteps!) {
      totalLp += lpOptimalBonus;
    }

    session.lpEarned = totalLp;
    await _storage.updateLadderSession(session);

    // Award LP to both partners
    await _awardLovePoints(
      userId: user.id,
      amount: totalLp,
      reason: 'Completed Word Ladder',
      sessionId: session.id,
    );

    // Auto-generate new ladder to maintain 3 active
    await _autoGenerateNewLadder();

    // Notify partner of completion
    final partner = _storage.getPartner();
    if (partner != null) {
      await _sendLadderNotification(
        session: session,
        type: 'ladder_completed',
      );
    }

    String message = 'Ladder completed! +$totalLp LP';
    if (session.optimalSteps != null && session.stepCount <= session.optimalSteps!) {
      message += ' (Optimal bonus!)';
    }

    return MoveResult(
      success: true,
      lpEarned: totalLp,
      isCompleted: true,
      message: message,
    );
  }

  /// Yield turn to partner (when stuck)
  Future<YieldResult> yieldTurn(String sessionId) async {
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user == null || partner == null) {
      return YieldResult(
        success: false,
        errorMessage: 'User and partner must be paired',
      );
    }

    final session = _storage.getLadderSession(sessionId);
    if (session == null) {
      return YieldResult(
        success: false,
        errorMessage: 'Ladder session not found',
      );
    }

    // Verify it's the user's turn
    if (session.currentTurn != user.id) {
      return YieldResult(
        success: false,
        errorMessage: 'Not your turn',
      );
    }

    // Update yield state
    session.yieldedBy = user.id;
    session.yieldedAt = DateTime.now();
    session.yieldCount += 1;
    session.lastAction = 'yielded';
    session.currentTurn = partner.pushToken; // Switch turn to partner

    await _storage.updateLadderSession(session);

    // Notify partner they've been yielded to
    await _sendLadderNotification(
      session: session,
      type: 'ladder_yielded',
    );

    return YieldResult(
      success: true,
      message: 'Turn yielded to partner',
    );
  }

  /// Auto-generate a new ladder when one completes (maintain 3 active)
  Future<void> _autoGenerateNewLadder() async {
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user == null || partner == null) return;

    final activeCount = _storage.getActiveLadderCount();
    if (activeCount >= 3) return; // Already have 3 active

    // Determine whose turn it should be (alternate from last completed)
    final completedLadders = _storage.getCompletedLadders();
    String firstTurn = user.id;

    if (completedLadders.isNotEmpty) {
      // Give first turn to partner if user just completed one
      final lastCompleted = completedLadders.first;
      firstTurn = lastCompleted.currentTurn == user.id
          ? partner.pushToken
          : user.id;
    }

    // Get a random pair (varying difficulty)
    final pair = WordPairBank.getRandomPair();
    if (pair == null) return;

    final session = LadderSession(
      id: _uuid.v4(),
      wordPairId: pair.id,
      startWord: pair.startWord,
      endWord: pair.endWord,
      wordChain: [pair.startWord],
      status: 'active',
      createdAt: DateTime.now(),
      currentTurn: firstTurn,
      language: pair.language,
      optimalSteps: pair.optimalSteps,
      lastAction: 'created',
    );

    await _storage.saveLadderSession(session);

    // Notify if it's partner's turn
    if (session.currentTurn != user.id) {
      await _sendLadderNotification(
        session: session,
        type: 'ladder_created',
      );
    }
  }

  /// Award love points to both partners
  Future<void> _awardLovePoints({
    required String userId,
    required int amount,
    required String reason,
    String? sessionId,
  }) async {
    final transaction = LovePointTransaction(
      id: _uuid.v4(),
      amount: amount,
      reason: reason,
      timestamp: DateTime.now(),
      relatedId: sessionId,
    );

    await _storage.saveTransaction(transaction);
  }

  /// Send notification for ladder events
  Future<void> _sendLadderNotification({
    required LadderSession session,
    required String type,
  }) async {
    try {
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user == null || partner == null) return;

      // Removed verbose logging
      // print('🪜 Sending Word Ladder notification');
      // print('   Type: $type');
      // print('   Session ID: ${session.id}');
      // print('   Partner token: ${partner.pushToken}');

      final callable = _functions.httpsCallable('sendWordLadderNotification');
      await callable.call({
        'partnerToken': partner.pushToken,
        'senderName': user.name ?? 'Your partner',
        'sessionId': session.id,
        'notificationType': type,
        'currentWord': session.currentWord,
        'startWord': session.startWord,
        'endWord': session.endWord,
        'lpEarned': session.lpEarned,
      });

      // Removed verbose logging
      // Logger.success('Word Ladder notification sent successfully', service: 'ladder');
    } catch (e) {
      Logger.error('Error sending Word Ladder notification', error: e, service: 'ladder');
      // Don't throw - notifications are not critical for gameplay
    }
  }

  /// Get all active ladders for current user
  List<LadderSession> getActiveLadders() {
    return _storage.getActiveLadders();
  }

  /// Get a specific ladder session
  LadderSession? getLadderSession(String id) {
    return _storage.getLadderSession(id);
  }

  /// Get completed ladders (for history)
  List<LadderSession> getCompletedLadders() {
    return _storage.getCompletedLadders();
  }

  /// Check if it's the current user's turn
  bool isMyTurn(LadderSession session) {
    final user = _storage.getUser();
    if (user == null) {
      // Removed verbose logging
      // print('🪜 isMyTurn: user is null');
      return false;
    }
    final result = session.currentTurn == user.id;
    // Removed verbose logging
    // print('🪜 isMyTurn check: currentTurn=${session.currentTurn}, user.id=${user.id}, result=$result');
    return result;
  }
}

class MoveResult {
  final bool success;
  final String? errorMessage;
  final String? message;
  final int lpEarned;
  final bool isCompleted;

  MoveResult({
    required this.success,
    this.errorMessage,
    this.message,
    this.lpEarned = 0,
    this.isCompleted = false,
  });
}

class YieldResult {
  final bool success;
  final String? errorMessage;
  final String? message;

  YieldResult({
    required this.success,
    this.errorMessage,
    this.message,
  });
}

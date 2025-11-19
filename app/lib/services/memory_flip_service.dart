import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/memory_flip.dart';
import '../services/storage_service.dart';
import '../services/memory_content_bank.dart';
import '../services/memory_flip_sync_service.dart';
import '../utils/logger.dart';

/// Result of checking for matches after flipping cards
class MatchResult {
  final MemoryCard card1;
  final MemoryCard card2;
  final String quote;
  final int lovePoints;

  MatchResult({
    required this.card1,
    required this.card2,
    required this.quote,
    required this.lovePoints,
  });
}

/// Core service for Memory Flip game logic
class MemoryFlipService {
  final StorageService _storage = StorageService();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  late final MemoryFlipSyncService _syncService = MemoryFlipSyncService(storage: _storage);
  static const int _defaultFlipsPerDay = 6; // Must be even number
  static const int _defaultPuzzleDurationDays = 7; // Weekly puzzles
  static const int _defaultPairCount = 8; // 8 pairs = 16 cards (4×4 grid)
  static const int _baseMatchPoints = 10;

  /// Generate a new daily puzzle
  /// Creates a 4×4 grid with 8 pairs of emoji cards
  Future<MemoryPuzzle> generateDailyPuzzle({String? puzzleId}) async {
    // Use provided puzzle ID or generate new one (for date-based sync)
    puzzleId ??= const Uuid().v4();
    final now = DateTime.now();
    final expiresAt = now.add(Duration(days: _defaultPuzzleDurationDays));

    // Get random emoji pairs from content bank
    final pairs = MemoryContentBank.getBalancedPairs(_defaultPairCount);

    // Create cards (2 per pair)
    final cards = <MemoryCard>[];
    for (var i = 0; i < pairs.length; i++) {
      final pair = pairs[i];
      final pairId = const Uuid().v4();

      // Create two cards for this pair
      cards.add(MemoryCard(
        id: const Uuid().v4(),
        puzzleId: puzzleId,
        position: i * 2, // Will be shuffled later
        emoji: pair.emoji,
        pairId: pairId,
        status: 'hidden',
        revealQuote: pair.quote,
      ));

      cards.add(MemoryCard(
        id: const Uuid().v4(),
        puzzleId: puzzleId,
        position: i * 2 + 1, // Will be shuffled later
        emoji: pair.emoji,
        pairId: pairId,
        status: 'hidden',
        revealQuote: pair.quote,
      ));
    }

    // Shuffle cards and assign positions
    cards.shuffle();
    for (var i = 0; i < cards.length; i++) {
      cards[i].position = i;
    }

    // Create puzzle
    final puzzle = MemoryPuzzle(
      id: puzzleId,
      createdAt: now,
      expiresAt: expiresAt,
      cards: cards,
      status: 'active',
      totalPairs: _defaultPairCount,
      matchedPairs: 0,
      completionQuote: MemoryContentBank.getRandomCompletionQuote(),
    );

    await _storage.saveMemoryPuzzle(puzzle);
    return puzzle;
  }

  /// Get the current active puzzle, or generate a new one if none exists
  ///
  /// Implements "first device creates, second device loads" pattern via Firebase RTDB
  Future<MemoryPuzzle> getCurrentPuzzle() async {
    // Get user and partner for Firebase sync
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    // Check local storage first
    var puzzle = _storage.getActivePuzzle();

    // If no active puzzle or expired, check Firebase or generate new one
    if (puzzle == null || puzzle.expiresAt.isBefore(DateTime.now())) {
      if (puzzle != null && puzzle.status == 'active') {
        // Mark expired puzzle as completed (incomplete)
        puzzle.status = 'completed';
        await _storage.updateMemoryPuzzle(puzzle);
      }

      // If we have both user and partner, try to sync with Firebase
      if (user != null && partner != null) {
        // Generate date-based puzzle ID for syncing (same ID for both partners today)
        final dateKey = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
        final puzzleId = 'puzzle_$dateKey';

        // Try to load from Firebase
        Logger.debug('Checking Firebase for puzzle: $puzzleId', service: 'memory_flip');
        final firebasePuzzle = await _syncService.syncPuzzle(
          puzzleId,
          user.id,
          partner.pushToken,
        );

        if (firebasePuzzle != null) {
          // Puzzle exists in Firebase - save locally and return
          Logger.debug('Loaded puzzle from Firebase', service: 'memory_flip');
          await _storage.saveMemoryPuzzle(firebasePuzzle);
          return firebasePuzzle;
        }

        // No puzzle in Firebase - generate new one with date-based ID and save to Firebase
        Logger.debug('Generating new puzzle and saving to Firebase', service: 'memory_flip');
        puzzle = await generateDailyPuzzle(puzzleId: puzzleId);

        // Save to Firebase for partner to load
        final coupleId = _getCoupleId(user.id, partner.pushToken);
        await _syncService.savePuzzleToFirebase(puzzle, coupleId, user.id);
      } else {
        // No partner - just generate locally
        Logger.debug('No partner found - generating local puzzle only', service: 'memory_flip');
        puzzle = await generateDailyPuzzle();
      }
    }

    return puzzle;
  }

  /// Generate couple ID from sorted push tokens
  String _getCoupleId(String userToken, String partnerToken) {
    final tokens = [userToken, partnerToken]..sort();
    return tokens.join('_');
  }

  /// Get or create flip allowance for a user
  Future<MemoryFlipAllowance> getFlipAllowance(String userId) async {
    var allowance = _storage.getMemoryAllowance(userId);

    if (allowance == null) {
      // Create initial allowance
      allowance = MemoryFlipAllowance(
        userId: userId,
        flipsRemaining: _defaultFlipsPerDay,
        resetsAt: _getNextResetTime(),
        totalFlipsToday: 0,
        lastFlipAt: DateTime.now(),
      );
      await _storage.saveMemoryAllowance(allowance);
    } else if (allowance.needsReset) {
      // Reset allowance if past reset time
      await resetDailyAllowance(userId);
      allowance = _storage.getMemoryAllowance(userId)!;
    }

    return allowance;
  }

  /// Check if a user can flip (needs at least 2 flips for one turn)
  Future<bool> canFlip(String userId) async {
    final allowance = await getFlipAllowance(userId);
    return allowance.canFlip;
  }

  /// Flip a card (temporarily reveal it)
  /// Returns the flipped card
  /// Note: This doesn't decrement allowance yet - that happens after checking for match
  Future<MemoryCard> flipCard(String cardId, String userId) async {
    final puzzle = await getCurrentPuzzle();
    final card = puzzle.cards.firstWhere((c) => c.id == cardId);

    if (card.isMatched) {
      throw Exception('Card is already matched');
    }

    // Card flip is temporary - actual state update happens in matchCards or resetCards
    return card;
  }

  /// Check for matches between two flipped cards
  /// If cards match, marks them as matched and returns MatchResult
  /// If cards don't match, returns null (caller should flip them back)
  Future<MatchResult?> checkForMatches(
    MemoryPuzzle puzzle,
    MemoryCard card1,
    MemoryCard card2,
    String userId,
  ) async {
    // Check if cards match (same emoji and pairId)
    if (card1.pairId == card2.pairId && card1.emoji == card2.emoji) {
      // Match found!
      await matchCards(puzzle, card1, card2, userId);

      final lovePoints = calculateMatchPoints();

      return MatchResult(
        card1: card1,
        card2: card2,
        quote: card1.revealQuote,
        lovePoints: lovePoints,
      );
    }

    return null; // No match
  }

  /// Mark two cards as matched
  Future<void> matchCards(
    MemoryPuzzle puzzle,
    MemoryCard card1,
    MemoryCard card2,
    String userId,
  ) async {
    final now = DateTime.now();

    // Update card statuses
    card1.status = 'matched';
    card1.matchedBy = userId;
    card1.matchedAt = now;

    card2.status = 'matched';
    card2.matchedBy = userId;
    card2.matchedAt = now;

    // Update puzzle progress
    puzzle.matchedPairs++;

    // Check if puzzle is complete
    if (puzzle.matchedPairs >= puzzle.totalPairs) {
      puzzle.status = 'completed';
      puzzle.completedAt = now;
    }

    await _storage.updateMemoryPuzzle(puzzle);

    // Sync match to Firebase RTDB for partner to see
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    if (user != null && partner != null) {
      final coupleId = _getCoupleId(user.id, partner.pushToken);
      _syncService.syncMatchToFirebase(
        coupleId,
        puzzle.id,
        card1.id,
        card2.id,
        userId,
      ).catchError((e) {
        Logger.error('Error syncing match to Firebase RTDB', error: e, service: 'memory_flip');
      });
    }
  }

  /// Decrement flip allowance after a turn (2 flips)
  Future<void> decrementFlipAllowance(String userId) async {
    final allowance = await getFlipAllowance(userId);

    if (allowance.flipsRemaining < 2) {
      throw Exception('Not enough flips remaining');
    }

    allowance.flipsRemaining -= 2; // Each turn uses 2 flips
    allowance.totalFlipsToday += 2;
    allowance.lastFlipAt = DateTime.now();

    await _storage.updateMemoryAllowance(allowance);
  }

  /// Reset daily flip allowance for a user
  Future<void> resetDailyAllowance(String userId) async {
    final allowance = MemoryFlipAllowance(
      userId: userId,
      flipsRemaining: _defaultFlipsPerDay,
      resetsAt: _getNextResetTime(),
      totalFlipsToday: 0,
      lastFlipAt: DateTime.now(),
    );

    await _storage.saveMemoryAllowance(allowance);
  }

  /// Calculate Love Points for a match
  int calculateMatchPoints() {
    return _baseMatchPoints;
  }

  /// Calculate Love Points reward for completing a puzzle
  int calculateCompletionPoints(MemoryPuzzle puzzle) {
    int basePoints = 50; // Completion bonus
    int pairBonus = puzzle.totalPairs * 10; // 10 per pair

    // Time bonus (complete faster = more points)
    Duration timeToComplete = puzzle.completedAt!.difference(puzzle.createdAt);
    int daysTaken = timeToComplete.inDays;
    int timeBonus = max(0, 30 - (daysTaken * 5)); // -5 per day

    return basePoints + pairBonus + timeBonus;
  }

  /// Get next reset time (midnight of next day)
  DateTime _getNextResetTime() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow;
  }

  /// Get time until allowance resets
  Duration getTimeUntilReset(MemoryFlipAllowance allowance) {
    return allowance.resetsAt.difference(DateTime.now());
  }

  /// Format time until reset as a human-readable string
  String formatTimeUntilReset(MemoryFlipAllowance allowance) {
    final duration = getTimeUntilReset(allowance);

    if (duration.inHours > 0) {
      return '${duration.inHours}h';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return 'soon';
    }
  }

  /// Get a card by ID from current puzzle
  Future<MemoryCard?> getCard(String cardId) async {
    final puzzle = await getCurrentPuzzle();
    try {
      return puzzle.cards.firstWhere((c) => c.id == cardId);
    } catch (e) {
      return null;
    }
  }

  /// Get all cards at specific positions
  List<MemoryCard> getCardsAtPositions(MemoryPuzzle puzzle, List<int> positions) {
    return puzzle.cards.where((c) => positions.contains(c.position)).toList();
  }

  /// Get all matched cards in puzzle
  List<MemoryCard> getMatchedCards(MemoryPuzzle puzzle) {
    return puzzle.cards.where((c) => c.isMatched).toList();
  }

  /// Get all hidden cards in puzzle
  List<MemoryCard> getHiddenCards(MemoryPuzzle puzzle) {
    return puzzle.cards.where((c) => c.isHidden).toList();
  }

  /// Check if puzzle has expired
  bool isPuzzleExpired(MemoryPuzzle puzzle) {
    return puzzle.expiresAt.isBefore(DateTime.now());
  }

  /// Get puzzle progress as percentage
  double getPuzzleProgress(MemoryPuzzle puzzle) {
    return puzzle.progressPercentage;
  }

  /// Sync flip with Cloud Function (Firestore backup)
  Future<void> syncFlip(
    String puzzleId,
    List<String> cardIds,
    String userId,
  ) async {
    try {
      final callable = _functions.httpsCallable('syncMemoryFlip');
      await callable.call({
        'puzzleId': puzzleId,
        'cardIds': cardIds,
        'userId': userId,
        'action': 'flip',
      });
    } catch (e) {
      Logger.error('Error syncing flip', error: e, service: 'memory_flip');
      // Don't throw - allow offline play
    }
  }

  /// Sync match with Cloud Function (Firestore backup)
  Future<void> syncMatch(
    String puzzleId,
    List<String> cardIds,
    String userId,
  ) async {
    try {
      final callable = _functions.httpsCallable('syncMemoryFlip');
      await callable.call({
        'puzzleId': puzzleId,
        'cardIds': cardIds,
        'userId': userId,
        'action': 'match',
      });
    } catch (e) {
      Logger.error('Error syncing match', error: e, service: 'memory_flip');
      // Don't throw - allow offline play
    }
  }

  /// Send match notification to partner
  Future<void> sendMatchNotification({
    required String partnerToken,
    required String senderName,
    required String emoji,
    required String quote,
    required int lovePoints,
  }) async {
    try {
      final callable = _functions.httpsCallable('sendMemoryFlipMatchNotification');
      await callable.call({
        'partnerToken': partnerToken,
        'senderName': senderName,
        'emoji': emoji,
        'quote': quote,
        'lovePoints': lovePoints,
      });
    } catch (e) {
      Logger.error('Error sending match notification', error: e, service: 'memory_flip');
      // Don't throw - notification is not critical
    }
  }

  /// Send completion notification to partner
  Future<void> sendCompletionNotification({
    required String partnerToken,
    required String senderName,
    required String completionQuote,
    required int lovePoints,
    required int daysTaken,
  }) async {
    try {
      final callable = _functions.httpsCallable('sendMemoryFlipCompletionNotification');
      await callable.call({
        'partnerToken': partnerToken,
        'senderName': senderName,
        'completionQuote': completionQuote,
        'lovePoints': lovePoints,
        'daysTaken': daysTaken,
      });
    } catch (e) {
      Logger.error('Error sending completion notification', error: e, service: 'memory_flip');
      // Don't throw - notification is not critical
    }
  }

  /// Send new puzzle notification to partner
  Future<void> sendNewPuzzleNotification({
    required String partnerToken,
    required String senderName,
    required int totalPairs,
    required int expiresInDays,
  }) async {
    try {
      final callable = _functions.httpsCallable('sendMemoryFlipNewPuzzleNotification');
      await callable.call({
        'partnerToken': partnerToken,
        'senderName': senderName,
        'totalPairs': totalPairs,
        'expiresInDays': expiresInDays,
      });
    } catch (e) {
      Logger.error('Error sending new puzzle notification', error: e, service: 'memory_flip');
      // Don't throw - notification is not critical
    }
  }
}

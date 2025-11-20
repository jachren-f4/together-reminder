import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import '../models/memory_flip.dart';
import '../services/storage_service.dart';
import '../services/api_client.dart';
import '../utils/logger.dart';

/// Service for synchronizing Memory Flip puzzles via Firebase RTDB
///
/// Uses "first user creates, second user loads" pattern to ensure
/// both partners play the same puzzle with synced match state.
///
/// Database structure:
/// /memory_puzzles/{coupleId}/{puzzleId}/
///   - id: puzzle ID
///   - createdAt: timestamp
///   - createdBy: userId who generated
///   - expiresAt: timestamp
///   - totalPairs: number of pairs
///   - matchedPairs: number of matched pairs
///   - status: 'active' or 'completed'
///   - completionQuote: quote for completion
///   - completedAt: timestamp (optional)
///   - cards: List of card objects
class MemoryFlipSyncService {
  final StorageService _storage;
  final DatabaseReference _database;
  final ApiClient _apiClient = ApiClient();

  MemoryFlipSyncService({
    required StorageService storage,
  })  : _storage = storage,
        _database = FirebaseDatabase.instance.ref();

  /// Generate couple ID from user and partner
  String _getCoupleId() {
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user == null || partner == null) {
      throw Exception('User or partner not found');
    }

    // Sort user IDs to ensure consistent couple ID (matches quest system)
    final tokens = [user.id, partner.pushToken]..sort();
    return tokens.join('_');
  }

  /// Convert MemoryPuzzle to Firebase JSON
  Map<String, dynamic> _puzzleToJson(MemoryPuzzle puzzle, String userId) {
    return {
      'id': puzzle.id,
      'createdAt': puzzle.createdAt.toIso8601String(),
      'createdBy': userId,
      'expiresAt': puzzle.expiresAt.toIso8601String(),
      'totalPairs': puzzle.totalPairs,
      'matchedPairs': puzzle.matchedPairs,
      'status': puzzle.status,
      'completionQuote': puzzle.completionQuote,
      'completedAt': puzzle.completedAt?.toIso8601String(),
      'cards': puzzle.cards.map((card) => _cardToJson(card)).toList(),
    };
  }

  /// Convert MemoryCard to Firebase JSON
  Map<String, dynamic> _cardToJson(MemoryCard card) {
    return {
      'id': card.id,
      'puzzleId': card.puzzleId,
      'position': card.position,
      'emoji': card.emoji,
      'pairId': card.pairId,
      'status': card.status,
      'matchedBy': card.matchedBy,
      'matchedAt': card.matchedAt?.toIso8601String(),
      'revealQuote': card.revealQuote,
    };
  }

  /// Convert Firebase JSON to MemoryPuzzle
  MemoryPuzzle _jsonToPuzzle(Map<dynamic, dynamic> data) {
    final cardsData = data['cards'] as List<dynamic>;
    final cards = cardsData.map((cardData) => _jsonToCard(cardData as Map<dynamic, dynamic>)).toList();

    return MemoryPuzzle(
      id: data['id'] as String,
      createdAt: DateTime.parse(data['createdAt'] as String),
      expiresAt: DateTime.parse(data['expiresAt'] as String),
      cards: cards,
      status: data['status'] as String,
      totalPairs: data['totalPairs'] as int,
      matchedPairs: data['matchedPairs'] as int? ?? 0,
      completedAt: data['completedAt'] != null ? DateTime.parse(data['completedAt'] as String) : null,
      completionQuote: data['completionQuote'] as String,
    );
  }

  /// Convert Firebase JSON to MemoryCard
  MemoryCard _jsonToCard(Map<dynamic, dynamic> data) {
    return MemoryCard(
      id: data['id'] as String,
      puzzleId: data['puzzleId'] as String,
      position: data['position'] as int,
      emoji: data['emoji'] as String,
      pairId: data['pairId'] as String,
      status: data['status'] as String? ?? 'hidden',
      matchedBy: data['matchedBy'] as String?,
      matchedAt: data['matchedAt'] != null ? DateTime.parse(data['matchedAt'] as String) : null,
      revealQuote: data['revealQuote'] as String,
    );
  }

  /// Load puzzle from Firebase RTDB
  ///
  /// Returns puzzle if found in Firebase, null otherwise
  Future<MemoryPuzzle?> loadPuzzleFromFirebase(
    String coupleId,
    String puzzleId,
  ) async {
    try {
      Logger.debug('📡 Loading puzzle from Firebase...', service: 'memory_flip');
      Logger.debug('   Couple ID: $coupleId', service: 'memory_flip');
      Logger.debug('   Puzzle ID: $puzzleId', service: 'memory_flip');

      final puzzleRef = _database.child('memory_puzzles/$coupleId/$puzzleId');
      final snapshot = await puzzleRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        Logger.debug('   ❌ No puzzle found in Firebase', service: 'memory_flip');
        return null;
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final puzzle = _jsonToPuzzle(data);

      Logger.debug('   ✅ Puzzle loaded from Firebase', service: 'memory_flip');
      Logger.debug('   Matched pairs: ${puzzle.matchedPairs}/${puzzle.totalPairs}', service: 'memory_flip');

      return puzzle;
    } catch (e) {
      Logger.error('Error loading puzzle from Firebase', error: e, service: 'memory_flip');
      return null;
    }
  }

  /// Save puzzle to Firebase RTDB
  ///
  /// Called by first device that generates the puzzle
  Future<void> savePuzzleToFirebase(
    MemoryPuzzle puzzle,
    String coupleId,
    String userId,
  ) async {
    try {
      Logger.debug('💾 Saving puzzle to Firebase...', service: 'memory_flip');
      Logger.debug('   Couple ID: $coupleId', service: 'memory_flip');
      Logger.debug('   Puzzle ID: ${puzzle.id}', service: 'memory_flip');

      final puzzleRef = _database.child('memory_puzzles/$coupleId/${puzzle.id}');
      final puzzleData = _puzzleToJson(puzzle, userId);

      await puzzleRef.set(puzzleData);

      // Sync to Supabase (Dual-Write)
      await _syncPuzzleToSupabase(puzzle);

      Logger.debug('   ✅ Puzzle saved to Firebase', service: 'memory_flip');
    } catch (e) {
      Logger.error('Error saving puzzle to Firebase', error: e, service: 'memory_flip');
      // Don't throw - allow offline play
    }
  }

  /// Sync Memory Flip puzzle to Supabase (Dual-Write Implementation)
  Future<void> _syncPuzzleToSupabase(MemoryPuzzle puzzle) async {
    try {
      Logger.debug('🚀 Attempting dual-write to Supabase (memoryFlip)...', service: 'memory_flip');

      final response = await _apiClient.post('/api/sync/memory-flip', body: {
        'id': puzzle.id,
        'date': puzzle.createdAt.toIso8601String().split('T')[0], // YYYY-MM-DD format
        'totalPairs': puzzle.totalPairs,
        'matchedPairs': puzzle.matchedPairs,
        'cards': puzzle.cards.map((card) => {
          'id': card.id,
          'puzzleId': card.puzzleId,
          'position': card.position,
          'emoji': card.emoji,
          'pairId': card.pairId,
          'status': card.status,
          'matchedBy': card.matchedBy,
          'matchedAt': card.matchedAt?.toIso8601String(),
          'revealQuote': card.revealQuote,
        }).toList(),
        'status': puzzle.status,
        'completionQuote': puzzle.completionQuote,
        'createdAt': puzzle.createdAt.toIso8601String(),
        'completedAt': puzzle.completedAt?.toIso8601String(),
      });

      if (response.success) {
        Logger.debug('✅ Supabase dual-write successful!', service: 'memory_flip');
      }
    } catch (e) {
      Logger.error('Supabase dual-write exception', error: e, service: 'memory_flip');
    }
  }

  /// Sync match to Firebase RTDB
  ///
  /// Updates card status when a match is found
  Future<void> syncMatchToFirebase(
    String coupleId,
    String puzzleId,
    String cardId1,
    String cardId2,
    String userId,
  ) async {
    try {
      Logger.debug('🔄 Syncing match to Firebase RTDB...', service: 'memory_flip');
      Logger.debug('   Couple ID: $coupleId', service: 'memory_flip');
      Logger.debug('   Puzzle ID: $puzzleId', service: 'memory_flip');
      Logger.debug('   Cards: $cardId1, $cardId2', service: 'memory_flip');

      final puzzleRef = _database.child('memory_puzzles/$coupleId/$puzzleId');

      // Get current puzzle state
      final snapshot = await puzzleRef.get();
      if (!snapshot.exists || snapshot.value == null) {
        Logger.debug('   ⚠️  Puzzle not found in Firebase - skipping sync', service: 'memory_flip');
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final cardsData = List<Map<dynamic, dynamic>>.from(
        (data['cards'] as List<dynamic>).map((e) => e as Map<dynamic, dynamic>),
      );

      // Update matched cards
      final matchedAt = DateTime.now().toIso8601String();
      bool updated = false;

      for (var card in cardsData) {
        if (card['id'] == cardId1 || card['id'] == cardId2) {
          card['status'] = 'matched';
          card['matchedBy'] = userId;
          card['matchedAt'] = matchedAt;
          updated = true;
        }
      }

      if (updated) {
        // Update matched pairs count
        final matchedPairs = cardsData.where((c) => c['status'] == 'matched').length ~/ 2;
        final totalPairs = data['totalPairs'] as int;

        // Update puzzle state
        await puzzleRef.update({
          'cards': cardsData,
          'matchedPairs': matchedPairs,
          'status': matchedPairs == totalPairs ? 'completed' : 'active',
        });

        Logger.debug('   ✅ Match synced to Firebase RTDB', service: 'memory_flip');
        Logger.debug('   Matched pairs: $matchedPairs/$totalPairs', service: 'memory_flip');
      }
    } catch (e) {
      Logger.error('Error syncing match to Firebase RTDB', error: e, service: 'memory_flip');
      // Don't throw - allow offline play
    }
  }

  /// Sync puzzle with Firebase
  ///
  /// Returns puzzle from Firebase if exists, null if need to generate
  Future<MemoryPuzzle?> syncPuzzle(
    String puzzleId,
    String currentUserId,
    String partnerUserId,
  ) async {
    try {
      final coupleId = _getCoupleId();

      Logger.debug('🔄 Memory Flip Sync Check:', service: 'memory_flip');
      Logger.debug('   Couple ID: $coupleId', service: 'memory_flip');
      Logger.debug('   Puzzle ID: $puzzleId', service: 'memory_flip');
      Logger.debug('   Firebase Path: /memory_puzzles/$coupleId/$puzzleId', service: 'memory_flip');

      // Determine device priority to prevent race condition
      // Device with alphabetically first user ID is device 0 (generates)
      // Device with alphabetically second user ID is device 1 (loads)
      final sortedIds = [currentUserId, partnerUserId]..sort();
      final isSecondDevice = currentUserId == sortedIds[1];

      if (isSecondDevice) {
        // Second device waits 2 seconds to allow first device to generate and sync
        Logger.debug('   ⏱️  Second device detected - waiting 2 seconds for first device to generate puzzle...', service: 'memory_flip');
        await Future.delayed(const Duration(seconds: 2));
      }

      // Check Firebase first
      Logger.debug('   📡 Checking Firebase for existing puzzle...', service: 'memory_flip');
      final puzzle = await loadPuzzleFromFirebase(coupleId, puzzleId);

      if (puzzle != null) {
        Logger.debug('   ✅ Puzzle found in Firebase - loading...', service: 'memory_flip');
        return puzzle;
      }

      // If second device and Firebase is still empty, retry once after 2 more seconds
      if (isSecondDevice) {
        Logger.debug('   ⏱️  Firebase still empty - retrying in 2 seconds...', service: 'memory_flip');
        await Future.delayed(const Duration(seconds: 2));

        final retryPuzzle = await loadPuzzleFromFirebase(coupleId, puzzleId);
        if (retryPuzzle != null) {
          Logger.debug('   ✅ Puzzle found in Firebase on retry - loading...', service: 'memory_flip');
          return retryPuzzle;
        }
      }

      Logger.debug('   ❌ No puzzle in Firebase - need to generate', service: 'memory_flip');
      return null; // Signal to generate new puzzle
    } catch (e) {
      Logger.error('Error syncing puzzle', error: e, service: 'memory_flip');
      return null; // Allow offline play
    }
  }

  /// Watch puzzle updates in real-time (optional feature)
  ///
  /// Returns stream of puzzle updates for real-time sync
  Stream<Map<String, dynamic>> watchPuzzleUpdates(
    String coupleId,
    String puzzleId,
  ) {
    final puzzleRef = _database.child('memory_puzzles/$coupleId/$puzzleId');

    return puzzleRef.onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <String, dynamic>{};
      }
      return Map<String, dynamic>.from(event.snapshot.value as Map);
    });
  }
}

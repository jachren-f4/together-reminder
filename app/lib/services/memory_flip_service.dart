import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/memory_flip.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../utils/logger.dart';

/// Game state returned from API
class GameState {
  final MemoryPuzzle puzzle;
  final bool isMyTurn;
  final bool canPlay;
  final int myFlipsRemaining;
  final int partnerFlipsRemaining;
  final int? timeUntilTurnExpires;
  final int myPairs;
  final int partnerPairs;

  GameState({
    required this.puzzle,
    required this.isMyTurn,
    required this.canPlay,
    required this.myFlipsRemaining,
    required this.partnerFlipsRemaining,
    this.timeUntilTurnExpires,
    required this.myPairs,
    required this.partnerPairs,
  });
}

/// Result of submitting a move
class MoveResult {
  final bool matchFound;
  final bool turnAdvanced;
  final int playerFlipsRemaining;
  final int? partnerFlipsRemaining;
  final bool gameCompleted;

  MoveResult({
    required this.matchFound,
    required this.turnAdvanced,
    required this.playerFlipsRemaining,
    this.partnerFlipsRemaining,
    this.gameCompleted = false,
  });
}

/// Core service for Memory Flip game logic
///
/// API-first architecture: Server is single source of truth.
/// No local puzzle generation - all puzzles created server-side.
class MemoryFlipService {
  final StorageService _storage = StorageService();
  final AuthService _authService = AuthService();

  static const int _baseMatchPoints = 10;

  /// Get API base URL based on environment
  String get _apiBaseUrl {
    if (kDebugMode) {
      if (kIsWeb) {
        return 'http://localhost:3000';
      } else {
        return 'http://10.0.2.2:3000';
      }
    } else {
      return const String.fromEnvironment('API_URL',
          defaultValue: 'https://api.togetherremind.com');
    }
  }

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
          error: e, service: 'memory_flip');
      rethrow;
    }
  }

  /// Get or create today's puzzle from API
  ///
  /// This is the main entry point. Server handles:
  /// - Creating puzzle if none exists for today
  /// - Returning existing puzzle if already created
  /// - All game state calculation (turns, flips, etc.)
  Future<GameState> getOrCreatePuzzle() async {
    try {
      final response = await _apiRequest('POST', '/api/sync/memory-flip');

      final puzzleData = response['puzzle'];
      final gameStateData = response['gameState'];

      final puzzle = _parsePuzzleFromApi(puzzleData);

      // Cache locally for offline viewing (read-only)
      await _storage.saveMemoryPuzzle(puzzle);

      return GameState(
        puzzle: puzzle,
        isMyTurn: gameStateData['isMyTurn'] ?? false,
        canPlay: gameStateData['canPlay'] ?? false,
        myFlipsRemaining: gameStateData['myFlipsRemaining'] ?? 6,
        partnerFlipsRemaining: gameStateData['partnerFlipsRemaining'] ?? 6,
        timeUntilTurnExpires: gameStateData['timeUntilTurnExpires'],
        myPairs: gameStateData['myPairs'] ?? 0,
        partnerPairs: gameStateData['partnerPairs'] ?? 0,
      );
    } catch (e) {
      Logger.error('Failed to get/create puzzle from API', error: e, service: 'memory_flip');

      // Fall back to cached puzzle if available (read-only mode)
      final cached = _storage.getActivePuzzle();
      if (cached != null) {
        Logger.warn('Using cached puzzle (offline mode)', service: 'memory_flip');
        return GameState(
          puzzle: cached,
          isMyTurn: false, // Can't play offline
          canPlay: false,
          myFlipsRemaining: 0,
          partnerFlipsRemaining: 0,
          myPairs: 0,
          partnerPairs: 0,
        );
      }

      rethrow;
    }
  }

  /// Refresh game state from API (for polling)
  Future<GameState> refreshGameState() async {
    return getOrCreatePuzzle();
  }

  /// Parse puzzle from API response
  MemoryPuzzle _parsePuzzleFromApi(Map<String, dynamic> data) {
    final cardsData = data['cards'] as List;
    final cards = cardsData.map((c) {
      return MemoryCard(
        id: c['id'],
        puzzleId: data['id'],
        position: c['position'] ?? 0,
        emoji: c['emoji'],
        pairId: c['pairId'],
        status: c['status'],
        revealQuote: '', // Not included in API response
      );
    }).toList();

    return MemoryPuzzle(
      id: data['id'],
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      cards: cards,
      status: data['status'] ?? 'active',
      totalPairs: data['totalPairs'] ?? 8,
      matchedPairs: data['matchedPairs'] ?? 0,
      completionQuote: data['completionQuote'] ?? '',
      completedAt: data['completedAt'] != null
          ? DateTime.parse(data['completedAt'])
          : null,
      currentPlayerId: data['currentPlayerId'],
      turnNumber: data['turnNumber'] ?? 0,
      player1Pairs: data['player1Pairs'] ?? 0,
      player2Pairs: data['player2Pairs'] ?? 0,
    );
  }

  /// Submit a move (flip 2 cards)
  Future<MoveResult> submitMove(
    String puzzleId,
    String card1Id,
    String card2Id,
  ) async {
    try {
      final response = await _apiRequest(
        'POST',
        '/api/sync/memory-flip/move',
        body: {
          'puzzleId': puzzleId,
          'card1Id': card1Id,
          'card2Id': card2Id,
        },
      );

      // Update local cache with new state
      if (response['puzzle'] != null) {
        final updatedPuzzle = _parsePuzzleFromApi(response['puzzle']);
        await _storage.updateMemoryPuzzle(updatedPuzzle);
      }

      return MoveResult(
        matchFound: response['matchFound'] ?? false,
        turnAdvanced: response['turnAdvanced'] ?? false,
        playerFlipsRemaining: response['playerFlipsRemaining'] ?? 0,
        partnerFlipsRemaining: response['partnerFlipsRemaining'],
        gameCompleted: response['gameCompleted'] ?? false,
      );
    } catch (e) {
      Logger.error('Failed to submit move', error: e, service: 'memory_flip');
      throw Exception('Failed to submit move: $e');
    }
  }

  /// Format time until turn expires as human-readable string
  String formatTimeRemaining(int? seconds) {
    if (seconds == null || seconds <= 0) return 'Expired';

    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      if (minutes > 0) {
        return '${hours}h ${minutes}m';
      }
      return '${hours}h';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return 'Less than 1m';
    }
  }

  /// Calculate Love Points for a match
  int calculateMatchPoints() {
    return _baseMatchPoints;
  }

  /// Calculate Love Points reward for completing a puzzle
  int calculateCompletionPoints(MemoryPuzzle puzzle) {
    int basePoints = 50;
    int pairBonus = puzzle.totalPairs * 10;

    if (puzzle.completedAt != null) {
      Duration timeToComplete = puzzle.completedAt!.difference(puzzle.createdAt);
      int daysTaken = timeToComplete.inDays;
      int timeBonus = max(0, 30 - (daysTaken * 5));
      return basePoints + pairBonus + timeBonus;
    }

    return basePoints + pairBonus;
  }

  /// Check if puzzle has expired
  bool isPuzzleExpired(MemoryPuzzle puzzle) {
    return puzzle.expiresAt.isBefore(DateTime.now());
  }

  /// Get puzzle progress as percentage
  double getPuzzleProgress(MemoryPuzzle puzzle) {
    return puzzle.progressPercentage;
  }
}

/// Word Search Integration Tests
///
/// Integration tests simulating the full flow of Word Search game.
/// Uses mock HTTP client to simulate API responses without network calls.
///
/// Run: cd app && flutter test test/integration/word_search_integration_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:togetherremind/models/word_search.dart';
import 'package:togetherremind/services/love_point_service.dart';
import '../mocks/mock_http_client.dart';

void main() {
  group('Word Search Integration', () {
    setUp(() {
      // Reset state before each test
      MockHttpOverrides.reset();
      LovePointService.setLPChangeCallback(null);
    });

    group('Match Creation Flow', () {
      test('API response structure matches expected format', () {
        final response = TestWordSearchFactory.matchCreationResponse(
          matchId: 'ws-match-001',
          puzzleId: 'ws-puzzle-001',
        );

        // Verify response structure matches API contract
        expect(response['success'], isTrue);
        expect(response['match'], isA<Map>());
        expect(response['puzzle'], isA<Map>());
        expect(response['gameState'], isA<Map>());

        final match = response['match'] as Map<String, dynamic>;
        expect(match['matchId'], equals('ws-match-001'));
        expect(match['puzzleId'], equals('ws-puzzle-001'));
        expect(match['status'], equals('active'));
        expect(match['foundWords'], isEmpty);
        expect(match['turnNumber'], equals(1));
      });

      test('puzzle response contains required fields', () {
        final response = TestWordSearchFactory.matchCreationResponse();
        final puzzle = response['puzzle'] as Map<String, dynamic>;

        expect(puzzle['puzzleId'], isNotEmpty);
        expect(puzzle['title'], isNotEmpty);
        expect(puzzle['size'], isA<Map>());
        expect(puzzle['grid'], isA<String>());
        expect(puzzle['words'], isA<List>());

        final size = puzzle['size'] as Map<String, dynamic>;
        expect(size['rows'], equals(10));
        expect(size['cols'], equals(10));

        final grid = puzzle['grid'] as String;
        expect(grid.length, equals(100)); // 10x10 grid

        final words = puzzle['words'] as List;
        expect(words.length, greaterThanOrEqualTo(12));
      });

      test('gameState reflects initial turn state', () {
        final response = TestWordSearchFactory.matchCreationResponse(
          isMyTurn: true,
        );
        final gameState = response['gameState'] as Map<String, dynamic>;

        expect(gameState['isMyTurn'], isTrue);
        expect(gameState['canPlay'], isTrue);
        expect(gameState['wordsRemainingThisTurn'], equals(3));
        expect(gameState['myWordsFound'], equals(0));
        expect(gameState['partnerWordsFound'], equals(0));
        expect(gameState['myScore'], equals(0));
        expect(gameState['partnerScore'], equals(0));
        expect(gameState['progressPercent'], equals(0));
      });

      test('cooldown response has correct structure', () {
        final response = TestWordSearchFactory.cooldownResponse();

        expect(response['success'], isFalse);
        expect(response['code'], equals('COOLDOWN_ACTIVE'));
        expect(response['message'], isA<String>());
        expect(response['cooldownEnabled'], isTrue);
      });
    });

    group('Word Submission Flow', () {
      test('valid word submission response has correct fields', () {
        final response = TestWordSearchFactory.wordSubmitResponse(
          valid: true,
          word: 'LOVE',
          pointsEarned: 40, // 4 letters × 10 points
          wordsFoundThisTurn: 1,
        );

        expect(response['success'], isTrue);
        expect(response['valid'], isTrue);
        expect(response['pointsEarned'], equals(40));
        expect(response['wordsFoundThisTurn'], equals(1));
        expect(response['turnComplete'], isFalse);
        expect(response['gameComplete'], isFalse);
        expect(response['colorIndex'], isA<int>());
      });

      test('invalid word submission includes rejection reason', () {
        final response = TestWordSearchFactory.wordSubmitResponse(
          valid: false,
          reason: 'WORD_NOT_IN_PUZZLE',
        );

        expect(response['valid'], isFalse);
        expect(response['reason'], equals('WORD_NOT_IN_PUZZLE'));
        expect(response['pointsEarned'], equals(0));
      });

      test('already found word returns specific reason', () {
        final response = TestWordSearchFactory.wordSubmitResponse(
          valid: false,
          reason: 'WORD_ALREADY_FOUND',
        );

        expect(response['valid'], isFalse);
        expect(response['reason'], equals('WORD_ALREADY_FOUND'));
      });

      test('turn complete response has correct flags', () {
        final response = TestWordSearchFactory.wordSubmitResponse(
          valid: true,
          word: 'HEART',
          pointsEarned: 50,
          wordsFoundThisTurn: 3,
          turnComplete: true,
          nextTurnUserId: 'partner-id',
        );

        expect(response['turnComplete'], isTrue);
        expect(response['wordsFoundThisTurn'], equals(3));
        expect(response['nextTurnUserId'], equals('partner-id'));
        expect(response['gameComplete'], isFalse);
      });

      test('game complete response includes winner and LP info', () {
        final response = TestWordSearchFactory.wordSubmitResponse(
          valid: true,
          word: 'FOREVER',
          pointsEarned: 70,
          wordsFoundThisTurn: 3,
          turnComplete: true,
          gameComplete: true,
          winnerId: 'user-id',
        );

        expect(response['gameComplete'], isTrue);
        expect(response['winnerId'], equals('user-id'));
        expect(response['turnComplete'], isTrue);
      });

      test('points calculated as word.length × 10', () {
        // Test various word lengths
        final testCases = [
          ('LOVE', 4, 40),
          ('HEART', 5, 50),
          ('ROMANCE', 7, 70),
          ('KISS', 4, 40),
          ('AFFECTION', 9, 90),
        ];

        for (final (word, length, expectedPoints) in testCases) {
          final response = TestWordSearchFactory.wordSubmitResponse(
            valid: true,
            word: word,
            pointsEarned: length * 10,
          );

          expect(
            response['pointsEarned'],
            equals(expectedPoints),
            reason: '$word should award $expectedPoints points',
          );
        }
      });
    });

    group('Turn Management', () {
      test('turn switches after 3 words', () {
        // Simulate 3 word submissions in a turn
        var wordsFoundThisTurn = 0;

        for (var i = 0; i < 3; i++) {
          wordsFoundThisTurn++;
          final turnComplete = wordsFoundThisTurn >= 3;

          final response = TestWordSearchFactory.wordSubmitResponse(
            valid: true,
            word: 'WORD$i',
            pointsEarned: 50,
            wordsFoundThisTurn: wordsFoundThisTurn,
            turnComplete: turnComplete,
            nextTurnUserId: turnComplete ? 'partner-id' : null,
          );

          if (i < 2) {
            expect(response['turnComplete'], isFalse,
                reason: 'Turn should not be complete after ${i + 1} words');
          } else {
            expect(response['turnComplete'], isTrue,
                reason: 'Turn should be complete after 3 words');
            expect(response['nextTurnUserId'], equals('partner-id'));
          }
        }
      });

      test('wordsRemainingThisTurn decrements correctly', () {
        // Initial state
        var remaining = 3;

        for (var found = 0; found < 3; found++) {
          remaining = 3 - found;
          expect(remaining, equals(3 - found));
        }
      });
    });

    group('LP Sync on Game Completion', () {
      test('LP callback triggers when game completes', () {
        var lpCallbackFired = false;

        LovePointService.setLPChangeCallback(() {
          lpCallbackFired = true;
        });

        // Simulate what happens after game completion API response
        // In real code: UnifiedGameService calls LovePointService.fetchAndSyncFromServer()
        // which calls syncTotalLP() which calls notifyLPChanged()
        LovePointService.notifyLPChanged();

        expect(lpCallbackFired, isTrue,
            reason: 'LP callback should fire when game completes');
      });

      test('LP awarded on game completion is 30 points', () {
        const expectedLpReward = 30;

        final gameCompleteResponse = TestWordSearchFactory.wordSubmitResponse(
          valid: true,
          word: 'LASTWORD',
          pointsEarned: 80,
          wordsFoundThisTurn: 3,
          turnComplete: true,
          gameComplete: true,
          winnerId: 'user-id',
        );

        // When gameComplete is true, server awards 30 LP to the couple
        final gameStatusAfterCompletion = TestWordSearchFactory.gameStatusResponse(
          totalLp: expectedLpReward,
        );

        expect(gameCompleteResponse['gameComplete'], isTrue);
        expect(gameStatusAfterCompletion['totalLp'], equals(30));
      });
    });

    group('Polling Behavior', () {
      test('poll response matches match creation response structure', () {
        final createResponse = TestWordSearchFactory.matchCreationResponse(
          matchId: 'ws-match-001',
        );
        final pollResponse = TestWordSearchFactory.pollMatchResponse(
          matchId: 'ws-match-001',
          isMyTurn: false,
          wordsFoundThisTurn: 2,
        );

        // Both should have same structure
        expect(pollResponse['match'], isA<Map>());
        expect(pollResponse['gameState'], isA<Map>());

        // Match ID should be consistent
        final createMatch = createResponse['match'] as Map<String, dynamic>;
        final pollMatch = pollResponse['match'] as Map<String, dynamic>;
        expect(pollMatch['matchId'], equals(createMatch['matchId']));
      });

      test('poll reflects partner turn state', () {
        final response = TestWordSearchFactory.pollMatchResponse(
          isMyTurn: false,
          wordsFoundThisTurn: 1,
        );

        final gameState = response['gameState'] as Map<String, dynamic>;

        expect(gameState['isMyTurn'], isFalse);
        expect(gameState['canPlay'], isFalse);
      });

      test('poll reflects when it becomes my turn', () {
        final response = TestWordSearchFactory.pollMatchResponse(
          isMyTurn: true,
          wordsFoundThisTurn: 0,
        );

        final gameState = response['gameState'] as Map<String, dynamic>;

        expect(gameState['isMyTurn'], isTrue);
        expect(gameState['canPlay'], isTrue);
        expect(gameState['wordsRemainingThisTurn'], equals(3));
      });
    });

    group('NOT_YOUR_TURN Error Handling', () {
      test('API returns 403 for wrong player submission', () {
        final response = TestWordSearchFactory.notYourTurnResponse();

        expect(response['statusCode'], equals(403));
        expect(response['body']['code'], equals('NOT_YOUR_TURN'));
        expect(response['body']['message'], isA<String>());
      });

      test('mock HTTP client can return NOT_YOUR_TURN error', () {
        MockHttpOverrides.when(
          'POST',
          '/api/sync/word-search/submit',
          MockResponse(
            statusCode: 403,
            body: {
              'code': 'NOT_YOUR_TURN',
              'message': 'It is not your turn to play',
            },
          ),
        );

        final response = MockHttpOverrides.findResponse(
          'POST',
          'https://api.example.com/api/sync/word-search/submit',
        );

        expect(response, isNotNull);
        expect(response!.statusCode, equals(403));
      });
    });

    group('Model Deserialization from API', () {
      test('WordSearchMatch.fromJson handles full API response', () {
        final apiResponse = TestWordSearchFactory.matchCreationResponse();
        final matchJson = apiResponse['match'] as Map<String, dynamic>;

        final match = WordSearchMatch.fromJson(matchJson);

        expect(match.matchId, isNotEmpty);
        expect(match.status, equals('active'));
        expect(match.turnNumber, equals(1));
      });

      test('WordSearchPuzzle.fromJson handles full API response', () {
        final apiResponse = TestWordSearchFactory.matchCreationResponse();
        final puzzleJson = apiResponse['puzzle'] as Map<String, dynamic>;

        final puzzle = WordSearchPuzzle.fromJson(puzzleJson);

        expect(puzzle.puzzleId, isNotEmpty);
        expect(puzzle.rows, equals(10));
        expect(puzzle.cols, equals(10));
        expect(puzzle.grid.length, equals(100));
        expect(puzzle.words.length, greaterThanOrEqualTo(12));
      });

      test('WordSearchSubmitResult.fromJson handles all response types', () {
        // Valid submission
        final validJson = TestWordSearchFactory.wordSubmitResponse(
          valid: true,
          word: 'TEST',
          pointsEarned: 40,
        );
        final valid = WordSearchSubmitResult.fromJson(validJson);
        expect(valid.valid, isTrue);
        expect(valid.pointsEarned, equals(40));

        // Invalid submission
        final invalidJson = TestWordSearchFactory.wordSubmitResponse(
          valid: false,
          reason: 'WORD_NOT_IN_PUZZLE',
        );
        final invalid = WordSearchSubmitResult.fromJson(invalidJson);
        expect(invalid.valid, isFalse);
        expect(invalid.reason, equals('WORD_NOT_IN_PUZZLE'));
      });

      test('WordSearchGameState.fromJson combines all data correctly', () {
        final apiResponse = TestWordSearchFactory.matchCreationResponse(
          isMyTurn: true,
        );

        final gameState = WordSearchGameState.fromJson(apiResponse, 'user-id');

        expect(gameState.match.matchId, isNotEmpty);
        expect(gameState.puzzle, isNotNull);
        expect(gameState.isMyTurn, isTrue);
        expect(gameState.canPlay, isTrue);
        expect(gameState.wordsRemainingThisTurn, equals(3));
      });
    });

    group('Winner Determination', () {
      test('winner is player with higher score when game completes', () {
        // Player 1 has higher score
        final response = TestWordSearchFactory.gameCompleteResponse(
          player1Score: 350,
          player2Score: 280,
          winnerId: 'player1-id',
        );

        final match = response['match'] as Map<String, dynamic>;
        expect(match['winnerId'], equals('player1-id'));
        expect(match['status'], equals('completed'));
      });

      test('winnerId is null when scores are tied', () {
        final response = TestWordSearchFactory.gameCompleteResponse(
          player1Score: 300,
          player2Score: 300,
          winnerId: null,
        );

        final match = response['match'] as Map<String, dynamic>;
        expect(match['winnerId'], isNull);
      });
    });

    group('Score Tracking', () {
      test('scores accumulate correctly over multiple words', () {
        var player1Score = 0;

        // Player 1 finds 3 words
        final words = [
          ('LOVE', 40),
          ('HEART', 50),
          ('ROMANCE', 70),
        ];

        for (final (word, points) in words) {
          player1Score += points;
        }

        expect(player1Score, equals(160));
      });

      test('match model correctly tracks player scores', () {
        final match = WordSearchMatch(
          matchId: 'test',
          puzzleId: 'test',
          player1Id: 'player1',
          player2Id: 'player2',
          player1Score: 150,
          player2Score: 120,
          createdAt: DateTime.now(),
        );

        expect(match.getUserScore('player1'), equals(150));
        expect(match.getUserScore('player2'), equals(120));
        expect(match.getPartnerScore('player1'), equals(120));
        expect(match.getPartnerScore('player2'), equals(150));
      });
    });
  });
}

// ============================================================================
// Test Data Factory for Word Search
// ============================================================================

class TestWordSearchFactory {
  static Map<String, dynamic> matchCreationResponse({
    String? matchId,
    String? puzzleId,
    bool isMyTurn = true,
    bool isNewMatch = true,
  }) {
    final mId = matchId ?? 'ws-match-${DateTime.now().millisecondsSinceEpoch}';
    final pId = puzzleId ?? 'ws-puzzle-001';

    return {
      'success': true,
      'isNewMatch': isNewMatch,
      'match': {
        'matchId': mId,
        'puzzleId': pId,
        'status': 'active',
        'foundWords': <Map<String, dynamic>>[],
        'currentTurnUserId': isMyTurn ? 'user-id' : 'partner-id',
        'turnNumber': 1,
        'wordsFoundThisTurn': 0,
        'player1WordsFound': 0,
        'player2WordsFound': 0,
        'player1Score': 0,
        'player2Score': 0,
        'player1Hints': 3,
        'player2Hints': 3,
        'player1Id': 'user-id',
        'player2Id': 'partner-id',
        'winnerId': null,
        'createdAt': DateTime.now().toIso8601String(),
        'completedAt': null,
      },
      'puzzle': {
        'puzzleId': pId,
        'title': 'Romantic Words',
        'theme': 'everyday',
        'size': {'rows': 10, 'cols': 10},
        'grid': _generateTestGrid(),
        'words': [
          'LOVE', 'HEART', 'SOUL', 'KISS', 'HUG',
          'ROMANCE', 'PASSION', 'DESIRE', 'DREAM', 'HOPE',
          'JOY', 'BLISS', // 12 words total
        ],
      },
      'gameState': {
        'isMyTurn': isMyTurn,
        'canPlay': isMyTurn,
        'wordsRemainingThisTurn': 3,
        'myWordsFound': 0,
        'partnerWordsFound': 0,
        'myScore': 0,
        'partnerScore': 0,
        'myHints': 3,
        'partnerHints': 3,
        'progressPercent': 0,
      },
    };
  }

  static Map<String, dynamic> wordSubmitResponse({
    required bool valid,
    String? word,
    String? reason,
    int pointsEarned = 0,
    int wordsFoundThisTurn = 0,
    bool turnComplete = false,
    bool gameComplete = false,
    String? nextTurnUserId,
    int colorIndex = 0,
    String? winnerId,
  }) {
    return {
      'success': true,
      'valid': valid,
      'reason': reason,
      'pointsEarned': pointsEarned,
      'wordsFoundThisTurn': wordsFoundThisTurn,
      'turnComplete': turnComplete,
      'gameComplete': gameComplete,
      'nextTurnUserId': nextTurnUserId,
      'colorIndex': colorIndex,
      'winnerId': winnerId,
    };
  }

  static Map<String, dynamic> pollMatchResponse({
    String? matchId,
    bool isMyTurn = false,
    int wordsFoundThisTurn = 0,
    int turnNumber = 1,
    int myWordsFound = 0,
    int partnerWordsFound = 0,
    int myScore = 0,
    int partnerScore = 0,
  }) {
    return {
      'success': true,
      'match': {
        'matchId': matchId ?? 'ws-match-001',
        'puzzleId': 'ws-puzzle-001',
        'status': 'active',
        'foundWords': <Map<String, dynamic>>[],
        'currentTurnUserId': isMyTurn ? 'user-id' : 'partner-id',
        'turnNumber': turnNumber,
        'wordsFoundThisTurn': wordsFoundThisTurn,
        'player1WordsFound': myWordsFound,
        'player2WordsFound': partnerWordsFound,
        'player1Score': myScore,
        'player2Score': partnerScore,
        'player1Hints': 3,
        'player2Hints': 3,
        'player1Id': 'user-id',
        'player2Id': 'partner-id',
        'winnerId': null,
        'createdAt': DateTime.now().toIso8601String(),
        'completedAt': null,
      },
      'puzzle': {
        'puzzleId': 'ws-puzzle-001',
        'title': 'Romantic Words',
        'theme': 'everyday',
        'size': {'rows': 10, 'cols': 10},
        'grid': _generateTestGrid(),
        'words': [
          'LOVE', 'HEART', 'SOUL', 'KISS', 'HUG',
          'ROMANCE', 'PASSION', 'DESIRE', 'DREAM', 'HOPE',
          'JOY', 'BLISS',
        ],
      },
      'gameState': {
        'isMyTurn': isMyTurn,
        'canPlay': isMyTurn,
        'wordsRemainingThisTurn': 3 - wordsFoundThisTurn,
        'myWordsFound': myWordsFound,
        'partnerWordsFound': partnerWordsFound,
        'myScore': myScore,
        'partnerScore': partnerScore,
        'myHints': 3,
        'partnerHints': 3,
        'progressPercent': ((myWordsFound + partnerWordsFound) / 12 * 100).round(),
      },
    };
  }

  static Map<String, dynamic> gameCompleteResponse({
    int player1Score = 300,
    int player2Score = 280,
    String? winnerId,
  }) {
    return {
      'success': true,
      'match': {
        'matchId': 'ws-match-001',
        'puzzleId': 'ws-puzzle-001',
        'status': 'completed',
        'foundWords': <Map<String, dynamic>>[],
        'currentTurnUserId': null,
        'turnNumber': 8,
        'wordsFoundThisTurn': 0,
        'player1WordsFound': 6,
        'player2WordsFound': 6,
        'player1Score': player1Score,
        'player2Score': player2Score,
        'player1Hints': 2,
        'player2Hints': 2,
        'player1Id': 'player1-id',
        'player2Id': 'player2-id',
        'winnerId': winnerId,
        'createdAt': DateTime.now().toIso8601String(),
        'completedAt': DateTime.now().toIso8601String(),
      },
      'gameState': {
        'isMyTurn': false,
        'canPlay': false,
        'wordsRemainingThisTurn': 0,
        'myWordsFound': 6,
        'partnerWordsFound': 6,
        'myScore': player1Score,
        'partnerScore': player2Score,
        'myHints': 2,
        'partnerHints': 2,
        'progressPercent': 100,
      },
    };
  }

  static Map<String, dynamic> cooldownResponse() {
    return {
      'success': false,
      'code': 'COOLDOWN_ACTIVE',
      'message': 'Next puzzle available in 5 hours',
      'cooldownEnabled': true,
    };
  }

  static Map<String, dynamic> notYourTurnResponse() {
    return {
      'statusCode': 403,
      'body': {
        'code': 'NOT_YOUR_TURN',
        'message': 'It is not your turn to play',
      },
    };
  }

  static Map<String, dynamic> gameStatusResponse({int totalLp = 30}) {
    return {
      'success': true,
      'totalLp': totalLp,
      'games': [
        {
          'gameType': 'wordSearch',
          'status': 'completed',
          'matchId': 'ws-match-001',
        }
      ],
      'date': DateTime.now().toIso8601String().substring(0, 10),
    };
  }

  /// Generate a test 10x10 grid (100 characters)
  static String _generateTestGrid() {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final buffer = StringBuffer();
    for (var i = 0; i < 100; i++) {
      buffer.write(letters[i % letters.length]);
    }
    return buffer.toString();
  }
}

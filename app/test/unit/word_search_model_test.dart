/// Word Search Model Unit Tests
///
/// Tests for Word Search data models and helper methods.
/// These are pure unit tests with no external dependencies.
///
/// Run: cd app && flutter test test/unit/word_search_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:togetherremind/models/word_search.dart';

void main() {
  group('WordSearchMatch', () {
    group('Card State Logic', () {
      test('returns completed state when match is complete', () {
        final match = _createMatch(status: 'completed');

        final state = match.getCardState('user1');

        expect(state, equals(WordSearchCardState.completed));
      });

      test('returns yourTurnFresh when it is user turn and no words found this turn', () {
        final match = _createMatch(
          status: 'active',
          currentTurnUserId: 'user1',
          wordsFoundThisTurn: 0,
        );

        final state = match.getCardState('user1');

        expect(state, equals(WordSearchCardState.yourTurnFresh));
      });

      test('returns yourTurnInProgress when user turn and 1-2 words found', () {
        final match = _createMatch(
          status: 'active',
          currentTurnUserId: 'user1',
          wordsFoundThisTurn: 2,
        );

        final state = match.getCardState('user1');

        expect(state, equals(WordSearchCardState.yourTurnInProgress));
      });

      test('returns partnerTurn when it is not user turn', () {
        final match = _createMatch(
          status: 'active',
          currentTurnUserId: 'partner1',
          wordsFoundThisTurn: 0,
        );

        final state = match.getCardState('user1');

        expect(state, equals(WordSearchCardState.partnerTurn));
      });
    });

    group('Progress Tracking', () {
      test('calculates progress percentage correctly', () {
        final match = _createMatch(foundWordCount: 6);

        expect(match.progressPercent, equals(0.5));
        expect(match.progressPercentInt, equals(50));
      });

      test('progress is 0 when no words found', () {
        final match = _createMatch(foundWordCount: 0);

        expect(match.progressPercent, equals(0.0));
        expect(match.progressPercentInt, equals(0));
      });

      test('progress is 1.0 (100%) when all 12 words found', () {
        final match = _createMatch(foundWordCount: 12);

        expect(match.progressPercent, equals(1.0));
        expect(match.progressPercentInt, equals(100));
      });

      test('totalWordsFound returns correct count', () {
        final match = _createMatch(foundWordCount: 7);

        expect(match.totalWordsFound, equals(7));
      });
    });

    group('Turn Management', () {
      test('wordsRemainingThisTurn calculates correctly', () {
        expect(_createMatch(wordsFoundThisTurn: 0).wordsRemainingThisTurn, equals(3));
        expect(_createMatch(wordsFoundThisTurn: 1).wordsRemainingThisTurn, equals(2));
        expect(_createMatch(wordsFoundThisTurn: 2).wordsRemainingThisTurn, equals(1));
        expect(_createMatch(wordsFoundThisTurn: 3).wordsRemainingThisTurn, equals(0));
      });

      test('isTurnFresh is true only when 0 words found this turn', () {
        expect(_createMatch(wordsFoundThisTurn: 0).isTurnFresh, isTrue);
        expect(_createMatch(wordsFoundThisTurn: 1).isTurnFresh, isFalse);
        expect(_createMatch(wordsFoundThisTurn: 2).isTurnFresh, isFalse);
      });

      test('isTurnInProgress is true when 1-2 words found this turn', () {
        expect(_createMatch(wordsFoundThisTurn: 0).isTurnInProgress, isFalse);
        expect(_createMatch(wordsFoundThisTurn: 1).isTurnInProgress, isTrue);
        expect(_createMatch(wordsFoundThisTurn: 2).isTurnInProgress, isTrue);
        expect(_createMatch(wordsFoundThisTurn: 3).isTurnInProgress, isFalse);
      });
    });

    group('Score and Word Count Getters', () {
      test('getUserWordCount returns correct count for each player', () {
        final match = _createMatch(
          player1WordsFound: 5,
          player2WordsFound: 3,
        );

        expect(match.getUserWordCount('user1'), equals(5));
        expect(match.getUserWordCount('partner1'), equals(3));
        expect(match.getUserWordCount('unknown'), equals(0));
      });

      test('getPartnerWordCount returns correct count', () {
        final match = _createMatch(
          player1WordsFound: 5,
          player2WordsFound: 3,
        );

        expect(match.getPartnerWordCount('user1'), equals(3));
        expect(match.getPartnerWordCount('partner1'), equals(5));
      });

      test('getUserScore returns correct score for each player', () {
        final match = _createMatch(
          player1Score: 150,
          player2Score: 120,
        );

        expect(match.getUserScore('user1'), equals(150));
        expect(match.getUserScore('partner1'), equals(120));
        expect(match.getUserScore('unknown'), equals(0));
      });

      test('getPartnerScore returns correct score', () {
        final match = _createMatch(
          player1Score: 150,
          player2Score: 120,
        );

        expect(match.getPartnerScore('user1'), equals(120));
        expect(match.getPartnerScore('partner1'), equals(150));
      });
    });

    group('Winner Logic', () {
      test('didUserWin returns null when game not completed', () {
        final match = _createMatch(status: 'active');

        expect(match.didUserWin('user1'), isNull);
      });

      test('didUserWin returns null when winnerId is null (tie)', () {
        final match = _createMatch(status: 'completed', winnerId: null);

        expect(match.didUserWin('user1'), isNull);
      });

      test('didUserWin returns true when user won', () {
        final match = _createMatch(status: 'completed', winnerId: 'user1');

        expect(match.didUserWin('user1'), isTrue);
        expect(match.didUserWin('partner1'), isFalse);
      });
    });

    group('Found Word Tracking', () {
      test('isWordFound correctly identifies found words', () {
        final match = _createMatchWithWords(['LOVE', 'HEART']);

        expect(match.isWordFound('LOVE'), isTrue);
        expect(match.isWordFound('love'), isTrue); // Case insensitive
        expect(match.isWordFound('HEART'), isTrue);
        expect(match.isWordFound('SOUL'), isFalse);
      });

      test('getFoundWord returns word data when found', () {
        final match = _createMatchWithWords(['LOVE']);

        final found = match.getFoundWord('love');

        expect(found, isNotNull);
        expect(found!.word, equals('LOVE'));
      });

      test('getFoundWord returns null when word not found', () {
        final match = _createMatchWithWords(['LOVE']);

        expect(match.getFoundWord('SOUL'), isNull);
      });
    });

    group('JSON Serialization', () {
      test('fromJson creates valid match from API response', () {
        final json = {
          'matchId': 'match-123',
          'puzzleId': 'puzzle-456',
          'status': 'active',
          'foundWords': [
            {
              'word': 'LOVE',
              'foundBy': 'user1',
              'turnNumber': 1,
              'positions': [
                {'row': 0, 'col': 0},
                {'row': 0, 'col': 1},
              ],
              'colorIndex': 0,
            }
          ],
          'currentTurnUserId': 'user1',
          'turnNumber': 2,
          'wordsFoundThisTurn': 1,
          'player1WordsFound': 1,
          'player2WordsFound': 0,
          'player1Score': 40,
          'player2Score': 0,
          'player1Hints': 3,
          'player2Hints': 3,
          'player1Id': 'user1',
          'player2Id': 'partner1',
          'winnerId': null,
          'createdAt': '2025-12-01T10:00:00Z',
          'completedAt': null,
        };

        final match = WordSearchMatch.fromJson(json);

        expect(match.matchId, equals('match-123'));
        expect(match.puzzleId, equals('puzzle-456'));
        expect(match.status, equals('active'));
        expect(match.foundWords.length, equals(1));
        expect(match.foundWords[0].word, equals('LOVE'));
        expect(match.currentTurnUserId, equals('user1'));
        expect(match.turnNumber, equals(2));
        expect(match.player1Score, equals(40));
      });

      test('fromJson handles missing optional fields with defaults', () {
        final json = {
          'matchId': 'match-123',
          'puzzleId': 'puzzle-456',
          'player1Id': 'user1',
          'player2Id': 'partner1',
        };

        final match = WordSearchMatch.fromJson(json);

        expect(match.status, equals('active'));
        expect(match.foundWords, isEmpty);
        expect(match.turnNumber, equals(1));
        expect(match.wordsFoundThisTurn, equals(0));
        expect(match.player1Hints, equals(3));
        expect(match.player2Hints, equals(3));
      });
    });

    group('CopyWith', () {
      test('copyWith creates new instance with updated fields', () {
        final original = _createMatch(
          status: 'active',
          turnNumber: 1,
          wordsFoundThisTurn: 0,
        );

        final updated = original.copyWith(
          status: 'completed',
          turnNumber: 5,
        );

        // Original unchanged
        expect(original.status, equals('active'));
        expect(original.turnNumber, equals(1));

        // Updated has new values
        expect(updated.status, equals('completed'));
        expect(updated.turnNumber, equals(5));

        // Unchanged fields preserved
        expect(updated.matchId, equals(original.matchId));
        expect(updated.puzzleId, equals(original.puzzleId));
      });
    });
  });

  group('WordSearchPuzzle', () {
    test('letterAt returns correct letter at row/col', () {
      final puzzle = WordSearchPuzzle(
        puzzleId: 'test',
        title: 'Test Puzzle',
        rows: 3,
        cols: 3,
        grid: 'ABCDEFGHI',
        words: ['ABC'],
      );

      expect(puzzle.letterAt(0, 0), equals('A'));
      expect(puzzle.letterAt(0, 2), equals('C'));
      expect(puzzle.letterAt(1, 0), equals('D'));
      expect(puzzle.letterAt(2, 2), equals('I'));
    });

    test('letterAtIndex returns correct letter', () {
      final puzzle = WordSearchPuzzle(
        puzzleId: 'test',
        title: 'Test Puzzle',
        rows: 3,
        cols: 3,
        grid: 'ABCDEFGHI',
        words: ['ABC'],
      );

      expect(puzzle.letterAtIndex(0), equals('A'));
      expect(puzzle.letterAtIndex(4), equals('E'));
      expect(puzzle.letterAtIndex(8), equals('I'));
    });

    test('indexToPosition converts correctly', () {
      final puzzle = WordSearchPuzzle(
        puzzleId: 'test',
        title: 'Test Puzzle',
        rows: 10,
        cols: 10,
        grid: 'A' * 100,
        words: [],
      );

      expect(puzzle.indexToPosition(0), equals((row: 0, col: 0)));
      expect(puzzle.indexToPosition(5), equals((row: 0, col: 5)));
      expect(puzzle.indexToPosition(10), equals((row: 1, col: 0)));
      expect(puzzle.indexToPosition(45), equals((row: 4, col: 5)));
    });

    test('positionToIndex converts correctly', () {
      final puzzle = WordSearchPuzzle(
        puzzleId: 'test',
        title: 'Test Puzzle',
        rows: 10,
        cols: 10,
        grid: 'A' * 100,
        words: [],
      );

      expect(puzzle.positionToIndex(0, 0), equals(0));
      expect(puzzle.positionToIndex(0, 5), equals(5));
      expect(puzzle.positionToIndex(1, 0), equals(10));
      expect(puzzle.positionToIndex(4, 5), equals(45));
    });

    test('fromJson parses puzzle correctly', () {
      final json = {
        'puzzleId': 'ws_001',
        'title': 'Romantic Words',
        'theme': 'romance',
        'size': {'rows': 10, 'cols': 10},
        'grid': 'A' * 100,
        'words': ['LOVE', 'HEART', 'SOUL'],
      };

      final puzzle = WordSearchPuzzle.fromJson(json);

      expect(puzzle.puzzleId, equals('ws_001'));
      expect(puzzle.title, equals('Romantic Words'));
      expect(puzzle.theme, equals('romance'));
      expect(puzzle.rows, equals(10));
      expect(puzzle.cols, equals(10));
      expect(puzzle.words, equals(['LOVE', 'HEART', 'SOUL']));
    });
  });

  group('WordSearchSubmitResult', () {
    test('fromJson parses valid submission result', () {
      final json = {
        'valid': true,
        'pointsEarned': 40,
        'wordsFoundThisTurn': 2,
        'turnComplete': false,
        'gameComplete': false,
        'nextTurnUserId': null,
        'colorIndex': 1,
        'winnerId': null,
      };

      final result = WordSearchSubmitResult.fromJson(json);

      expect(result.valid, isTrue);
      expect(result.pointsEarned, equals(40));
      expect(result.wordsFoundThisTurn, equals(2));
      expect(result.turnComplete, isFalse);
      expect(result.gameComplete, isFalse);
      expect(result.colorIndex, equals(1));
    });

    test('fromJson parses rejection with reason', () {
      final json = {
        'valid': false,
        'reason': 'WORD_NOT_IN_PUZZLE',
      };

      final result = WordSearchSubmitResult.fromJson(json);

      expect(result.valid, isFalse);
      expect(result.reason, equals('WORD_NOT_IN_PUZZLE'));
      expect(result.pointsEarned, equals(0));
    });

    test('fromJson parses game completion', () {
      final json = {
        'valid': true,
        'pointsEarned': 50,
        'wordsFoundThisTurn': 3,
        'turnComplete': true,
        'gameComplete': true,
        'nextTurnUserId': null,
        'colorIndex': 5,
        'winnerId': 'user1',
      };

      final result = WordSearchSubmitResult.fromJson(json);

      expect(result.gameComplete, isTrue);
      expect(result.winnerId, equals('user1'));
    });
  });

  group('GridPosition', () {
    test('equality works correctly', () {
      final pos1 = GridPosition(5, 3);
      final pos2 = GridPosition(5, 3);
      final pos3 = GridPosition(3, 5);

      expect(pos1, equals(pos2));
      expect(pos1, isNot(equals(pos3)));
    });

    test('toJson creates correct map', () {
      final pos = GridPosition(5, 3);

      expect(pos.toJson(), equals({'row': 5, 'col': 3}));
    });

    test('toString is readable', () {
      final pos = GridPosition(5, 3);

      expect(pos.toString(), equals('GridPosition(5, 3)'));
    });
  });
}

// ============================================================================
// Test Helpers
// ============================================================================

WordSearchMatch _createMatch({
  String status = 'active',
  String? currentTurnUserId = 'user1',
  int wordsFoundThisTurn = 0,
  int turnNumber = 1,
  int player1WordsFound = 0,
  int player2WordsFound = 0,
  int player1Score = 0,
  int player2Score = 0,
  int foundWordCount = 0,
  String? winnerId,
}) {
  final foundWords = List.generate(
    foundWordCount,
    (i) => WordSearchFoundWord(
      word: 'WORD$i',
      foundByUserId: i % 2 == 0 ? 'user1' : 'partner1',
      turnNumber: (i ~/ 3) + 1,
    ),
  );

  return WordSearchMatch(
    matchId: 'test-match',
    puzzleId: 'test-puzzle',
    status: status,
    currentTurnUserId: currentTurnUserId,
    wordsFoundThisTurn: wordsFoundThisTurn,
    turnNumber: turnNumber,
    player1WordsFound: player1WordsFound,
    player2WordsFound: player2WordsFound,
    player1Score: player1Score,
    player2Score: player2Score,
    player1Id: 'user1',
    player2Id: 'partner1',
    foundWords: foundWords,
    winnerId: winnerId,
    createdAt: DateTime.now(),
  );
}

WordSearchMatch _createMatchWithWords(List<String> words) {
  return WordSearchMatch(
    matchId: 'test-match',
    puzzleId: 'test-puzzle',
    status: 'active',
    player1Id: 'user1',
    player2Id: 'partner1',
    createdAt: DateTime.now(),
    foundWords: words.map((w) => WordSearchFoundWord(
      word: w.toUpperCase(),
      foundByUserId: 'user1',
      turnNumber: 1,
    )).toList(),
  );
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:togetherremind/models/memory_flip.dart';
import 'package:togetherremind/services/memory_flip_service.dart';
import 'package:togetherremind/services/storage_service.dart';

void main() {
  late MemoryFlipService service;
  late StorageService storage;
  late Directory tempDir;

  setUpAll(() async {
    // Create a temporary directory for Hive
    tempDir = await Directory.systemTemp.createTemp('hive_test_');

    // Initialize Hive with temp directory
    Hive.init(tempDir.path);

    // Register adapters
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(MemoryPuzzleAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(MemoryCardAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(MemoryFlipAllowanceAdapter());
    }

    // Open test boxes
    await Hive.openBox<MemoryPuzzle>('memory_puzzles');
    await Hive.openBox<MemoryFlipAllowance>('memory_allowances');
  });

  tearDownAll(() async {
    // Close all boxes and delete temp directory
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() {
    service = MemoryFlipService();
    storage = StorageService();
  });

  tearDown(() async {
    // Clear boxes after each test
    final puzzleBox = Hive.box<MemoryPuzzle>('memory_puzzles');
    final allowanceBox = Hive.box<MemoryFlipAllowance>('memory_allowances');
    await puzzleBox.clear();
    await allowanceBox.clear();
  });

  group('Puzzle Generation', () {
    test('Generate puzzle with correct number of pairs', () async {
      final puzzle = await service.generateDailyPuzzle();

      expect(puzzle.totalPairs, equals(8));
      expect(puzzle.cards.length, equals(16)); // 8 pairs = 16 cards
      expect(puzzle.status, equals('active'));
      expect(puzzle.matchedPairs, equals(0));
    });

    test('Shuffle cards randomly', () async {
      final puzzle1 = await service.generateDailyPuzzle();

      // Delete first puzzle and generate second
      await Hive.box<MemoryPuzzle>('memory_puzzles').delete(puzzle1.id);
      final puzzle2 = await service.generateDailyPuzzle();

      // Cards should be in different positions (high probability)
      final positions1 = puzzle1.cards.map((c) => c.emoji).toList();
      final positions2 = puzzle2.cards.map((c) => c.emoji).toList();

      expect(positions1, isNot(equals(positions2)));
    });

    test('Each pair has exactly 2 cards with same emoji', () async {
      final puzzle = await service.generateDailyPuzzle();

      // Group cards by emoji
      final emojiCounts = <String, int>{};
      for (var card in puzzle.cards) {
        emojiCounts[card.emoji] = (emojiCounts[card.emoji] ?? 0) + 1;
      }

      // Each emoji should appear exactly twice
      for (var count in emojiCounts.values) {
        expect(count, equals(2));
      }
    });

    test('All cards start as hidden', () async {
      final puzzle = await service.generateDailyPuzzle();

      for (var card in puzzle.cards) {
        expect(card.status, equals('hidden'));
        expect(card.isHidden, isTrue);
        expect(card.isMatched, isFalse);
      }
    });

    test('Puzzle has completion quote', () async {
      final puzzle = await service.generateDailyPuzzle();

      expect(puzzle.completionQuote, isNotEmpty);
    });

    test('Puzzle expires after 7 days', () async {
      final puzzle = await service.generateDailyPuzzle();

      final duration = puzzle.expiresAt.difference(puzzle.createdAt);
      expect(duration.inDays, equals(7));
    });
  });

  group('Flip Allowance', () {
    test('Initial allowance is 6 flips', () async {
      final allowance = await service.getFlipAllowance('user123');

      expect(allowance.flipsRemaining, equals(6));
      expect(allowance.totalFlipsToday, equals(0));
      expect(allowance.canFlip, isTrue);
    });

    test('Can flip when allowance >= 2', () async {
      final allowance = await service.getFlipAllowance('user123');

      expect(allowance.canFlip, isTrue);

      // Set to 2 flips
      allowance.flipsRemaining = 2;
      await storage.updateMemoryAllowance(allowance);

      final updated = await service.getFlipAllowance('user123');
      expect(updated.canFlip, isTrue);
    });

    test('Cannot flip when allowance is 1', () async {
      final allowance = await service.getFlipAllowance('user123');

      allowance.flipsRemaining = 1;
      await storage.updateMemoryAllowance(allowance);

      final updated = await service.getFlipAllowance('user123');
      expect(updated.canFlip, isFalse);
    });

    test('Cannot flip when allowance is 0', () async {
      final allowance = await service.getFlipAllowance('user123');

      allowance.flipsRemaining = 0;
      await storage.updateMemoryAllowance(allowance);

      final updated = await service.getFlipAllowance('user123');
      expect(updated.canFlip, isFalse);
    });

    test('Flip allowance decrements by 2 per turn', () async {
      final allowance = await service.getFlipAllowance('user123');
      final initialFlips = allowance.flipsRemaining;

      await service.decrementFlipAllowance('user123');

      final updated = await service.getFlipAllowance('user123');
      expect(updated.flipsRemaining, equals(initialFlips - 2));
      expect(updated.totalFlipsToday, equals(2));
    });

    test('Cannot decrement when less than 2 flips remain', () async {
      final allowance = await service.getFlipAllowance('user123');
      allowance.flipsRemaining = 1;
      await storage.updateMemoryAllowance(allowance);

      expect(
        () async => await service.decrementFlipAllowance('user123'),
        throwsException,
      );
    });

    test('Daily allowance resets correctly', () async {
      final allowance = await service.getFlipAllowance('user123');
      allowance.flipsRemaining = 0;
      allowance.totalFlipsToday = 6;
      await storage.updateMemoryAllowance(allowance);

      await service.resetDailyAllowance('user123');

      final reset = await service.getFlipAllowance('user123');
      expect(reset.flipsRemaining, equals(6));
      expect(reset.totalFlipsToday, equals(0));
    });
  });

  group('Match Detection', () {
    test('Match detection works for matching cards', () async {
      final puzzle = await service.generateDailyPuzzle();
      final firstEmoji = puzzle.cards[0].emoji;

      // Find the two cards with the same emoji
      final matchingCards =
          puzzle.cards.where((c) => c.emoji == firstEmoji).toList();
      expect(matchingCards.length, equals(2));

      final card1 = matchingCards[0];
      final card2 = matchingCards[1];

      final matchResult = await service.checkForMatches(
        puzzle,
        card1,
        card2,
        'user123',
      );

      expect(matchResult, isNotNull);
      expect(matchResult!.card1.emoji, equals(card1.emoji));
      expect(matchResult.card2.emoji, equals(card2.emoji));
      expect(matchResult.quote, isNotEmpty);
      expect(matchResult.lovePoints, equals(10));
    });

    test('No match for non-matching cards', () async {
      final puzzle = await service.generateDailyPuzzle();

      // Find two cards with different emojis
      final card1 = puzzle.cards.firstWhere((c) => true);
      final card2 = puzzle.cards.firstWhere((c) => c.emoji != card1.emoji);

      final matchResult = await service.checkForMatches(
        puzzle,
        card1,
        card2,
        'user123',
      );

      expect(matchResult, isNull);
    });

    test('Matching cards stay permanently revealed', () async {
      final puzzle = await service.generateDailyPuzzle();
      final firstEmoji = puzzle.cards[0].emoji;

      final matchingCards =
          puzzle.cards.where((c) => c.emoji == firstEmoji).toList();
      final card1 = matchingCards[0];
      final card2 = matchingCards[1];

      await service.matchCards(puzzle, card1, card2, 'user123');

      expect(card1.status, equals('matched'));
      expect(card2.status, equals('matched'));
      expect(card1.isMatched, isTrue);
      expect(card2.isMatched, isTrue);
      expect(card1.matchedBy, equals('user123'));
      expect(card2.matchedBy, equals('user123'));
    });

    test('Puzzle progress updates after match', () async {
      final puzzle = await service.generateDailyPuzzle();
      expect(puzzle.matchedPairs, equals(0));

      final firstEmoji = puzzle.cards[0].emoji;
      final matchingCards =
          puzzle.cards.where((c) => c.emoji == firstEmoji).toList();

      await service.matchCards(
        puzzle,
        matchingCards[0],
        matchingCards[1],
        'user123',
      );

      expect(puzzle.matchedPairs, equals(1));
    });

    test('Puzzle completes when all pairs matched', () async {
      final puzzle = await service.generateDailyPuzzle();

      // Match all pairs
      final emojiGroups = <String, List<MemoryCard>>{};
      for (var card in puzzle.cards) {
        emojiGroups[card.emoji] = emojiGroups[card.emoji] ?? [];
        emojiGroups[card.emoji]!.add(card);
      }

      for (var pair in emojiGroups.values) {
        await service.matchCards(puzzle, pair[0], pair[1], 'user123');
      }

      expect(puzzle.status, equals('completed'));
      expect(puzzle.completedAt, isNotNull);
      expect(puzzle.matchedPairs, equals(puzzle.totalPairs));
    });
  });

  group('Love Points Calculation', () {
    test('Match points are 10', () {
      final points = service.calculateMatchPoints();
      expect(points, equals(10));
    });

    test('Completion points calculated correctly - fast completion', () async {
      final puzzle = await service.generateDailyPuzzle();
      puzzle.status = 'completed';
      puzzle.completedAt = puzzle.createdAt.add(Duration(days: 1));

      final points = service.calculateCompletionPoints(puzzle);

      // 50 (base) + 80 (8 pairs × 10) + 25 (time bonus: 30 - 5×1)
      expect(points, equals(155));
    });

    test('Completion points calculated correctly - slow completion', () async {
      final puzzle = await service.generateDailyPuzzle();
      puzzle.status = 'completed';
      puzzle.completedAt = puzzle.createdAt.add(Duration(days: 7));

      final points = service.calculateCompletionPoints(puzzle);

      // 50 (base) + 80 (8 pairs × 10) + 0 (time bonus: 30 - 5×7 = -5, capped at 0)
      expect(points, equals(130));
    });
  });

  group('Helper Methods', () {
    test('Get matched cards', () async {
      final puzzle = await service.generateDailyPuzzle();
      final firstEmoji = puzzle.cards[0].emoji;
      final matchingCards =
          puzzle.cards.where((c) => c.emoji == firstEmoji).toList();

      await service.matchCards(
        puzzle,
        matchingCards[0],
        matchingCards[1],
        'user123',
      );

      final matched = service.getMatchedCards(puzzle);
      expect(matched.length, equals(2));
    });

    test('Get hidden cards', () async {
      final puzzle = await service.generateDailyPuzzle();
      final firstEmoji = puzzle.cards[0].emoji;
      final matchingCards =
          puzzle.cards.where((c) => c.emoji == firstEmoji).toList();

      await service.matchCards(
        puzzle,
        matchingCards[0],
        matchingCards[1],
        'user123',
      );

      final hidden = service.getHiddenCards(puzzle);
      expect(hidden.length, equals(14)); // 16 - 2 matched
    });

    test('Get puzzle progress percentage', () async {
      final puzzle = await service.generateDailyPuzzle();
      expect(service.getPuzzleProgress(puzzle), equals(0.0));

      puzzle.matchedPairs = 4;
      expect(service.getPuzzleProgress(puzzle), equals(0.5));

      puzzle.matchedPairs = 8;
      expect(service.getPuzzleProgress(puzzle), equals(1.0));
    });

    test('Check puzzle expiration', () async {
      final puzzle = await service.generateDailyPuzzle();

      expect(service.isPuzzleExpired(puzzle), isFalse);

      // Set expiry to past
      puzzle.expiresAt = DateTime.now().subtract(Duration(days: 1));
      expect(service.isPuzzleExpired(puzzle), isTrue);
    });

    test('Format time until reset', () async {
      final allowance = await service.getFlipAllowance('user123');

      // Set reset time to 3 hours from now
      allowance.resetsAt = DateTime.now().add(Duration(hours: 3));
      await storage.updateMemoryAllowance(allowance);

      final updated = await service.getFlipAllowance('user123');
      final formatted = service.formatTimeUntilReset(updated);

      expect(formatted, contains('h'));
    });
  });

  group('Edge Cases', () {
    test('Cannot flip already matched card', () async {
      final puzzle = await service.generateDailyPuzzle();
      final card = puzzle.cards[0];

      // Mark card as matched
      card.status = 'matched';
      await storage.updateMemoryPuzzle(puzzle);

      expect(
        () async => await service.flipCard(card.id, 'user123'),
        throwsException,
      );
    });

    test('Get current puzzle creates new if none exists', () async {
      final puzzle = await service.getCurrentPuzzle();

      expect(puzzle, isNotNull);
      expect(puzzle.status, equals('active'));
    });

    test('Expired puzzle triggers new puzzle generation', () async {
      final oldPuzzle = await service.generateDailyPuzzle();
      oldPuzzle.expiresAt = DateTime.now().subtract(Duration(days: 1));
      await storage.updateMemoryPuzzle(oldPuzzle);

      final newPuzzle = await service.getCurrentPuzzle();

      expect(newPuzzle.id, isNot(equals(oldPuzzle.id)));
      expect(newPuzzle.status, equals('active'));
    });
  });
}

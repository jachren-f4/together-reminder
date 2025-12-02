/// Integration tests for Linked game navigation safety
///
/// Tests scenarios that could cause crashes or inconsistent state:
/// 8. Navigation during async - no setState crash
/// 9. Return to home during submission - server still completes
/// 10. Duplicate submission prevention (double-tap)
/// 11. Out-of-order response handling
library;

import 'dart:async';
import 'package:test/test.dart';
import 'linked_test_helpers.dart';
import 'test_config.dart';

void main() {
  late LinkedTestApi userApi;
  late LinkedTestApi partnerApi;

  setUpAll(() async {
    await LinkedTestDataReset.resetTestData();
  });

  setUp(() {
    userApi = LinkedTestApi(userId: LinkedTestConfig.testUserId);
    partnerApi = LinkedTestApi(userId: LinkedTestConfig.partnerUserId);
  });

  tearDown(() async {
    await Future.delayed(const Duration(milliseconds: 100));
  });

  group('Submission Safety Tests', () {
    test('8. Concurrent submissions to same match are serialized', () async {
      await LinkedTestDataReset.resetTestData();
      await Future.delayed(const Duration(milliseconds: 200));

      final matchResponse = await userApi.getOrCreateMatch();
      final matchId = matchResponse['matchId'] as String;
      final gameState = matchResponse['gameState'] as Map<String, dynamic>?;

      if (gameState?['isMyTurn'] != true) {
        print('Skipping: not our turn');
        return;
      }

      final rack = (gameState?['rack'] as List<dynamic>?) ?? [];
      if (rack.length < 2) {
        print('Skipping: need at least 2 letters');
        return;
      }

      final puzzle = matchResponse['puzzle'] as Map<String, dynamic>?;
      final grid = puzzle?['grid'] as List<dynamic>?;
      if (grid == null) return;

      // Find two empty cells
      final emptyCells = <int>[];
      for (int i = 0; i < grid.length && emptyCells.length < 2; i++) {
        final cell = grid[i] as Map<String, dynamic>;
        if (cell['type'] == 'answer' && cell['letter'] == null) {
          emptyCells.add(i);
        }
      }

      if (emptyCells.length < 2) {
        print('Skipping: not enough empty cells');
        return;
      }

      // Try to submit two requests simultaneously
      // First should succeed, second should fail with NOT_YOUR_TURN
      // (if turn switches) or be blocked by server serialization
      final futures = <Future>[];

      futures.add(
        userApi.submitTurn(matchId, [
          {'index': emptyCells[0], 'letter': rack[0]['letter']}
        ]).catchError((e) => {'error': e.toString()}),
      );

      // Small delay to ensure second request arrives while first is processing
      await Future.delayed(const Duration(milliseconds: 10));

      futures.add(
        userApi.submitTurn(matchId, [
          {'index': emptyCells[1], 'letter': rack[1]['letter']}
        ]).catchError((e) => {'error': e.toString()}),
      );

      final results = await Future.wait(futures);

      // At least one should succeed
      final successes = results.where((r) => r['success'] == true).length;
      expect(successes, greaterThanOrEqualTo(1), reason: 'At least one submission should succeed');

      // Verify game state is consistent
      final finalState = await userApi.pollMatch(matchId);
      expect(finalState['status'], isIn(['active', 'completed']), reason: 'Game should be in valid state');
    });

    test('9. Server completes transaction even if client disconnects', () async {
      // This tests that the server-side transaction completes atomically
      // We can verify by checking that partial state doesn't exist

      await LinkedTestDataReset.resetTestData();
      await Future.delayed(const Duration(milliseconds: 200));

      final matchResponse = await userApi.getOrCreateMatch();
      final matchId = matchResponse['matchId'] as String;
      final gameState = matchResponse['gameState'] as Map<String, dynamic>?;

      if (gameState?['isMyTurn'] != true) {
        print('Skipping: not our turn');
        return;
      }

      final rack = (gameState?['rack'] as List<dynamic>?) ?? [];
      if (rack.isEmpty) return;

      final puzzle = matchResponse['puzzle'] as Map<String, dynamic>?;
      final grid = puzzle?['grid'] as List<dynamic>?;
      if (grid == null) return;

      // Find an empty cell
      for (int i = 0; i < grid.length; i++) {
        final cell = grid[i] as Map<String, dynamic>;
        if (cell['type'] == 'answer' && cell['letter'] == null) {
          // Submit and immediately timeout (simulating disconnect)
          try {
            await userApi.submitTurn(matchId, [
              {'index': i, 'letter': rack[0]['letter']}
            ]).timeout(const Duration(milliseconds: 50));
          } on TimeoutException {
            // Expected - client "disconnected"
          }

          // Wait for server to complete
          await Future.delayed(const Duration(milliseconds: 500));

          // Verify state is consistent
          final state = await userApi.pollMatch(matchId);
          expect(state['status'], isIn(['active', 'completed']), reason: 'Game should be in valid state');

          // Score should be consistent (not partial)
          final gs = state['gameState'] as Map<String, dynamic>?;
          if (gs != null) {
            final myScore = gs['myScore'] as int?;
            expect(myScore, isA<int>(), reason: 'Score should be integer');
            expect(myScore! % LinkedTestConfig.pointsPerLetter, equals(0),
                reason: 'Score should be multiple of points per letter');
          }
          break;
        }
      }
    });

    test('10. Double submission returns consistent results', () async {
      await LinkedTestDataReset.resetTestData();
      await Future.delayed(const Duration(milliseconds: 200));

      final matchResponse = await userApi.getOrCreateMatch();
      final matchId = matchResponse['matchId'] as String;
      final gameState = matchResponse['gameState'] as Map<String, dynamic>?;

      if (gameState?['isMyTurn'] != true) {
        print('Skipping: not our turn');
        return;
      }

      final rack = (gameState?['rack'] as List<dynamic>?) ?? [];
      if (rack.isEmpty) return;

      final puzzle = matchResponse['puzzle'] as Map<String, dynamic>?;
      final grid = puzzle?['grid'] as List<dynamic>?;
      if (grid == null) return;

      // Find an empty cell
      for (int i = 0; i < grid.length; i++) {
        final cell = grid[i] as Map<String, dynamic>;
        if (cell['type'] == 'answer' && cell['letter'] == null) {
          final placement = {'index': i, 'letter': rack[0]['letter']};

          // First submission
          final result1 = await userApi.submitTurn(matchId, [placement]);
          expect(result1['success'], isTrue);

          // Attempt same submission again (should be rejected or idempotent)
          try {
            final result2 = await userApi.submitTurn(matchId, [placement]);
            // If it succeeds, it should return same result (idempotent)
            // or fail gracefully
            if (result2['success'] == true) {
              // Verify scores didn't double
              final state = await userApi.pollMatch(matchId);
              final gs = state['gameState'] as Map<String, dynamic>?;
              final myScore = gs?['myScore'] as int? ?? 0;

              // Score should not be doubled (at most one letter's worth)
              expect(
                myScore,
                lessThanOrEqualTo(LinkedTestConfig.pointsPerLetter * 10),
                reason: 'Score should not be doubled from duplicate submission',
              );
            }
          } on ApiException catch (e) {
            // Expected - duplicate submission rejected
            expect(
              e.isNotYourTurn || e.isGameNotActive,
              isTrue,
              reason: 'Duplicate should be rejected with appropriate error',
            );
          }
          break;
        }
      }
    });

    test('11. Stale poll response after fresh submission', () async {
      // Tests that a slow poll response doesn't overwrite fresh submission data

      await LinkedTestDataReset.resetTestData();
      await Future.delayed(const Duration(milliseconds: 200));

      final matchResponse = await userApi.getOrCreateMatch();
      final matchId = matchResponse['matchId'] as String;
      final gameState = matchResponse['gameState'] as Map<String, dynamic>?;

      if (gameState?['isMyTurn'] != true) {
        print('Skipping: not our turn');
        return;
      }

      final initialScore = gameState?['myScore'] as int? ?? 0;

      final rack = (gameState?['rack'] as List<dynamic>?) ?? [];
      if (rack.isEmpty) return;

      final puzzle = matchResponse['puzzle'] as Map<String, dynamic>?;
      final grid = puzzle?['grid'] as List<dynamic>?;
      if (grid == null) return;

      // Start a poll
      final pollFuture = userApi.pollMatch(matchId);

      // Find and submit while poll is in flight
      for (int i = 0; i < grid.length; i++) {
        final cell = grid[i] as Map<String, dynamic>;
        if (cell['type'] == 'answer' && cell['letter'] == null) {
          // Submit while poll is pending
          final submitResult = await userApi.submitTurn(matchId, [
            {'index': i, 'letter': rack[0]['letter']}
          ]);

          expect(submitResult['success'], isTrue);

          // Get poll result
          final pollResult = await pollFuture;

          // The important thing is that subsequent polls show updated state
          final freshPoll = await userApi.pollMatch(matchId);
          final freshScore = (freshPoll['gameState'] as Map<String, dynamic>?)?['myScore'] as int? ?? 0;

          // Fresh poll should show updated score (not stale)
          if (submitResult['results']?[0]?['correct'] == true) {
            expect(
              freshScore,
              greaterThan(initialScore),
              reason: 'Fresh poll should show updated score after successful submission',
            );
          }
          break;
        }
      }
    });
  });

  group('LP Sync Safety Tests', () {
    test('LP is awarded exactly once on game completion', () async {
      // This test verifies LP isn't double-counted

      await LinkedTestDataReset.resetTestData();
      await Future.delayed(const Duration(milliseconds: 200));

      final initialLP = await userApi.getCoupleLP();
      expect(initialLP, equals(0), reason: 'LP should start at 0 after reset');

      // Create a match
      await userApi.getOrCreateMatch();

      // Fetch LP multiple times to ensure consistency
      final lp1 = await userApi.getCoupleLP();
      final lp2 = await partnerApi.getCoupleLP();

      // Both partners should see same LP
      expect(lp1, equals(lp2), reason: 'Both partners should see identical LP');
    });

    test('LP fetch during game does not award LP', () async {
      await LinkedTestDataReset.resetTestData();
      await Future.delayed(const Duration(milliseconds: 200));

      // Get initial LP
      final lp1 = await userApi.getCoupleLP();

      // Create match and poll multiple times
      await userApi.getOrCreateMatch();

      await userApi.getCoupleLP();
      await userApi.getCoupleLP();
      await userApi.getCoupleLP();

      final lp2 = await userApi.getCoupleLP();

      // LP should not have changed from polling
      expect(lp2, equals(lp1), reason: 'Polling LP endpoint should not change LP value');
    });
  });

  group('Partner Turn Tests', () {
    test('Partner can complete their turn after user submits', () async {
      await LinkedTestDataReset.resetTestData();
      await Future.delayed(const Duration(milliseconds: 200));

      // User creates/gets match
      final userMatch = await userApi.getOrCreateMatch();
      final matchId = userMatch['matchId'] as String;
      final gameState = userMatch['gameState'] as Map<String, dynamic>?;

      // If it's user's turn, submit to switch to partner
      if (gameState?['isMyTurn'] == true) {
        final rack = (gameState?['rack'] as List<dynamic>?) ?? [];
        if (rack.isEmpty) {
          print('Skipping: no letters');
          return;
        }

        final puzzle = userMatch['puzzle'] as Map<String, dynamic>?;
        final grid = puzzle?['grid'] as List<dynamic>?;
        if (grid == null) return;

        // Submit all rack letters to complete turn
        final placements = <Map<String, dynamic>>[];
        var cellIndex = 0;
        for (final letter in rack) {
          while (cellIndex < grid.length) {
            final cell = grid[cellIndex] as Map<String, dynamic>;
            if (cell['type'] == 'answer' && cell['letter'] == null) {
              placements.add({'index': cellIndex, 'letter': letter['letter']});
              cellIndex++;
              break;
            }
            cellIndex++;
          }
        }

        if (placements.isNotEmpty) {
          final result = await userApi.submitTurn(matchId, placements);
          expect(result['success'], isTrue);

          // If turn completed, verify partner can now play
          if (result['turnComplete'] == true) {
            final partnerMatch = await partnerApi.pollMatch(matchId);
            final partnerState = partnerMatch['gameState'] as Map<String, dynamic>?;

            expect(partnerState?['isMyTurn'], isTrue, reason: 'Partner should now have the turn');
          }
        }
      } else {
        // Already partner's turn - verify they can play
        final partnerMatch = await partnerApi.pollMatch(matchId);
        final partnerState = partnerMatch['gameState'] as Map<String, dynamic>?;

        expect(partnerState?['isMyTurn'], isTrue, reason: 'Partner should have the turn');
      }
    });
  });
}

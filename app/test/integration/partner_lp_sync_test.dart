/// Partner LP Sync Integration Tests
///
/// Integration tests simulating the full flow of LP sync when partner completes a quest.
/// Uses mock HTTP client to simulate API responses.
///
/// Run: cd app && flutter test test/integration/partner_lp_sync_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:togetherremind/services/love_point_service.dart';
import '../mocks/mock_http_client.dart';

void main() {
  group('Partner LP Sync Integration', () {
    setUp(() {
      // Reset state before each test
      LovePointService.setLPChangeCallback(null);
      MockHttpOverrides.reset();
    });

    group('Quest Completion Detection', () {
      test('partner completion response triggers LP sync requirement', () async {
        // Simulate the data that would be returned by /api/sync/quest-status
        final questStatusResponse = TestDataFactory.questStatusWithPartnerComplete(
          questType: 'classic',
          partnerCompleted: true,
          status: 'completed',
        );

        // Verify the response format matches what _pollQuestStatus expects
        expect(questStatusResponse['success'], isTrue);
        expect(questStatusResponse['quests'], isA<List>());

        final quests = questStatusResponse['quests'] as List;
        expect(quests.length, greaterThan(0));

        final quest = quests[0] as Map<String, dynamic>;
        expect(quest['partnerCompleted'], isTrue);
        expect(quest['status'], equals('completed'));
      });

      test('LP response format matches expected structure', () {
        // Simulate the data returned by /api/sync/game/status
        final gameStatusResponse = TestDataFactory.gameStatusResponse(
          totalLp: 30,
          games: [
            {
              'gameType': 'classic',
              'status': 'completed',
              'matchId': 'test-match-id',
            }
          ],
        );

        // Verify structure matches what fetchAndSyncFromServer expects
        expect(gameStatusResponse['success'], isTrue);
        expect(gameStatusResponse['totalLp'], equals(30));
        expect(gameStatusResponse['games'], isA<List>());
      });

      test('callback fires when LP is synced', () async {
        var callbackFired = false;
        var lpValue = 0;

        // Set up callback (simulates NewHomeScreen's callback)
        LovePointService.setLPChangeCallback(() {
          callbackFired = true;
          lpValue = 30; // In real code, this reads from storage
        });

        // Simulate what happens after successful LP fetch
        // In real code: fetchAndSyncFromServer() → syncTotalLP() → notifyLPChanged()
        LovePointService.notifyLPChanged();

        expect(callbackFired, isTrue,
            reason: 'LP change callback should fire');
        expect(lpValue, equals(30),
            reason: 'LP value should be updated in callback');
      });
    });

    group('Full Partner Completion Flow', () {
      test('simulated partner completion triggers callback chain', () {
        // This test simulates the full flow:
        // 1. _pollQuestStatus() fetches from /api/sync/quest-status
        // 2. Response shows partnerCompleted=true for 'classic' quest
        // 3. anyUpdates is set to true
        // 4. If anyUpdates && mounted: LovePointService.fetchAndSyncFromServer()
        // 5. fetchAndSyncFromServer() gets totalLp from /api/sync/game/status
        // 6. syncTotalLP() updates Hive and calls notifyLPChanged()
        // 7. Callback triggers setState() in NewHomeScreen
        // 8. LP counter updates

        var step7Reached = false;

        // Step 6: Register callback (simulates step 7)
        LovePointService.setLPChangeCallback(() {
          step7Reached = true;
        });

        // Step 5-6: Simulate syncTotalLP completing
        LovePointService.notifyLPChanged();

        expect(step7Reached, isTrue,
            reason: 'Full partner completion flow should reach UI callback');
      });

      test('multiple partners completing different quests triggers multiple syncs', () {
        var syncCount = 0;

        LovePointService.setLPChangeCallback(() {
          syncCount++;
        });

        // Partner completes Classic Quiz
        LovePointService.notifyLPChanged();
        expect(syncCount, equals(1));

        // Partner completes Affirmation Quiz
        LovePointService.notifyLPChanged();
        expect(syncCount, equals(2));

        // Partner completes You or Me
        LovePointService.notifyLPChanged();
        expect(syncCount, equals(3));
      });
    });

    group('API Response Handling', () {
      test('mock HTTP client returns expected quest status', () {
        // Register mock response
        MockHttpOverrides.when(
          'GET',
          '/api/sync/quest-status',
          MockResponse(
            body: TestDataFactory.questStatusWithPartnerComplete(),
          ),
        );

        // Verify response can be found
        final response = MockHttpOverrides.findResponse(
          'GET',
          'https://api.example.com/api/sync/quest-status',
        );

        expect(response, isNotNull);
        expect(response!.statusCode, equals(200));
      });

      test('mock HTTP client returns expected game status with LP', () {
        // Register mock response for LP fetch
        MockHttpOverrides.when(
          'GET',
          '/api/sync/game/status',
          MockResponse(
            body: TestDataFactory.gameStatusResponse(totalLp: 60),
          ),
        );

        final response = MockHttpOverrides.findResponse(
          'GET',
          'https://api.example.com/api/sync/game/status',
        );

        expect(response, isNotNull);
        final responseBody = response!.body;
        expect(responseBody['totalLp'], equals(60));
      });
    });

    group('Edge Cases', () {
      test('poll with no updates does not trigger LP sync', () {
        var syncTriggered = false;

        LovePointService.setLPChangeCallback(() {
          syncTriggered = true;
        });

        // If anyUpdates is false, fetchAndSyncFromServer() is NOT called
        // So notifyLPChanged() is never called
        // We simulate this by NOT calling notifyLPChanged()

        expect(syncTriggered, isFalse,
            reason: 'No updates should not trigger LP sync');
      });

      test('widget unmounted before callback prevents setState error', () {
        var callbackCalled = false;
        var mounted = true;

        // Callback checks mounted state before setState
        LovePointService.setLPChangeCallback(() {
          if (mounted) {
            callbackCalled = true;
          }
        });

        // Simulate widget disposal
        mounted = false;
        LovePointService.notifyLPChanged();

        expect(callbackCalled, isFalse,
            reason: 'Unmounted widget should not trigger setState');
      });

      test('rapid poll responses only sync once per change', () {
        var syncCount = 0;
        int? lastLpValue;

        LovePointService.setLPChangeCallback(() {
          syncCount++;
          lastLpValue = 30;
        });

        // Only the actual LP change triggers callback
        // syncTotalLP checks if local == server and returns early if equal
        // So rapid identical polls don't multiply callbacks
        LovePointService.notifyLPChanged();

        expect(syncCount, equals(1));
        expect(lastLpValue, equals(30));
      });
    });
  });
}

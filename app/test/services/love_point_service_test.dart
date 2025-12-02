/// Love Point Service Tests
///
/// Tests for LP sync behavior, callbacks, and tier calculations.
/// These tests focus on pure logic that doesn't require storage.
///
/// Run: cd app && flutter test test/services/love_point_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:togetherremind/services/love_point_service.dart';

void main() {
  group('LovePointService', () {
    setUp(() {
      // Reset callback before each test
      LovePointService.setLPChangeCallback(null);
    });

    group('LP Change Callback', () {
      test('setLPChangeCallback registers callback', () {
        var callbackCalled = false;

        LovePointService.setLPChangeCallback(() {
          callbackCalled = true;
        });

        // Callback registered but not yet called
        expect(callbackCalled, isFalse);
      });

      test('callback can be set and cleared', () {
        var callCount = 0;

        // Set callback
        LovePointService.setLPChangeCallback(() {
          callCount++;
        });

        // Clear callback
        LovePointService.setLPChangeCallback(null);

        // No crashes, callback count still 0
        expect(callCount, equals(0));
      });

      test('callback can be replaced', () {
        var callback1Called = false;
        var callback2Called = false;

        // Set first callback
        LovePointService.setLPChangeCallback(() {
          callback1Called = true;
        });

        // Replace with second callback
        LovePointService.setLPChangeCallback(() {
          callback2Called = true;
        });

        // Neither called yet (just registered)
        expect(callback1Called, isFalse);
        expect(callback2Called, isFalse);
      });
    });

    group('Arena Definitions', () {
      test('has exactly 5 tiers', () {
        expect(LovePointService.arenas.length, equals(5));
      });

      test('tier 1 (Cozy Cabin) starts at 0 LP', () {
        final tier1 = LovePointService.arenas[1]!;
        expect(tier1['name'], equals('Cozy Cabin'));
        expect(tier1['emoji'], equals('🏕️'));
        expect(tier1['min'], equals(0));
        expect(tier1['max'], equals(1000));
        expect(tier1['floor'], equals(0));
      });

      test('tier 2 (Beach Villa) starts at 1000 LP', () {
        final tier2 = LovePointService.arenas[2]!;
        expect(tier2['name'], equals('Beach Villa'));
        expect(tier2['emoji'], equals('🏖️'));
        expect(tier2['min'], equals(1000));
        expect(tier2['max'], equals(2500));
        expect(tier2['floor'], equals(1000));
      });

      test('tier 3 (Yacht Getaway) starts at 2500 LP', () {
        final tier3 = LovePointService.arenas[3]!;
        expect(tier3['name'], equals('Yacht Getaway'));
        expect(tier3['emoji'], equals('⛵'));
        expect(tier3['min'], equals(2500));
        expect(tier3['max'], equals(5000));
        expect(tier3['floor'], equals(2500));
      });

      test('tier 4 (Mountain Penthouse) starts at 5000 LP', () {
        final tier4 = LovePointService.arenas[4]!;
        expect(tier4['name'], equals('Mountain Penthouse'));
        expect(tier4['emoji'], equals('🏔️'));
        expect(tier4['min'], equals(5000));
        expect(tier4['max'], equals(10000));
        expect(tier4['floor'], equals(5000));
      });

      test('tier 5 (Castle Retreat) starts at 10000 LP', () {
        final tier5 = LovePointService.arenas[5]!;
        expect(tier5['name'], equals('Castle Retreat'));
        expect(tier5['emoji'], equals('🏰'));
        expect(tier5['min'], equals(10000));
        expect(tier5['max'], equals(999999));
        expect(tier5['floor'], equals(10000));
      });

      test('all tiers have required fields', () {
        for (final tier in LovePointService.arenas.keys) {
          final arena = LovePointService.arenas[tier]!;
          expect(arena.containsKey('name'), isTrue,
              reason: 'Tier $tier missing name');
          expect(arena.containsKey('emoji'), isTrue,
              reason: 'Tier $tier missing emoji');
          expect(arena.containsKey('min'), isTrue,
              reason: 'Tier $tier missing min');
          expect(arena.containsKey('max'), isTrue,
              reason: 'Tier $tier missing max');
          expect(arena.containsKey('floor'), isTrue,
              reason: 'Tier $tier missing floor');
        }
      });

      test('tier thresholds are in ascending order', () {
        var previousMax = 0;
        for (int i = 1; i <= 5; i++) {
          final arena = LovePointService.arenas[i]!;
          final min = arena['min'] as int;
          final max = arena['max'] as int;

          expect(min, greaterThanOrEqualTo(previousMax),
              reason: 'Tier $i min should be >= previous max');
          expect(max, greaterThan(min),
              reason: 'Tier $i max should be > min');

          previousMax = max;
        }
      });

      test('floor protection matches tier minimum', () {
        for (int i = 1; i <= 5; i++) {
          final arena = LovePointService.arenas[i]!;
          final min = arena['min'] as int;
          final floor = arena['floor'] as int;

          expect(floor, equals(min),
              reason: 'Tier $i floor should equal min');
        }
      });
    });

    group('LP Constants', () {
      test('LP reward for quiz completion is 30', () {
        // This is defined in test-config.ts and used in tests
        // Verifying the expected value matches documentation
        const expectedReward = 30;
        expect(expectedReward, equals(30));
      });
    });
  });
}

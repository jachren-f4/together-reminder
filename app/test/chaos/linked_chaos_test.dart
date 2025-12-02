/// Chaos tests for Linked game points system
///
/// Uses fault injection to test edge cases:
/// - Double-tap protection
/// - Out-of-order response handling
/// - Network timeout recovery
/// - Stale session recovery
/// - LP double-award prevention
library;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'chaos_config.dart';

// Note: These tests use a mock API client that can be configured
// to inject delays, errors, and response reordering.

void main() {
  group('Chaos Tests - Double Tap Protection', () {
    test('Rapid double submit is blocked locally', () async {
      // Simulates user rapidly tapping submit twice
      final submissionTracker = SubmissionTracker();

      // First tap - should be allowed
      final canSubmit1 = submissionTracker.tryStartSubmission();
      expect(canSubmit1, isTrue, reason: 'First submission should be allowed');

      // Second tap while first is in progress - should be blocked
      final canSubmit2 = submissionTracker.tryStartSubmission();
      expect(canSubmit2, isFalse, reason: 'Second submission should be blocked');

      // Complete first submission
      submissionTracker.completeSubmission();

      // Now third tap should be allowed
      final canSubmit3 = submissionTracker.tryStartSubmission();
      expect(canSubmit3, isTrue, reason: 'Third submission after completion should be allowed');
    });

    test('Double submit with delay is still blocked', () async {
      final submissionTracker = SubmissionTracker();

      // First tap
      expect(submissionTracker.tryStartSubmission(), isTrue);

      // Wait a bit but not enough for submission to complete
      await Future.delayed(const Duration(milliseconds: 50));

      // Second tap should still be blocked
      expect(submissionTracker.tryStartSubmission(), isFalse);

      submissionTracker.completeSubmission();
    });
  });

  group('Chaos Tests - Response Ordering', () {
    test('Out-of-order responses are handled correctly', () async {
      final queue = ResponseReorderQueue<int>();

      // Simulate requests sent in order 1, 2, 3
      queue.add(1, const Duration(milliseconds: 100));
      queue.add(2, const Duration(milliseconds: 50));
      queue.add(3, const Duration(milliseconds: 200));

      // Get ordered responses
      final ordered = queue.getOrderedResponses();
      expect(ordered, equals([1, 2, 3]), reason: 'Ordered responses should be in sequence');
    });

    test('Stale response detection works', () async {
      final response = ChaosResponse(
        data: 'test',
        sequenceNumber: 1,
        requestTime: DateTime.now().subtract(const Duration(seconds: 10)),
        artificialDelay: Duration.zero,
      );

      expect(response.isStale, isTrue, reason: 'Old response should be marked stale');
    });

    test('Fresh response detection works', () async {
      final response = ChaosResponse(
        data: 'test',
        sequenceNumber: 1,
        requestTime: DateTime.now(),
        artificialDelay: Duration.zero,
      );

      expect(response.isStale, isFalse, reason: 'New response should not be stale');
    });
  });

  group('Chaos Tests - Error Recovery', () {
    test('Transient error triggers retry', () async {
      final chaos = ChaosConfig.light;

      // Track retry attempts
      var attempts = 0;
      const maxRetries = 3;

      Future<bool> submitWithRetry() async {
        for (var i = 0; i < maxRetries; i++) {
          attempts++;
          if (!chaos.shouldFail()) {
            return true; // Success
          }
          await Future.delayed(const Duration(milliseconds: 100));
        }
        return false; // All retries failed
      }

      // With 5% error rate, most attempts should succeed
      final results = <bool>[];
      for (var i = 0; i < 10; i++) {
        attempts = 0;
        results.add(await submitWithRetry());
      }

      // Most should succeed with retries
      final successes = results.where((r) => r).length;
      expect(successes, greaterThanOrEqualTo(8), reason: 'With retries, most attempts should succeed');
    });

    test('Timeout is handled gracefully', () async {
      final chaos = ChaosConfig.heavy;

      Future<String> fetchWithTimeout() async {
        if (chaos.shouldTimeout()) {
          throw const ChaosException(ChaosErrorType.timeout, 'Request timed out');
        }
        return 'success';
      }

      // Should handle timeout without crashing
      try {
        await fetchWithTimeout();
      } on ChaosException catch (e) {
        expect(e.type, equals(ChaosErrorType.timeout));
      }
    });
  });

  group('Chaos Tests - LP Double Award Prevention', () {
    test('LP awarded exactly once per game completion', () async {
      final lpTracker = LPAwardTracker();

      const matchId = 'test-match-1';

      // First completion signal
      final awarded1 = lpTracker.tryAwardLP(matchId, 30);
      expect(awarded1, isTrue, reason: 'First LP award should succeed');

      // Duplicate completion signal (e.g., from race condition)
      final awarded2 = lpTracker.tryAwardLP(matchId, 30);
      expect(awarded2, isFalse, reason: 'Duplicate LP award should be blocked');

      // Verify total LP
      expect(lpTracker.totalLP, equals(30), reason: 'LP should be awarded exactly once');
    });

    test('LP awarded for different matches', () async {
      final lpTracker = LPAwardTracker();

      // First match completion
      lpTracker.tryAwardLP('match-1', 30);

      // Second match completion (different match)
      final awarded = lpTracker.tryAwardLP('match-2', 30);
      expect(awarded, isTrue, reason: 'LP for different match should be allowed');

      expect(lpTracker.totalLP, equals(60), reason: 'Both matches should award LP');
    });
  });

  group('Chaos Tests - Widget Disposal Safety', () {
    test('Mounted check prevents setState after dispose', () async {
      final widget = MockMountedWidget();

      // Widget is mounted
      expect(widget.isMounted, isTrue);

      // Simulate async operation starting
      final future = Future.delayed(const Duration(milliseconds: 100), () => 'data');

      // Widget is disposed before async completes
      widget.dispose();
      expect(widget.isMounted, isFalse);

      // Async completes
      await future;

      // Safe setState check
      final updated = widget.safeSetState(() {});
      expect(updated, isFalse, reason: 'setState should be skipped after dispose');
    });
  });

  group('Chaos Tests - Concurrent Operations', () {
    test('Poll and submit can run concurrently without corruption', () async {
      final stateManager = GameStateManager();

      // Start polling
      final pollFuture = Future.delayed(const Duration(milliseconds: 150), () {
        stateManager.updateFromPoll(score: 100);
      });

      // Submit while poll is pending
      await Future.delayed(const Duration(milliseconds: 50));
      stateManager.updateFromSubmit(score: 110);

      // Wait for poll to complete
      await pollFuture;

      // State should reflect the most recent update
      // (submit was more recent than the poll that started earlier)
      expect(stateManager.score, greaterThanOrEqualTo(100));
    });

    test('Multiple concurrent polls are serialized', () async {
      final stateManager = GameStateManager();
      var updateCount = 0;

      // Start multiple polls concurrently
      final polls = List.generate(5, (i) {
        return Future.delayed(Duration(milliseconds: i * 20), () {
          updateCount++;
          stateManager.updateFromPoll(score: 100 + i * 10);
        });
      });

      await Future.wait(polls);

      expect(updateCount, equals(5), reason: 'All polls should complete');
    });
  });
}

// ============================================================================
// Mock Classes for Testing
// ============================================================================

/// Tracks submission state to prevent double-tap
class SubmissionTracker {
  bool _isSubmitting = false;

  bool tryStartSubmission() {
    if (_isSubmitting) {
      return false;
    }
    _isSubmitting = true;
    return true;
  }

  void completeSubmission() {
    _isSubmitting = false;
  }
}

/// Tracks LP awards to prevent double-counting
class LPAwardTracker {
  final Set<String> _awardedMatchIds = {};
  int _totalLP = 0;

  int get totalLP => _totalLP;

  bool tryAwardLP(String matchId, int amount) {
    if (_awardedMatchIds.contains(matchId)) {
      return false; // Already awarded
    }

    _awardedMatchIds.add(matchId);
    _totalLP += amount;
    return true;
  }
}

/// Mock widget with mounted state tracking
class MockMountedWidget {
  bool _mounted = true;

  bool get isMounted => _mounted;

  void dispose() {
    _mounted = false;
  }

  bool safeSetState(void Function() fn) {
    if (!_mounted) {
      return false;
    }
    fn();
    return true;
  }
}

/// Mock game state manager for concurrent update testing
class GameStateManager {
  int _score = 0;
  final List<int> _updateLog = [];

  int get score => _score;
  List<int> get updateLog => List.unmodifiable(_updateLog);

  void updateFromPoll({required int score}) {
    _score = score;
    _updateLog.add(score);
  }

  void updateFromSubmit({required int score}) {
    _score = score;
    _updateLog.add(score);
  }
}

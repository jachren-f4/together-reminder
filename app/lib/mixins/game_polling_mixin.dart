import 'dart:async';
import 'package:flutter/material.dart';

/// Mixin that provides polling functionality for turn-based game screens.
///
/// Use this mixin to standardize polling behavior across game screens:
/// - Linked Game Screen
/// - Word Search Game Screen
/// - Quiz Match Game Screen
/// - You or Me Match Game Screen
///
/// ## Usage:
/// ```dart
/// class _LinkedGameScreenState extends State<LinkedGameScreen>
///     with GamePollingMixin {
///
///   @override
///   Duration get pollInterval => const Duration(seconds: 5);
///
///   @override
///   bool get shouldPoll => !_isLoading && !_isSubmitting && _gameState != null && !_gameState!.isMyTurn;
///
///   @override
///   Future<void> onPollUpdate() async {
///     final newState = await _service.pollMatchState(_gameState!.match.matchId);
///     if (mounted) {
///       setState(() => _gameState = newState);
///     }
///   }
///
///   @override
///   void initState() {
///     super.initState();
///     _loadGameState();
///   }
///
///   @override
///   void dispose() {
///     cancelPolling();
///     super.dispose();
///   }
/// }
/// ```
mixin GamePollingMixin<T extends StatefulWidget> on State<T> {
  Timer? _pollTimer;

  /// The interval between poll requests.
  /// Default is 5 seconds for consistent UX across all game screens.
  Duration get pollInterval => const Duration(seconds: 5);

  /// Whether polling should be active.
  /// Override this to define when polling should occur.
  /// Typically: `!isLoading && !isSubmitting && hasGameState && !isMyTurn`
  bool get shouldPoll;

  /// Called when a poll update should be fetched.
  /// Override this to implement the actual polling logic.
  Future<void> onPollUpdate();

  /// Optional callback when polling detects a turn change.
  /// Override to show "It's your turn!" toast, etc.
  void onTurnChange() {}

  /// Start the polling timer.
  /// Call this after loading game state.
  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) {
      if (shouldPoll) {
        _performPoll();
      }
    });
  }

  /// Cancel the polling timer.
  /// Call this in dispose().
  void cancelPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Restart polling with fresh interval.
  /// Useful after submission or state changes.
  void restartPolling() {
    cancelPolling();
    startPolling();
  }

  /// Perform a single poll operation.
  Future<void> _performPoll() async {
    try {
      await onPollUpdate();
    } catch (e) {
      // Silent failure for polling - don't disturb user
    }
  }

  /// Manually trigger a poll (e.g., on pull-to-refresh).
  Future<void> manualPoll() async {
    if (mounted) {
      await _performPoll();
    }
  }
}

/// Extension to help track turn changes during polling.
///
/// Use this when you need to detect when it becomes the user's turn:
/// ```dart
/// final wasPartnerTurn = !_gameState!.isMyTurn;
/// setState(() => _gameState = newState);
/// if (wasPartnerTurn && newState.isMyTurn) {
///   onTurnChange();
/// }
/// ```
class TurnTracker {
  bool _wasMyTurn = false;

  /// Call before updating state to track previous turn.
  void recordCurrentTurn(bool isMyTurn) {
    _wasMyTurn = isMyTurn;
  }

  /// Call after updating state to check if turn changed to user.
  /// Returns true if it just became the user's turn.
  bool didBecomeMyTurn(bool isMyTurn) {
    return !_wasMyTurn && isMyTurn;
  }

  /// Returns true if it just became partner's turn.
  bool didBecomePartnerTurn(bool isMyTurn) {
    return _wasMyTurn && !isMyTurn;
  }
}

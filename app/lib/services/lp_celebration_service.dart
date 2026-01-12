import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Data for an LP celebration animation
class LpCelebrationData {
  final Offset startPosition;
  final Offset endPosition;
  final int lpAmount;
  final VoidCallback? onComplete;

  LpCelebrationData({
    required this.startPosition,
    required this.endPosition,
    required this.lpAmount,
    this.onComplete,
  });
}

/// Global service for triggering LP celebration animations.
/// The animation is rendered at the app level (in MaterialApp builder)
/// so it's completely outside all navigators and won't follow scroll.
class LpCelebrationService {
  LpCelebrationService._();

  /// Current celebration data (null = no celebration showing)
  static final ValueNotifier<LpCelebrationData?> celebration =
      ValueNotifier<LpCelebrationData?>(null);

  /// Trigger a celebration animation
  static void trigger({
    required Offset startPosition,
    required Offset endPosition,
    required int lpAmount,
    VoidCallback? onComplete,
  }) {
    celebration.value = LpCelebrationData(
      startPosition: startPosition,
      endPosition: endPosition,
      lpAmount: lpAmount,
      onComplete: onComplete,
    );
  }

  /// Dismiss the current celebration
  static void dismiss() {
    celebration.value = null;
  }
}

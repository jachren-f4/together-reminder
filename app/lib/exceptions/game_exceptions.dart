/// Base class for all game-related exceptions
///
/// Unified exceptions for side quest games (Linked, Word Search, etc.)
/// These exceptions provide consistent error handling across all turn-based games.
abstract class GameException implements Exception {
  final String message;
  const GameException(this.message);

  @override
  String toString() => message;
}

/// Thrown when puzzle cooldown is active (8h cooldown after 2 plays)
class CooldownActiveException extends GameException {
  /// When the cooldown ends (ISO 8601 timestamp)
  final DateTime? cooldownEndsAt;

  /// Milliseconds until cooldown ends
  final int? cooldownRemainingMs;

  /// Number of plays remaining in current batch (0 when on cooldown)
  final int remainingInBatch;

  const CooldownActiveException(
    super.message, {
    this.cooldownEndsAt,
    this.cooldownRemainingMs,
    this.remainingInBatch = 0,
  });

  /// Format remaining time for display (e.g., "7 hours", "45 minutes")
  String get formattedTimeRemaining {
    if (cooldownRemainingMs == null) return '';

    final duration = Duration(milliseconds: cooldownRemainingMs!);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    } else if (minutes > 0) {
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    } else {
      return 'less than a minute';
    }
  }
}

/// Thrown when trying to play on opponent's turn
class NotYourTurnException extends GameException {
  const NotYourTurnException(super.message);
}

/// Thrown when game is not in active state
class GameNotActiveException extends GameException {
  const GameNotActiveException(super.message);
}

/// Thrown when no hints are remaining
class NoHintsRemainingException extends GameException {
  const NoHintsRemainingException(super.message);
}

/// Thrown when match is not found
class MatchNotFoundException extends GameException {
  const MatchNotFoundException(super.message);
}

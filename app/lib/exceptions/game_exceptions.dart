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

/// Thrown when puzzle cooldown is active (next puzzle available tomorrow)
class CooldownActiveException extends GameException {
  const CooldownActiveException(super.message);
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

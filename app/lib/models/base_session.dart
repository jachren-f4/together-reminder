/// Base class for all session types (QuizSession, YouOrMeSession, etc.)
/// Provides type-safe interface for unified screens
abstract class BaseSession {
  /// Unique session identifier
  String get id;

  /// When the session was created
  DateTime get createdAt;

  /// Whether both users have completed the session
  bool get isCompleted;

  /// Whether the session has expired (24-hour window)
  bool get isExpired {
    final now = DateTime.now();
    final expiryTime = DateTime(
      createdAt.year,
      createdAt.month,
      createdAt.day,
      23,
      59,
      59,
    );
    return now.isAfter(expiryTime);
  }

  /// Convert session to Firebase format
  Map<String, dynamic> toFirebase();

  /// Check if a specific user has answered/participated
  bool hasUserAnswered(String userId);
}

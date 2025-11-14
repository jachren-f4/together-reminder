import 'package:hive/hive.dart';

part 'quiz_progression_state.g.dart';

/// Tracks a couple's progression through the branching quiz system
///
/// The system has 3 tracks, each with 4 quizzes:
/// - Track 0: Relationship Foundations
/// - Track 1: Communication & Conflict
/// - Track 2: Future & Growth
@HiveType(typeId: 19)
class QuizProgressionState extends HiveObject {
  @HiveField(0)
  late String coupleId; // Unique ID for the couple

  @HiveField(1)
  late int currentTrack; // 0-2: which track they're on

  @HiveField(2)
  late int currentPosition; // 0-3: which quiz in the track (0 = not started)

  @HiveField(3)
  late Map<String, bool> completedQuizzes; // "track_position" -> completed
  // Example: "0_0": true means Track 0, Quiz 0 is completed

  @HiveField(4)
  late DateTime createdAt;

  @HiveField(5)
  DateTime? lastCompletedAt; // When the last quiz was completed

  @HiveField(6, defaultValue: 0)
  int totalQuizzesCompleted; // Running count of all completed quizzes

  @HiveField(7, defaultValue: false)
  bool hasCompletedAllTracks; // True when all 3 tracks are done

  QuizProgressionState({
    required this.coupleId,
    required this.currentTrack,
    required this.currentPosition,
    required this.completedQuizzes,
    required this.createdAt,
    this.lastCompletedAt,
    this.totalQuizzesCompleted = 0,
    this.hasCompletedAllTracks = false,
  });

  // Factory constructor for creating initial state
  factory QuizProgressionState.initial(String coupleId) {
    return QuizProgressionState(
      coupleId: coupleId,
      currentTrack: 0,
      currentPosition: 0,
      completedQuizzes: {},
      createdAt: DateTime.now(),
      totalQuizzesCompleted: 0,
      hasCompletedAllTracks: false,
    );
  }

  // Helper methods

  /// Get the current quiz ID that should be assigned
  String getCurrentQuizId() {
    return 'track_${currentTrack}_quiz_$currentPosition';
  }

  /// Check if a specific quiz has been completed
  bool isQuizCompleted(int track, int position) {
    final key = '${track}_$position';
    return completedQuizzes[key] ?? false;
  }

  /// Mark a quiz as completed and advance progression
  void completeQuiz(int track, int position) {
    final key = '${track}_$position';
    if (completedQuizzes[key] == true) {
      return; // Already completed
    }

    completedQuizzes[key] = true;
    totalQuizzesCompleted++;
    lastCompletedAt = DateTime.now();

    // Advance position if completing current quiz
    if (track == currentTrack && position == currentPosition) {
      _advancePosition();
    }
  }

  /// Advance to the next quiz in the progression
  void _advancePosition() {
    currentPosition++;

    // Check if we've completed the current track
    if (currentPosition >= 4) {
      currentTrack++;
      currentPosition = 0;

      // Check if we've completed all tracks
      if (currentTrack >= 3) {
        hasCompletedAllTracks = true;
        currentTrack = 2; // Stay on last track
        currentPosition = 3; // Stay on last position
      }
    }
  }

  /// Get completion percentage (0-100)
  int getCompletionPercentage() {
    const totalQuizzes = 12; // 3 tracks × 4 quizzes
    return ((totalQuizzesCompleted / totalQuizzes) * 100).round();
  }

  /// Get the track name
  String getTrackName() {
    switch (currentTrack) {
      case 0:
        return 'Relationship Foundations';
      case 1:
        return 'Communication & Conflict';
      case 2:
        return 'Future & Growth';
      default:
        return 'Unknown Track';
    }
  }

  /// Check if ready for next track
  bool isTrackCompleted(int track) {
    for (int i = 0; i < 4; i++) {
      if (!isQuizCompleted(track, i)) {
        return false;
      }
    }
    return true;
  }

  /// Get next available quiz (track, position)
  Map<String, int> getNextQuiz() {
    // If all tracks completed, return last quiz
    if (hasCompletedAllTracks) {
      return {'track': 2, 'position': 3};
    }

    // Find first incomplete quiz in current track
    for (int pos = 0; pos < 4; pos++) {
      if (!isQuizCompleted(currentTrack, pos)) {
        return {'track': currentTrack, 'position': pos};
      }
    }

    // Current track is done, move to next track
    return {'track': currentTrack + 1, 'position': 0};
  }
}

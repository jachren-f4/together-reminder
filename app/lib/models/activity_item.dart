// Unified activity model that wraps all activity types in the app
// Used by the Activity Hub to display a consolidated view of everything happening

enum ActivityType {
  reminder,
  poke,
  question,
  quiz,
  affirmation,
  wouldYouRather,
  dailyPulse,
}

enum ActivityStatus {
  yourTurn,           // Current user needs to act
  waitingForPartner,  // Current user acted, waiting for partner
  completed,          // Both users finished
  mutual,            // Special status for mutual pokes
  pending,           // Generic pending state
  expired,           // Activity expired
}

/// Represents a participant's status in an activity
class ParticipantStatus {
  final String userId;
  final String displayName;
  final bool hasCompleted;
  final DateTime? completedAt;

  ParticipantStatus({
    required this.userId,
    required this.displayName,
    required this.hasCompleted,
    this.completedAt,
  });

  /// Get first letter for avatar display
  String get initial => displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
}

/// Unified activity item that can represent any activity type
class ActivityItem {
  final String id;
  final ActivityType type;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final ActivityStatus status;
  final List<ParticipantStatus> participants;
  final dynamic sourceData; // Original model (QuizSession, Reminder, etc.)
  final bool isUnread;
  final String? emoji; // Optional emoji for the activity

  ActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.status,
    required this.participants,
    required this.sourceData,
    this.isUnread = false,
    this.emoji,
  });

  /// Get display label for activity type
  String get typeLabel {
    switch (type) {
      case ActivityType.reminder:
        return 'Reminder';
      case ActivityType.poke:
        return 'Poke';
      case ActivityType.question:
        return 'Question';
      case ActivityType.quiz:
        return 'Quiz';
      case ActivityType.affirmation:
        return 'Affirmation';
      case ActivityType.wouldYouRather:
        return 'Game';
      case ActivityType.dailyPulse:
        return 'Daily Pulse';
    }
  }

  /// Get emoji for activity type (if not overridden)
  String get displayEmoji {
    if (emoji != null) return emoji!;

    switch (type) {
      case ActivityType.reminder:
        return '📝';
      case ActivityType.poke:
        return '💫';
      case ActivityType.question:
        return '💭';
      case ActivityType.quiz:
        return '🎯';
      case ActivityType.affirmation:
        return '💗';
      case ActivityType.wouldYouRather:
        return '🤔';
      case ActivityType.dailyPulse:
        return '💗';
    }
  }

  /// Get status badge text
  String? get statusBadge {
    switch (status) {
      case ActivityStatus.yourTurn:
        return 'Your Turn';
      case ActivityStatus.waitingForPartner:
        return 'Waiting';
      case ActivityStatus.completed:
        return 'Completed';
      case ActivityStatus.mutual:
        return 'Mutual!';
      case ActivityStatus.expired:
        return 'Expired';
      case ActivityStatus.pending:
        return null; // No badge for pending
    }
  }

  /// Get participants who have completed
  List<ParticipantStatus> get completedParticipants {
    return participants.where((p) => p.hasCompleted).toList();
  }

  /// Check if both users completed
  bool get isBothCompleted {
    return participants.length == 2 &&
           participants.every((p) => p.hasCompleted);
  }

  /// Check if current user completed (requires userId)
  bool hasUserCompleted(String userId) {
    return participants
        .any((p) => p.userId == userId && p.hasCompleted);
  }
}

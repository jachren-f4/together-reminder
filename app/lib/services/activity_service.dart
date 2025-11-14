import '../models/activity_item.dart';
import '../services/storage_service.dart';
import '../services/poke_service.dart';

/// Service to aggregate all activities from different sources into a unified view
class ActivityService {
  final StorageService _storage = StorageService();

  /// Get current user's ID
  String _getCurrentUserId() {
    final user = _storage.getUser();
    return user?.id ?? '';
  }

  /// Get partner's name
  String _getPartnerName() {
    final partner = _storage.getPartner();
    return partner?.name ?? 'Partner';
  }

  /// Get user's name
  String _getUserName() {
    final user = _storage.getUser();
    return user?.name ?? 'You';
  }

  /// Get all activities from all sources
  List<ActivityItem> getAllActivities() {
    final activities = <ActivityItem>[];

    // Add reminders
    activities.addAll(_getReminders());

    // Add pokes
    activities.addAll(_getPokes());

    // Add quizzes
    activities.addAll(_getQuizzes());

    // Add word ladders
    activities.addAll(_getWordLadders());

    // Add memory flip puzzles
    activities.addAll(_getMemoryFlips());

    // Sort by timestamp (most recent first)
    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return activities;
  }

  /// Get filtered activities based on filter type
  List<ActivityItem> getFilteredActivities(String filter) {
    final all = getAllActivities();

    switch (filter) {
      case 'yourTurn':
        return all.where((a) => a.status == ActivityStatus.yourTurn).toList();

      case 'unread':
        return all.where((a) => a.isUnread).toList();

      case 'completed':
        return all.where((a) =>
          a.status == ActivityStatus.completed ||
          a.status == ActivityStatus.mutual
        ).toList();

      case 'all':
      default:
        return all;
    }
  }

  /// Convert reminders to activity items
  List<ActivityItem> _getReminders() {
    final reminders = _storage.getAllReminders()
        .where((r) => !r.isPoke) // Exclude pokes
        .toList();

    final userId = _getCurrentUserId();
    final userName = _getUserName();
    final partnerName = _getPartnerName();

    return reminders.map((reminder) {
      final isReceived = reminder.type == 'received';
      final isDone = reminder.status == 'done';

      // Determine participants
      final participants = <ParticipantStatus>[];

      if (isReceived) {
        // Partner sent, user received
        participants.add(ParticipantStatus(
          userId: 'partner',
          displayName: partnerName,
          hasCompleted: true, // Partner sent it
          completedAt: reminder.timestamp,
        ));
        participants.add(ParticipantStatus(
          userId: userId,
          displayName: userName,
          hasCompleted: isDone,
          completedAt: isDone ? reminder.timestamp : null,
        ));
      } else {
        // User sent
        participants.add(ParticipantStatus(
          userId: userId,
          displayName: userName,
          hasCompleted: true, // User sent it
          completedAt: reminder.timestamp,
        ));
      }

      // Determine status
      ActivityStatus status;
      if (isReceived && !isDone) {
        status = ActivityStatus.yourTurn;
      } else if (isReceived && isDone) {
        status = ActivityStatus.completed;
      } else {
        status = ActivityStatus.pending;
      }

      return ActivityItem(
        id: reminder.id,
        type: ActivityType.reminder,
        title: reminder.text,
        subtitle: isReceived ? 'From $partnerName' : 'To $partnerName',
        timestamp: reminder.timestamp,
        status: status,
        participants: participants,
        sourceData: reminder,
        isUnread: isReceived && reminder.status == 'pending',
      );
    }).toList();
  }

  /// Convert pokes to activity items
  List<ActivityItem> _getPokes() {
    final pokes = _storage.getAllReminders()
        .where((r) => r.isPoke)
        .toList();

    final userId = _getCurrentUserId();
    final userName = _getUserName();
    final partnerName = _getPartnerName();

    return pokes.map((poke) {
      final isReceived = poke.type == 'received';
      final isMutual = PokeService.isMutualPoke(poke);

      // Determine participants
      final participants = <ParticipantStatus>[];

      if (isMutual) {
        // Both poked each other
        participants.add(ParticipantStatus(
          userId: userId,
          displayName: userName,
          hasCompleted: true,
          completedAt: poke.timestamp,
        ));
        participants.add(ParticipantStatus(
          userId: 'partner',
          displayName: partnerName,
          hasCompleted: true,
          completedAt: poke.timestamp,
        ));
      } else if (isReceived) {
        participants.add(ParticipantStatus(
          userId: 'partner',
          displayName: partnerName,
          hasCompleted: true,
          completedAt: poke.timestamp,
        ));
      } else {
        participants.add(ParticipantStatus(
          userId: userId,
          displayName: userName,
          hasCompleted: true,
          completedAt: poke.timestamp,
        ));
      }

      return ActivityItem(
        id: poke.id,
        type: ActivityType.poke,
        title: isMutual ? 'Mutual Poke!' : 'Poke',
        subtitle: isReceived ? 'From $partnerName' : 'To $partnerName',
        timestamp: poke.timestamp,
        status: isMutual ? ActivityStatus.mutual : ActivityStatus.completed,
        participants: participants,
        sourceData: poke,
        emoji: '💫',
      );
    }).toList();
  }

  /// Convert quiz sessions to activity items
  List<ActivityItem> _getQuizzes() {
    final sessions = _storage.getAllQuizSessions();
    final userId = _getCurrentUserId();
    final userName = _getUserName();
    final partnerName = _getPartnerName();

    return sessions.map((session) {
      final userAnswered = session.hasUserAnswered(userId);
      final partnerAnswered = session.answers != null &&
                             session.answers!.keys.any((k) => k != userId);
      final bothAnswered = userAnswered && partnerAnswered;

      // Determine participants
      final participants = <ParticipantStatus>[
        ParticipantStatus(
          userId: userId,
          displayName: userName,
          hasCompleted: userAnswered,
          completedAt: userAnswered ? session.createdAt : null,
        ),
        ParticipantStatus(
          userId: 'partner',
          displayName: partnerName,
          hasCompleted: partnerAnswered,
          completedAt: partnerAnswered ? session.createdAt : null,
        ),
      ];

      // Determine status
      ActivityStatus status;
      if (session.isExpired) {
        status = ActivityStatus.expired;
      } else if (bothAnswered) {
        status = ActivityStatus.completed;
      } else if (userAnswered) {
        status = ActivityStatus.waitingForPartner;
      } else {
        status = ActivityStatus.yourTurn;
      }

      // Get format-specific title
      String title;
      switch (session.formatType) {
        case 'speed':
          title = 'Speed Round Quiz';
          break;
        case 'would_you_rather':
          title = 'Would You Rather';
          break;
        case 'daily_pulse':
          title = 'Daily Pulse';
          break;
        default:
          title = 'Relationship Checkup';
      }

      return ActivityItem(
        id: session.id,
        type: session.formatType == 'would_you_rather'
            ? ActivityType.wouldYouRather
            : (session.formatType == 'daily_pulse'
                ? ActivityType.dailyPulse
                : ActivityType.quiz),
        title: title,
        subtitle: userAnswered
            ? 'You answered this quiz'
            : 'Waiting for your answers',
        timestamp: session.createdAt,
        status: status,
        participants: participants,
        sourceData: session,
        isUnread: !userAnswered && !session.isExpired,
      );
    }).toList();
  }

  /// Convert word ladder sessions to activity items
  List<ActivityItem> _getWordLadders() {
    final sessions = _storage.getAllLadderSessions();
    final userId = _getCurrentUserId();
    final userName = _getUserName();
    final partnerName = _getPartnerName();

    return sessions.map((session) {
      final isMyTurn = session.currentTurn == userId;
      final isCompleted = session.isCompleted;

      // Determine participants (ladder is collaborative, both participate)
      final participants = <ParticipantStatus>[
        ParticipantStatus(
          userId: userId,
          displayName: userName,
          hasCompleted: isCompleted || !isMyTurn,
        ),
        ParticipantStatus(
          userId: 'partner',
          displayName: partnerName,
          hasCompleted: isCompleted || isMyTurn,
        ),
      ];

      // Determine status
      ActivityStatus status;
      if (isCompleted) {
        status = ActivityStatus.completed;
      } else if (session.isYielded) {
        status = ActivityStatus.pending;
      } else if (isMyTurn) {
        status = ActivityStatus.yourTurn;
      } else {
        status = ActivityStatus.waitingForPartner;
      }

      return ActivityItem(
        id: session.id,
        type: ActivityType.wordLadder,
        title: 'Word Ladder: ${session.startWord.toUpperCase()} → ${session.endWord.toUpperCase()}',
        subtitle: isCompleted
            ? 'Completed in ${session.stepCount} steps'
            : (isMyTurn ? 'Your turn' : 'Waiting for $partnerName'),
        timestamp: session.createdAt,
        status: status,
        participants: participants,
        sourceData: session,
        isUnread: isMyTurn && !isCompleted,
        emoji: '🪜',
      );
    }).toList();
  }

  /// Convert memory flip puzzles to activity items
  List<ActivityItem> _getMemoryFlips() {
    final puzzles = _storage.getAllMemoryPuzzles();
    final userId = _getCurrentUserId();
    final userName = _getUserName();
    final partnerName = _getPartnerName();

    return puzzles.map((puzzle) {
      final isCompleted = puzzle.isCompleted;

      // Check flip allowances to determine who has participated
      final userAllowance = _storage.getMemoryAllowance(userId);
      final userHasFlipsLeft = userAllowance?.canFlip ?? true;
      final userHasFlippedToday = (userAllowance?.totalFlipsToday ?? 0) > 0;

      // For partner, we don't have their userId, so we check if any cards were matched by someone other than user
      final partnerHasParticipated = puzzle.cards
          .any((c) => c.matchedBy != null && c.matchedBy != userId);

      // Determine participants
      final participants = <ParticipantStatus>[
        ParticipantStatus(
          userId: userId,
          displayName: userName,
          // User has completed if: game is done, OR they have no flips left, OR they've flipped today
          hasCompleted: isCompleted || !userHasFlipsLeft || userHasFlippedToday,
        ),
        ParticipantStatus(
          userId: 'partner',
          displayName: partnerName,
          // Partner has completed if game is done or they've participated
          hasCompleted: isCompleted || partnerHasParticipated,
        ),
      ];

      // Determine status
      ActivityStatus status;
      if (isCompleted) {
        status = ActivityStatus.completed;
      } else if (!userHasFlipsLeft) {
        // User has no flips left - waiting for partner or next day
        status = ActivityStatus.waitingForPartner;
      } else {
        // User still has flips available
        status = ActivityStatus.yourTurn;
      }

      return ActivityItem(
        id: puzzle.id,
        type: ActivityType.memoryFlip,
        title: 'Memory Flip',
        subtitle: isCompleted
            ? 'Completed together'
            : '${puzzle.matchedPairs}/${puzzle.totalPairs} pairs matched',
        timestamp: puzzle.createdAt,
        status: status,
        participants: participants,
        sourceData: puzzle,
        isUnread: !isCompleted && userHasFlipsLeft,
        emoji: '🎴',
      );
    }).toList();
  }

  /// Get count of activities waiting for user's turn
  int getYourTurnCount() {
    return getAllActivities()
        .where((a) => a.status == ActivityStatus.yourTurn)
        .length;
  }

  /// Get count of unread activities
  int getUnreadCount() {
    return getAllActivities()
        .where((a) => a.isUnread)
        .length;
  }
}

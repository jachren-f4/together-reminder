import '../models/activity_item.dart';
import '../models/daily_quest.dart';
import '../services/storage_service.dart';
import '../services/poke_service.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/brand_config.dart';

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

    // Add daily quests
    activities.addAll(_getDailyQuests());

    // Add quizzes
    activities.addAll(_getQuizzes());

    // Sort by timestamp (most recent first)
    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return activities;
  }

  /// Get filtered activities based on filter type
  List<ActivityItem> getFilteredActivities(String filter) {
    final all = getAllActivities();

    switch (filter) {
      case 'yourTurn':
        return all.where((activity) {
          // Exclude expired quests from "Your Turn"
          if (activity.sourceData is DailyQuest) {
            final quest = activity.sourceData as DailyQuest;
            if (quest.isExpired) return false;
          }
          return activity.status == ActivityStatus.yourTurn;
        }).toList();

      case 'unread':
        return all.where((a) => a.isUnread).toList();

      case 'completed':
        return all.where((a) =>
          a.status == ActivityStatus.completed ||
          a.status == ActivityStatus.mutual
        ).toList();

      case 'pokes':
        return all.where((a) => a.type == ActivityType.poke).toList();

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

    // Filter out quiz sessions created from daily quests to prevent duplication
    final standaloneQuizzes = sessions.where((session) => !session.isDailyQuest).toList();

    return standaloneQuizzes.map((session) {
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

  /// Convert daily quests to activity items
  List<ActivityItem> _getDailyQuests() {
    final quests = _storage.getTodayQuests();
    final userId = _getCurrentUserId();

    return quests.map((quest) {
      final userCompleted = quest.hasUserCompleted(userId);
      final bothCompleted = quest.isCompleted;

      // Map quest status to activity status
      ActivityStatus status;
      if (bothCompleted) {
        status = ActivityStatus.completed;
      } else if (userCompleted) {
        status = ActivityStatus.waitingForPartner;
      } else {
        status = ActivityStatus.yourTurn;
      }

      return ActivityItem(
        id: quest.id,
        type: _mapQuestTypeToActivityType(quest.questType, quest.contentId),
        title: _getQuestTitle(quest),
        subtitle: _getQuestSubtitle(quest, userCompleted, bothCompleted),
        timestamp: quest.createdAt,
        status: status,
        participants: _getQuestParticipants(quest, userId),
        sourceData: quest,
        isUnread: !userCompleted && !quest.isExpired,
      );
    }).toList();
  }

  /// Map quest type to activity type
  ActivityType _mapQuestTypeToActivityType(int questType, String? contentId) {
    switch (questType) {
      case 0: // QuestType.question
        return ActivityType.question;
      case 1: // QuestType.quiz
        // Check if this is an affirmation quiz
        if (contentId != null) {
          final session = _storage.getQuizSession(contentId);
          if (session != null && session.formatType == 'affirmation') {
            return ActivityType.affirmation;
          }
        }
        return ActivityType.quiz;
      case 2: // QuestType.game
        return ActivityType.quiz; // Generic game maps to quiz for now
      case 3: // QuestType.youOrMe
        return ActivityType.wouldYouRather;
      case 4: // QuestType.linked
      case 5: // QuestType.wordSearch
      case 6: // QuestType.steps
        return ActivityType.quiz; // Game types map to quiz for now
      default:
        return ActivityType.quiz;
    }
  }

  /// Get quest title based on type and sort order
  String _getQuestTitle(DailyQuest quest) {
    switch (quest.questType) {
      case 0: // QuestType.question
        return 'Daily Question';
      case 1: // QuestType.quiz
        // Check quest formatType first (always available from Firebase)
        if (quest.formatType == 'affirmation') {
          // Use quest.quizName (synced from Firebase) or fallback
          return quest.quizName ?? 'Affirmation Quiz';
        }
        // Use sort order to generate distinct titles for classic quizzes
        const titles = [
          'Getting to Know You',
          'Deeper Connection',
          'Understanding Each Other',
        ];
        if (quest.sortOrder >= 0 && quest.sortOrder < titles.length) {
          return titles[quest.sortOrder];
        }
        return 'Relationship Quiz #${quest.sortOrder + 1}';
      case 2: // QuestType.game
        return 'Fun Game';
      case 3: // QuestType.youOrMe
        return 'You or Me?';
      case 4: // QuestType.linked
        return 'Crossword Puzzle';
      case 5: // QuestType.wordSearch
        return 'Word Search';
      case 6: // QuestType.steps
        return BrandLoader().config.brand == Brand.us2 ? 'Steps' : 'Steps Together';
      default:
        return 'Quiz';
    }
  }

  /// Get quest subtitle based on completion status
  String _getQuestSubtitle(DailyQuest quest, bool userCompleted, bool bothCompleted) {
    if (bothCompleted) {
      return 'Both completed';
    } else if (userCompleted) {
      final partnerName = _getPartnerName();
      return 'Waiting for $partnerName to complete';
    } else {
      return 'Complete together to earn Love Points';
    }
  }

  /// Get participants for quest
  List<ParticipantStatus> _getQuestParticipants(DailyQuest quest, String userId) {
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    final userName = user?.name ?? 'You';
    final partnerName = partner?.name ?? 'Partner';

    List<ParticipantStatus> participants = [];

    // Only add avatars for users who have completed
    if (quest.hasUserCompleted(userId)) {
      participants.add(ParticipantStatus(
        userId: userId,
        displayName: userName,
        hasCompleted: true,
        completedAt: quest.completedAt,
      ));
    }

    if (partner != null && _hasPartnerCompleted(quest, userId)) {
      participants.add(ParticipantStatus(
        userId: 'partner', // Partner doesn't have id field, use generic identifier
        displayName: partnerName,
        hasCompleted: true,
        completedAt: quest.completedAt,
      ));
    }

    return participants;
  }

  /// Check if partner has completed quest
  bool _hasPartnerCompleted(DailyQuest quest, String userId) {
    if (quest.userCompletions == null) return false;

    // Find partner's completion status (any completion that's not the current user)
    for (var entry in quest.userCompletions!.entries) {
      if (entry.key != userId && entry.value == true) {
        return true;
      }
    }
    return false;
  }
}

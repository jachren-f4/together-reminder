import 'package:flutter/foundation.dart';
import '../models/daily_quest.dart';
import '../services/storage_service.dart';
import '../services/love_point_service.dart';
import '../services/quest_sync_service.dart';
import '../services/quest_utilities.dart';
import '../utils/logger.dart';

/// Service for managing daily quests
///
/// Responsibilities:
/// - Generate daily quests
/// - Track quest completion by both users
/// - Award Love Points when both users complete
/// - Manage quest expiration
/// - Provide quest status
class DailyQuestService {
  final StorageService _storage;
  final QuestSyncService? _questSyncService;

  DailyQuestService({
    required StorageService storage,
    QuestSyncService? questSyncService,
  })  : _storage = storage,
        _questSyncService = questSyncService;

  /// Get today's date key in YYYY-MM-DD format
  ///
  /// @deprecated Use [QuestUtilities.getTodayDateKey] instead.
  /// This method is kept for backward compatibility and will be removed in a future version.
  @Deprecated('Use QuestUtilities.getTodayDateKey() instead')
  String getTodayDateKey() {
    return QuestUtilities.getTodayDateKey();
  }

  /// Get date key for a specific date
  ///
  /// @deprecated Use [QuestUtilities.getDateKey] instead.
  /// This method is kept for backward compatibility and will be removed in a future version.
  @Deprecated('Use QuestUtilities.getDateKey() instead')
  String getDateKey(DateTime date) {
    return QuestUtilities.getDateKey(date);
  }

  /// Get today's quests (sorted by sortOrder)
  List<DailyQuest> getTodayQuests() {
    return _storage.getTodayQuests();
  }

  /// Get quests for a specific date
  List<DailyQuest> getQuestsForDate(String dateKey) {
    return _storage.getDailyQuestsForDate(dateKey);
  }

  /// Get only main daily quests (not side quests)
  List<DailyQuest> getMainDailyQuests() {
    final quests = getTodayQuests();
    return quests.where((q) => !q.isSideQuest).toList();
  }

  /// Get only side quests
  List<DailyQuest> getSideQuests() {
    final quests = getTodayQuests();
    return quests.where((q) => q.isSideQuest).toList();
  }

  /// Check if today's quests have been generated
  bool hasTodayQuests() {
    final quests = getTodayQuests();
    return quests.isNotEmpty;
  }

  /// Complete a quest for a specific user
  ///
  /// Returns true if this completion triggered the quest to be fully completed
  Future<bool> completeQuestForUser({
    required String questId,
    required String userId,
    String? partnerUserId,
  }) async {
    final quest = _storage.getDailyQuest(questId);
    if (quest == null) {
      Logger.debug('Quest not found: $questId', service: 'quest');
      return false;
    }

    // Check if already completed by this user
    if (quest.hasUserCompleted(userId)) {
      Logger.debug('User $userId already completed quest $questId', service: 'quest');
      return false;
    }

    // Mark user as completed
    quest.userCompletions ??= {};
    quest.userCompletions![userId] = true;

    // Check if both users have now completed
    final bothCompleted = quest.areBothUsersCompleted();

    if (bothCompleted) {
      // Mark quest as completed
      quest.status = 'completed';
      quest.completedAt = DateTime.now();

      // Award Love Points to BOTH users
      // Note: Quiz quests award LP via QuizService, so skip LP for quiz type quests
      const lpReward = 30;
      quest.lpAwarded = lpReward;

      if (quest.type != QuestType.quiz) {
        // Non-quiz quests award LP here
        final user = _storage.getUser();
        final partner = _storage.getPartner();

        if (user != null && partner != null) {
          await LovePointService.awardPointsToBothUsers(
            userId1: user.id,
            userId2: partner.pushToken,
            amount: lpReward,
            reason: 'daily_quest',
            relatedId: questId,
          );
        }

        Logger.debug('Quest $questId completed by both users! Awarded $lpReward LP to both', service: 'quest');
      } else {
        // Quiz quests award LP via QuizService when quiz completes
        Logger.debug('Quest $questId (quiz) completed by both users! LP awarded via QuizService', service: 'quest');
      }

      // Update daily completion stats
      await _updateDailyCompletion(quest.dateKey);
    } else {
      // One user completed, still waiting for partner
      quest.status = 'in_progress';
      Logger.debug('Quest $questId completed by $userId, waiting for partner', service: 'quest');
    }

    // Save quest locally
    await _storage.updateDailyQuest(quest);

    // Sync completion to Firebase if sync service is available
    if (_questSyncService != null && partnerUserId != null) {
      await _questSyncService!.markQuestCompleted(
        questId: questId,
        currentUserId: userId,
        partnerUserId: partnerUserId,
      );
      Logger.debug('Quest completion synced to Firebase', service: 'quest');
    }

    return bothCompleted;
  }

  /// Update the daily completion record
  Future<void> _updateDailyCompletion(String dateKey) async {
    var completion = _storage.getDailyQuestCompletion(dateKey);

    if (completion == null) {
      completion = DailyQuestCompletion.forDate(dateKey);
    }

    // Count completed main quests
    final quests = getQuestsForDate(dateKey);
    final mainQuests = quests.where((q) => !q.isSideQuest).toList();
    final completedMainQuests = mainQuests.where((q) => q.isCompleted).length;
    final completedSideQuests = quests.where((q) => q.isSideQuest && q.isCompleted).length;

    completion.questsCompleted = completedMainQuests;
    completion.sideQuestsCompleted = completedSideQuests;
    completion.allQuestsCompleted = completedMainQuests >= 3;
    completion.totalLpEarned = completedMainQuests * 30; // 30 LP per main quest
    completion.lastUpdatedAt = DateTime.now();

    if (completion.allQuestsCompleted && completion.completedAt.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      completion.completedAt = DateTime.now();
    }

    await _storage.saveDailyQuestCompletion(completion);
  }

  /// Check quest status for current user
  ///
  /// Returns status: 'your_turn', 'waiting', 'completed', 'expired'
  String getQuestStatus(DailyQuest quest, String userId) {
    if (quest.isExpired) return 'expired';
    if (quest.isCompleted) return 'completed';

    final userCompleted = quest.hasUserCompleted(userId);

    if (userCompleted) {
      return 'waiting'; // User completed, waiting for partner
    } else {
      return 'your_turn'; // User needs to complete
    }
  }

  /// Get completion stats for today
  DailyQuestCompletion? getTodayCompletion() {
    return _storage.getTodayCompletion();
  }

  /// Get completion percentage (0-100) for today's main quests
  int getTodayCompletionPercentage() {
    final quests = getMainDailyQuests();
    if (quests.isEmpty) return 0;

    final completed = quests.where((q) => q.isCompleted).length;
    return ((completed / 3) * 100).round(); // 3 main quests
  }

  /// Check if all main daily quests are completed
  bool areAllMainQuestsCompleted() {
    final quests = getMainDailyQuests();
    if (quests.length < 3) return false;

    return quests.every((q) => q.isCompleted);
  }

  /// Clean up expired quests
  Future<void> cleanupExpiredQuests() async {
    final allQuests = _storage.dailyQuestsBox.values.toList();
    final now = DateTime.now();

    for (final quest in allQuests) {
      // Delete quests older than 7 days
      if (now.difference(quest.expiresAt).inDays > 7) {
        await quest.delete();
        Logger.debug('Deleted old quest: ${quest.id}', service: 'quest');
      }
    }
  }

  /// Get streak count (consecutive days with all quests completed)
  int getCurrentStreak() {
    final completions = _storage.getAllDailyQuestCompletions();

    if (completions.isEmpty) return 0;

    int streak = 0;
    final today = DateTime.now();

    // Start from today and go backwards
    for (int i = 0; i < 365; i++) {
      final date = today.subtract(Duration(days: i));
      final dateKey = getDateKey(date);
      final completion = _storage.getDailyQuestCompletion(dateKey);

      if (completion?.allQuestsCompleted == true) {
        streak++;
      } else {
        break; // Streak broken
      }
    }

    return streak;
  }

  /// Get total LP earned from daily quests
  int getTotalLpEarned() {
    final completions = _storage.getAllDailyQuestCompletions();
    return completions.fold(0, (sum, c) => sum + c.totalLpEarned);
  }

  /// Get total main quests completed (all time)
  int getTotalMainQuestsCompleted() {
    final completions = _storage.getAllDailyQuestCompletions();
    return completions.fold(0, (sum, c) => sum + c.questsCompleted);
  }

  /// Get total side quests completed (all time)
  int getTotalSideQuestsCompleted() {
    final completions = _storage.getAllDailyQuestCompletions();
    return completions.fold(0, (sum, c) => sum + c.sideQuestsCompleted);
  }
}

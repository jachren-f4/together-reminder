import '../models/daily_quest.dart';
import '../services/storage_service.dart';
import '../utils/logger.dart';

/// Mock service for testing daily quests UI
///
/// Creates fake quests to verify UI components work correctly
class MockDailyQuestsService {
  final StorageService _storage;

  MockDailyQuestsService({required StorageService storage}) : _storage = storage;

  /// Generate mock daily quests for testing
  Future<void> generateMockQuests() async {
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user == null) {
      Logger.error('No user found, cannot generate mock quests', service: 'mock');
      return;
    }

    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // Clear existing quests for today
    final existingQuests = _storage.getDailyQuestsForDate(dateKey);
    for (final quest in existingQuests) {
      await quest.delete();
    }

    // Quest 1: Both users completed
    final quest1 = DailyQuest.create(
      dateKey: dateKey,
      type: QuestType.quiz,
      contentId: 'mock_quiz_1',
      sortOrder: 0,
      isSideQuest: false,
    );
    quest1.status = 'completed';
    quest1.userCompletions = {
      user.id: true,
      partner?.pushToken ?? 'partner_123': true,
    };
    quest1.completedAt = DateTime.now().subtract(const Duration(hours: 2));
    quest1.lpAwarded = 30;
    await _storage.saveDailyQuest(quest1);

    // Quest 2: Only current user completed (waiting for partner)
    final quest2 = DailyQuest.create(
      dateKey: dateKey,
      type: QuestType.quiz,
      contentId: 'mock_quiz_2',
      sortOrder: 1,
      isSideQuest: false,
    );
    quest2.status = 'in_progress';
    quest2.userCompletions = {
      user.id: true,
    };
    await _storage.saveDailyQuest(quest2);

    // Quest 3: Not started yet
    final quest3 = DailyQuest.create(
      dateKey: dateKey,
      type: QuestType.quiz,
      contentId: 'mock_quiz_3',
      sortOrder: 2,
      isSideQuest: false,
    );
    quest3.status = 'pending';
    quest3.userCompletions = {};
    await _storage.saveDailyQuest(quest3);

    Logger.success('Generated 3 mock daily quests for testing', service: 'mock');
  }

  /// Clear all mock quests
  Future<void> clearMockQuests() async {
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final quests = _storage.getDailyQuestsForDate(dateKey);
    for (final quest in quests) {
      await quest.delete();
    }

    Logger.success('Cleared all mock quests', service: 'mock');
  }
}

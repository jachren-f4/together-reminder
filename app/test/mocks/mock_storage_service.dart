/// Mock Storage Service for testing
///
/// Provides in-memory storage that mimics Hive behavior for tests.

import 'package:togetherremind/models/reminder.dart';
import 'package:togetherremind/models/daily_quest.dart';

/// In-memory storage for tests (mimics Hive boxes)
class MockStorage {
  static User? _user;
  static Partner? _partner;
  static final List<DailyQuest> _quests = [];
  static int _lovePoints = 0;

  /// Reset all storage
  static void reset() {
    _user = null;
    _partner = null;
    _quests.clear();
    _lovePoints = 0;
  }

  /// Setup test user
  static void setUser({
    String id = 'test-user-id',
    String name = 'TestUser',
    String email = 'test@example.com',
    int lovePoints = 0,
    int arenaTier = 1,
  }) {
    _user = User(
      id: id,
      fullName: name,
      phoneNumber: '',
      pushToken: 'test-push-token',
    );
    _user!.lovePoints = lovePoints;
    _user!.arenaTier = arenaTier;
    _lovePoints = lovePoints;
  }

  /// Setup test partner
  static void setPartner({
    String id = 'test-partner-id',
    String name = 'TestPartner',
  }) {
    _partner = Partner(
      id: id,
      fullName: name,
      pushToken: 'test-partner-push-token',
    );
  }

  /// Setup test couple
  static void setupTestCouple({
    int initialLP = 0,
  }) {
    setUser(lovePoints: initialLP);
    setPartner();
  }

  /// Get user
  static User? getUser() => _user;

  /// Get partner
  static Partner? getPartner() => _partner;

  /// Add a quest
  static void addQuest(DailyQuest quest) {
    _quests.add(quest);
  }

  /// Get today's quests
  static List<DailyQuest> getTodayQuests() => List.from(_quests);

  /// Update a quest
  static void updateQuest(DailyQuest quest) {
    final index = _quests.indexWhere((q) => q.id == quest.id);
    if (index >= 0) {
      _quests[index] = quest;
    }
  }

  /// Update LP
  static void setLovePoints(int lp) {
    _lovePoints = lp;
    if (_user != null) {
      _user!.lovePoints = lp;
    }
  }

  /// Get LP
  static int getLovePoints() => _lovePoints;

  /// Create a test daily quest
  static DailyQuest createTestQuest({
    String id = 'test-quest-id',
    QuestType type = QuestType.quiz,
    String formatType = 'classic',
    String branch = 'lighthearted',
    String status = 'active',
    bool userCompleted = false,
    bool partnerCompleted = false,
  }) {
    final quest = DailyQuest(
      id: id,
      type: type,
      contentId: 'test-content-id',
      createdAt: DateTime.now(),
      branch: branch,
    );
    quest.status = status;
    quest.formatType = formatType;
    quest.userCompletions = {};

    if (userCompleted && _user != null) {
      quest.userCompletions![_user!.id] = true;
    }
    if (partnerCompleted && _partner != null) {
      quest.userCompletions![_partner!.id] = true;
    }

    return quest;
  }

  /// Setup quests for "waiting for partner" scenario
  static void setupWaitingForPartnerScenario() {
    setupTestCouple(initialLP: 0);

    // User has completed, partner hasn't
    final classicQuest = createTestQuest(
      id: 'classic-quest',
      type: QuestType.quiz,
      formatType: 'classic',
      userCompleted: true,
      partnerCompleted: false,
    );
    addQuest(classicQuest);
  }

  /// Setup quests for "partner just completed" scenario
  static void setupPartnerJustCompletedScenario() {
    setupTestCouple(initialLP: 0);

    // Both have completed
    final classicQuest = createTestQuest(
      id: 'classic-quest',
      type: QuestType.quiz,
      formatType: 'classic',
      status: 'completed',
      userCompleted: true,
      partnerCompleted: true,
    );
    addQuest(classicQuest);
  }
}

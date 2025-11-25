import 'package:hive/hive.dart';

part 'daily_quest.g.dart';

enum QuestType {
  question,
  quiz,
  game,
  wordLadder,
  memoryFlip,
  youOrMe,
  linked,
}

@HiveType(typeId: 17)
class DailyQuest extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String dateKey; // YYYY-MM-DD format

  @HiveField(2)
  late int questType; // Store as int, convert to/from QuestType

  @HiveField(3)
  late String contentId; // Reference to actual content (quiz session, question, etc.)

  @HiveField(4)
  late DateTime createdAt;

  @HiveField(5)
  late DateTime expiresAt; // End of day (23:59:59)

  @HiveField(6)
  late String status; // 'pending', 'in_progress', 'completed'

  @HiveField(7)
  Map<String, bool>? userCompletions; // userId -> completed bool

  @HiveField(8)
  int? lpAwarded; // 30 LP when both complete

  @HiveField(9)
  DateTime? completedAt;

  @HiveField(10, defaultValue: false)
  bool isSideQuest; // true for optional quests beyond the 3 daily

  @HiveField(11, defaultValue: 0)
  int sortOrder; // 0-2 for daily quests, 3+ for side quests

  @HiveField(12, defaultValue: 'classic')
  String formatType; // 'classic', 'affirmation', 'speed_round', etc.

  @HiveField(13)
  String? quizName; // Quiz name for display (e.g., "Warm Vibes")

  @HiveField(14, defaultValue: null)
  String? imagePath; // Path to quest image asset (e.g., "assets/images/quests/trust-basics.png")

  @HiveField(15, defaultValue: null)
  String? description; // Quest description (e.g., "Answer ten questions together")

  DailyQuest({
    required this.id,
    required this.dateKey,
    required this.questType,
    required this.contentId,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    this.userCompletions,
    this.lpAwarded,
    this.completedAt,
    this.isSideQuest = false,
    this.sortOrder = 0,
    this.formatType = 'classic',
    this.quizName,
    this.imagePath,
    this.description,
  });

  // Helper getters
  QuestType get type => QuestType.values[questType];

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isCompleted => status == 'completed';

  bool hasUserCompleted(String userId) {
    return userCompletions?.containsKey(userId) == true &&
           userCompletions![userId] == true;
  }

  bool areBothUsersCompleted() {
    if (userCompletions == null || userCompletions!.length != 2) {
      return false;
    }
    return userCompletions!.values.every((completed) => completed);
  }

  // Factory constructor for easier creation
  factory DailyQuest.create({
    required String dateKey,
    required QuestType type,
    required String contentId,
    int sortOrder = 0,
    bool isSideQuest = false,
    String formatType = 'classic',
    String? quizName,
    String? imagePath,
    String? description,
  }) {
    final now = DateTime.now();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return DailyQuest(
      id: 'quest_${DateTime.now().millisecondsSinceEpoch}_${type.name}',
      dateKey: dateKey,
      questType: type.index,
      contentId: contentId,
      createdAt: now,
      expiresAt: endOfDay,
      status: 'pending',
      sortOrder: sortOrder,
      isSideQuest: isSideQuest,
      formatType: formatType,
      quizName: quizName,
      imagePath: imagePath,
      description: description,
    );
  }
}

@HiveType(typeId: 18)
class DailyQuestCompletion extends HiveObject {
  @HiveField(0)
  late String dateKey; // YYYY-MM-DD

  @HiveField(1)
  late int questsCompleted; // 0-3 for daily quests

  @HiveField(2)
  late bool allQuestsCompleted; // true when 3/3 done

  @HiveField(3)
  late DateTime completedAt;

  @HiveField(4)
  late int totalLpEarned; // 90 LP for 3 quests

  @HiveField(5, defaultValue: 0)
  int sideQuestsCompleted; // Bonus quests beyond the 3

  @HiveField(6)
  DateTime? lastUpdatedAt;

  DailyQuestCompletion({
    required this.dateKey,
    required this.questsCompleted,
    required this.allQuestsCompleted,
    required this.completedAt,
    required this.totalLpEarned,
    this.sideQuestsCompleted = 0,
    this.lastUpdatedAt,
  });

  // Factory constructor for creating a new completion record
  factory DailyQuestCompletion.forDate(String dateKey) {
    return DailyQuestCompletion(
      dateKey: dateKey,
      questsCompleted: 0,
      allQuestsCompleted: false,
      completedAt: DateTime.now(),
      totalLpEarned: 0,
      sideQuestsCompleted: 0,
      lastUpdatedAt: DateTime.now(),
    );
  }
}

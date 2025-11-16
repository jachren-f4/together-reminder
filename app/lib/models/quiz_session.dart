import 'package:hive/hive.dart';

part 'quiz_session.g.dart';

@HiveType(typeId: 5)
class QuizSession extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late List<String> questionIds; // 5 questions

  @HiveField(2)
  late DateTime createdAt;

  @HiveField(3)
  late DateTime expiresAt; // 3 hours from creation

  @HiveField(4)
  late String status; // 'waiting_for_answers', 'completed', 'expired'

  @HiveField(5)
  Map<String, List<int>>? answers; // userId -> [answer indices]

  @HiveField(6)
  int? matchPercentage; // Calculated after both submit

  @HiveField(7)
  int? lpEarned;

  @HiveField(8)
  DateTime? completedAt;

  @HiveField(9)
  late String initiatedBy; // userId who started the quiz

  @HiveField(10, defaultValue: '')
  String subjectUserId; // CRITICAL: Who the quiz is ABOUT (for knowledge test model)

  @HiveField(11)
  String? formatType; // 'classic', 'speed', 'deep_dive', 'mystery_box', 'would_you_rather', 'timeline', 'daily_pulse'

  @HiveField(12)
  Map<String, List<int>>? predictions; // For "Would You Rather": userId -> [predicted partner answers]

  @HiveField(13, defaultValue: 0)
  int alignmentMatches; // For "Would You Rather": count of questions where both chose same answer

  @HiveField(14)
  Map<String, int>? predictionScores; // For "Would You Rather": userId -> number of correct predictions

  @HiveField(15)
  String? quizName; // For affirmation quizzes: display name

  @HiveField(16)
  String? category; // For affirmation quizzes: category (trust, emotional_support, etc.)

  @HiveField(17, defaultValue: false)
  bool isDailyQuest; // True if this quiz session was created from a daily quest

  @HiveField(18, defaultValue: '')
  String dailyQuestId; // Links back to the DailyQuest that created this session

  @HiveField(19, defaultValue: null)
  String? imagePath; // Path to quest image asset (for carousel display)

  @HiveField(20, defaultValue: null)
  String? description; // Quest description (for carousel display)

  QuizSession({
    required this.id,
    required this.questionIds,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    required this.initiatedBy,
    this.subjectUserId = '',
    this.formatType,
    this.quizName,
    this.category,
    this.isDailyQuest = false,
    this.dailyQuestId = '',
    this.imagePath,
    this.description,
    this.answers,
    this.predictions,
    this.alignmentMatches = 0,
    this.predictionScores,
    this.matchPercentage,
    this.lpEarned,
    this.completedAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isCompleted => status == 'completed';
  bool hasUserAnswered(String userId) => answers?.containsKey(userId) ?? false;

  // Helper methods for knowledge test model
  bool isUserSubject(String userId) => subjectUserId == userId;
  bool isUserPredictor(String userId) => !isUserSubject(userId) && userId != subjectUserId;
}

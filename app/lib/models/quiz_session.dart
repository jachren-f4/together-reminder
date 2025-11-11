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

  QuizSession({
    required this.id,
    required this.questionIds,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    required this.initiatedBy,
    this.subjectUserId = '',
    this.formatType,
    this.answers,
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

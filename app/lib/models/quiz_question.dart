import 'package:hive/hive.dart';

part 'quiz_question.g.dart';

@HiveType(typeId: 4)
class QuizQuestion extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String question;

  @HiveField(2)
  late List<String> options; // 5 options (4 specific + 1 "Other" with context-aware wording)

  @HiveField(3)
  late int correctAnswerIndex; // For validation (not used for couple quizzes)

  @HiveField(4)
  late String category; // 'favorites', 'memories', 'preferences', 'future', etc.

  @HiveField(5, defaultValue: 1)
  int difficulty; // 1 = Easy, 2 = Challenge, 3 = Expert

  @HiveField(6, defaultValue: 1)
  int tier; // Which unlock tier (1-6)

  @HiveField(7, defaultValue: false)
  bool isSeasonal; // Is this a seasonal/event question?

  @HiveField(8)
  String? seasonalTheme; // 'valentine', 'halloween', 'anniversary', etc.

  @HiveField(9, defaultValue: 0)
  int timesAsked; // Track usage for analytics

  @HiveField(10, defaultValue: 0.0)
  double avgMatchRate; // Performance tracking

  QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.category,
    this.difficulty = 1,
    this.tier = 1,
    this.isSeasonal = false,
    this.seasonalTheme,
    this.timesAsked = 0,
    this.avgMatchRate = 0.0,
  });
}

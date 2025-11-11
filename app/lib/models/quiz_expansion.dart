import 'package:hive/hive.dart';

part 'quiz_expansion.g.dart';

/// Quiz Format - Different quiz types (Classic, Speed Round, Deep Dive, etc.)
@HiveType(typeId: 13)
class QuizFormat extends HiveObject {
  @HiveField(0)
  late String id; // 'classic', 'speed', 'deep_dive', 'mystery_box', etc.

  @HiveField(1)
  late String name;

  @HiveField(2)
  late String description;

  @HiveField(3)
  late bool isUnlocked;

  @HiveField(4)
  late Map<String, dynamic> unlockRequirements; // e.g., {'quizCount': 5}

  @HiveField(5)
  late int baseLP; // Base LP reward

  @HiveField(6)
  late int questionCount; // Number of questions in this format

  @HiveField(7)
  int? timeLimit; // Seconds per question (null = no limit)

  @HiveField(8)
  late String emoji;

  QuizFormat({
    required this.id,
    required this.name,
    required this.description,
    required this.isUnlocked,
    required this.unlockRequirements,
    required this.baseLP,
    required this.questionCount,
    this.timeLimit,
    required this.emoji,
  });
}

/// Quiz Category - Track progress in each category
@HiveType(typeId: 14)
class QuizCategory extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late String emoji;

  @HiveField(3)
  late int tier; // 1-6

  @HiveField(4)
  late bool isUnlocked;

  @HiveField(5)
  late int questionsCompleted;

  @HiveField(6)
  late int totalQuestions;

  @HiveField(7, defaultValue: 0.0)
  double avgMatchRate; // Average match rate in this category

  QuizCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.tier,
    required this.isUnlocked,
    required this.questionsCompleted,
    required this.totalQuestions,
    this.avgMatchRate = 0.0,
  });
}

/// Quiz Streak - Track daily pulse and weekly challenge streaks
@HiveType(typeId: 15)
class QuizStreak extends HiveObject {
  @HiveField(0)
  late String type; // 'daily_pulse', 'weekly_challenge'

  @HiveField(1)
  late int currentStreak;

  @HiveField(2)
  late int longestStreak;

  @HiveField(3)
  late DateTime lastCompletedDate;

  @HiveField(4, defaultValue: 0)
  int totalCompleted; // Total number of times completed

  QuizStreak({
    required this.type,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastCompletedDate,
    this.totalCompleted = 0,
  });
}

/// Daily Pulse - Single daily question with alternating subject
@HiveType(typeId: 16)
class QuizDailyPulse extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String questionId;

  @HiveField(2)
  late DateTime availableDate; // Date this pulse is available

  @HiveField(3)
  late String subjectUserId; // Who the question is ABOUT (alternates daily)

  @HiveField(4)
  Map<String, int>? answers; // subjectUserId -> self-answer, predictorUserId -> prediction

  @HiveField(5)
  late bool bothAnswered;

  @HiveField(6, defaultValue: 0)
  int lpAwarded;

  @HiveField(7)
  DateTime? completedAt;

  @HiveField(8, defaultValue: false)
  bool isMatch; // Did the predictor guess correctly?

  QuizDailyPulse({
    required this.id,
    required this.questionId,
    required this.availableDate,
    required this.subjectUserId,
    this.answers,
    required this.bothAnswered,
    this.lpAwarded = 0,
    this.completedAt,
    this.isMatch = false,
  });

  bool get isCompleted => bothAnswered && completedAt != null;
  bool get isExpired => DateTime.now().difference(availableDate).inDays > 1;
}

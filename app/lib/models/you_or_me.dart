import 'package:hive/hive.dart';

part 'you_or_me.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// YouOrMeQuestion - Single question in the You or Me game
// ─────────────────────────────────────────────────────────────────────────────

@HiveType(typeId: 20)
class YouOrMeQuestion {
  @HiveField(0)
  String id; // e.g., "yom_q001"

  @HiveField(1)
  String prompt; // "Who's more...", "Who would...", etc.

  @HiveField(2)
  String content; // "Creative", "Plan the perfect date", etc.

  @HiveField(3)
  String category; // "personality", "actions", "scenarios", "comparative"

  YouOrMeQuestion({
    required this.id,
    required this.prompt,
    required this.content,
    required this.category,
  });

  /// Convert to map for JSON serialization
  Map<String, dynamic> toMap() => {
        'id': id,
        'prompt': prompt,
        'content': content,
        'category': category,
      };

  /// Create from map (JSON deserialization)
  factory YouOrMeQuestion.fromMap(Map<String, dynamic> map) {
    return YouOrMeQuestion(
      id: map['id'] as String,
      prompt: map['prompt'] as String,
      content: map['content'] as String,
      category: map['category'] as String,
    );
  }

  @override
  String toString() {
    return 'YouOrMeQuestion(id: $id, prompt: "$prompt", content: "$content", category: $category)';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YouOrMeAnswer - Single answer from a user
// ─────────────────────────────────────────────────────────────────────────────

@HiveType(typeId: 21)
class YouOrMeAnswer {
  @HiveField(0)
  String questionId;

  @HiveField(1)
  String questionPrompt;

  @HiveField(2)
  String questionContent;

  @HiveField(3)
  bool answerValue; // true = "Me", false = "You"

  @HiveField(4)
  DateTime answeredAt;

  YouOrMeAnswer({
    required this.questionId,
    required this.questionPrompt,
    required this.questionContent,
    required this.answerValue,
    required this.answeredAt,
  });

  /// Convert to map for Firebase RTDB
  Map<String, dynamic> toMap() => {
        'questionId': questionId,
        'questionPrompt': questionPrompt,
        'questionContent': questionContent,
        'answerValue': answerValue,
        'answeredAt': answeredAt.millisecondsSinceEpoch,
      };

  /// Create from map (Firebase RTDB)
  factory YouOrMeAnswer.fromMap(Map<String, dynamic> map) {
    return YouOrMeAnswer(
      questionId: map['questionId'] as String,
      questionPrompt: map['questionPrompt'] as String,
      questionContent: map['questionContent'] as String,
      answerValue: map['answerValue'] as bool,
      answeredAt: DateTime.fromMillisecondsSinceEpoch(map['answeredAt'] as int),
    );
  }

  @override
  String toString() {
    return 'YouOrMeAnswer(questionId: $questionId, answerValue: $answerValue)';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YouOrMeSession - Game session with questions and answers
// ─────────────────────────────────────────────────────────────────────────────

@HiveType(typeId: 22)
class YouOrMeSession extends HiveObject {
  @HiveField(0)
  String id; // Session identifier

  @HiveField(1)
  String userId; // Creator's user ID

  @HiveField(2)
  String partnerId; // Partner's user ID

  @HiveField(3)
  String? questId; // Associated daily quest (null if from Activities screen)

  @HiveField(4)
  List<YouOrMeQuestion> questions; // 10 questions for this session

  @HiveField(5)
  Map<String, List<YouOrMeAnswer>>? answers; // {userId: [10 answers]}

  @HiveField(6)
  String status; // 'in_progress', 'completed'

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  DateTime? completedAt;

  @HiveField(9)
  int? lpEarned; // 30 LP when both complete

  @HiveField(10)
  String coupleId; // For Firebase sync (deterministic, sorted)

  @HiveField(11)
  String initiatedBy; // Who created this session

  @HiveField(12)
  String subjectUserId; // Who this session belongs to (same as userId for You or Me)

  YouOrMeSession({
    required this.id,
    required this.userId,
    required this.partnerId,
    this.questId,
    required this.questions,
    this.answers,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.lpEarned,
    required this.coupleId,
    required this.initiatedBy,
    required this.subjectUserId,
  });

  /// Check if session is completed
  bool get isCompleted => status == 'completed';

  /// Get count of users who have answered
  int getAnswerCount() {
    if (answers == null) return 0;
    return answers!.values.where((list) => list.isNotEmpty).length;
  }

  /// Check if specific user has answered all 10 questions
  bool hasUserAnswered(String userId) {
    return answers?.containsKey(userId) == true &&
        answers![userId]!.length == 10;
  }

  /// Check if both users have answered
  bool areBothUsersAnswered() {
    return hasUserAnswered(userId) && hasUserAnswered(partnerId);
  }

  /// Convert to map for Firebase RTDB
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'partnerId': partnerId,
      'questId': questId,
      'questions': questions.map((q) => q.toMap()).toList(),
      'answers': answers?.map((k, v) =>
          MapEntry(k, v.map((a) => a.toMap()).toList())),
      'status': status,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'lpEarned': lpEarned,
      'coupleId': coupleId,
      'initiatedBy': initiatedBy,
      'subjectUserId': subjectUserId,
      'isCompleted': isCompleted,
    };
  }

  /// Create from map (Firebase RTDB)
  factory YouOrMeSession.fromMap(Map<String, dynamic> map) {
    return YouOrMeSession(
      id: map['id'] as String,
      userId: map['userId'] as String,
      partnerId: map['partnerId'] as String,
      questId: map['questId'] as String?,
      questions: (map['questions'] as List)
          .map((q) => YouOrMeQuestion.fromMap(Map<String, dynamic>.from(q)))
          .toList(),
      answers: map['answers'] != null
          ? (map['answers'] as Map).map((k, v) => MapEntry(
              k.toString(),
              (v as List)
                  .map((a) => YouOrMeAnswer.fromMap(Map<String, dynamic>.from(a)))
                  .toList()))
          : null,
      status: map['status'] as String? ?? 'in_progress',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int)
          : null,
      lpEarned: map['lpEarned'] as int?,
      coupleId: map['coupleId'] as String,
      initiatedBy: map['initiatedBy'] as String,
      subjectUserId: map['subjectUserId'] as String,
    );
  }

  @override
  String toString() {
    return 'YouOrMeSession(id: $id, status: $status, userId: $userId, partnerId: $partnerId, questId: $questId, answerCount: ${getAnswerCount()}/2)';
  }
}

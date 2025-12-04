/// Quiz match data from server
/// Maps to quiz_matches table in Supabase
class QuizMatch {
  String id;
  String quizId;
  String quizType; // 'classic' | 'affirmation'
  String branch;
  String status; // 'active' | 'completed'
  List<int> player1Answers;
  List<int> player2Answers;
  int? matchPercentage;
  String player1Id;
  String player2Id;
  String date;
  DateTime createdAt;
  DateTime? completedAt;

  QuizMatch({
    required this.id,
    required this.quizId,
    required this.quizType,
    required this.branch,
    required this.status,
    required this.player1Answers,
    required this.player2Answers,
    this.matchPercentage,
    required this.player1Id,
    required this.player2Id,
    required this.date,
    required this.createdAt,
    this.completedAt,
  });

  bool get isCompleted => status == 'completed';

  factory QuizMatch.fromJson(Map<String, dynamic> json) {
    return QuizMatch(
      id: json['id'] ?? '',
      quizId: json['quizId'] ?? '',
      quizType: json['quizType'] ?? 'classic',
      branch: json['branch'] ?? '',
      status: json['status'] ?? 'active',
      player1Answers: List<int>.from(json['player1Answers'] ?? []),
      player2Answers: List<int>.from(json['player2Answers'] ?? []),
      matchPercentage: json['matchPercentage'],
      player1Id: json['player1Id'] ?? '',
      player2Id: json['player2Id'] ?? '',
      date: json['date'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
    );
  }
}

/// Quiz question from server
class ServerQuizQuestion {
  String id;
  String text;
  List<String> choices;
  String category;

  ServerQuizQuestion({
    required this.id,
    required this.text,
    required this.choices,
    required this.category,
  });

  factory ServerQuizQuestion.fromJson(Map<String, dynamic> json) {
    return ServerQuizQuestion(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      choices: List<String>.from(json['choices'] ?? []),
      category: json['category'] ?? '',
    );
  }
}

/// Full quiz data from server
class ServerQuiz {
  final String quizId;
  final String title;
  final String branch;
  final String? description;
  final List<ServerQuizQuestion> questions;

  ServerQuiz({
    required this.quizId,
    required this.title,
    required this.branch,
    this.description,
    required this.questions,
  });

  factory ServerQuiz.fromJson(Map<String, dynamic> json) {
    return ServerQuiz(
      quizId: json['quizId'] ?? '',
      title: json['title'] ?? '',
      branch: json['branch'] ?? '',
      description: json['description'],
      questions: (json['questions'] as List?)
              ?.map((q) => ServerQuizQuestion.fromJson(q))
              .toList() ??
          [],
    );
  }
}

/// Game state returned from quiz-match API
class QuizMatchGameState {
  final QuizMatch match;
  final ServerQuiz? quiz;
  final bool hasUserAnswered;
  final bool hasPartnerAnswered;
  final bool isCompleted;
  final bool canAnswer;

  QuizMatchGameState({
    required this.match,
    this.quiz,
    required this.hasUserAnswered,
    required this.hasPartnerAnswered,
    required this.isCompleted,
    required this.canAnswer,
  });
}

/// Submit result from quiz-match API
class QuizMatchSubmitResult {
  final bool success;
  final bool bothAnswered;
  final bool isCompleted;
  final int? matchPercentage;
  final int? lpEarned;
  final List<int> userAnswers;
  final List<int> partnerAnswers;

  QuizMatchSubmitResult({
    required this.success,
    required this.bothAnswered,
    required this.isCompleted,
    this.matchPercentage,
    this.lpEarned,
    this.userAnswers = const [],
    this.partnerAnswers = const [],
  });

  factory QuizMatchSubmitResult.fromJson(Map<String, dynamic> json) {
    return QuizMatchSubmitResult(
      success: json['success'] ?? false,
      bothAnswered: json['bothAnswered'] ?? false,
      isCompleted: json['isCompleted'] ?? false,
      matchPercentage: json['matchPercentage'],
      lpEarned: json['lpEarned'],
      userAnswers: List<int>.from(json['userAnswers'] ?? []),
      partnerAnswers: List<int>.from(json['partnerAnswers'] ?? []),
    );
  }
}

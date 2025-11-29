/// You-or-Me match data from server
/// Maps to quiz_matches table in Supabase (quiz_type = 'you_or_me')
class YouOrMeMatch {
  String id;
  String quizId;
  String branch;
  String status; // 'active' | 'completed'
  List<String> player1Answers;
  List<String> player2Answers;
  int player1AnswerCount;
  int player2AnswerCount;
  String? currentTurnUserId;
  int turnNumber;
  int player1Score;
  int player2Score;
  String player1Id;
  String player2Id;
  String date;
  DateTime createdAt;
  DateTime? completedAt;

  YouOrMeMatch({
    required this.id,
    required this.quizId,
    required this.branch,
    required this.status,
    required this.player1Answers,
    required this.player2Answers,
    required this.player1AnswerCount,
    required this.player2AnswerCount,
    this.currentTurnUserId,
    required this.turnNumber,
    required this.player1Score,
    required this.player2Score,
    required this.player1Id,
    required this.player2Id,
    required this.date,
    required this.createdAt,
    this.completedAt,
  });

  bool get isCompleted => status == 'completed';

  factory YouOrMeMatch.fromJson(Map<String, dynamic> json) {
    return YouOrMeMatch(
      id: json['id'] ?? '',
      quizId: json['quizId'] ?? '',
      branch: json['branch'] ?? '',
      status: json['status'] ?? 'active',
      player1Answers: List<String>.from(json['player1Answers'] ?? []),
      player2Answers: List<String>.from(json['player2Answers'] ?? []),
      player1AnswerCount: json['player1AnswerCount'] ?? 0,
      player2AnswerCount: json['player2AnswerCount'] ?? 0,
      currentTurnUserId: json['currentTurnUserId'],
      turnNumber: json['turnNumber'] ?? 1,
      player1Score: json['player1Score'] ?? 0,
      player2Score: json['player2Score'] ?? 0,
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

/// You-or-Me question from server
class ServerYouOrMeQuestion {
  String id;
  String prompt; // "Who's more...", "Which of you..."
  String content; // "Artistic", "Likely to..."

  ServerYouOrMeQuestion({
    required this.id,
    required this.prompt,
    required this.content,
  });

  factory ServerYouOrMeQuestion.fromJson(Map<String, dynamic> json) {
    return ServerYouOrMeQuestion(
      id: json['id'] ?? '',
      prompt: json['prompt'] ?? '',
      content: json['content'] ?? '',
    );
  }
}

/// Full You-or-Me quiz data from server
class ServerYouOrMeQuiz {
  final String quizId;
  final String title;
  final String branch;
  final List<ServerYouOrMeQuestion> questions;
  final int totalQuestions;

  ServerYouOrMeQuiz({
    required this.quizId,
    required this.title,
    required this.branch,
    required this.questions,
    required this.totalQuestions,
  });

  factory ServerYouOrMeQuiz.fromJson(Map<String, dynamic> json) {
    return ServerYouOrMeQuiz(
      quizId: json['quizId'] ?? '',
      title: json['title'] ?? '',
      branch: json['branch'] ?? '',
      questions: (json['questions'] as List?)
              ?.map((q) => ServerYouOrMeQuestion.fromJson(q))
              .toList() ??
          [],
      totalQuestions: json['totalQuestions'] ?? 10,
    );
  }
}

/// Game state returned from you-or-me-match API
class YouOrMeGameState {
  final YouOrMeMatch match;
  final ServerYouOrMeQuiz? quiz;
  final bool isMyTurn;
  final bool canPlay;
  final int currentQuestion;
  final int myAnswerCount;
  final int partnerAnswerCount;
  final int myScore;
  final int partnerScore;
  final bool isCompleted;
  final int totalQuestions;

  YouOrMeGameState({
    required this.match,
    this.quiz,
    required this.isMyTurn,
    required this.canPlay,
    required this.currentQuestion,
    required this.myAnswerCount,
    required this.partnerAnswerCount,
    required this.myScore,
    required this.partnerScore,
    required this.isCompleted,
    required this.totalQuestions,
  });
}

/// Submit result from you-or-me-match API (legacy turn-based)
class YouOrMeSubmitResult {
  final bool success;
  final bool isCompleted;
  final int? lpEarned;
  final YouOrMeMatch match;
  final YouOrMeGameState gameState;

  YouOrMeSubmitResult({
    required this.success,
    required this.isCompleted,
    this.lpEarned,
    required this.match,
    required this.gameState,
  });

  factory YouOrMeSubmitResult.fromJson(Map<String, dynamic> json) {
    final matchData = json['match'] as Map<String, dynamic>? ?? {};
    final gameStateData = json['gameState'] as Map<String, dynamic>? ?? {};

    final match = YouOrMeMatch.fromJson(matchData);
    final gameState = YouOrMeGameState(
      match: match,
      quiz: null,
      isMyTurn: gameStateData['isMyTurn'] ?? false,
      canPlay: gameStateData['canPlay'] ?? false,
      currentQuestion: gameStateData['currentQuestion'] ?? 0,
      myAnswerCount: gameStateData['myAnswerCount'] ?? 0,
      partnerAnswerCount: gameStateData['partnerAnswerCount'] ?? 0,
      myScore: gameStateData['myScore'] ?? 0,
      partnerScore: gameStateData['partnerScore'] ?? 0,
      isCompleted: gameStateData['isCompleted'] ?? false,
      totalQuestions: gameStateData['totalQuestions'] ?? 10,
    );

    return YouOrMeSubmitResult(
      success: json['success'] ?? false,
      isCompleted: json['isCompleted'] ?? false,
      lpEarned: json['lpEarned'],
      match: match,
      gameState: gameState,
    );
  }
}

/// Bulk submit result for You-or-Me (new unified API)
class YouOrMeBulkSubmitResult {
  final bool success;
  final bool bothAnswered;
  final bool isCompleted;
  final int? matchPercentage;
  final int? lpEarned;
  final List<String> userAnswers;
  final List<String>? partnerAnswers;

  YouOrMeBulkSubmitResult({
    required this.success,
    required this.bothAnswered,
    required this.isCompleted,
    this.matchPercentage,
    this.lpEarned,
    required this.userAnswers,
    this.partnerAnswers,
  });
}

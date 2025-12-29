/// A detailed answer from a quiz match, used for journal detail display.
///
/// Contains the question text and both partners' answers with display text.
/// Fetched from API on demand, not stored in Hive.
class QuizAnswerDetail {
  /// The question index (0-based)
  final int questionIndex;

  /// The question text to display
  final String questionText;

  /// User's answer index (-1 if no answer)
  final int userAnswerIndex;

  /// User's answer as display text
  final String userAnswerText;

  /// Partner's answer index (-1 if no answer)
  final int partnerAnswerIndex;

  /// Partner's answer as display text
  final String partnerAnswerText;

  /// Whether user and partner answers are aligned
  final bool isAligned;

  QuizAnswerDetail({
    required this.questionIndex,
    required this.questionText,
    required this.userAnswerIndex,
    required this.userAnswerText,
    required this.partnerAnswerIndex,
    required this.partnerAnswerText,
    required this.isAligned,
  });

  factory QuizAnswerDetail.fromJson(Map<String, dynamic> json) {
    return QuizAnswerDetail(
      questionIndex: json['questionIndex'] ?? 0,
      questionText: json['questionText'] ?? '',
      userAnswerIndex: json['userAnswerIndex'] ?? -1,
      userAnswerText: json['userAnswerText'] ?? 'No answer',
      partnerAnswerIndex: json['partnerAnswerIndex'] ?? -1,
      partnerAnswerText: json['partnerAnswerText'] ?? 'No answer',
      isAligned: json['isAligned'] ?? false,
    );
  }
}

/// Full quiz details response from the API.
class QuizDetailsResponse {
  final String matchId;
  final String quizType;
  final String branch;
  final String quizId;
  final String quizTitle;
  final DateTime completedAt;
  final List<QuizAnswerDetail> answers;
  final int alignedCount;
  final int differentCount;
  final double? matchPercentage;

  QuizDetailsResponse({
    required this.matchId,
    required this.quizType,
    required this.branch,
    required this.quizId,
    required this.quizTitle,
    required this.completedAt,
    required this.answers,
    required this.alignedCount,
    required this.differentCount,
    this.matchPercentage,
  });

  factory QuizDetailsResponse.fromJson(Map<String, dynamic> json) {
    final details = json['details'] ?? json;
    return QuizDetailsResponse(
      matchId: details['matchId'] ?? '',
      quizType: details['quizType'] ?? '',
      branch: details['branch'] ?? '',
      quizId: details['quizId'] ?? '',
      quizTitle: details['quizTitle'] ?? '',
      completedAt: DateTime.tryParse(details['completedAt'] ?? '') ?? DateTime.now(),
      answers: (details['answers'] as List<dynamic>?)
              ?.map((a) => QuizAnswerDetail.fromJson(a))
              .toList() ??
          [],
      alignedCount: details['alignedCount'] ?? 0,
      differentCount: details['differentCount'] ?? 0,
      matchPercentage: details['matchPercentage'] != null
          ? (details['matchPercentage'] as num).toDouble()
          : null,
    );
  }
}

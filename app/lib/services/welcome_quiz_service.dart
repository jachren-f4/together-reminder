import 'package:flutter/foundation.dart';
import 'api_client.dart';
import '../utils/logger.dart';

/// Welcome Quiz question model
class WelcomeQuizQuestion {
  final String id;
  final String question;
  final List<String> options;

  const WelcomeQuizQuestion({
    required this.id,
    required this.question,
    required this.options,
  });

  factory WelcomeQuizQuestion.fromJson(Map<String, dynamic> json) {
    return WelcomeQuizQuestion(
      id: json['id'] as String,
      question: json['question'] as String,
      options:
          (json['options'] as List<dynamic>).map((e) => e as String).toList(),
    );
  }
}

/// Quiz answer to submit
class WelcomeQuizAnswer {
  final String questionId;
  final String answer;

  const WelcomeQuizAnswer({
    required this.questionId,
    required this.answer,
  });

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'answer': answer,
      };
}

/// Quiz status for both partners
class WelcomeQuizStatus {
  final bool userHasAnswered;
  final bool partnerHasAnswered;
  final bool bothCompleted;

  const WelcomeQuizStatus({
    required this.userHasAnswered,
    required this.partnerHasAnswered,
    required this.bothCompleted,
  });

  factory WelcomeQuizStatus.fromJson(Map<String, dynamic> json) {
    return WelcomeQuizStatus(
      userHasAnswered: json['userHasAnswered'] as bool? ?? false,
      partnerHasAnswered: json['partnerHasAnswered'] as bool? ?? false,
      bothCompleted: json['bothCompleted'] as bool? ?? false,
    );
  }
}

/// Quiz result comparison
class WelcomeQuizResult {
  final String questionId;
  final String question;
  final String? user1Answer;
  final String? user2Answer;
  final bool isMatch;

  const WelcomeQuizResult({
    required this.questionId,
    required this.question,
    this.user1Answer,
    this.user2Answer,
    required this.isMatch,
  });

  factory WelcomeQuizResult.fromJson(Map<String, dynamic> json) {
    return WelcomeQuizResult(
      questionId: json['questionId'] as String? ?? '',
      question: json['question'] as String? ?? '',
      user1Answer: json['user1Answer'] as String?,
      user2Answer: json['user2Answer'] as String?,
      isMatch: json['isMatch'] as bool? ?? false,
    );
  }
}

/// Complete quiz results
class WelcomeQuizResults {
  final List<WelcomeQuizResult> questions;
  final int matchCount;
  final int totalQuestions;

  const WelcomeQuizResults({
    required this.questions,
    required this.matchCount,
    required this.totalQuestions,
  });

  factory WelcomeQuizResults.fromJson(Map<String, dynamic> json) {
    return WelcomeQuizResults(
      questions: (json['questions'] as List<dynamic>?)
              ?.map(
                  (e) => WelcomeQuizResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      matchCount: json['matchCount'] as int? ?? 0,
      totalQuestions: json['totalQuestions'] as int? ?? 0,
    );
  }
}

/// Full quiz data response
class WelcomeQuizData {
  final List<WelcomeQuizQuestion> questions;
  final WelcomeQuizStatus status;
  final WelcomeQuizResults? results;

  const WelcomeQuizData({
    required this.questions,
    required this.status,
    this.results,
  });

  factory WelcomeQuizData.fromJson(Map<String, dynamic> json) {
    return WelcomeQuizData(
      questions: (json['questions'] as List<dynamic>?)
              ?.map((e) =>
                  WelcomeQuizQuestion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      status: WelcomeQuizStatus.fromJson(
          json['status'] as Map<String, dynamic>? ?? {}),
      results: json['results'] != null
          ? WelcomeQuizResults.fromJson(
              json['results'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Submit result response
class WelcomeQuizSubmitResult {
  final bool submitted;
  final bool bothCompleted;
  final bool waitingForPartner;
  final int lpAwarded;
  final WelcomeQuizResults? results;

  const WelcomeQuizSubmitResult({
    required this.submitted,
    required this.bothCompleted,
    required this.waitingForPartner,
    required this.lpAwarded,
    this.results,
  });

  factory WelcomeQuizSubmitResult.fromJson(Map<String, dynamic> json) {
    return WelcomeQuizSubmitResult(
      submitted: json['submitted'] as bool? ?? false,
      bothCompleted: json['bothCompleted'] as bool? ?? false,
      waitingForPartner: json['waitingForPartner'] as bool? ?? false,
      lpAwarded: json['lpAwarded'] as int? ?? 0,
      results: json['results'] != null
          ? WelcomeQuizResults.fromJson(
              json['results'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Service for Welcome Quiz API interactions
class WelcomeQuizService {
  static final WelcomeQuizService _instance = WelcomeQuizService._internal();
  factory WelcomeQuizService() => _instance;
  WelcomeQuizService._internal();

  final ApiClient _apiClient = ApiClient();

  /// Fetch quiz questions and current status
  Future<WelcomeQuizData?> getQuizData() async {
    try {
      final response = await _apiClient.get<WelcomeQuizData>(
        '/api/welcome-quiz',
        parser: (json) => WelcomeQuizData.fromJson(json),
      );

      if (response.success && response.data != null) {
        Logger.debug(
            'Fetched quiz data: ${response.data!.questions.length} questions, '
            'status: ${response.data!.status.bothCompleted}',
            service: 'welcome_quiz');
        return response.data;
      } else {
        Logger.warn('Failed to fetch quiz data: ${response.error}',
            service: 'welcome_quiz');
        return null;
      }
    } catch (e) {
      Logger.error('Error fetching quiz data: $e', service: 'welcome_quiz');
      return null;
    }
  }

  /// Submit quiz answers
  /// [onBehalfOf] - Optional phantom user ID for single-phone mode
  Future<WelcomeQuizSubmitResult?> submitAnswers(
      List<WelcomeQuizAnswer> answers, {String? onBehalfOf}) async {
    try {
      final body = <String, dynamic>{
        'answers': answers.map((a) => a.toJson()).toList(),
      };

      if (onBehalfOf != null) {
        body['onBehalfOf'] = onBehalfOf;
      }

      final response = await _apiClient.post<WelcomeQuizSubmitResult>(
        '/api/welcome-quiz/submit',
        body: body,
        parser: (json) => WelcomeQuizSubmitResult.fromJson(json),
      );

      if (response.success && response.data != null) {
        final result = response.data!;
        Logger.info(
            'Submitted quiz answers: bothCompleted=${result.bothCompleted}, '
            'lpAwarded=${result.lpAwarded}',
            service: 'welcome_quiz');
        return result;
      } else {
        Logger.warn('Failed to submit quiz answers: ${response.error}',
            service: 'welcome_quiz');
        return null;
      }
    } catch (e) {
      Logger.error('Error submitting quiz answers: $e', service: 'welcome_quiz');
      return null;
    }
  }

  /// Poll for partner completion (returns updated status)
  Future<WelcomeQuizStatus?> pollStatus() async {
    final data = await getQuizData();
    return data?.status;
  }
}

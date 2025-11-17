import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/quiz_question.dart';
import '../utils/logger.dart';

/// Service for loading and managing affirmation quizzes
/// Affirmation quizzes are pre-packaged sets of questions with metadata
class AffirmationQuizBank {
  static final AffirmationQuizBank _instance = AffirmationQuizBank._internal();
  factory AffirmationQuizBank() => _instance;
  AffirmationQuizBank._internal();

  List<AffirmationQuiz> _quizzes = [];
  bool _isInitialized = false;

  /// Initialize affirmation quizzes from JSON file
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final String jsonString = await rootBundle.loadString('assets/data/affirmation_quizzes.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> quizzesJson = jsonData['quizzes'] as List<dynamic>;

      _quizzes = quizzesJson.map((quizJson) {
        final List<dynamic> questionsJson = quizJson['questions'] as List<dynamic>;
        final questions = questionsJson.map((q) => QuizQuestion(
          id: '${quizJson['id']}_${questionsJson.indexOf(q)}',
          question: q['question'] as String,
          options: [], // Affirmation questions don't use options
          correctAnswerIndex: -1, // Not applicable
          category: quizJson['category'] as String,
          difficulty: quizJson['difficulty'] as int? ?? 1,
          questionType: q['questionType'] as String? ?? 'scale',
        )).toList();

        return AffirmationQuiz(
          id: quizJson['id'] as String,
          name: quizJson['name'] as String,
          category: quizJson['category'] as String,
          difficulty: quizJson['difficulty'] as int? ?? 1,
          formatType: quizJson['formatType'] as String? ?? 'affirmation',
          imagePath: quizJson['imagePath'] as String?,
          description: quizJson['description'] as String?,
          questions: questions,
        );
      }).toList();

      _isInitialized = true;
      Logger.success('Loaded ${_quizzes.length} affirmation quizzes (${_quizzes.fold<int>(0, (sum, q) => sum + q.questions.length)} total questions)', service: 'affirmation');
    } catch (e) {
      Logger.error('Error loading affirmation quizzes', error: e, service: 'affirmation');
      rethrow;
    }
  }

  /// Get all affirmation quizzes
  List<AffirmationQuiz> getAllQuizzes() {
    return _quizzes;
  }

  /// Get quizzes by category
  List<AffirmationQuiz> getQuizzesByCategory(String category) {
    return _quizzes.where((q) => q.category == category).toList();
  }

  /// Get a specific quiz by ID
  AffirmationQuiz? getQuizById(String id) {
    try {
      return _quizzes.firstWhere((q) => q.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get a random quiz for a specific category
  AffirmationQuiz? getRandomQuizForCategory(String category) {
    final categoryQuizzes = getQuizzesByCategory(category);
    if (categoryQuizzes.isEmpty) return null;
    categoryQuizzes.shuffle();
    return categoryQuizzes.first;
  }

  /// Get a quiz by matching its question IDs
  /// Used when partner device created the quiz and we need to find it for answering
  AffirmationQuiz? getQuizByQuestionIds(String category, List<String> questionIds) {
    final categoryQuizzes = getQuizzesByCategory(category);
    for (final quiz in categoryQuizzes) {
      // Check if the quiz has the same question IDs (order matters)
      final quizIds = quiz.questions.map((q) => q.id).toList();
      if (quizIds.length == questionIds.length) {
        bool matches = true;
        for (int i = 0; i < quizIds.length; i++) {
          if (quizIds[i] != questionIds[i]) {
            matches = false;
            break;
          }
        }
        if (matches) return quiz;
      }
    }
    return null;
  }

  /// Check if quizzes are loaded
  bool get isInitialized => _isInitialized;

  /// Get total quiz count
  int get totalQuizzes => _quizzes.length;
}

/// Model for a complete affirmation quiz
class AffirmationQuiz {
  final String id;
  final String name;
  final String category;
  final int difficulty;
  final String formatType;
  final String? imagePath; // Path to quest image asset
  final String? description; // Quest description
  final List<QuizQuestion> questions;

  AffirmationQuiz({
    required this.id,
    required this.name,
    required this.category,
    required this.difficulty,
    required this.formatType,
    this.imagePath,
    this.description,
    required this.questions,
  });
}

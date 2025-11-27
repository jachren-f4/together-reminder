import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/quiz_question.dart';
import '../config/brand/brand_loader.dart';
import '../utils/logger.dart';

/// Service for loading and managing affirmation quizzes with branch support.
///
/// Affirmation quizzes are pre-packaged sets of questions with metadata.
/// Supports branching content system where quizzes can be loaded from
/// different branches (e.g., 'emotional' vs 'practical') based on progression.
class AffirmationQuizBank {
  static final AffirmationQuizBank _instance = AffirmationQuizBank._internal();
  factory AffirmationQuizBank() => _instance;
  AffirmationQuizBank._internal();

  List<AffirmationQuiz> _quizzes = [];
  bool _isInitialized = false;
  String _currentBranch = '';  // Empty = legacy mode

  /// Initialize affirmation quizzes from legacy flat file
  Future<void> initialize() async {
    if (_isInitialized && _currentBranch.isEmpty) return;

    await _loadFromPath(BrandLoader().content.affirmationQuizzesPath);
    _currentBranch = '';
    _isInitialized = true;
  }

  /// Initialize affirmation quizzes from a specific branch.
  ///
  /// [branch] - Branch folder name (e.g., 'emotional', 'practical')
  ///
  /// This clears existing quizzes and loads from the branch folder.
  /// Falls back to legacy file if branch folder doesn't exist.
  Future<void> initializeWithBranch(String branch) async {
    // Skip if already loaded for this branch
    if (_isInitialized && _currentBranch == branch) {
      Logger.debug('AffirmationQuizBank already initialized for branch: $branch', service: 'affirmation');
      return;
    }

    // Clear existing quizzes when switching branches
    _quizzes = [];
    _isInitialized = false;

    // Try branch-specific path first
    final branchPath = BrandLoader().content.getAffirmationPath(branch);
    try {
      await _loadFromPath(branchPath);
      _currentBranch = branch;
      _isInitialized = true;
      Logger.info('Loaded affirmation quizzes from branch: $branch', service: 'affirmation');
    } catch (e) {
      // Fallback to legacy path
      Logger.warn('Branch $branch not found, falling back to legacy', service: 'affirmation');
      await _loadFromPath(BrandLoader().content.affirmationQuizzesPath);
      _currentBranch = '';
      _isInitialized = true;
    }
  }

  /// Load quizzes from a specific JSON file path
  Future<void> _loadFromPath(String path) async {
    try {
      final String jsonString = await rootBundle.loadString(path);
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

      Logger.success('Loaded ${_quizzes.length} affirmation quizzes (${_quizzes.fold<int>(0, (sum, q) => sum + q.questions.length)} total questions) from $path', service: 'affirmation');
    } catch (e) {
      Logger.error('Error loading affirmation quizzes from $path', error: e, service: 'affirmation');
      rethrow;
    }
  }

  /// Get the currently loaded branch (empty string = legacy)
  String get currentBranch => _currentBranch;

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

  /// Get a random quiz (from any category in current branch)
  AffirmationQuiz? getRandomQuiz() {
    if (_quizzes.isEmpty) return null;
    final shuffled = List<AffirmationQuiz>.from(_quizzes)..shuffle();
    return shuffled.first;
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

  /// Reset initialization state (useful for testing or brand switching)
  void reset() {
    _quizzes = [];
    _currentBranch = '';
    _isInitialized = false;
  }
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

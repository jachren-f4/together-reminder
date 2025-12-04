import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/quiz_question.dart';
import '../config/brand/brand_loader.dart';
import 'storage_service.dart';
import '../utils/logger.dart';

/// Manages quiz question loading and retrieval with branch support.
///
/// Supports branching content system where questions can be loaded from
/// different branches (e.g., 'lighthearted' vs 'meaningful') based on progression.
class QuizQuestionBank {
  static final QuizQuestionBank _instance = QuizQuestionBank._internal();
  factory QuizQuestionBank() => _instance;
  QuizQuestionBank._internal();

  final StorageService _storage = StorageService();
  bool _isInitialized = false;
  String _currentBranch = '';  // Empty = legacy mode

  /// Initialize quiz questions from legacy flat file
  Future<void> initialize() async {
    if (_isInitialized && _currentBranch.isEmpty) return;

    // Check if questions already loaded (legacy mode)
    if (_storage.getAllQuizQuestions().isNotEmpty && _currentBranch.isEmpty) {
      _isInitialized = true;
      return;
    }

    // Load from legacy JSON asset
    await _loadFromPath(BrandLoader().content.quizQuestionsPath);
    _currentBranch = '';
    _isInitialized = true;
  }

  /// Initialize quiz questions from a specific branch.
  ///
  /// [branch] - Branch folder name (e.g., 'lighthearted', 'meaningful')
  ///
  /// This clears existing questions and loads from the branch folder.
  /// Falls back to legacy file if branch folder doesn't exist.
  Future<void> initializeWithBranch(String branch) async {
    // Skip if already loaded for this branch
    if (_isInitialized && _currentBranch == branch) {
      Logger.debug('QuizQuestionBank already initialized for branch: $branch', service: 'quiz');
      return;
    }

    // Clear existing questions when switching branches
    await _clearQuestions();

    // Try branch-specific path first
    final branchPath = BrandLoader().content.getClassicQuizPath(branch);
    try {
      await _loadFromPath(branchPath);
      _currentBranch = branch;
      _isInitialized = true;
      Logger.info('Loaded quiz questions from branch: $branch', service: 'quiz');
    } catch (e) {
      // Fallback to legacy path
      Logger.warn('Branch $branch not found, falling back to legacy', service: 'quiz');
      await _loadFromPath(BrandLoader().content.quizQuestionsPath);
      _currentBranch = '';
      _isInitialized = true;
    }
  }

  /// Load questions from a specific JSON file path
  Future<void> _loadFromPath(String path) async {
    try {
      final String jsonString = await rootBundle.loadString(path);
      final List<dynamic> jsonList = json.decode(jsonString);

      // Convert to QuizQuestion objects and save to Hive
      for (final item in jsonList) {
        final question = QuizQuestion(
          id: item['id'],
          question: item['question'],
          options: List<String>.from(item['options']),
          correctAnswerIndex: 0, // Not used for couple quizzes
          category: item['category'],
        );
        await _storage.saveQuizQuestion(question);
      }

      Logger.success('Loaded ${jsonList.length} quiz questions from $path', service: 'quiz');
    } catch (e) {
      Logger.error('Error loading quiz questions from $path', error: e, service: 'quiz');
      rethrow;
    }
  }

  /// Clear all loaded questions (used when switching branches)
  Future<void> _clearQuestions() async {
    final box = _storage.quizQuestionsBox;
    await box.clear();
    _isInitialized = false;
    Logger.debug('Cleared quiz questions from storage', service: 'quiz');
  }

  /// Get the currently loaded branch (empty string = legacy)
  String get currentBranch => _currentBranch;

  /// Get all questions
  List<QuizQuestion> getAllQuestions() {
    return _storage.getAllQuizQuestions();
  }

  /// Get questions by category
  List<QuizQuestion> getQuestionsByCategory(String category) {
    return getAllQuestions().where((q) => q.category == category).toList();
  }

  /// Get random questions for a quiz session (1-2 per category, 5 total)
  List<QuizQuestion> getRandomQuestionsForSession() {
    final random = Random();
    final allQuestions = getAllQuestions();

    if (allQuestions.isEmpty) {
      throw Exception('No quiz questions available. Call initialize() first.');
    }

    // Categories and desired count from each
    final categories = ['favorites', 'memories', 'preferences', 'future'];
    final questionsPerCategory = [2, 1, 1, 1]; // 5 total questions

    final selectedQuestions = <QuizQuestion>[];

    for (var i = 0; i < categories.length; i++) {
      final categoryQuestions = getQuestionsByCategory(categories[i]);
      if (categoryQuestions.isEmpty) continue;

      // Shuffle and take desired count
      categoryQuestions.shuffle(random);
      final count = min(questionsPerCategory[i], categoryQuestions.length);
      selectedQuestions.addAll(categoryQuestions.take(count));
    }

    // If we don't have 5 questions, fill with random ones
    if (selectedQuestions.length < 5) {
      final remaining = allQuestions.where((q) => !selectedQuestions.contains(q)).toList();
      remaining.shuffle(random);
      selectedQuestions.addAll(remaining.take(5 - selectedQuestions.length));
    }

    // Final shuffle for variety
    selectedQuestions.shuffle(random);
    return selectedQuestions.take(5).toList();
  }

  /// Get random questions for Speed Round (10 rapid questions)
  List<QuizQuestion> getRandomQuestionsForSpeedRound() {
    final random = Random();
    final allQuestions = getAllQuestions();

    if (allQuestions.isEmpty) {
      throw Exception('No quiz questions available. Call initialize() first.');
    }

    // For Speed Round: distribute 10 questions across categories
    final categories = ['favorites', 'memories', 'preferences', 'future', 'daily_habits'];
    final questionsPerCategory = [3, 2, 2, 2, 1]; // 10 total questions

    final selectedQuestions = <QuizQuestion>[];

    for (var i = 0; i < categories.length; i++) {
      final categoryQuestions = getQuestionsByCategory(categories[i]);
      if (categoryQuestions.isEmpty) continue;

      // Shuffle and take desired count
      categoryQuestions.shuffle(random);
      final count = min(questionsPerCategory[i], categoryQuestions.length);
      selectedQuestions.addAll(categoryQuestions.take(count));
    }

    // If we don't have 10 questions, fill with random ones
    if (selectedQuestions.length < 10) {
      final remaining = allQuestions.where((q) => !selectedQuestions.contains(q)).toList();
      remaining.shuffle(random);
      selectedQuestions.addAll(remaining.take(10 - selectedQuestions.length));
    }

    // Final shuffle for variety
    selectedQuestions.shuffle(random);
    return selectedQuestions.take(10).toList();
  }

  /// Get random questions for Would You Rather (7 scenario questions)
  List<QuizQuestion> getRandomQuestionsForWouldYouRather() {
    final random = Random();
    final wouldYouRatherQuestions = getQuestionsByCategory('would_you_rather');

    if (wouldYouRatherQuestions.isEmpty) {
      throw Exception('No "Would You Rather" questions available.');
    }

    if (wouldYouRatherQuestions.length < 7) {
      throw Exception('Not enough "Would You Rather" questions. Need at least 7.');
    }

    // Shuffle and select 7 random questions
    wouldYouRatherQuestions.shuffle(random);
    return wouldYouRatherQuestions.take(7).toList();
  }

  /// Get category distribution stats
  Map<String, int> getCategoryStats() {
    final allQuestions = getAllQuestions();
    final stats = <String, int>{};

    for (final q in allQuestions) {
      stats[q.category] = (stats[q.category] ?? 0) + 1;
    }

    return stats;
  }

  /// Check if questions are loaded
  bool get isInitialized => _isInitialized;

  /// Get total question count
  int get totalQuestions => getAllQuestions().length;

  /// Reset initialization state (useful for testing or brand switching)
  Future<void> reset() async {
    await _clearQuestions();
    _currentBranch = '';
    _isInitialized = false;
  }
}

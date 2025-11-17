import 'package:flutter/material.dart';
import '../utils/logger.dart';
import '../models/quiz_session.dart';
import '../models/quiz_question.dart';
import '../services/quiz_service.dart';
import '../services/storage_service.dart';
import '../widgets/five_point_scale.dart';
import 'quiz_waiting_screen.dart';

class QuizQuestionScreen extends StatefulWidget {
  final QuizSession session;

  const QuizQuestionScreen({super.key, required this.session});

  @override
  State<QuizQuestionScreen> createState() => _QuizQuestionScreenState();
}

class _QuizQuestionScreenState extends State<QuizQuestionScreen> {
  final QuizService _quizService = QuizService();
  final StorageService _storage = StorageService();

  late List<QuizQuestion> _questions;
  int _currentQuestionIndex = 0;
  final List<int> _selectedAnswers = [];
  int? _tempSelectedAnswer;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  void _loadQuestions() {
    Logger.debug('[QuizQuestionScreen] Loading questions...', service: 'quiz');
    Logger.debug('Session ID: ${widget.session.id}', service: 'quiz');
    Logger.debug('Session category: ${widget.session.category}', service: 'quiz');
    Logger.debug('Session formatType: ${widget.session.formatType}', service: 'quiz');
    Logger.debug('Session questionIds: ${widget.session.questionIds}', service: 'quiz');

    _questions = _quizService.getSessionQuestions(widget.session);

    Logger.debug('Loaded ${_questions.length} questions', service: 'quiz');
    if (_questions.isNotEmpty) {
      for (var i = 0; i < _questions.length; i++) {
        final previewLength = _questions[i].question.length > 50 ? 50 : _questions[i].question.length;
        Logger.debug('Question $i: ${_questions[i].id} - ${_questions[i].question.substring(0, previewLength)}...', service: 'quiz');
      }
    }

    if (_questions.isEmpty) {
      setState(() {
        _error = 'Failed to load questions (formatType: ${widget.session.formatType}, category: ${widget.session.category}, ${widget.session.questionIds.length} question IDs)';
      });
    }
  }

  // Determine if current user is the subject or predictor
  bool get _isSubject {
    final user = _storage.getUser();
    if (user == null) return false;
    return widget.session.isUserSubject(user.id);
  }

  // Format question based on role
  String _formatQuestion(String question, String questionType) {
    // Affirmation questions are always first-person (no role transformation)
    if (questionType == 'scale') {
      return question;
    }

    final partner = _storage.getPartner();
    final partnerName = partner?.name ?? 'your partner';

    if (_isSubject) {
      // Subject sees questions about themselves (YOU)
      return question
          .replaceAll('your ', 'YOUR ')
          .replaceAll('you ', 'YOU ')
          .replaceAll('My ', 'YOUR ')
          .replaceAll('my ', 'your ');
    } else {
      // Predictor sees questions about the partner
      return question
          .replaceAll('your ', '$partnerName\'s ')
          .replaceAll('you ', '$partnerName ')
          .replaceAll('My ', '$partnerName\'s ')
          .replaceAll('my ', '$partnerName\'s ')
          .replaceAll('YOUR ', '$partnerName\'s ')
          .replaceAll('YOU ', '$partnerName ');
    }
  }

  void _selectAnswer(int index) {
    setState(() {
      _tempSelectedAnswer = index;
    });
  }

  void _nextQuestion() {
    if (_tempSelectedAnswer == null) return;

    setState(() {
      _selectedAnswers.add(_tempSelectedAnswer!);
      _tempSelectedAnswer = null;

      if (_currentQuestionIndex < _questions.length - 1) {
        _currentQuestionIndex++;
      } else {
        // All questions answered, submit
        _submitAnswers();
      }
    });
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        _tempSelectedAnswer = _selectedAnswers.removeLast();
      });
    }
  }

  Future<void> _submitAnswers() async {
    final user = _storage.getUser();
    if (user == null) {
      setState(() {
        _error = 'User not found';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await _quizService.submitAnswers(
        widget.session.id,
        user.id,
        _selectedAnswers,
      );

      if (!mounted) return;

      // Navigate to waiting screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => QuizWaitingScreen(session: widget.session),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isSubmitting = false;
      });
    }
  }

  String _getCategoryEmoji(String category) {
    switch (category) {
      case 'favorites':
        return '⭐';
      case 'memories':
        return '📸';
      case 'preferences':
        return '💭';
      case 'future':
        return '🔮';
      default:
        return '❓';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: Center(
          child: _error != null
              ? Text(_error!, style: TextStyle(color: theme.colorScheme.error))
              : const CircularProgressIndicator(),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${_currentQuestionIndex + 1}/${_questions.length}'),
        centerTitle: true,
        leading: _currentQuestionIndex > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _isSubmitting ? null : _previousQuestion,
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              minHeight: 6,
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Role indicator badge (hide for affirmation quizzes)
                    if (currentQuestion.questionType != 'scale')
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _isSubject
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _isSubject
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.secondary,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isSubject ? Icons.person : Icons.psychology,
                                size: 20,
                                color: _isSubject
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSecondaryContainer,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isSubject
                                    ? 'You\'re answering as yourself'
                                    : 'You\'re guessing ${_storage.getPartner()?.name ?? 'partner'}\'s answer',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _isSubject
                                      ? theme.colorScheme.onPrimaryContainer
                                      : theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (currentQuestion.questionType != 'scale')
                      const SizedBox(height: 24),

                    // Category badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _getCategoryEmoji(currentQuestion.category),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              currentQuestion.category.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Question text (role-aware formatting for classic, first-person for affirmation)
                    Text(
                      _formatQuestion(currentQuestion.question, currentQuestion.questionType),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Playfair Display',
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Answer options - conditional based on question type
                    if (currentQuestion.questionType == 'scale')
                      // Affirmation: 5-point scale widget
                      FivePointScaleWidget(
                        selectedValue: _tempSelectedAnswer != null
                            ? _tempSelectedAnswer! + 1 // Convert 0-4 index to 1-5 value
                            : null,
                        onChanged: (value) {
                          _selectAnswer(value - 1); // Convert 1-5 value to 0-4 index
                        },
                      )
                    else
                      // Classic: Multiple choice buttons
                      ...List.generate(
                        currentQuestion.options.length,
                        (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildOptionButton(
                            currentQuestion.options[index],
                            index,
                            theme,
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Error message
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom action bar
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: FilledButton(
                onPressed: _tempSelectedAnswer == null || _isSubmitting
                    ? null
                    : _nextQuestion,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _currentQuestionIndex < _questions.length - 1
                            ? 'Next Question'
                            : 'Submit Answers',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(String option, int index, ThemeData theme) {
    final isSelected = _tempSelectedAnswer == index;

    return InkWell(
      onTap: _isSubmitting ? null : () => _selectAnswer(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + index), // A, B, C, D
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                option,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

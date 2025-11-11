import 'dart:async';
import 'package:flutter/material.dart';
import '../models/quiz_session.dart';
import '../models/quiz_question.dart';
import '../services/quiz_service.dart';
import '../services/storage_service.dart';
import 'speed_round_results_screen.dart';

/// Speed Round quiz screen with 10-second timer per question
class SpeedRoundScreen extends StatefulWidget {
  final QuizSession session;

  const SpeedRoundScreen({super.key, required this.session});

  @override
  State<SpeedRoundScreen> createState() => _SpeedRoundScreenState();
}

class _SpeedRoundScreenState extends State<SpeedRoundScreen> with SingleTickerProviderStateMixin {
  final QuizService _quizService = QuizService();
  final StorageService _storage = StorageService();

  late List<QuizQuestion> _questions;
  int _currentQuestionIndex = 0;
  final List<int> _selectedAnswers = [];
  int? _tempSelectedAnswer;
  bool _isSubmitting = false;
  String? _error;

  // Timer logic
  Timer? _questionTimer;
  int _secondsRemaining = 10;
  late AnimationController _timerAnimationController;

  // Streak tracking
  final List<bool> _correctAnswers = []; // Track for streak bonus calculation

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    _timerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _startQuestionTimer();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _timerAnimationController.dispose();
    super.dispose();
  }

  void _loadQuestions() {
    _questions = _quizService.getSessionQuestions(widget.session);
    if (_questions.isEmpty) {
      setState(() {
        _error = 'Failed to load questions';
      });
    }
  }

  void _startQuestionTimer() {
    _secondsRemaining = 10;
    _timerAnimationController.reset();
    _timerAnimationController.forward();

    _questionTimer?.cancel();
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _secondsRemaining--;
      });

      if (_secondsRemaining <= 0) {
        timer.cancel();
        // Time's up! Auto-advance with no answer (treated as incorrect)
        _nextQuestion(timedOut: true);
      }
    });
  }

  // Determine if current user is the subject or predictor
  bool get _isSubject {
    final user = _storage.getUser();
    if (user == null) return false;
    return widget.session.isUserSubject(user.id);
  }

  // Format question based on role
  String _formatQuestion(String question) {
    final partner = _storage.getPartner();
    final partnerName = partner?.name ?? 'your partner';

    if (_isSubject) {
      return question
          .replaceAll('your ', 'YOUR ')
          .replaceAll('you ', 'YOU ')
          .replaceAll('My ', 'YOUR ')
          .replaceAll('my ', 'your ');
    } else {
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
    if (_tempSelectedAnswer != null) return; // Already selected, prevent changes

    setState(() {
      _tempSelectedAnswer = index;
    });

    // Auto-advance after selection
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _tempSelectedAnswer != null) {
        _nextQuestion();
      }
    });
  }

  void _nextQuestion({bool timedOut = false}) {
    _questionTimer?.cancel();
    _timerAnimationController.stop();

    setState(() {
      if (timedOut) {
        // No answer selected, use -1 as indicator
        _selectedAnswers.add(-1);
        _correctAnswers.add(false); // Timed out = incorrect
      } else {
        _selectedAnswers.add(_tempSelectedAnswer ?? -1);
        // For now, we'll calculate correctness in results screen
        _correctAnswers.add(true); // Placeholder
      }

      _tempSelectedAnswer = null;

      if (_currentQuestionIndex < _questions.length - 1) {
        _currentQuestionIndex++;
        _startQuestionTimer();
      } else {
        // All questions answered, submit
        _submitAnswers();
      }
    });
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

      // Navigate directly to Speed Round results screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => SpeedRoundResultsScreen(
            session: widget.session,
            userAnswers: _selectedAnswers,
          ),
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
        return '🌟';
      case 'daily_habits':
        return '📅';
      default:
        return '❓';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Speed Round')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty || _isSubmitting) {
      return Scaffold(
        appBar: AppBar(title: const Text('Speed Round')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Speed Round ${_currentQuestionIndex + 1}/${_questions.length}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Timer display at top
          Container(
            color: _secondsRemaining <= 3 ? Colors.red.shade50 : Colors.blue.shade50,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer,
                      size: 32,
                      color: _secondsRemaining <= 3 ? Colors.red : Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$_secondsRemaining',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: _secondsRemaining <= 3 ? Colors.red : Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _timerAnimationController,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: 1 - _timerAnimationController.value,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _secondsRemaining <= 3 ? Colors.red : Colors.blue,
                      ),
                      minHeight: 8,
                    );
                  },
                ),
              ],
            ),
          ),

          // Progress bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade300,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            minHeight: 4,
          ),

          // Question content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Category badge
                  Row(
                    children: [
                      Text(
                        '${_getCategoryEmoji(currentQuestion.category)} ${currentQuestion.category.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Question text
                  Text(
                    _formatQuestion(currentQuestion.question),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Role indicator
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isSubject ? Colors.blue.shade50 : Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isSubject
                          ? 'Answer about YOURSELF'
                          : 'Predict your partner\'s answer',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _isSubject ? Colors.blue.shade700 : Colors.purple.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Answer options
                  ...List.generate(currentQuestion.options.length, (index) {
                    final isSelected = _tempSelectedAnswer == index;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: InkWell(
                        onTap: _tempSelectedAnswer == null ? () => _selectAnswer(index) : null,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary.withOpacity(0.2)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.grey.shade300,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: Text(
                            currentQuestion.options[index],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

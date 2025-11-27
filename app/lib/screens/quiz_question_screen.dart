import 'package:flutter/material.dart';
import '../utils/logger.dart';
import '../models/quiz_session.dart';
import '../models/quiz_question.dart';
import '../services/quiz_service.dart';
import '../services/storage_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../widgets/editorial/editorial.dart';
import 'quiz_waiting_screen.dart';

class QuizQuestionScreen extends StatefulWidget {
  final QuizSession session;

  const QuizQuestionScreen({super.key, required this.session});

  @override
  State<QuizQuestionScreen> createState() => _QuizQuestionScreenState();
}

class _QuizQuestionScreenState extends State<QuizQuestionScreen>
    with TickerProviderStateMixin {
  final QuizService _quizService = QuizService();
  final StorageService _storage = StorageService();

  // Animation controllers
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  late List<QuizQuestion> _questions;
  int _currentQuestionIndex = 0;
  final List<int> _selectedAnswers = [];
  int? _tempSelectedAnswer;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    // Question slide-in animation
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    _loadQuestions();

    // Start entrance animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _loadQuestions() {
    Logger.debug('[QuizQuestionScreen] Loading questions...', service: 'quiz');
    _questions = _quizService.getSessionQuestions(widget.session);

    if (_questions.isEmpty) {
      setState(() {
        _error = 'Failed to load questions';
      });
    }
  }

  bool get _isSubject {
    final user = _storage.getUser();
    if (user == null) return false;
    return widget.session.isUserSubject(user.id);
  }

  String _formatQuestion(String question, String questionType) {
    if (questionType == 'scale') {
      return question;
    }

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
    // Haptic feedback on selection
    HapticService().trigger(HapticType.selection);
    SoundService().play(SoundId.answerSelect);

    setState(() {
      _tempSelectedAnswer = index;
    });
  }

  void _nextQuestion() {
    if (_tempSelectedAnswer == null) return;

    // Haptic feedback on next
    HapticService().trigger(HapticType.light);

    setState(() {
      _selectedAnswers.add(_tempSelectedAnswer!);
      _tempSelectedAnswer = null;

      if (_currentQuestionIndex < _questions.length - 1) {
        // Animate out, then in
        _slideController.reverse().then((_) {
          setState(() {
            _currentQuestionIndex++;
          });
          _slideController.forward();
        });
      } else {
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

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: EditorialStyles.paper,
        body: SafeArea(
          child: Column(
            children: [
              EditorialHeader(
                title: 'Quiz',
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Center(
                  child: _error != null
                      ? Text(_error!, style: TextStyle(color: EditorialStyles.ink))
                      : CircularProgressIndicator(color: EditorialStyles.ink),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;
    final isAffirmation = currentQuestion.questionType == 'scale';

    return Scaffold(
      backgroundColor: EditorialStyles.paper,
      body: SafeArea(
        child: Column(
          children: [
            // Combined header with progress
            EditorialHeader(
              title: widget.session.category ?? 'Quiz',
              counter: '${_currentQuestionIndex + 1} of ${_questions.length}',
              progress: progress,
              onClose: () => Navigator.of(context).pop(),
            ),

            // Question content with slide animation
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),

                        // Question text
                        Text(
                          _formatQuestion(currentQuestion.question, currentQuestion.questionType),
                          style: EditorialStyles.questionText,
                        ),

                        const SizedBox(height: 32),

                        // Answer options
                        if (isAffirmation)
                          _buildScaleOptions()
                        else
                          Expanded(
                            child: Column(
                              children: List.generate(
                                currentQuestion.options.length,
                                (index) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _buildOptionButton(
                                    currentQuestion.options[index],
                                    index,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Error message
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: EditorialStyles.ink.withValues(alpha: 0.05),
                              border: EditorialStyles.fullBorder,
                            ),
                            child: Text(
                              _error!,
                              style: EditorialStyles.bodySmall.copyWith(
                                color: EditorialStyles.ink,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Footer with Next button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: EditorialStyles.paper,
                border: Border(top: EditorialStyles.border),
              ),
              child: EditorialPrimaryButton(
                label: _currentQuestionIndex < _questions.length - 1
                    ? 'Next Question'
                    : 'Submit Answers',
                onPressed: _tempSelectedAnswer == null || _isSubmitting
                    ? null
                    : _nextQuestion,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(String option, int index) {
    final isSelected = _tempSelectedAnswer == index;
    final letter = String.fromCharCode(65 + index); // A, B, C, D

    return GestureDetector(
      onTap: _isSubmitting ? null : () => _selectAnswer(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? EditorialStyles.ink : EditorialStyles.paper,
          border: EditorialStyles.fullBorder,
          boxShadow: isSelected ? [
            BoxShadow(
              color: EditorialStyles.ink.withValues(alpha: 0.15),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ] : null,
        ),
        child: Row(
          children: [
            // Letter circle with animated color
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? EditorialStyles.paper : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? EditorialStyles.paper : EditorialStyles.ink,
                  width: EditorialStyles.borderWidth,
                ),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: EditorialStyles.counterText.copyWith(
                    color: isSelected ? EditorialStyles.ink : EditorialStyles.ink,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Option text
            Expanded(
              child: Text(
                option,
                style: EditorialStyles.bodySmall.copyWith(
                  color: isSelected ? EditorialStyles.paper : EditorialStyles.ink,
                ),
              ),
            ),
            // Animated checkmark
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isSelected ? 1.0 : 0.0,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: isSelected ? 1.0 : 0.5,
                curve: Curves.easeOutBack,
                child: Icon(
                  Icons.check,
                  size: 18,
                  color: EditorialStyles.paper,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScaleOptions() {
    const labels = [
      'Strongly Disagree',
      'Disagree',
      'Neutral',
      'Agree',
      'Strongly Agree',
    ];

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
              final isSelected = _tempSelectedAnswer == index;
              return EditorialScalePoint(
                number: index + 1,
                label: labels[index],
                isSelected: isSelected,
                onTap: _isSubmitting ? null : () => _selectAnswer(index),
              );
            }),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/welcome_quiz_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../utils/logger.dart';
import '../widgets/animations/animations.dart';
import '../widgets/editorial/editorial.dart';
import 'welcome_quiz_waiting_screen.dart';
import 'welcome_quiz_results_screen.dart';

/// Welcome Quiz game screen.
/// Shows questions one at a time and submits answers to server.
class WelcomeQuizGameScreen extends StatefulWidget {
  const WelcomeQuizGameScreen({super.key});

  @override
  State<WelcomeQuizGameScreen> createState() => _WelcomeQuizGameScreenState();
}

class _WelcomeQuizGameScreenState extends State<WelcomeQuizGameScreen>
    with TickerProviderStateMixin, DramaticScreenMixin {
  final WelcomeQuizService _service = WelcomeQuizService();

  // Animation controllers
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  WelcomeQuizData? _quizData;
  bool _isLoading = true;
  String? _error;

  int _currentQuestionIndex = 0;
  final List<WelcomeQuizAnswer> _answers = [];
  int? _tempSelectedIndex;
  bool _isSubmitting = false;

  @override
  bool get enableConfetti => false;

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

    _loadQuizData();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadQuizData() async {
    try {
      final data = await _service.getQuizData();

      if (!mounted) return;

      if (data == null) {
        setState(() {
          _error = 'Failed to load quiz';
          _isLoading = false;
        });
        return;
      }

      // Check if user has already answered
      if (data.status.userHasAnswered) {
        if (data.status.bothCompleted && data.results != null) {
          // Both completed - go to results
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => WelcomeQuizResultsScreen(
                results: data.results!,
              ),
            ),
          );
        } else {
          // Just user completed - go to waiting
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const WelcomeQuizWaitingScreen(),
            ),
          );
        }
        return;
      }

      setState(() {
        _quizData = data;
        _isLoading = false;
      });

      _slideController.forward();
    } catch (e) {
      Logger.error('Failed to load quiz data', error: e, service: 'welcome_quiz');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _selectAnswer(int index, [TapDownDetails? details]) {
    HapticService().trigger(HapticType.selection);
    SoundService().play(SoundId.answerSelect);

    // Trigger dramatic effects at tap position
    if (details != null) {
      triggerFlash();
      triggerParticlesAt(details.globalPosition);
    }

    setState(() {
      _tempSelectedIndex = index;
    });
  }

  void _nextQuestion() {
    if (_tempSelectedIndex == null || _quizData == null) return;

    HapticService().trigger(HapticType.light);

    final currentQuestion = _quizData!.questions[_currentQuestionIndex];
    final selectedOption = currentQuestion.options[_tempSelectedIndex!];

    // Save the answer
    _answers.add(WelcomeQuizAnswer(
      questionId: currentQuestion.id,
      answer: selectedOption,
    ));

    setState(() {
      _tempSelectedIndex = null;

      if (_currentQuestionIndex < _quizData!.questions.length - 1) {
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
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final result = await _service.submitAnswers(_answers);

      if (!mounted) return;

      if (result == null) {
        setState(() {
          _error = 'Failed to submit answers';
          _isSubmitting = false;
        });
        return;
      }

      if (result.bothCompleted && result.results != null) {
        // Both completed - go to results
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => WelcomeQuizResultsScreen(
              results: result.results!,
            ),
          ),
        );
      } else {
        // Waiting for partner
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const WelcomeQuizWaitingScreen(),
          ),
        );
      }
    } catch (e) {
      Logger.error('Failed to submit answers', error: e, service: 'welcome_quiz');
      setState(() {
        _error = e.toString();
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_quizData == null || _quizData!.questions.isEmpty) {
      return _buildErrorState('No questions available');
    }

    final questions = _quizData!.questions;
    final currentQuestion = questions[_currentQuestionIndex];

    return wrapWithDramaticEffects(
      PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: EditorialStyles.paper,
          body: SafeArea(
            child: Column(
              children: [
                // Header
                AnimatedHeaderDrop(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: EditorialStyles.border),
                    ),
                    child: Row(
                      children: [
                        // Progress indicator
                        Text(
                          '${_currentQuestionIndex + 1}/${questions.length}',
                          style: EditorialStyles.labelUppercase.copyWith(
                            letterSpacing: 2,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Welcome Quiz',
                          style: EditorialStyles.headlineSmall,
                        ),
                        const Spacer(),
                        const SizedBox(width: 40), // Balance
                      ],
                    ),
                  ),
                ),

                // Progress bar
                LinearProgressIndicator(
                  value: (_currentQuestionIndex + 1) / questions.length,
                  backgroundColor: EditorialStyles.ink.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(EditorialStyles.ink),
                  minHeight: 3,
                ),

                // Question content
                Expanded(
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 40),

                            // Question text
                            Text(
                              currentQuestion.question,
                              style: EditorialStyles.headline.copyWith(
                                fontSize: 24,
                                height: 1.3,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 40),

                            // Answer options
                            ...currentQuestion.options.asMap().entries.map((entry) {
                              final index = entry.key;
                              final option = entry.value;
                              final isSelected = _tempSelectedIndex == index;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: GestureDetector(
                                  onTapDown: (details) => _selectAnswer(index, details),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? EditorialStyles.ink
                                          : EditorialStyles.paper,
                                      border: EditorialStyles.fullBorder,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isSelected
                                                ? EditorialStyles.paper
                                                : Colors.transparent,
                                            border: Border.all(
                                              color: isSelected
                                                  ? EditorialStyles.paper
                                                  : EditorialStyles.ink,
                                              width: 2,
                                            ),
                                          ),
                                          child: isSelected
                                              ? Icon(
                                                  Icons.check,
                                                  size: 16,
                                                  color: EditorialStyles.ink,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            option,
                                            style: EditorialStyles.bodyText.copyWith(
                                              color: isSelected
                                                  ? EditorialStyles.paper
                                                  : EditorialStyles.ink,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Next/Submit button
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: EditorialButton(
                    label: _isSubmitting
                        ? 'Submitting...'
                        : _currentQuestionIndex < questions.length - 1
                            ? 'Next'
                            : 'Submit',
                    onPressed: _tempSelectedIndex != null && !_isSubmitting
                        ? _nextQuestion
                        : null,
                    isFullWidth: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: EditorialStyles.paper,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              decoration: BoxDecoration(
                border: Border(bottom: EditorialStyles.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Welcome Quiz',
                    style: EditorialStyles.headlineSmall,
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState([String? message]) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: EditorialStyles.paper,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                decoration: BoxDecoration(
                  border: Border(bottom: EditorialStyles.border),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 40), // Balance
                    const Spacer(),
                    Text(
                      'Welcome Quiz',
                      style: EditorialStyles.headlineSmall,
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message ?? _error ?? 'An error occurred',
                        style: EditorialStyles.bodyText,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      EditorialButton(
                        label: 'Try Again',
                        onPressed: () {
                          setState(() {
                            _error = null;
                          });
                          // If we have answers collected, retry submission
                          // Otherwise reload the quiz data
                          if (_answers.isNotEmpty && _quizData != null &&
                              _answers.length >= _quizData!.questions.length) {
                            _submitAnswers();
                          } else {
                            setState(() {
                              _isLoading = true;
                            });
                            _loadQuizData();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

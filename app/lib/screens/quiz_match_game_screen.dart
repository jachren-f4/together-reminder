import 'package:flutter/material.dart';
import '../models/quiz_match.dart';
import '../services/quiz_match_service.dart';
import '../services/daily_quest_service.dart';
import '../services/storage_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../utils/logger.dart';
import '../widgets/editorial/editorial.dart';
import 'quiz_match_waiting_screen.dart';
import 'quiz_match_results_screen.dart';

/// Quiz Match game screen (server-centric architecture)
///
/// Uses QuizMatchService which follows the LinkedService pattern:
/// - Server provides quiz content (questions from JSON files)
/// - Server creates and manages matches via quiz_matches table
/// - Simple polling for sync between partners
class QuizMatchGameScreen extends StatefulWidget {
  final String quizType; // 'classic' or 'affirmation'
  final String? questId; // Optional: Daily quest ID for updating local status

  const QuizMatchGameScreen({
    super.key,
    required this.quizType,
    this.questId,
  });

  @override
  State<QuizMatchGameScreen> createState() => _QuizMatchGameScreenState();
}

class _QuizMatchGameScreenState extends State<QuizMatchGameScreen>
    with TickerProviderStateMixin {
  final QuizMatchService _service = QuizMatchService();

  // Animation controllers
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  QuizMatchGameState? _gameState;
  bool _isLoading = true;
  String? _error;

  int _currentQuestionIndex = 0;
  final List<int> _selectedAnswers = [];
  int? _tempSelectedAnswer;
  bool _isSubmitting = false;

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

    _loadGameState();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _service.stopPolling();
    super.dispose();
  }

  Future<void> _loadGameState() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final gameState = await _service.getOrCreateMatch(widget.quizType);

      if (!mounted) return;

      // Check if user has already answered
      if (gameState.hasUserAnswered) {
        // Go to waiting or results
        if (gameState.isCompleted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => QuizMatchResultsScreen(
                match: gameState.match,
                quiz: gameState.quiz,
              ),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => QuizMatchWaitingScreen(
                matchId: gameState.match.id,
                quizType: widget.quizType,
              ),
            ),
          );
        }
        return;
      }

      setState(() {
        _gameState = gameState;
        _isLoading = false;
      });

      // Start entrance animation
      _slideController.forward();
    } catch (e) {
      Logger.error('Failed to load quiz match', error: e, service: 'quiz');
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _selectAnswer(int index) {
    HapticService().trigger(HapticType.selection);
    SoundService().play(SoundId.answerSelect);

    setState(() {
      _tempSelectedAnswer = index;
    });
  }

  void _nextQuestion() {
    if (_tempSelectedAnswer == null) return;

    HapticService().trigger(HapticType.light);

    setState(() {
      _selectedAnswers.add(_tempSelectedAnswer!);
      _tempSelectedAnswer = null;

      final questions = _gameState?.quiz?.questions ?? [];
      if (_currentQuestionIndex < questions.length - 1) {
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
    if (_isSubmitting || _gameState == null) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final result = await _service.submitAnswers(
        matchId: _gameState!.match.id,
        answers: _selectedAnswers,
        quizType: widget.quizType,
      );

      if (!mounted) return;

      // Update local quest status (for home screen card)
      await _updateLocalQuestStatus(bothCompleted: result.isCompleted);

      // LP is now server-authoritative - synced via UnifiedGameService.submitAnswers()
      // No local awardLovePoints() needed (would cause double-counting)
      if (result.isCompleted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => QuizMatchResultsScreen(
              match: _gameState!.match,
              quiz: _gameState!.quiz,
              matchPercentage: result.matchPercentage,
              lpEarned: result.lpEarned,
            ),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => QuizMatchWaitingScreen(
              matchId: _gameState!.match.id,
              quizType: widget.quizType,
              questId: widget.questId,
            ),
          ),
        );
      }
    } catch (e) {
      Logger.error('Failed to submit answers', error: e, service: 'quiz');
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isSubmitting = false;
      });
    }
  }

  /// Update local quest status in Hive storage
  /// Server (Supabase) is the source of truth - this just updates local cache
  Future<void> _updateLocalQuestStatus({required bool bothCompleted}) async {
    if (widget.questId == null) return;

    final storage = StorageService();
    final user = storage.getUser();
    final partner = storage.getPartner();
    if (user == null) return;

    try {
      // 1. Update local Hive storage - mark current user as completed
      final questService = DailyQuestService(storage: storage);
      await questService.completeQuestForUser(
        questId: widget.questId!,
        userId: user.id,
      );

      // 2. If both completed, also mark quest status as 'completed'
      if (bothCompleted) {
        final quest = storage.getDailyQuest(widget.questId!);
        if (quest != null) {
          quest.status = 'completed';
          // Also mark partner as completed in userCompletions
          // Use partner.id (UUID) if available, fallback to pushToken for backward compatibility
          if (partner != null) {
            final partnerKey = partner.id.isNotEmpty ? partner.id : partner.pushToken;
            quest.userCompletions ??= {};
            quest.userCompletions![partnerKey] = true;
          }
          await quest.save();
          Logger.debug('Marked quest as fully completed for ${widget.questId}', service: 'quiz');
        }
      }

      Logger.debug('Updated local quest status for ${widget.questId}', service: 'quiz');
    } catch (e) {
      // Don't fail the submit if local update fails
      Logger.error('Failed to update quest status', error: e, service: 'quiz');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: EditorialStyles.paper,
        body: SafeArea(
          child: Column(
            children: [
              EditorialHeader(
                title: _getQuizTitle(),
                onClose: () => Navigator.of(context).pop(),
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

    if (_error != null) {
      return Scaffold(
        backgroundColor: EditorialStyles.paper,
        body: SafeArea(
          child: Column(
            children: [
              EditorialHeader(
                title: _getQuizTitle(),
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          style: EditorialStyles.bodyText,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        EditorialPrimaryButton(
                          label: 'Try Again',
                          onPressed: _loadGameState,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final questions = _gameState?.quiz?.questions ?? [];
    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: EditorialStyles.paper,
        body: SafeArea(
          child: Column(
            children: [
              EditorialHeader(
                title: _getQuizTitle(),
                onClose: () => Navigator.of(context).pop(),
              ),
              const Expanded(
                child: Center(
                  child: Text('No questions available'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentQuestion = questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / questions.length;
    final isAffirmation = widget.quizType == 'affirmation';

    return Scaffold(
      backgroundColor: EditorialStyles.paper,
      body: SafeArea(
        child: Column(
          children: [
            // Combined header with progress
            EditorialHeader(
              title: _gameState?.quiz?.title ?? _getQuizTitle(),
              counter: '${_currentQuestionIndex + 1} of ${questions.length}',
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
                          currentQuestion.text,
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
                                currentQuestion.choices.length,
                                (index) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _buildOptionButton(
                                    currentQuestion.choices[index],
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
                label: _currentQuestionIndex < questions.length - 1
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

  String _getQuizTitle() {
    return widget.quizType == 'affirmation' ? 'Affirmation Quiz' : 'Classic Quiz';
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

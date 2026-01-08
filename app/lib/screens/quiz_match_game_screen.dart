import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/us2_theme.dart';
import '../models/quiz_match.dart';
import '../services/quiz_match_service.dart';
import '../services/daily_quest_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../utils/logger.dart';
import '../widgets/editorial/editorial.dart';
import '../widgets/daily_quests_widget.dart' show questRouteObserver;
import '../widgets/notification_permission_popup.dart';
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
    with TickerProviderStateMixin, RouteAware {
  final QuizMatchService _service = QuizMatchService();

  /// Track match ID to detect when server returns a different quiz
  String? _currentMatchId;

  /// Check if Us 2.0 brand is active
  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route events to detect when returning from debug menu
    final route = ModalRoute.of(context);
    if (route != null) {
      questRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    // Called when a route (e.g., debug dialog) has been popped off
    // Reload game state in case branch was advanced via debug menu
    Logger.debug('Route popped - reloading quiz state', service: 'quiz');
    _reloadIfMatchChanged();
  }

  /// Check if server has a different match and reload if needed
  Future<void> _reloadIfMatchChanged() async {
    if (!mounted || _selectedAnswers.isNotEmpty) {
      // Don't reload if user has already started answering
      return;
    }

    try {
      final newState = await _service.getOrCreateMatch(widget.quizType);
      if (!mounted) return;

      // If the match ID changed, the debug menu advanced to a new quiz
      if (_currentMatchId != null && newState.match.id != _currentMatchId) {
        Logger.info(
          'Quiz match changed: $_currentMatchId -> ${newState.match.id}',
          service: 'quiz',
        );
        // Reset UI state and reload
        setState(() {
          _gameState = newState;
          _currentMatchId = newState.match.id;
          _currentQuestionIndex = 0;
          _selectedAnswers.clear();
          _tempSelectedAnswer = null;
          _isLoading = false;
          _error = null;
        });
        // Restart entrance animation
        _slideController.reset();
        _slideController.forward();
      }
    } catch (e) {
      Logger.warn('Failed to check for match changes: $e', service: 'quiz');
    }
  }

  @override
  void dispose() {
    questRouteObserver.unsubscribe(this);
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
          // Partner hasn't answered yet - go to waiting screen
          // Set pending results flag now so it's available if user leaves waiting screen
          // Quest card will only show "RESULTS ARE READY!" when both flag is set AND quest is completed
          final contentType = '${widget.quizType}_quiz';
          await StorageService().setPendingResultsMatchId(contentType, gameState.match.id);
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
        _currentMatchId = gameState.match.id;
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
        // Create updated match with answers from the submit result
        // The original _gameState.match doesn't have answers populated
        final user = StorageService().getUser();
        final updatedMatch = QuizMatch(
          id: _gameState!.match.id,
          quizId: _gameState!.match.quizId,
          quizType: _gameState!.match.quizType,
          branch: _gameState!.match.branch,
          status: 'completed',
          player1Answers: result.userAnswers,
          player2Answers: result.partnerAnswers,
          matchPercentage: result.matchPercentage,
          player1Id: user?.id ?? '',  // Set to current user so isPlayer1 check works
          player2Id: '',
          date: _gameState!.match.date,
          createdAt: _gameState!.match.createdAt,
          completedAt: DateTime.now(),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => QuizMatchResultsScreen(
              match: updatedMatch,
              quiz: _gameState!.quiz,
              matchPercentage: result.matchPercentage,
              lpEarned: result.lpEarned,
            ),
          ),
        );
      } else {
        // Partner hasn't answered yet - go to waiting screen
        // Set pending results flag now so it's available if user leaves waiting screen
        // Quest card will only show "RESULTS ARE READY!" when both flag is set AND quest is completed
        final contentType = '${widget.quizType}_quiz';
        await StorageService().setPendingResultsMatchId(contentType, _gameState!.match.id);

        // Show notification permission popup for classic quiz if not yet authorized
        if (widget.quizType == 'classic' && mounted) {
          final isAuthorized = await NotificationService.isAuthorized();
          if (!isAuthorized && mounted) {
            final shouldEnable = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) => const NotificationPermissionPopup(),
            );

            if (shouldEnable == true) {
              await NotificationService.requestPermission();
            }
          }
        }

        if (!mounted) return;

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
          await StorageService().saveDailyQuest(quest);
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
    // Us 2.0 brand uses different styling
    if (_isUs2) {
      return _buildUs2Screen();
    }

    if (_isLoading) {
      return PopScope(
        canPop: false,
        child: Scaffold(
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
        ),
      );
    }

    if (_error != null) {
      return PopScope(
        canPop: false,
        child: Scaffold(
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
        ),
      );
    }

    final questions = _gameState?.quiz?.questions ?? [];
    if (questions.isEmpty) {
      return PopScope(
        canPop: false,
        child: Scaffold(
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
        ),
      );
    }

    final currentQuestion = questions[_currentQuestionIndex];
    final progress = _currentQuestionIndex / questions.length;
    final isAffirmation = widget.quizType == 'affirmation';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: EditorialStyles.paper,
        body: Stack(
          children: [
            SafeArea(
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

            // Loading overlay when submitting - outside SafeArea to cover full screen
            if (_isSubmitting)
              Positioned.fill(
                child: Container(
                  color: EditorialStyles.ink.withValues(alpha: 0.3),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build Us 2.0 styled quiz screen
  Widget _buildUs2Screen() {
    if (_isLoading) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(gradient: Us2Theme.backgroundGradient),
            child: SafeArea(
              child: Column(
                children: [
                  _buildUs2Header(),
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Us2Theme.primaryBrandPink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(gradient: Us2Theme.backgroundGradient),
            child: SafeArea(
              child: Column(
                children: [
                  _buildUs2Header(),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _error!,
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                color: Us2Theme.textDark,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            _buildUs2Button('Try Again', _loadGameState),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final questions = _gameState?.quiz?.questions ?? [];
    if (questions.isEmpty) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(gradient: Us2Theme.backgroundGradient),
            child: SafeArea(
              child: Column(
                children: [
                  _buildUs2Header(),
                  Expanded(
                    child: Center(
                      child: Text(
                        'No questions available',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          color: Us2Theme.textMedium,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final currentQuestion = questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / questions.length;
    final isAffirmation = widget.quizType == 'affirmation';

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: Us2Theme.backgroundGradient),
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    // Header with progress
                    _buildUs2Header(
                      counter: '${_currentQuestionIndex + 1} of ${questions.length}',
                      progress: progress,
                    ),

                    // Question content
                    Expanded(
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: isAffirmation
                              // Affirmation uses centered layout without scroll
                              ? Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      const SizedBox(height: 8),
                                      // Question text
                                      Text(
                                        currentQuestion.text,
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          color: Us2Theme.textDark,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      // Scale options in expanded area
                                      Expanded(child: _buildUs2ScaleOptions()),
                                    ],
                                  ),
                                )
                              // Classic quiz uses scrollable list
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      const SizedBox(height: 8),
                                      // Question text
                                      Text(
                                        currentQuestion.text,
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          color: Us2Theme.textDark,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      // Answer options
                                      ...List.generate(
                                        currentQuestion.choices.length,
                                        (index) => Padding(
                                          padding: const EdgeInsets.only(bottom: 10),
                                          child: _buildUs2OptionButton(
                                            currentQuestion.choices[index],
                                            index,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ),

                    // Footer
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                      ),
                      child: _buildUs2Button(
                        _currentQuestionIndex < questions.length - 1
                            ? 'Next Question'
                            : 'Submit Answers',
                        _tempSelectedAnswer == null || _isSubmitting
                            ? null
                            : _nextQuestion,
                      ),
                    ),
                  ],
                ),
              ),

              // Loading overlay
              if (_isSubmitting)
                Positioned.fill(
                  child: Container(
                    color: Us2Theme.textDark.withOpacity(0.3),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Us2Theme.primaryBrandPink,
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

  /// Build Us 2.0 styled header
  Widget _buildUs2Header({String? counter, double? progress}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Close button
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 20,
                    color: Us2Theme.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Title
              Text(
                _gameState?.quiz?.title ?? _getQuizTitle(),
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Us2Theme.textDark,
                ),
              ),
              const Spacer(),
              // Counter badge
              if (counter != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: Us2Theme.accentGradient,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    counter,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          // Progress bar
          if (progress != null) ...[
            const SizedBox(height: 12),
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: Us2Theme.accentGradient,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build Us 2.0 styled option button
  Widget _buildUs2OptionButton(String option, int index) {
    final isSelected = _tempSelectedAnswer == index;
    final letter = String.fromCharCode(65 + index); // A, B, C, D

    return GestureDetector(
      onTap: _isSubmitting ? null : () => _selectAnswer(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Us2Theme.cardSalmon, Us2Theme.cardSalmonDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Us2Theme.cream,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? null
              : Border.all(color: Us2Theme.beige, width: 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Us2Theme.glowPink.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Letter circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Us2Theme.textMedium,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : Us2Theme.textDark,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Option text
            Expanded(
              child: Text(
                option,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : Us2Theme.textDark,
                  height: 1.4,
                ),
              ),
            ),
            // Checkmark
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isSelected ? 1.0 : 0.0,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: isSelected ? 1.0 : 0.5,
                curve: Curves.easeOutBack,
                child: const Icon(
                  Icons.check,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build Us 2.0 styled scale options (for affirmation quiz)
  Widget _buildUs2ScaleOptions() {
    const labels = [
      'Strongly\nDisagree',
      'Disagree',
      'Neutral',
      'Agree',
      'Strongly\nAgree',
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (index) {
            final isSelected = _tempSelectedAnswer == index;
            return GestureDetector(
              onTap: _isSubmitting ? null : () => _selectAnswer(index),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Us2Theme.cardSalmon, Us2Theme.cardSalmonDark],
                            )
                          : null,
                      color: isSelected ? null : Us2Theme.cream,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? null
                          : Border.all(color: Us2Theme.beige, width: 2),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Us2Theme.glowPink.withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : Us2Theme.textMedium,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 60,
                    child: Text(
                      labels[index],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? Us2Theme.primaryBrandPink : Us2Theme.textMedium,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  /// Build Us 2.0 styled button
  Widget _buildUs2Button(String label, VoidCallback? onPressed) {
    final isEnabled = onPressed != null;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: isEnabled ? Us2Theme.accentGradient : null,
          color: isEnabled ? null : Us2Theme.beige,
          borderRadius: BorderRadius.circular(30),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: Us2Theme.glowPink.withOpacity(0.4),
                    blurRadius: 25,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isEnabled ? Colors.white : Us2Theme.textLight,
            ),
          ),
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

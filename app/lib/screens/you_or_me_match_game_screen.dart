import 'package:flutter/material.dart';
import '../models/you_or_me_match.dart';
import '../services/you_or_me_match_service.dart';
import '../services/daily_quest_service.dart';
import '../services/storage_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../utils/logger.dart';
import '../widgets/editorial/editorial.dart';
import '../widgets/daily_quests_widget.dart' show questRouteObserver;
import 'you_or_me_match_waiting_screen.dart';
import 'you_or_me_match_results_screen.dart';

/// You-or-Me Match game screen (bulk submission)
///
/// Players answer all questions locally, then submit all at once.
/// Uses unified game API (POST /api/sync/game/you_or_me/play).
class YouOrMeMatchGameScreen extends StatefulWidget {
  final String? questId; // Optional: Daily quest ID for updating local status

  const YouOrMeMatchGameScreen({
    super.key,
    this.questId,
  });

  @override
  State<YouOrMeMatchGameScreen> createState() => _YouOrMeMatchGameScreenState();
}

class _YouOrMeMatchGameScreenState extends State<YouOrMeMatchGameScreen>
    with TickerProviderStateMixin, RouteAware {
  final YouOrMeMatchService _service = YouOrMeMatchService();
  final StorageService _storage = StorageService();

  YouOrMeGameState? _gameState;

  /// Track match ID to detect when server returns a different quiz
  String? _currentMatchId;
  bool _isLoading = true;
  String? _error;
  bool _isSubmitting = false;

  // Question navigation
  int _currentQuestionIndex = 0;
  final List<String> _selectedAnswers = []; // 'you' or 'me'
  String? _tempSelectedAnswer;

  // Card swipe animation
  late AnimationController _cardAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _fadeAnimation;

  // Decision stamp animation
  late AnimationController _stampController;
  late Animation<double> _stampScaleAnimation;
  late Animation<double> _stampOpacityAnimation;

  @override
  void initState() {
    super.initState();

    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.5, 0),
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeInOut,
    ));

    _rotateAnimation = Tween<double>(
      begin: 0,
      end: 0.3,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeInOut,
    ));

    // Decision stamp animation (bouncy pop-in)
    _stampController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _stampScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.2).chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(_stampController);

    _stampOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _stampController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
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
    Logger.debug('Route popped - reloading You-or-Me state', service: 'you_or_me');
    _reloadIfMatchChanged();
  }

  /// Check if server has a different match and reload if needed
  Future<void> _reloadIfMatchChanged() async {
    if (!mounted || _selectedAnswers.isNotEmpty) {
      // Don't reload if user has already started answering
      return;
    }

    try {
      final newState = await _service.getOrCreateMatch();
      if (!mounted) return;

      // If the match ID changed, the debug menu advanced to a new quiz
      if (_currentMatchId != null && newState.match.id != _currentMatchId) {
        Logger.info(
          'You-or-Me match changed: $_currentMatchId -> ${newState.match.id}',
          service: 'you_or_me',
        );
        // Reset UI state and reload
        _cardAnimationController.reset();
        _stampController.reset();
        setState(() {
          _gameState = newState;
          _currentMatchId = newState.match.id;
          _currentQuestionIndex = 0;
          _selectedAnswers.clear();
          _tempSelectedAnswer = null;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      Logger.warn('Failed to check for match changes: $e', service: 'you_or_me');
    }
  }

  @override
  void dispose() {
    questRouteObserver.unsubscribe(this);
    _cardAnimationController.dispose();
    _stampController.dispose();
    _service.stopPolling();
    super.dispose();
  }

  Future<void> _loadGameState() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final gameState = await _service.getOrCreateMatch();

      if (!mounted) return;

      // Check if user has already answered
      if (gameState.myAnswerCount > 0) {
        // User already submitted - go to waiting or results
        if (gameState.isCompleted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => YouOrMeMatchResultsScreen(
                match: gameState.match,
                quiz: gameState.quiz,
                myScore: gameState.myScore,
                partnerScore: gameState.partnerScore,
              ),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => YouOrMeMatchWaitingScreen(
                matchId: gameState.match.id,
                questId: widget.questId,
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
    } catch (e) {
      Logger.error('Failed to load You-or-Me match', error: e, service: 'you_or_me');
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAnswer(String answer) async {
    if (_isSubmitting || _gameState == null) return;

    HapticService().trigger(HapticType.medium);
    SoundService().play(SoundId.answerSelect);

    setState(() {
      _tempSelectedAnswer = answer;
    });

    // Show decision stamp, then animate card out
    await _stampController.forward();

    // Update slide direction based on answer (right = Me, left = You)
    final isMe = answer == 'me';
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(isMe ? 1.5 : -1.5, 0),
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeInOut,
    ));

    _rotateAnimation = Tween<double>(
      begin: 0,
      end: isMe ? 0.15 : -0.15,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeInOut,
    ));

    await _cardAnimationController.forward();

    // Store answer locally and move to next question
    await _nextQuestion(answer);
  }

  Future<void> _nextQuestion(String answer) async {
    final questions = _gameState?.quiz?.questions ?? [];

    setState(() {
      _selectedAnswers.add(answer);
      _tempSelectedAnswer = null;
    });

    // Check if we've answered all questions
    if (_currentQuestionIndex < questions.length - 1) {
      // Animate card back in and show next question
      _cardAnimationController.reset();
      _stampController.reset();
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      // All questions answered - submit all at once
      await _submitAllAnswers();
    }
  }

  Future<void> _submitAllAnswers() async {
    if (_gameState == null) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final result = await _service.submitAllAnswers(
        matchId: _gameState!.match.id,
        answers: _selectedAnswers,
      );

      if (!mounted) return;

      // Update local quest status (for home screen card)
      await _updateLocalQuestStatus(bothCompleted: result.isCompleted);

      // LP is now server-authoritative - synced via UnifiedGameService.submitAnswers()
      // No local awardLovePoints() needed (would cause double-counting)
      if (result.isCompleted) {
        // Calculate match count from answers (how many questions both partners answered the same)
        // For you-or-me: answers are relative (me=1, you=0). A match means both picked the SAME PERSON.
        // Server inverts player2's answers before comparison, and returns them already inverted.
        // So here we can compare directly - if userAnswers[i] == partnerAnswers[i], both picked the same person.
        int matchCount = 0;
        final userAnswers = result.userAnswers ?? [];
        final partnerAnswers = result.partnerAnswers ?? [];
        for (int i = 0; i < userAnswers.length && i < partnerAnswers.length; i++) {
          if (userAnswers[i] == partnerAnswers[i]) {
            matchCount++;
          }
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => YouOrMeMatchResultsScreen(
              match: _gameState!.match,
              quiz: _gameState!.quiz,
              myScore: matchCount, // Both partners see the same match count
              partnerScore: matchCount,
              lpEarned: result.lpEarned,
              matchPercentage: result.matchPercentage,
              userAnswers: result.userAnswers,
              partnerAnswers: result.partnerAnswers,
            ),
          ),
        );
      } else {
        // Partner hasn't answered yet - go to waiting screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => YouOrMeMatchWaitingScreen(
              matchId: _gameState!.match.id,
              questId: widget.questId,
            ),
          ),
        );
      }
    } catch (e) {
      Logger.error('Failed to submit answers', error: e, service: 'you_or_me');
      _cardAnimationController.reset();
      _stampController.reset();
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isSubmitting = false;
        // Reset to allow retry - remove last answer
        if (_selectedAnswers.isNotEmpty) {
          _selectedAnswers.removeLast();
        }
      });
    }
  }

  /// Update local quest status in Hive storage
  /// Server (Supabase) is the source of truth - this just updates local cache
  Future<void> _updateLocalQuestStatus({required bool bothCompleted}) async {
    if (widget.questId == null) return;

    final user = _storage.getUser();
    final partner = _storage.getPartner();
    if (user == null) return;

    try {
      // 1. Update local Hive storage - mark current user as completed
      final questService = DailyQuestService(storage: _storage);
      await questService.completeQuestForUser(
        questId: widget.questId!,
        userId: user.id,
      );

      // 2. If both completed, also mark quest status as 'completed'
      if (bothCompleted) {
        final quest = _storage.getDailyQuest(widget.questId!);
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
          Logger.debug('Marked quest as fully completed for ${widget.questId}', service: 'you_or_me');
        }
      }

      Logger.debug('Updated local quest status for ${widget.questId}', service: 'you_or_me');
    } catch (e) {
      // Don't fail the submit if local update fails
      Logger.error('Failed to update quest status', error: e, service: 'you_or_me');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: EditorialStyles.paper,
          body: SafeArea(
            child: Column(
              children: [
                EditorialHeader(
                  title: 'You or Me',
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

    if (_error != null && _gameState == null) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: EditorialStyles.paper,
          body: SafeArea(
            child: Column(
              children: [
                EditorialHeader(
                  title: 'You or Me',
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
                  title: 'You or Me',
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

    final currentIndex = _currentQuestionIndex;
    if (currentIndex >= questions.length) {
      // Shouldn't happen, but handle gracefully
      return PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: EditorialStyles.paper,
          body: const Center(child: Text('Loading...')),
        ),
      );
    }

    final question = questions[currentIndex];
    final progress = (currentIndex + 1) / questions.length;
    final partnerName = _storage.getPartner()?.name ?? 'Partner';
    final userName = _storage.getUser()?.name ?? 'You';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: EditorialStyles.paper,
        body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Header with progress
                EditorialHeader(
                  title: 'You or Me',
                  counter: '${currentIndex + 1} of ${questions.length}',
                  progress: progress,
                  onClose: () => Navigator.of(context).popUntil((route) => route.isFirst),
                ),

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Card stack
                        Expanded(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Background cards
                              if (currentIndex + 2 < questions.length)
                                _buildBackgroundCard(offset: 12, opacity: 0.3, scale: 0.94),
                              if (currentIndex + 1 < questions.length)
                                _buildBackgroundCard(offset: 6, opacity: 0.6, scale: 0.97),

                              // Current card with animation
                              SlideTransition(
                                position: _slideAnimation,
                                child: RotationTransition(
                                  turns: _rotateAnimation,
                                  child: FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: Stack(
                                      children: [
                                        _buildQuestionCard(question),
                                        // Decision stamp overlay
                                        if (_tempSelectedAnswer != null)
                                          Positioned.fill(
                                            child: _buildDecisionStamp(_tempSelectedAnswer! == 'me'),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Answer buttons
                        _buildAnswerButtons(userName, partnerName),

                        // Error message
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: EditorialStyles.bodySmall.copyWith(
                              color: EditorialStyles.ink,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Loading overlay
          if (_isSubmitting)
            Container(
              color: EditorialStyles.ink.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildQuestionCard(ServerYouOrMeQuestion question) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: EditorialStyles.paper,
        border: EditorialStyles.fullBorder,
        boxShadow: [
          BoxShadow(
            color: EditorialStyles.ink.withValues(alpha: 0.1),
            offset: const Offset(6, 6),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            question.prompt.toUpperCase(),
            style: EditorialStyles.labelUppercaseSmall.copyWith(
              color: EditorialStyles.inkMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            '"${question.content}"',
            style: EditorialStyles.questionText.copyWith(
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundCard({
    required double offset,
    required double opacity,
    required double scale,
  }) {
    return Transform.translate(
      offset: Offset(0, -offset),
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: EditorialStyles.paper,
              border: EditorialStyles.fullBorder,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerButtons(String userName, String partnerName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: EditorialStyles.fullBorder,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAnswerButton(
            label: userName,
            emoji: '🙋',
            onTap: () => _handleAnswer('me'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'or',
              style: EditorialStyles.bodySmall.copyWith(
                color: EditorialStyles.inkMuted,
              ),
            ),
          ),
          _buildAnswerButton(
            label: partnerName,
            emoji: '🙋‍♀️',
            onTap: () => _handleAnswer('you'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerButton({
    required String label,
    required String emoji,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isSubmitting ? null : onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: EditorialStyles.paper,
          border: EditorialStyles.fullBorder,
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              label.length > 8 ? '${label.substring(0, 8)}...' : label,
              style: EditorialStyles.labelUppercase.copyWith(
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecisionStamp(bool isMe) {
    final stampText = isMe ? 'ME' : 'YOU';
    final stampColor = isMe
        ? EditorialStyles.ink
        : EditorialStyles.inkMuted;

    return AnimatedBuilder(
      animation: _stampController,
      builder: (context, child) {
        return Center(
          child: Transform.scale(
            scale: _stampScaleAnimation.value,
            child: Opacity(
              opacity: _stampOpacityAnimation.value,
              child: Transform.rotate(
                angle: isMe ? 0.15 : -0.15,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: stampColor,
                      width: 4,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    stampText,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: stampColor,
                      letterSpacing: 8,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

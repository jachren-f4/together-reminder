import 'package:flutter/material.dart';
import '../models/you_or_me_match.dart';
import '../services/you_or_me_match_service.dart';
import '../services/daily_quest_service.dart';
import '../services/storage_service.dart';
import '../services/arena_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../utils/logger.dart';
import '../widgets/editorial/editorial.dart';
import 'you_or_me_match_waiting_screen.dart';
import 'you_or_me_match_results_screen.dart';

/// You-or-Me Match game screen (server-centric architecture)
///
/// Uses YouOrMeMatchService which follows the LinkedService pattern:
/// - Server provides quiz content (questions from JSON files)
/// - Server creates and manages matches via quiz_matches table
/// - Turn-based: players alternate answering questions
/// - Simple polling for sync between partners
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
    with TickerProviderStateMixin {
  final YouOrMeMatchService _service = YouOrMeMatchService();
  final StorageService _storage = StorageService();
  final ArenaService _arenaService = ArenaService();

  YouOrMeGameState? _gameState;
  bool _isLoading = true;
  String? _error;
  bool _isSubmitting = false;
  String? _pendingAnswer; // 'you' or 'me'

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
  void dispose() {
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

      // Check game completion and turn status
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
        return;
      }

      if (!gameState.isMyTurn) {
        // Go to waiting screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => YouOrMeMatchWaitingScreen(
              matchId: gameState.match.id,
            ),
          ),
        );
        return;
      }

      setState(() {
        _gameState = gameState;
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
      _pendingAnswer = answer;
    });

    // Show decision stamp, then submit
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

    // Submit the answer
    await _submitAnswer(answer);
  }

  Future<void> _submitAnswer(String answer) async {
    if (_gameState == null) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final result = await _service.submitAnswer(
        matchId: _gameState!.match.id,
        questionIndex: _gameState!.currentQuestion,
        answer: answer,
      );

      if (!mounted) return;

      if (result.isCompleted) {
        // Update local quest status (for home screen card)
        await _updateLocalQuestStatus(bothCompleted: true);

        // Award LP locally when game is completed
        final lpEarned = result.lpEarned ?? 30;
        await _arenaService.awardLovePoints(lpEarned, 'you_or_me_complete');
        Logger.debug('Awarded $lpEarned LP locally for You-or-Me completion', service: 'you_or_me');

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => YouOrMeMatchResultsScreen(
              match: result.match,
              quiz: _gameState!.quiz,
              myScore: result.gameState.myScore,
              partnerScore: result.gameState.partnerScore,
              lpEarned: result.lpEarned,
            ),
          ),
        );
      } else if (!result.gameState.isMyTurn) {
        // Partner's turn now - update our completion status
        await _updateLocalQuestStatus(bothCompleted: false);

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => YouOrMeMatchWaitingScreen(
              matchId: _gameState!.match.id,
              questId: widget.questId,
            ),
          ),
        );
      } else {
        // Still our turn, update state and reset animation
        _cardAnimationController.reset();
        _stampController.reset();
        setState(() {
          _gameState = result.gameState;
          _pendingAnswer = null;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to submit answer', error: e, service: 'you_or_me');
      _cardAnimationController.reset();
      _stampController.reset();
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _pendingAnswer = null;
        _isSubmitting = false;
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
          if (partner != null) {
            quest.userCompletions ??= {};
            quest.userCompletions![partner.pushToken] = true;
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
      return Scaffold(
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
      );
    }

    if (_error != null && _gameState == null) {
      return Scaffold(
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
      );
    }

    final currentIndex = _gameState!.currentQuestion;
    if (currentIndex >= questions.length) {
      // Shouldn't happen, but handle gracefully
      return Scaffold(
        backgroundColor: EditorialStyles.paper,
        body: const Center(child: Text('Loading...')),
      );
    }

    final question = questions[currentIndex];
    final progress = (currentIndex + 1) / questions.length;
    final partnerName = _storage.getPartner()?.name ?? 'Partner';
    final userName = _storage.getUser()?.name ?? 'You';

    return Scaffold(
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
                                        if (_pendingAnswer != null)
                                          Positioned.fill(
                                            child: _buildDecisionStamp(_pendingAnswer! == 'me'),
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

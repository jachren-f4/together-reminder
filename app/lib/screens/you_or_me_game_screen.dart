import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/you_or_me.dart';
import '../services/storage_service.dart';
import '../services/you_or_me_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../utils/logger.dart';
import '../widgets/editorial/editorial.dart';
import 'you_or_me_results_screen.dart';
import 'you_or_me_waiting_screen.dart';

/// Main game screen for You or Me
/// Editorial newspaper aesthetic with card stack and swipe animations
class YouOrMeGameScreen extends StatefulWidget {
  final YouOrMeSession session;
  final int initialQuestionIndex; // For resuming mid-game
  final List<YouOrMeAnswer>? existingAnswers; // Pre-populated answers when resuming

  const YouOrMeGameScreen({
    super.key,
    required this.session,
    this.initialQuestionIndex = 0,
    this.existingAnswers,
  });

  @override
  State<YouOrMeGameScreen> createState() => _YouOrMeGameScreenState();
}

class _YouOrMeGameScreenState extends State<YouOrMeGameScreen>
    with TickerProviderStateMixin {
  final StorageService _storage = StorageService();
  final YouOrMeService _service = YouOrMeService();

  late int _currentQuestionIndex;
  late List<YouOrMeAnswer> _answers;
  bool _isSubmitting = false;
  bool _isAnimating = false;

  // Card swipe animation
  late AnimationController _cardAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _fadeAnimation;

  // Drag state for interactive swipe
  Offset _dragOffset = Offset.zero;
  double _dragRotation = 0;
  bool? _pendingAnswer; // true = Me (right), false = You (left)

  // Decision stamp animation
  late AnimationController _stampController;
  late Animation<double> _stampScaleAnimation;
  late Animation<double> _stampOpacityAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize with resume state if provided
    _currentQuestionIndex = widget.initialQuestionIndex;
    _answers = widget.existingAnswers != null
        ? List<YouOrMeAnswer>.from(widget.existingAnswers!)
        : [];

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

    _cardAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _cardAnimationController.reset();
        _stampController.reset();
        setState(() {
          _pendingAnswer = null;
        });

        final wasLastQuestion = (_currentQuestionIndex + 1) >= widget.session.questions.length;

        if (wasLastQuestion) {
          _submitAnswers();
        } else {
          setState(() {
            _currentQuestionIndex++;
          });
        }
      }
    });

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
  }

  @override
  void dispose() {
    _cardAnimationController.dispose();
    _stampController.dispose();
    super.dispose();
  }

  Future<void> _handleAnswer(bool answerValue) async {
    if (_isSubmitting || _isAnimating) return;

    _isAnimating = true;

    // Haptic and sound feedback
    HapticService().trigger(HapticType.medium);
    SoundService().play(SoundId.answerSelect);

    final question = widget.session.questions[_currentQuestionIndex];

    final answer = YouOrMeAnswer(
      questionId: question.id,
      questionPrompt: question.prompt,
      questionContent: question.content,
      answerValue: answerValue,
      answeredAt: DateTime.now(),
    );

    _answers.add(answer);
    Logger.info(
      'Answer recorded: ${question.content} -> ${answerValue ? "Me" : "You"}',
      service: 'you_or_me',
    );

    // Show decision stamp, then swipe card away
    setState(() {
      _pendingAnswer = answerValue;
    });
    await _stampController.forward();

    // Update slide direction based on answer (right = Me, left = You)
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(answerValue ? 1.5 : -1.5, 0),
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeInOut,
    ));

    _rotateAnimation = Tween<double>(
      begin: 0,
      end: answerValue ? 0.15 : -0.15,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeInOut,
    ));

    await _cardAnimationController.forward();

    _isAnimating = false;
  }

  // Handle drag gestures for swipe interaction
  void _onPanStart(DragStartDetails details) {
    if (_isSubmitting || _isAnimating) return;
    HapticService().trigger(HapticType.selection);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isSubmitting || _isAnimating) return;

    setState(() {
      _dragOffset += details.delta;
      // Rotation proportional to horizontal drag (-0.15 to 0.15 radians)
      _dragRotation = (_dragOffset.dx / 300).clamp(-0.15, 0.15);

      // Determine pending answer based on drag direction
      if (_dragOffset.dx.abs() > 50) {
        _pendingAnswer = _dragOffset.dx > 0; // Right = Me (true), Left = You (false)
      } else {
        _pendingAnswer = null;
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isSubmitting || _isAnimating) return;

    final velocity = details.velocity.pixelsPerSecond.dx;
    final threshold = 100.0;

    // Check if swipe was strong enough
    if (_dragOffset.dx.abs() > threshold || velocity.abs() > 500) {
      final answerValue = _dragOffset.dx > 0; // Right = Me, Left = You
      _handleAnswer(answerValue);
    }

    // Reset drag state
    setState(() {
      _dragOffset = Offset.zero;
      _dragRotation = 0;
      if (_pendingAnswer == null) {
        _pendingAnswer = null;
      }
    });
  }

  Future<void> _submitAnswers() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final user = _storage.getUser();
      if (user == null) {
        throw Exception('User not found');
      }

      Logger.info('Submitting ${_answers.length} answers', service: 'you_or_me');
      await _service.submitAnswers(widget.session.id, user.id, _answers);

      if (!mounted) return;

      final updatedSession = await _service.getSession(widget.session.id);
      if (updatedSession == null) {
        throw Exception('Session not found');
      }

      if (updatedSession.areBothUsersAnswered()) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => YouOrMeResultsScreen(session: updatedSession),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => YouOrMeWaitingScreen(session: updatedSession),
          ),
        );
      }
    } catch (e) {
      Logger.error('Error submitting answers', error: e, service: 'you_or_me');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting answers: $e'),
          backgroundColor: EditorialStyles.ink,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  String _getUserName() {
    final user = _storage.getUser();
    return user?.name ?? 'You';
  }

  String _getPartnerName() {
    final partner = _storage.getPartner();
    return partner?.name ?? 'Partner';
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.session.questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / widget.session.questions.length;

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
                  counter: '${_currentQuestionIndex + 1} of ${widget.session.questions.length}',
                  progress: progress,
                  onClose: () {
                    // Pop all the way back to home screen (skips intro)
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
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
                              if (_currentQuestionIndex + 2 < widget.session.questions.length)
                                _buildBackgroundCard(offset: 12, opacity: 0.3, scale: 0.94),
                              if (_currentQuestionIndex + 1 < widget.session.questions.length)
                                _buildBackgroundCard(offset: 6, opacity: 0.6, scale: 0.97),

                              // Current card with drag gesture and animation
                              GestureDetector(
                                onPanStart: _onPanStart,
                                onPanUpdate: _onPanUpdate,
                                onPanEnd: _onPanEnd,
                                child: Transform.translate(
                                  offset: _dragOffset,
                                  child: Transform.rotate(
                                    angle: _dragRotation,
                                    child: SlideTransition(
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
                                                  child: _buildDecisionStamp(_pendingAnswer!),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Answer buttons
                        _buildAnswerButtons(),
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
              color: EditorialStyles.ink.withValues(alpha: 0.5),
              child: Center(
                child: CircularProgressIndicator(color: EditorialStyles.paper),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(YouOrMeQuestion question) {
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

  Widget _buildAnswerButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: EditorialStyles.fullBorder,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAnswerButton(
            label: _getUserName(),
            emoji: '🙋',
            onTap: () => _handleAnswer(true),
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
            label: _getPartnerName(),
            emoji: '🙋‍♀️',
            onTap: () => _handleAnswer(false),
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

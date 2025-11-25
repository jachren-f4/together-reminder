import 'package:flutter/material.dart';
import '../models/you_or_me.dart';
import '../services/storage_service.dart';
import '../services/you_or_me_service.dart';
import '../utils/logger.dart';
import 'you_or_me_results_screen.dart';
import 'you_or_me_waiting_screen.dart';

/// Main game screen for You or Me
/// Shows question cards with swipe animations and answer buttons
class YouOrMeGameScreen extends StatefulWidget {
  final YouOrMeSession session;

  const YouOrMeGameScreen({
    super.key,
    required this.session,
  });

  @override
  State<YouOrMeGameScreen> createState() => _YouOrMeGameScreenState();
}

class _YouOrMeGameScreenState extends State<YouOrMeGameScreen>
    with SingleTickerProviderStateMixin {
  final StorageService _storage = StorageService();
  final YouOrMeService _service = YouOrMeService();

  int _currentQuestionIndex = 0;
  final List<YouOrMeAnswer> _answers = [];
  bool _isSubmitting = false;
  bool _isAnimating = false;

  late AnimationController _cardAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Setup card animation controller
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

        // Check if this was the last question BEFORE incrementing
        final wasLastQuestion = (_currentQuestionIndex + 1) >= widget.session.questions.length;

        if (wasLastQuestion) {
          // Don't increment or rebuild - just submit answers
          _submitAnswers();
        } else {
          // Move to next question
          setState(() {
            _currentQuestionIndex++;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _cardAnimationController.dispose();
    super.dispose();
  }

  Future<void> _handleAnswer(bool answerValue) async {
    if (_isSubmitting || _isAnimating) return;

    // Prevent duplicate answers while animation is in progress
    _isAnimating = true;

    final question = widget.session.questions[_currentQuestionIndex];

    final answer = YouOrMeAnswer(
      questionId: question.id,
      questionPrompt: question.prompt,
      questionContent: question.content,
      answerValue: answerValue, // true = "Me", false = "You"
      answeredAt: DateTime.now(),
    );

    _answers.add(answer);
    Logger.info(
      'Answer recorded: ${question.content} -> ${answerValue ? "Me" : "You"}',
      service: 'you_or_me',
    );

    // Animate card out
    await _cardAnimationController.forward();

    // Animation completes, allow next answer
    _isAnimating = false;
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

      // Check if partner has answered
      final updatedSession = await _service.getSession(widget.session.id);
      if (updatedSession == null) {
        throw Exception('Session not found');
      }

      if (updatedSession.areBothUsersAnswered()) {
        // Both answered - go to results
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => YouOrMeResultsScreen(session: updatedSession),
          ),
        );
      } else {
        // Waiting for partner
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
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  String _getUserInitial() {
    final user = _storage.getUser();
    if (user != null && user.name != null && user.name!.isNotEmpty) {
      return user.name![0].toUpperCase();
    }
    return 'M';
  }

  String _getPartnerInitial() {
    final partner = _storage.getPartner();
    if (partner != null && partner.name != null && partner.name!.isNotEmpty) {
      return partner.name![0].toUpperCase();
    }
    return 'P';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final partner = _storage.getPartner();
    final question = widget.session.questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / widget.session.questions.length;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: const Color(0xFFF0F0F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
                      minHeight: 6,
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Question prompt
                        Text(
                          question.prompt,
                          style: const TextStyle(
                            fontFamily: 'Playfair Display',
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: Color(0xFF1A1A1A),
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 16),

                        // Card stack
                        SizedBox(
                          height: 240,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Background cards (stacked effect)
                              if (_currentQuestionIndex + 2 < widget.session.questions.length)
                                _buildBackgroundCard(offset: 16, opacity: 0.3, scale: 0.94),
                              if (_currentQuestionIndex + 1 < widget.session.questions.length)
                                _buildBackgroundCard(offset: 8, opacity: 0.6, scale: 0.97),

                              // Current card with animation
                              SlideTransition(
                                position: _slideAnimation,
                                child: RotationTransition(
                                  turns: _rotateAnimation,
                                  child: FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: _buildQuestionCard(question, _currentQuestionIndex),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Answer section
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFEFD),
                            border: Border.all(color: const Color(0xFFF0F0F0), width: 2),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // "Me" button (true)
                              _buildAnswerButton(
                                label: _getUserInitial(),
                                onPressed: () => _handleAnswer(true),
                                isInitial: true,
                              ),
                              const SizedBox(width: 20),
                              const Text(
                                'or',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFAAAAAA),
                                ),
                              ),
                              const SizedBox(width: 20),
                              // "You" button (false)
                              _buildAnswerButton(
                                label: _getPartnerInitial(),
                                onPressed: () => _handleAnswer(false),
                                isInitial: true,
                              ),
                            ],
                          ),
                        ),
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
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(YouOrMeQuestion question, int index) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFD),
        border: Border.all(color: const Color(0xFFF0F0F0), width: 2),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Question ${index + 1} of ${widget.session.questions.length}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6E6E6E),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            question.content,
            style: const TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              color: Color(0xFF1A1A1A),
              height: 1.2,
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
            decoration: BoxDecoration(
              color: const Color(0xFFFFFEFD),
              border: Border.all(color: const Color(0xFFE0E0E0), width: 2),
              borderRadius: BorderRadius.circular(24),
            ),
            height: 320,
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerButton({
    required String label,
    required VoidCallback onPressed,
    required bool isInitial,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF1A1A1A), width: 2.5),
          color: const Color(0xFFFFFEFD),
        ),
        child: Center(
          child: isInitial
              ? Text(
                  label,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Your',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'partner',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

}

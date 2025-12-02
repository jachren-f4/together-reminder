import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../models/word_search.dart';
import '../services/celebration_service.dart';
import '../config/brand/brand_loader.dart';

/// Completion screen for Word Search game
///
/// Shows winner, final scores, and celebratory confetti
/// Design matches LinkedCompletionScreen
class WordSearchCompletionScreen extends StatefulWidget {
  final WordSearchMatch match;
  final String currentUserId;
  final String? partnerName;

  const WordSearchCompletionScreen({
    super.key,
    required this.match,
    required this.currentUserId,
    this.partnerName,
  });

  @override
  State<WordSearchCompletionScreen> createState() =>
      _WordSearchCompletionScreenState();
}

class _WordSearchCompletionScreenState extends State<WordSearchCompletionScreen>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _animationController;
  late Animation<double> _badgeAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _badgeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    // Start animations with celebration sound and haptic
    _animationController.forward();
    CelebrationService().celebrate(
      CelebrationType.questComplete,
      confettiController: _confettiController,
    );

    // LP is now server-authoritative - awarded via awardLP() in word-search/submit route
    // LP sync happens before navigation to this screen (in word_search_game_screen.dart)
    // No local awardPoints() needed (would cause double-counting)
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  bool get _isPlayer1 => widget.currentUserId == widget.match.player1Id;

  int get _myScore =>
      _isPlayer1 ? widget.match.player1Score : widget.match.player2Score;

  int get _partnerScore =>
      _isPlayer1 ? widget.match.player2Score : widget.match.player1Score;

  bool get _isWinner => _myScore > _partnerScore;

  bool get _isTie => _myScore == _partnerScore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandLoader().colors.surface,
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          // Badge with checkmark
                          _buildBadge(),
                          const SizedBox(height: 32),
                          // Title
                          _buildTitle(),
                          const SizedBox(height: 8),
                          // Subtitle
                          _buildSubtitle(),
                          const SizedBox(height: 48),
                          // Scores section
                          _buildScoresSection(),
                          // Stats row
                          _buildStatsRow(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
                // Bottom action button
                _buildBottomAction(),
              ],
            ),
          ),

          // Confetti overlay via CelebrationService
          CelebrationService().createConfettiWidget(
            _confettiController,
            type: CelebrationType.questComplete,
          ),
        ],
      ),
    );
  }

  Widget _buildBadge() {
    return AnimatedBuilder(
      animation: _badgeAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _badgeAnimation.value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: BrandLoader().colors.textPrimary, width: 4),
            ),
            child: Center(
              child: Text(
                '✓',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  color: BrandLoader().colors.textPrimary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitle() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Text(
        'COMPLETE',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w400,
          letterSpacing: 4,
          color: BrandLoader().colors.textPrimary,
          fontFamily: 'Georgia',
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Text(
        'ALL WORDS FOUND',
        style: TextStyle(
          fontSize: 14,
          letterSpacing: 2,
          color: BrandLoader().colors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildScoresSection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SizedBox(
        width: 280,
        child: Column(
          children: [
            // Winner row first (or tied row)
            if (_isTie) ...[
              _buildScoreRow('You', _myScore, isTied: true),
              _buildScoreRow(
                  widget.partnerName ?? 'Partner', _partnerScore, isTied: true),
            ] else if (_isWinner) ...[
              _buildScoreRow('You', _myScore, isWinner: true),
              _buildScoreRow(widget.partnerName ?? 'Partner', _partnerScore),
            ] else ...[
              _buildScoreRow(widget.partnerName ?? 'Partner', _partnerScore,
                  isWinner: true),
              _buildScoreRow('You', _myScore),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow(String label, int score,
      {bool isWinner = false, bool isTied = false}) {
    final isHighlighted = isWinner && !isTied;

    return Container(
      margin: isHighlighted ? const EdgeInsets.symmetric(horizontal: 0) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isHighlighted
            ? BrandLoader().colors.textPrimary
            : Colors.transparent,
        border: isHighlighted
            ? null
            : Border(
                bottom: BorderSide(
                  color: BrandLoader().colors.divider,
                  width: 1,
                ),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  letterSpacing: 1,
                  color: isHighlighted
                      ? BrandLoader().colors.textOnPrimary
                      : BrandLoader().colors.textPrimary,
                ),
              ),
              if (isHighlighted)
                Text(
                  'WINNER',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    color: BrandLoader().colors.textOnPrimary.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
          Row(
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: isHighlighted
                      ? BrandLoader().colors.textOnPrimary
                      : BrandLoader().colors.textPrimary,
                ),
              ),
              Text(
                ' pts',
                style: TextStyle(
                  fontSize: 12,
                  color: isHighlighted
                      ? BrandLoader().colors.textOnPrimary.withValues(alpha: 0.7)
                      : BrandLoader().colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.only(top: 32),
        padding: const EdgeInsets.only(top: 24),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: BrandLoader().colors.textPrimary, width: 2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatItem('12', 'WORDS'),
            const SizedBox(width: 32),
            _buildStatItem('${widget.match.turnNumber}', 'TURNS'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1,
            color: BrandLoader().colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: BrandLoader().colors.textPrimary,
            foregroundColor: BrandLoader().colors.textOnPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
          ),
          child: const Text(
            'BACK TO HOME',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

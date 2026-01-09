import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/linked.dart';
import '../services/storage_service.dart';
import '../services/celebration_service.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/us2_theme.dart';
import '../widgets/brand/brand_widget_factory.dart';

/// Completion screen for Linked game
///
/// Shows winner, final scores, and celebratory confetti
/// Design based on mockups/crossword/completion-v1-fullscreen.html
class LinkedCompletionScreen extends StatefulWidget {
  final LinkedMatch match;
  final String currentUserId;
  final String? partnerName;

  const LinkedCompletionScreen({
    super.key,
    required this.match,
    required this.currentUserId,
    this.partnerName,
  });

  @override
  State<LinkedCompletionScreen> createState() => _LinkedCompletionScreenState();
}

class _LinkedCompletionScreenState extends State<LinkedCompletionScreen>
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

    // Start animations with celebration sounds
    _animationController.forward();
    CelebrationService().celebrate(
      CelebrationType.questComplete,
      confettiController: _confettiController,
    );

    // Clear pending results flag - user is viewing results
    StorageService().clearPendingResultsMatchId('linked');

    // LP is now server-authoritative - awarded via awardLP() in linked/submit route
    // LP sync happens before navigation to this screen (in linked_game_screen.dart)
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
    // Us 2.0 brand uses different styling
    if (BrandWidgetFactory.isUs2) {
      return _buildUs2Screen();
    }

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

          // Confetti overlay using CelebrationService for consistent styling
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
              border: Border.all(color: BrandLoader().colors.textPrimary, width: 4),
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
        'PUZZLE FINISHED',
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
              _buildScoreRow(widget.partnerName ?? 'Partner', _partnerScore, isTied: true),
            ] else if (_isWinner) ...[
              _buildScoreRow('You', _myScore, isWinner: true),
              _buildScoreRow(widget.partnerName ?? 'Partner', _partnerScore),
            ] else ...[
              _buildScoreRow(widget.partnerName ?? 'Partner', _partnerScore, isWinner: true),
              _buildScoreRow('You', _myScore),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow(String label, int score, {bool isWinner = false, bool isTied = false}) {
    final isHighlighted = isWinner && !isTied;

    return Container(
      margin: isHighlighted ? const EdgeInsets.symmetric(horizontal: 0) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isHighlighted ? BrandLoader().colors.textPrimary : Colors.transparent,
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
                  color: isHighlighted ? BrandLoader().colors.textOnPrimary : BrandLoader().colors.textPrimary,
                ),
              ),
              if (isHighlighted)
                Text(
                  'WINNER',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    color: BrandLoader().colors.textOnPrimary.withOpacity(0.7),
                  ),
                ),
            ],
          ),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: isHighlighted ? BrandLoader().colors.textOnPrimary : BrandLoader().colors.textPrimary,
            ),
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
            _buildStatItem('${widget.match.boardState.length}', 'CELLS'),
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

  // ============================================
  // Us 2.0 Brand Styling
  // ============================================

  Widget _buildUs2Screen() {
    return Scaffold(
      body: Stack(
        children: [
          // Main content with gradient background
          Container(
            decoration: const BoxDecoration(gradient: Us2Theme.backgroundGradient),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  _buildUs2Header(),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Score Summary Section
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                            ),
                            child: Column(
                              children: [
                                // Trophy/Badge
                                AnimatedBuilder(
                                  animation: _badgeAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _badgeAnimation.value,
                                      child: Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          gradient: Us2Theme.accentGradient,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Us2Theme.glowPink.withOpacity(0.5),
                                              blurRadius: 30,
                                              spreadRadius: 5,
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Text(
                                            '✓',
                                            style: TextStyle(
                                              fontSize: 48,
                                              fontWeight: FontWeight.w300,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),

                                // Title
                                FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: Text(
                                    'Puzzle Complete!',
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: Us2Theme.textDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Subtitle based on outcome
                                FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: Text(
                                    _getUs2ResultMessage(),
                                    style: GoogleFonts.nunito(
                                      fontSize: 16,
                                      fontStyle: FontStyle.italic,
                                      color: Us2Theme.textMedium,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Scores
                                _buildUs2ScoreCards(),
                                const SizedBox(height: 24),

                                // Stats pills
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildUs2StatPill('${widget.match.turnNumber} turns', false),
                                    const SizedBox(width: 12),
                                    _buildUs2StatPill('+30 LP', true),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // Footer button
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                    ),
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          gradient: Us2Theme.accentGradient,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Us2Theme.glowPink.withOpacity(0.4),
                              blurRadius: 25,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'Return Home',
                            style: GoogleFonts.nunito(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Confetti overlay
          CelebrationService().createConfettiWidget(
            _confettiController,
            type: CelebrationType.questComplete,
          ),
        ],
      ),
    );
  }

  Widget _buildUs2Header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
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
          Text(
            'Crossword Results',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Us2Theme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  String _getUs2ResultMessage() {
    if (_isTie) {
      return "It's a tie! You both solved the same number of clues.";
    } else if (_isWinner) {
      return "You won! Great word skills.";
    } else {
      return "${widget.partnerName ?? 'Partner'} won this round!";
    }
  }

  Widget _buildUs2ScoreCards() {
    final userName = StorageService().getUser()?.name ?? 'You';
    final partnerName = widget.partnerName ?? 'Partner';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // User score
          _buildUs2PlayerScore(
            name: userName,
            score: _myScore,
            isWinner: _isWinner && !_isTie,
          ),
          // Separator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'vs',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: Us2Theme.textMedium,
              ),
            ),
          ),
          // Partner score
          _buildUs2PlayerScore(
            name: partnerName,
            score: _partnerScore,
            isWinner: !_isWinner && !_isTie,
          ),
        ],
      ),
    );
  }

  Widget _buildUs2PlayerScore({
    required String name,
    required int score,
    required bool isWinner,
  }) {
    return Column(
      children: [
        // Score card
        Container(
          width: 100,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: isWinner ? Us2Theme.accentGradient : null,
            color: isWinner ? null : Us2Theme.cream,
            borderRadius: BorderRadius.circular(16),
            border: isWinner ? null : Border.all(color: Colors.black.withOpacity(0.05)),
            boxShadow: isWinner
                ? [
                    BoxShadow(
                      color: Us2Theme.glowPink.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(
                '$score',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: isWinner ? Colors.white : Us2Theme.textDark,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'CLUES',
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: isWinner ? Colors.white.withOpacity(0.8) : Us2Theme.textMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Name
        Text(
          name.length > 10 ? '${name.substring(0, 10)}...' : name,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Us2Theme.textDark,
          ),
        ),
        // Winner badge
        if (isWinner)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              gradient: Us2Theme.accentGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'WINNER',
              style: GoogleFonts.nunito(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUs2StatPill(String text, bool isHighlight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        gradient: isHighlight
            ? const LinearGradient(
                colors: [Us2Theme.cardSalmon, Us2Theme.cardSalmonDark],
              )
            : null,
        color: isHighlight ? null : Us2Theme.cream,
        borderRadius: BorderRadius.circular(20),
        border: isHighlight ? null : Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: isHighlight
            ? [
                BoxShadow(
                  color: Us2Theme.glowPink.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isHighlight ? Colors.white : Us2Theme.textDark,
        ),
      ),
    );
  }
}

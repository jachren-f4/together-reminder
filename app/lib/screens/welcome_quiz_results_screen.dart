import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/logger.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/us2_theme.dart';
import '../services/welcome_quiz_service.dart';
import '../services/storage_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../services/app_bootstrap_service.dart';
import '../widgets/animations/animations.dart';
import '../widgets/editorial/editorial.dart';
import '../widgets/lp_intro_overlay.dart';
import 'onboarding/value_proposition_screen.dart';

/// Results screen for Welcome Quiz.
/// Shows match score and answer breakdown.
///
/// After user taps Continue, shows LP intro overlay on top of this screen.
/// When LP intro is dismissed, navigates to MainScreen.
class WelcomeQuizResultsScreen extends StatefulWidget {
  final WelcomeQuizResults results;

  const WelcomeQuizResultsScreen({
    super.key,
    required this.results,
  });

  @override
  State<WelcomeQuizResultsScreen> createState() =>
      _WelcomeQuizResultsScreenState();
}

class _WelcomeQuizResultsScreenState extends State<WelcomeQuizResultsScreen>
    with DramaticScreenMixin {
  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;
  bool _showLpIntroOverlay = false;
  bool _isProcessing = false;

  @override
  bool get enableConfetti => true;

  @override
  void initState() {
    super.initState();
    // Play celebration sounds
    Future.delayed(const Duration(milliseconds: 500), () {
      HapticService().trigger(HapticType.success);
      SoundService().play(SoundId.confettiBurst);
      triggerConfetti();
    });
  }

  void _continue() async {
    // Prevent double-tap
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    HapticService().trigger(HapticType.light);
    triggerFlash();

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    // Bootstrap before showing LP intro
    await AppBootstrapService.instance.bootstrap();

    if (!mounted) return;

    // Show LP intro overlay on top of this screen
    setState(() {
      _showLpIntroOverlay = true;
    });
  }

  void _onLpIntroDismissed() async {
    if (!mounted) return;

    // Navigate to Value Proposition screen (which handles subscription check and paywall)
    Logger.debug('Navigating to Value Proposition screen after LP intro', service: 'welcome_quiz');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const ValuePropositionScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isUs2) return _buildUs2Screen();

    final user = StorageService().getUser();
    final partner = StorageService().getPartner();
    final userName = user?.name ?? 'You';
    final partnerName = partner?.name ?? 'Partner';

    return wrapWithDramaticEffects(
      Stack(
        children: [
          Scaffold(
        backgroundColor: EditorialStyles.paper,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              AnimatedHeaderDrop(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  decoration: BoxDecoration(
                    border: Border(bottom: EditorialStyles.border),
                  ),
                  child: Column(
                    children: [
                      ShineOverlayWidget(
                        delay: const Duration(milliseconds: 800),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: EditorialStyles.ink,
                          ),
                          child: Text(
                            'QUIZ COMPLETE!',
                            style: EditorialStyles.labelUppercase.copyWith(
                              color: EditorialStyles.paper,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Here's how you two answered",
                        style: EditorialStyles.bodyText.copyWith(
                          color: EditorialStyles.ink.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Match score
              BounceInWidget(
                delay: const Duration(milliseconds: 400),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      ColorFiltered(
                        colorFilter: const ColorFilter.matrix(<double>[
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0, 0, 0, 1, 0,
                        ]),
                        child: const Text(
                          '🎯',
                          style: TextStyle(fontSize: 40),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          // Animated count-up number
                          TweenAnimationBuilder<int>(
                            tween: IntTween(begin: 0, end: widget.results.matchCount),
                            duration: const Duration(milliseconds: 800),
                            builder: (context, value, child) {
                              return Text(
                                '$value',
                                style: EditorialStyles.headline.copyWith(
                                  fontSize: 64,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            },
                          ),
                          Text(
                            ' out of ${widget.results.totalQuestions}',
                            style: EditorialStyles.headlineSmall.copyWith(
                              fontSize: 24,
                              color: EditorialStyles.ink.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'matched!',
                        style: EditorialStyles.headlineSmall.copyWith(
                          color: EditorialStyles.ink.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Question breakdown
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'QUESTION BREAKDOWN',
                        style: EditorialStyles.labelUppercase.copyWith(
                          letterSpacing: 2,
                          color: EditorialStyles.ink.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...widget.results.questions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final result = entry.value;
                        return BounceInWidget(
                          delay: Duration(milliseconds: 600 + (index * 100)),
                          child: _buildQuestionResult(
                            result,
                            userName,
                            partnerName,
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Continue button
              BounceInWidget(
                delay: const Duration(milliseconds: 1200),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: EditorialButton(
                    label: 'Continue',
                    onPressed: _continue,
                    isFullWidth: true,
                    isLoading: _isProcessing,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
          // LP Intro Overlay on top
          if (_showLpIntroOverlay)
            LpIntroOverlay(
              onDismiss: _onLpIntroDismissed,
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionResult(
    WelcomeQuizResult result,
    String userName,
    String partnerName,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: result.isMatch
            ? Border.all(color: EditorialStyles.ink, width: 2)
            : EditorialStyles.fullBorder,
        color: result.isMatch
            ? EditorialStyles.ink.withOpacity(0.05)
            : Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question text with match badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  result.question,
                  style: EditorialStyles.headlineSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
              if (result.isMatch) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: EditorialStyles.ink,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check,
                        size: 12,
                        color: EditorialStyles.paper,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Match!',
                        style: EditorialStyles.labelUppercase.copyWith(
                          color: EditorialStyles.paper,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // Answers
          _buildAnswerRow(userName, result.user1Answer ?? '—'),
          const SizedBox(height: 8),
          _buildAnswerRow(partnerName, result.user2Answer ?? '—'),
        ],
      ),
    );
  }

  Widget _buildAnswerRow(String name, String answer) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            name,
            style: EditorialStyles.bodyText.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: EditorialStyles.ink.withOpacity(0.05),
              border: Border.all(
                color: EditorialStyles.ink.withOpacity(0.1),
              ),
            ),
            child: Text(
              answer,
              style: EditorialStyles.bodyText.copyWith(fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================
  // Us 2.0 Implementation
  // ===========================================

  Widget _buildUs2Screen() {
    final user = StorageService().getUser();
    final partner = StorageService().getPartner();
    final userName = user?.name ?? 'You';
    final partnerName = partner?.name ?? 'Partner';

    return wrapWithDramaticEffects(
      Stack(
        children: [
          Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: Us2Theme.backgroundGradient,
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Header
                    _buildUs2Header(),

                    // Score section
                    _buildUs2ScoreSection(),

                    // Question breakdown (label removed for compactness)
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ...widget.results.questions.asMap().entries.map((entry) {
                              final result = entry.value;
                              return _buildUs2QuestionResult(result, userName, partnerName);
                            }),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),

                    // Continue button
                    _buildUs2Footer(),
                  ],
                ),
              ),
            ),
          ),
          // LP Intro Overlay on top
          if (_showLpIntroOverlay)
            LpIntroOverlay(
              onDismiss: _onLpIntroDismissed,
            ),
        ],
      ),
    );
  }

  Widget _buildUs2Header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          gradient: Us2Theme.accentGradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'QUIZ COMPLETE!',
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildUs2ScoreSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          // Emoji removed - the large score number is enough visual anchor
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: widget.results.matchCount),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, child) {
                  return ShaderMask(
                    shaderCallback: (bounds) => Us2Theme.accentGradient.createShader(bounds),
                    child: Text(
                      '$value',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 72,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              Text(
                ' out of ${widget.results.totalQuestions}',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  color: Us2Theme.textLight,
                ),
              ),
            ],
          ),
          Text(
            'matched!',
            style: GoogleFonts.nunito(
              fontSize: 18,
              color: Us2Theme.textLight,
            ),
          ),
          const SizedBox(height: 3), // Margin below "matched!" to separate from first card
        ],
      ),
    );
  }

  Widget _buildUs2QuestionResult(
    WelcomeQuizResult result,
    String userName,
    String partnerName,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14), // Reduced from 16px
      decoration: BoxDecoration(
        color: result.isMatch
            ? Us2Theme.primaryBrandPink.withOpacity(0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: result.isMatch
            ? Border.all(color: Us2Theme.primaryBrandPink, width: 2)
            : null,
        boxShadow: result.isMatch
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question text with match badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  result.question,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 15, // Slightly reduced
                    fontWeight: FontWeight.w600,
                    color: Us2Theme.textDark,
                    height: 1.3,
                  ),
                ),
              ),
              if (result.isMatch) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: Us2Theme.accentGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check, size: 10, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Match!',
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10), // Reduced from 12px
          // Answers
          _buildUs2AnswerRow(userName, result.user1Answer ?? '—'),
          const SizedBox(height: 6), // Reduced from 8px
          _buildUs2AnswerRow(partnerName, result.user2Answer ?? '—'),
        ],
      ),
    );
  }

  Widget _buildUs2AnswerRow(String name, String answer) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            name,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Us2Theme.textDark,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Reduced from 8px
            decoration: BoxDecoration(
              color: Us2Theme.cream,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              answer,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: Us2Theme.textDark,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUs2Footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: GestureDetector(
        onTap: _isProcessing ? null : _continue,
        child: AnimatedOpacity(
          opacity: _isProcessing ? 0.7 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: Us2Theme.accentGradient,
              borderRadius: BorderRadius.circular(30),
              boxShadow: Us2Theme.buttonGlowShadow,
            ),
            child: Center(
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Continue',
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
    );
  }
}

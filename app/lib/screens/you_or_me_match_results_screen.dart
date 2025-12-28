import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/animation_constants.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/us2_theme.dart';
import '../models/you_or_me_match.dart';
import '../services/storage_service.dart';
import '../services/unlock_service.dart';
import '../widgets/animations/animations.dart';
import '../widgets/editorial/editorial.dart';
import '../widgets/unlock_celebration.dart';

/// Results screen for You-or-Me Match (bulk submission)
///
/// Displays match percentage with question-by-question comparison.
/// Editorial design with clear match/mismatch indicators.
class YouOrMeMatchResultsScreen extends StatefulWidget {
  final YouOrMeMatch match;
  final ServerYouOrMeQuiz? quiz;
  final int myScore;
  final int partnerScore;
  final int? lpEarned;
  final int? matchPercentage;
  final List<String>? userAnswers;
  final List<String>? partnerAnswers;
  final bool fromPendingResults;

  const YouOrMeMatchResultsScreen({
    super.key,
    required this.match,
    this.quiz,
    required this.myScore,
    required this.partnerScore,
    this.lpEarned,
    this.matchPercentage,
    this.userAnswers,
    this.partnerAnswers,
    this.fromPendingResults = false,
  });

  @override
  State<YouOrMeMatchResultsScreen> createState() => _YouOrMeMatchResultsScreenState();
}

class _YouOrMeMatchResultsScreenState extends State<YouOrMeMatchResultsScreen>
    with TickerProviderStateMixin, DramaticScreenMixin {
  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

  @override
  void initState() {
    super.initState();
    // Trigger celebration confetti after a brief delay
    Future.delayed(AnimationConstants.confettiDelay, () {
      if (mounted) triggerConfetti();
    });

    // Always clear pending results flag when viewing results
    // (whether from pending results tap or normal waiting screen flow)
    StorageService().clearPendingResultsMatchId('you_or_me');

    // Check for unlock progression (You or Me → Linked)
    _checkForUnlock();
  }

  Future<void> _checkForUnlock() async {
    final unlockService = UnlockService();
    final result = await unlockService.notifyCompletion(UnlockTrigger.youOrMe);

    if (result != null && result.hasNewUnlocks && mounted) {
      // Show unlock celebration after a brief delay for confetti to settle
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        await UnlockCelebrations.showLinkedUnlocked(context, result.lpAwarded);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isUs2) return _buildUs2Screen();

    final storage = StorageService();
    final user = storage.getUser();
    final partner = storage.getPartner();
    final userName = user?.name ?? 'You';
    final partnerName = partner?.name ?? 'Partner';
    final lp = widget.lpEarned ?? 30;

    // Use server-provided values directly (server is authoritative)
    final totalQuestions = widget.quiz?.totalQuestions ?? 10;
    final displayMatchPercentage = widget.matchPercentage ?? 0;

    // Derive aligned/different counts from server's percentage
    final alignedCount = totalQuestions > 0
        ? ((displayMatchPercentage / 100) * totalQuestions).round()
        : 0;
    final differentCount = totalQuestions - alignedCount;

    return wrapWithDramaticEffects(
      Scaffold(
      backgroundColor: EditorialStyles.paper,
      body: SafeArea(
        child: Column(
          children: [
            // Header with animated drop
            AnimatedHeaderDrop(
              delay: AnimationConstants.headerDropDelay,
              child: EditorialHeaderSimple(
                title: 'You or Me',
                onClose: () => Navigator.of(context).popUntil((route) => route.isFirst),
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Score summary section with bounce entrance
                    BounceInWidget(
                      delay: AnimationConstants.cardEntranceDelay,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                        child: Column(
                          children: [
                            // Aligned/Different counts display (matching quiz style)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Aligned count
                                Column(
                                  children: [
                                    Text(
                                      '$alignedCount',
                                      style: EditorialStyles.scoreLarge.copyWith(
                                        fontSize: 56,
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'ALIGNED',
                                      style: EditorialStyles.labelUppercase,
                                    ),
                                  ],
                                ),
                                // Separator dot
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 28),
                                    child: Text(
                                      '·',
                                      style: TextStyle(
                                        fontSize: 40,
                                        color: EditorialStyles.inkLight,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ),
                                // Different count
                                Column(
                                  children: [
                                    Text(
                                      '$differentCount',
                                      style: EditorialStyles.scoreLarge.copyWith(
                                        fontSize: 56,
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'DIFFERENT',
                                      style: EditorialStyles.labelUppercase,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _getResultDescription(alignedCount, differentCount, totalQuestions),
                              style: EditorialStyles.bodyTextItalic,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),

                            // Stats row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildStatPill('$totalQuestions questions'),
                                const SizedBox(width: 12),
                                _buildStatPill('+$lp LP'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Divider
                    Container(
                      height: 1,
                      color: EditorialStyles.ink.withValues(alpha: 0.15),
                    ),

                    // Answer comparison header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                      child: Text(
                        'ANSWER COMPARISON',
                        style: EditorialStyles.labelUppercase,
                      ),
                    ),

                    // Question-by-question comparison
                    if (widget.quiz != null && widget.quiz!.questions.isNotEmpty &&
                        widget.userAnswers != null && widget.partnerAnswers != null)
                      ...List.generate(widget.quiz!.questions.length, (index) {
                        final question = widget.quiz!.questions[index];
                        final userAnswer = index < widget.userAnswers!.length ? widget.userAnswers![index] : '';
                        final partnerAnswer = index < widget.partnerAnswers!.length ? widget.partnerAnswers![index] : '';
                        // Answers are from each person's perspective: "me" = picked self, "you" = picked other
                        // They're ALIGNED if they picked the SAME person, which means DIFFERENT relative answers:
                        // - you say "you" (partner) + they say "me" (themselves = partner) → same person
                        // - you say "me" (yourself) + they say "you" (you from their view) → same person
                        final isMatch = userAnswer.isNotEmpty && partnerAnswer.isNotEmpty && userAnswer != partnerAnswer;

                        return _buildQuestionComparison(
                          questionNumber: index + 1,
                          prompt: question.prompt,
                          content: question.content,
                          userAnswer: userAnswer,
                          partnerAnswer: partnerAnswer,
                          userName: userName,
                          partnerName: partnerName,
                          isMatch: isMatch,
                        );
                      })
                    else
                      // Fallback when no detailed data available
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Individual scores summary
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                border: EditorialStyles.fullBorder,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildScoreColumn(userName, widget.myScore, totalQuestions),
                                  Container(
                                    width: 1,
                                    height: 60,
                                    color: EditorialStyles.inkLight,
                                  ),
                                  _buildScoreColumn(partnerName, widget.partnerScore, totalQuestions),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: EditorialStyles.paper,
                border: Border(top: EditorialStyles.border),
              ),
              child: EditorialPrimaryButton(
                label: 'Return Home',
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  // ============================================
  // Us 2.0 Brand Implementation
  // ============================================

  Widget _buildUs2Screen() {
    final storage = StorageService();
    final user = storage.getUser();
    final partner = storage.getPartner();
    final userName = user?.name ?? 'You';
    final partnerName = partner?.name ?? 'Partner';
    final lp = widget.lpEarned ?? 30;

    final totalQuestions = widget.quiz?.totalQuestions ?? 10;
    final displayMatchPercentage = widget.matchPercentage ?? 0;
    final alignedCount = totalQuestions > 0
        ? ((displayMatchPercentage / 100) * totalQuestions).round()
        : 0;
    final differentCount = totalQuestions - alignedCount;

    return wrapWithDramaticEffects(
      Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Us2Theme.bgGradientStart,
                Us2Theme.bgGradientEnd,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                _buildUs2Header(),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),

                        // Aligned/Different stats
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildUs2StatPill('$alignedCount', 'Aligned', true),
                            const SizedBox(width: 16),
                            _buildUs2StatPill('$differentCount', 'Different', false),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Description
                        Text(
                          _getResultDescription(alignedCount, differentCount, totalQuestions),
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            color: Us2Theme.textMedium,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 20),

                        // LP earned badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Us2Theme.goldBorder.withValues(alpha: 0.2),
                                Us2Theme.goldBorder.withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Us2Theme.goldBorder.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '💕',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '+$lp LP',
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Us2Theme.goldBorder,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Divider with label
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                color: Us2Theme.textMedium.withValues(alpha: 0.2),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'QUESTION BREAKDOWN',
                                style: GoogleFonts.nunito(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  color: Us2Theme.textMedium,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: Us2Theme.textMedium.withValues(alpha: 0.2),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Question cards
                        if (widget.quiz != null && widget.quiz!.questions.isNotEmpty &&
                            widget.userAnswers != null && widget.partnerAnswers != null)
                          ...List.generate(widget.quiz!.questions.length, (index) {
                            final question = widget.quiz!.questions[index];
                            final userAnswer = index < widget.userAnswers!.length ? widget.userAnswers![index] : '';
                            final partnerAnswer = index < widget.partnerAnswers!.length ? widget.partnerAnswers![index] : '';
                            final isMatch = userAnswer.isNotEmpty && partnerAnswer.isNotEmpty && userAnswer != partnerAnswer;

                            return _buildUs2QuestionCard(
                              questionNumber: index + 1,
                              prompt: question.prompt,
                              content: question.content,
                              userAnswer: userAnswer,
                              partnerAnswer: partnerAnswer,
                              userName: userName,
                              partnerName: partnerName,
                              isMatch: isMatch,
                            );
                          }),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Footer button
                Container(
                  padding: const EdgeInsets.all(20),
                  child: _buildUs2Button(
                    'Return Home',
                    () => Navigator.of(context).popUntil((route) => route.isFirst),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUs2Header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Close button
          GestureDetector(
            onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Us2Theme.primaryBrandPink.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.close,
                color: Us2Theme.textDark,
                size: 20,
              ),
            ),
          ),
          const Spacer(),
          // Title
          Text(
            'Results',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Us2Theme.textDark,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40), // Balance for close button
        ],
      ),
    );
  }

  Widget _buildUs2StatPill(String value, String label, bool isAligned) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAligned
              ? Us2Theme.primaryBrandPink.withValues(alpha: 0.3)
              : Us2Theme.textMedium.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isAligned ? Us2Theme.primaryBrandPink : Colors.black).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: isAligned ? Us2Theme.primaryBrandPink : Us2Theme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Us2Theme.textMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUs2QuestionCard({
    required int questionNumber,
    required String prompt,
    required String content,
    required String userAnswer,
    required String partnerAnswer,
    required String userName,
    required String partnerName,
    required bool isMatch,
  }) {
    String formatAnswer(String answer, String selfName, String otherName) {
      switch (answer.toLowerCase()) {
        case 'me':
        case 'self':
          return selfName;
        case 'you':
        case 'partner':
          return otherName;
        default:
          return answer.isNotEmpty ? answer : '—';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMatch
              ? Us2Theme.primaryBrandPink.withValues(alpha: 0.3)
              : Us2Theme.textMedium.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isMatch
                  ? Us2Theme.primaryBrandPink.withValues(alpha: 0.05)
                  : Us2Theme.cream,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                // Question number
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isMatch
                          ? [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd]
                          : [Us2Theme.textMedium, Us2Theme.textMedium.withValues(alpha: 0.8)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$questionNumber',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Question text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prompt,
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: Us2Theme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        content,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Us2Theme.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                // Match badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: isMatch
                        ? LinearGradient(
                            colors: [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
                          )
                        : null,
                    color: isMatch ? null : Colors.transparent,
                    border: isMatch ? null : Border.all(color: Us2Theme.textMedium.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isMatch ? '✓ ALIGNED' : 'DIFFERENT',
                    style: GoogleFonts.nunito(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: isMatch ? Colors.white : Us2Theme.textMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Answers
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildUs2AnswerRow(
                  label: userName,
                  answer: formatAnswer(userAnswer, userName, partnerName),
                  isUser: true,
                ),
                const SizedBox(height: 8),
                _buildUs2AnswerRow(
                  label: partnerName,
                  answer: formatAnswer(partnerAnswer, partnerName, userName),
                  isUser: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUs2AnswerRow({
    required String label,
    required String answer,
    required bool isUser,
  }) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isUser
                ? Us2Theme.primaryBrandPink.withValues(alpha: 0.1)
                : Us2Theme.gradientAccentEnd.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              label.isNotEmpty ? label[0].toUpperCase() : '?',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isUser ? Us2Theme.primaryBrandPink : Us2Theme.gradientAccentEnd,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${label.length > 12 ? '${label.substring(0, 12)}...' : label} said',
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: Us2Theme.textMedium,
            ),
          ),
        ),
        Text(
          answer,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Us2Theme.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildUs2Button(String label, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Us2Theme.gradientAccentStart,
              Us2Theme.gradientAccentEnd,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Us2Theme.primaryBrandPink.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildStatPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: EditorialStyles.fullBorder,
      ),
      child: Text(
        text,
        style: EditorialStyles.labelUppercaseSmall,
      ),
    );
  }

  Widget _buildQuestionComparison({
    required int questionNumber,
    required String prompt,
    required String content,
    required String userAnswer,
    required String partnerAnswer,
    required String userName,
    required String partnerName,
    required bool isMatch,
  }) {
    // Convert answer codes to display names
    String formatAnswer(String answer, String userName, String partnerName) {
      switch (answer.toLowerCase()) {
        case 'me':
        case 'self':
          return userName;
        case 'you':
        case 'partner':
          return partnerName;
        default:
          return answer.isNotEmpty ? answer : '—';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        border: EditorialStyles.fullBorder,
        color: isMatch
            ? EditorialStyles.ink.withValues(alpha: 0.03)
            : EditorialStyles.paper,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header with match indicator
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: EditorialStyles.border),
            ),
            child: Row(
              children: [
                // Question number
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: EditorialStyles.ink,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$questionNumber',
                      style: TextStyle(
                        color: EditorialStyles.paper,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Question text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prompt,
                        style: EditorialStyles.labelUppercaseSmall.copyWith(
                          color: EditorialStyles.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        content,
                        style: EditorialStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Match indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isMatch ? EditorialStyles.ink : Colors.transparent,
                    border: Border.all(
                      color: EditorialStyles.ink,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isMatch ? 'ALIGNED' : 'DIFF',
                    style: TextStyle(
                      color: isMatch ? EditorialStyles.paper : EditorialStyles.ink,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Answer comparison rows
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildAnswerRow(
                  label: '$userName said',
                  answer: formatAnswer(userAnswer, userName, partnerName),
                  isHighlighted: isMatch,
                ),
                const SizedBox(height: 8),
                _buildAnswerRow(
                  label: '$partnerName said',
                  // Swap names for partner's answer - their "me" means themselves (partnerName),
                  // their "you" means the current user (userName)
                  answer: formatAnswer(partnerAnswer, partnerName, userName),
                  isHighlighted: isMatch,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerRow({
    required String label,
    required String answer,
    required bool isHighlighted,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: EditorialStyles.labelUppercaseSmall.copyWith(
              color: EditorialStyles.inkMuted,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            answer,
            style: EditorialStyles.bodySmall.copyWith(
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreColumn(String name, int score, int total) {
    return Column(
      children: [
        Text(
          name.length > 10 ? '${name.substring(0, 10)}...' : name,
          style: EditorialStyles.labelUppercaseSmall,
        ),
        const SizedBox(height: 8),
        Text(
          '$score/$total',
          style: EditorialStyles.scoreMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'matches',
          style: EditorialStyles.bodySmall.copyWith(
            color: EditorialStyles.inkMuted,
          ),
        ),
      ],
    );
  }

  /// Returns a description based on aligned/different counts
  /// Emphasizes that both alignments and differences are valuable
  String _getResultDescription(int aligned, int different, int total) {
    if (different == 0) {
      return 'You\'re naturally aligned on everything!';
    } else if (aligned == 0) {
      return 'Lots of differences to explore—now you understand each other better!';
    } else if (aligned > different) {
      return 'Mostly aligned, with some interesting differences to discuss.';
    } else if (different > aligned) {
      return 'Different perspectives on most—great insights about each other!';
    } else {
      return 'A balance of shared views and unique perspectives.';
    }
  }
}

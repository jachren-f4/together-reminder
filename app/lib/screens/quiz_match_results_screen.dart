import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/animation_constants.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/us2_theme.dart';
import '../config/quiz_constants.dart';
import '../models/quiz_match.dart';
import '../services/storage_service.dart';
import '../services/unlock_service.dart';
import '../services/quiz_match_service.dart';
import '../widgets/animations/animations.dart';
import '../widgets/editorial/editorial.dart';
import '../widgets/unlock_celebration.dart';

/// Helper to get answer text, handling the fallback option for classic quiz
String _getAnswerText(int answerIndex, List<String> choices) {
  if (answerIndex < 0) return '—';
  if (answerIndex < choices.length) return choices[answerIndex];
  if (answerIndex == kClassicQuizFallbackOptionIndex) {
    return kClassicQuizFallbackOptionText;
  }
  return '—';
}

/// Results screen for Quiz Match (server-centric architecture)
///
/// Displays alignment counts (not percentage) with question-by-question comparison.
/// Editorial design with clear aligned/different indicators.
/// No percentage shown - both alignments and differences are valuable.
///
/// Can be instantiated in two ways:
/// 1. With `match` data (normal flow from waiting screen)
/// 2. With `matchId` + `quizType` (optimistic navigation - fetches data internally)
class QuizMatchResultsScreen extends StatefulWidget {
  /// The match data (optional if matchId is provided)
  final QuizMatch? match;
  final ServerQuiz? quiz;
  final int? matchPercentage;
  final int? lpEarned;
  final bool fromPendingResults;

  /// For optimistic navigation: fetch match data internally
  final String? matchId;
  final String? quizType; // 'classic' or 'affirmation'

  const QuizMatchResultsScreen({
    super.key,
    this.match,
    this.quiz,
    this.matchPercentage,
    this.lpEarned,
    this.fromPendingResults = false,
    this.matchId,
    this.quizType,
  }) : assert(match != null || (matchId != null && quizType != null),
            'Either match or (matchId + quizType) must be provided');

  @override
  State<QuizMatchResultsScreen> createState() => _QuizMatchResultsScreenState();
}

class _QuizMatchResultsScreenState extends State<QuizMatchResultsScreen>
    with TickerProviderStateMixin, DramaticScreenMixin {
  // For optimistic navigation: fetched data
  QuizMatch? _fetchedMatch;
  ServerQuiz? _fetchedQuiz;
  bool _isLoading = false;
  String? _error;

  /// Check if Us 2.0 brand is active
  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

  /// Get the match data (from widget or fetched)
  QuizMatch? get _match => widget.match ?? _fetchedMatch;
  ServerQuiz? get _quiz => widget.quiz ?? _fetchedQuiz;

  @override
  void initState() {
    super.initState();

    // If match not provided, fetch it (optimistic navigation)
    if (widget.match == null && widget.matchId != null) {
      _fetchMatchData();
    } else {
      _onDataReady();
    }
  }

  /// Fetch match data for optimistic navigation
  Future<void> _fetchMatchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final state = await QuizMatchService().pollMatchState(
        widget.matchId!,
        quizType: widget.quizType!,
      );

      if (mounted) {
        if (state.isCompleted) {
          setState(() {
            _fetchedMatch = state.match;
            _fetchedQuiz = state.quiz;
            _isLoading = false;
          });
          _onDataReady();
        } else {
          // Results not ready - clear stale pending flag
          final contentType = '${widget.quizType}_quiz';
          StorageService().clearPendingResultsMatchId(contentType);
          setState(() {
            _error = 'Results not ready yet';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        // Clear stale pending flag on error
        final contentType = '${widget.quizType}_quiz';
        StorageService().clearPendingResultsMatchId(contentType);
        setState(() {
          _error = 'Failed to load results';
          _isLoading = false;
        });
      }
    }
  }

  /// Called when match data is ready (either from widget or fetched)
  void _onDataReady() {
    final match = _match;
    if (match == null) return;

    // Trigger celebration confetti after a brief delay
    Future.delayed(AnimationConstants.confettiDelay, () {
      if (mounted) triggerConfetti();
    });

    // Always clear pending results flag when viewing results
    final contentType = '${match.quizType}_quiz'; // 'classic_quiz' or 'affirmation_quiz'
    StorageService().clearPendingResultsMatchId(contentType);

    // Check for unlock progression (daily quiz → You or Me)
    _checkForUnlock();
  }

  Future<void> _checkForUnlock() async {
    final match = _match;
    if (match == null) return;

    final unlockService = UnlockService();

    // Get the quiz type from the match (classic or affirmation)
    final quizType = match.quizType;

    // Notify server of completion with quiz type
    // Server will track both Classic and Affirmation completion separately
    // and only unlock You or Me when BOTH are completed
    final result = await unlockService.notifyCompletion(
      UnlockTrigger.dailyQuiz,
      quizType: quizType,
    );

    // Check if this user should see the celebration
    // Both partners should see it - tracked per-user in local storage
    final shouldShow = await unlockService.shouldShowYouOrMeCelebration();

    if (shouldShow && mounted) {
      // Show unlock celebration after a brief delay for confetti to settle
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        // Use LP from result if available, otherwise default to 0
        final lpAwarded = result?.lpAwarded ?? 0;
        await UnlockCelebrations.showYouOrMeUnlocked(context, lpAwarded);
        // Mark as seen so this user won't see it again
        await unlockService.markCelebrationSeen('you_or_me');
      }
    }
  }

  String get _title {
    final quizType = widget.quizType ?? _match?.quizType ?? 'classic';
    return quizType == 'affirmation' ? 'Affirmation Quiz' : 'Lighthearted Quiz';
  }

  @override
  Widget build(BuildContext context) {
    // Us 2.0 brand uses different styling
    if (_isUs2) {
      return _buildUs2Screen();
    }

    // Loading state - show spinner (user is already on this screen, not main screen)
    if (_isLoading) {
      return Scaffold(
        backgroundColor: EditorialStyles.paper,
        body: SafeArea(
          child: Column(
            children: [
              EditorialHeader(
                title: _title,
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

    // Error state
    if (_error != null || _match == null) {
      return Scaffold(
        backgroundColor: EditorialStyles.paper,
        body: SafeArea(
          child: Column(
            children: [
              EditorialHeader(
                title: _title,
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error ?? 'Something went wrong'),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final match = _match!;
    final quiz = _quiz;

    final storage = StorageService();
    final user = storage.getUser();
    final partner = storage.getPartner();
    final userName = user?.name ?? 'You';
    final partnerName = partner?.name ?? 'Partner';

    // Use server-provided values directly (server is authoritative)
    final percentage = widget.matchPercentage ?? match.matchPercentage ?? 0;
    final lp = widget.lpEarned ?? 30;

    // Determine which answers belong to whom
    final isPlayer1 = user?.id == match.player1Id;
    final userAnswers = isPlayer1 ? match.player1Answers : match.player2Answers;
    final partnerAnswers = isPlayer1 ? match.player2Answers : match.player1Answers;

    // Calculate aligned/different counts directly from answers
    final totalQuestions = quiz?.questions.length ?? userAnswers.length;
    int alignedCount = 0;
    for (int i = 0; i < totalQuestions && i < userAnswers.length && i < partnerAnswers.length; i++) {
      if (userAnswers[i] == partnerAnswers[i] && userAnswers[i] >= 0) {
        alignedCount++;
      }
    }
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
                title: quiz?.title ?? 'Quiz Results',
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
                            // Aligned/Different counts display
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
                    if (quiz != null && quiz.questions.isNotEmpty)
                      ...List.generate(quiz.questions.length, (index) {
                        final question = quiz.questions[index];
                        final userAnswer = index < userAnswers.length ? userAnswers[index] : -1;
                        final partnerAnswer = index < partnerAnswers.length ? partnerAnswers[index] : -1;
                        final isMatch = userAnswer == partnerAnswer && userAnswer >= 0;

                        return _buildQuestionComparison(
                          questionNumber: index + 1,
                          questionText: question.text,
                          choices: question.choices,
                          userAnswer: userAnswer,
                          partnerAnswer: partnerAnswer,
                          userName: userName,
                          partnerName: partnerName,
                          isMatch: isMatch,
                        );
                      })
                    else
                      // Fallback when no quiz data available
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Detailed comparison not available.',
                          style: EditorialStyles.bodyTextItalic.copyWith(
                            color: EditorialStyles.inkMuted,
                          ),
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
                onPressed: () {
                  print('🏠 Return Home button tapped');
                  print('🏠 Navigator.canPop: ${Navigator.of(context).canPop()}');
                  Navigator.of(context).popUntil((route) {
                    print('🏠 Checking route: ${route.settings.name}, isFirst: ${route.isFirst}');
                    return route.isFirst;
                  });
                  print('🏠 Navigation complete');
                },
              ),
            ),
          ],
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
    required String questionText,
    required List<String> choices,
    required int userAnswer,
    required int partnerAnswer,
    required String userName,
    required String partnerName,
    required bool isMatch,
  }) {
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
                  child: Text(
                    questionText,
                    style: EditorialStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Alignment indicator
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
                  label: userName,
                  answer: _getAnswerText(userAnswer, choices),
                  isHighlighted: isMatch,
                ),
                const SizedBox(height: 8),
                _buildAnswerRow(
                  label: partnerName,
                  answer: _getAnswerText(partnerAnswer, choices),
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
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: EditorialStyles.labelUppercaseSmall.copyWith(
              color: EditorialStyles.inkMuted,
            ),
          ),
        ),
        Expanded(
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

  /// Build Us 2.0 styled results screen
  Widget _buildUs2Screen() {
    // Loading state
    if (_isLoading) {
      return Scaffold(
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
      );
    }

    // Error state
    if (_error != null || _match == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: Us2Theme.backgroundGradient),
          child: SafeArea(
            child: Column(
              children: [
                _buildUs2Header(),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error ?? 'Something went wrong',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            color: Us2Theme.textDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Text(
                            'Go Back',
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Us2Theme.primaryBrandPink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final match = _match!;
    final quiz = _quiz;

    final storage = StorageService();
    final user = storage.getUser();
    final partner = storage.getPartner();
    final userName = user?.name ?? 'You';
    final partnerName = partner?.name ?? 'Partner';

    final lp = widget.lpEarned ?? 30;

    // Determine which answers belong to whom
    final isPlayer1 = user?.id == match.player1Id;
    final userAnswers = isPlayer1 ? match.player1Answers : match.player2Answers;
    final partnerAnswers = isPlayer1 ? match.player2Answers : match.player1Answers;

    // Calculate aligned/different counts
    final totalQuestions = quiz?.questions.length ?? userAnswers.length;
    int alignedCount = 0;
    for (int i = 0; i < totalQuestions && i < userAnswers.length && i < partnerAnswers.length; i++) {
      if (userAnswers[i] == partnerAnswers[i] && userAnswers[i] >= 0) {
        alignedCount++;
      }
    }
    final differentCount = totalQuestions - alignedCount;

    return wrapWithDramaticEffects(
      Scaffold(
        body: Container(
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Score Summary
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                          ),
                          child: Column(
                            children: [
                              // Score numbers
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Aligned
                                  Column(
                                    children: [
                                      Text(
                                        '$alignedCount',
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 56,
                                          fontWeight: FontWeight.w700,
                                          color: Us2Theme.textDark,
                                          height: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'ALIGNED',
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.5,
                                          color: Us2Theme.textMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Separator
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 28),
                                      child: Text(
                                        '·',
                                        style: TextStyle(
                                          fontSize: 40,
                                          color: Us2Theme.beige,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Different
                                  Column(
                                    children: [
                                      Text(
                                        '$differentCount',
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 56,
                                          fontWeight: FontWeight.w700,
                                          color: Us2Theme.textDark,
                                          height: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'DIFFERENT',
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.5,
                                          color: Us2Theme.textMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              // Description
                              Text(
                                _getResultDescription(alignedCount, differentCount, totalQuestions),
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                  color: Us2Theme.textMedium,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              // Stats pills
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildUs2StatPill('$totalQuestions questions', false),
                                  const SizedBox(width: 12),
                                  _buildUs2StatPill('+$lp LP', true),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Divider
                        Container(
                          height: 1,
                          color: Us2Theme.beige,
                        ),

                        // Section header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                          child: Text(
                            'ANSWER COMPARISON',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: Us2Theme.textMedium,
                            ),
                          ),
                        ),

                        // Question comparisons
                        if (quiz != null && quiz.questions.isNotEmpty)
                          ...List.generate(quiz.questions.length, (index) {
                            final question = quiz.questions[index];
                            final userAnswer = index < userAnswers.length ? userAnswers[index] : -1;
                            final partnerAnswer = index < partnerAnswers.length ? partnerAnswers[index] : -1;
                            final isMatch = userAnswer == partnerAnswer && userAnswer >= 0;

                            return _buildUs2QuestionCard(
                              questionNumber: index + 1,
                              questionText: question.text,
                              choices: question.choices,
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

                // Footer
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
      ),
    );
  }

  /// Build Us 2.0 styled header
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
            _quiz?.title ?? 'Quiz Results',
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

  /// Build Us 2.0 styled stat pill
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

  /// Build Us 2.0 styled question comparison card
  Widget _buildUs2QuestionCard({
    required int questionNumber,
    required String questionText,
    required List<String> choices,
    required int userAnswer,
    required int partnerAnswer,
    required String userName,
    required String partnerName,
    required bool isMatch,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isMatch
            ? const Color(0xFFE8F5E9).withOpacity(0.7)
            : Us2Theme.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.black.withOpacity(0.05)),
              ),
            ),
            child: Row(
              children: [
                // Question number
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: isMatch
                        ? const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF388E3C)])
                        : const LinearGradient(colors: [Us2Theme.cardSalmon, Us2Theme.cardSalmonDark]),
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
                const SizedBox(width: 12),
                // Question text
                Expanded(
                  child: Text(
                    questionText,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Us2Theme.textDark,
                      height: 1.4,
                    ),
                  ),
                ),
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isMatch ? const Color(0xFF4CAF50) : Colors.transparent,
                    border: isMatch
                        ? null
                        : Border.all(color: Us2Theme.textMedium),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isMatch ? 'ALIGNED' : 'DIFF',
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
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildUs2AnswerRow(
                  label: userName,
                  answer: _getAnswerText(userAnswer, choices),
                  isHighlighted: isMatch,
                ),
                const SizedBox(height: 10),
                _buildUs2AnswerRow(
                  label: partnerName,
                  answer: _getAnswerText(partnerAnswer, choices),
                  isHighlighted: isMatch,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build Us 2.0 styled answer row
  Widget _buildUs2AnswerRow({
    required String label,
    required String answer,
    required bool isHighlighted,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Us2Theme.textLight,
            ),
          ),
        ),
        Expanded(
          child: Text(
            answer,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
              color: Us2Theme.textDark,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

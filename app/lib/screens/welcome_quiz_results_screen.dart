import 'package:flutter/material.dart';
import '../services/welcome_quiz_service.dart';
import '../services/storage_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../widgets/animations/animations.dart';
import '../widgets/editorial/editorial.dart';
import 'home_screen.dart';

/// Results screen for Welcome Quiz.
/// Shows match score and answer breakdown.
///
/// After user taps Continue, navigates to HomeScreen where LP intro will show.
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

  void _continue() {
    HapticService().trigger(HapticType.light);
    triggerFlash();

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      // Navigate to home screen shell, which will show LP intro overlay
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const HomeScreen(showLpIntro: true),
        ),
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = StorageService().getUser();
    final partner = StorageService().getPartner();
    final userName = user?.name ?? 'You';
    final partnerName = partner?.name ?? 'Partner';

    return wrapWithDramaticEffects(
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
                  ),
                ),
              ),
            ],
          ),
        ),
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
}

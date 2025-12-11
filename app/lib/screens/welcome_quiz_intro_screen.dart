import 'package:flutter/material.dart';
import '../widgets/editorial/editorial.dart';
import '../widgets/animations/animations.dart';
import '../services/storage_service.dart';
import 'welcome_quiz_game_screen.dart';

/// Introduction screen for the Welcome Quiz.
/// Shows "How It Works" box and starts the quiz flow.
///
/// NOTE: LP is NOT introduced here - it's introduced on the home screen
/// after both partners complete the quiz.
class WelcomeQuizIntroScreen extends StatefulWidget {
  const WelcomeQuizIntroScreen({super.key});

  @override
  State<WelcomeQuizIntroScreen> createState() => _WelcomeQuizIntroScreenState();
}

class _WelcomeQuizIntroScreenState extends State<WelcomeQuizIntroScreen>
    with DramaticScreenMixin {
  bool _isLoading = false;

  @override
  bool get enableConfetti => false;

  void _startQuiz() {
    setState(() => _isLoading = true);
    triggerFlash();
    triggerParticlesAt(Offset(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height * 0.7,
    ));

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const WelcomeQuizGameScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final partner = StorageService().getPartner();
    final partnerName = partner?.name ?? 'your partner';

    return wrapWithDramaticEffects(
      PopScope(
        canPop: false,
        child: Scaffold(
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
                            'WELCOME',
                            style: EditorialStyles.labelUppercase.copyWith(
                              color: EditorialStyles.paper,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Welcome Quiz',
                        style: EditorialStyles.headline,
                      ),
                    ],
                  ),
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Heart icon
                      BounceInWidget(
                        delay: const Duration(milliseconds: 400),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            border: EditorialStyles.fullBorder,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: ColorFiltered(
                              colorFilter: const ColorFilter.matrix(<double>[
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0, 0, 0, 1, 0,
                              ]),
                              child: const Text(
                                '💕',
                                style: TextStyle(fontSize: 40),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Subtitle
                      BounceInWidget(
                        delay: const Duration(milliseconds: 600),
                        child: Text(
                          "Let's start with some fun icebreaker questions about your relationship",
                          textAlign: TextAlign.center,
                          style: EditorialStyles.bodyText.copyWith(
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // How It Works box
                      BounceInWidget(
                        delay: const Duration(milliseconds: 800),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: EditorialStyles.fullBorder,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
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
                                      style: TextStyle(fontSize: 24),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'How It Works',
                                    style: EditorialStyles.headlineSmall.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Answer questions separately, then see how your answers compare. Do you really know each other?',
                                style: EditorialStyles.bodyText.copyWith(
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Unlock preview
                      BounceInWidget(
                        delay: const Duration(milliseconds: 1000),
                        child: Text(
                          'Completing this unlocks: Daily Quests',
                          textAlign: TextAlign.center,
                          style: EditorialStyles.labelUppercase.copyWith(
                            color: EditorialStyles.ink.withOpacity(0.6),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Start button
              BounceInWidget(
                delay: const Duration(milliseconds: 1200),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: EditorialButton(
                    label: _isLoading ? 'Starting...' : 'Fill Out Quiz',
                    onPressed: _isLoading ? null : _startQuiz,
                    isFullWidth: true,
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
}

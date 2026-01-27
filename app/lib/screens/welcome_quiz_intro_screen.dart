import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/us2_theme.dart';
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

  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

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
    if (_isUs2) return _buildUs2Screen();

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
                          'Completing this unlocks: Quizzes',
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

  // ===========================================
  // Us 2.0 Implementation
  // ===========================================

  Widget _buildUs2Screen() {
    return wrapWithDramaticEffects(
      PopScope(
        canPop: false,
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: Us2Theme.backgroundGradient,
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  _buildUs2Header(),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),

                          // Hero illustration with interlinked hearts
                          _buildUs2HeroIllustration(),

                          const SizedBox(height: 24),

                          // Subtitle
                          Text(
                            "Let's start with some fun icebreaker questions about your relationship",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              color: Us2Theme.textMedium,
                              height: 1.6,
                            ),
                          ),

                          const SizedBox(height: 32),

                          // How It Works info card
                          _buildUs2InfoCard(),

                          const SizedBox(height: 24),

                          // Unlock preview
                          Text(
                            'COMPLETING THIS UNLOCKS: QUIZZES',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                              color: Us2Theme.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer with button
                  _buildUs2Footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUs2Header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        children: [
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              gradient: Us2Theme.accentGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'WELCOME',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome Quiz',
            style: GoogleFonts.playfairDisplay(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: Us2Theme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUs2HeroIllustration() {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF8F0), Color(0xFFFFE8D8)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Us2Theme.glowPink.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: SvgPicture.asset(
          'assets/brands/us2/images/welcome_quiz_hero.svg',
          width: 100,
          height: 80,
        ),
      ),
    );
  }

  Widget _buildUs2InfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Branded gradient circle with "?" icon (replacing 🎯 emoji)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  gradient: Us2Theme.accentGradient,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'How It Works',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Us2Theme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Answer questions separately, then see how your answers compare. Do you really know each other?',
            style: GoogleFonts.nunito(
              fontSize: 15,
              color: Us2Theme.textMedium,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUs2Footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: GestureDetector(
        onTap: _isLoading ? null : _startQuiz,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: Us2Theme.accentGradient,
            borderRadius: BorderRadius.circular(30),
            boxShadow: Us2Theme.buttonGlowShadow,
          ),
          child: Center(
            child: Text(
              _isLoading ? 'Starting...' : 'Fill Out Quiz',
              style: GoogleFonts.nunito(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

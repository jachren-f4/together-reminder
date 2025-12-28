import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:togetherremind/config/brand/brand_config.dart';
import 'package:togetherremind/config/brand/brand_loader.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';
import 'package:togetherremind/screens/auth_screen.dart';
import 'package:togetherremind/screens/name_entry_screen.dart';
import 'package:togetherremind/theme/app_theme.dart';
import 'package:togetherremind/widgets/newspaper/newspaper_widgets.dart';

/// Splash screen for Liia - "A shared daily ritual"
///
/// Variant D: Newspaper Editorial style matching the app's visual language.
/// Emphasizes ritual positioning with calm, intentional design.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Single fade-in animation under 300ms per spec
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _handleBegin() {
    // New user flow - needs name entry first
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NameEntryScreen(isNewUser: true),
      ),
    );
  }

  void _handleSignIn() {
    // Returning user flow - skip name entry, go directly to email
    // They already have a name from their previous signup
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AuthScreen(isNewUser: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isUs2) return _buildUs2Screen();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: NewspaperColors.primary,
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      offset: Offset(8, 8),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Section
                      _buildHeader(),

                      // Content Section
                      _buildContent(),

                      // Footer Section
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // Us 2.0 Brand Implementation
  // ============================================

  Widget _buildUs2Screen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: Us2Theme.backgroundGradient,
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Logo section
                  _buildUs2Logo(),

                  const SizedBox(height: 12),

                  // Tagline
                  Text(
                    'FOR COUPLES WHO CONNECT',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3,
                      color: Us2Theme.textMedium,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Hearts symbol
                  _buildUs2HeartsSymbol(),

                  const SizedBox(height: 40),

                  // Subtitle
                  Text(
                    'For the small moments that matter',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      color: Us2Theme.textMedium,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(flex: 3),

                  // Buttons section
                  _buildUs2Buttons(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUs2Logo() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Text(
          'Us 2.0',
          style: GoogleFonts.pacifico(
            fontSize: 64,
            color: Colors.white,
            shadows: [
              Shadow(
                blurRadius: 20,
                color: Us2Theme.glowPink.withValues(alpha: 0.8),
              ),
              Shadow(
                blurRadius: 40,
                color: Us2Theme.glowOrange.withValues(alpha: 0.5),
              ),
              Shadow(
                blurRadius: 60,
                color: Us2Theme.glowPink.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
        Positioned(
          top: -8,
          right: -20,
          child: Text(
            '♥',
            style: GoogleFonts.pacifico(
              fontSize: 24,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 10,
                  color: Us2Theme.glowPink.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUs2HeartsSymbol() {
    return SizedBox(
      width: 180,
      height: 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left circle
          Positioned(
            left: 20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.5),
                border: Border.all(
                  color: Us2Theme.gradientAccentStart,
                  width: 3,
                ),
              ),
              child: const Center(
                child: Text('💕', style: TextStyle(fontSize: 32)),
              ),
            ),
          ),
          // Right circle
          Positioned(
            right: 20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.5),
                border: Border.all(
                  color: Us2Theme.gradientAccentEnd,
                  width: 3,
                ),
              ),
              child: const Center(
                child: Text('💖', style: TextStyle(fontSize: 32)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUs2Buttons() {
    return Column(
      children: [
        // Primary button - Get Started
        GestureDetector(
          onTap: _handleBegin,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Us2Theme.glowPink.withValues(alpha: 0.5),
                  blurRadius: 25,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              'Get Started',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Secondary link - Sign in
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account? ',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Us2Theme.textMedium,
              ),
            ),
            GestureDetector(
              onTap: _handleSignIn,
              child: Text(
                'Sign in',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Us2Theme.primaryBrandPink,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: NewspaperColors.primary,
            width: 2,
          ),
        ),
      ),
      child: Column(
        children: [
          // Brand name - LIIA
          Text(
            'LIIA',
            style: AppTheme.headlineFont.copyWith(
              fontSize: 48,
              fontWeight: FontWeight.w400,
              letterSpacing: 6,
              color: NewspaperColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          // Tagline
          Text(
            'A SHARED DAILY RITUAL',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              letterSpacing: 3,
              color: NewspaperColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Abstract symbol - two overlapping circles
          const _OverlappingCirclesSymbol(),
          const SizedBox(height: 40),
          // Supporting copy
          Text(
            'For the small moments that matter',
            textAlign: TextAlign.center,
            style: AppTheme.headlineFont.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              color: NewspaperColors.secondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: NewspaperColors.primary,
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary CTA - Begin
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleBegin,
              style: ElevatedButton.styleFrom(
                backgroundColor: NewspaperColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                  side: BorderSide(
                    color: NewspaperColors.primary,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                'BEGIN',
                style: AppTheme.headlineFont.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 3,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Secondary action - Sign in
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Returning reader?',
                style: AppTheme.headlineFont.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                  color: NewspaperColors.secondary,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _handleSignIn,
                child: Text(
                  'Sign in',
                  style: AppTheme.headlineFont.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: NewspaperColors.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: NewspaperColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Abstract symbol: Two overlapping circles representing togetherness
class _OverlappingCirclesSymbol extends StatelessWidget {
  const _OverlappingCirclesSymbol();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 80,
      child: Stack(
        children: [
          // Left circle
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: NewspaperColors.primary,
                  width: 2,
                ),
              ),
            ),
          ),
          // Right circle
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: NewspaperColors.primary,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

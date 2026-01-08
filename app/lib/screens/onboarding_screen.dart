import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
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

  // Video player for Us 2.0 splash screen
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

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

    // Initialize video for Us 2.0
    if (_isUs2) {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.asset(
      'assets/brands/us2/videos/splash.mp4',
    );

    try {
      await _videoController!.initialize();
      await _videoController!.setLooping(true);
      await _videoController!.setVolume(0);
      await _videoController!.play();
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      // Video failed to load - will show gradient fallback
      debugPrint('Splash video failed to load: $e');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _videoController?.dispose();
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
  // Us 2.0 Brand Implementation - Video Splash
  // ============================================

  Widget _buildUs2Screen() {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video background (or gradient fallback)
          _buildVideoBackground(),

          // Gradient overlay for readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.1),
                  Colors.black.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.4),
                  Colors.black.withValues(alpha: 0.7),
                ],
                stops: const [0.0, 0.3, 0.5, 0.8, 1.0],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 60),

                    // Logo section at top
                    _buildUs2Logo(),

                    const SizedBox(height: 8),

                    // Tagline with enhanced shadow for readability
                    _buildUs2Tagline(),

                    const Spacer(),

                    // Buttons section at bottom
                    _buildUs2Buttons(),

                    const SizedBox(height: 16),

                    // Terms text
                    _buildUs2Terms(),

                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoBackground() {
    if (_isVideoInitialized && _videoController != null) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        ),
      );
    }

    // Fallback gradient while video loads
    return Container(
      decoration: const BoxDecoration(
        gradient: Us2Theme.backgroundGradient,
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
            fontSize: 48,
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
              Shadow(
                blurRadius: 80,
                color: Us2Theme.glowOrange.withValues(alpha: 0.2),
              ),
            ],
          ),
        ),
        Positioned(
          top: -6,
          right: -18,
          child: _AnimatedHeart(),
        ),
      ],
    );
  }

  Widget _buildUs2Tagline() {
    return Text(
      'Grow closer, one moment at a time',
      style: GoogleFonts.playfairDisplay(
        fontSize: 16,
        fontStyle: FontStyle.italic,
        color: Colors.white.withValues(alpha: 0.9),
        shadows: [
          // Dark outline effect (reduced 50%)
          const Shadow(
            offset: Offset(-1.0, -1.0),
            blurRadius: 1,
            color: Colors.black26,
          ),
          const Shadow(
            offset: Offset(1.0, -1.0),
            blurRadius: 1,
            color: Colors.black26,
          ),
          const Shadow(
            offset: Offset(-1.0, 1.0),
            blurRadius: 1,
            color: Colors.black26,
          ),
          const Shadow(
            offset: Offset(1.0, 1.0),
            blurRadius: 1,
            color: Colors.black26,
          ),
          // Soft drop shadow
          const Shadow(
            offset: Offset(0, 2),
            blurRadius: 4,
            color: Colors.black45,
          ),
          // Additional glow for depth
          const Shadow(
            offset: Offset(0, 0),
            blurRadius: 8,
            color: Colors.black26,
          ),
        ],
      ),
      textAlign: TextAlign.center,
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
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Us2Theme.glowPink.withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Us2Theme.glowPink.withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Text(
              'GET STARTED',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Secondary button - Sign in
        GestureDetector(
          onTap: _handleSignIn,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              'I ALREADY HAVE AN ACCOUNT',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUs2Terms() {
    return Text.rich(
      TextSpan(
        style: GoogleFonts.nunito(
          fontSize: 11,
          color: Colors.white.withValues(alpha: 0.6),
          height: 1.5,
        ),
        children: [
          const TextSpan(text: 'By continuing, you agree to our '),
          TextSpan(
            text: 'Terms',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              decoration: TextDecoration.underline,
            ),
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
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

/// Animated pulsing heart for Us 2.0 logo
class _AnimatedHeart extends StatefulWidget {
  @override
  State<_AnimatedHeart> createState() => _AnimatedHeartState();
}

class _AnimatedHeartState extends State<_AnimatedHeart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Text(
        '❤',
        style: GoogleFonts.pacifico(
          fontSize: 16,
          color: Colors.white,
          shadows: [
            Shadow(
              blurRadius: 10,
              color: Us2Theme.glowPink.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }
}

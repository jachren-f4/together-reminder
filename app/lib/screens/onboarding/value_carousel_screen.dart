import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';
import 'package:togetherremind/screens/auth_screen.dart';
import 'package:togetherremind/screens/onboarding/name_birthday_screen.dart';
import 'package:togetherremind/widgets/debug/debug_menu.dart';

/// Screen 01: Value Carousel
///
/// Swipeable carousel with video background showcasing three key benefits.
/// Users can swipe through or tap dots/sides to navigate.
/// "Get Started" button visible on all slides for eager users.
///
/// Mockup: mockups/new-onboarding-flow/01-carousel.html
class ValueCarouselScreen extends StatefulWidget {
  /// When true, runs in preview mode for debug browser
  /// - Navigation goes back to browser instead of real flow
  /// - Shows "PREVIEW MODE" banner
  final bool previewMode;

  const ValueCarouselScreen({
    super.key,
    this.previewMode = false,
  });

  @override
  State<ValueCarouselScreen> createState() => _ValueCarouselScreenState();
}

class _ValueCarouselScreenState extends State<ValueCarouselScreen> {
  // Video controller
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  // Page controller for swipeable carousel
  late PageController _pageController;
  int _currentPage = 0;
  static const int _totalSlides = 3;


  // Slide content - using Large size (34/18) with medium shadows
  static const List<Map<String, dynamic>> _slides = [
    {
      'headline': 'Grow closer, one moment at a time',
      'subheadline':
          'Dedicate a few minutes each day to connect with your partner through quick, fun activities.',
    },
    {
      'headline': 'Play together, stay together',
      'subheadline':
          'Discover each other through quizzes, puzzles, and daily challenges designed for couples.',
    },
    {
      'headline': 'Two hearts, one journey',
      'subheadline':
          'One subscription covers both of you. Share every activity, track your progress together.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializeVideo();
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
        setState(() => _isVideoInitialized = true);
      }
    } catch (e) {
      debugPrint('Video failed to load: $e');
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _goToSlide(int index) {
    final targetIndex = index.clamp(0, _totalSlides - 1);
    _pageController.animateToPage(
      targetIndex,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  void _handleTapNavigation(TapUpDetails details) {
    final width = MediaQuery.of(context).size.width;
    final tapX = details.localPosition.dx;

    // Tap on left third = previous, right third = next, middle = no action
    if (tapX < width * 0.33 && _currentPage > 0) {
      _goToSlide(_currentPage - 1);
    } else if (tapX > width * 0.67 && _currentPage < _totalSlides - 1) {
      _goToSlide(_currentPage + 1);
    }
  }

  void _handleGetStarted() {
    if (widget.previewMode) {
      Navigator.pop(context);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NameBirthdayScreen(),
      ),
    );
  }

  void _handleLogIn() {
    if (widget.previewMode) {
      Navigator.pop(context);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AuthScreen(isNewUser: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video background
          _buildVideoBackground(),

          // Gradient overlay for readability
          _buildGradientOverlay(),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Logo at top, centered
                _buildLogo(),

                // Spacer pushes content to bottom
                const Spacer(),

                // Swipeable carousel
                _buildCarousel(),

                // Bottom content section
                _buildBottomContent(),
              ],
            ),
          ),

          // Preview mode banner
          if (widget.previewMode) _buildPreviewBanner(),
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
    // Fallback gradient if video fails
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2A1B3D),
            Color(0xFF1A1428),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    // Matches mockup CSS gradient exactly
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.30, 0.50, 0.68, 1.0],
          colors: [
            Color.fromRGBO(0, 0, 0, 0.15),
            Color.fromRGBO(0, 0, 0, 0.05),
            Color.fromRGBO(0, 0, 0, 0.10),
            Color.fromRGBO(26, 20, 40, 0.80),
            Color.fromRGBO(26, 20, 40, 0.98),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Padding(
      padding: const EdgeInsets.only(top: 116),
      child: Align(
        alignment: Alignment.topCenter,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Only enable debug menu in debug mode
          onDoubleTap: kDebugMode
              ? () {
                  showDialog(
                    context: context,
                    builder: (context) => const DebugMenu(),
                  );
                }
              : null,
          child: Stack(
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
                      color: Us2Theme.glowPink.withOpacity(0.8),
                    ),
                    Shadow(
                      blurRadius: 40,
                      color: Us2Theme.glowOrange.withOpacity(0.5),
                    ),
                    Shadow(
                      blurRadius: 60,
                      color: Us2Theme.glowPink.withOpacity(0.3),
                    ),
                    Shadow(
                      blurRadius: 80,
                      color: Us2Theme.glowOrange.withOpacity(0.2),
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
          ),
        ),
      ),
    );
  }

  Widget _buildCarousel() {
    return GestureDetector(
      onTapUp: _handleTapNavigation,
      child: SizedBox(
        height: 195, // Balanced to fit text without overflow
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() => _currentPage = index);
          },
          itemCount: _totalSlides,
          itemBuilder: (context, index) => _buildSlide(_slides[index]),
        ),
      ),
    );
  }

  Widget _buildSlide(Map<String, dynamic> slide) {
    // Using Large size (34/18) with medium shadows
    const headlineShadows = [
      Shadow(offset: Offset(0, 2), blurRadius: 4, color: Color.fromRGBO(0, 0, 0, 0.6)),
      Shadow(offset: Offset(0, 4), blurRadius: 10, color: Color.fromRGBO(0, 0, 0, 0.5)),
      Shadow(offset: Offset(0, 6), blurRadius: 20, color: Color.fromRGBO(0, 0, 0, 0.4)),
    ];

    const subheadlineShadows = [
      Shadow(offset: Offset(0, 1), blurRadius: 3, color: Color.fromRGBO(0, 0, 0, 0.6)),
      Shadow(offset: Offset(0, 3), blurRadius: 8, color: Color.fromRGBO(0, 0, 0, 0.5)),
      Shadow(offset: Offset(0, 5), blurRadius: 14, color: Color.fromRGBO(0, 0, 0, 0.4)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Headline with text shadows
          Text(
            slide['headline'] as String,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.3,
              shadows: headlineShadows,
            ),
          ),
          const SizedBox(height: 16),
          // Subheadline with text shadows
          Text(
            slide['subheadline'] as String,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.95),
              height: 1.6,
              shadows: subheadlineShadows,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress dots
          _buildProgressDots(),
          const SizedBox(height: 20),

          // Get Started button (primary)
          _buildPrimaryButton(
            text: 'Get Started',
            onTap: _handleGetStarted,
          ),
          const SizedBox(height: 10),

          // I already have an account (secondary)
          _buildSecondaryButton(
            text: 'I already have an account',
            onTap: _handleLogIn,
          ),
          const SizedBox(height: 12),

          // Terms text
          _buildTermsText(),
        ],
      ),
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalSlides, (index) {
        final isActive = index == _currentPage;
        return GestureDetector(
          onTap: () => _goToSlide(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 48 : 32,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: isActive
                  ? const LinearGradient(
                      colors: [
                        Us2Theme.gradientAccentStart,
                        Us2Theme.gradientAccentEnd,
                      ],
                    )
                  : null,
              color: isActive ? null : Colors.white.withOpacity(0.3),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Us2Theme.gradientAccentStart,
              Us2Theme.gradientAccentEnd,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Us2Theme.gradientAccentStart.withOpacity(0.4),
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          text,
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

  Widget _buildSecondaryButton({
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Text(
              text,
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
      ),
    );
  }

  Widget _buildTermsText() {
    return Text.rich(
      TextSpan(
        style: GoogleFonts.nunito(
          fontSize: 11,
          color: Colors.white.withOpacity(0.6),
          height: 1.5,
          shadows: const [
            Shadow(
              offset: Offset(0, 1),
              blurRadius: 4,
              color: Color.fromRGBO(0, 0, 0, 0.3),
            ),
          ],
        ),
        children: [
          const TextSpan(text: 'By continuing, you agree to our '),
          TextSpan(
            text: 'Terms',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              decoration: TextDecoration.underline,
            ),
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              decoration: TextDecoration.underline,
            ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildPreviewBanner() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'PREVIEW MODE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated pulsing heart for the logo
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
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
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              color: Us2Theme.glowPink.withOpacity(0.7),
              offset: Offset.zero,
            ),
          ],
        ),
        child: SvgPicture.asset(
          'assets/brands/us2/images/heart_icon.svg',
          width: 20,
          height: 20,
        ),
      ),
    );
  }
}

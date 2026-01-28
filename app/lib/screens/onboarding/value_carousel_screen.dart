import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
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

  // Gesture recognizers for Terms/Privacy links
  late TapGestureRecognizer _termsRecognizer;
  late TapGestureRecognizer _privacyRecognizer;


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

    // Initialize tap recognizers for Terms/Privacy links
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _showLegalPopup('terms');
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _showLegalPopup('privacy');
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
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
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

  void _showLegalPopup(String type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _LegalContentScreen(type: type),
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
            recognizer: _termsRecognizer,
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              decoration: TextDecoration.underline,
            ),
            recognizer: _privacyRecognizer,
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

/// Full-screen legal content popup for Terms and Privacy Policy
class _LegalContentScreen extends StatefulWidget {
  final String type; // 'terms' or 'privacy'

  const _LegalContentScreen({required this.type});

  @override
  State<_LegalContentScreen> createState() => _LegalContentScreenState();
}

class _LegalContentScreenState extends State<_LegalContentScreen> {
  late TapGestureRecognizer _contactRecognizer;

  String get _title => widget.type == 'terms' ? 'Terms of Service' : 'Privacy Policy';

  @override
  void initState() {
    super.initState();
    _contactRecognizer = TapGestureRecognizer()
      ..onTap = () async {
        final url = Uri.parse('https://jachren-f4.github.io/together-reminder');
        // Don't use canLaunchUrl - it returns false on Android 11+ due to package visibility
        // Just try to launch directly
        try {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('Failed to launch URL: $e');
        }
      };
  }

  @override
  void dispose() {
    _contactRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D2D2D)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _title,
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2D2D2D),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.type == 'terms' ? _buildTermsContent(context) : _buildPrivacyContent(context),
              ),
            ),
          ),
          // Return button at bottom
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B6B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'Return',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTermsContent(BuildContext context) {
    return [
      _buildSectionTitle('1. Acceptance of Terms'),
      _buildParagraph(
        'By downloading, installing, or using Us 2.0 ("the App"), you agree to be bound by these Terms of Service. '
        'If you do not agree to these terms, please do not use the App.',
      ),
      _buildSectionTitle('2. Description of Service'),
      _buildParagraph(
        'Us 2.0 is a couples relationship app designed to help partners connect through daily activities, '
        'quizzes, games, and shared experiences. The App is intended for use by couples who are 18 years or older.',
      ),
      _buildSectionTitle('3. User Accounts'),
      _buildParagraph(
        'To use the App, you must create an account and pair with your partner. You are responsible for '
        'maintaining the confidentiality of your account and for all activities that occur under your account.',
      ),
      _buildSectionTitle('4. Acceptable Use'),
      _buildParagraph(
        'You agree to use the App only for lawful purposes and in accordance with these Terms. You agree not to:\n'
        '• Use the App in any way that violates applicable laws\n'
        '• Attempt to gain unauthorized access to any part of the App\n'
        '• Interfere with or disrupt the App or servers\n'
        '• Share your account credentials with anyone other than your paired partner',
      ),
      _buildSectionTitle('5. Subscription and Payments'),
      _buildParagraph(
        'Some features of the App require a paid subscription. Subscriptions automatically renew unless '
        'cancelled at least 24 hours before the end of the current period. You can manage your subscription '
        'through your app store account settings.',
      ),
      _buildSectionTitle('6. Intellectual Property'),
      _buildParagraph(
        'The App and its original content, features, and functionality are owned by Us 2.0 and are protected '
        'by international copyright, trademark, and other intellectual property laws.',
      ),
      _buildSectionTitle('7. Termination'),
      _buildParagraph(
        'We may terminate or suspend your account at any time, without prior notice, for conduct that we '
        'believe violates these Terms or is harmful to other users, us, or third parties.',
      ),
      _buildSectionTitle('8. Limitation of Liability'),
      _buildParagraph(
        'The App is provided "as is" without warranties of any kind. We shall not be liable for any indirect, '
        'incidental, special, or consequential damages arising from your use of the App.',
      ),
      _buildSectionTitle('9. Changes to Terms'),
      _buildParagraph(
        'We reserve the right to modify these Terms at any time. We will notify users of significant changes '
        'through the App. Your continued use of the App after changes constitutes acceptance of the new Terms.',
      ),
      _buildSectionTitle('10. Contact Us'),
      _buildContactParagraph(context),
      const SizedBox(height: 16),
      _buildLastUpdated('January 2025'),
    ];
  }

  List<Widget> _buildPrivacyContent(BuildContext context) {
    return [
      _buildSectionTitle('1. Information We Collect'),
      _buildParagraph(
        'We collect information you provide directly, including:\n'
        '• Account information (email, name)\n'
        '• Profile information (anniversary date, preferences)\n'
        '• Activity data (quiz answers, game scores, app usage)\n'
        '• Device information for push notifications',
      ),
      _buildSectionTitle('2. How We Use Your Information'),
      _buildParagraph(
        'We use your information to:\n'
        '• Provide and improve the App experience\n'
        '• Sync data between you and your partner\n'
        '• Send push notifications for pokes and reminders\n'
        '• Generate insights about your relationship\n'
        '• Process subscription payments',
      ),
      _buildSectionTitle('3. Data Sharing'),
      _buildParagraph(
        'Your quiz answers, game results, and activity data are shared only with your paired partner. '
        'We do not sell your personal information to third parties. We may share anonymized, aggregated '
        'data for research or analytics purposes.',
      ),
      _buildSectionTitle('4. Data Security'),
      _buildParagraph(
        'We implement industry-standard security measures to protect your information. Data is encrypted '
        'in transit and at rest. However, no method of transmission over the internet is 100% secure.',
      ),
      _buildSectionTitle('5. Data Retention'),
      _buildParagraph(
        'We retain your data for as long as your account is active. You can request deletion of your '
        'account and associated data at any time through the App settings.',
      ),
      _buildSectionTitle('6. Your Rights'),
      _buildParagraph(
        'You have the right to:\n'
        '• Access your personal data\n'
        '• Correct inaccurate data\n'
        '• Request deletion of your data\n'
        '• Export your data\n'
        '• Opt out of marketing communications',
      ),
      _buildSectionTitle('7. Children\'s Privacy'),
      _buildParagraph(
        'The App is not intended for users under 18 years of age. We do not knowingly collect information '
        'from children under 18.',
      ),
      _buildSectionTitle('8. Third-Party Services'),
      _buildParagraph(
        'The App uses third-party services including:\n'
        '• Firebase (analytics, notifications)\n'
        '• RevenueCat (subscription management)\n'
        '• Supabase (database, authentication)\n\n'
        'These services have their own privacy policies.',
      ),
      _buildSectionTitle('9. Changes to Privacy Policy'),
      _buildParagraph(
        'We may update this Privacy Policy periodically. We will notify you of significant changes '
        'through the App.',
      ),
      _buildSectionTitle('10. Contact Us'),
      _buildContactParagraph(context, isPrivacy: true),
      const SizedBox(height: 16),
      _buildLastUpdated('January 2025'),
    ];
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF2D2D2D),
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: GoogleFonts.nunito(
        fontSize: 14,
        height: 1.6,
        color: const Color(0xFF5A5A5A),
      ),
    );
  }

  Widget _buildLastUpdated(String date) {
    return Text(
      'Last updated: $date',
      style: GoogleFonts.nunito(
        fontSize: 12,
        fontStyle: FontStyle.italic,
        color: const Color(0xFF8A8A8A),
      ),
    );
  }

  Widget _buildContactParagraph(BuildContext context, {bool isPrivacy = false}) {
    final prefix = isPrivacy
        ? 'For privacy-related questions, please '
        : 'If you have questions about these Terms, please ';

    return Text.rich(
      TextSpan(
        style: GoogleFonts.nunito(
          fontSize: 14,
          height: 1.6,
          color: const Color(0xFF5A5A5A),
        ),
        children: [
          TextSpan(text: prefix),
          TextSpan(
            text: 'contact us here',
            style: const TextStyle(
              color: Color(0xFFFF6B6B),
              decoration: TextDecoration.underline,
            ),
            recognizer: _contactRecognizer,
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}

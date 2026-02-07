import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
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
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video background (or gradient fallback)
          // TEMPORARILY DISABLED - Testing if video blocks taps on Terms/Privacy (Issue #54)
          // _buildVideoBackground(),
          const ColoredBox(color: Colors.black), // Simple replacement

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
      // Stack with black behind video prevents flash before first frame renders
      return Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController!.value.size.width,
                height: _videoController!.value.size.height,
                child: VideoPlayer(_videoController!),
              ),
            ),
          ),
        ],
      );
    }

    // Solid black while video loads - matches native splash screen
    return const ColoredBox(color: Colors.black);
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            'Grow closer, one moment at a time',
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
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
    final baseStyle = GoogleFonts.nunito(
      fontSize: 11,
      color: Colors.white.withValues(alpha: 0.6),
      height: 1.5,
    );
    final linkStyle = GoogleFonts.nunito(
      fontSize: 11,
      color: Colors.white.withValues(alpha: 0.8),
      height: 1.5,
      decoration: TextDecoration.underline,
    );

    // GitHub Issue #54: Three different tap handling approaches
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Approach 1: InkWell with Material ancestor for "By continuing" → Terms
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showLegalPopup('terms'),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                'TEST123 - By continuing, you agree to our Terms!',
                style: baseStyle.copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Approach 2: TextButton for "Terms"
            TextButton(
              onPressed: () => _showLegalPopup('terms'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(44, 44), // Minimum tap target per Apple HIG
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Terms', style: linkStyle),
            ),
            Text(' and ', style: baseStyle),
            // Approach 3: Listener with explicit gesture handling for "Privacy Policy"
            Listener(
              onPointerUp: (_) => _showLegalPopup('privacy'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                color: Colors.transparent, // Explicit color for hit testing
                child: Text('Privacy Policy', style: linkStyle),
              ),
            ),
          ],
        ),
      ],
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

/// Animated pulsing illustrated heart for Us 2.0 logo
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
              color: Us2Theme.glowPink.withValues(alpha: 0.7),
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
class _LegalContentScreen extends StatelessWidget {
  final String type; // 'terms' or 'privacy'

  const _LegalContentScreen({required this.type});

  String get _title => type == 'terms' ? 'Terms of Service' : 'Privacy Policy';

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
                children: type == 'terms' ? _buildTermsContent(context) : _buildPrivacyContent(context),
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
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                final url = Uri.parse('https://jachren-f4.github.io/together-reminder');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}

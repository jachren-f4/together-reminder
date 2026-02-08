import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';
import 'package:togetherremind/screens/paywall_screen.dart';
import 'package:togetherremind/screens/already_subscribed_screen.dart';
import 'package:togetherremind/screens/main_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:togetherremind/services/subscription_service.dart';
import 'package:togetherremind/utils/logger.dart';

/// Screen 14: Value Proposition (Benefits Cards)
///
/// Benefits cards grid showcasing app features with game images.
/// Shown AFTER the LP intro overlay (on Welcome Quiz Results),
/// BEFORE the Paywall.
///
/// Mockup: mockups/value-proposition-v2/variant-a-larger.html
class ValuePropositionScreen extends StatefulWidget {
  /// When true, runs in preview mode for debug browser
  final bool previewMode;

  const ValuePropositionScreen({
    super.key,
    this.previewMode = false,
  });

  @override
  State<ValuePropositionScreen> createState() => _ValuePropositionScreenState();
}

class _ValuePropositionScreenState extends State<ValuePropositionScreen> {
  bool _isProcessing = false;

  void _handleGetStarted() async {
    if (widget.previewMode) {
      Navigator.pop(context);
      return;
    }

    // Prevent double-tap
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    // Check subscription status
    final subscriptionService = SubscriptionService();
    Logger.debug('Checking subscription status...', service: 'value_proposition');
    final coupleStatus = await subscriptionService.checkCoupleSubscription();
    final isPremium = subscriptionService.isPremium;

    if (!mounted) return;

    if (coupleStatus?.isActive == true && coupleStatus?.subscribedByMe == false) {
      // Partner already subscribed - show AlreadySubscribedScreen
      Logger.debug('Partner already subscribed - showing AlreadySubscribedScreen', service: 'value_proposition');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => AlreadySubscribedScreen(
            subscriberName: coupleStatus?.subscriberName ?? 'Your partner',
            onContinue: _navigateToMainScreen,
          ),
        ),
        (route) => false,
      );
    } else if (!isPremium) {
      // Show paywall for non-premium users
      Logger.debug('Showing paywall - user is not premium', service: 'value_proposition');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => PaywallScreen(
            onContinue: _navigateToMainScreen,
            allowSkip: false, // Hard paywall - must start trial
          ),
        ),
        (route) => false,
      );
    } else {
      // User already has premium, skip paywall
      Logger.debug('Skipping paywall - user already has premium', service: 'value_proposition');
      _navigateToMainScreen(context);
    }
  }

  static Future<void> _navigateToMainScreen(BuildContext context) async {
    // Mark onboarding as fully completed (used by AuthWrapper on restart)
    await const FlutterSecureStorage().write(
      key: 'onboarding_fully_completed',
      value: 'true',
    );
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const MainScreen(showLpIntro: false),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Us2Theme.bgGradientStart, Us2Theme.bgGradientEnd],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Main content
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 38, 20, 12),
                      child: Column(
                        children: [
                          // Header
                          _buildHeader(),
                          const SizedBox(height: 20),

                          // Benefits grid
                          _buildBenefitsGrid(),
                        ],
                      ),
                    ),
                  ),

                  // Footer
                  _buildFooter(),
                ],
              ),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Us2Theme.gradientAccentStart.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            'WHAT YOU\'LL GET',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: Us2Theme.primaryBrandPink,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Title with gradient "again"
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Us2Theme.textDark,
              height: 1.2,
            ),
            children: [
              const TextSpan(text: 'Small moments that bring you '),
              WidgetSpan(
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Us2Theme.gradientAccentStart,
                      Us2Theme.gradientAccentEnd,
                    ],
                  ).createShader(bounds),
                  child: Text(
                    'closer',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitsGrid() {
    return Column(
      children: [
        // Featured card (full width) - with image
        const _BenefitCard(
          imagePath: 'assets/brands/us2/images/quests/new_classic_quiz.png',
          title: 'Daily conversation starters',
          description:
              'Fun questions that spark meaningful talks and help you learn new things about each other',
          isFeatured: true,
        ),
        const SizedBox(height: 12),

        // Regular cards in 2x2 grid
        Row(
          children: const [
            Expanded(
              child: _BenefitCard(
                imagePath: 'assets/brands/us2/images/quests/new_word_search.png',
                title: 'Fun games',
                description: 'Play together & grow',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _BenefitCard(
                imagePath: 'assets/brands/us2/images/quests/linked.png',
                title: '5 min/day',
                description: 'Small habit, big impact',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(
              child: _BenefitCard(
                imagePath: 'assets/brands/us2/images/quests/new_you_or_me.png',
                title: 'Love Points',
                description: 'Track your journey',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _BenefitCard(
                imagePath: 'assets/brands/us2/images/quests/linked.png',
                title: 'Synced together',
                description: 'Always connected',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      child: GestureDetector(
        onTap: _isProcessing ? null : _handleGetStarted,
        child: AnimatedOpacity(
          opacity: _isProcessing ? 0.7 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
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
                  color: Us2Theme.gradientAccentStart.withValues(alpha: 0.4),
                  blurRadius: 25,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Get Started',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

}

/// Individual benefit card with image or icon
class _BenefitCard extends StatelessWidget {
  final String? imagePath;
  final IconData? icon;
  final String title;
  final String description;
  final bool isFeatured;

  const _BenefitCard({
    this.imagePath,
    this.icon,
    required this.title,
    required this.description,
    this.isFeatured = false,
  }) : assert(imagePath != null || icon != null, 'Either imagePath or icon must be provided');

  @override
  Widget build(BuildContext context) {
    if (isFeatured) {
      return _buildFeaturedCard();
    }
    return _buildRegularCard();
  }

  Widget _buildFeaturedCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Image or Icon
          if (imagePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                imagePath!,
                width: 88,
                height: 88,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Us2Theme.gradientAccentStart.withValues(alpha: 0.12),
                    Us2Theme.gradientAccentEnd.withValues(alpha: 0.12),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Us2Theme.gradientAccentStart,
                    Us2Theme.gradientAccentEnd,
                  ],
                ).createShader(bounds),
                child: Icon(icon, size: 40, color: Colors.white),
              ),
            ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Us2Theme.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: Us2Theme.textMedium,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegularCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Image or Icon
          if (imagePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                imagePath!,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Us2Theme.gradientAccentStart.withValues(alpha: 0.12),
                    Us2Theme.gradientAccentEnd.withValues(alpha: 0.12),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Us2Theme.gradientAccentStart,
                    Us2Theme.gradientAccentEnd,
                  ],
                ).createShader(bounds),
                child: Icon(icon, size: 28, color: Colors.white),
              ),
            ),
          const SizedBox(height: 12),
          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Us2Theme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          // Description
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: Us2Theme.textMedium,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

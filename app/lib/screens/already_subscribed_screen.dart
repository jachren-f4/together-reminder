import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/brand/us2_theme.dart';

/// Screen shown when partner has already subscribed for the couple.
///
/// Displays a success state with:
/// - Animated checkmark icon
/// - "You're All Set!" headline
/// - Partner name who subscribed
/// - Premium active badge
/// - Feature list
/// - "Let's Go!" CTA
///
/// Reference: mockups/paywall/variant4-already-subscribed.html
class AlreadySubscribedScreen extends StatefulWidget {
  /// Name of the partner who subscribed
  final String subscriberName;

  /// Called when user taps "Let's Go!" to continue
  final VoidCallback onContinue;

  const AlreadySubscribedScreen({
    super.key,
    required this.subscriberName,
    required this.onContinue,
  });

  @override
  State<AlreadySubscribedScreen> createState() =>
      _AlreadySubscribedScreenState();
}

class _AlreadySubscribedScreenState extends State<AlreadySubscribedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Pulse animation for the success icon
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Success Icon with pulse animation
                  _buildSuccessIcon(),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    "You're All Set!",
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: Us2Theme.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtitle with partner name
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: widget.subscriberName,
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Us2Theme.primaryBrandPink,
                          ),
                        ),
                        TextSpan(
                          text: ' already subscribed for both of you.',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            color: Us2Theme.textMedium,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Premium Card
                  _buildPremiumCard(),
                  const SizedBox(height: 32),

                  // CTA Button
                  _buildCtaButton(),
                  const SizedBox(height: 16),

                  // Note
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "Subscription is managed by ${widget.subscriberName}. You'll keep access as long as the subscription is active.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: Us2Theme.textLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessIcon() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Us2Theme.primaryBrandPink, Us2Theme.gradientAccentEnd],
              ),
              boxShadow: [
                BoxShadow(
                  color: Us2Theme.glowPink.withValues(alpha: 0.4),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Us2Theme.glowPink.withValues(alpha: 0.2),
                  blurRadius: 60,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '✓',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Premium badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Us2Theme.primaryBrandPink, Us2Theme.gradientAccentEnd],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '★',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'PREMIUM ACTIVE',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            'You have full access to Us 2.0 Premium. Enjoy all features together!',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: Us2Theme.textMedium,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),

          // Features
          _buildFeatureRow('Daily couples quests'),
          _buildFeatureRow('All game modes'),
          _buildFeatureRow('Fresh content weekly'),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '✓',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF4CAF50),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: Us2Theme.textMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCtaButton() {
    return GestureDetector(
      onTap: widget.onContinue,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Us2Theme.primaryBrandPink, Us2Theme.gradientAccentEnd],
          ),
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Us2Theme.glowPink.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Us2Theme.primaryBrandPink.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            "Let's Go! ❤️",
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/brand/us2_theme.dart';
import '../../services/play_mode_service.dart';

/// Upgrade prompt popup shown when phantom partner tries to use
/// features that require two devices (Poke, Steps Together).
///
/// Shows benefits of setting up partner's phone and navigates
/// to PairingScreen when tapped.
class UpgradePromptPopup extends StatelessWidget {
  /// Icon shown at the top of the popup (e.g. Icons.devices, Icons.directions_run)
  final IconData icon;

  /// Title text (e.g. "Poke Taija anytime!")
  final String title;

  /// Description text below the title
  final String description;

  /// Called when user taps the primary "Set Up Phone" button
  final VoidCallback onSetUpPhone;

  /// Called when user taps "Maybe Later"
  final VoidCallback onDismiss;

  const UpgradePromptPopup({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onSetUpPhone,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final partnerName = PlayModeService().partnerName;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: ((scale - 0.85) / 0.15).clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 48,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
              ).createShader(bounds),
              child: Icon(icon, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Us2Theme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              description,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: Us2Theme.textMedium,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Benefits list
            _buildBenefit(Icons.waving_hand, 'Send pokes & reminders'),
            _buildBenefit(Icons.schedule, 'Play quizzes anytime, anywhere'),
            _buildBenefit(Icons.notifications, 'Get notified when results are ready'),
            _buildBenefit(Icons.directions_run, 'Track steps together'),
            const SizedBox(height: 24),

            // Primary button
            GestureDetector(
              onTap: onSetUpPhone,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: Us2Theme.accentGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Us2Theme.glowPink,
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  "Set Up $partnerName's Phone",
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Dismiss button
            GestureDetector(
              onTap: onDismiss,
              child: Text(
                'Maybe Later',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Us2Theme.textLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefit(IconData benefitIcon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
            ).createShader(bounds),
            child: Icon(benefitIcon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: Us2Theme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

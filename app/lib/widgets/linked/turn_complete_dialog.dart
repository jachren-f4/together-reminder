import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/brand/brand_loader.dart';
import '../../config/brand/brand_colors.dart';
import '../../config/brand/brand_config.dart';
import '../../config/brand/brand_typography.dart';
import '../../config/brand/us2_theme.dart';

/// Turn complete dialog for Linked game
///
/// Shows a framed modal when player has placed all their letters
/// and it's now their partner's turn.
///
/// Uses brand colors and typography for easy white-label customization.
class TurnCompleteDialog extends StatelessWidget {
  final String partnerName;
  final VoidCallback onLeave;
  final VoidCallback onStay;

  const TurnCompleteDialog({
    super.key,
    required this.partnerName,
    required this.onLeave,
    required this.onStay,
  });

  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

  @override
  Widget build(BuildContext context) {
    if (_isUs2) return _buildUs2Dialog(context);
    return _buildLiiaDialog(context);
  }

  Widget _buildLiiaDialog(BuildContext context) {
    final colors = BrandLoader().colors;
    final typography = BrandLoader().config.typography;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        color: colors.textPrimary.withOpacity(0.6),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: _buildLiiaCard(colors, typography),
          ),
        ),
      ),
    );
  }

  Widget _buildLiiaCard(BrandColors colors, BrandTypography typography) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: colors.textPrimary, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label
            Text(
              'TURN COMPLETE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: colors.textSecondary,
                fontFamily: typography.bodyFontFamily,
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              'Well done',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                color: colors.textPrimary,
                fontFamily: 'Georgia',
              ),
            ),
            const SizedBox(height: 16),

            // Divider
            Container(
              width: 40,
              height: 1,
              color: colors.textPrimary,
            ),
            const SizedBox(height: 16),

            // Subtitle
            Text(
              'All letters placed.',
              style: TextStyle(
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.5,
                fontFamily: typography.bodyFontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textSecondary,
                  height: 1.5,
                  fontFamily: typography.bodyFontFamily,
                ),
                children: [
                  const TextSpan(text: 'Waiting for '),
                  TextSpan(
                    text: partnerName,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: colors.textPrimary,
                    ),
                  ),
                  const TextSpan(text: ' to continue.'),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Primary button
            GestureDetector(
              onTap: onLeave,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: colors.textPrimary,
                  border: Border.all(color: colors.textPrimary),
                ),
                child: Text(
                  'LEAVE PUZZLE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: colors.textOnPrimary,
                    fontFamily: typography.bodyFontFamily,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Secondary button
            GestureDetector(
              onTap: onStay,
              child: Text(
                'Stay and view',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textSecondary,
                  letterSpacing: 0.5,
                  fontFamily: typography.bodyFontFamily,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUs2Dialog(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        color: Colors.black.withOpacity(0.6),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: _buildUs2Card(),
          ),
        ),
      ),
    );
  }

  Widget _buildUs2Card() {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Us2Theme.cream,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          Text(
            'TURN COMPLETE',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: Us2Theme.textLight,
            ),
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            'Nice work!',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Us2Theme.textDark,
            ),
          ),
          const SizedBox(height: 16),

          // Divider
          Container(
            width: 50,
            height: 2,
            decoration: BoxDecoration(
              gradient: Us2Theme.accentGradient,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 16),

          // Subtitle
          Text(
            'All letters placed.',
            style: GoogleFonts.nunito(
              fontSize: 15,
              color: Us2Theme.textMedium,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.nunito(
                fontSize: 15,
                color: Us2Theme.textMedium,
                height: 1.5,
              ),
              children: [
                const TextSpan(text: 'Waiting for '),
                TextSpan(
                  text: partnerName,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        colors: [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
                      ).createShader(const Rect.fromLTWH(0, 0, 100, 20)),
                  ),
                ),
                const TextSpan(text: ' to continue.'),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Primary button with gradient and glow
          GestureDetector(
            onTap: onLeave,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: Us2Theme.accentGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Us2Theme.glowPink,
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                'LEAVE PUZZLE',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Secondary button
          GestureDetector(
            onTap: onStay,
            child: Text(
              'Stay and view',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Us2Theme.textLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

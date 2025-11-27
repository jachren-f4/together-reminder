import 'package:flutter/material.dart';
import '../../config/brand/brand_loader.dart';
import '../../config/brand/brand_colors.dart';
import '../../config/brand/brand_typography.dart';

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

  @override
  Widget build(BuildContext context) {
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
            child: _buildCard(colors, typography),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BrandColors colors, BrandTypography typography) {
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
}

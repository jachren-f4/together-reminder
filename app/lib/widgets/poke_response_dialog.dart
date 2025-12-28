import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:togetherremind/services/poke_service.dart';
import 'package:togetherremind/services/poke_animation_service.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/theme/app_theme.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/us2_theme.dart';

class PokeResponseDialog extends StatelessWidget {
  final String pokeId;
  final String fromName;
  final String emoji;

  const PokeResponseDialog({
    super.key,
    required this.pokeId,
    required this.fromName,
    required this.emoji,
  });

  Future<void> _sendPokeBack(BuildContext context) async {
    HapticFeedback.mediumImpact();

    // Close dialog
    Navigator.of(context).pop();

    // Show animation
    await PokeAnimationService.showPokeAnimation(
      context,
      type: PokeAnimationType.send,
    );

    // Send poke back
    final success = await PokeService.sendPokeBack(pokeId);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '❤️ Poked back!' : '❌ Failed to poke back'),
          backgroundColor: success ? AppTheme.accentGreen : BrandLoader().colors.error,
          duration: const Duration(seconds: 2),
        ),
      );

      // If successful and mutual, show mutual animation
      if (success) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (context.mounted) {
          await PokeAnimationService.showPokeAnimation(
            context,
            type: PokeAnimationType.mutual,
            partnerName: fromName,
          );
        }
      }
    }
  }

  Future<void> _acknowledge(BuildContext context) async {
    HapticFeedback.lightImpact();

    // Update status to acknowledged
    final storage = StorageService();
    final poke = storage.remindersBox.get(pokeId);
    if (poke != null) {
      poke.status = 'acknowledged';
      await poke.save();
    }

    // Close dialog
    if (context.mounted) {
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🙂 Acknowledged'),
          backgroundColor: AppTheme.textSecondary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

  @override
  Widget build(BuildContext context) {
    if (_isUs2) return _buildUs2Dialog(context);
    return _buildLiiaDialog(context);
  }

  Widget _buildLiiaDialog(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 30),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: AppTheme.primaryWhite,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: BrandLoader().colors.textPrimary.withAlpha((0.15 * 255).round()),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 80),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                '$fromName poked you!',
                style: AppTheme.headlineFont.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Subtitle
              Text(
                'How do you want to respond?',
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // Response buttons
              Row(
                children: [
                  Expanded(
                    child: _ResponseButton(
                      emoji: '❤️',
                      label: 'Send Back',
                      onTap: () => _sendPokeBack(context),
                      isPrimary: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ResponseButton(
                      emoji: '🙂',
                      label: 'Smile',
                      onTap: () => _acknowledge(context),
                      isPrimary: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUs2Dialog(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 30),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 60,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji with elastic animation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 80),
                ),
              ),
              const SizedBox(height: 20),

              // Title with gradient partner name
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Us2Theme.textDark,
                  ),
                  children: [
                    TextSpan(
                      text: fromName,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        foreground: Paint()
                          ..shader = const LinearGradient(
                            colors: [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
                          ).createShader(const Rect.fromLTWH(0, 0, 100, 30)),
                      ),
                    ),
                    const TextSpan(text: ' poked you!'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Subtitle
              Text(
                'How do you want to respond?',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  color: Us2Theme.textMedium,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // Response buttons
              Row(
                children: [
                  Expanded(
                    child: _Us2ResponseButton(
                      emoji: '❤️',
                      label: 'Send Back',
                      onTap: () => _sendPokeBack(context),
                      isPrimary: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Us2ResponseButton(
                      emoji: '🙂',
                      label: 'Smile',
                      onTap: () => _acknowledge(context),
                      isPrimary: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponseButton extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ResponseButton({
    required this.emoji,
    required this.label,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.primaryBlack : AppTheme.backgroundGray,
          border: isPrimary ? null : Border.all(color: AppTheme.borderLight, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTheme.bodyFont.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isPrimary ? BrandLoader().colors.textOnPrimary : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Us2ResponseButton extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _Us2ResponseButton({
    required this.emoji,
    required this.label,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: isPrimary ? Us2Theme.accentGradient : null,
          color: isPrimary ? null : Us2Theme.cream,
          border: isPrimary ? null : Border.all(color: Us2Theme.beige, width: 2),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: Us2Theme.glowPink,
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isPrimary ? Colors.white : Us2Theme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

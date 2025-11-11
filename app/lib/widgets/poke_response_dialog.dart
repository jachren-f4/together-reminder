import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:togetherremind/services/poke_service.dart';
import 'package:togetherremind/services/poke_animation_service.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/theme/app_theme.dart';

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
          backgroundColor: success ? AppTheme.accentGreen : Colors.red,
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
        const SnackBar(
          content: Text('🙂 Acknowledged'),
          backgroundColor: AppTheme.textSecondary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                color: Colors.black.withAlpha((0.15 * 255).round()),
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
                color: isPrimary ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

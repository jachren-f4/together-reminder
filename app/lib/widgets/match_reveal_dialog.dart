import 'package:flutter/material.dart';
import 'package:togetherremind/services/memory_flip_service.dart';
import 'package:togetherremind/theme/app_theme.dart';

class MatchRevealDialog extends StatefulWidget {
  final MatchResult matchResult;
  final VoidCallback onDismiss;

  const MatchRevealDialog({
    super.key,
    required this.matchResult,
    required this.onDismiss,
  });

  @override
  State<MatchRevealDialog> createState() => _MatchRevealDialogState();
}

class _MatchRevealDialogState extends State<MatchRevealDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
        backgroundColor: Colors.transparent,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.primaryWhite,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppTheme.accentGreen, width: 3),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Celebration emoji
                const Text(
                  '✨',
                  style: TextStyle(fontSize: 64),
                ),
                const SizedBox(height: 16),

                // "Match Found!" title
                Text(
                  'Match Found!',
                  style: AppTheme.headlineFont.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Matched emoji pair
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildEmojiCard(widget.matchResult.card1.emoji),
                    const SizedBox(width: 12),
                    const Text(
                      '=',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildEmojiCard(widget.matchResult.card2.emoji),
                  ],
                ),
                const SizedBox(height: 24),

                // Quote
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundGray,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderLight, width: 2),
                  ),
                  child: Text(
                    widget.matchResult.quote,
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 15,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),

                // Love Points badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlack,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('💎', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(
                        '+${widget.matchResult.lovePoints}',
                        style: AppTheme.bodyFont.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryWhite,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Partner notification text
                Text(
                  'Your partner will see this too!',
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Tap to dismiss hint
                GestureDetector(
                  onTap: widget.onDismiss,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundGray,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.borderLight, width: 2),
                    ),
                    child: Text(
                      'Tap to continue',
                      style: AppTheme.bodyFont.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiCard(String emoji) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentGreen, width: 2),
      ),
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 48),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:togetherremind/theme/app_theme.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/us2_theme.dart';

class MatchRevealDialog extends StatefulWidget {
  final String emoji;
  final String quote;
  final int lovePoints;
  final VoidCallback onDismiss;

  const MatchRevealDialog({
    super.key,
    required this.emoji,
    required this.quote,
    required this.lovePoints,
    required this.onDismiss,
  });

  @override
  State<MatchRevealDialog> createState() => _MatchRevealDialogState();
}

class _MatchRevealDialogState extends State<MatchRevealDialog>
    with SingleTickerProviderStateMixin {
  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

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
    if (_isUs2) return _buildUs2Dialog();
    return _buildLiiaDialog();
  }

  Widget _buildLiiaDialog() {
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
                    _buildEmojiCard(widget.emoji),
                    const SizedBox(width: 12),
                    Text(
                      '=',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildEmojiCard(widget.emoji),
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
                    widget.quote,
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
                        '+${widget.lovePoints}',
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

  Widget _buildUs2Dialog() {
    const successGreen = Color(0xFF4CAF50);

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
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: successGreen, width: 3),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Celebration emoji with bounce
                const Text(
                  '✨',
                  style: TextStyle(fontSize: 64),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Match Found!',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: Us2Theme.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Matched emoji pair
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildUs2EmojiCard(widget.emoji),
                    const SizedBox(width: 12),
                    Text(
                      '=',
                      style: GoogleFonts.nunito(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Us2Theme.textLight,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildUs2EmojiCard(widget.emoji),
                  ],
                ),
                const SizedBox(height: 24),

                // Quote box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Us2Theme.cream,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Us2Theme.beige, width: 2),
                  ),
                  child: Text(
                    widget.quote,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      color: Us2Theme.textMedium,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),

                // LP badge with gradient
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: Us2Theme.accentGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Us2Theme.glowPink,
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('💎', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(
                        '+${widget.lovePoints}',
                        style: GoogleFonts.nunito(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Partner note
                Text(
                  'Your partner will see this too!',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: Us2Theme.textLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Continue button
                GestureDetector(
                  onTap: widget.onDismiss,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Us2Theme.cream,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Us2Theme.beige, width: 2),
                    ),
                    child: Text(
                      'Tap to continue',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Us2Theme.textMedium,
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

  Widget _buildUs2EmojiCard(String emoji) {
    const successGreen = Color(0xFF4CAF50);
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Us2Theme.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: successGreen, width: 2),
      ),
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 48),
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

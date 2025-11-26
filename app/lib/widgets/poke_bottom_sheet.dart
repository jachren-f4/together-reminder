import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:togetherremind/services/poke_service.dart';
import 'package:togetherremind/services/poke_animation_service.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/theme/app_theme.dart';
import '../config/brand/brand_loader.dart';

class PokeBottomSheet extends StatefulWidget {
  const PokeBottomSheet({super.key});

  @override
  State<PokeBottomSheet> createState() => _PokeBottomSheetState();
}

class _PokeBottomSheetState extends State<PokeBottomSheet>
    with SingleTickerProviderStateMixin {
  String _selectedEmoji = '💫';
  bool _isSending = false;
  late AnimationController _pulseController;
  final StorageService _storage = StorageService();
  int _remainingSeconds = 0;
  bool _isRateLimited = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    // Check rate limit status
    _checkRateLimit();
  }

  void _checkRateLimit() {
    setState(() {
      _isRateLimited = !PokeService.canSendPoke();
      _remainingSeconds = PokeService.getRemainingSeconds();
    });

    if (_isRateLimited) {
      // Start countdown
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _remainingSeconds > 0) {
          _checkRateLimit();
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _sendPoke() async {
    if (_isSending) return;

    // Check rate limit
    if (!PokeService.canSendPoke()) {
      final remaining = PokeService.getRemainingSeconds();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏳ Wait $remaining seconds before poking again'),
          backgroundColor: AppTheme.accentOrange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    // Send poke
    final success = await PokeService.sendPoke(emoji: _selectedEmoji);

    if (mounted) {
      setState(() => _isSending = false);

      if (success) {
        // Close bottom sheet
        Navigator.of(context).pop();

        // Show success animation
        await PokeAnimationService.showPokeAnimation(
          context,
          type: PokeAnimationType.send,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$_selectedEmoji Poke sent!'),
              backgroundColor: AppTheme.accentGreen,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Error feedback
        HapticFeedback.vibrate();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('❌ Failed to send poke. Please try again.'),
            backgroundColor: BrandLoader().colors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final partner = _storage.getPartner();
    final partnerName = partner?.name ?? 'Partner';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: BrandLoader().colors.textPrimary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.1),
                  child: const Text(
                    '💫',
                    style: TextStyle(fontSize: 60),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Send a Poke!',
              style: AppTheme.headlineFont.copyWith(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.backgroundGray,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderLight, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '💕',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    partnerName,
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Poke card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: AppTheme.backgroundGray,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.borderLight, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: BrandLoader().colors.textPrimary.withAlpha((0.06 * 255).round()),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Sparkles decoration
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSparkle(),
                      _buildSparkle(),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Main poke button
                  GestureDetector(
                    onTap: (_isSending || _isRateLimited) ? null : _sendPoke,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_isSending || _isRateLimited)
                            ? AppTheme.textTertiary
                            : AppTheme.primaryBlack,
                        boxShadow: [
                          BoxShadow(
                            color: BrandLoader().colors.textPrimary.withAlpha((0.15 * 255).round()),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isSending)
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                color: BrandLoader().colors.textOnPrimary,
                                strokeWidth: 3,
                              ),
                            )
                          else if (_isRateLimited)
                            Text(
                              '${_remainingSeconds}s',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w700,
                                color: BrandLoader().colors.textOnPrimary,
                              ),
                            )
                          else
                            Text(
                              _selectedEmoji,
                              style: const TextStyle(fontSize: 70),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            _isSending
                                ? 'Sending...'
                                : _isRateLimited
                                    ? 'Wait...'
                                    : 'Poke',
                            style: AppTheme.bodyFont.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: BrandLoader().colors.textOnPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Description
                  Text(
                    'Send an instant "thinking of you" ❤️',
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // LP info
                  Text(
                    'Mutual pokes earn +5 LP',
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Quick emoji selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildEmojiOption('💫'),
                      const SizedBox(width: 12),
                      _buildEmojiOption('❤️'),
                      const SizedBox(width: 12),
                      _buildEmojiOption('👋'),
                      const SizedBox(width: 12),
                      _buildEmojiOption('🫶'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Haptic indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '📳',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Tap for vibration + animation',
                        style: AppTheme.bodyFont.copyWith(
                          fontSize: 13,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),

                  // Sparkles decoration (bottom)
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSparkle(),
                      _buildSparkle(),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiOption(String emoji) {
    final isSelected = _selectedEmoji == emoji;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedEmoji = emoji);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryWhite : AppTheme.backgroundGray,
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlack : AppTheme.borderLight,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildSparkle() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 1500),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.8 + (value * 0.4),
            child: const Text(
              '✨',
              style: TextStyle(fontSize: 24),
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted) {
          setState(() {}); // Restart animation
        }
      },
    );
  }
}

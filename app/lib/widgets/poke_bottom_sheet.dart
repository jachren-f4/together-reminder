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

class _PokeBottomSheetState extends State<PokeBottomSheet> {
  String _selectedEmoji = '💫';
  bool _isSending = false;
  final StorageService _storage = StorageService();
  int _remainingSeconds = 0;
  bool _isRateLimited = false;

  @override
  void initState() {
    super.initState();
    _checkRateLimit();
  }

  void _checkRateLimit() {
    setState(() {
      _isRateLimited = !PokeService.canSendPoke();
      _remainingSeconds = PokeService.getRemainingSeconds();
    });

    if (_isRateLimited) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _remainingSeconds > 0) {
          _checkRateLimit();
        }
      });
    }
  }

  Future<void> _sendPoke() async {
    if (_isSending) return;

    if (!PokeService.canSendPoke()) {
      final remaining = PokeService.getRemainingSeconds();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wait $remaining seconds before poking again'),
          backgroundColor: AppTheme.primaryBlack,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    final success = await PokeService.sendPoke(emoji: _selectedEmoji);

    if (mounted) {
      setState(() => _isSending = false);

      if (success) {
        Navigator.of(context).pop();

        await PokeAnimationService.showPokeAnimation(
          context,
          type: PokeAnimationType.send,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$_selectedEmoji Poke sent!'),
              backgroundColor: AppTheme.primaryBlack,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        HapticFeedback.vibrate();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to send poke. Please try again.'),
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
        border: Border(
          top: BorderSide(color: AppTheme.primaryBlack, width: 2),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Eyebrow text
              Text(
                'QUICK ACTION',
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              // Large emoji
              Text(
                _selectedEmoji,
                style: const TextStyle(fontSize: 80),
              ),
              const SizedBox(height: 20),

              // Title - uppercase serif
              Text(
                'POKE',
                style: AppTheme.headlineFont.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 3,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Recipient - italic
              Text(
                'to $partnerName',
                style: AppTheme.headlineFont.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Divider line
              Container(
                width: 60,
                height: 2,
                color: AppTheme.primaryBlack,
              ),
              const SizedBox(height: 32),

              // Emoji selector row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildEmojiOption('💫'),
                  const SizedBox(width: 16),
                  _buildEmojiOption('❤️'),
                  const SizedBox(width: 16),
                  _buildEmojiOption('👋'),
                  const SizedBox(width: 16),
                  _buildEmojiOption('🫶'),
                ],
              ),
              const SizedBox(height: 32),

              // Send button
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: (_isSending || _isRateLimited) ? null : _sendPoke,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: (_isSending || _isRateLimited)
                          ? AppTheme.textTertiary
                          : AppTheme.primaryBlack,
                      border: Border.all(
                        color: AppTheme.primaryBlack,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: _isSending
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryWhite,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _isRateLimited
                                  ? 'WAIT ${_remainingSeconds}S'
                                  : 'SEND POKE',
                              style: AppTheme.headlineFont.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 2,
                                color: AppTheme.primaryWhite,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Hint text
              Text(
                'Mutual pokes earn +5 Love Points',
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 11,
                  color: AppTheme.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
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
        duration: const Duration(milliseconds: 150),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlack : AppTheme.primaryWhite,
          border: Border.all(
            color: AppTheme.primaryBlack,
            width: 1,
          ),
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
}

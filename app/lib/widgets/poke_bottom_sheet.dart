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

class PokeBottomSheet extends StatefulWidget {
  const PokeBottomSheet({super.key});

  @override
  State<PokeBottomSheet> createState() => _PokeBottomSheetState();
}

class _PokeBottomSheetState extends State<PokeBottomSheet> {
  String _selectedEmoji = '👋';
  bool _isSending = false;
  final StorageService _storage = StorageService();
  int _remainingSeconds = 0;
  bool _isRateLimited = false;
  bool _partnerTokenMissing = false;

  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

  @override
  void initState() {
    super.initState();
    _checkRateLimit();
    _checkPartnerToken();
  }

  void _checkPartnerToken() {
    final partner = _storage.getPartner();
    setState(() {
      _partnerTokenMissing = partner?.pushToken == null || partner!.pushToken!.isEmpty;
    });
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

        // Check if failure was due to missing partner token
        final partner = _storage.getPartner();
        final partnerName = partner?.name ?? 'Partner';
        final isTokenMissing = partner?.pushToken == null || partner!.pushToken!.isEmpty;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isTokenMissing
                  ? 'Ask $partnerName to open the app to receive pokes'
                  : 'Failed to send poke. Please try again.',
            ),
            backgroundColor: isTokenMissing
                ? AppTheme.primaryBlack
                : BrandLoader().colors.error,
            duration: const Duration(seconds: 4),
          ),
        );

        // Update state to show warning
        if (isTokenMissing) {
          setState(() => _partnerTokenMissing = true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isUs2) return _buildUs2Sheet();
    return _buildLiiaSheet();
  }

  Widget _buildLiiaSheet() {
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

              // Partner notification warning
              if (_partnerTokenMissing) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E7),
                    border: Border.all(
                      color: AppTheme.primaryBlack.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('📱', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Ask $partnerName to open the app so they can receive pokes',
                          style: AppTheme.bodyFont.copyWith(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUs2Sheet() {
    final partner = _storage.getPartner();
    final partnerName = partner?.name ?? 'Partner';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Us2Theme.beige,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: Us2Theme.textDark,
                  ),
                  children: [
                    const TextSpan(text: 'Poke '),
                    TextSpan(
                      text: partnerName,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        foreground: Paint()
                          ..shader = const LinearGradient(
                            colors: [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
                          ).createShader(const Rect.fromLTWH(0, 0, 100, 30)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Send a quick reminder you\'re thinking of them',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: Us2Theme.textMedium,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Emoji grid
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: ['👋', '❤️', '😘', '🥰', '😊', '🤗', '💕', '✨']
                    .map((emoji) => _buildUs2EmojiOption(emoji))
                    .toList(),
              ),
              const SizedBox(height: 24),

              // Send button - uses muted gradient when disabled
              GestureDetector(
                onTap: (_isSending || _isRateLimited) ? null : _sendPoke,
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: (_isSending || _isRateLimited)
                          ? [
                              Us2Theme.gradientAccentStart.withValues(alpha: 0.4),
                              Us2Theme.gradientAccentEnd.withValues(alpha: 0.4),
                            ]
                          : [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: (_isSending || _isRateLimited)
                        ? null
                        : [
                            BoxShadow(
                              color: Us2Theme.glowPink,
                              blurRadius: 25,
                              offset: const Offset(0, 8),
                            ),
                          ],
                  ),
                  child: Center(
                    child: _isSending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isRateLimited
                                ? 'Wait ${_remainingSeconds}s'
                                : 'Send Poke $_selectedEmoji',
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Rate limit notice
              Text(
                'You can poke once every 15 minutes',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: Us2Theme.textLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUs2EmojiOption(String emoji) {
    final isSelected = _selectedEmoji == emoji;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedEmoji = emoji);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected ? null : Us2Theme.cream,
          gradient: isSelected ? Us2Theme.accentGradient : null,
          border: Border.all(
            color: isSelected ? Colors.transparent : Us2Theme.beige,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Us2Theme.glowPink,
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 32),
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

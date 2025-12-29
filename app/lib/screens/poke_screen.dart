import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:togetherremind/services/poke_service.dart';
import 'package:togetherremind/services/poke_animation_service.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/theme/app_theme.dart';
import 'package:togetherremind/config/brand/brand_loader.dart';
import 'package:togetherremind/config/brand/brand_config.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';

/// Full-screen Poke tab - one of the main navigation screens
class PokeScreen extends StatefulWidget {
  const PokeScreen({super.key});

  @override
  State<PokeScreen> createState() => _PokeScreenState();
}

class _PokeScreenState extends State<PokeScreen> {
  String _selectedEmoji = '👋';
  bool _isSending = false;
  final StorageService _storage = StorageService();
  int _remainingSeconds = 0;
  bool _isRateLimited = false;

  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

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
        await PokeAnimationService.showPokeAnimation(
          context,
          type: PokeAnimationType.send,
        );

        _checkRateLimit(); // Update rate limit after successful send

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

        final partner = _storage.getPartner();
        final partnerName = partner?.name ?? 'Partner';
        final isTokenMissing =
            partner?.pushToken == null || partner!.pushToken!.isEmpty;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isTokenMissing
                  ? 'Ask $partnerName to open the app to receive pokes'
                  : 'Failed to send poke. Please try again.',
            ),
            backgroundColor:
                isTokenMissing ? AppTheme.primaryBlack : BrandLoader().colors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isUs2 ? _buildUs2Content() : _buildLiiaContent(),
    );
  }

  Widget _buildLiiaContent() {
    final partner = _storage.getPartner();
    final partnerName = partner?.name ?? 'Partner';

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Eyebrow
              Text(
                'QUICK ACTION',
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Large emoji
              Text(_selectedEmoji, style: const TextStyle(fontSize: 100)),
              const SizedBox(height: 24),

              // Title
              Text(
                'POKE',
                style: AppTheme.headlineFont.copyWith(
                  fontSize: 36,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 4,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'to $partnerName',
                style: AppTheme.headlineFont.copyWith(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Send a quick reminder you\'re thinking of them',
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 14,
                  color: AppTheme.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Divider
              Container(width: 60, height: 2, color: AppTheme.primaryBlack),
              const SizedBox(height: 40),

              // Emoji selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ['💫', '❤️', '👋', '🫶']
                    .map((e) => _buildEmojiOption(e))
                    .toList(),
              ),
              const SizedBox(height: 40),

              // Send button
              GestureDetector(
                onTap: (_isSending || _isRateLimited) ? null : _sendPoke,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: (_isSending || _isRateLimited)
                        ? AppTheme.textTertiary
                        : AppTheme.primaryBlack,
                    border: Border.all(color: AppTheme.primaryBlack, width: 1),
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
                              fontSize: 14,
                              letterSpacing: 2,
                              color: AppTheme.primaryWhite,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'You can poke once every 15 minutes',
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUs2Content() {
    final partner = _storage.getPartner();
    final partnerName = partner?.name ?? 'Partner';

    return Container(
      decoration: BoxDecoration(
        gradient: Us2Theme.backgroundGradient,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Large emoji with glow
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Us2Theme.glowPink,
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Text(_selectedEmoji, style: const TextStyle(fontSize: 80)),
                ),
                const SizedBox(height: 32),

                // Title with gradient
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: Us2Theme.textDark,
                    ),
                    children: [
                      const TextSpan(text: 'Poke '),
                      TextSpan(
                        text: partnerName,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: [
                                Us2Theme.gradientAccentStart,
                                Us2Theme.gradientAccentEnd
                              ],
                            ).createShader(const Rect.fromLTWH(0, 0, 150, 40)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Send a quick reminder you\'re thinking of them',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    color: Us2Theme.textMedium,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Emoji grid
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    physics: const NeverScrollableScrollPhysics(),
                    children: ['👋', '❤️', '😘', '🥰', '😊', '🤗', '💕', '✨']
                        .map((emoji) => _buildUs2EmojiOption(emoji))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 32),

                // Send button
                GestureDetector(
                  onTap: (_isSending || _isRateLimited) ? null : _sendPoke,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: (_isSending || _isRateLimited)
                            ? [
                                Us2Theme.gradientAccentStart.withOpacity(0.4),
                                Us2Theme.gradientAccentEnd.withOpacity(0.4),
                              ]
                            : [
                                Us2Theme.gradientAccentStart,
                                Us2Theme.gradientAccentEnd
                              ],
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
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'You can poke once every 15 minutes',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: Us2Theme.textLight,
                  ),
                ),
              ],
            ),
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
          child: Text(emoji, style: const TextStyle(fontSize: 32)),
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
        width: 60,
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlack : AppTheme.primaryWhite,
          border: Border.all(color: AppTheme.primaryBlack, width: 1),
        ),
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 28)),
        ),
      ),
    );
  }
}

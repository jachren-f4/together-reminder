import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/unlock_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../services/quest_initialization_service.dart';
import '../services/storage_service.dart';
import '../widgets/editorial/editorial.dart';
import '../widgets/animations/animations.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/us2_theme.dart';
import '../models/magnet_collection.dart';
import '../widgets/brand/us2/us2_connection_bar.dart';

/// LP Introduction overlay shown on home screen after completing Welcome Quiz.
///
/// Shows animated LP meter filling from 0 to 30 LP.
/// This is the first time users learn about Love Points.
class LpIntroOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final int lpAwarded;

  const LpIntroOverlay({
    super.key,
    required this.onDismiss,
    this.lpAwarded = 30,
  });

  @override
  State<LpIntroOverlay> createState() => _LpIntroOverlayState();
}

class _LpIntroOverlayState extends State<LpIntroOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _meterController;
  late Animation<double> _meterAnimation;
  late AnimationController _badgeController;
  late Animation<double> _badgeAnimation;

  bool _showContent = false;
  bool _isProcessing = false;
  bool _showBadge = false;
  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

  @override
  void initState() {
    super.initState();

    // Fade in animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // LP meter fill animation
    _meterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _meterAnimation = CurvedAnimation(
      parent: _meterController,
      curve: Curves.easeOutCubic,
    );

    // Badge pop-in animation
    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _badgeAnimation = CurvedAnimation(
      parent: _badgeController,
      curve: Curves.elasticOut,
    );

    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _showContent = true);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _meterController.forward();
            HapticService().trigger(HapticType.success);
            SoundService().play(SoundId.success);

            // Show +30 LP badge during meter fill (Us2 only)
            if (_isUs2) {
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) {
                  setState(() => _showBadge = true);
                  _badgeController.forward();

                  // Hide badge after 2.5 seconds
                  Future.delayed(const Duration(milliseconds: 2500), () {
                    if (mounted) {
                      _badgeController.reverse().then((_) {
                        if (mounted) setState(() => _showBadge = false);
                      });
                    }
                  });
                }
              });
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _meterController.dispose();
    _badgeController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    // Prevent double-tap
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    HapticService().trigger(HapticType.light);

    // Mark LP intro as shown on server
    await UnlockService().markLpIntroShown();

    // Ensure daily quests are initialized before revealing home screen
    // This prevents the "No Daily Quests Yet" flash when overlay dismisses
    await _ensureQuestsReady();

    // Fade out
    await _fadeController.reverse();

    if (mounted) {
      widget.onDismiss();
    }
  }

  /// Wait for daily quests to be available in local storage
  /// Either from sync or generation - prevents empty state flash
  Future<void> _ensureQuestsReady() async {
    final storage = StorageService();

    // Check if quests already exist (fast path)
    if (storage.getTodayQuests().isNotEmpty) {
      return;
    }

    // Trigger quest initialization (may already be in progress from HomeScreen)
    final initService = QuestInitializationService();
    await initService.ensureQuestsInitialized();

    // Poll for quests to appear in Hive (max 3 seconds)
    // This handles race condition where quests are being saved by another async task
    for (int i = 0; i < 15; i++) {
      if (storage.getTodayQuests().isNotEmpty) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isUs2) return _buildUs2Overlay(context);
    return _buildLiiaOverlay(context);
  }

  Widget _buildLiiaOverlay(BuildContext context) {
    // Wrap with opaque background that's always visible (prevents home screen flash)
    // Only the content fades in, not the background
    return Material(
      color: Colors.white, // Opaque white background - NO animation
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom -
                    48,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),

                  // Sparkle icon
                  if (_showContent)
                  BounceInWidget(
                    delay: const Duration(milliseconds: 0),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: EditorialStyles.fullBorder,
                      ),
                      child: Center(
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0, 0, 0, 1, 0,
                          ]),
                          child: const Text(
                            '✨',
                            style: TextStyle(fontSize: 36),
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 32),

                // Title
                if (_showContent)
                  BounceInWidget(
                    delay: const Duration(milliseconds: 200),
                    child: Text(
                      'Love Points',
                      style: EditorialStyles.headline.copyWith(
                        fontSize: 32,
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Explanation
                if (_showContent)
                  BounceInWidget(
                    delay: const Duration(milliseconds: 400),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'You just earned your first Love Points! Complete activities together to earn more and track your journey.',
                        textAlign: TextAlign.center,
                        style: EditorialStyles.bodyText.copyWith(
                          height: 1.5,
                          color: EditorialStyles.ink.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 40),

                // Animated LP meter
                if (_showContent)
                  BounceInWidget(
                    delay: const Duration(milliseconds: 600),
                    child: AnimatedBuilder(
                      animation: _meterAnimation,
                      builder: (context, child) {
                        final progress = _meterAnimation.value;
                        final currentLp = (widget.lpAwarded * progress).round();

                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            border: EditorialStyles.fullBorder,
                          ),
                          child: Column(
                            children: [
                              // LP count with +30 badge
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$currentLp',
                                    style: EditorialStyles.headline.copyWith(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'LP',
                                    style: EditorialStyles.headlineSmall.copyWith(
                                      fontSize: 24,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Progress bar
                              Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  border: EditorialStyles.fullBorder,
                                ),
                                child: Stack(
                                  children: [
                                    FractionallySizedBox(
                                      widthFactor: progress * 0.03, // 30 out of ~1000
                                      child: Container(
                                        color: EditorialStyles.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              // +30 LP badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: EditorialStyles.ink,
                                ),
                                child: Text(
                                  '+${widget.lpAwarded} LP',
                                  style: EditorialStyles.labelUppercase.copyWith(
                                    color: EditorialStyles.paper,
                                    letterSpacing: 2,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 40),

                // Got It button
                if (_showContent)
                  BounceInWidget(
                    delay: const Duration(milliseconds: 800),
                    child: EditorialButton(
                      label: 'Got It!',
                      onPressed: _dismiss,
                      isLoading: _isProcessing,
                    ),
                  ),

                const SizedBox(height: 32),
              ],
            ), // Column
            ), // ConstrainedBox
          ), // SingleChildScrollView
        ), // SafeArea
      ), // FadeTransition
    ); // Material
  }

  Widget _buildUs2Overlay(BuildContext context) {
    // Get first destination dynamically from config
    const firstMagnetId = 1;
    final destinationName = MagnetCollection.getMagnetName(firstMagnetId);
    final destinationAsset = MagnetCollection.getMagnetAssetPath(firstMagnetId);
    final lpThreshold = Us2ConnectionBar.getCumulativeLpForMagnet(firstMagnetId);

    return Material(
      // Dark overlay background
      color: Colors.black,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: _showContent
                    ? BounceInWidget(
                        delay: Duration.zero,
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 340),
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Us2Theme.cream,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 40,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Pulsing heart emoji
                              _buildPulsingHeart(),

                              const SizedBox(height: 16),

                              // Title
                              Text(
                                'Love Points',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Us2Theme.textDark,
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Subtitle - mentions destinations
                              Text(
                                'Complete quests together to earn Love Points and unlock romantic destinations!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Us2Theme.textMedium,
                                  height: 1.5,
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Connection bar preview with animation
                              AnimatedBuilder(
                                animation: _meterAnimation,
                                builder: (context, child) {
                                  return _buildUs2JourneyBar(
                                    progress: _meterAnimation.value,
                                    destinationAsset: destinationAsset,
                                    lpThreshold: lpThreshold,
                                  );
                                },
                              ),

                              const SizedBox(height: 16),

                              // First destination hint
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'First stop: ',
                                      style: GoogleFonts.nunito(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        fontStyle: FontStyle.italic,
                                        color: Us2Theme.textLight,
                                      ),
                                    ),
                                    TextSpan(
                                      text: destinationName,
                                      style: GoogleFonts.nunito(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Us2Theme.primaryBrandPink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Let's Go button
                              GestureDetector(
                                onTap: _isProcessing ? null : _dismiss,
                                child: AnimatedOpacity(
                                  opacity: _isProcessing ? 0.7 : 1.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Container(
                                    width: double.infinity,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFF6B6B),
                                          Color(0xFFFF9F43),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(26),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF6B6B).withValues(alpha: 0.4),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: _isProcessing
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                              ),
                                            )
                                          : Text(
                                              "Let's Go!",
                                              style: GoogleFonts.nunito(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPulsingHeart() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 1.1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: const Text(
            '💗',
            style: TextStyle(fontSize: 48),
          ),
        );
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }

  /// Connection bar preview matching the mockup design
  Widget _buildUs2JourneyBar({
    required double progress,
    required String destinationAsset,
    required int lpThreshold,
  }) {
    // Calculate the fill percentage (30 LP out of threshold)
    final fillPercent = (widget.lpAwarded / lpThreshold).clamp(0.0, 1.0) * progress;
    final currentLp = (widget.lpAwarded * progress).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF6B6B),
            Color(0xFFFF9F43),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header label
          Text(
            'YOUR JOURNEY',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),

          const SizedBox(height: 14),

          // Track with destination
          SizedBox(
            height: 50,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackWidth = constraints.maxWidth - 48; // Reserve space for destination
                final heartPosition = trackWidth * fillPercent;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Track background
                    Positioned(
                      left: 0,
                      right: 48,
                      top: 15,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),

                    // Progress fill with glow
                    Positioned(
                      left: 0,
                      top: 15,
                      child: Container(
                        height: 10,
                        width: trackWidth * fillPercent,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFFE066), // Gold start
                              Color(0xFFFFB347), // Gold end
                            ],
                          ),
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFE066).withValues(alpha: 0.6),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Heart indicator
                    Positioned(
                      left: heartPosition - 18,
                      top: -3,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFF6B6B),
                              Color(0xFFFF9F43),
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B6B).withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('💗', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),

                    // +30 LP badge (animated)
                    if (_showBadge)
                      Positioned(
                        left: heartPosition - 10,
                        top: -34,
                        child: AnimatedBuilder(
                          animation: _badgeAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _badgeAnimation.value,
                              child: Opacity(
                                opacity: _badgeAnimation.value.clamp(0.0, 1.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFFE066),
                                        Color(0xFFFFB347),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFFE066).withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '+$currentLp LP',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Us2Theme.textDark,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    // Destination magnet image
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            destinationAsset,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback to emoji
                              return Container(
                                color: const Color(0xFFFF6B6B),
                                child: Center(
                                  child: Text(
                                    Us2ConnectionBar.getMagnetEmoji(1),
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}

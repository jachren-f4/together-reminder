import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../widgets/editorial/editorial.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/us2_theme.dart';

/// Celebration overlay shown when a feature is unlocked.
///
/// Displays:
/// - Full-screen dark overlay
/// - Animated unlock icon with pulse animation
/// - Feature name and description
/// - LP earned (if any)
/// - "Continue" button
class UnlockCelebrationOverlay extends StatefulWidget {
  final String featureName;
  final String featureDescription;
  final int lpEarned;
  final VoidCallback onContinue;

  const UnlockCelebrationOverlay({
    super.key,
    required this.featureName,
    required this.featureDescription,
    required this.lpEarned,
    required this.onContinue,
  });

  /// Show the overlay as a modal dialog
  static Future<void> show(
    BuildContext context, {
    required String featureName,
    required String featureDescription,
    required int lpEarned,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      barrierLabel: 'Unlock Celebration',
      transitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) {
        return UnlockCelebrationOverlay(
          featureName: featureName,
          featureDescription: featureDescription,
          lpEarned: lpEarned,
          onContinue: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  @override
  State<UnlockCelebrationOverlay> createState() =>
      _UnlockCelebrationOverlayState();
}

class _UnlockCelebrationOverlayState extends State<UnlockCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the icon
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_pulseController);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
      ),
    );

    // Start animations - play once, don't repeat (prevents looping/blinking)
    _pulseController.forward();

    // Trigger haptic and sound
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        HapticService().trigger(HapticType.success);
        SoundService().play(SoundId.confettiBurst);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isUs2) return _buildUs2Overlay();
    return _buildLiiaOverlay();
  }

  Widget _buildLiiaOverlay() {
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return SizedBox.expand(
            child: Container(
              // Apply background to entire screen including safe area
              color: Colors.black.withOpacity(0.95 * _fadeAnimation.value),
              child: SafeArea(
                // Keep content in safe area, but background extends edge-to-edge
                child: Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),

                      // Animated unlock icon
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: EditorialStyles.paper,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: EditorialStyles.paper.withOpacity(0.3),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.lock_open,
                            size: 48,
                            color: EditorialStyles.ink,
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Feature name
                      Text(
                        '${widget.featureName} Unlocked!',
                        style: EditorialStyles.headline.copyWith(
                          color: EditorialStyles.paper,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 16),

                      // Description
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          widget.featureDescription,
                          style: EditorialStyles.bodyText.copyWith(
                            color: EditorialStyles.paper.withOpacity(0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // LP earned badge
                      if (widget.lpEarned > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: EditorialStyles.paper,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            '+${widget.lpEarned} LP',
                            style: EditorialStyles.scoreMedium.copyWith(
                              color: EditorialStyles.paper,
                            ),
                          ),
                        ),

                      const Spacer(),

                      // Continue button
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: widget.onContinue,
                            style: TextButton.styleFrom(
                              backgroundColor: EditorialStyles.paper,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                            child: Text(
                              'Continue',
                              style: EditorialStyles.primaryButtonText.copyWith(
                                color: EditorialStyles.ink,
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
            ),
          ),
        );
        },
      ),
    );
  }

  String _getFeatureEmoji() {
    switch (widget.featureName.toLowerCase()) {
      case 'you or me':
        return '🤔';
      case 'linked':
        return '🧩';
      case 'word search':
        return '🔍';
      case 'steps together':
        return '👟';
      default:
        return '✨';
    }
  }

  Widget _buildUs2Overlay() {
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return SizedBox.expand(
            child: Container(
              color: const Color(0xF22D2D2D), // Dark overlay 95% opacity
              child: SafeArea(
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(),

                          // Unlock icon with glow
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Glow effect
                                Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        Us2Theme.glowPink,
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                // Icon
                                const Text(
                                  '🔓',
                                  style: TextStyle(fontSize: 100),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // "NEW FEATURE UNLOCKED" label
                          Text(
                            'NEW FEATURE UNLOCKED',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3,
                              color: Us2Theme.gradientAccentEnd,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Feature name with gradient
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Us2Theme.gradientAccentStart, Us2Theme.gradientAccentEnd],
                            ).createShader(bounds),
                            child: Text(
                              widget.featureName,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Description
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              widget.featureDescription,
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.7),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Feature preview card
                          Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxWidth: 300),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                // Feature icon
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    gradient: Us2Theme.accentGradient,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _getFeatureEmoji(),
                                      style: const TextStyle(fontSize: 28),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Feature info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.featureName,
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'New game unlocked!',
                                        style: GoogleFonts.nunito(
                                          fontSize: 13,
                                          color: Colors.white.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),

                          // Primary button - "Try It Now"
                          GestureDetector(
                            onTap: widget.onContinue,
                            child: Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxWidth: 280),
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: Us2Theme.accentGradient,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Us2Theme.glowPink,
                                    blurRadius: 25,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  'Continue',
                                  style: GoogleFonts.nunito(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Helper to show unlock celebration with common feature configurations
class UnlockCelebrations {
  UnlockCelebrations._();

  static Future<void> showYouOrMeUnlocked(BuildContext context, int lpEarned) {
    return UnlockCelebrationOverlay.show(
      context,
      featureName: 'You or Me',
      featureDescription:
          'A new game mode! Answer questions about each other and see if you agree.',
      lpEarned: lpEarned,
    );
  }

  static Future<void> showLinkedUnlocked(BuildContext context, int lpEarned) {
    return UnlockCelebrationOverlay.show(
      context,
      featureName: 'Crossword',
      featureDescription:
          'Work together to solve word puzzles! Take turns guessing the clues.',
      lpEarned: lpEarned,
    );
  }

  static Future<void> showWordSearchUnlocked(
      BuildContext context, int lpEarned) {
    return UnlockCelebrationOverlay.show(
      context,
      featureName: 'Word Search',
      featureDescription:
          'Find hidden words together in a fun word search puzzle!',
      lpEarned: lpEarned,
    );
  }

  static Future<void> showStepsUnlocked(BuildContext context, int lpEarned) {
    final isUs2 = BrandLoader().config.brand == Brand.us2;
    return UnlockCelebrationOverlay.show(
      context,
      featureName: isUs2 ? 'Steps' : 'Steps Together',
      featureDescription: isUs2
          ? 'Track your daily steps and earn points for staying active!'
          : 'Track your daily steps and earn points for staying active together!',
      lpEarned: lpEarned,
    );
  }
}

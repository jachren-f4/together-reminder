import 'package:flutter/material.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../widgets/editorial/editorial.dart';

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
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => UnlockCelebrationOverlay(
        featureName: featureName,
        featureDescription: featureDescription,
        lpEarned: lpEarned,
        onContinue: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  State<UnlockCelebrationOverlay> createState() =>
      _UnlockCelebrationOverlayState();
}

class _UnlockCelebrationOverlayState extends State<UnlockCelebrationOverlay>
    with SingleTickerProviderStateMixin {
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

    // Start animations
    _pulseController.repeat();

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
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            color: Colors.black.withOpacity(0.95 * _fadeAnimation.value),
            child: SafeArea(
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
      featureName: 'Linked',
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
    return UnlockCelebrationOverlay.show(
      context,
      featureName: 'Steps Together',
      featureDescription:
          'Track your daily steps and earn points for staying active together!',
      lpEarned: lpEarned,
    );
  }
}

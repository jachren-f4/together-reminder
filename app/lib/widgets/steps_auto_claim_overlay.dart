import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../config/brand/us2_theme.dart';
import '../models/steps_data.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';

/// Overlay widget for auto-claim steps celebration.
///
/// Shows when the app launches and there's a claimable steps reward.
/// Two variants:
/// 1. Current user claimed (or will claim) - "Got it!" button
/// 2. Partner already claimed - shows "[Partner] claimed for you both!"
class StepsAutoClaimOverlay extends StatefulWidget {
  /// The steps data for the day being celebrated
  final StepsDay stepsDay;

  /// Whether the current user is the one who claimed (vs partner)
  final bool isCurrentUserClaimer;

  /// Partner's name for display
  final String partnerName;

  /// Current user's name for display
  final String userName;

  /// Called when the overlay should be dismissed
  final VoidCallback onDismiss;

  const StepsAutoClaimOverlay({
    super.key,
    required this.stepsDay,
    required this.isCurrentUserClaimer,
    required this.partnerName,
    required this.userName,
    required this.onDismiss,
  });

  @override
  State<StepsAutoClaimOverlay> createState() => _StepsAutoClaimOverlayState();
}

class _StepsAutoClaimOverlayState extends State<StepsAutoClaimOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();

    // Slide-up animation for the card
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    // Confetti controller
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    // Start animations
    _animationController.forward();
    _confettiController.play();

    // Play celebration sound
    SoundService().play(SoundId.confettiBurst);
    HapticService().trigger(HapticType.success);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    HapticService().tap();
    SoundService().tap();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Dark backdrop
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return GestureDetector(
                onTap: _handleDismiss,
                child: Container(
                  color: Colors.black.withOpacity(0.5 * _fadeAnimation.value),
                ),
              );
            },
          ),

          // Celebration card
          Center(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: _buildCard(),
                  ),
                );
              },
            ),
          ),

          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Us2Theme.gradientAccentStart,
                Us2Theme.gradientAccentEnd,
                Color(0xFF4ECDC4), // Teal
                Color(0xFFFFD700), // Gold
                Colors.white,
              ],
              numberOfParticles: 30,
              maxBlastForce: 20,
              minBlastForce: 5,
              emissionFrequency: 0.05,
              gravity: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      constraints: const BoxConstraints(maxWidth: 340),
      decoration: BoxDecoration(
        color: Us2Theme.cream,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                gradient: Us2Theme.accentGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'STEPS TOGETHER',
                style: TextStyle(
                  fontFamily: Us2Theme.fontBody,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Headline
            Text(
              "Yesterday's Goal\nAchieved!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Us2Theme.fontHeading,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Us2Theme.textDark,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),

            // Step count
            Text(
              _formatNumber(widget.stepsDay.combinedSteps),
              style: TextStyle(
                fontFamily: Us2Theme.fontBody,
                fontSize: 42,
                fontWeight: FontWeight.w700,
                color: Us2Theme.gradientAccentStart,
              ),
            ),
            Text(
              'combined steps',
              style: TextStyle(
                fontFamily: Us2Theme.fontBody,
                fontSize: 14,
                color: Us2Theme.textMedium,
              ),
            ),
            const SizedBox(height: 20),

            // Partner breakdown
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Us2Theme.beige),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatColumn('You', widget.stepsDay.userSteps),
                  const SizedBox(width: 32),
                  _buildStatColumn(widget.partnerName, widget.stepsDay.partnerSteps),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Partner claimed message (if applicable)
            if (!widget.isCurrentUserClaimer) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4ECDC4), Color(0xFF45B7AA)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '✓',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${widget.partnerName} claimed for you both!',
                      style: const TextStyle(
                        fontFamily: Us2Theme.fontBody,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // LP Reward badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB347), Color(0xFFFFD89B)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFB347).withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '💗',
                        style: TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '+${widget.stepsDay.earnedLP} LP',
                        style: TextStyle(
                          fontFamily: Us2Theme.fontHeading,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // "Added" label
                Positioned(
                  bottom: -10,
                  right: -10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ECDC4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ADDED',
                      style: TextStyle(
                        fontFamily: Us2Theme.fontBody,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Dismiss button
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _handleDismiss,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: Us2Theme.accentGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Us2Theme.gradientAccentStart.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.isCurrentUserClaimer ? 'GOT IT!' : 'AWESOME!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: Us2Theme.fontBody,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Hint text
            Text(
              'Your Love Points have been updated',
              style: TextStyle(
                fontFamily: Us2Theme.fontBody,
                fontSize: 12,
                color: Us2Theme.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, int steps) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: Us2Theme.fontBody,
            fontSize: 12,
            color: Us2Theme.textLight,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatNumber(steps),
          style: TextStyle(
            fontFamily: Us2Theme.fontBody,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Us2Theme.textDark,
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return number.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
    }
    return number.toString();
  }
}

/// Shows the steps auto-claim overlay as a dialog.
/// Returns when the user dismisses the overlay.
Future<void> showStepsAutoClaimOverlay({
  required BuildContext context,
  required StepsDay stepsDay,
  required bool isCurrentUserClaimer,
  required String partnerName,
  required String userName,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (context) => StepsAutoClaimOverlay(
      stepsDay: stepsDay,
      isCurrentUserClaimer: isCurrentUserClaimer,
      partnerName: partnerName,
      userName: userName,
      onDismiss: () => Navigator.of(context).pop(),
    ),
  );
}

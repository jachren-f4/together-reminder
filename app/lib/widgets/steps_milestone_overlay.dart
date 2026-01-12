import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../config/brand/us2_theme.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';

/// Celebration overlay shown when crossing a tier threshold.
class StepsMilestoneOverlay extends StatefulWidget {
  final int previousTier; // e.g., 10000
  final int newTier; // e.g., 12000
  final int combinedSteps;
  final int userSteps;
  final int partnerSteps;
  final String partnerName;
  final int previousLP;
  final int newLP;
  final VoidCallback onDismiss;

  const StepsMilestoneOverlay({
    super.key,
    required this.previousTier,
    required this.newTier,
    required this.combinedSteps,
    required this.userSteps,
    required this.partnerSteps,
    required this.partnerName,
    required this.previousLP,
    required this.newLP,
    required this.onDismiss,
  });

  @override
  State<StepsMilestoneOverlay> createState() => _StepsMilestoneOverlayState();
}

class _StepsMilestoneOverlayState extends State<StepsMilestoneOverlay>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    // Start animations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiController.play();
      _animationController.forward();
      HapticService().trigger(HapticType.success);
      SoundService().play(SoundId.confettiBurst);
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String _getTierEmoji() {
    if (widget.newTier >= 20000) return '';
    if (widget.newTier >= 18000) return '';
    if (widget.newTier >= 16000) return '';
    if (widget.newTier >= 14000) return '';
    if (widget.newTier >= 12000) return '';
    return '';
  }

  String _getTierLabel(int tier) {
    return '${(tier / 1000).round()}K';
  }

  @override
  Widget build(BuildContext context) {
    final lpIncrease = widget.newLP - widget.previousLP;

    return Material(
      color: Colors.black.withValues(alpha: 0.7),
      child: Stack(
        children: [
          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Color(0xFFFF6B6B),
                Color(0xFFFF8E53),
                Color(0xFF4ECDC4),
                Color(0xFFFFD89B),
                Color(0xFF81C784),
              ],
              numberOfParticles: 30,
              maxBlastForce: 20,
              minBlastForce: 5,
            ),
          ),

          // Content
          Center(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Emoji and badge
                    Text(_getTierEmoji(), style: const TextStyle(fontSize: 60)),
                    const SizedBox(height: 16),

                    // Title
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: Us2Theme.accentGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'TIER UP!',
                        style: TextStyle(
                          fontFamily: Us2Theme.fontBody,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // New tier
                    Text(
                      '${_getTierLabel(widget.newTier)} Reached!',
                      style: const TextStyle(
                        fontFamily: Us2Theme.fontHeading,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Us2Theme.textDark,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Steps breakdown
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F9F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStepColumn('You', widget.userSteps, Us2Theme.gradientAccentStart),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('+', style: TextStyle(fontSize: 24, color: Us2Theme.textLight)),
                          ),
                          _buildStepColumn(widget.partnerName, widget.partnerSteps, const Color(0xFF4ECDC4)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('=', style: TextStyle(fontSize: 24, color: Us2Theme.textLight)),
                          ),
                          _buildStepColumn('Together', widget.combinedSteps, Us2Theme.textDark, isBold: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // LP reward
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFB347), Color(0xFFFFD89B)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '+${widget.newLP} LP',
                            style: const TextStyle(
                              fontFamily: Us2Theme.fontHeading,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (lpIncrease > 0) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '+$lpIncrease more!',
                              style: const TextStyle(
                                fontFamily: Us2Theme.fontBody,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tier comparison
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _getTierLabel(widget.previousTier),
                          style: const TextStyle(
                            fontFamily: Us2Theme.fontBody,
                            fontSize: 16,
                            color: Us2Theme.textLight,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward, color: Us2Theme.gradientAccentStart),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: Us2Theme.accentGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getTierLabel(widget.newTier),
                            style: const TextStyle(
                              fontFamily: Us2Theme.fontBody,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Next milestone preview
                    if (widget.newTier < 20000)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Us2Theme.beige),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              'Next: ${_getTierLabel(widget.newTier + 2000)} in ${_formatNumber(widget.newTier + 2000 - widget.combinedSteps)} steps',
                              style: const TextStyle(
                                fontFamily: Us2Theme.fontBody,
                                fontSize: 13,
                                color: Us2Theme.textMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Dismiss button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.onDismiss,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Us2Theme.textDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Keep Walking!',
                          style: TextStyle(
                            fontFamily: Us2Theme.fontBody,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepColumn(String label, int steps, Color color, {bool isBold = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: Us2Theme.fontBody,
            fontSize: 11,
            color: color.withValues(alpha: 0.7),
          ),
        ),
        Text(
          _formatNumber(steps),
          style: TextStyle(
            fontFamily: Us2Theme.fontHeading,
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: color,
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

/// Shows the milestone celebration overlay.
void showStepsMilestoneOverlay({
  required BuildContext context,
  required int previousTier,
  required int newTier,
  required int combinedSteps,
  required int userSteps,
  required int partnerSteps,
  required String partnerName,
  required int previousLP,
  required int newLP,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (context) => StepsMilestoneOverlay(
      previousTier: previousTier,
      newTier: newTier,
      combinedSteps: combinedSteps,
      userSteps: userSteps,
      partnerSteps: partnerSteps,
      partnerName: partnerName,
      previousLP: previousLP,
      newLP: newLP,
      onDismiss: () => Navigator.of(context).pop(),
    ),
  );
}

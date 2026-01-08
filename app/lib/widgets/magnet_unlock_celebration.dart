import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/magnet_collection.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';

/// Celebration overlay shown when a new magnet is unlocked
///
/// Full-screen celebration with confetti shower and destination image.
/// Matches the mockup design with falling confetti animation.
class MagnetUnlockCelebration extends StatefulWidget {
  final int magnetId;
  final VoidCallback onDismiss;

  const MagnetUnlockCelebration({
    super.key,
    required this.magnetId,
    required this.onDismiss,
  });

  /// Show the celebration overlay as a full-screen dialog
  static Future<void> show(BuildContext context, int magnetId) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => MagnetUnlockCelebration(
        magnetId: magnetId,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  State<MagnetUnlockCelebration> createState() => _MagnetUnlockCelebrationState();
}

class _MagnetUnlockCelebrationState extends State<MagnetUnlockCelebration>
    with TickerProviderStateMixin {
  late AnimationController _magnetController;
  late Animation<double> _magnetScale;
  late Animation<double> _magnetRotation;

  // Confetti particles
  final List<_ConfettiParticle> _confetti = [];
  late AnimationController _confettiController;

  @override
  void initState() {
    super.initState();

    // Play haptic and sound
    HapticService().trigger(HapticType.success);
    SoundService().play(SoundId.confettiBurst);

    // Magnet pop-in animation
    _magnetController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _magnetScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.05), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _magnetController,
      curve: Curves.easeOut,
    ));
    _magnetRotation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: -0.15, end: 0.05), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.05, end: 0.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _magnetController,
      curve: Curves.easeOut,
    ));

    // Confetti animation (2.5 seconds, plays once)
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    // Generate 30 confetti particles
    final random = Random();
    for (int i = 0; i < 30; i++) {
      _confetti.add(_ConfettiParticle(
        x: random.nextDouble(),
        delay: random.nextDouble() * 0.25,
        size: 8 + random.nextDouble() * 8,
        color: _confettiColors[random.nextInt(_confettiColors.length)],
        isCircle: random.nextBool(),
        rotationSpeed: 2 + random.nextDouble() * 4,
      ));
    }

    // Start animations
    _magnetController.forward();
    _confettiController.forward();
  }

  static const _confettiColors = [
    Color(0xFFFF6B6B), // Coral red
    Color(0xFFFFE066), // Yellow
    Color(0xFFFF9F43), // Orange
    Color(0xFFFFB347), // Light orange
  ];

  @override
  void dispose() {
    _magnetController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final magnetName = MagnetCollection.getMagnetName(widget.magnetId);
    final magnetAssetPath = MagnetCollection.getMagnetAssetPath(widget.magnetId);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFD1C1), // bg-gradient-start
              Color(0xFFFFF5F0), // bg-gradient-end
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Confetti layer (in front)
              ..._buildConfetti(),

              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    // Title
                    Text(
                      'New Destination Unlocked!',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF3A3A3A),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Magnet image with animation
                    AnimatedBuilder(
                      animation: _magnetController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _magnetScale.value,
                          child: Transform.rotate(
                            angle: _magnetRotation.value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFFFF8F0),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 40,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.asset(
                            magnetAssetPath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFFE8E0D8),
                                child: Center(
                                  child: Text(
                                    magnetName.substring(0, 1),
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF5A5A5A),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Destination name as tagline
                    Text(
                      '"$magnetName"',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF5A5A5A),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Stats
                    Column(
                      children: [
                        Text(
                          '18',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFFF5E62),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'NEW QUIZZES UNLOCKED',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                            color: const Color(0xFF707070),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Button
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white,
                              Color(0xFFFFF8F0),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF5E62).withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Text(
                          'Add to Collection',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFFF5E62),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildConfetti() {
    return _confetti.map((particle) {
      return AnimatedBuilder(
        animation: _confettiController,
        builder: (context, child) {
          // Calculate progress with delay
          final adjustedProgress = ((_confettiController.value - particle.delay) / (1 - particle.delay)).clamp(0.0, 1.0);

          if (adjustedProgress <= 0) return const SizedBox.shrink();

          // Confetti falls from top to bottom
          final screenHeight = MediaQuery.of(context).size.height;
          final y = -20 + (screenHeight + 40) * adjustedProgress;

          // Fade out near the end
          final opacity = adjustedProgress < 0.8 ? 1.0 : (1.0 - adjustedProgress) * 5;

          return Positioned(
            left: MediaQuery.of(context).size.width * particle.x,
            top: y,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: adjustedProgress * particle.rotationSpeed * pi,
                child: Container(
                  width: particle.size,
                  height: particle.size,
                  decoration: BoxDecoration(
                    color: particle.color,
                    borderRadius: particle.isCircle
                        ? BorderRadius.circular(particle.size / 2)
                        : BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }).toList();
  }
}

class _ConfettiParticle {
  final double x; // Horizontal position (0-1)
  final double delay; // Animation delay (0-0.25)
  final double size;
  final Color color;
  final bool isCircle;
  final double rotationSpeed;

  _ConfettiParticle({
    required this.x,
    required this.delay,
    required this.size,
    required this.color,
    required this.isCircle,
    required this.rotationSpeed,
  });
}

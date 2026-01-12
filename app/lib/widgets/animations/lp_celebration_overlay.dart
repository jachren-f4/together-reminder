import 'dart:math';
import 'package:flutter/material.dart';
import '../../config/animation_constants.dart';

/// Overlay widget that shows flying sparkle particles from quest area to LP meter.
/// Used to celebrate LP gains when returning from daily quests.
class LpCelebrationOverlay extends StatefulWidget {
  /// Position where particles start (quest carousel area)
  final Offset startPosition;

  /// Position where particles end (LP meter)
  final Offset endPosition;

  /// Called when particles arrive at destination
  final VoidCallback onComplete;

  /// Amount of LP earned (for potential future use)
  final int lpAmount;

  const LpCelebrationOverlay({
    super.key,
    required this.startPosition,
    required this.endPosition,
    required this.onComplete,
    required this.lpAmount,
  });

  @override
  State<LpCelebrationOverlay> createState() => _LpCelebrationOverlayState();
}

class _LpCelebrationOverlayState extends State<LpCelebrationOverlay>
    with TickerProviderStateMixin {
  late List<_ParticleData> _particles;
  late List<AnimationController> _controllers;
  bool _hasCalledComplete = false;

  @override
  void initState() {
    super.initState();
    _initializeParticles();
    _startAnimations();
  }

  void _initializeParticles() {
    final random = Random();
    final particleCount = AnimationConstants.lpParticleCount;

    _particles = List.generate(particleCount, (index) {
      // Randomize start position with larger spread (wider burst from center)
      final startOffsetX = (random.nextDouble() - 0.5) * 120;
      final startOffsetY = (random.nextDouble() - 0.5) * 80;

      // Randomize end position slightly (converge on meter)
      final endOffsetX = (random.nextDouble() - 0.5) * 30;
      final endOffsetY = (random.nextDouble() - 0.5) * 15;

      // Random size between 12-22 (larger, more visible particles)
      final size = 12.0 + random.nextDouble() * 10.0;

      // Random arc height (how much curve in the path) - more dramatic arcs
      final arcHeight = 40.0 + random.nextDouble() * 60.0;

      return _ParticleData(
        startOffset: Offset(startOffsetX, startOffsetY),
        endOffset: Offset(endOffsetX, endOffsetY),
        size: size,
        arcHeight: arcHeight,
        delay: AnimationConstants.lpParticleStagger * index,
      );
    });

    _controllers = List.generate(particleCount, (index) {
      return AnimationController(
        duration: AnimationConstants.lpParticleFlight,
        vsync: this,
      );
    });
  }

  void _startAnimations() async {
    // Start each particle with staggered delay (only delay by stagger, not cumulative)
    for (var i = 0; i < _controllers.length; i++) {
      if (i > 0) {
        await Future.delayed(AnimationConstants.lpParticleStagger);
      }
      if (mounted) {
        _controllers[i].forward();
      }
    }

    // Wait for last particle to complete its flight
    await Future.delayed(AnimationConstants.lpParticleFlight);

    if (mounted && !_hasCalledComplete) {
      _hasCalledComplete = true;
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use Material + SizedBox.expand for proper Overlay positioning
    return Material(
      type: MaterialType.transparency,
      child: SizedBox.expand(
        child: IgnorePointer(
          child: Stack(
            children: List.generate(_particles.length, (index) {
              return _buildParticle(index);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildParticle(int index) {
    final particle = _particles[index];
    final controller = _controllers[index];

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        if (controller.value == 0) {
          return const SizedBox.shrink();
        }

        final progress = Curves.easeInQuad.transform(controller.value);

        // Calculate position along curved path
        final position = _calculateArcPosition(
          widget.startPosition + particle.startOffset,
          widget.endPosition + particle.endOffset,
          particle.arcHeight,
          progress,
        );

        // Scale: start at 1.0, shrink slightly as approaching destination
        final scale = 1.0 - (progress * 0.2);

        // Fade out quickly in last 15% of journey
        final opacity = progress < 0.85 ? 1.0 : (1.0 - (progress - 0.85) / 0.15);

        return Positioned(
          left: position.dx - (particle.size * scale / 2),
          top: position.dy - (particle.size * scale / 2),
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale,
              child: _buildSparkle(particle.size),
            ),
          ),
        );
      },
    );
  }

  /// Calculate position along a curved arc path
  Offset _calculateArcPosition(
    Offset start,
    Offset end,
    double arcHeight,
    double progress,
  ) {
    // Linear interpolation for x
    final x = start.dx + (end.dx - start.dx) * progress;

    // Parabolic arc for y (peaks in the middle)
    final linearY = start.dy + (end.dy - start.dy) * progress;
    final arcOffset = -arcHeight * 4 * progress * (1 - progress);
    final y = linearY + arcOffset;

    return Offset(x, y);
  }

  Widget _buildSparkle(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Glow behind the star
          Center(
            child: Container(
              width: size * 0.8,
              height: size * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700), // Gold glow
                    blurRadius: size * 1.5,
                    spreadRadius: size * 0.3,
                  ),
                ],
              ),
            ),
          ),
          // Star icon
          Center(
            child: Icon(
              Icons.star,
              size: size,
              color: const Color(0xFFFFD700), // Gold star
              shadows: const [
                Shadow(
                  color: Colors.white,
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticleData {
  final Offset startOffset;
  final Offset endOffset;
  final double size;
  final double arcHeight;
  final Duration delay;

  _ParticleData({
    required this.startOffset,
    required this.endOffset,
    required this.size,
    required this.arcHeight,
    required this.delay,
  });
}

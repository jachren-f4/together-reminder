import 'dart:math';
import 'package:flutter/material.dart';
import '../../config/animation_constants.dart';
import '../../config/brand/us2_theme.dart';

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
      // Randomize start position slightly (spread around center)
      final startOffsetX = (random.nextDouble() - 0.5) * 60;
      final startOffsetY = (random.nextDouble() - 0.5) * 40;

      // Randomize end position slightly (converge on meter)
      final endOffsetX = (random.nextDouble() - 0.5) * 20;
      final endOffsetY = (random.nextDouble() - 0.5) * 10;

      // Random size between 8-14
      final size = 8.0 + random.nextDouble() * 6.0;

      // Random arc height (how much curve in the path)
      final arcHeight = 30.0 + random.nextDouble() * 40.0;

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
    // Start each particle with staggered delay
    for (var i = 0; i < _controllers.length; i++) {
      await Future.delayed(_particles[i].delay);
      if (mounted) {
        _controllers[i].forward();
      }
    }

    // Wait for all particles to complete, then call onComplete
    await Future.delayed(
      AnimationConstants.lpParticleFlight +
          AnimationConstants.lpParticleStagger * (_controllers.length - 1),
    );

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
    return IgnorePointer(
      child: Stack(
        children: List.generate(_particles.length, (index) {
          return _buildParticle(index);
        }),
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

        // Scale: start at 1.0, shrink to 0.6 as approaching destination
        final scale = 1.0 - (progress * 0.4);

        // Opacity: full until 80%, then fade out
        final opacity = progress < 0.8 ? 1.0 : (1.0 - (progress - 0.8) * 5.0);

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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white,
            Us2Theme.primaryBrandPink.withValues(alpha: 0.8),
            Us2Theme.gradientAccentEnd.withValues(alpha: 0.6),
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Us2Theme.glowPink.withValues(alpha: 0.6),
            blurRadius: size * 1.5,
            spreadRadius: size * 0.3,
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

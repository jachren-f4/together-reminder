import 'dart:math';
import 'package:flutter/material.dart';
import '../../config/animation_constants.dart';

/// A widget that creates a particle burst effect at a specified location.
/// Particles explode outward from the origin point and fade away.
class ParticleBurstWidget extends StatefulWidget {
  /// The origin point for the particle burst (in local coordinates)
  final Offset origin;

  /// Number of particles to create
  final int particleCount;

  /// Color of the particles
  final Color color;

  /// Callback when animation completes
  final VoidCallback? onComplete;

  const ParticleBurstWidget({
    super.key,
    required this.origin,
    this.particleCount = AnimationConstants.defaultParticleCount,
    this.color = Colors.black,
    this.onComplete,
  });

  @override
  State<ParticleBurstWidget> createState() => _ParticleBurstWidgetState();
}

class _ParticleBurstWidgetState extends State<ParticleBurstWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AnimationConstants.particleBurst,
    );

    _particles = _generateParticles();

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  List<_Particle> _generateParticles() {
    return List.generate(widget.particleCount, (index) {
      final angle = _random.nextDouble() * 2 * pi;
      final distance =
          AnimationConstants.particleSpread * (0.5 + _random.nextDouble() * 0.5);
      final size = AnimationConstants.minParticleSize +
          _random.nextDouble() *
              (AnimationConstants.maxParticleSize -
                  AnimationConstants.minParticleSize);

      return _Particle(
        targetX: cos(angle) * distance,
        targetY: sin(angle) * distance,
        size: size,
        rotationSpeed: (_random.nextDouble() - 0.5) * 4,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AnimationConstants.shouldReduceMotion(context)) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ParticlePainter(
            particles: _particles,
            progress: AnimationConstants.smoothOutCurve.transform(_controller.value),
            origin: widget.origin,
            color: widget.color,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Particle {
  final double targetX;
  final double targetY;
  final double size;
  final double rotationSpeed;

  _Particle({
    required this.targetX,
    required this.targetY,
    required this.size,
    required this.rotationSpeed,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Offset origin;
  final Color color;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.origin,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    for (final particle in particles) {
      final currentX = origin.dx + particle.targetX * progress;
      final currentY = origin.dy + particle.targetY * progress;
      final currentScale = 1.0 - progress;
      final currentOpacity = 1.0 - progress;

      if (currentOpacity <= 0 || currentScale <= 0) continue;

      paint.color = color.withOpacity(currentOpacity);

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(particle.rotationSpeed * progress * pi);
      canvas.scale(currentScale);

      final halfSize = particle.size / 2;
      canvas.drawRect(
        Rect.fromLTWH(-halfSize, -halfSize, particle.size, particle.size),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Controller for triggering particle bursts
class ParticleBurstController extends ChangeNotifier {
  Offset? _origin;
  int _burstCount = 0;

  Offset? get origin => _origin;
  int get burstCount => _burstCount;

  /// Trigger a particle burst at the specified position
  void burst(Offset position) {
    _origin = position;
    _burstCount++;
    notifyListeners();
  }

  /// Clear the current burst
  void clear() {
    _origin = null;
    notifyListeners();
  }
}

/// Overlay widget that listens to a controller and shows particle bursts
class ParticleBurstOverlay extends StatefulWidget {
  final ParticleBurstController controller;
  final Widget child;
  final int particleCount;
  final Color color;

  const ParticleBurstOverlay({
    super.key,
    required this.controller,
    required this.child,
    this.particleCount = AnimationConstants.defaultParticleCount,
    this.color = Colors.black,
  });

  @override
  State<ParticleBurstOverlay> createState() => _ParticleBurstOverlayState();
}

class _ParticleBurstOverlayState extends State<ParticleBurstOverlay> {
  final List<_BurstInstance> _activeBursts = [];
  int _lastBurstCount = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (widget.controller.burstCount > _lastBurstCount &&
        widget.controller.origin != null) {
      setState(() {
        _activeBursts.add(_BurstInstance(
          key: UniqueKey(),
          origin: widget.controller.origin!,
        ));
        _lastBurstCount = widget.controller.burstCount;
      });
    }
  }

  void _removeBurst(_BurstInstance burst) {
    setState(() {
      _activeBursts.remove(burst);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ..._activeBursts.map((burst) => Positioned.fill(
              child: IgnorePointer(
                child: ParticleBurstWidget(
                  key: burst.key,
                  origin: burst.origin,
                  particleCount: widget.particleCount,
                  color: widget.color,
                  onComplete: () => _removeBurst(burst),
                ),
              ),
            )),
      ],
    );
  }
}

class _BurstInstance {
  final Key key;
  final Offset origin;

  _BurstInstance({required this.key, required this.origin});
}

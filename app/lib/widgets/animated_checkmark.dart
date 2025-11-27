import 'package:flutter/material.dart';
import '../animations/animation_config.dart';

/// Animated checkmark with draw-in effect
///
/// Displays a checkmark that animates from invisible to fully drawn
/// Uses a CustomPainter with path animation for smooth draw effect
class AnimatedCheckmark extends StatefulWidget {
  final double size;
  final Color color;
  final double strokeWidth;
  final Duration duration;
  final Curve curve;

  const AnimatedCheckmark({
    super.key,
    this.size = 12,
    this.color = Colors.white,
    this.strokeWidth = 2,
    this.duration = AnimationConfig.normal,
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<AnimatedCheckmark>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    // Start animation after a brief delay for entrance effect
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _CheckmarkPainter(
            progress: _animation.value,
            color: widget.color,
            strokeWidth: widget.strokeWidth,
          ),
        );
      },
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CheckmarkPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Checkmark path points (normalized 0-1)
    final startX = size.width * 0.15;
    final startY = size.height * 0.5;
    final midX = size.width * 0.4;
    final midY = size.height * 0.75;
    final endX = size.width * 0.85;
    final endY = size.height * 0.25;

    final path = Path();
    path.moveTo(startX, startY);

    // First stroke (down-right) - first 40% of animation
    final firstStrokeProgress = (progress / 0.4).clamp(0.0, 1.0);
    if (firstStrokeProgress > 0) {
      final x = startX + (midX - startX) * firstStrokeProgress;
      final y = startY + (midY - startY) * firstStrokeProgress;
      path.lineTo(x, y);
    }

    // Second stroke (up-right) - last 60% of animation
    final secondStrokeProgress = ((progress - 0.4) / 0.6).clamp(0.0, 1.0);
    if (secondStrokeProgress > 0) {
      final x = midX + (endX - midX) * secondStrokeProgress;
      final y = midY + (endY - midY) * secondStrokeProgress;
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Simple scale-in checkmark for use in badges
///
/// Uses TweenAnimationBuilder for implicit animation
/// Perfect for "✓" text that should pop in
class AnimatedCheckmarkText extends StatelessWidget {
  final TextStyle style;

  const AnimatedCheckmarkText({
    super.key,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: AnimationConfig.normal,
      curve: AnimationConfig.scaleIn,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: Text('✓', style: style),
          ),
        );
      },
    );
  }
}

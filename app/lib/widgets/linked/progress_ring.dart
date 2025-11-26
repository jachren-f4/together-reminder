import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../config/brand/brand_loader.dart';

/// Progress ring widget showing completion percentage
/// Displays as a white circle with percentage text inside
class LinkedProgressRing extends StatelessWidget {
  final int progressPercent;
  final double size;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;
  final TextStyle? textStyle;

  LinkedProgressRing({
    super.key,
    required this.progressPercent,
    this.size = 40,
    this.strokeWidth = 3,
    Color? backgroundColor,
    Color? progressColor,
    this.textStyle,
  })  : backgroundColor = backgroundColor ?? BrandLoader().colors.surface,
        progressColor = progressColor ?? BrandLoader().colors.textPrimary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: BrandLoader().colors.textPrimary.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          // Progress arc
          CustomPaint(
            size: Size(size, size),
            painter: _ProgressRingPainter(
              progress: progressPercent / 100,
              strokeWidth: strokeWidth,
              color: progressColor,
            ),
          ),
          // Percentage text
          Text(
            '$progressPercent%',
            style: textStyle ??
                TextStyle(
                  fontSize: size * 0.25,
                  fontWeight: FontWeight.bold,
                  color: BrandLoader().colors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color color;

  _ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Draw progress arc
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.color != color;
  }
}

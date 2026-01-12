import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom painter for combined progress ring visualization.
/// Shows user (coral) and partner (teal) progress as continuous segments.
class CombinedRingPainter extends CustomPainter {
  final double userProgress; // 0.0 to 1.0 (of total goal)
  final double partnerProgress; // 0.0 to 1.0 (of total goal)
  final Color userColorStart;
  final Color userColorEnd;
  final Color partnerColorStart;
  final Color partnerColorEnd;
  final Color backgroundColor;
  final bool showThresholdMarker;

  CombinedRingPainter({
    required this.userProgress,
    required this.partnerProgress,
    required this.userColorStart,
    required this.userColorEnd,
    required this.partnerColorStart,
    required this.partnerColorEnd,
    required this.backgroundColor,
    this.showThresholdMarker = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 16;
    const strokeWidth = 16.0;

    // Background ring
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Threshold marker at 50% (10K of 20K goal)
    if (showThresholdMarker) {
      final thresholdPaint = Paint()
        ..color = const Color(0xFFDDDDDD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      const thresholdAngle = -math.pi / 2 + math.pi; // 50% = 180 degrees from top

      // Draw small tick mark at the threshold point
      final innerX = center.dx + (radius - 12) * math.cos(thresholdAngle);
      final innerY = center.dy + (radius - 12) * math.sin(thresholdAngle);
      final outerX = center.dx + (radius + 12) * math.cos(thresholdAngle);
      final outerY = center.dy + (radius + 12) * math.sin(thresholdAngle);

      canvas.drawLine(
        Offset(innerX, innerY),
        Offset(outerX, outerY),
        thresholdPaint,
      );
    }

    const startAngle = -math.pi / 2; // Start from top

    // Draw user segment (coral gradient)
    if (userProgress > 0) {
      final userSweep = 2 * math.pi * userProgress.clamp(0.0, 1.0);
      final userRect = Rect.fromCircle(center: center, radius: radius);

      final userPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + userSweep,
          colors: [userColorStart, userColorEnd],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(userRect);

      canvas.drawArc(
        userRect,
        startAngle,
        userSweep,
        false,
        userPaint,
      );
    }

    // Draw partner segment (teal gradient) - continues from user
    if (partnerProgress > 0) {
      final userSweep = 2 * math.pi * userProgress.clamp(0.0, 1.0);
      final partnerSweep = 2 * math.pi * partnerProgress.clamp(0.0, 1.0 - userProgress);
      final partnerStartAngle = startAngle + userSweep;
      final partnerRect = Rect.fromCircle(center: center, radius: radius);

      final partnerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: partnerStartAngle,
          endAngle: partnerStartAngle + partnerSweep,
          colors: [partnerColorStart, partnerColorEnd],
          transform: GradientRotation(partnerStartAngle + math.pi / 2),
        ).createShader(partnerRect);

      canvas.drawArc(
        partnerRect,
        partnerStartAngle,
        partnerSweep,
        false,
        partnerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CombinedRingPainter oldDelegate) {
    return oldDelegate.userProgress != userProgress ||
        oldDelegate.partnerProgress != partnerProgress;
  }
}

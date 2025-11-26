import 'package:flutter/material.dart';
import '../../config/brand/brand_loader.dart';

/// Black void cell - non-interactive filler
/// Enhanced with subtle texture pattern
class LinkedVoidCell extends StatelessWidget {
  final double size;

  const LinkedVoidCell({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2A2A2A),
            const Color(0xFF1A1A1A),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF0A0A0A),
          width: 0.5,
        ),
      ),
      // Subtle diagonal pattern overlay
      child: CustomPaint(
        size: Size(size, size),
        painter: _VoidPatternPainter(),
      ),
    );
  }
}

/// Subtle diagonal line pattern for void cells
class _VoidPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BrandLoader().colors.surface.withValues(alpha: 0.03)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Draw subtle diagonal lines
    const spacing = 8.0;
    for (double i = -size.height; i < size.width; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

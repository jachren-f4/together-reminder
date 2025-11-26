import 'package:flutter/material.dart';
import '../../config/brand/brand_loader.dart';
import 'answer_cell.dart';

/// Animated rack tile for letter selection
/// Features scale animation on appear and bounce on drag start
class RackTile extends StatefulWidget {
  final String letter;
  final int rackIndex;
  final bool isUsed;
  final double size;
  final int animationDelay; // Stagger animation

  const RackTile({
    super.key,
    required this.letter,
    required this.rackIndex,
    required this.isUsed,
    this.size = 44,
    this.animationDelay = 0,
  });

  @override
  State<RackTile> createState() => _RackTileState();
}

class _RackTileState extends State<RackTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.bounceOut),
      ),
    );

    // Stagger animation based on index
    Future.delayed(Duration(milliseconds: widget.animationDelay * 50), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isUsed) {
      return _buildEmptySlot();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value * _bounceAnimation.value,
          child: Draggable<DragData>(
            data: DragData(
              letter: widget.letter,
              sourceType: DragSourceType.rack,
              rackIndex: widget.rackIndex,
            ),
            feedback: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: _buildTile(isFloating: true),
            ),
            childWhenDragging: _buildEmptySlot(),
            child: _buildTile(),
          ),
        );
      },
    );
  }

  Widget _buildTile({bool isFloating = false}) {
    final size = isFloating ? widget.size * 1.15 : widget.size;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF59D), // Light yellow
            Color(0xFFFFEE58), // Yellow
            Color(0xFFFFCA28), // Darker yellow
          ],
        ),
        border: Border.all(
          color: Colors.amber.shade700,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: isFloating ? 0.5 : 0.3),
            blurRadius: isFloating ? 12 : 4,
            offset: Offset(0, isFloating ? 4 : 2),
          ),
          if (!isFloating)
            BoxShadow(
              color: BrandLoader().colors.surface.withValues(alpha: 0.24),
              blurRadius: 1,
              offset: const Offset(-1, -1),
            ),
        ],
      ),
      child: Center(
        child: Text(
          widget.letter,
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.w700,
            fontFamily: 'Georgia',
            color: BrandLoader().colors.textPrimary,
            shadows: [
              Shadow(
                color: BrandLoader().colors.surface.withValues(alpha: 0.38),
                offset: const Offset(0.5, 0.5),
                blurRadius: 0,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySlot() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: BrandLoader().colors.surface,
        border: Border.all(
          color: BrandLoader().colors.textTertiary,
          width: 1.5,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: BrandLoader().colors.textTertiary,
        ),
      ),
    );
  }
}

/// Dashed border painter for empty slots
class _DashedBorderPainter extends CustomPainter {
  final Color color;

  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw subtle dashed pattern
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 4.0;

    // Draw dashed lines
    double startX = dashSpace;
    while (startX < size.width - dashSpace) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

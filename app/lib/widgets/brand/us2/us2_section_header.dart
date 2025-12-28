import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';

/// Ribbon-style section header for Us 2.0
///
/// Based on us2-home-v2.html mockup:
/// - Beige ribbon background with diagonal tail cutout on right
/// - Playfair Display font, uppercase, bold (not italic)
/// - Fading line extending to the right edge
class Us2SectionHeader extends StatelessWidget {
  final String title;

  const Us2SectionHeader({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 15, right: 15, bottom: 20),
      child: Row(
        children: [
          // Ribbon with diagonal tail
          _buildRibbon(),
          const SizedBox(width: 25),
          // Fading line to the right
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Us2Theme.beige,
                    Us2Theme.beige.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRibbon() {
    return CustomPaint(
      painter: _RibbonPainter(color: Us2Theme.beige),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 25, 10),
        child: Text(
          title.toUpperCase(),
          style: GoogleFonts.playfairDisplay(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: Us2Theme.textDark,
          ),
        ),
      ),
    );
  }
}

/// Custom painter for ribbon with diagonal tail
class _RibbonPainter extends CustomPainter {
  final Color color;

  _RibbonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Shadow paint
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final tailWidth = 20.0;
    final path = Path();

    // Main rectangle
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    // Diagonal tail (triangle cutout going right)
    path.lineTo(size.width + tailWidth, size.height / 2);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // Draw shadow first
    canvas.save();
    canvas.translate(2, 2);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // Draw ribbon
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

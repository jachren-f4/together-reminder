import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';

/// Us 2.0 logo with glow effect and illustrated heart accent
///
/// Features:
/// - Pacifico font
/// - Multi-layer text shadow glow
/// - Illustrated SVG heart positioned top-right with pulse animation
/// - Optional double-tap callback for debug menu
class Us2Logo extends StatefulWidget {
  final VoidCallback? onDoubleTap;

  const Us2Logo({super.key, this.onDoubleTap});

  @override
  State<Us2Logo> createState() => _Us2LogoState();
}

class _Us2LogoState extends State<Us2Logo> with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _heartScale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _heartController,
        curve: Curves.easeInOut,
      ),
    );
    _heartController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: widget.onDoubleTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main logo text with glow
          Text(
            'Us 2.0',
            style: GoogleFonts.pacifico(
              fontSize: Us2Theme.logoFontSize,
              color: Colors.white,
              shadows: Us2Theme.logoGlowShadows,
            ),
          ),
          // Illustrated heart accent with animation
          Positioned(
            top: -8,
            right: -22,
            child: ScaleTransition(
              scale: _heartScale,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 12,
                      color: Us2Theme.glowPink.withOpacity(0.7),
                      offset: Offset.zero,
                    ),
                  ],
                ),
                child: SvgPicture.asset(
                  'assets/brands/us2/images/heart_icon.svg',
                  width: 24,
                  height: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

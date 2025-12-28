import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';

/// Us 2.0 logo with glow effect and heart accent
///
/// Features:
/// - Pacifico font
/// - Multi-layer text shadow glow
/// - Heart emoji positioned top-right
class Us2Logo extends StatelessWidget {
  const Us2Logo({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
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
        // Heart accent
        Positioned(
          top: -8,
          right: -18,
          child: Text(
            '♥',
            style: GoogleFonts.pacifico(
              fontSize: Us2Theme.logoHeartSize,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 10,
                  color: Us2Theme.glowPink.withOpacity(0.8),
                  offset: Offset.zero,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

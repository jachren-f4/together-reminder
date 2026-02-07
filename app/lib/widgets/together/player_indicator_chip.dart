import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Small chip showing which player's turn it is in single-phone mode.
///
/// Placed in the header area of game screens. Shows a colored dot
/// (pink for P1, blue for P2) and the player's name.
///
/// Follows mockup: mockups/us20variants/single-mode/quiz-flow.html
class PlayerIndicatorChip extends StatelessWidget {
  final String playerName;
  final bool isPlayer1;

  const PlayerIndicatorChip({
    super.key,
    required this.playerName,
    required this.isPlayer1,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = isPlayer1
        ? const Color(0xFFFF6B6B) // pink for P1
        : const Color(0xFF6C9CE9); // blue for P2

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            playerName,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF3A3A3A),
            ),
          ),
        ],
      ),
    );
  }
}

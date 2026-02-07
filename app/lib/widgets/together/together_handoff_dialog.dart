import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modal dialog handoff for single-phone mode in Linked/Word Search.
///
/// Shows as an overlay on top of the game grid after a player completes
/// their turn. The next player taps "I'M READY" to begin their turn.
///
/// Follows mockup: mockups/us20variants/single-mode/linked-turn-flow.html
class TogetherHandoffDialog extends StatelessWidget {
  final String partnerName;
  final VoidCallback onReady;

  const TogetherHandoffDialog({
    super.key,
    required this.partnerName,
    required this.onReady,
  });

  /// Show the handoff dialog as a modal overlay.
  static Future<void> show(
    BuildContext context, {
    required String partnerName,
    required VoidCallback onReady,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => TogetherHandoffDialog(
        partnerName: partnerName,
        onReady: () {
          Navigator.of(context).pop();
          onReady();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F0), // cream
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // "TURN COMPLETE" label
              Text(
                'TURN COMPLETE',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: const Color(0xFF707070),
                ),
              ),

              const SizedBox(height: 16),

              // Partner avatar
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF6C9CE9), Color(0xFF45B7D1)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x406C9CE9),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    partnerName.isNotEmpty ? partnerName[0].toUpperCase() : 'P',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // "Pass to [Partner]"
              Text(
                'Pass to',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5A5A5A),
                ),
              ),

              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                ).createShader(bounds),
                child: Text(
                  partnerName,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // "I'M READY" button
              GestureDetector(
                onTap: onReady,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B6B).withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      "I'M READY",
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Lock indicator
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    size: 14,
                    color: Color(0xFFA0A0A0),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Answers hidden until ready',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFA0A0A0),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full-screen handoff screen for single-phone mode quizzes.
///
/// Shows after Player 1 completes their turn. Player 2 taps "I'M READY"
/// to begin their turn. Answers are hidden until ready.
///
/// Follows mockup: mockups/us20variants/single-mode/waiting-handoff.html (together side)
class TogetherHandoffScreen extends StatefulWidget {
  final String partnerName;
  final VoidCallback onReady;

  const TogetherHandoffScreen({
    super.key,
    required this.partnerName,
    required this.onReady,
  });

  @override
  State<TogetherHandoffScreen> createState() => _TogetherHandoffScreenState();
}

class _TogetherHandoffScreenState extends State<TogetherHandoffScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.25, end: 0.35).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFFFFF8F0), // cream
          child: SafeArea(
            child: Column(
              children: [
                // Lock indicator at top
                Padding(
                  padding: const EdgeInsets.only(left: 24, top: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 16,
                        color: Color(0xFFA0A0A0),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Answers hidden until ready',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFA0A0A0),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main content centered
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
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

                          // Partner avatar with glow pulse
                          AnimatedBuilder(
                            animation: _glowAnimation,
                            builder: (context, child) {
                              return Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6C9CE9), Color(0xFF45B7D1)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color.fromRGBO(108, 156, 233, _glowAnimation.value),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                    BoxShadow(
                                      color: Color.fromRGBO(255, 107, 107, _glowAnimation.value * 0.4),
                                      blurRadius: 40,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    widget.partnerName.isNotEmpty
                                        ? widget.partnerName[0].toUpperCase()
                                        : 'P',
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 24),

                          // "Nice work!" title
                          Text(
                            'Nice work!',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF3A3A3A),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Gradient divider
                          Container(
                            width: 50,
                            height: 2,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(1),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // "Pass the phone to [Partner]"
                          Text(
                            'Pass the phone to',
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF5A5A5A),
                            ),
                          ),

                          const SizedBox(height: 4),

                          // Partner name in gradient italic
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                            ).createShader(bounds),
                            child: Text(
                              widget.partnerName,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 18,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // "I'M READY" button
                          GestureDetector(
                            onTap: widget.onReady,
                            child: Container(
                              width: 300,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.25),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  "I'M READY",
                                  style: GoogleFonts.nunito(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';

/// Connection bar showing LP progress
///
/// Features:
/// - Gradient background (pink to orange)
/// - Progress bar with heart indicator
/// - Animated sparkles around heart
class Us2ConnectionBar extends StatelessWidget {
  final int currentLp;
  final int nextTierLp;

  const Us2ConnectionBar({
    super.key,
    required this.currentLp,
    required this.nextTierLp,
  });

  @override
  Widget build(BuildContext context) {
    final progress = nextTierLp > 0 ? (currentLp / nextTierLp).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        gradient: Us2Theme.connectionBarGradient,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(Us2Theme.connectionBarBorderRadius),
          topRight: Radius.circular(Us2Theme.connectionBarBorderRadius),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CONNECTION BAR',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
              Text(
                '$currentLp/$nextTierLp',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          SizedBox(
            height: 44,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = constraints.maxWidth;
                final heartPosition = barWidth * progress;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Track background - dark semi-transparent
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 17,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    // Progress fill - gold gradient
                    Positioned(
                      left: 0,
                      top: 17,
                      child: Container(
                        height: 10,
                        width: barWidth * progress,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFFE066), // Gold start
                              Color(0xFFFFB347), // Gold end
                            ],
                          ),
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFE066).withOpacity(0.6),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Heart indicator - positioned at progress point
                    Positioned(
                      left: heartPosition - 22,
                      top: 0,
                      child: _Us2ProgressHeart(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated heart with sparkles
class _Us2ProgressHeart extends StatefulWidget {
  @override
  State<_Us2ProgressHeart> createState() => _Us2ProgressHeartState();
}

class _Us2ProgressHeartState extends State<_Us2ProgressHeart>
    with TickerProviderStateMixin {
  late List<AnimationController> _sparkleControllers;
  late List<Animation<double>> _sparkleAnimations;

  @override
  void initState() {
    super.initState();

    // Create 3 staggered sparkle animations
    _sparkleControllers = List.generate(3, (index) {
      return AnimationController(
        duration: const Duration(milliseconds: Us2Theme.sparkleAnimationDuration),
        vsync: this,
      )..repeat();
    });

    _sparkleAnimations = _sparkleControllers.asMap().entries.map((entry) {
      final index = entry.key;
      final controller = entry.value;
      // Stagger the animations
      Future.delayed(Duration(milliseconds: index * 500), () {
        if (mounted) controller.forward();
      });
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final controller in _sparkleControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: Us2Theme.progressHeartSize,
      height: Us2Theme.progressHeartSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Heart circle
          Container(
            width: Us2Theme.progressHeartSize,
            height: Us2Theme.progressHeartSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Us2Theme.gradientAccentStart,
                  Us2Theme.gradientAccentEnd,
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Us2Theme.glowPink.withOpacity(0.5),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text('💗', style: TextStyle(fontSize: 20)),
            ),
          ),
          // Sparkles
          _buildSparkle(0, -8, -8),
          _buildSparkle(1, 30, -5),
          _buildSparkle(2, 35, 25),
        ],
      ),
    );
  }

  Widget _buildSparkle(int index, double left, double top) {
    return Positioned(
      left: left,
      top: top,
      child: AnimatedBuilder(
        animation: _sparkleAnimations[index],
        builder: (context, child) {
          return Opacity(
            opacity: _sparkleAnimations[index].value,
            child: Transform.scale(
              scale: 0.8 + (_sparkleAnimations[index].value * 0.4),
              child: const Text('✨', style: TextStyle(fontSize: 14)),
            ),
          );
        },
      ),
    );
  }
}

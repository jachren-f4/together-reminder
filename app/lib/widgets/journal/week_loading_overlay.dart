import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:togetherremind/config/journal_fonts.dart';

/// Overlay shown while loading week data in the Journal.
///
/// Features:
/// - Semi-transparent cream background
/// - Bouncing polaroid animation
/// - "Flipping pages..." text with animated dots
/// - Week label showing target week
class WeekLoadingOverlay extends StatefulWidget {
  final String targetWeekLabel;
  final bool visible;

  const WeekLoadingOverlay({
    super.key,
    required this.targetWeekLabel,
    required this.visible,
  });

  @override
  State<WeekLoadingOverlay> createState() => _WeekLoadingOverlayState();
}

class _WeekLoadingOverlayState extends State<WeekLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    // Bounce: translateY 0 → -12 → 0 with easing
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: -12).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -12, end: 0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);

    // Rotation: -3deg → 3deg → -3deg
    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: -3, end: 3), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 3, end: -3), weight: 50),
    ]).animate(_controller);

    // Shimmer: moves across from left to right
    _shimmerAnimation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: widget.visible ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: Container(
          color: const Color(0xFFFFF8F0).withAlpha(235), // ~0.92 opacity
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBouncingPolaroid(),
                const SizedBox(height: 24),
                _buildLoadingText(),
                const SizedBox(height: 12),
                _buildWeekLabel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBouncingPolaroid() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounceAnimation.value),
          child: Transform.rotate(
            angle: _rotationAnimation.value * math.pi / 180,
            child: Container(
              width: 120,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(38), // ~0.15 opacity
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFFD1C1), Color(0xFFFFF5F0)],
                        ),
                      ),
                      child: Stack(
                        children: [
                          const Center(
                            child: Text('📖', style: TextStyle(fontSize: 36)),
                          ),
                          // Shimmer effect
                          ClipRect(
                            child: AnimatedBuilder(
                              animation: _shimmerAnimation,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(
                                    _shimmerAnimation.value * 100,
                                    0,
                                  ),
                                  child: Container(
                                    width: 40,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withAlpha(0),
                                          Colors.white.withAlpha(77),
                                          Colors.white.withAlpha(0),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingText() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Flipping pages',
          style: JournalFonts.weekLoadingText,
        ),
        _buildAnimatedDots(),
      ],
    );
  }

  Widget _buildAnimatedDots() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Show 1, 2, or 3 dots based on animation progress
        final progress = _controller.value;
        final dotCount = ((progress * 4) % 4).floor();

        return SizedBox(
          width: 24,
          child: Text(
            '.' * (dotCount == 0 ? 3 : dotCount),
            style: JournalFonts.weekLoadingText,
          ),
        );
      },
    );
  }

  Widget _buildWeekLabel() {
    return Text(
      widget.targetWeekLabel,
      style: JournalFonts.weekLoadingLabel,
    );
  }
}

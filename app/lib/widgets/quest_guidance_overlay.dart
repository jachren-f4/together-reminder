import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/brand/brand_loader.dart';
import '../config/brand/brand_config.dart';
import '../config/brand/us2_theme.dart';

/// Overlay widget that shows onboarding guidance on a quest card.
///
/// Renders a ribbon ("Start Here" or "Continue Here") and a floating
/// hand pointer to guide new users to their next activity.
class QuestGuidanceOverlay extends StatelessWidget {
  final Widget child;
  final bool showGuidance;
  final String ribbonText;

  const QuestGuidanceOverlay({
    super.key,
    required this.child,
    required this.showGuidance,
    this.ribbonText = 'Start Here',
  });

  @override
  Widget build(BuildContext context) {
    if (!showGuidance) {
      return child;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        // Ribbon at top-left (inside card bounds)
        Positioned(
          top: 12,
          left: 0,
          child: GuidanceRibbon(text: ribbonText),
        ),
        // Floating hand centered, pointing to middle of image
        // IgnorePointer lets taps pass through to the card underneath
        const Positioned(
          top: 70,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: FloatingHandPointer(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Ribbon for guidance text.
/// Uses gradient for Us 2.0 brand, solid black for Liia.
class GuidanceRibbon extends StatelessWidget {
  final String text;

  const GuidanceRibbon({
    super.key,
    required this.text,
  });

  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

  @override
  Widget build(BuildContext context) {
    if (_isUs2) return _buildUs2Ribbon();
    return _buildLiiaRibbon();
  }

  Widget _buildLiiaRibbon() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.black,
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildUs2Ribbon() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: Us2Theme.accentGradient,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        boxShadow: [
          BoxShadow(
            color: Us2Theme.glowPink,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✨', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated floating hand pointer with tap animation.
/// Uses colorful emoji for Us 2.0, grayscale for Liia.
class FloatingHandPointer extends StatefulWidget {
  const FloatingHandPointer({super.key});

  @override
  State<FloatingHandPointer> createState() => _FloatingHandPointerState();
}

class _FloatingHandPointerState extends State<FloatingHandPointer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _translateAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  bool get _isUs2 => BrandLoader().config.brand == Brand.us2;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Float up and down with a "tap" at the bottom
    _translateAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 18)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 18, end: 0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0),
        weight: 50,
      ),
    ]).animate(_controller);

    // Scale down slightly during "tap"
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.95)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.95, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 50,
      ),
    ]).animate(_controller);

    // Slight rotation during animation
    _rotateAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.17, end: -0.09) // ~-10° to ~-5°
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.09, end: -0.17)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(-0.17),
        weight: 50,
      ),
    ]).animate(_controller);

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _translateAnimation.value),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.rotate(
              angle: _rotateAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: _isUs2 ? _buildUs2Hand() : _buildLiiaHand(),
    );
  }

  Widget _buildLiiaHand() {
    return const ColorFiltered(
      colorFilter: ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: Text(
        '👆',
        style: TextStyle(fontSize: 144),
      ),
    );
  }

  Widget _buildUs2Hand() {
    // Colorful hand with subtle glow effect
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow behind
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Us2Theme.glowPink,
                Colors.transparent,
              ],
            ),
          ),
        ),
        // Colorful emoji
        const Text(
          '👆',
          style: TextStyle(fontSize: 144),
        ),
      ],
    );
  }
}

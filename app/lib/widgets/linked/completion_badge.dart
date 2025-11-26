import 'package:flutter/material.dart';
import '../../config/brand/brand_loader.dart';

/// Completion badge widget showing a checkmark
/// Used on completed cards
class LinkedCompletionBadge extends StatelessWidget {
  final double size;
  final Color backgroundColor;
  final Color checkColor;
  final bool animate;

  LinkedCompletionBadge({
    super.key,
    this.size = 40,
    Color? backgroundColor,
    Color? checkColor,
    this.animate = true,
  })  : backgroundColor = backgroundColor ?? BrandLoader().colors.surface,
        checkColor = checkColor ?? BrandLoader().colors.textPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: BrandLoader().colors.textPrimary.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.check,
          size: size * 0.6,
          color: checkColor,
        ),
      ),
    );
  }
}

/// Animated completion badge with scale animation
class LinkedCompletionBadgeAnimated extends StatefulWidget {
  final double size;
  final Color backgroundColor;
  final Color checkColor;
  final Duration animationDuration;

  LinkedCompletionBadgeAnimated({
    super.key,
    this.size = 40,
    Color? backgroundColor,
    Color? checkColor,
    this.animationDuration = const Duration(milliseconds: 300),
  })  : backgroundColor = backgroundColor ?? BrandLoader().colors.surface,
        checkColor = checkColor ?? BrandLoader().colors.textPrimary;

  @override
  State<LinkedCompletionBadgeAnimated> createState() =>
      _LinkedCompletionBadgeAnimatedState();
}

class _LinkedCompletionBadgeAnimatedState
    extends State<LinkedCompletionBadgeAnimated>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    // Start animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: LinkedCompletionBadge(
        size: widget.size,
        backgroundColor: widget.backgroundColor,
        checkColor: widget.checkColor,
        animate: false,
      ),
    );
  }
}

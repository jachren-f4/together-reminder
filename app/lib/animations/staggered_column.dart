import 'package:flutter/material.dart';
import 'animation_config.dart';

/// A Column that animates its children in sequence with staggered timing.
///
/// Each child fades in and slides up from below, creating an elegant
/// reveal effect perfect for completion screens and results displays.
///
/// Usage:
/// ```dart
/// StaggeredColumn(
///   children: [
///     Icon(Icons.check_circle, size: 80),
///     Text('Completed!'),
///     Text('Score: 100'),
///     ElevatedButton(onPressed: () {}, child: Text('Continue')),
///   ],
/// )
/// ```
class StaggeredColumn extends StatefulWidget {
  /// The widgets to display in the column
  final List<Widget> children;

  /// Main axis alignment (default: center)
  final MainAxisAlignment mainAxisAlignment;

  /// Cross axis alignment (default: center)
  final CrossAxisAlignment crossAxisAlignment;

  /// Main axis size (default: min)
  final MainAxisSize mainAxisSize;

  /// Delay before starting the animation
  final Duration initialDelay;

  /// Delay between each child's animation start
  final Duration staggerDelay;

  /// Duration of each child's animation
  final Duration animationDuration;

  /// Distance to slide up from (in pixels)
  final double slideDistance;

  /// Whether to auto-start the animation on mount
  final bool autoStart;

  const StaggeredColumn({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.min,
    this.initialDelay = Duration.zero,
    this.staggerDelay = const Duration(milliseconds: 150),
    this.animationDuration = AnimationConfig.normal,
    this.slideDistance = AnimationConfig.slideMedium,
    this.autoStart = true,
  });

  @override
  State<StaggeredColumn> createState() => StaggeredColumnState();
}

class StaggeredColumnState extends State<StaggeredColumn>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    if (widget.autoStart) {
      _startAnimations();
    }
  }

  void _initAnimations() {
    _controllers = List.generate(
      widget.children.length,
      (index) => AnimationController(
        vsync: this,
        duration: widget.animationDuration,
      ),
    );

    _fadeAnimations = _controllers.map((controller) {
      return CurvedAnimation(
        parent: controller,
        curve: AnimationConfig.fadeIn,
      );
    }).toList();

    _slideAnimations = _controllers.map((controller) {
      return Tween<Offset>(
        begin: Offset(0, widget.slideDistance),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: AnimationConfig.slideIn,
      ));
    }).toList();
  }

  /// Manually start the staggered animation
  void startAnimations() {
    _startAnimations();
  }

  /// Reset and replay the animations
  void replay() {
    for (final controller in _controllers) {
      controller.reset();
    }
    _hasStarted = false;
    _startAnimations();
  }

  Future<void> _startAnimations() async {
    if (_hasStarted) return;
    _hasStarted = true;

    // Initial delay before starting
    if (widget.initialDelay > Duration.zero) {
      await Future.delayed(widget.initialDelay);
    }

    // Start each animation with stagger delay
    for (int i = 0; i < _controllers.length; i++) {
      if (!mounted) return;
      _controllers[i].forward();
      if (i < _controllers.length - 1) {
        await Future.delayed(widget.staggerDelay);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: widget.mainAxisAlignment,
      crossAxisAlignment: widget.crossAxisAlignment,
      mainAxisSize: widget.mainAxisSize,
      children: List.generate(widget.children.length, (index) {
        return AnimatedBuilder(
          animation: _controllers[index],
          builder: (context, child) {
            return Transform.translate(
              offset: _slideAnimations[index].value,
              child: Opacity(
                opacity: _fadeAnimations[index].value,
                child: child,
              ),
            );
          },
          child: widget.children[index],
        );
      }),
    );
  }
}

/// A simpler alternative using implicit animations
///
/// Use this for cases where you want automatic animation on mount
/// without needing manual control.
class StaggeredFadeIn extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration staggerDelay;
  final Duration animationDuration;
  final double slideDistance;

  const StaggeredFadeIn({
    super.key,
    required this.child,
    required this.index,
    this.staggerDelay = const Duration(milliseconds: 150),
    this.animationDuration = AnimationConfig.normal,
    this.slideDistance = AnimationConfig.slideMedium,
  });

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: AnimationConfig.fadeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.slideDistance),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AnimationConfig.slideIn,
    ));

    // Start animation after stagger delay
    Future.delayed(
      Duration(milliseconds: widget.staggerDelay.inMilliseconds * widget.index),
      () {
        if (mounted) _controller.forward();
      },
    );
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
          offset: _slideAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

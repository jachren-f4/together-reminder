import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../config/animation_constants.dart';

/// Tracks which widgets have already animated to prevent re-animation on rebuild.
/// Uses a session-based approach where animations reset on hot restart but not on hot reload.
class AnimationSessionTracker {
  static final AnimationSessionTracker _instance = AnimationSessionTracker._internal();
  factory AnimationSessionTracker() => _instance;
  AnimationSessionTracker._internal();

  final Set<String> _animatedKeys = {};

  /// Check if a widget with this key has already animated
  bool hasAnimated(String key) => _animatedKeys.contains(key);

  /// Mark a widget as having animated
  void markAnimated(String key) => _animatedKeys.add(key);

  /// Clear all tracked animations (useful for testing or screen transitions)
  void clearAll() => _animatedKeys.clear();

  /// Clear animations for a specific prefix (e.g., 'quest_carousel_')
  void clearWithPrefix(String prefix) {
    _animatedKeys.removeWhere((key) => key.startsWith(prefix));
  }
}

/// A widget that animates its child with a dramatic 3D header drop effect.
/// Used for screen headers that drop in from the top with perspective.
///
/// Set [trackingKey] to prevent re-animation on widget rebuild.
class AnimatedHeaderDrop extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final bool animate;
  /// Optional key to track animation state across rebuilds.
  final String? trackingKey;

  const AnimatedHeaderDrop({
    super.key,
    required this.child,
    this.duration = AnimationConstants.headerDrop,
    this.delay = AnimationConstants.headerDropDelay,
    this.animate = true,
    this.trackingKey,
  });

  @override
  State<AnimatedHeaderDrop> createState() => _AnimatedHeaderDropState();
}

class _AnimatedHeaderDropState extends State<AnimatedHeaderDrop>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _translateY;
  late Animation<double> _rotateX;
  late Animation<double> _opacity;
  bool _shouldSkipAnimation = false;

  @override
  void initState() {
    super.initState();

    // Check if this animation has already played (prevents re-animation on rebuild)
    if (widget.trackingKey != null) {
      final tracker = AnimationSessionTracker();
      if (tracker.hasAnimated(widget.trackingKey!)) {
        _shouldSkipAnimation = true;
      } else {
        tracker.markAnimated(widget.trackingKey!);
      }
    }

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _translateY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: -60.0, end: 8.0)
            .chain(CurveTween(curve: AnimationConstants.overshootCurve)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 8.0, end: 0.0),
        weight: 40,
      ),
    ]).animate(_controller);

    _rotateX = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: -0.26, end: 0.09), // -15° to 5°
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.09, end: 0.0),
        weight: 40,
      ),
    ]).animate(_controller);

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // Skip animation if already played, or if animate is false
    if (_shouldSkipAnimation || !widget.animate) {
      _controller.value = 1.0;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate || AnimationConstants.shouldReduceMotion(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, AnimationConstants.perspective)
            ..translate(0.0, _translateY.value)
            ..rotateX(_rotateX.value),
          alignment: Alignment.center,
          child: Opacity(
            opacity: _opacity.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// A widget that bounces in with scale and translate overshoot.
/// Generic entrance animation for cards, buttons, etc.
///
/// Set [trackingKey] to prevent re-animation on widget rebuild.
class BounceInWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final bool animate;
  final double initialScale;
  final double initialTranslateY;
  final Curve curve;
  /// Optional key to track animation state across rebuilds.
  final String? trackingKey;

  const BounceInWidget({
    super.key,
    required this.child,
    this.duration = AnimationConstants.heroReveal,
    this.delay = Duration.zero,
    this.animate = true,
    this.initialScale = 0.7,
    this.initialTranslateY = 40.0,
    this.curve = AnimationConstants.overshootCurve,
    this.trackingKey,
  });

  @override
  State<BounceInWidget> createState() => _BounceInWidgetState();
}

class _BounceInWidgetState extends State<BounceInWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _translateY;
  late Animation<double> _opacity;
  bool _shouldSkipAnimation = false;

  @override
  void initState() {
    super.initState();

    // Check if this animation has already played (prevents re-animation on rebuild)
    if (widget.trackingKey != null) {
      final tracker = AnimationSessionTracker();
      if (tracker.hasAnimated(widget.trackingKey!)) {
        _shouldSkipAnimation = true;
      } else {
        tracker.markAnimated(widget.trackingKey!);
      }
    }

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // Use easeOut for TweenSequence (overshoot curves produce t > 1 which breaks TweenSequence)
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: widget.initialScale, end: 1.05),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.05, end: 1.0),
        weight: 40,
      ),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _translateY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: widget.initialTranslateY, end: -10.0),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -10.0, end: 0.0),
        weight: 40,
      ),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    // Skip animation if already played, or if animate is false
    if (_shouldSkipAnimation || !widget.animate) {
      _controller.value = 1.0;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate || AnimationConstants.shouldReduceMotion(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _translateY.value),
          child: Transform.scale(
            scale: _scale.value,
            child: Opacity(
              opacity: _opacity.value,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// A widget that slides in from left or right with rotation.
/// Used for answer options and result cards in alternating pattern.
///
/// Set [trackingKey] to prevent re-animation on widget rebuild.
class StaggeredSlideIn extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final Duration baseDelay;
  final Duration staggerDelay;
  final bool animate;
  final double slideDistance;
  final double rotationDegrees;
  /// Optional key to track animation state across rebuilds.
  final String? trackingKey;

  const StaggeredSlideIn({
    super.key,
    required this.child,
    required this.index,
    this.duration = AnimationConstants.slideIn,
    this.baseDelay = const Duration(milliseconds: 700),
    this.staggerDelay = const Duration(milliseconds: 100),
    this.animate = true,
    this.slideDistance = 60.0,
    this.rotationDegrees = 5.0,
    this.trackingKey,
  });

  @override
  State<StaggeredSlideIn> createState() => _StaggeredSlideInState();
}

class _StaggeredSlideInState extends State<StaggeredSlideIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _translateX;
  late Animation<double> _rotation;
  late Animation<double> _opacity;
  bool _shouldSkipAnimation = false;

  bool get _fromLeft => AnimationConstants.slidesFromLeft(widget.index);

  @override
  void initState() {
    super.initState();

    // Check if this animation has already played (prevents re-animation on rebuild)
    if (widget.trackingKey != null) {
      final tracker = AnimationSessionTracker();
      if (tracker.hasAnimated(widget.trackingKey!)) {
        _shouldSkipAnimation = true;
      } else {
        tracker.markAnimated(widget.trackingKey!);
      }
    }

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    final direction = _fromLeft ? -1.0 : 1.0;
    final rotationDirection = _fromLeft ? -1.0 : 1.0;

    _translateX = Tween<double>(
      begin: widget.slideDistance * direction,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AnimationConstants.overshootCurve,
    ));

    _rotation = Tween<double>(
      begin: widget.rotationDegrees * rotationDirection * (math.pi / 180),
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AnimationConstants.overshootCurve,
    ));

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Skip animation if already played, or if animate is false
    if (_shouldSkipAnimation || !widget.animate) {
      _controller.value = 1.0;
    } else {
      final totalDelay = widget.baseDelay + (widget.staggerDelay * widget.index);
      Future.delayed(totalDelay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate || AnimationConstants.shouldReduceMotion(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform(
          transform: Matrix4.identity()
            ..translate(_translateX.value, 0.0)
            ..rotateZ(_rotation.value),
          alignment: Alignment.center,
          child: Opacity(
            opacity: _opacity.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// A widget that performs a 3D card flip entrance.
/// Used for question cards with dramatic reveal.
///
/// Set [trackingKey] to prevent re-animation on widget rebuild. When provided,
/// the animation will only play once per session for that key.
class Card3DEntrance extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final bool animate;
  final bool isDramatic;
  /// Optional key to track animation state across rebuilds.
  /// When set, the animation only plays once per session.
  final String? trackingKey;

  const Card3DEntrance({
    super.key,
    required this.child,
    this.duration = AnimationConstants.cardEntrance,
    this.delay = AnimationConstants.cardEntranceDelay,
    this.animate = true,
    this.isDramatic = false,
    this.trackingKey,
  });

  @override
  State<Card3DEntrance> createState() => _Card3DEntranceState();
}

class _Card3DEntranceState extends State<Card3DEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _translateY;
  late Animation<double> _scale;
  late Animation<double> _rotateX;
  late Animation<double> _opacity;
  bool _shouldSkipAnimation = false;

  @override
  void initState() {
    super.initState();

    // Check if this animation has already played (prevents re-animation on rebuild)
    if (widget.trackingKey != null) {
      final tracker = AnimationSessionTracker();
      if (tracker.hasAnimated(widget.trackingKey!)) {
        _shouldSkipAnimation = true;
      } else {
        tracker.markAnimated(widget.trackingKey!);
      }
    }

    _controller = AnimationController(
      vsync: this,
      duration: widget.isDramatic
          ? AnimationConstants.cardEntranceDramatic
          : widget.duration,
    );

    if (widget.isDramatic) {
      // 4-stage dramatic entrance
      _translateY = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 80.0, end: -15.0), weight: 50),
        TweenSequenceItem(tween: Tween(begin: -15.0, end: 5.0), weight: 25),
        TweenSequenceItem(tween: Tween(begin: 5.0, end: 0.0), weight: 25),
      ]).animate(_controller);

      _scale = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.05), weight: 50),
        TweenSequenceItem(tween: Tween(begin: 1.05, end: 0.98), weight: 25),
        TweenSequenceItem(tween: Tween(begin: 0.98, end: 1.0), weight: 25),
      ]).animate(_controller);

      _rotateX = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: -0.35, end: 0.14), weight: 50),
        TweenSequenceItem(tween: Tween(begin: 0.14, end: -0.05), weight: 25),
        TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.0), weight: 25),
      ]).animate(_controller);
    } else {
      // Standard entrance
      _translateY = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 60.0, end: -10.0), weight: 60),
        TweenSequenceItem(tween: Tween(begin: -10.0, end: 0.0), weight: 40),
      ]).animate(_controller);

      _scale = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.03), weight: 60),
        TweenSequenceItem(tween: Tween(begin: 1.03, end: 1.0), weight: 40),
      ]).animate(_controller);

      _rotateX = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: -0.26, end: 0.09), weight: 60),
        TweenSequenceItem(tween: Tween(begin: 0.09, end: 0.0), weight: 40),
      ]).animate(_controller);
    }

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    // Skip animation if already played, or if animate is false
    if (_shouldSkipAnimation || !widget.animate) {
      _controller.value = 1.0;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate || AnimationConstants.shouldReduceMotion(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, AnimationConstants.perspective)
            ..translate(0.0, _translateY.value)
            ..scale(_scale.value)
            ..rotateX(_rotateX.value),
          alignment: Alignment.center,
          child: Opacity(
            opacity: _opacity.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// A widget that performs a 3D flip reveal (like rotateY).
/// Used for score circles and sync meters.
class FlipRevealWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final bool animate;

  const FlipRevealWidget({
    super.key,
    required this.child,
    this.duration = AnimationConstants.scoreFlip,
    this.delay = const Duration(milliseconds: 600),
    this.animate = true,
  });

  @override
  State<FlipRevealWidget> createState() => _FlipRevealWidgetState();
}

class _FlipRevealWidgetState extends State<FlipRevealWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotateY;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _rotateY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: math.pi, end: math.pi / 2), weight: 50),
      TweenSequenceItem(tween: Tween(begin: math.pi / 2, end: 0.0), weight: 25),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 25),
    ]).animate(_controller);

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.95), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 25),
    ]).animate(_controller);

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    if (widget.animate) {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate || AnimationConstants.shouldReduceMotion(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, AnimationConstants.perspective)
            ..rotateY(_rotateY.value)
            ..scale(_scale.value),
          alignment: Alignment.center,
          child: Opacity(
            opacity: _opacity.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// A widget that performs a button rise animation.
/// Bounces up from below with scale.
class ButtonRiseWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final bool animate;

  const ButtonRiseWidget({
    super.key,
    required this.child,
    this.duration = AnimationConstants.buttonRise,
    this.delay = AnimationConstants.buttonRiseDelay,
    this.animate = true,
  });

  @override
  State<ButtonRiseWidget> createState() => _ButtonRiseWidgetState();
}

class _ButtonRiseWidgetState extends State<ButtonRiseWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _translateY;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // Use easeOut for TweenSequence (overshoot curves produce t > 1 which breaks TweenSequence)
    _translateY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 30.0, end: -5.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 0.0), weight: 40),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.02), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.02, end: 1.0), weight: 40),
    ]).animate(_controller);

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    if (widget.animate) {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate || AnimationConstants.shouldReduceMotion(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _translateY.value),
          child: Transform.scale(
            scale: _scale.value,
            child: Opacity(
              opacity: _opacity.value,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Grid cell pop animation for crossword/word search intros
class CellPopWidget extends StatefulWidget {
  final Widget child;
  final int cellIndex;
  final Duration duration;
  final Duration baseDelay;
  final Duration staggerDelay;
  final bool animate;
  final bool withRotation;

  const CellPopWidget({
    super.key,
    required this.child,
    required this.cellIndex,
    this.duration = AnimationConstants.cellPop,
    this.baseDelay = const Duration(milliseconds: 800),
    this.staggerDelay = const Duration(milliseconds: 50),
    this.animate = true,
    this.withRotation = true,
  });

  @override
  State<CellPopWidget> createState() => _CellPopWidgetState();
}

class _CellPopWidgetState extends State<CellPopWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _rotation;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // Use easeOut for TweenSequence (overshoot curves produce t > 1 which breaks TweenSequence)
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    if (widget.withRotation) {
      _rotation = TweenSequence<double>([
        TweenSequenceItem(
            tween: Tween(begin: -10 * (math.pi / 180), end: 3 * (math.pi / 180)),
            weight: 60),
        TweenSequenceItem(
            tween: Tween(begin: 3 * (math.pi / 180), end: 0.0), weight: 40),
      ]).animate(_controller);
    } else {
      _rotation = ConstantTween(0.0).animate(_controller);
    }

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    if (widget.animate) {
      final totalDelay =
          widget.baseDelay + (widget.staggerDelay * widget.cellIndex);
      Future.delayed(totalDelay, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate || AnimationConstants.shouldReduceMotion(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform(
          transform: Matrix4.identity()
            ..scale(_scale.value)
            ..rotateZ(_rotation.value),
          alignment: Alignment.center,
          child: Opacity(
            opacity: _opacity.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Wave animation for word search grid cells
class WaveInWidget extends StatefulWidget {
  final Widget child;
  final int row;
  final int column;
  final Duration duration;
  final Duration baseDelay;
  final bool animate;

  const WaveInWidget({
    super.key,
    required this.child,
    required this.row,
    required this.column,
    this.duration = AnimationConstants.letterWave,
    this.baseDelay = const Duration(milliseconds: 700),
    this.animate = true,
  });

  @override
  State<WaveInWidget> createState() => _WaveInWidgetState();
}

class _WaveInWidgetState extends State<WaveInWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 40),
    ]).animate(_controller);

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    if (widget.animate) {
      final delay = AnimationConstants.waveDelay(widget.row, widget.column);
      Future.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate || AnimationConstants.shouldReduceMotion(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: Opacity(
            opacity: _opacity.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

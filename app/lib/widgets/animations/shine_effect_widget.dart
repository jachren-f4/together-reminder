import 'package:flutter/material.dart';
import '../../config/animation_constants.dart';

/// A widget that adds a shine sweep effect over its child.
/// The shine animates from left to right periodically.
class ShineEffectWidget extends StatefulWidget {
  /// The child widget to apply the shine effect to
  final Widget child;

  /// Whether the shine animation is enabled
  final bool enabled;

  /// Duration of the shine sweep
  final Duration duration;

  /// Delay before the first shine
  final Duration delay;

  /// Pause duration between shines (as fraction of total cycle)
  /// 0.5 means shine takes half the time, pause takes half
  final double pauseFraction;

  /// Color of the shine highlight
  final Color shineColor;

  /// Width of the shine gradient (as fraction of widget width)
  final double shineWidth;

  const ShineEffectWidget({
    super.key,
    required this.child,
    this.enabled = true,
    this.duration = AnimationConstants.shineSweep,
    this.delay = const Duration(milliseconds: 1000),
    this.pauseFraction = 0.5,
    this.shineColor = Colors.white,
    this.shineWidth = 0.3,
  });

  @override
  State<ShineEffectWidget> createState() => _ShineEffectWidgetState();
}

class _ShineEffectWidgetState extends State<ShineEffectWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shineAnimation;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // Animation goes from -1 (off left) to 1 (off right) during first half
    // Then stays at 1 (paused) during second half
    // Ensure weights are always > 0 to avoid TweenSequence assertion
    final sweepWeight = ((1 - widget.pauseFraction) * 100).clamp(1.0, 99.0);
    final pauseWeight = (widget.pauseFraction * 100).clamp(1.0, 99.0);
    _shineAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: -1.0, end: 1.0 + widget.shineWidth),
        weight: sweepWeight,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0 + widget.shineWidth),
        weight: pauseWeight,
      ),
    ]).animate(_controller);

    if (widget.enabled) {
      _startAfterDelay();
    }
  }

  void _startAfterDelay() {
    Future.delayed(widget.delay, () {
      if (mounted && widget.enabled) {
        _hasStarted = true;
        _controller.repeat();
      }
    });
  }

  @override
  void didUpdateWidget(ShineEffectWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.enabled && !oldWidget.enabled) {
      if (!_hasStarted) {
        _startAfterDelay();
      } else {
        _controller.repeat();
      }
    } else if (!widget.enabled && oldWidget.enabled) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || AnimationConstants.shouldReduceMotion(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _shineAnimation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final shinePosition = _shineAnimation.value;

            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.white,
                Colors.white,
                widget.shineColor.withOpacity(0.3),
                Colors.white,
                Colors.white,
              ],
              stops: [
                0.0,
                (shinePosition - widget.shineWidth / 2).clamp(0.0, 1.0),
                shinePosition.clamp(0.0, 1.0),
                (shinePosition + widget.shineWidth / 2).clamp(0.0, 1.0),
                1.0,
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Alternative shine effect that overlays a gradient instead of using ShaderMask
/// More performant but works differently visually
class ShineOverlayWidget extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final Duration duration;
  final Duration delay;
  final double pauseFraction;
  final Color shineColor;

  const ShineOverlayWidget({
    super.key,
    required this.child,
    this.enabled = true,
    this.duration = AnimationConstants.shineSweep,
    this.delay = const Duration(milliseconds: 1000),
    this.pauseFraction = 0.5,
    this.shineColor = Colors.white,
  });

  @override
  State<ShineOverlayWidget> createState() => _ShineOverlayWidgetState();
}

class _ShineOverlayWidgetState extends State<ShineOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnimation;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // Ensure weights are always > 0 to avoid TweenSequence assertion
    final sweepWeight = ((1 - widget.pauseFraction) * 100).clamp(1.0, 99.0);
    final pauseWeight = (widget.pauseFraction * 100).clamp(1.0, 99.0);
    _positionAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: -0.5, end: 1.5),
        weight: sweepWeight,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.5),
        weight: pauseWeight,
      ),
    ]).animate(_controller);

    if (widget.enabled) {
      _startAfterDelay();
    }
  }

  void _startAfterDelay() {
    Future.delayed(widget.delay, () {
      if (mounted && widget.enabled) {
        _hasStarted = true;
        _controller.repeat();
      }
    });
  }

  @override
  void didUpdateWidget(ShineOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.enabled && !oldWidget.enabled) {
      if (!_hasStarted) {
        _startAfterDelay();
      } else {
        _controller.repeat();
      }
    } else if (!widget.enabled && oldWidget.enabled) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || AnimationConstants.shouldReduceMotion(context)) {
      return widget.child;
    }

    return ClipRRect(
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _positionAnimation,
              builder: (context, child) {
                return IgnorePointer(
                  child: FractionallySizedBox(
                    alignment: Alignment(
                      _positionAnimation.value * 2 - 1,
                      0,
                    ),
                    widthFactor: 0.3,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.shineColor.withOpacity(0),
                            widget.shineColor.withOpacity(0.3),
                            widget.shineColor.withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import '../../config/animation_constants.dart';

/// A widget that creates falling confetti particles.
/// Used for celebration screens like quiz results.
class ConfettiWidget extends StatefulWidget {
  /// Whether to trigger the confetti
  final bool trigger;

  /// Number of confetti pieces
  final int pieceCount;

  /// Color of the confetti
  final Color color;

  /// Callback when animation completes
  final VoidCallback? onComplete;

  const ConfettiWidget({
    super.key,
    required this.trigger,
    this.pieceCount = 15,
    this.color = Colors.black,
    this.onComplete,
  });

  @override
  State<ConfettiWidget> createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<ConfettiWidget>
    with TickerProviderStateMixin {
  final List<_ConfettiPiece> _pieces = [];
  final Random _random = Random();
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    if (widget.trigger) {
      _startConfetti();
    }
  }

  @override
  void didUpdateWidget(ConfettiWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger && !_isAnimating) {
      _startConfetti();
    }
  }

  void _startConfetti() {
    _isAnimating = true;
    _pieces.clear();

    for (int i = 0; i < widget.pieceCount; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds: 2500 + _random.nextInt(900),
        ),
      );

      final piece = _ConfettiPiece(
        controller: controller,
        startX: 0.03 + _random.nextDouble() * 0.94, // 3% to 97% of width
        width: [6.0, 10.0, 4.0][_random.nextInt(3)],
        height: [14.0, 10.0, 18.0][_random.nextInt(3)],
        delay: Duration(milliseconds: 200 + _random.nextInt(400)),
        rotationSpeed: 3 + _random.nextDouble() * 3, // 3-6 full rotations
        swayAmount: 20 + _random.nextDouble() * 40,
        swaySpeed: 2 + _random.nextDouble() * 2,
      );

      _pieces.add(piece);

      Future.delayed(piece.delay, () {
        if (mounted) {
          controller.forward();
        }
      });

      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _checkAllComplete();
        }
      });
    }

    setState(() {});
  }

  void _checkAllComplete() {
    if (_pieces.every((p) => p.controller.isCompleted)) {
      _isAnimating = false;
      widget.onComplete?.call();
    }
  }

  @override
  void dispose() {
    for (final piece in _pieces) {
      piece.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AnimationConstants.shouldReduceMotion(context) || _pieces.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: _pieces.map((piece) {
            return AnimatedBuilder(
              animation: piece.controller,
              builder: (context, child) {
                final progress = piece.controller.value;
                final easedProgress =
                    AnimationConstants.smoothOutCurve.transform(progress);

                // Vertical fall
                final y = easedProgress * (constraints.maxHeight + 100);

                // Horizontal sway
                final swayOffset = sin(progress * pi * piece.swaySpeed) *
                    piece.swayAmount *
                    (1 - progress * 0.5);

                // Rotation
                final rotation = progress * pi * 2 * piece.rotationSpeed;

                // Scale down as it falls
                final scale = 1.0 - (progress * 0.7);

                // Fade out near end
                final opacity = progress < 0.85 ? 1.0 : (1 - progress) / 0.15;

                if (opacity <= 0 || scale <= 0) {
                  return const SizedBox.shrink();
                }

                final x = piece.startX * constraints.maxWidth + swayOffset;

                return Positioned(
                  left: x - piece.width / 2,
                  top: y - 20, // Start slightly above
                  child: Transform.rotate(
                    angle: rotation,
                    child: Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Container(
                          width: piece.width,
                          height: piece.height,
                          color: widget.color,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}

class _ConfettiPiece {
  final AnimationController controller;
  final double startX;
  final double width;
  final double height;
  final Duration delay;
  final double rotationSpeed;
  final double swayAmount;
  final double swaySpeed;

  _ConfettiPiece({
    required this.controller,
    required this.startX,
    required this.width,
    required this.height,
    required this.delay,
    required this.rotationSpeed,
    required this.swayAmount,
    required this.swaySpeed,
  });
}

/// Controller for triggering confetti
class ConfettiController extends ChangeNotifier {
  bool _shouldTrigger = false;
  int _triggerCount = 0;

  bool get shouldTrigger => _shouldTrigger;
  int get triggerCount => _triggerCount;

  void trigger() {
    _shouldTrigger = true;
    _triggerCount++;
    notifyListeners();

    Future.microtask(() {
      _shouldTrigger = false;
      notifyListeners();
    });
  }
}

/// Overlay widget for confetti controlled by a controller
class ConfettiOverlay extends StatefulWidget {
  final ConfettiController controller;
  final Widget child;
  final int pieceCount;
  final Color color;

  const ConfettiOverlay({
    super.key,
    required this.controller,
    required this.child,
    this.pieceCount = 15,
    this.color = Colors.black,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> {
  int _lastTriggerCount = 0;
  bool _trigger = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (widget.controller.triggerCount > _lastTriggerCount) {
      setState(() {
        _trigger = true;
        _lastTriggerCount = widget.controller.triggerCount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ConfettiWidget(
              trigger: _trigger,
              pieceCount: widget.pieceCount,
              color: widget.color,
              onComplete: () {
                setState(() {
                  _trigger = false;
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Heart beat animation for LP icons
class HeartBeatWidget extends StatefulWidget {
  final Widget child;
  final bool animate;
  final Duration delay;

  const HeartBeatWidget({
    super.key,
    required this.child,
    this.animate = true,
    this.delay = const Duration(milliseconds: 1500),
  });

  @override
  State<HeartBeatWidget> createState() => _HeartBeatWidgetState();
}

class _HeartBeatWidgetState extends State<HeartBeatWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Heart beat pattern: beat-beat-pause
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
    ]).animate(_controller);

    if (widget.animate) {
      Future.delayed(widget.delay, () {
        if (mounted) {
          _controller.repeat();
        }
      });
    }
  }

  @override
  void didUpdateWidget(HeartBeatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !oldWidget.animate) {
      _controller.repeat();
    } else if (!widget.animate && oldWidget.animate) {
      _controller.stop();
      _controller.value = 0;
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
      animation: _scale,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

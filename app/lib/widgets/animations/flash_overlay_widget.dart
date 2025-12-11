import 'package:flutter/material.dart';
import '../../config/animation_constants.dart';

/// A widget that creates a full-screen flash overlay effect.
/// Used for screen transitions and dramatic selections.
class FlashOverlayWidget extends StatefulWidget {
  /// Whether to trigger the flash
  final bool trigger;

  /// Peak opacity of the flash (0.0 - 1.0)
  final double peakOpacity;

  /// Color of the flash
  final Color color;

  /// Duration of the flash
  final Duration duration;

  /// Callback when flash completes
  final VoidCallback? onComplete;

  const FlashOverlayWidget({
    super.key,
    required this.trigger,
    this.peakOpacity = 0.15, // Subtle flash - 15% opacity instead of 100%
    this.color = Colors.black,
    this.duration = AnimationConstants.flash,
    this.onComplete,
  });

  @override
  State<FlashOverlayWidget> createState() => _FlashOverlayWidgetState();
}

class _FlashOverlayWidgetState extends State<FlashOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  bool _lastTrigger = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: widget.peakOpacity)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: widget.peakOpacity, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

    if (widget.trigger) {
      _controller.forward();
      _lastTrigger = true;
    }
  }

  @override
  void didUpdateWidget(FlashOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Trigger on rising edge (false -> true)
    if (widget.trigger && !_lastTrigger) {
      _controller.forward(from: 0.0);
    }
    _lastTrigger = widget.trigger;

    // Update peak opacity if changed
    if (oldWidget.peakOpacity != widget.peakOpacity) {
      _opacityAnimation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 0.0, end: widget.peakOpacity)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40,
        ),
        TweenSequenceItem(
          tween: Tween(begin: widget.peakOpacity, end: 0.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 60,
        ),
      ]).animate(_controller);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AnimationConstants.shouldReduceMotion(context)) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        if (_opacityAnimation.value == 0) {
          return const SizedBox.shrink();
        }
        return Positioned.fill(
          child: IgnorePointer(
            child: Container(
              color: widget.color.withOpacity(_opacityAnimation.value),
            ),
          ),
        );
      },
    );
  }
}

/// Controller for triggering flash effects
class FlashController extends ChangeNotifier {
  bool _shouldFlash = false;
  int _flashCount = 0;

  bool get shouldFlash => _shouldFlash;
  int get flashCount => _flashCount;

  /// Trigger a flash
  void flash() {
    _shouldFlash = true;
    _flashCount++;
    notifyListeners();

    // Reset after a frame
    Future.microtask(() {
      _shouldFlash = false;
      notifyListeners();
    });
  }
}

/// Convenience widget that wraps content with a flash overlay controlled by a controller
class FlashOverlay extends StatefulWidget {
  final FlashController controller;
  final Widget child;
  final double peakOpacity;
  final Color color;
  final Duration duration;

  const FlashOverlay({
    super.key,
    required this.controller,
    required this.child,
    this.peakOpacity = 0.15, // Subtle flash - 15% opacity instead of 100%
    this.color = Colors.black,
    this.duration = AnimationConstants.flash,
  });

  @override
  State<FlashOverlay> createState() => _FlashOverlayState();
}

class _FlashOverlayState extends State<FlashOverlay> {
  int _lastFlashCount = 0;
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
    if (widget.controller.flashCount > _lastFlashCount) {
      setState(() {
        _trigger = true;
        _lastFlashCount = widget.controller.flashCount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        FlashOverlayWidget(
          trigger: _trigger,
          peakOpacity: widget.peakOpacity,
          color: widget.color,
          duration: widget.duration,
          onComplete: () {
            setState(() {
              _trigger = false;
            });
          },
        ),
      ],
    );
  }
}

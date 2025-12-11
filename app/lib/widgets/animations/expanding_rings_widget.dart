import 'package:flutter/material.dart';
import '../../config/animation_constants.dart';

/// A widget that creates expanding ring animations from a center point.
/// Used for major celebrations and transitions.
class ExpandingRingsWidget extends StatefulWidget {
  /// Whether to trigger the animation
  final bool trigger;

  /// Center point for the rings (defaults to widget center)
  final Offset? center;

  /// Number of rings
  final int ringCount;

  /// Color of the rings
  final Color color;

  /// Ring border width
  final double borderWidth;

  /// Duration per ring
  final Duration duration;

  /// Stagger delay between rings
  final Duration staggerDelay;

  /// Callback when all rings complete
  final VoidCallback? onComplete;

  const ExpandingRingsWidget({
    super.key,
    required this.trigger,
    this.center,
    this.ringCount = AnimationConstants.ringCount,
    this.color = Colors.black,
    this.borderWidth = AnimationConstants.ringBorderWidth,
    this.duration = AnimationConstants.ringExpand,
    this.staggerDelay = const Duration(milliseconds: 100),
    this.onComplete,
  });

  @override
  State<ExpandingRingsWidget> createState() => _ExpandingRingsWidgetState();
}

class _ExpandingRingsWidgetState extends State<ExpandingRingsWidget>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<double>> _opacityAnimations;
  bool _lastTrigger = false;
  int _completedCount = 0;

  @override
  void initState() {
    super.initState();
    _initAnimations();

    if (widget.trigger) {
      _startAnimations();
      _lastTrigger = true;
    }
  }

  void _initAnimations() {
    _controllers = List.generate(
      widget.ringCount,
      (index) => AnimationController(
        vsync: this,
        duration: widget.duration,
      ),
    );

    _scaleAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: AnimationConstants.standardCurve,
        ),
      );
    }).toList();

    _opacityAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeOut,
        ),
      );
    }).toList();

    for (final controller in _controllers) {
      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _completedCount++;
          if (_completedCount >= widget.ringCount) {
            widget.onComplete?.call();
          }
        }
      });
    }
  }

  void _startAnimations() {
    _completedCount = 0;
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(widget.staggerDelay * i, () {
        if (mounted) {
          _controllers[i].forward(from: 0.0);
        }
      });
    }
  }

  @override
  void didUpdateWidget(ExpandingRingsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Trigger on rising edge
    if (widget.trigger && !_lastTrigger) {
      _startAnimations();
    }
    _lastTrigger = widget.trigger;
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
    if (AnimationConstants.shouldReduceMotion(context)) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final center = widget.center ??
            Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
        final maxSize = (constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.of(context).size.width) *
            3;

        return Stack(
          children: List.generate(widget.ringCount, (index) {
            return AnimatedBuilder(
              animation: _controllers[index],
              builder: (context, child) {
                final scale = _scaleAnimations[index].value;
                final opacity = _opacityAnimations[index].value;

                if (opacity <= 0 || scale <= 0) {
                  return const SizedBox.shrink();
                }

                final size = maxSize * scale;

                return Positioned(
                  left: center.dx - size / 2,
                  top: center.dy - size / 2,
                  child: IgnorePointer(
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.color.withOpacity(opacity),
                          width: widget.borderWidth,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        );
      },
    );
  }
}

/// Controller for triggering ring expansion effects
class ExpandingRingsController extends ChangeNotifier {
  bool _shouldExpand = false;
  int _expandCount = 0;
  Offset? _center;

  bool get shouldExpand => _shouldExpand;
  int get expandCount => _expandCount;
  Offset? get center => _center;

  /// Trigger ring expansion from center of screen
  void expand() {
    _center = null;
    _shouldExpand = true;
    _expandCount++;
    notifyListeners();

    Future.microtask(() {
      _shouldExpand = false;
      notifyListeners();
    });
  }

  /// Trigger ring expansion from a specific point
  void expandFrom(Offset center) {
    _center = center;
    _shouldExpand = true;
    _expandCount++;
    notifyListeners();

    Future.microtask(() {
      _shouldExpand = false;
      notifyListeners();
    });
  }
}

/// Convenience widget that wraps content with expanding rings controlled by a controller
class ExpandingRingsOverlay extends StatefulWidget {
  final ExpandingRingsController controller;
  final Widget child;
  final int ringCount;
  final Color color;
  final double borderWidth;
  final Duration duration;
  final Duration staggerDelay;

  const ExpandingRingsOverlay({
    super.key,
    required this.controller,
    required this.child,
    this.ringCount = AnimationConstants.ringCount,
    this.color = Colors.black,
    this.borderWidth = AnimationConstants.ringBorderWidth,
    this.duration = AnimationConstants.ringExpand,
    this.staggerDelay = const Duration(milliseconds: 100),
  });

  @override
  State<ExpandingRingsOverlay> createState() => _ExpandingRingsOverlayState();
}

class _ExpandingRingsOverlayState extends State<ExpandingRingsOverlay> {
  int _lastExpandCount = 0;
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
    if (widget.controller.expandCount > _lastExpandCount) {
      setState(() {
        _trigger = true;
        _lastExpandCount = widget.controller.expandCount;
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
            child: ExpandingRingsWidget(
              trigger: _trigger,
              center: widget.controller.center,
              ringCount: widget.ringCount,
              color: widget.color,
              borderWidth: widget.borderWidth,
              duration: widget.duration,
              staggerDelay: widget.staggerDelay,
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

import 'package:flutter/material.dart';
import '../../config/brand/brand_loader.dart';

/// Answer cell state
enum AnswerCellState {
  empty, // White, no letter placed
  draft, // Yellow, letter placed but not submitted
  locked, // Green, correctly placed and locked
  incorrect, // Red flash for wrong placement (temporary)
}

/// Answer cell - can be empty, have a draft letter, or be locked
/// Now with animations for visual polish
class LinkedAnswerCell extends StatefulWidget {
  final double size;
  final AnswerCellState state;
  final String? letter;
  final bool isHighlighted; // Blue glow for hint
  final bool isDragTarget; // Currently being dragged over
  final VoidCallback? onTap;

  const LinkedAnswerCell({
    super.key,
    required this.size,
    required this.state,
    this.letter,
    this.isHighlighted = false,
    this.isDragTarget = false,
    this.onTap,
  });

  @override
  State<LinkedAnswerCell> createState() => _LinkedAnswerCellState();
}

class _LinkedAnswerCellState extends State<LinkedAnswerCell>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation for highlighted cells
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Scale animation for letter placement
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _scaleController.value = 1.0; // Start at full scale

    if (widget.isHighlighted) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(LinkedAnswerCell oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle highlight changes
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isHighlighted && oldWidget.isHighlighted) {
      _pulseController.stop();
      _pulseController.reset();
    }

    // Animate letter appearance
    if (widget.letter != null && oldWidget.letter == null) {
      _scaleController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Color get _backgroundColor {
    if (widget.isDragTarget) return const Color(0xFFE3F2FD); // Light blue
    switch (widget.state) {
      case AnswerCellState.empty:
        return BrandLoader().colors.surface;
      case AnswerCellState.draft:
        return const Color(0xFFFFEE58); // Yellow
      case AnswerCellState.locked:
        return const Color(0xFF81C784); // Green
      case AnswerCellState.incorrect:
        return const Color(0xFFEF5350); // Red
    }
  }

  Color get _borderColor {
    if (widget.isDragTarget) return BrandLoader().colors.info;
    if (widget.isHighlighted) return BrandLoader().colors.info;
    if (widget.state == AnswerCellState.locked) return const Color(0xFF4CAF50);
    if (widget.state == AnswerCellState.incorrect) return BrandLoader().colors.error;
    return BrandLoader().colors.textSecondary;
  }

  double get _borderWidth {
    if (widget.isDragTarget || widget.isHighlighted) return 3;
    if (widget.state == AnswerCellState.locked) return 2.5;
    return 1.5;
  }

  List<BoxShadow>? get _boxShadow {
    if (widget.isHighlighted) {
      return [
        BoxShadow(
          color: BrandLoader().colors.info.withValues(alpha: 0.5),
          blurRadius: 12,
          spreadRadius: 3,
        ),
      ];
    }
    if (widget.state == AnswerCellState.locked) {
      return [
        BoxShadow(
          color: BrandLoader().colors.success.withValues(alpha: 0.3),
          blurRadius: 6,
          spreadRadius: 1,
        ),
      ];
    }
    if (widget.state == AnswerCellState.draft) {
      return [
        BoxShadow(
          color: Colors.amber.withValues(alpha: 0.3),
          blurRadius: 4,
          spreadRadius: 0,
        ),
      ];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _scaleAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isHighlighted ? _pulseAnimation.value : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: _backgroundColor,
                border: Border.all(
                  color: _borderColor,
                  width: _borderWidth,
                ),
                borderRadius: BorderRadius.circular(4),
                boxShadow: _boxShadow,
              ),
              child: Center(
                child: widget.letter != null
                    ? Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Text(
                          widget.letter!,
                          style: TextStyle(
                            fontSize: widget.size * 0.5,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Georgia',
                            color: widget.state == AnswerCellState.locked
                                ? BrandLoader().colors.textOnPrimary
                                : BrandLoader().colors.textPrimary,
                            shadows: widget.state == AnswerCellState.locked
                                ? [
                                    Shadow(
                                      color: BrandLoader().colors.textPrimary.withValues(alpha: 0.26),
                                      offset: const Offset(1, 1),
                                      blurRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Draggable answer cell for draft letters with enhanced feedback
class DraggableAnswerCell extends StatelessWidget {
  final double size;
  final String letter;
  final int cellIndex;
  final int rackIndex;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnd;

  const DraggableAnswerCell({
    super.key,
    required this.size,
    required this.letter,
    required this.cellIndex,
    required this.rackIndex,
    this.onDragStarted,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Draggable<DragData>(
      data: DragData(
        letter: letter,
        sourceType: DragSourceType.grid,
        cellIndex: cellIndex,
        rackIndex: rackIndex,
      ),
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnd?.call(),
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: size * 1.1,
          height: size * 1.1,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEE58),
            border: Border.all(color: Colors.amber.shade700, width: 2),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: BrandLoader().colors.textPrimary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              letter,
              style: TextStyle(
                fontSize: size * 0.55,
                fontWeight: FontWeight.w700,
                fontFamily: 'Georgia',
                color: BrandLoader().colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: BrandLoader().colors.surface,
          border: Border.all(color: BrandLoader().colors.textTertiary, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      child: LinkedAnswerCell(
        size: size,
        state: AnswerCellState.draft,
        letter: letter,
      ),
    );
  }
}

/// Data transferred during drag operations
class DragData {
  final String letter;
  final DragSourceType sourceType;
  final int? cellIndex; // For grid-to-grid drags
  final int rackIndex; // Original rack position

  DragData({
    required this.letter,
    required this.sourceType,
    this.cellIndex,
    required this.rackIndex,
  });
}

enum DragSourceType {
  rack, // Dragging from rack
  grid, // Dragging from grid (rearranging)
}

import 'package:flutter/material.dart';
import 'editorial_styles.dart';
import '../../animations/animation_config.dart';
import '../../services/sound_service.dart';
import '../../services/haptic_service.dart';

/// Editorial-style button with black/white styling
///
/// Supports primary (filled black) and secondary (outlined) variants.
/// Can be full-width or inline.
/// Includes subtle press animation with haptic and sound feedback.
///
/// Usage:
/// ```dart
/// EditorialButton(
///   label: 'START QUIZ',
///   onPressed: () => startQuiz(),
///   isPrimary: true,
///   isFullWidth: true,
/// )
/// ```
class EditorialButton extends StatefulWidget {
  /// Button label text (will be uppercased)
  final String label;

  /// Callback when button is pressed (null = disabled)
  final VoidCallback? onPressed;

  /// Primary (filled black) or secondary (outlined) style
  final bool isPrimary;

  /// Whether button should expand to full width
  final bool isFullWidth;

  /// Optional icon to show before the label
  final IconData? icon;

  /// Optional emoji to show before the label
  final String? emoji;

  const EditorialButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isPrimary = true,
    this.isFullWidth = false,
    this.icon,
    this.emoji,
  });

  @override
  State<EditorialButton> createState() => _EditorialButtonState();
}

class _EditorialButtonState extends State<EditorialButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  bool get _isDisabled => widget.onPressed == null;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: AnimationConfig.fast,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: AnimationConfig.pressScale,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: AnimationConfig.buttonPress,
    ));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (_isDisabled) return;
    setState(() => _isPressed = true);
    _scaleController.forward();
    HapticService().tap();
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isDisabled) return;
    setState(() => _isPressed = false);
    _scaleController.reverse();
  }

  void _handleTapCancel() {
    if (_isDisabled) return;
    setState(() => _isPressed = false);
    _scaleController.reverse();
  }

  void _handleTap() {
    if (_isDisabled) return;
    SoundService().tap();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final decoration = _isDisabled
        ? EditorialStyles.disabledButtonDecoration
        : widget.isPrimary
            ? EditorialStyles.primaryButtonDecoration
            : EditorialStyles.secondaryButtonDecoration;

    final textStyle = _isDisabled
        ? EditorialStyles.disabledButtonText
        : widget.isPrimary
            ? EditorialStyles.primaryButtonText
            : EditorialStyles.secondaryButtonText;

    final iconColor = _isDisabled
        ? EditorialStyles.inkMuted
        : widget.isPrimary
            ? EditorialStyles.paper
            : EditorialStyles.ink;

    Widget content = Row(
      mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.emoji != null) ...[
          Text(widget.emoji!, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
        ],
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
        ],
        Text(
          widget.label.toUpperCase(),
          style: textStyle,
        ),
      ],
    );

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _isPressed && !_isDisabled
                  ? AnimationConfig.pressedOpacity
                  : 1.0,
              child: Container(
                width: widget.isFullWidth ? double.infinity : null,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: decoration,
                child: content,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Primary button shorthand - full width, filled black
class EditorialPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? emoji;

  const EditorialPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return EditorialButton(
      label: label,
      onPressed: onPressed,
      isPrimary: true,
      isFullWidth: true,
      icon: icon,
      emoji: emoji,
    );
  }
}

/// Secondary button shorthand - full width, outlined
class EditorialSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? emoji;

  const EditorialSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return EditorialButton(
      label: label,
      onPressed: onPressed,
      isPrimary: false,
      isFullWidth: true,
      icon: icon,
      emoji: emoji,
    );
  }
}

/// Compact inline button for use in rows
class EditorialInlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final IconData? icon;
  final String? emoji;

  const EditorialInlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isPrimary = false,
    this.icon,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return EditorialButton(
      label: label,
      onPressed: onPressed,
      isPrimary: isPrimary,
      isFullWidth: false,
      icon: icon,
      emoji: emoji,
    );
  }
}

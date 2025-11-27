import 'package:flutter/material.dart';
import 'editorial_styles.dart';

/// Editorial-style badge for labels like "CLASSIC QUIZ", "COMPLETED", etc.
///
/// Supports inverted (black background) and normal (white background) variants.
///
/// Usage:
/// ```dart
/// EditorialBadge(
///   label: 'CLASSIC QUIZ',
///   isInverted: true,
/// )
/// ```
class EditorialBadge extends StatelessWidget {
  /// Badge text (will be uppercased)
  final String label;

  /// Inverted style (black background, white text)
  final bool isInverted;

  /// Optional icon before the label
  final IconData? icon;

  /// Optional emoji before the label
  final String? emoji;

  /// Padding inside the badge
  final EdgeInsets padding;

  const EditorialBadge({
    super.key,
    required this.label,
    this.isInverted = false,
    this.icon,
    this.emoji,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isInverted ? EditorialStyles.ink : EditorialStyles.paper;
    final textColor = isInverted ? EditorialStyles.paper : EditorialStyles.ink;
    final borderColor = EditorialStyles.ink;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: EditorialStyles.borderWidth),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null) ...[
            Text(emoji!, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
          ],
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 8),
          ],
          Text(
            label.toUpperCase(),
            style: EditorialStyles.labelUppercase.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

/// Completed badge with checkmark
///
/// Black background with white checkmark and "YOU'RE DONE!" text.
class EditorialCompletedBadge extends StatelessWidget {
  final String label;

  const EditorialCompletedBadge({
    super.key,
    this.label = "You're Done!",
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: EditorialStyles.ink,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check,
            size: 16,
            color: EditorialStyles.paper,
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: EditorialStyles.labelUppercase.copyWith(
              color: EditorialStyles.paper,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small circular badge for option letters (A, B, C, D)
class EditorialOptionLetter extends StatelessWidget {
  final String letter;
  final bool isSelected;

  const EditorialOptionLetter({
    super.key,
    required this.letter,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected ? EditorialStyles.paper : Colors.transparent;
    final textColor = isSelected ? EditorialStyles.ink : null;
    final borderColor = isSelected ? EditorialStyles.paper : null;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? EditorialStyles.ink,
          width: EditorialStyles.borderWidth,
        ),
      ),
      child: Center(
        child: Text(
          letter.toUpperCase(),
          style: EditorialStyles.counterText.copyWith(
            color: textColor,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// Scale point for 5-point Likert scale
class EditorialScalePoint extends StatelessWidget {
  final int number;
  final String? label;
  final bool isSelected;
  final VoidCallback? onTap;

  const EditorialScalePoint({
    super.key,
    required this.number,
    this.label,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected ? EditorialStyles.ink : EditorialStyles.paper;
    final textColor = isSelected ? EditorialStyles.paper : EditorialStyles.ink;
    final labelColor = isSelected ? EditorialStyles.ink : EditorialStyles.inkMuted;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: EditorialStyles.ink,
                width: EditorialStyles.borderWidth,
              ),
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: TextStyle(
                  fontFamily: EditorialStyles.counterText.fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: 55,
              child: Text(
                label!.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 0.3,
                  color: labelColor,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Number badge in a square border (for steps)
class EditorialStepNumber extends StatelessWidget {
  final int number;

  const EditorialStepNumber({
    super.key,
    required this.number,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        border: EditorialStyles.fullBorder,
      ),
      child: Center(
        child: Text(
          number.toString(),
          style: EditorialStyles.counterText,
        ),
      ),
    );
  }
}

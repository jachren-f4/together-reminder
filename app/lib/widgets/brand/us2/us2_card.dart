import 'package:flutter/material.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';

/// Styled card for Us 2.0 brand
///
/// Features salmon gradient, glow shadow, and rounded corners.
/// Used for question cards, result cards, list items, etc.
class Us2Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final bool useGradient;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const Us2Card({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.useGradient = true,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: useGradient ? Us2Theme.cardGradient : null,
        color: useGradient ? null : (backgroundColor ?? Us2Theme.cream),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: Us2Theme.cardGlowShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}

/// Light variant of Us2Card with cream background
class Us2CardLight extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;

  const Us2CardLight({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Us2Card(
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      useGradient: false,
      backgroundColor: Us2Theme.cream,
      onTap: onTap,
      child: child,
    );
  }
}

/// Question card with emoji, question text, and answer options
class Us2QuestionCard extends StatelessWidget {
  final String emoji;
  final String question;
  final List<String> options;
  final int? selectedIndex;
  final Function(int) onOptionSelected;

  const Us2QuestionCard({
    super.key,
    required this.emoji,
    required this.question,
    required this.options,
    required this.onOptionSelected,
    this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Us2Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Emoji
          Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 48),
            ),
          ),
          const SizedBox(height: 16),
          // Question text
          Text(
            question,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Options
          ...options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected = selectedIndex == index;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Us2OptionButton(
                label: option,
                isSelected: isSelected,
                onTap: () => onOptionSelected(index),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Option button for question cards
class Us2OptionButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const Us2OptionButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Us2Theme.primaryBrandPink
                : Colors.white.withOpacity(0.5),
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isSelected ? Us2Theme.primaryBrandPink : Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Result card for displaying match results
class Us2ResultCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final Color? valueColor;

  const Us2ResultCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Us2Card(
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: valueColor ?? Colors.white,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

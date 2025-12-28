import 'package:flutter/material.dart';
import 'editorial_styles.dart';

/// Editorial-style card with black border and optional offset shadow
///
/// Used for stats cards, question cards, partner cards, etc.
///
/// Usage:
/// ```dart
/// EditorialCard(
///   hasShadow: true,
///   child: Column(
///     children: [...],
///   ),
/// )
/// ```
class EditorialCard extends StatelessWidget {
  /// Card content
  final Widget child;

  /// Padding inside the card
  final EdgeInsets padding;

  /// Whether to show the offset shadow
  final bool hasShadow;

  /// Shadow size variant
  final EditorialShadowSize shadowSize;

  /// Background color (defaults to paper/white)
  final Color? backgroundColor;

  const EditorialCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.hasShadow = true,
    this.shadowSize = EditorialShadowSize.medium,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final shadow = hasShadow ? _getShadow() : null;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? EditorialStyles.paper,
        border: EditorialStyles.fullBorder,
        boxShadow: shadow,
      ),
      child: child,
    );
  }

  List<BoxShadow>? _getShadow() {
    switch (shadowSize) {
      case EditorialShadowSize.small:
        return EditorialStyles.cardShadowSubtle;
      case EditorialShadowSize.medium:
        return EditorialStyles.cardShadowSmall;
      case EditorialShadowSize.large:
        return EditorialStyles.cardShadow;
    }
  }
}

/// Shadow size options for editorial cards
enum EditorialShadowSize {
  small,  // 4px offset
  medium, // 6px offset
  large,  // 8px offset
}

/// Stats card with rows of label-value pairs
///
/// Usage:
/// ```dart
/// EditorialStatsCard(
///   rows: [
///     ('QUESTIONS', '10'),
///     ('TIME', '~5 min'),
///     ('REWARD', '30 LP'),
///   ],
/// )
/// ```
class EditorialStatsCard extends StatelessWidget {
  /// List of (label, value) pairs
  final List<(String label, String value)> rows;

  const EditorialStatsCard({
    super.key,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return EditorialCard(
      padding: EdgeInsets.zero,
      hasShadow: false,
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            _StatsRow(label: rows[i].$1, value: rows[i].$2),
            if (i < rows.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: EditorialStyles.inkLight,
              ),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatsRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: EditorialStyles.labelUppercaseSmall,
          ),
          Text(
            value,
            style: EditorialStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Question card for You or Me game
///
/// Displays a label and question text in a centered card.
class EditorialQuestionCard extends StatelessWidget {
  /// Small label above the question (e.g., "WHO IS MORE LIKELY TO...")
  final String? label;

  /// The question text
  final String question;

  /// Whether the question should be italic
  final bool isItalic;

  const EditorialQuestionCard({
    super.key,
    this.label,
    required this.question,
    this.isItalic = true,
  });

  @override
  Widget build(BuildContext context) {
    return EditorialCard(
      hasShadow: true,
      shadowSize: EditorialShadowSize.medium,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Text(
              label!.toUpperCase(),
              style: EditorialStyles.labelUppercaseSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          Text(
            question,
            style: isItalic
                ? EditorialStyles.statementText
                : EditorialStyles.questionText,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Partner status card for waiting screens
class EditorialPartnerCard extends StatelessWidget {
  /// Partner's avatar (emoji or widget)
  final String avatarEmoji;

  /// Partner's name
  final String name;

  /// Status text (e.g., "In progress...")
  final String status;

  /// Whether to render the emoji in grayscale (for waiting states)
  final bool grayscale;

  const EditorialPartnerCard({
    super.key,
    required this.avatarEmoji,
    required this.name,
    required this.status,
    this.grayscale = false,
  });

  @override
  Widget build(BuildContext context) {
    return EditorialCard(
      hasShadow: false,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: EditorialStyles.inkLight,
              shape: BoxShape.circle,
              border: Border.all(
                color: EditorialStyles.ink,
                width: EditorialStyles.borderWidth,
              ),
            ),
            child: Center(
              child: grayscale
                  ? ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0, 0, 0, 1, 0,
                      ]),
                      child: Text(
                        avatarEmoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                    )
                  : Text(
                      avatarEmoji,
                      style: const TextStyle(fontSize: 26),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: EditorialStyles.bodyText.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: EditorialStyles.bodySmall.copyWith(
                    color: EditorialStyles.inkMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

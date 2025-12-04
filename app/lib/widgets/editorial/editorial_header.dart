import 'package:flutter/material.dart';
import 'editorial_styles.dart';

/// Editorial-style header with close button, title, counter, and progress bar
///
/// Used in quiz question screens, game screens, and waiting screens.
/// Combines the header row and progress bar into a single compact component.
///
/// Usage:
/// ```dart
/// EditorialHeader(
///   title: 'CLASSIC QUIZ',
///   counter: '3 of 10',
///   progress: 0.3,
///   onClose: () => Navigator.pop(context),
/// )
/// ```
class EditorialHeader extends StatelessWidget {
  /// The title displayed next to the close button (e.g., "CLASSIC QUIZ")
  final String title;

  /// The counter text on the right (e.g., "3 of 10")
  final String? counter;

  /// Progress value from 0.0 to 1.0 (shows progress bar if provided)
  final double? progress;

  /// Callback when close button is pressed
  final VoidCallback onClose;

  /// Whether to show the bottom border
  final bool showBorder;

  const EditorialHeader({
    super.key,
    required this.title,
    this.counter,
    this.progress,
    required this.onClose,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: EditorialStyles.paper,
        border: showBorder
            ? Border(bottom: EditorialStyles.border)
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Padding(
            padding: EditorialStyles.headerPadding,
            child: Row(
              children: [
                // Close button
                _CloseButton(onPressed: onClose),
                const SizedBox(width: 12),
                // Title
                Text(
                  title.toUpperCase(),
                  style: EditorialStyles.labelUppercase,
                ),
                const Spacer(),
                // Counter
                if (counter != null)
                  Text(
                    counter!,
                    style: EditorialStyles.counterText,
                  ),
              ],
            ),
          ),
          // Progress bar (if progress is provided)
          if (progress != null) ...[
            const SizedBox(height: 2),
            _ProgressBar(progress: progress!),
          ],
        ],
      ),
    );
  }
}

/// Square close button with border
class _CloseButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CloseButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: EditorialStyles.paper,
          border: EditorialStyles.fullBorder,
        ),
        child: Center(
          child: Icon(
            Icons.close,
            size: 18,
            color: EditorialStyles.ink,
          ),
        ),
      ),
    );
  }
}

/// 4px tall progress bar with black fill on gray track
class _ProgressBar extends StatelessWidget {
  final double progress;

  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      color: EditorialStyles.inkLight,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          color: EditorialStyles.ink,
        ),
      ),
    );
  }
}

/// Simpler header variant with just close button and title (no progress)
///
/// Used for waiting screens and results screens.
class EditorialHeaderSimple extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  final bool showBorder;

  const EditorialHeaderSimple({
    super.key,
    required this.title,
    required this.onClose,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return EditorialHeader(
      title: title,
      onClose: onClose,
      showBorder: showBorder,
    );
  }
}

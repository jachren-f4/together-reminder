import 'package:flutter/material.dart';

enum DebugStatus {
  success,
  warning,
  error,
}

/// Status indicator widget for debug menu
class DebugStatusIndicator extends StatelessWidget {
  final DebugStatus status;
  final double size;

  const DebugStatusIndicator({
    Key? key,
    required this.status,
    this.size = 16,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case DebugStatus.success:
        return Icon(
          Icons.check_circle,
          color: Colors.green.shade600,
          size: size,
        );
      case DebugStatus.warning:
        return Icon(
          Icons.warning,
          color: Colors.orange.shade600,
          size: size,
        );
      case DebugStatus.error:
        return Icon(
          Icons.error,
          color: Colors.red.shade600,
          size: size,
        );
    }
  }

  /// Static method to get text representation
  static String getText(DebugStatus status) {
    switch (status) {
      case DebugStatus.success:
        return '✅';
      case DebugStatus.warning:
        return '⚠️';
      case DebugStatus.error:
        return '❌';
    }
  }
}

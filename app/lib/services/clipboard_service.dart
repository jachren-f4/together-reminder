import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Service for clipboard operations with user feedback
class ClipboardService {
  /// Copy text to clipboard and show a toast message
  static Future<void> copyToClipboard(
    BuildContext context,
    String data, {
    String? message,
  }) async {
    try {
      await Clipboard.setData(ClipboardData(text: data));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message ?? 'Copied to clipboard'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy: $e'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }
}

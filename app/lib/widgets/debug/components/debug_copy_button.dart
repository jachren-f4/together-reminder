import 'package:flutter/material.dart';
import '../../../services/clipboard_service.dart';

/// Copy button for debug menu sections
class DebugCopyButton extends StatelessWidget {
  final String data;
  final String? message;
  final bool isLarge;

  const DebugCopyButton({
    Key? key,
    required this.data,
    this.message,
    this.isLarge = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLarge) {
      // Large "Copy All" button for header
      return ElevatedButton.icon(
        onPressed: () => ClipboardService.copyToClipboard(
          context,
          data,
          message: message,
        ),
        icon: const Icon(Icons.copy, size: 16),
        label: const Text('Copy All'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else {
      // Small copy button for sections/cards
      return IconButton(
        icon: const Icon(Icons.copy, size: 16),
        onPressed: () => ClipboardService.copyToClipboard(
          context,
          data,
          message: message,
        ),
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(),
        style: IconButton.styleFrom(
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.grey.shade700,
        ),
      );
    }
  }
}

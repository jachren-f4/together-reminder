import 'package:flutter/material.dart';
import 'debug_copy_button.dart';

/// Reusable section card for debug menu
class DebugSectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final String? copyData;
  final String? copyMessage;

  const DebugSectionCard({
    Key? key,
    required this.title,
    required this.child,
    this.copyData,
    this.copyMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header with title and copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                if (copyData != null)
                  DebugCopyButton(
                    data: copyData!,
                    message: copyMessage,
                  ),
              ],
            ),
          ),

          // Section content
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// A 5-point Likert scale widget using heart icons
/// Used for affirmation-style quiz questions
class FivePointScaleWidget extends StatelessWidget {
  final int? selectedValue; // 1-5, null if not selected
  final ValueChanged<int> onChanged;

  const FivePointScaleWidget({
    super.key,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top label
        Text(
          'Strongly disagree',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),

        // Heart scale (1-5)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (index) {
            final value = index + 1;
            final isSelected = selectedValue != null && value <= selectedValue!;

            return GestureDetector(
              onTap: () {
                // Defensive bounds check (1-5 only)
                if (value >= 1 && value <= 5) {
                  onChanged(value);
                }
              },
              child: Icon(
                isSelected ? Icons.favorite : Icons.favorite_border,
                size: 48,
                color: isSelected ? Colors.red : Colors.grey[400],
              ),
            );
          }),
        ),

        const SizedBox(height: 16),

        // Bottom label
        Text(
          'Strongly agree',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

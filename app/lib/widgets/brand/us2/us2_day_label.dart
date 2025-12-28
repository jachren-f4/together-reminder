import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:togetherremind/config/brand/us2_theme.dart';

/// Day label showing "Day Two", "Day Five", etc.
///
/// Uses Playfair Display italic font for elegant appearance.
class Us2DayLabel extends StatelessWidget {
  final int dayNumber;

  const Us2DayLabel({
    super.key,
    required this.dayNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      'Day ${_numberToWord(dayNumber)}',
      style: GoogleFonts.playfairDisplay(
        fontSize: Us2Theme.dayLabelFontSize,
        fontStyle: FontStyle.italic,
        color: Us2Theme.textDark,
      ),
    );
  }

  String _numberToWord(int number) {
    const words = [
      'One', 'Two', 'Three', 'Four', 'Five',
      'Six', 'Seven', 'Eight', 'Nine', 'Ten',
      'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen',
      'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen', 'Twenty',
    ];

    if (number >= 1 && number <= 20) {
      return words[number - 1];
    }
    return number.toString();
  }
}

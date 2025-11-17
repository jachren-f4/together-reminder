/// Utility for formatting numbers as words
/// Used for quest descriptions and header subtitles
class NumberFormatter {
  /// Format a number with commas (e.g., 2450 → "2,450")
  /// Used for Love Points and large numbers
  static String format(int number) {
    if (number < 1000) return number.toString();

    final str = number.toString();
    final result = StringBuffer();
    int count = 0;

    for (int i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        result.write(',');
      }
      result.write(str[i]);
      count++;
    }

    return result.toString().split('').reversed.join();
  }

  /// Convert a number (1-999) to its capitalized word equivalent
  /// Returns the number as a string if out of range
  ///
  /// Examples:
  /// - 1 → "One"
  /// - 42 → "Forty-Two"
  /// - 100 → "One Hundred"
  static String toWords(int number) {
    if (number < 0 || number > 999) return number.toString();

    const ones = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine'
    ];
    const teens = [
      'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen',
      'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'
    ];
    const tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
    ];

    if (number == 0) return 'Zero';
    if (number < 10) return ones[number];
    if (number < 20) return teens[number - 10];
    if (number < 100) {
      final ten = number ~/ 10;
      final one = number % 10;
      return tens[ten] + (one > 0 ? '-${ones[one]}' : '');
    }

    // Handle hundreds
    final hundred = number ~/ 100;
    final remainder = number % 100;
    String result = '${ones[hundred]} Hundred';
    if (remainder > 0) {
      result += ' ${toWords(remainder)}';
    }
    return result;
  }

  /// Convert a number (1-10) to its lowercase word equivalent
  /// Returns the number as a string if out of range
  static String numberToWords(int number) {
    const Map<int, String> numbers = {
      1: 'one',
      2: 'two',
      3: 'three',
      4: 'four',
      5: 'five',
      6: 'six',
      7: 'seven',
      8: 'eight',
      9: 'nine',
      10: 'ten',
    };

    return numbers[number] ?? number.toString();
  }

  /// Convert a number (1-10) to its capitalized word equivalent
  /// Returns the number as a string if out of range
  static String numberToWordsCapitalized(int number) {
    final word = numberToWords(number);
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1);
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Available serif fonts for the app
enum SerifFont {
  georgia('Georgia', 'Classic, screen-optimized serif'),
  lora('Lora', 'Modern, elegant serif with warmth'),
  merriweather('Merriweather', 'Sturdy, readable serif'),
  crimsonText('Crimson Text', 'Traditional book-like serif'),
  libreBaskerville('Libre Baskerville', 'Classic Baskerville revival'),
  playfairDisplay('Playfair Display', 'High-contrast dramatic serif'),
  ebGaramond('EB Garamond', 'Old-style manuscript serif');

  final String displayName;
  final String description;

  const SerifFont(this.displayName, this.description);

  /// Get the TextStyle for this font
  /// Georgia is a system font, others are Google Fonts
  TextStyle getTextStyle() {
    switch (this) {
      case SerifFont.georgia:
        // Georgia is a system font, not available in Google Fonts
        return const TextStyle(fontFamily: 'Georgia');
      case SerifFont.lora:
        return GoogleFonts.lora();
      case SerifFont.merriweather:
        return GoogleFonts.merriweather();
      case SerifFont.crimsonText:
        return GoogleFonts.crimsonText();
      case SerifFont.libreBaskerville:
        return GoogleFonts.libreBaskerville();
      case SerifFont.playfairDisplay:
        return GoogleFonts.playfairDisplay();
      case SerifFont.ebGaramond:
        return GoogleFonts.ebGaramond();
    }
  }

  /// Get the font family name for ThemeData
  String? getFontFamily() {
    if (this == SerifFont.georgia) {
      return 'Georgia';
    }
    return getTextStyle().fontFamily;
  }
}

/// Centralized theme configuration service
/// Allows switching serif fonts app-wide without modifying code throughout
class ThemeConfig {
  static final ThemeConfig _instance = ThemeConfig._internal();
  factory ThemeConfig() => _instance;
  ThemeConfig._internal();

  /// Current serif font selection (default: Georgia)
  final ValueNotifier<SerifFont> currentFont = ValueNotifier(SerifFont.georgia);

  /// Get the current serif font TextStyle
  TextStyle get serifFont => currentFont.value.getTextStyle();

  /// Get the current serif font family name
  String? get serifFontFamily => currentFont.value.getFontFamily();

  /// Change the serif font (triggers app-wide rebuild)
  void setFont(SerifFont font) {
    currentFont.value = font;
  }

  /// Get current font name for display
  String get currentFontName => currentFont.value.displayName;

  /// Get current font description
  String get currentFontDescription => currentFont.value.description;
}

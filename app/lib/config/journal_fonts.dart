import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography styles for the Journal feature.
///
/// Uses Google Fonts for Caveat (handwritten) and Playfair Display (serif).
/// These fonts create the scrapbook/journal aesthetic.
class JournalFonts {
  // ============================================
  // Color constants
  // ============================================

  static const Color _ink = Color(0xFF2D2D2D);
  static const Color _inkLight = Color(0xFF666666);

  // ============================================
  // Header styles
  // ============================================

  /// Main "Our Journal" header - large handwritten style
  static TextStyle get header => GoogleFonts.caveat(
        fontSize: 42,
        fontWeight: FontWeight.w600,
        color: _ink,
      );

  /// Week dates in navigation - medium handwritten
  static TextStyle get weekDates => GoogleFonts.caveat(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: _ink,
      );

  /// Day labels (Monday, Tuesday, etc.) - smaller handwritten
  static TextStyle get dayLabel => GoogleFonts.caveat(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: _ink,
      );

  // ============================================
  // Polaroid card styles
  // ============================================

  /// Caption below polaroid photo
  static TextStyle get polaroidCaption => GoogleFonts.caveat(
        fontSize: 16,
        color: _ink,
      );

  /// Type label under caption
  static TextStyle get polaroidType => TextStyle(
        fontSize: 10,
        color: _inkLight,
        letterSpacing: 0.5,
      );

  // ============================================
  // Bottom sheet styles
  // ============================================

  /// Title in detail bottom sheet
  static TextStyle get sheetTitle => GoogleFonts.caveat(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: _ink,
      );

  /// Section headers in bottom sheet
  static TextStyle get sectionTitle => GoogleFonts.caveat(
        fontSize: 22,
        color: _ink,
      );

  // ============================================
  // Insights card styles
  // ============================================

  /// Weekly insights card header - elegant serif
  static TextStyle get insightsHeader => GoogleFonts.playfairDisplay(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _ink,
      );

  /// Insight row headline
  static TextStyle get insightHeadline => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: _ink,
      );

  /// Insight row detail text
  static TextStyle get insightDetail => TextStyle(
        fontSize: 13,
        color: _inkLight,
        height: 1.4,
      );

  // ============================================
  // Loading screen styles
  // ============================================

  /// Serif title ("Your Journal") - for loading screen
  static TextStyle get loadingTitleSerif => GoogleFonts.playfairDisplay(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: _ink,
      );

  /// Handwritten title ("Our Journal") - for loading screen
  static TextStyle get loadingTitleHandwritten => GoogleFonts.caveat(
        fontSize: 48,
        fontWeight: FontWeight.w600,
        color: _ink,
      );

  /// Subtitle ("Memories written together...") - loading screen
  static TextStyle get loadingSubtitle => GoogleFonts.caveat(
        fontSize: 22,
        color: _inkLight,
      );

  /// Loading message ("Gathering your memories...")
  static TextStyle get loadingMessage => GoogleFonts.caveat(
        fontSize: 18,
        color: _inkLight,
      );

  /// "Tap to continue" prompt
  static TextStyle get tapToContinue => GoogleFonts.caveat(
        fontSize: 20,
        color: const Color(0xFFFF6B6B), // accent-pink
      );

  // ============================================
  // Week loading overlay styles
  // ============================================

  /// "Flipping pages..." text
  static TextStyle get weekLoadingText => GoogleFonts.caveat(
        fontSize: 24,
        color: _ink,
      );

  /// Week label in loading overlay
  static TextStyle get weekLoadingLabel => GoogleFonts.caveat(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: _inkLight,
      );

  // ============================================
  // Empty state styles
  // ============================================

  /// "Your story starts here" - empty state header
  static TextStyle get emptyStateHeader => GoogleFonts.caveat(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: _ink,
      );

  /// Empty state description text
  static TextStyle get emptyStateDescription => GoogleFonts.caveat(
        fontSize: 20,
        color: _inkLight,
      );
}

import 'package:flutter/animation.dart';
import 'package:flutter/widgets.dart';

/// Animation configuration for "Subtle & Elegant" personality
///
/// These constants define the timing, curves, and scale factors used
/// throughout the app for consistent, refined animations.
///
/// Accessibility: Use the context-aware methods (e.g., `durationFor()`)
/// to automatically respect the user's "reduce motion" preference.
class AnimationConfig {
  // ============================================
  // Durations
  // ============================================

  /// Instant feedback (100ms) - micro-interactions like haptic response
  static const Duration instant = Duration(milliseconds: 100);

  /// Fast animations (200ms) - button states, quick feedback
  static const Duration fast = Duration(milliseconds: 200);

  /// Normal transitions (300ms) - standard UI transitions
  static const Duration normal = Duration(milliseconds: 300);

  /// Slow emphasis (500ms) - deliberate attention-drawing animations
  static const Duration slow = Duration(milliseconds: 500);

  /// Dramatic reveals (800ms) - celebrations, important moments
  static const Duration dramatic = Duration(milliseconds: 800);

  /// Celebration entrance (1000ms) - score rings, achievement reveals
  static const Duration celebrationIn = Duration(milliseconds: 1000);

  /// Score reveals (1200ms) - counting up scores, progress rings
  static const Duration scoreReveal = Duration(milliseconds: 1200);

  /// Stagger delay between sequential items
  static const Duration staggerDelay = Duration(milliseconds: 100);

  // ============================================
  // Curves
  // ============================================

  /// Fade in - smooth deceleration
  static const Curve fadeIn = Curves.easeOut;

  /// Fade out - smooth acceleration
  static const Curve fadeOut = Curves.easeIn;

  /// Scale in - slight overshoot for pop effect
  static const Curve scaleIn = Curves.easeOutBack;

  /// Slide in - smooth cubic deceleration
  static const Curve slideIn = Curves.easeOutCubic;

  /// Elastic bounce - celebratory pop
  static const Curve elastic = Curves.elasticOut;

  /// Score reveal - dramatic slow-down at end
  static const Curve scoreRevealCurve = Curves.easeOutExpo;

  /// Button press - quick response
  static const Curve buttonPress = Curves.easeInOut;

  /// Standard transition
  static const Curve standard = Curves.easeInOutCubic;

  // ============================================
  // Scale Factors
  // ============================================

  /// Button press scale (subtle depression)
  static const double pressScale = 0.97;

  /// Secondary press scale (lighter touch)
  static const double lightPressScale = 0.98;

  /// Card lift scale (slight enlargement)
  static const double liftScale = 1.02;

  /// Celebration pop scale
  static const double celebrationScale = 1.05;

  /// Pulse range (min)
  static const double pulseMin = 0.95;

  /// Pulse range (max)
  static const double pulseMax = 1.05;

  // ============================================
  // Movement Distances
  // ============================================

  /// Small slide distance (16px)
  static const double slideSmall = 16.0;

  /// Medium slide distance (24px)
  static const double slideMedium = 24.0;

  /// Large slide distance (40px) - for page transitions
  static const double slideLarge = 40.0;

  /// Floating animation amplitude (4px)
  static const double floatAmplitude = 4.0;

  // ============================================
  // Opacity Values
  // ============================================

  /// Disabled state opacity
  static const double disabledOpacity = 0.5;

  /// Pressed state opacity
  static const double pressedOpacity = 0.8;

  /// Highlight overlay opacity
  static const double highlightOpacity = 0.1;

  // ============================================
  // Helper Methods
  // ============================================

  /// Get staggered delay for item at index
  static Duration staggerDelayFor(int index) {
    return Duration(milliseconds: 100 * index);
  }

  /// Get interval for staggered animation (for use with Interval curve)
  /// Returns start and end values between 0.0 and 1.0
  static ({double start, double end}) staggerInterval({
    required int index,
    required int totalItems,
    double overlap = 0.3, // How much animations overlap
  }) {
    if (totalItems <= 1) return (start: 0.0, end: 1.0);

    final itemDuration = 1.0 / (totalItems * (1 - overlap) + overlap);
    final start = index * itemDuration * (1 - overlap);
    final end = (start + itemDuration).clamp(0.0, 1.0);

    return (start: start, end: end);
  }

  // ============================================
  // Accessibility Helpers
  // ============================================

  /// Check if user has enabled "reduce motion" accessibility setting
  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Get duration respecting reduce motion preference
  /// Returns Duration.zero if reduce motion is enabled
  static Duration durationFor(BuildContext context, Duration duration) {
    return shouldReduceMotion(context) ? Duration.zero : duration;
  }

  /// Get scale factor respecting reduce motion preference
  /// Returns 1.0 (no scale change) if reduce motion is enabled
  static double scaleFor(BuildContext context, double scale) {
    return shouldReduceMotion(context) ? 1.0 : scale;
  }

  /// Check if animations should be enabled
  /// Convenience method for conditional animation code
  static bool animationsEnabled(BuildContext context) {
    return !shouldReduceMotion(context);
  }
}

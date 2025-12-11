import 'package:flutter/material.dart';

/// Animation constants based on ANIMATION_SPEC.md
/// Source of truth for all dramatic UI animations
class AnimationConstants {
  // ============================================
  // EASING CURVES
  // ============================================

  /// Primary overshoot curve - use for most entrances
  /// CSS: cubic-bezier(0.34, 1.56, 0.64, 1)
  static const Curve overshootCurve = Cubic(0.34, 1.56, 0.64, 1);

  /// Smooth out curve - for exits and progress
  /// CSS: cubic-bezier(0.25, 0.46, 0.45, 0.94)
  static const Curve smoothOutCurve = Cubic(0.25, 0.46, 0.45, 0.94);

  /// Standard ease - for ring expansion
  static const Curve standardCurve = Curves.easeInOut;

  // ============================================
  // DURATIONS
  // ============================================

  /// Particle burst effect duration
  static const Duration particleBurst = Duration(milliseconds: 800);

  /// Flash overlay duration
  static const Duration flash = Duration(milliseconds: 300);

  /// Ring expansion duration
  static const Duration ringExpand = Duration(milliseconds: 600);

  /// Standard card entrance
  static const Duration cardEntrance = Duration(milliseconds: 800);

  /// Dramatic card entrance (You-or-Me)
  static const Duration cardEntranceDramatic = Duration(milliseconds: 900);

  /// Button/answer slide in
  static const Duration slideIn = Duration(milliseconds: 500);

  /// Fast slide in
  static const Duration slideInFast = Duration(milliseconds: 400);

  /// Score/meter flip reveal
  static const Duration scoreFlip = Duration(milliseconds: 1000);

  /// Meter fill animation
  static const Duration meterFill = Duration(milliseconds: 1500);

  /// LP notification toast
  static const Duration lpNotification = Duration(milliseconds: 2500);

  /// Shine sweep effect
  static const Duration shineSweep = Duration(milliseconds: 2000);

  /// Confetti fall duration
  static const Duration confettiFall = Duration(milliseconds: 2500);

  /// Header drop animation
  static const Duration headerDrop = Duration(milliseconds: 700);

  /// Hero section reveal
  static const Duration heroReveal = Duration(milliseconds: 900);

  /// Button rise animation
  static const Duration buttonRise = Duration(milliseconds: 600);

  /// Cell pop animation (grid items)
  static const Duration cellPop = Duration(milliseconds: 400);

  /// Letter wave animation
  static const Duration letterWave = Duration(milliseconds: 300);

  /// Highlight line grow
  static const Duration highlightGrow = Duration(milliseconds: 600);

  // ============================================
  // STAGGER DELAYS
  // ============================================

  /// Answer options stagger (alternating left/right)
  static const List<Duration> answerDelays = [
    Duration(milliseconds: 700),
    Duration(milliseconds: 800),
    Duration(milliseconds: 900),
    Duration(milliseconds: 1000),
  ];

  /// Result cards stagger
  static const List<Duration> resultCardDelays = [
    Duration(milliseconds: 1400),
    Duration(milliseconds: 1500),
    Duration(milliseconds: 1600),
    Duration(milliseconds: 1700),
    Duration(milliseconds: 1800),
  ];

  /// Ring expansion stagger
  static const List<Duration> ringDelays = [
    Duration.zero,
    Duration(milliseconds: 100),
    Duration(milliseconds: 200),
  ];

  /// Header drop delay
  static const Duration headerDropDelay = Duration(milliseconds: 300);

  /// Card entrance delay
  static const Duration cardEntranceDelay = Duration(milliseconds: 400);

  /// Progress bar delay
  static const Duration progressBarDelay = Duration(milliseconds: 300);

  /// Hero section delay
  static const Duration heroRevealDelay = Duration(milliseconds: 500);

  /// Reward box delay
  static const Duration rewardBoxDelay = Duration(milliseconds: 1200);

  /// Button rise delay
  static const Duration buttonRiseDelay = Duration(milliseconds: 1400);

  /// Answer option base delay (first answer appears after this)
  static const Duration answerOptionBaseDelay = Duration(milliseconds: 700);

  /// Answer option stagger (between each answer)
  static const Duration answerOptionStagger = Duration(milliseconds: 100);

  /// Confetti trigger delay (after results screen loads)
  static const Duration confettiDelay = Duration(milliseconds: 500);

  // ============================================
  // PARTICLE SETTINGS
  // ============================================

  /// Default particle count for bursts
  static const int defaultParticleCount = 30;

  /// Minimum particle count
  static const int minParticleCount = 20;

  /// Maximum particle count
  static const int maxParticleCount = 40;

  /// Particle spread distance
  static const double particleSpread = 175.0;

  /// Minimum particle size
  static const double minParticleSize = 4.0;

  /// Maximum particle size
  static const double maxParticleSize = 12.0;

  // ============================================
  // RING SETTINGS
  // ============================================

  /// Number of expanding rings
  static const int ringCount = 3;

  /// Ring border width
  static const double ringBorderWidth = 3.0;

  // ============================================
  // 3D TRANSFORM VALUES
  // ============================================

  /// Perspective for 3D transforms
  static const double perspective = 0.001;

  /// Initial rotateX angle for header drop (in radians)
  static const double headerRotateXStart = -0.26; // ~-15 degrees

  /// Overshoot rotateX angle
  static const double headerRotateXOvershoot = 0.09; // ~5 degrees

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Calculate stagger delay for grid cells (Linked crossword)
  /// Base delay: 800ms, stagger: 50ms per cell
  static Duration cellStaggerDelay(int cellIndex) {
    return Duration(milliseconds: 800 + (cellIndex * 50));
  }

  /// Calculate wave delay for word search grid
  /// Base delay: 700ms, wave: 50ms per diagonal
  static Duration waveDelay(int row, int column) {
    return Duration(milliseconds: 700 + ((row + column) * 50));
  }

  /// Get alternating slide direction for index
  /// Odd indices slide from left, even from right
  static bool slidesFromLeft(int index) => index.isOdd;

  /// Check if animations should be reduced based on accessibility
  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }
}

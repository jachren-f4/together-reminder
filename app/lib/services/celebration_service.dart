import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../config/brand/brand_loader.dart';
import 'sound_service.dart';
import 'haptic_service.dart';

/// Types of celebrations available in the app
enum CelebrationType {
  /// Quest/puzzle completed - moderate celebration
  questComplete,

  /// Perfect score achieved - maximum celebration
  perfectScore,

  /// Match found in game - small celebration
  matchFound,

  /// Daily goal achieved - special celebration
  dailyGoal,

  /// Achievement unlocked - big celebration
  achievement,
}

/// Unified service for triggering celebrations across the app
///
/// Combines confetti, sounds, and haptic feedback into a single API.
/// Use this instead of manually managing confetti controllers everywhere.
///
/// Usage:
/// ```dart
/// // In your widget's initState or completion handler:
/// CelebrationService().celebrate(
///   CelebrationType.questComplete,
///   confettiController: _confettiController,
/// );
/// ```
class CelebrationService {
  static final CelebrationService _instance = CelebrationService._internal();
  factory CelebrationService() => _instance;
  CelebrationService._internal();

  final SoundService _soundService = SoundService();
  final HapticService _hapticService = HapticService();

  /// Trigger a celebration with sound, haptic, and optionally confetti
  ///
  /// [type] - The type of celebration to trigger
  /// [confettiController] - Optional confetti controller to play
  /// [delaySound] - Optional delay before playing sound (for sync with animations)
  Future<void> celebrate(
    CelebrationType type, {
    ConfettiController? confettiController,
    Duration delaySound = Duration.zero,
  }) async {
    // Trigger haptic immediately
    _triggerHaptic(type);

    // Start confetti if provided
    confettiController?.play();

    // Play sound (possibly delayed)
    if (delaySound > Duration.zero) {
      await Future.delayed(delaySound);
    }
    _playSound(type);
  }

  /// Play celebration sound only (no haptic or confetti)
  void playSound(CelebrationType type) {
    _playSound(type);
  }

  /// Trigger haptic only (no sound or confetti)
  void triggerHaptic(CelebrationType type) {
    _triggerHaptic(type);
  }

  void _playSound(CelebrationType type) {
    switch (type) {
      case CelebrationType.perfectScore:
      case CelebrationType.achievement:
        _soundService.play(SoundId.confettiBurst);
        break;
      case CelebrationType.questComplete:
      case CelebrationType.dailyGoal:
        _soundService.play(SoundId.chimeSuccess);
        break;
      case CelebrationType.matchFound:
        _soundService.play(SoundId.matchFound);
        break;
    }
  }

  void _triggerHaptic(CelebrationType type) {
    switch (type) {
      case CelebrationType.perfectScore:
      case CelebrationType.achievement:
        _hapticService.trigger(HapticType.heavy);
        // Double tap for extra emphasis
        Future.delayed(const Duration(milliseconds: 100), () {
          _hapticService.trigger(HapticType.medium);
        });
        break;
      case CelebrationType.questComplete:
      case CelebrationType.dailyGoal:
        _hapticService.trigger(HapticType.success);
        break;
      case CelebrationType.matchFound:
        _hapticService.trigger(HapticType.medium);
        break;
    }
  }

  /// Get brand-themed confetti colors
  ///
  /// Returns a list of colors based on the current brand theme.
  /// Use these when configuring your ConfettiWidget.
  List<Color> get confettiColors {
    final colors = BrandLoader().colors;
    return [
      colors.textPrimary,
      colors.textPrimary.withOpacity(0.87),
      colors.textPrimary.withOpacity(0.54),
      colors.success,
      colors.warning,
    ];
  }

  /// Get confetti colors for a specific celebration type
  List<Color> getConfettiColorsFor(CelebrationType type) {
    final colors = BrandLoader().colors;

    switch (type) {
      case CelebrationType.perfectScore:
        // Gold/sparkle colors for perfect score
        return [
          const Color(0xFFFFD700), // Gold
          const Color(0xFFFFA500), // Orange
          colors.textPrimary,
          colors.success,
        ];
      case CelebrationType.achievement:
        // Special achievement colors
        return [
          colors.textPrimary,
          colors.success,
          const Color(0xFF9C27B0), // Purple
          const Color(0xFF2196F3), // Blue
        ];
      default:
        return confettiColors;
    }
  }

  /// Create a pre-configured ConfettiWidget with brand colors
  ///
  /// Usage:
  /// ```dart
  /// Stack(
  ///   children: [
  ///     // Your content
  ///     CelebrationService().createConfettiWidget(_confettiController),
  ///   ],
  /// )
  /// ```
  Widget createConfettiWidget(
    ConfettiController controller, {
    CelebrationType type = CelebrationType.questComplete,
    AlignmentGeometry alignment = Alignment.topCenter,
    double blastDirection = 3.14159 / 2, // Downward
  }) {
    return Align(
      alignment: alignment,
      child: ConfettiWidget(
        confettiController: controller,
        blastDirection: blastDirection,
        maxBlastForce: _getMaxBlastForce(type),
        minBlastForce: _getMinBlastForce(type),
        emissionFrequency: _getEmissionFrequency(type),
        numberOfParticles: _getParticleCount(type),
        gravity: 0.1,
        shouldLoop: false,
        colors: getConfettiColorsFor(type),
      ),
    );
  }

  double _getMaxBlastForce(CelebrationType type) {
    switch (type) {
      case CelebrationType.perfectScore:
      case CelebrationType.achievement:
        return 10;
      case CelebrationType.questComplete:
      case CelebrationType.dailyGoal:
        return 5;
      case CelebrationType.matchFound:
        return 3;
    }
  }

  double _getMinBlastForce(CelebrationType type) {
    switch (type) {
      case CelebrationType.perfectScore:
      case CelebrationType.achievement:
        return 5;
      case CelebrationType.questComplete:
      case CelebrationType.dailyGoal:
        return 2;
      case CelebrationType.matchFound:
        return 1;
    }
  }

  double _getEmissionFrequency(CelebrationType type) {
    switch (type) {
      case CelebrationType.perfectScore:
      case CelebrationType.achievement:
        return 0.03; // More frequent
      case CelebrationType.questComplete:
      case CelebrationType.dailyGoal:
        return 0.05;
      case CelebrationType.matchFound:
        return 0.1; // Less frequent
    }
  }

  int _getParticleCount(CelebrationType type) {
    switch (type) {
      case CelebrationType.perfectScore:
      case CelebrationType.achievement:
        return 40;
      case CelebrationType.questComplete:
      case CelebrationType.dailyGoal:
        return 25;
      case CelebrationType.matchFound:
        return 10;
    }
  }
}

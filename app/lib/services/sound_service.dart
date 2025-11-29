import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/logger.dart';

/// Sound effect identifiers
///
/// Use these constants when calling [SoundService.play]
class SoundId {
  // UI sounds
  static const String tapSoft = 'ui/tap_soft';
  static const String tapLight = 'ui/tap_light';
  static const String toggleOn = 'ui/toggle_on';
  static const String toggleOff = 'ui/toggle_off';

  // Celebration sounds
  static const String confettiBurst = 'celebration/confetti_burst';
  static const String sparkle = 'celebration/sparkle';
  static const String chimeSuccess = 'celebration/chime_success';

  // Feedback sounds
  static const String success = 'feedback/success';
  static const String error = 'feedback/error';
  static const String warning = 'feedback/warning';

  // Game sounds
  static const String cardFlip = 'games/card_flip';
  static const String matchFound = 'games/match_found';
  static const String wordFound = 'games/word_found';
  static const String letterType = 'games/letter_type';
  static const String answerSelect = 'games/answer_select';
}

/// Centralized sound effect service
///
/// Provides unified sound playback across the app with user preference toggle.
/// Supports both shared and brand-specific sounds.
/// Automatically disabled on web platform (for stability).
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  static const String _prefsKey = 'sound_enabled';
  static const String _basePath = 'assets/shared/sounds';

  bool _isEnabled = true;
  bool _isInitialized = false;
  final AudioPlayer _player = AudioPlayer();

  // Cache for preloaded sounds
  final Map<String, Source> _soundCache = {};

  /// Whether sound effects are currently enabled
  /// Note: Web sounds enabled for testing (audioplayers supports web)
  bool get isEnabled => _isEnabled;

  /// Initialize the service and load user preference
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final box = Hive.box('app_metadata');
      _isEnabled = box.get(_prefsKey, defaultValue: true) as bool;
      _isInitialized = true;

      // Configure audio player for short sound effects
      await _player.setReleaseMode(ReleaseMode.stop);

      Logger.debug('SoundService initialized, enabled: $_isEnabled', service: 'sound');
    } catch (e) {
      Logger.error('Failed to initialize SoundService', error: e, service: 'sound');
      _isEnabled = true; // Default to enabled
      _isInitialized = true;
    }
  }

  /// Set sound effects enabled/disabled
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    try {
      final box = Hive.box('app_metadata');
      await box.put(_prefsKey, enabled);
      Logger.debug('SoundService enabled set to: $enabled', service: 'sound');
    } catch (e) {
      Logger.error('Failed to save sound preference', error: e, service: 'sound');
    }
  }

  /// Play a sound effect by ID
  ///
  /// [soundId] should be one of the constants from [SoundId]
  /// Does nothing if sounds are disabled or on web platform.
  Future<void> play(String soundId) async {
    // print('🔊 SoundService.play called: $soundId, isEnabled: $isEnabled');
    if (!isEnabled) return;

    try {
      final path = '$_basePath/$soundId.mp3';

      // Use cached source if available
      Source source;
      if (_soundCache.containsKey(soundId)) {
        source = _soundCache[soundId]!;
      } else {
        source = AssetSource(path.replaceFirst('assets/', ''));
        _soundCache[soundId] = source;
      }

      await _player.play(source);
      // Logger.debug('Playing sound: $soundId', service: 'sound');
    } catch (e) {
      // Silently fail - sounds are non-critical
      Logger.debug('Sound playback failed for $soundId: $e', service: 'sound');
    }
  }

  /// Preload sounds for faster playback
  ///
  /// Call this during app initialization for critical sounds
  Future<void> preload(List<String> soundIds) async {
    // Web preloading enabled for testing
    for (final soundId in soundIds) {
      try {
        final path = '$_basePath/$soundId.mp3';
        final source = AssetSource(path.replaceFirst('assets/', ''));
        _soundCache[soundId] = source;
        Logger.debug('Preloaded sound: $soundId', service: 'sound');
      } catch (e) {
        Logger.debug('Failed to preload sound $soundId: $e', service: 'sound');
      }
    }
  }

  /// Stop any currently playing sound
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      Logger.debug('Failed to stop sound: $e', service: 'sound');
    }
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      Logger.debug('Failed to set volume: $e', service: 'sound');
    }
  }

  // ============================================
  // Convenience methods for common sounds
  // ============================================

  /// Play tap sound (primary button)
  Future<void> tap() => play(SoundId.tapSoft);

  /// Play light tap sound (secondary button)
  Future<void> tapLight() => play(SoundId.tapLight);

  /// Play toggle on sound
  Future<void> toggleOn() => play(SoundId.toggleOn);

  /// Play toggle off sound
  Future<void> toggleOff() => play(SoundId.toggleOff);

  /// Play celebration/confetti sound
  Future<void> celebrate() => play(SoundId.confettiBurst);

  /// Play success sound
  Future<void> success() => play(SoundId.success);

  /// Play error sound
  Future<void> error() => play(SoundId.error);

  /// Play card flip sound
  Future<void> cardFlip() => play(SoundId.cardFlip);

  /// Play match found sound
  Future<void> matchFound() => play(SoundId.matchFound);

  /// Play word found sound
  Future<void> wordFound() => play(SoundId.wordFound);

  /// Dispose the audio player
  void dispose() {
    _player.dispose();
  }
}

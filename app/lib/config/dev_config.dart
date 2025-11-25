import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../utils/logger.dart';

/// Development configuration for testing and debugging
class DevConfig {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static bool? _cachedIsSimulator;

  /// Skip Supabase authentication in development mode
  /// Set to true to bypass auth flow during development
  /// Set to false when you need to test auth functionality
  static const bool skipAuthInDev = true;

  // ============================================================================
  // PHASE 4 MIGRATION FEATURE FLAGS
  // ============================================================================
  // These flags enable gradual migration from Firebase → Supabase
  // ALL FLAGS ARE FALSE BY DEFAULT - existing code still works
  // Enable individually to test specific migration pieces

  /// Use Supabase for Daily Quests (instead of Firebase RTDB)
  /// FALSE = Firebase RTDB (current/stable)
  /// TRUE = Supabase API (Phase 4 migration)
  static const bool useSuperbaseForDailyQuests = false;

  /// Use Supabase for Love Points (instead of Firebase RTDB)
  /// FALSE = Firebase RTDB (current/stable)
  /// TRUE = Supabase API (Phase 4 migration)
  static const bool useSupabaseForLovePoints = false;

  /// Use Supabase for Memory Flip (instead of Firebase RTDB)
  /// FALSE = Firebase RTDB (current/stable)
  /// TRUE = Supabase API (Phase 4 migration)
  static const bool useSupabaseForMemoryFlip = false;

  /// Use Supabase for You or Me (instead of Firebase RTDB)
  /// FALSE = Firebase RTDB (current/stable)
  /// TRUE = Supabase API (Phase 4 migration)
  static const bool useSupabaseForYouOrMe = false;

  /// Development User IDs for API auth bypass
  /// These IDs are sent to the API via X-Dev-User-Id header
  /// Only active when API has AUTH_DEV_BYPASS_ENABLED=true
  ///
  /// Usage: Android uses devUserIdAndroid, Chrome/Web uses devUserIdWeb
  /// This allows two-device testing with different users simultaneously
  ///
  /// **IMPORTANT**: Replace with your actual user IDs from database:
  ///   SELECT user1_id, user2_id FROM couples LIMIT 1;
  static const String devUserIdAndroid = 'c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28';  // user1_id
  static const String devUserIdWeb = 'd71425a3-a92f-404e-bfbe-a54c4cb58b6a';      // user2_id

  /// Detect if running on iOS/Android simulator or emulator
  /// Returns true ONLY when running in a simulator/emulator
  /// Returns false when running on a real physical device
  static Future<bool> get isSimulator async {
    // Only enable in debug mode - never in release builds
    if (!kDebugMode) return false;

    // Web is always treated as a "simulator" for development purposes
    if (kIsWeb) {
      _cachedIsSimulator = true;
      // Removed verbose logging
      // print('🌐 Web Platform: Treated as simulator for dev mode');
      return true;
    }

    // Return cached value if available (avoid repeated async calls)
    if (_cachedIsSimulator != null) return _cachedIsSimulator!;

    try {
      if (Platform.isIOS) {
        // Use device_info_plus to check if it's a physical device
        final iosInfo = await _deviceInfo.iosInfo;

        // isPhysicalDevice is false for simulators, true for real devices
        _cachedIsSimulator = !iosInfo.isPhysicalDevice;

        Logger.debug('iOS Device Detection:', service: 'debug');
        Logger.debug('Device: ${iosInfo.name}', service: 'debug');
        Logger.debug('Model: ${iosInfo.model}', service: 'debug');
        Logger.debug('isPhysicalDevice: ${iosInfo.isPhysicalDevice}', service: 'debug');
        Logger.debug('isSimulator: $_cachedIsSimulator', service: 'debug');

        return _cachedIsSimulator!;
      }

      if (Platform.isAndroid) {
        // Use device_info_plus to check if it's a physical device
        final androidInfo = await _deviceInfo.androidInfo;

        // isPhysicalDevice is false for emulators, true for real devices
        _cachedIsSimulator = !androidInfo.isPhysicalDevice;

        Logger.debug('Android Device Detection:', service: 'debug');
        Logger.debug('Device: ${androidInfo.device}', service: 'debug');
        Logger.debug('Model: ${androidInfo.model}', service: 'debug');
        Logger.debug('isPhysicalDevice: ${androidInfo.isPhysicalDevice}', service: 'debug');
        Logger.debug('isSimulator: $_cachedIsSimulator', service: 'debug');

        return _cachedIsSimulator!;
      }
    } catch (e) {
      Logger.warn('Error detecting device type: $e', service: 'debug');
      // If detection fails, assume real device (safer default)
      _cachedIsSimulator = false;
      return false;
    }

    return false;
  }

  /// Synchronous version for quick checks (uses cached value)
  /// Returns false if not yet determined
  static bool get isSimulatorSync {
    // Web is always a "simulator" in dev mode
    if (kIsWeb && kDebugMode) return true;
    return _cachedIsSimulator ?? false;
  }

  /// Enable automatic mock data injection on startup
  /// Only works in debug mode on simulators/emulators
  ///
  /// **DEPRECATED:** Now using real data from Supabase via dev auth bypass
  /// Mock data is no longer needed when using skipAuthInDev
  static Future<bool> get enableMockPairing async {
    if (!kDebugMode) return false;
    // Disabled - using real data from Supabase instead of mock data
    return false;
  }

  // Mock data configuration
  static const String mockPartnerName = 'Alex';
  static const String mockPartnerEmoji = '🧑‍💻';
  static const String mockUserName = 'You';

  /// Get unique emulator identifier from Android serial, AVD name, or web
  /// Returns 'emulator-5554', 'emulator-5556', 'web-bob', 'web-alice', etc.
  static Future<String?> get emulatorId async {
    // Web: Always return web-bob (dual Chrome not feasible with single origin)
    if (kIsWeb) {
      // Removed verbose logging
      // print('🌐 Platform: Web (Bob)');
      return 'web-bob';
    }

    if (!await isSimulator) return null;

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;

        // Method 1: Check AVD name from system property
        try {
          final result = await Process.run('getprop', ['ro.kernel.qemu.avd_name']);
          if (result.exitCode == 0) {
            final avdName = result.stdout.toString().trim();
            // Removed verbose logging
            // Logger.debug('AVD Name: $avdName', service: 'debug');

            // Pixel_5 = Alice (emulator-5554)
            // Pixel_5_Partner2 = Bob (emulator-5556)
            if (avdName == 'Pixel_5_Partner2') {
              // Removed verbose logging
              // Logger.debug('Emulator ID (AVD): emulator-5556', service: 'debug');
              return 'emulator-5556';
            } else if (avdName == 'Pixel_5') {
              // Removed verbose logging
              // Logger.debug('Emulator ID (AVD): emulator-5554', service: 'debug');
              return 'emulator-5554';
            }
          }
        } catch (e) {
          // Removed verbose logging
          // Logger.warn('Could not get AVD name: $e', service: 'debug');
        }

        // Method 2: Use serialNumber (works on older Android)
        if (androidInfo.serialNumber != null &&
            androidInfo.serialNumber != 'unknown' &&
            androidInfo.serialNumber.startsWith('emulator-')) {
          // Removed verbose logging
          // Logger.debug('Emulator ID (serial): ${androidInfo.serialNumber}', service: 'debug');
          return androidInfo.serialNumber;
        }

        // Method 3: Default to first emulator if we can't detect
        // Removed verbose logging
        // Logger.warn('Could not detect emulator ID, defaulting to emulator-5554', service: 'debug');
        return 'emulator-5554';
      }
    } catch (e) {
      // Removed verbose logging
      // Logger.warn('Error getting emulator ID: $e', service: 'debug');
    }
    return null;
  }

  /// Determine partner index (0 = Partner A, 1 = Partner B)
  /// Based on emulator port number or platform
  static Future<int> get partnerIndex async {
    final id = await emulatorId;
    if (id == null) return 0;

    // Web: Check emulator ID
    if (kIsWeb) {
      if (id == 'web-alice') {
        // Removed verbose logging
        // Logger.debug('Partner Index: 0 (Web = Alice)', service: 'debug');
        return 0;
      } else {
        // Removed verbose logging
        // Logger.debug('Partner Index: 1 (Web = Bob)', service: 'debug');
        return 1;
      }
    }

    // Parse port number from "emulator-5554"
    final match = RegExp(r'emulator-(\d+)').firstMatch(id);
    if (match != null) {
      final port = int.parse(match.group(1)!);
      // 5554 = Partner A (0), 5556 = Partner B (1), 5558 = Partner C (2)...
      final index = (port - 5554) ~/ 2;
      // Removed verbose logging
      // Logger.debug('Partner Index: $index (port: $port)', service: 'debug');
      return index;
    }
    return 0;
  }

  /// Partner configurations for dual-emulator testing
  /// Index 0 = Alice, Index 1 = Bob
  static const List<Map<String, String>> dualPartnerConfig = [
    {
      'name': 'Alice',
      'emoji': '👩',
      'partnerName': 'Bob',
      'partnerEmoji': '👨'
    },
    {
      'name': 'Bob',
      'emoji': '👨',
      'partnerName': 'Alice',
      'partnerEmoji': '👩'
    },
  ];

  /// Deterministic user IDs for dual-emulator testing
  /// These MUST be stable across app restarts for couple ID consistency
  /// Index 0 = Alice's user ID, Index 1 = Bob's user ID
  static const List<String> dualPartnerUserIds = [
    'alice-dev-user-00000000-0000-0000-0000-000000000001',
    'bob-dev-user-00000000-0000-0000-0000-000000000002',
  ];
}

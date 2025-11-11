import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Development configuration for testing and debugging
class DevConfig {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static bool? _cachedIsSimulator;

  /// Detect if running on iOS/Android simulator or emulator
  /// Returns true ONLY when running in a simulator/emulator
  /// Returns false when running on a real physical device
  static Future<bool> get isSimulator async {
    // Only enable in debug mode - never in release builds
    if (!kDebugMode) return false;

    // Web is always treated as a "simulator" for development purposes
    if (kIsWeb) {
      _cachedIsSimulator = true;
      print('🌐 Web Platform: Treated as simulator for dev mode');
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

        print('🔍 iOS Device Detection:');
        print('   Device: ${iosInfo.name}');
        print('   Model: ${iosInfo.model}');
        print('   isPhysicalDevice: ${iosInfo.isPhysicalDevice}');
        print('   isSimulator: $_cachedIsSimulator');

        return _cachedIsSimulator!;
      }

      if (Platform.isAndroid) {
        // Use device_info_plus to check if it's a physical device
        final androidInfo = await _deviceInfo.androidInfo;

        // isPhysicalDevice is false for emulators, true for real devices
        _cachedIsSimulator = !androidInfo.isPhysicalDevice;

        print('🔍 Android Device Detection:');
        print('   Device: ${androidInfo.device}');
        print('   Model: ${androidInfo.model}');
        print('   isPhysicalDevice: ${androidInfo.isPhysicalDevice}');
        print('   isSimulator: $_cachedIsSimulator');

        return _cachedIsSimulator!;
      }
    } catch (e) {
      print('⚠️ Error detecting device type: $e');
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
  /// When enabled:
  /// - Auto-creates mock partner "Alex" with fake push token
  /// - Injects 10 varied reminders (sent/received, pending/done/snoozed)
  /// - Bypasses QR pairing flow for rapid testing
  static Future<bool> get enableMockPairing async {
    if (!kDebugMode) return false;
    // Always enable mock data in debug mode for gamification development
    return true;
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
      print('🌐 Platform: Web (Bob)');
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
            print('🔍 AVD Name: $avdName');

            // Pixel_5 = Alice (emulator-5554)
            // Pixel_5_Partner2 = Bob (emulator-5556)
            if (avdName == 'Pixel_5_Partner2') {
              print('🔍 Emulator ID (AVD): emulator-5556');
              return 'emulator-5556';
            } else if (avdName == 'Pixel_5') {
              print('🔍 Emulator ID (AVD): emulator-5554');
              return 'emulator-5554';
            }
          }
        } catch (e) {
          print('⚠️ Could not get AVD name: $e');
        }

        // Method 2: Use serialNumber (works on older Android)
        if (androidInfo.serialNumber != null &&
            androidInfo.serialNumber != 'unknown' &&
            androidInfo.serialNumber.startsWith('emulator-')) {
          print('🔍 Emulator ID (serial): ${androidInfo.serialNumber}');
          return androidInfo.serialNumber;
        }

        // Method 3: Default to first emulator if we can't detect
        print('⚠️ Could not detect emulator ID, defaulting to emulator-5554');
        return 'emulator-5554';
      }
    } catch (e) {
      print('⚠️ Error getting emulator ID: $e');
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
        print('🔍 Partner Index: 0 (Web = Alice)');
        return 0;
      } else {
        print('🔍 Partner Index: 1 (Web = Bob)');
        return 1;
      }
    }

    // Parse port number from "emulator-5554"
    final match = RegExp(r'emulator-(\d+)').firstMatch(id);
    if (match != null) {
      final port = int.parse(match.group(1)!);
      // 5554 = Partner A (0), 5556 = Partner B (1), 5558 = Partner C (2)...
      final index = (port - 5554) ~/ 2;
      print('🔍 Partner Index: $index (port: $port)');
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
}

import 'dart:async';
import '../utils/logger.dart';

import 'package:firebase_database/firebase_database.dart';
import 'package:togetherremind/config/dev_config.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/models/partner.dart';
import '../utils/logger.dart';

/// Development service for auto-pairing emulators via Firebase RTDB
/// Only active in debug mode on simulators
///
/// NOTE: With deterministic user IDs (DevConfig.dualPartnerUserIds),
/// couple ID generation now works automatically without needing to exchange
/// user IDs. This service now only registers FCM tokens for potential
/// push notification testing (currently not used).
class DevPairingService {
  static final DevPairingService _instance = DevPairingService._internal();
  factory DevPairingService() => _instance;
  DevPairingService._internal();

  final DatabaseReference _rtdb = FirebaseDatabase.instance.ref();
  final StorageService _storage = StorageService();

  bool _isListening = false;

  /// Auto-pair this emulator with its partner
  /// Call this after MockDataService creates initial data
  Future<void> startAutoPairing() async {
    // Only run in debug mode on simulators
    if (!DevConfig.isSimulatorSync) {
      Logger.info('DevPairingService: Not a simulator, skipping auto-pairing', service: 'pairing');
      return;
    }

    final user = _storage.getUser();
    if (user == null) {
      Logger.warn('DevPairingService: No user found, cannot start pairing', service: 'pairing');
      return;
    }

    final emulatorId = await DevConfig.emulatorId;
    if (emulatorId == null) {
      Logger.warn('DevPairingService: Could not determine emulator ID', service: 'pairing');
      return;
    }

    final partnerIndex = await DevConfig.partnerIndex;
    final config = DevConfig.dualPartnerConfig[partnerIndex];

    // Removed verbose logging
    // print('🔗 DevPairingService: Pairing with deterministic IDs...');
    // print('   Emulator: $emulatorId');
    // print('   My name: ${config['name']}');
    // print('   Partner: ${config['partnerName']}');
    // print('   ℹ️  Using deterministic user IDs - couple ID is automatic!');

    // Register this emulator's FCM token in RTDB (for future push notification testing)
    await _registerEmulator(emulatorId, user.pushToken, config['name']!);

    // Removed verbose logging
    // Logger.success('Pairing complete! Both devices will use the same couple ID.', service: 'pairing');
  }

  /// Register this emulator's FCM token in RTDB
  /// (For future push notification testing - not currently used)
  Future<void> _registerEmulator(String emulatorId, String fcmToken, String name) async {
    try {
      await _rtdb.child('dev_emulators').child(emulatorId).set({
        'fcmToken': fcmToken,
        'name': name,
        'timestamp': ServerValue.timestamp,
      }).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          Logger.warn('RTDB registration timed out (network issue)', service: 'pairing');
          throw TimeoutException('Firebase RTDB write timed out');
        },
      );
      // Removed verbose logging
      // print('   Registered FCM token in RTDB: $name ($emulatorId)');
    } catch (e) {
      Logger.error('Error registering emulator', error: e, service: 'pairing');
    }
  }

  /// Clean up RTDB entry when app closes (optional)
  Future<void> cleanup() async {
    final emulatorId = await DevConfig.emulatorId;
    if (emulatorId != null) {
      await _rtdb.child('dev_emulators').child(emulatorId).remove();
      print('🧹 Cleaned up RTDB entry for $emulatorId');
    }
  }
}

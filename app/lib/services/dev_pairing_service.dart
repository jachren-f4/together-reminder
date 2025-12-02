import 'dart:async';
import '../utils/logger.dart';
import 'package:togetherremind/config/dev_config.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/models/partner.dart';

/// Development service for auto-pairing emulators
/// Only active in debug mode on simulators
///
/// NOTE: With deterministic user IDs (DevConfig.dualPartnerUserIds),
/// couple ID generation works automatically without needing to exchange
/// user IDs. Firebase RTDB is no longer used.
///
/// Architecture (Supabase-only):
/// - User/partner data loaded from Supabase via /api/dev/user-data
/// - Couple ID generated from deterministic user IDs
/// - No Firebase RTDB usage
class DevPairingService {
  static final DevPairingService _instance = DevPairingService._internal();
  factory DevPairingService() => _instance;
  DevPairingService._internal();

  final StorageService _storage = StorageService();

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

    Logger.debug('DevPairingService: Using deterministic IDs (no Firebase needed)', service: 'pairing');
    Logger.debug('   Emulator: $emulatorId', service: 'pairing');
    Logger.debug('   My name: ${config['name']}', service: 'pairing');
    Logger.debug('   Partner: ${config['partnerName']}', service: 'pairing');
  }

  /// Clean up (no-op since Firebase is no longer used)
  Future<void> cleanup() async {
    Logger.debug('DevPairingService cleanup (no-op)', service: 'pairing');
  }
}

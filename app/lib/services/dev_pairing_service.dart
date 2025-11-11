import 'package:firebase_database/firebase_database.dart';
import 'package:togetherremind/config/dev_config.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/models/partner.dart';

/// Development service for auto-pairing emulators via Firebase RTDB
/// Only active in debug mode on simulators
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
      print('ℹ️  DevPairingService: Not a simulator, skipping auto-pairing');
      return;
    }

    final user = _storage.getUser();
    if (user == null) {
      print('⚠️ DevPairingService: No user found, cannot start pairing');
      return;
    }

    final emulatorId = await DevConfig.emulatorId;
    if (emulatorId == null) {
      print('⚠️ DevPairingService: Could not determine emulator ID');
      return;
    }

    final partnerIndex = await DevConfig.partnerIndex;
    final config = DevConfig.dualPartnerConfig[partnerIndex];

    print('🔗 DevPairingService: Starting auto-pairing...');
    print('   Emulator: $emulatorId');
    print('   My name: ${config['name']}');
    print('   Partner: ${config['partnerName']}');

    // Register this emulator's FCM token in RTDB
    await _registerEmulator(emulatorId, user.pushToken, config['name']!);

    // Listen for partner's token
    await _listenForPartnerToken(emulatorId, config['partnerName']!);
  }

  /// Register this emulator's FCM token in RTDB
  Future<void> _registerEmulator(String emulatorId, String fcmToken, String name) async {
    try {
      await _rtdb.child('dev_emulators').child(emulatorId).set({
        'fcmToken': fcmToken,
        'name': name,
        'timestamp': ServerValue.timestamp,
      });
      print('✅ Registered in RTDB: $name ($emulatorId)');
    } catch (e) {
      print('❌ Error registering emulator: $e');
    }
  }

  /// Listen for partner's FCM token and update local storage
  Future<void> _listenForPartnerToken(String myEmulatorId, String partnerName) async {
    if (_isListening) return;
    _isListening = true;

    // Determine partner's emulator ID based on my index
    // Index 0 (Alice, emulator-5554) → listens for Index 1 (Bob, web-bob or emulator-5556)
    // Index 1 (Bob, web-bob) → listens for Index 0 (Alice, emulator-5554)
    final myIndex = await DevConfig.partnerIndex;
    final partnerConfig = DevConfig.dualPartnerConfig[(myIndex + 1) % 2];

    // Determine partner's emulator ID
    // If partner is index 0 (Alice), they use emulator-5554 or web-alice
    // If partner is index 1 (Bob), they use web-bob or emulator-5556
    // For now, hardcode: Alice=emulator-5554, Bob=web-bob
    final partnerEmulatorId = myIndex == 0 ? 'web-bob' : 'emulator-5554';

    print('👂 Listening for partner: $partnerEmulatorId ($partnerName)...');

    _rtdb.child('dev_emulators').child(partnerEmulatorId).onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final partnerToken = data['fcmToken'] as String?;

        if (partnerToken != null && partnerToken != 'awaiting_pairing') {
          _updatePartnerToken(partnerToken, partnerName);
        }
      }
    });
  }

  /// Update partner's FCM token in local storage
  Future<void> _updatePartnerToken(String token, String partnerName) async {
    final partner = _storage.getPartner();
    if (partner == null) {
      print('⚠️ No partner found in storage');
      return;
    }

    // Only update if token has changed
    if (partner.pushToken == token) {
      return;
    }

    partner.pushToken = token;
    await partner.save();

    print('✅ Partner paired! Updated ${partnerName}\'s FCM token');
    print('   Token: ${token.substring(0, 20)}...');
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

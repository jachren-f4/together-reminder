import '../models/partner.dart';
import '../utils/logger.dart';
import 'api_client.dart';
import 'play_mode_service.dart';
import 'storage_service.dart';

/// Service for creating and managing phantom partners.
///
/// A phantom partner is a real Supabase Auth account that nobody logs into.
/// It represents the partner in single-phone mode, allowing all game APIs
/// to work unchanged because the server always sees two real user IDs.
class PhantomPartnerService {
  static final PhantomPartnerService _instance = PhantomPartnerService._internal();
  factory PhantomPartnerService() => _instance;
  PhantomPartnerService._internal();

  final _apiClient = ApiClient();
  final _storage = StorageService();
  final _playMode = PlayModeService();

  /// Create a phantom partner and pair with the current user.
  ///
  /// Calls POST /api/couples/create-with-phantom with the partner's name.
  /// On success:
  /// - Stores phantom state in PlayModeService
  /// - Saves Partner model to Hive (for UI display)
  ///
  /// Returns the couple ID on success, throws on failure.
  Future<String> createPhantomPartner(String partnerName) async {
    Logger.info('Creating phantom partner: $partnerName', service: 'phantom');

    final response = await _apiClient.post(
      '/api/couples/create-with-phantom',
      body: {'partnerName': partnerName},
    );

    if (!response.success || response.data == null) {
      final error = response.error ?? 'Unknown error';
      Logger.error('Failed to create phantom partner: $error', service: 'phantom');
      throw Exception('Failed to create phantom partner: $error');
    }

    final data = response.data as Map<String, dynamic>;
    final coupleId = data['coupleId'] as String;
    final phantomUserId = data['phantomUserId'] as String;
    final name = data['partnerName'] as String;

    // Store phantom state
    await _playMode.setPhantomPartner(phantomUserId, name);

    // Save partner model to Hive for UI display
    final partner = Partner(
      id: phantomUserId,
      name: name,
      pushToken: '', // Phantom users don't have push tokens
      pairedAt: DateTime.now(),
      avatarEmoji: '💕',
    );
    await _storage.savePartner(partner);

    Logger.success('Phantom partner created: $name (couple: $coupleId)', service: 'phantom');
    return coupleId;
  }
}

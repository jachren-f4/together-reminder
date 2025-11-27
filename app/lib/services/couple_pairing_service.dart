import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/logger.dart';
import '../models/partner.dart';
import '../models/pairing_code.dart';
import 'storage_service.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'notification_service.dart';

/// Service for couple pairing using Supabase API
/// Replaces Firebase-based remote pairing with API calls
class CouplePairingService {
  static final CouplePairingService _instance =
      CouplePairingService._internal();
  factory CouplePairingService() => _instance;
  CouplePairingService._internal();

  final ApiClient _apiClient = ApiClient();
  final StorageService _storage = StorageService();
  final AuthService _authService = AuthService();
  final _secureStorage = const FlutterSecureStorage();

  static const _keyCoupleId = 'couple_id';

  /// Generate a new pairing code
  /// Returns PairingCode with 6-digit code and expiration time
  Future<PairingCode> generatePairingCode() async {
    // Use async token check to avoid race condition with auth state updates
    final token = await _authService.getAccessToken();
    if (token == null) {
      throw Exception('Not authenticated. Please sign in.');
    }

    try {
      // Get push token to include with invite (for partner notification)
      final pushToken = await NotificationService.getToken();

      final response = await _apiClient.post(
        '/api/couples/invite',
        body: pushToken != null ? {'pushToken': pushToken} : null,
      );

      if (!response.success) {
        throw Exception(response.error ?? 'Failed to generate code');
      }

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as String;
      final expiresAtStr = data['expiresAt'] as String;
      final expiresAt = DateTime.parse(expiresAtStr);

      Logger.success('Generated pairing code: $code', service: 'pairing');

      return PairingCode(
        code: code,
        expiresAt: expiresAt,
      );
    } catch (e) {
      Logger.error('Error generating pairing code', error: e, service: 'pairing');
      rethrow;
    }
  }

  /// Get current active invite code (if any)
  Future<PairingCode?> getCurrentInviteCode() async {
    // Use async token check to avoid race condition with auth state updates
    final token = await _authService.getAccessToken();
    if (token == null) {
      return null;
    }

    try {
      final response = await _apiClient.get('/api/couples/invite');

      if (!response.success) {
        return null;
      }

      final data = response.data as Map<String, dynamic>;
      final code = data['code'];

      if (code == null) {
        return null;
      }

      final expiresAtStr = data['expiresAt'] as String;
      final expiresAt = DateTime.parse(expiresAtStr);

      return PairingCode(
        code: code as String,
        expiresAt: expiresAt,
      );
    } catch (e) {
      Logger.error('Error fetching invite code', error: e, service: 'pairing');
      return null;
    }
  }

  /// Pair with a partner using their code
  /// Returns Partner object after successful pairing
  Future<Partner> joinWithCode(String code) async {
    // Use async token check to avoid race condition with auth state updates
    final token = await _authService.getAccessToken();
    if (token == null) {
      throw Exception('Not authenticated. Please sign in.');
    }

    if (code.trim().length != 6) {
      throw Exception('Code must be 6 digits');
    }

    try {
      final response = await _apiClient.post(
        '/api/couples/join',
        body: {'code': code.trim()},
      );

      if (!response.success) {
        throw Exception(response.error ?? 'Failed to join couple');
      }

      final data = response.data as Map<String, dynamic>;

      // Create partner object
      // Use partnerName from API response (extracted from user metadata)
      // Fall back to email parsing if name not available
      final partner = Partner(
        name: data['partnerName'] as String? ??
              data['partnerEmail']?.split('@').first ??
              'Partner',
        pushToken: '', // Will be set up separately
        pairedAt: DateTime.now(),
        avatarEmoji: '💕',
      );

      // Save partner to local storage
      await _storage.savePartner(partner);

      // Store couple ID for future API calls
      final coupleId = data['coupleId'] as String;
      await _secureStorage.write(key: _keyCoupleId, value: coupleId);

      Logger.success('Paired with: ${partner.name}', service: 'pairing');

      return partner;
    } catch (e) {
      Logger.error('Error joining with code', error: e, service: 'pairing');
      rethrow;
    }
  }

  /// Check current pairing status
  /// Returns partner info if paired, null otherwise
  Future<CoupleStatus?> getStatus() async {
    // Use async token check to avoid race condition with auth state updates
    final token = await _authService.getAccessToken();
    if (token == null) {
      return null;
    }

    try {
      final response = await _apiClient.get('/api/couples/status');

      if (!response.success) {
        return null;
      }

      final data = response.data as Map<String, dynamic>;

      if (data['isPaired'] != true) {
        return null;
      }

      return CoupleStatus(
        coupleId: data['coupleId'] as String,
        partnerId: data['partnerId'] as String,
        partnerEmail: data['partnerEmail'] as String?,
        partnerName: data['partnerName'] as String?,
        createdAt: DateTime.parse(data['createdAt'] as String),
      );
    } catch (e) {
      Logger.error('Error fetching couple status', error: e, service: 'pairing');
      return null;
    }
  }

  /// Leave current couple (unpair)
  Future<bool> leaveCouple() async {
    // Use async token check to avoid race condition with auth state updates
    final token = await _authService.getAccessToken();
    if (token == null) {
      throw Exception('Not authenticated. Please sign in.');
    }

    try {
      final response = await _apiClient.delete('/api/couples/status');

      if (!response.success) {
        throw Exception(response.error ?? 'Failed to leave couple');
      }

      // Clear local partner data
      await _storage.deletePartner();
      await _secureStorage.delete(key: _keyCoupleId);

      Logger.success('Left couple', service: 'pairing');

      return true;
    } catch (e) {
      Logger.error('Error leaving couple', error: e, service: 'pairing');
      rethrow;
    }
  }

  /// Check if user is currently paired
  Future<bool> isPaired() async {
    final status = await getStatus();
    return status != null;
  }

  /// Get stored couple ID
  Future<String?> getCoupleId() async {
    return _secureStorage.read(key: _keyCoupleId);
  }
}

/// Couple status information
class CoupleStatus {
  final String coupleId;
  final String partnerId;
  final String? partnerEmail;
  final String? partnerName;
  final DateTime createdAt;

  CoupleStatus({
    required this.coupleId,
    required this.partnerId,
    this.partnerEmail,
    this.partnerName,
    required this.createdAt,
  });
}

import 'package:cloud_functions/cloud_functions.dart';
import '../utils/logger.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // TODO: Add cloud_firestore to pubspec.yaml
import '../models/partner.dart';
import '../models/pairing_code.dart';
import 'storage_service.dart';
import 'notification_service.dart';
import '../utils/logger.dart';

/// Service for remote pairing using temporary codes
/// Enables long-distance couples to pair without QR scanning
class RemotePairingService {
  static final RemotePairingService _instance =
      RemotePairingService._internal();
  factory RemotePairingService() => _instance;
  RemotePairingService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final StorageService _storage = StorageService();

  /// Generate a new pairing code
  /// Returns PairingCode with 6-character code and expiration time
  /// Throws Exception if user not found or push token unavailable
  Future<PairingCode> generatePairingCode() async {
    final user = _storage.getUser();
    if (user == null) {
      throw Exception('User not found. Please restart the app.');
    }

    final pushToken = await NotificationService.getToken();
    if (pushToken == null) {
      throw Exception('Push notifications not available');
    }

    try {
      final callable = _functions.httpsCallable('createPairingCode');
      final result = await callable.call({
        'userId': user.id,
        'pushToken': pushToken,
        'name': user.name ?? 'Your Partner',
        'avatarEmoji': '💕',
      });

      final code = result.data['code'] as String;
      final expiresAt =
          DateTime.fromMillisecondsSinceEpoch(result.data['expiresAt'] as int);

      Logger.success('Generated pairing code: $code', service: 'pairing');

      return PairingCode(
        code: code,
        expiresAt: expiresAt,
      );
    } on FirebaseFunctionsException catch (e) {
      Logger.error('Error generating pairing code: ${e.code} - ${e.message}', service: 'pairing');
      throw Exception('Failed to generate code: ${e.message}');
    } catch (e) {
      Logger.error('Error generating pairing code', error: e, service: 'pairing');
      rethrow;
    }
  }

  /// Pair with a partner using their code
  /// Returns Partner object after successful pairing
  /// Throws Exception for invalid/expired codes or network errors
  Future<Partner> pairWithCode(String code) async {
    if (code.trim().length != 6) {
      throw Exception('Code must be 6 characters');
    }

    try {
      final callable = _functions.httpsCallable('getPairingCode');
      final result = await callable.call({
        'code': code.toUpperCase().trim(),
      });

      // Parse createdAt from Firebase response (timestamp for accurate "days together")
      // Fall back to DateTime.now() for backward compatibility
      DateTime pairedAt;
      if (result.data['createdAt'] != null) {
        pairedAt = DateTime.fromMillisecondsSinceEpoch(result.data['createdAt'] as int);
      } else {
        pairedAt = DateTime.now();
      }

      final partner = Partner(
        name: result.data['name'] ?? 'Partner',
        pushToken: result.data['pushToken'] ?? '',
        pairedAt: pairedAt,
        avatarEmoji: result.data['avatarEmoji'] ?? '💕',
      );

      await _storage.savePartner(partner);

      // Send pairing confirmation notification to partner
      final user = _storage.getUser();
      final myPushToken = await NotificationService.getToken();

      if (user != null && myPushToken != null) {
        await NotificationService.sendPairingConfirmation(
          partnerToken: partner.pushToken,
          myName: user.name ?? 'Your Partner',
          myPushToken: myPushToken,
        );
      }

      Logger.success('Paired with: ${partner.name}', service: 'pairing');

      return partner;
    } on FirebaseFunctionsException catch (e) {
      Logger.error('Error pairing with code: ${e.code} - ${e.message}', service: 'pairing');

      if (e.code == 'not-found') {
        throw Exception('Invalid or expired code');
      } else if (e.code == 'deadline-exceeded') {
        throw Exception('Code expired. Ask your partner for a new code.');
      } else if (e.code == 'invalid-argument') {
        throw Exception('Invalid code format');
      } else {
        throw Exception('Pairing failed: ${e.message}');
      }
    } catch (e) {
      Logger.error('Error pairing with code', error: e, service: 'pairing');
      rethrow;
    }
  }
}

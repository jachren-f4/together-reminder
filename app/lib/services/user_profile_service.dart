import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/partner.dart';
import '../utils/logger.dart';
import 'api_client.dart';
import 'storage_service.dart';
import 'notification_service.dart';

/// Result of completing signup or fetching profile
class SignupResult {
  final User user;
  final String? coupleId;
  final Partner? partner;

  SignupResult({
    required this.user,
    this.coupleId,
    this.partner,
  });

  bool get isPaired => coupleId != null && partner != null;
}

/// Service for managing user profile via API
///
/// Handles:
/// - Completing signup after OTP verification
/// - Updating user display name
/// - Syncing push tokens
/// - Fetching full profile for device switching
class UserProfileService {
  static final UserProfileService _instance = UserProfileService._internal();
  factory UserProfileService() => _instance;
  UserProfileService._internal();

  final ApiClient _apiClient = ApiClient();
  final StorageService _storage = StorageService();

  /// Complete signup after OTP verification
  ///
  /// Called immediately after verifyOTP() succeeds.
  /// Returns User and optionally restores couple/partner if exists.
  ///
  /// Parameters:
  /// - [pushToken]: Optional FCM token to sync
  /// - [name]: Optional name to set (if user entered name before auth)
  Future<SignupResult> completeSignup({String? pushToken, String? name}) async {
    try {
      // Get platform for push token
      String? platform;
      if (pushToken != null) {
        if (kIsWeb) {
          platform = 'web';
        } else if (Platform.isIOS) {
          platform = 'ios';
        } else if (Platform.isAndroid) {
          platform = 'android';
        }
      }

      final response = await _apiClient.post(
        '/api/user/complete-signup',
        body: {
          if (pushToken != null) 'pushToken': pushToken,
          if (platform != null) 'platform': platform,
          if (name != null) 'name': name,
        },
      );

      if (!response.success) {
        throw Exception(response.error ?? 'Failed to complete signup');
      }

      final data = response.data as Map<String, dynamic>;
      return _parseAndSaveResponse(data);
    } catch (e) {
      Logger.error('Error completing signup', error: e, service: 'profile');
      rethrow;
    }
  }

  /// Update user's display name
  ///
  /// Updates both server and local storage.
  Future<User> updateName(String name) async {
    try {
      final response = await _apiClient.patch(
        '/api/user/name',
        body: {'name': name},
      );

      if (!response.success) {
        throw Exception(response.error ?? 'Failed to update name');
      }

      final data = response.data as Map<String, dynamic>;
      final userData = data['user'] as Map<String, dynamic>;

      // Update local user
      var user = _storage.getUser();
      if (user != null) {
        user.name = userData['name'] as String?;
        await _storage.saveUser(user);
      } else {
        // User doesn't exist locally yet - create from response
        user = User(
          id: userData['id'] as String,
          pushToken: '',
          createdAt: DateTime.now(),
          name: userData['name'] as String?,
        );
        await _storage.saveUser(user);
      }

      Logger.success('Name updated to: ${user.name}', service: 'profile');
      return user;
    } catch (e) {
      Logger.error('Error updating name', error: e, service: 'profile');
      rethrow;
    }
  }

  /// Sync push token to server
  ///
  /// Called when FCM token is received or refreshed.
  Future<void> syncPushToken(String token, String platform) async {
    try {
      final response = await _apiClient.post(
        '/api/user/push-token',
        body: {
          'token': token,
          'platform': platform,
        },
      );

      if (!response.success) {
        Logger.warn('Failed to sync push token: ${response.error}', service: 'profile');
        return;
      }

      // Update local user's push token
      final user = _storage.getUser();
      if (user != null) {
        user.pushToken = token;
        await _storage.saveUser(user);
      }

      Logger.debug('Push token synced for $platform', service: 'profile');
    } catch (e) {
      Logger.error('Error syncing push token', error: e, service: 'profile');
      // Don't rethrow - push token sync failure shouldn't block the app
    }
  }

  /// Get full profile from server
  ///
  /// Used for device switching and state restoration.
  Future<SignupResult> getProfile() async {
    try {
      final response = await _apiClient.get('/api/user/profile');

      if (!response.success) {
        throw Exception(response.error ?? 'Failed to fetch profile');
      }

      final data = response.data as Map<String, dynamic>;
      return _parseAndSaveResponse(data);
    } catch (e) {
      Logger.error('Error fetching profile', error: e, service: 'profile');
      rethrow;
    }
  }

  /// Parse API response and save to local storage
  SignupResult _parseAndSaveResponse(Map<String, dynamic> data) {
    // Parse user
    final userData = data['user'] as Map<String, dynamic>;
    final user = User(
      id: userData['id'] as String,
      pushToken: userData['pushToken'] as String? ?? '',
      createdAt: userData['createdAt'] != null
          ? DateTime.parse(userData['createdAt'] as String)
          : DateTime.now(),
      name: userData['name'] as String?,
    );

    // Save user to local storage
    _storage.saveUser(user);
    Logger.debug('User saved: ${user.id}', service: 'profile');

    // Parse couple if exists
    String? coupleId;
    final coupleData = data['couple'] as Map<String, dynamic>?;
    if (coupleData != null) {
      coupleId = coupleData['id'] as String;
    }

    // Parse partner if exists
    Partner? partner;
    final partnerData = data['partner'] as Map<String, dynamic>?;
    if (partnerData != null) {
      final pairedAt = coupleData?['createdAt'] != null
          ? DateTime.parse(coupleData!['createdAt'] as String)
          : DateTime.now();

      partner = Partner(
        id: partnerData['id'] as String,
        name: partnerData['name'] as String? ?? 'Partner',
        pushToken: partnerData['pushToken'] as String? ?? '',
        pairedAt: pairedAt,
        avatarEmoji: partnerData['avatarEmoji'] as String? ?? '💕',
      );

      // Save partner to local storage
      _storage.savePartner(partner);
      Logger.debug('Partner saved: ${partner.name}', service: 'profile');
    }

    return SignupResult(
      user: user,
      coupleId: coupleId,
      partner: partner,
    );
  }

  /// Get current platform string for push token
  static String getPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }
}

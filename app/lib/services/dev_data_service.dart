import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../config/dev_config.dart';
import '../config/supabase_config.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/api_client.dart';
import '../models/user.dart';
import '../models/partner.dart';

/// Service for loading real user data from Supabase in development mode
///
/// This service replaces mock data with actual database records, allowing
/// development without email authentication while working with real data.
class DevDataService {
  static final DevDataService _instance = DevDataService._internal();
  factory DevDataService() => _instance;
  DevDataService._internal();

  final _storage = StorageService();
  final _apiClient = ApiClient();

  /// Load real user data from Supabase and store locally
  ///
  /// Only active when:
  /// - Debug mode OR allowAuthBypassInRelease = true
  /// - skipAuthInDev = true
  /// - No existing user/partner data in local storage
  Future<bool> loadRealDataIfNeeded() async {
    // Only with auth bypass enabled (debug mode or explicit release bypass)
    final canBypass = kDebugMode || DevConfig.allowAuthBypassInRelease;
    if (!canBypass || !DevConfig.skipAuthInDev) {
      return false;
    }

    // Skip if already has data
    if (_storage.hasPartner()) {
      debugPrint('🔧 [DEV] User data already exists, skipping load');
      return false;
    }

    try {
      debugPrint('🔧 [DEV] Loading real user data from Supabase...');

      // Get dev user ID based on platform and device name
      final devUserId = await _getDevUserId();
      if (devUserId == null) {
        debugPrint('⚠️ [DEV] No dev user ID configured');
        return false;
      }

      // Get real FCM token for this device (use placeholder if unavailable)
      var fcmToken = await NotificationService.getToken();
      if (fcmToken == null) {
        debugPrint('⚠️ [DEV] Could not get FCM token, using placeholder');
        fcmToken = 'dev-placeholder-token-${DateTime.now().millisecondsSinceEpoch}';
      }

      // Fetch real user data from API
      final apiUrl = SupabaseConfig.apiUrl;
      final url = Uri.parse('$apiUrl/api/dev/user-data?userId=$devUserId');

      debugPrint('🔧 [DEV] Fetching from: $url');

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('❌ [DEV] Failed to fetch user data: ${response.statusCode}');
        debugPrint('   Response: ${response.body}');
        return false;
      }

      final data = json.decode(response.body);

      // Create User from response
      final user = User(
        id: data['user']['id'],
        pushToken: fcmToken, // Use real FCM token for this device
        createdAt: DateTime.parse(data['user']['createdAt']),
        name: data['user']['name'],
        lovePoints: 0, // Start fresh
        arenaTier: 1,
        floor: 0,
        lastActivityDate: DateTime.now(),
      );

      await _storage.saveUser(user);
      debugPrint('✅ [DEV] Created user: ${user.name}');

      // Register our FCM token with Supabase so partner can fetch it
      await _registerPushToken(fcmToken);

      // Create Partner if exists
      if (data['partner'] != null) {
        final partnerData = data['partner'];
        final coupleData = data['couple'];

        // Fetch partner's real FCM token from Supabase
        final partnerToken = await _fetchPartnerPushToken();

        final partner = Partner(
          name: partnerData['name'],
          pushToken: partnerToken ?? partnerData['id'], // Use real FCM token, fallback to ID
          pairedAt: DateTime.parse(coupleData['createdAt']),
          avatarEmoji: partnerData['avatarEmoji'],
        );

        await _storage.savePartner(partner);
        debugPrint('✅ [DEV] Created partner: ${partner.name}');
        debugPrint('✅ [DEV] Partner FCM token: ${partnerToken != null ? "REAL" : "PLACEHOLDER (partner not registered yet)"}');
        debugPrint('✅ [DEV] Real data loaded successfully!');
        return true;
      } else {
        debugPrint('ℹ️ [DEV] No partner found for this user');
        return true; // Still succeeded in loading user data
      }

    } catch (e, stackTrace) {
      debugPrint('❌ [DEV] Error loading real data: $e');
      debugPrint('   Stack trace: $stackTrace');
      return false;
    }
  }

  /// Get development user ID based on platform and device
  /// Returns user1_id (TestiY) for primary device, user2_id (Jokke) for secondary
  ///
  /// Device mapping:
  /// - Android emulator / Joakim's iPhone 14 → TestiY (devUserIdAndroid)
  /// - Web/Chrome / Onni's iPhone 12 → Jokke (devUserIdWeb)
  Future<String?> _getDevUserId() async {
    // Check if running on Web (Chrome)
    if (kIsWeb) {
      final userId = DevConfig.devUserIdWeb;
      // Only return if not a placeholder
      if (userId.contains('REPLACE_WITH')) {
        debugPrint('⚠️ [DEV] devUserIdWeb not configured in DevConfig');
        return null;
      }
      debugPrint('🔧 [DEV] Web platform → using Jokke (devUserIdWeb)');
      return userId;
    }

    // Check iOS device model to determine which user
    if (!kIsWeb && Platform.isIOS) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final iosInfo = await deviceInfo.iosInfo;
        final deviceName = iosInfo.name;
        final deviceModel = iosInfo.utsname.machine; // e.g., "iPhone13,2" for iPhone 12
        debugPrint('🔧 [DEV] iOS device: name=$deviceName, model=$deviceModel');

        // iPhone 12 models: iPhone13,1 (mini), iPhone13,2 (regular), iPhone13,3 (Pro), iPhone13,4 (Pro Max)
        // iPhone 14 models: iPhone14,7 (regular), iPhone14,8 (Plus), iPhone15,2 (Pro), iPhone15,3 (Pro Max)
        // Use iPhone 12 (iPhone13,x) for Jokke (the partner)
        if (deviceModel.startsWith('iPhone13,')) {
          debugPrint('🔧 [DEV] iPhone 12 detected → using Jokke (devUserIdWeb)');
          return DevConfig.devUserIdWeb;
        }

        // Also check device name as fallback
        if (deviceName.toLowerCase().contains('onni') ||
            deviceName.toLowerCase().contains('12')) {
          debugPrint('🔧 [DEV] Onni\'s device or iPhone 12 → using Jokke (devUserIdWeb)');
          return DevConfig.devUserIdWeb;
        }

        // iPhone 14 and others get TestiY
        debugPrint('🔧 [DEV] Primary iOS device → using TestiY (devUserIdAndroid)');
        return DevConfig.devUserIdAndroid;
      } catch (e) {
        debugPrint('⚠️ [DEV] Could not get iOS device info: $e');
      }
    }

    // Default to Android user ID for Android and fallback
    final userId = DevConfig.devUserIdAndroid;
    if (userId.contains('REPLACE_WITH')) {
      debugPrint('⚠️ [DEV] devUserIdAndroid not configured in DevConfig');
      return null;
    }
    return userId;
  }

  /// Register this device's FCM token with Supabase
  Future<void> _registerPushToken(String fcmToken) async {
    try {
      // Determine platform
      String platform = 'web';
      String? deviceName;

      if (!kIsWeb) {
        if (Platform.isIOS) {
          platform = 'ios';
          try {
            final deviceInfo = DeviceInfoPlugin();
            final iosInfo = await deviceInfo.iosInfo;
            deviceName = iosInfo.name;
          } catch (_) {}
        } else if (Platform.isAndroid) {
          platform = 'android';
          try {
            final deviceInfo = DeviceInfoPlugin();
            final androidInfo = await deviceInfo.androidInfo;
            deviceName = androidInfo.model;
          } catch (_) {}
        }
      }

      final response = await _apiClient.post('/api/sync/push-token', body: {
        'fcmToken': fcmToken,
        'platform': platform,
        'deviceName': deviceName,
      });

      if (response.success) {
        debugPrint('✅ [DEV] Registered FCM token with Supabase');
      } else {
        debugPrint('⚠️ [DEV] Failed to register FCM token: ${response.error}');
      }
    } catch (e) {
      debugPrint('⚠️ [DEV] Error registering FCM token: $e');
    }
  }

  /// Fetch partner's FCM token from Supabase
  Future<String?> _fetchPartnerPushToken() async {
    try {
      final response = await _apiClient.get('/api/sync/push-token');

      if (response.success && response.data != null) {
        final partnerToken = response.data['partnerToken'] as String?;
        if (partnerToken != null && partnerToken.isNotEmpty) {
          debugPrint('✅ [DEV] Fetched partner FCM token from Supabase');
          return partnerToken;
        }
      }

      debugPrint('ℹ️ [DEV] Partner FCM token not yet registered');
      return null;
    } catch (e) {
      debugPrint('⚠️ [DEV] Error fetching partner FCM token: $e');
      return null;
    }
  }

  /// Refresh partner's push token (call periodically or on app resume)
  /// Updates the stored partner with the latest FCM token from Supabase
  Future<void> refreshPartnerPushToken() async {
    final canBypass = kDebugMode || DevConfig.allowAuthBypassInRelease;
    if (!canBypass || !DevConfig.skipAuthInDev) {
      return;
    }

    final partner = _storage.getPartner();
    if (partner == null) return;

    final newToken = await _fetchPartnerPushToken();
    if (newToken != null && newToken != partner.pushToken) {
      final updatedPartner = Partner(
        name: partner.name,
        pushToken: newToken,
        pairedAt: partner.pairedAt,
        avatarEmoji: partner.avatarEmoji,
      );
      await _storage.savePartner(updatedPartner);
      debugPrint('✅ [DEV] Updated partner FCM token');
    }
  }

  /// Sync push tokens on every app startup (even if data already exists)
  /// This ensures FCM tokens are always up-to-date in Supabase
  Future<void> syncPushTokensOnStartup() async {
    final canBypass = kDebugMode || DevConfig.allowAuthBypassInRelease;
    if (!canBypass || !DevConfig.skipAuthInDev) {
      return;
    }

    try {
      // Get real FCM token for this device
      var fcmToken = await NotificationService.getToken();
      if (fcmToken == null || fcmToken.startsWith('web_token_')) {
        debugPrint('⚠️ [DEV] No valid FCM token available');
        return;
      }

      // Register our token
      await _registerPushToken(fcmToken);

      // Try to fetch and update partner's token
      await refreshPartnerPushToken();
    } catch (e) {
      debugPrint('⚠️ [DEV] Error syncing push tokens: $e');
    }
  }
}

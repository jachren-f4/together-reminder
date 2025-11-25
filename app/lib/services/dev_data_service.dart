import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/dev_config.dart';
import '../config/supabase_config.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
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

  /// Load real user data from Supabase and store locally
  ///
  /// Only active when:
  /// - Debug mode
  /// - skipAuthInDev = true
  /// - No existing user/partner data in local storage
  Future<bool> loadRealDataIfNeeded() async {
    // Only in debug mode with auth bypass
    if (!kDebugMode || !DevConfig.skipAuthInDev) {
      return false;
    }

    // Skip if already has data
    if (_storage.hasPartner()) {
      debugPrint('🔧 [DEV] User data already exists, skipping load');
      return false;
    }

    try {
      debugPrint('🔧 [DEV] Loading real user data from Supabase...');

      // Get dev user ID based on platform (Android vs Web)
      final devUserId = _getDevUserId();
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

      // Create Partner if exists
      if (data['partner'] != null) {
        final partnerData = data['partner'];
        final coupleData = data['couple'];

        final partner = Partner(
          name: partnerData['name'],
          pushToken: partnerData['id'], // Use partner's user ID as token
          pairedAt: DateTime.parse(coupleData['createdAt']),
          avatarEmoji: partnerData['avatarEmoji'],
        );

        await _storage.savePartner(partner);
        debugPrint('✅ [DEV] Created partner: ${partner.name}');
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

  /// Get development user ID based on platform
  /// Returns user1_id for Android, user2_id for Web/Chrome
  String? _getDevUserId() {
    // Check if running on Web (Chrome)
    if (kIsWeb) {
      final userId = DevConfig.devUserIdWeb;
      // Only return if not a placeholder
      if (userId.contains('REPLACE_WITH')) {
        debugPrint('⚠️ [DEV] devUserIdWeb not configured in DevConfig');
        return null;
      }
      return userId;
    }

    // Default to Android user ID for all other platforms
    final userId = DevConfig.devUserIdAndroid;
    if (userId.contains('REPLACE_WITH')) {
      debugPrint('⚠️ [DEV] devUserIdAndroid not configured in DevConfig');
      return null;
    }
    return userId;
  }
}

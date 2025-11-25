import 'dart:ui';
import 'package:firebase_database/firebase_database.dart';
import 'package:hive/hive.dart';
import '../utils/logger.dart';
import 'api_client.dart';
import 'storage_service.dart';

/// Service for managing couple-level preferences
///
/// Features:
/// - Global "who goes first" preference for turn-based games
/// - Syncs between partners via Firebase RTDB
/// - Persists to Supabase for authoritative storage
/// - Local caching in Hive for fast access
class CouplePreferencesService {
  static final CouplePreferencesService _instance = CouplePreferencesService._internal();
  factory CouplePreferencesService() => _instance;
  CouplePreferencesService._internal();

  static final DatabaseReference _database = FirebaseDatabase.instance.ref();
  static final ApiClient _apiClient = ApiClient();
  static final StorageService _storage = StorageService();

  // Callback for triggering UI updates when preferences change
  static VoidCallback? _onPreferenceChanged;

  // Hive keys
  static const String _appMetadataBox = 'app_metadata';
  static const String _firstPlayerIdKey = 'first_player_id';
  static const String _coupleIdKey = 'couple_id';

  /// Get the user ID of the partner who goes first in new turn-based games
  ///
  /// Returns cached value if available, otherwise fetches from API
  /// Default: user2_id (latest joiner) if not explicitly set
  Future<String> getFirstPlayerId() async {
    try {
      // 1. Try cache first
      final box = Hive.box(_appMetadataBox);
      final cached = box.get(_firstPlayerIdKey) as String?;

      if (cached != null && cached.isNotEmpty) {
        Logger.debug('Using cached first player ID: $cached', service: 'preferences');
        return cached;
      }

      // 2. Fetch from API
      Logger.debug('Fetching first player ID from API...', service: 'preferences');
      final response = await _apiClient.get('/api/sync/couple-preferences');

      if (!response.success || response.data == null) {
        Logger.error('Failed to fetch first player ID', error: response.error, service: 'preferences');
        throw Exception('Failed to fetch preferences: ${response.error}');
      }

      final data = response.data as Map<String, dynamic>;
      final firstPlayerId = data['firstPlayerId'] as String;
      final coupleId = data['coupleId'] as String;

      // 3. Cache values
      await box.put(_firstPlayerIdKey, firstPlayerId);
      await box.put(_coupleIdKey, coupleId);

      Logger.success('Fetched first player ID: $firstPlayerId', service: 'preferences');
      return firstPlayerId;

    } catch (e) {
      Logger.error('Error getting first player ID', error: e, service: 'preferences');

      // Fallback: Try to determine from user/partner data
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user != null && partner != null) {
        // Assume current user is user2 (latest joiner) as fallback
        Logger.warn('Using fallback: current user as first player', service: 'preferences');
        return user.id;
      }

      rethrow;
    }
  }

  /// Set the user ID of the partner who goes first in new turn-based games
  ///
  /// Updates:
  /// 1. Local Hive cache
  /// 2. Supabase database (via API)
  /// 3. Firebase RTDB for real-time partner sync
  Future<void> setFirstPlayerId(String userId) async {
    try {
      Logger.info('Setting first player ID to: $userId', service: 'preferences');

      // 1. Update local cache immediately for instant UI feedback
      final box = Hive.box(_appMetadataBox);
      await box.put(_firstPlayerIdKey, userId);

      // 2. Update Supabase (authoritative)
      final response = await _apiClient.post(
        '/api/sync/couple-preferences',
        body: {'firstPlayerId': userId},
      );

      if (!response.success) {
        Logger.error('Failed to update first player ID in Supabase', error: response.error, service: 'preferences');
        throw Exception('Failed to update preferences: ${response.error}');
      }

      final data = response.data as Map<String, dynamic>;
      final coupleId = data['coupleId'] as String;

      // 3. Write to Firebase RTDB for real-time partner sync
      await _database.child('couple_preferences/$coupleId').set({
        'firstPlayerId': userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      Logger.success('First player ID updated successfully', service: 'preferences');

      // Trigger UI callback if registered
      _onPreferenceChanged?.call();

    } catch (e) {
      Logger.error('Error setting first player ID', error: e, service: 'preferences');
      rethrow;
    }
  }

  /// Start listening for real-time preference updates from Firebase RTDB
  ///
  /// Call this ONCE during app initialization (in main.dart)
  /// Partners' changes will trigger automatic cache updates and UI refreshes
  static void startListening() async {
    try {
      // Get couple ID from cache or API
      final box = Hive.box(_appMetadataBox);
      String? coupleId = box.get(_coupleIdKey) as String?;

      if (coupleId == null) {
        // Fetch from API if not cached
        final response = await _apiClient.get('/api/sync/couple-preferences');
        if (response.success && response.data != null) {
          final data = response.data as Map<String, dynamic>;
          coupleId = data['coupleId'] as String;
          await box.put(_coupleIdKey, coupleId);
        } else {
          Logger.warn('Cannot start listener: couple ID not available', service: 'preferences');
          return;
        }
      }

      Logger.info('Starting Firebase listener for couple preferences: $coupleId', service: 'preferences');

      // Listen for value changes (onValue triggers on any update)
      _database.child('couple_preferences/$coupleId').onValue.listen((event) async {
        if (event.snapshot.value == null) return;

        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final firstPlayerId = data['firstPlayerId'] as String?;

        if (firstPlayerId != null) {
          // Update local cache
          await box.put(_firstPlayerIdKey, firstPlayerId);
          Logger.success('Preference updated from Firebase: firstPlayerId = $firstPlayerId', service: 'preferences');

          // Trigger UI callback if registered
          _onPreferenceChanged?.call();
        }
      });

    } catch (e) {
      Logger.error('Error setting up preference listener', error: e, service: 'preferences');
    }
  }

  /// Register a callback to be called when preferences change
  ///
  /// Use in screens that need to update UI when partner changes preferences:
  /// ```dart
  /// CouplePreferencesService.setOnPreferenceChanged(() {
  ///   if (mounted) setState(() {});
  /// });
  /// ```
  static void setOnPreferenceChanged(VoidCallback callback) {
    _onPreferenceChanged = callback;
    Logger.debug('Preference change callback registered', service: 'preferences');
  }

  /// Get cached couple ID (if available)
  String? getCachedCoupleId() {
    final box = Hive.box(_appMetadataBox);
    return box.get(_coupleIdKey) as String?;
  }

  /// Clear cached preferences (useful for testing/debugging)
  Future<void> clearCache() async {
    final box = Hive.box(_appMetadataBox);
    await box.delete(_firstPlayerIdKey);
    await box.delete(_coupleIdKey);
    Logger.info('Preference cache cleared', service: 'preferences');
  }
}

import 'package:hive/hive.dart';
import '../utils/logger.dart';
import 'api_client.dart';

/// Model for per-user activity stats
class UserActivityStats {
  final String id;
  final String name;
  final String initial;
  final int activitiesCompleted;
  final int currentStreakDays;
  final int coupleGamesWon;

  UserActivityStats({
    required this.id,
    required this.name,
    required this.initial,
    required this.activitiesCompleted,
    required this.currentStreakDays,
    required this.coupleGamesWon,
  });

  factory UserActivityStats.fromJson(Map<String, dynamic> json) {
    return UserActivityStats(
      id: json['id'] as String,
      name: json['name'] as String,
      initial: json['initial'] as String,
      activitiesCompleted: json['activitiesCompleted'] as int? ?? 0,
      currentStreakDays: json['currentStreakDays'] as int? ?? 0,
      coupleGamesWon: json['coupleGamesWon'] as int? ?? 0,
    );
  }
}

/// Model for couple stats response
class CoupleStats {
  final DateTime? anniversaryDate;
  final UserActivityStats user1;
  final UserActivityStats user2;
  final String currentUserId;

  CoupleStats({
    this.anniversaryDate,
    required this.user1,
    required this.user2,
    required this.currentUserId,
  });

  factory CoupleStats.fromJson(Map<String, dynamic> json) {
    return CoupleStats(
      anniversaryDate: json['anniversaryDate'] != null
          ? DateTime.parse(json['anniversaryDate'] as String)
          : null,
      user1: UserActivityStats.fromJson(json['user1'] as Map<String, dynamic>),
      user2: UserActivityStats.fromJson(json['user2'] as Map<String, dynamic>),
      currentUserId: json['currentUserId'] as String,
    );
  }

  /// Get the current user's stats
  UserActivityStats get currentUserStats =>
      user1.id == currentUserId ? user1 : user2;

  /// Get the partner's stats
  UserActivityStats get partnerStats =>
      user1.id == currentUserId ? user2 : user1;
}

/// Service for fetching and caching couple statistics
///
/// Used by the profile page to display:
/// - "Together For" relationship duration
/// - "Your Activity" stats per partner
class CoupleStatsService {
  static final CoupleStatsService _instance = CoupleStatsService._internal();
  factory CoupleStatsService() => _instance;
  CoupleStatsService._internal();

  static final ApiClient _apiClient = ApiClient();

  // Hive keys
  static const String _appMetadataBox = 'app_metadata';
  static const String _anniversaryDateKey = 'anniversary_date';
  static const String _coupleStatsKey = 'couple_stats';
  static const String _coupleStatsFetchedAtKey = 'couple_stats_fetched_at';

  /// Fetch couple stats from API
  ///
  /// Returns cached data if available and recent (< 5 minutes old)
  /// Otherwise fetches from server
  Future<CoupleStats?> fetchStats({bool forceRefresh = false}) async {
    try {
      final box = Hive.box(_appMetadataBox);

      // Check cache unless force refresh
      if (!forceRefresh) {
        final cachedAt = box.get(_coupleStatsFetchedAtKey) as DateTime?;
        final cached = box.get(_coupleStatsKey) as Map?;

        if (cachedAt != null &&
            cached != null &&
            DateTime.now().difference(cachedAt).inMinutes < 5) {
          Logger.debug('Using cached couple stats', service: 'couplestats');
          return CoupleStats.fromJson(Map<String, dynamic>.from(cached));
        }
      }

      // Fetch from API
      Logger.debug('Fetching couple stats from API...', service: 'couplestats');
      final response = await _apiClient.get('/api/sync/couple-stats');

      if (!response.success || response.data == null) {
        Logger.error('Failed to fetch couple stats',
            error: response.error, service: 'couplestats');
        return null;
      }

      final data = response.data as Map<String, dynamic>;

      // Cache the response
      await box.put(_coupleStatsKey, data);
      await box.put(_coupleStatsFetchedAtKey, DateTime.now());

      // Also cache anniversary date separately for quick access
      if (data['anniversaryDate'] != null) {
        await box.put(_anniversaryDateKey, data['anniversaryDate']);
      } else {
        await box.delete(_anniversaryDateKey);
      }

      Logger.success('Couple stats fetched and cached', service: 'couplestats');
      return CoupleStats.fromJson(data);
    } catch (e) {
      Logger.error('Error fetching couple stats', error: e, service: 'couplestats');
      return null;
    }
  }

  /// Get cached anniversary date (for quick access without API call)
  DateTime? getCachedAnniversaryDate() {
    try {
      final box = Hive.box(_appMetadataBox);
      final dateStr = box.get(_anniversaryDateKey) as String?;
      if (dateStr != null) {
        return DateTime.parse(dateStr);
      }
      return null;
    } catch (e) {
      Logger.error('Error getting cached anniversary date',
          error: e, service: 'couplestats');
      return null;
    }
  }

  /// Set or update the anniversary date
  ///
  /// Updates both server and local cache
  Future<bool> setAnniversaryDate(DateTime date) async {
    try {
      Logger.info('Setting anniversary date: $date', service: 'couplestats');

      final dateStr = date.toIso8601String().split('T')[0];

      // Update server
      final response = await _apiClient.post(
        '/api/sync/couple-preferences',
        body: {'anniversaryDate': dateStr},
      );

      if (!response.success) {
        Logger.error('Failed to set anniversary date',
            error: response.error, service: 'couplestats');
        return false;
      }

      // Update local cache
      final box = Hive.box(_appMetadataBox);
      await box.put(_anniversaryDateKey, dateStr);

      // Invalidate stats cache to force refresh
      await box.delete(_coupleStatsFetchedAtKey);

      Logger.success('Anniversary date set successfully', service: 'couplestats');
      return true;
    } catch (e) {
      Logger.error('Error setting anniversary date', error: e, service: 'couplestats');
      return false;
    }
  }

  /// Delete the anniversary date
  ///
  /// Resets to "not set" state
  Future<bool> deleteAnniversaryDate() async {
    try {
      Logger.info('Deleting anniversary date', service: 'couplestats');

      // Update server (set to null)
      final response = await _apiClient.post(
        '/api/sync/couple-preferences',
        body: {'anniversaryDate': null},
      );

      if (!response.success) {
        Logger.error('Failed to delete anniversary date',
            error: response.error, service: 'couplestats');
        return false;
      }

      // Update local cache
      final box = Hive.box(_appMetadataBox);
      await box.delete(_anniversaryDateKey);

      // Invalidate stats cache to force refresh
      await box.delete(_coupleStatsFetchedAtKey);

      Logger.success('Anniversary date deleted successfully', service: 'couplestats');
      return true;
    } catch (e) {
      Logger.error('Error deleting anniversary date',
          error: e, service: 'couplestats');
      return false;
    }
  }

  /// Clear all cached stats (useful for testing/debugging)
  Future<void> clearCache() async {
    final box = Hive.box(_appMetadataBox);
    await box.delete(_anniversaryDateKey);
    await box.delete(_coupleStatsKey);
    await box.delete(_coupleStatsFetchedAtKey);
    Logger.info('Couple stats cache cleared', service: 'couplestats');
  }
}

/// Helper to calculate duration from anniversary date
class RelationshipDuration {
  final int years;
  final int months;
  final int days;

  RelationshipDuration({
    required this.years,
    required this.months,
    required this.days,
  });

  /// Calculate duration from anniversary to now
  factory RelationshipDuration.fromAnniversary(DateTime anniversary) {
    final now = DateTime.now();

    int years = now.year - anniversary.year;
    int months = now.month - anniversary.month;
    int days = now.day - anniversary.day;

    // Handle negative days
    if (days < 0) {
      months--;
      // Get days in previous month
      final prevMonth = DateTime(now.year, now.month, 0);
      days += prevMonth.day;
    }

    // Handle negative months
    if (months < 0) {
      years--;
      months += 12;
    }

    return RelationshipDuration(
      years: years < 0 ? 0 : years,
      months: months,
      days: days,
    );
  }
}

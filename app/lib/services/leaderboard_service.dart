import 'api_client.dart';
import '../utils/logger.dart';

/// Model for a leaderboard entry
class LeaderboardEntry {
  final String coupleId;
  final String initials;
  final int totalLp;
  final int rank;
  final bool isCurrentUser;

  LeaderboardEntry({
    required this.coupleId,
    required this.initials,
    required this.totalLp,
    required this.rank,
    required this.isCurrentUser,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      coupleId: json['couple_id'] as String,
      initials: json['initials'] as String,
      totalLp: json['total_lp'] as int,
      rank: json['rank'] as int,
      isCurrentUser: json['is_current_user'] as bool? ?? false,
    );
  }
}

/// Model for leaderboard response
class LeaderboardData {
  final String view; // 'global' or 'country'
  final String? countryCode;
  final String? countryName;
  final List<LeaderboardEntry> entries;
  final int? userRank;
  final int? userTotalLp;
  final int totalCouples;
  final DateTime updatedAt;
  final String? message;

  LeaderboardData({
    required this.view,
    this.countryCode,
    this.countryName,
    required this.entries,
    this.userRank,
    this.userTotalLp,
    required this.totalCouples,
    required this.updatedAt,
    this.message,
  });

  factory LeaderboardData.fromJson(Map<String, dynamic> json) {
    final entriesJson = json['entries'] as List<dynamic>? ?? [];
    final entries = entriesJson
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    return LeaderboardData(
      view: json['view'] as String,
      countryCode: json['country_code'] as String?,
      countryName: json['country_name'] as String?,
      entries: entries,
      userRank: json['user_rank'] as int?,
      userTotalLp: json['user_total_lp'] as int?,
      totalCouples: json['total_couples'] as int? ?? 0,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      message: json['message'] as String?,
    );
  }

  /// Get top 5 entries
  List<LeaderboardEntry> get top5 {
    return entries.where((e) => e.rank <= 5).toList();
  }

  /// Get user's context entries (above, user, below) if not in top 5
  List<LeaderboardEntry>? getUserContext() {
    if (userRank == null || userRank! <= 5) return null;

    final context = entries.where((e) => e.rank > 5).toList();
    return context.isEmpty ? null : context;
  }

  /// Check if user is in top N
  bool isUserInTop(int n) {
    return userRank != null && userRank! <= n;
  }

  /// Get LP needed to reach a target rank
  int? lpNeededForRank(int targetRank) {
    if (userTotalLp == null) return null;

    final target = entries.firstWhere(
      (e) => e.rank == targetRank,
      orElse: () => entries.first,
    );

    final diff = target.totalLp - userTotalLp!;
    return diff > 0 ? diff : null;
  }
}

/// Service for fetching leaderboard data
class LeaderboardService {
  static final LeaderboardService _instance = LeaderboardService._internal();
  factory LeaderboardService() => _instance;
  LeaderboardService._internal();

  final ApiClient _apiClient = ApiClient();

  // Cache for leaderboard data (30s TTL per plan)
  LeaderboardData? _cachedGlobalData;
  LeaderboardData? _cachedCountryData;
  DateTime? _globalCacheTime;
  DateTime? _countryCacheTime;
  static const Duration _cacheTTL = Duration(seconds: 30);

  /// Fetch global leaderboard
  Future<LeaderboardData?> getGlobalLeaderboard({bool forceRefresh = false}) async {
    // Check cache
    if (!forceRefresh && _cachedGlobalData != null && _globalCacheTime != null) {
      final cacheAge = DateTime.now().difference(_globalCacheTime!);
      if (cacheAge < _cacheTTL) {
        Logger.debug('Returning cached global leaderboard', service: 'leaderboard');
        return _cachedGlobalData;
      }
    }

    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/leaderboard',
        queryParams: {'view': 'global', 'limit': '50'},
      );

      if (response.success && response.data != null) {
        _cachedGlobalData = LeaderboardData.fromJson(response.data!);
        _globalCacheTime = DateTime.now();
        Logger.info('Fetched global leaderboard: ${_cachedGlobalData!.entries.length} entries', service: 'leaderboard');
        return _cachedGlobalData;
      } else {
        Logger.error('Failed to fetch global leaderboard: ${response.error}', service: 'leaderboard');
        return null;
      }
    } catch (e) {
      Logger.error('Error fetching global leaderboard', error: e, service: 'leaderboard');
      return null;
    }
  }

  /// Fetch country leaderboard (for current user's country)
  Future<LeaderboardData?> getCountryLeaderboard({bool forceRefresh = false}) async {
    // Check cache
    if (!forceRefresh && _cachedCountryData != null && _countryCacheTime != null) {
      final cacheAge = DateTime.now().difference(_countryCacheTime!);
      if (cacheAge < _cacheTTL) {
        Logger.debug('Returning cached country leaderboard', service: 'leaderboard');
        return _cachedCountryData;
      }
    }

    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/leaderboard',
        queryParams: {'view': 'country', 'limit': '50'},
      );

      if (response.success && response.data != null) {
        _cachedCountryData = LeaderboardData.fromJson(response.data!);
        _countryCacheTime = DateTime.now();
        Logger.info('Fetched country leaderboard: ${_cachedCountryData!.entries.length} entries', service: 'leaderboard');
        return _cachedCountryData;
      } else {
        Logger.error('Failed to fetch country leaderboard: ${response.error}', service: 'leaderboard');
        return null;
      }
    } catch (e) {
      Logger.error('Error fetching country leaderboard', error: e, service: 'leaderboard');
      return null;
    }
  }

  /// Clear cache (call when LP changes)
  void clearCache() {
    _cachedGlobalData = null;
    _cachedCountryData = null;
    _globalCacheTime = null;
    _countryCacheTime = null;
    Logger.debug('Leaderboard cache cleared', service: 'leaderboard');
  }
}

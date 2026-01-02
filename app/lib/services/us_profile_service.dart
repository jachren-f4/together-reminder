import 'package:hive/hive.dart';
import '../utils/logger.dart';
import 'api_client.dart';

// =============================================================================
// Models
// =============================================================================

/// Dimension score for a single user
class DimensionScore {
  final String dimensionId;
  final int leftCount;
  final int rightCount;
  final int totalAnswers;
  final double position; // -1 to 1

  DimensionScore({
    required this.dimensionId,
    required this.leftCount,
    required this.rightCount,
    required this.totalAnswers,
    required this.position,
  });

  factory DimensionScore.fromJson(Map<String, dynamic> json) {
    return DimensionScore(
      dimensionId: json['dimensionId'] as String,
      leftCount: json['leftCount'] as int? ?? 0,
      rightCount: json['rightCount'] as int? ?? 0,
      totalAnswers: json['totalAnswers'] as int? ?? 0,
      position: (json['position'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Framed dimension with display data
class FramedDimension {
  final String id;
  final String label;
  final double user1Position;
  final double user2Position;
  final String user1Label;
  final String user2Label;
  final String user1Description;
  final String user2Description;
  final String similarity;
  final String conversationPrompt;
  final bool isUnlocked;
  final int dataPoints;

  FramedDimension({
    required this.id,
    required this.label,
    required this.user1Position,
    required this.user2Position,
    required this.user1Label,
    required this.user2Label,
    required this.user1Description,
    required this.user2Description,
    required this.similarity,
    required this.conversationPrompt,
    required this.isUnlocked,
    required this.dataPoints,
  });

  factory FramedDimension.fromJson(Map<String, dynamic> json) {
    return FramedDimension(
      id: json['id'] as String,
      label: json['label'] as String,
      user1Position: (json['user1Position'] as num?)?.toDouble() ?? 0.0,
      user2Position: (json['user2Position'] as num?)?.toDouble() ?? 0.0,
      user1Label: json['user1Label'] as String? ?? 'Balanced',
      user2Label: json['user2Label'] as String? ?? 'Balanced',
      user1Description: json['user1Description'] as String? ?? '',
      user2Description: json['user2Description'] as String? ?? '',
      similarity: json['similarity'] as String? ?? 'similar',
      conversationPrompt: json['conversationPrompt'] as String? ?? '',
      isUnlocked: json['isUnlocked'] as bool? ?? false,
      dataPoints: json['dataPoints'] as int? ?? 0,
    );
  }
}

/// Love language score
class LoveLanguageScore {
  final String language;
  final String label;
  final int count;

  LoveLanguageScore({
    required this.language,
    required this.label,
    required this.count,
  });

  factory LoveLanguageScore.fromJson(Map<String, dynamic> json) {
    return LoveLanguageScore(
      language: json['language'] as String,
      label: json['label'] as String? ?? json['language'] as String,
      count: json['count'] as int? ?? 0,
    );
  }
}

/// Framed love languages
class FramedLoveLanguage {
  final String? user1Primary;
  final String? user1PrimaryLabel;
  final String? user2Primary;
  final String? user2PrimaryLabel;
  final List<LoveLanguageScore> user1All;
  final List<LoveLanguageScore> user2All;
  final String matchStatus;
  final String conversationPrompt;
  final bool isUnlocked;

  FramedLoveLanguage({
    this.user1Primary,
    this.user1PrimaryLabel,
    this.user2Primary,
    this.user2PrimaryLabel,
    required this.user1All,
    required this.user2All,
    required this.matchStatus,
    required this.conversationPrompt,
    required this.isUnlocked,
  });

  factory FramedLoveLanguage.fromJson(Map<String, dynamic> json) {
    return FramedLoveLanguage(
      user1Primary: json['user1Primary'] as String?,
      user1PrimaryLabel: json['user1PrimaryLabel'] as String?,
      user2Primary: json['user2Primary'] as String?,
      user2PrimaryLabel: json['user2PrimaryLabel'] as String?,
      user1All: (json['user1All'] as List<dynamic>?)
              ?.map((e) => LoveLanguageScore.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      user2All: (json['user2All'] as List<dynamic>?)
              ?.map((e) => LoveLanguageScore.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      matchStatus: json['matchStatus'] as String? ?? 'different',
      conversationPrompt: json['conversationPrompt'] as String? ?? '',
      isUnlocked: json['isUnlocked'] as bool? ?? false,
    );
  }
}

/// Discovery (different answers between partners)
class FramedDiscovery {
  final String id;
  final String questionText;
  final String user1Answer;
  final String user2Answer;
  final String? category;
  final String conversationPrompt;
  final String? tryThisAction;

  FramedDiscovery({
    required this.id,
    required this.questionText,
    required this.user1Answer,
    required this.user2Answer,
    this.category,
    required this.conversationPrompt,
    this.tryThisAction,
  });

  factory FramedDiscovery.fromJson(Map<String, dynamic> json) {
    return FramedDiscovery(
      id: json['id'] as String,
      questionText: json['questionText'] as String,
      user1Answer: json['user1Answer'] as String,
      user2Answer: json['user2Answer'] as String,
      category: json['category'] as String?,
      conversationPrompt: json['conversationPrompt'] as String? ?? '',
      tryThisAction: json['tryThisAction'] as String?,
    );
  }
}

/// Partner perception
class FramedPerception {
  final String userId;
  final List<String> traits;
  final String frame;

  FramedPerception({
    required this.userId,
    required this.traits,
    required this.frame,
  });

  factory FramedPerception.fromJson(Map<String, dynamic> json) {
    return FramedPerception(
      userId: json['userId'] as String,
      traits: (json['traits'] as List<dynamic>?)?.cast<String>() ?? [],
      frame: json['frame'] as String? ?? '',
    );
  }
}

/// Growth Edge - perception gap between self and partner view
class GrowthEdge {
  final String id;
  final String selfView;       // How the user described themselves
  final String partnerView;    // How partner sees them
  final String insight;        // The framing text
  final String askQuestion;    // Suggested question to ask partner
  final String partnerName;    // Name of the partner who sees this

  GrowthEdge({
    required this.id,
    required this.selfView,
    required this.partnerView,
    required this.insight,
    required this.askQuestion,
    required this.partnerName,
  });

  factory GrowthEdge.fromJson(Map<String, dynamic> json) {
    return GrowthEdge(
      id: json['id'] as String? ?? '',
      selfView: json['selfView'] as String? ?? '',
      partnerView: json['partnerView'] as String? ?? '',
      insight: json['insight'] as String? ??
          "This isn't right or wrong — it's interesting! How you see yourself isn't always how others experience you.",
      askQuestion: json['askQuestion'] as String? ?? '',
      partnerName: json['partnerName'] as String? ?? 'Partner',
    );
  }
}

/// Conversation starter
class ConversationStarter {
  final String? id;
  final String triggerType;
  final Map<String, dynamic> triggerData;
  final String promptText;
  final String contextText;

  ConversationStarter({
    this.id,
    required this.triggerType,
    required this.triggerData,
    required this.promptText,
    required this.contextText,
  });

  factory ConversationStarter.fromJson(Map<String, dynamic> json) {
    return ConversationStarter(
      id: json['id'] as String?,
      triggerType: json['triggerType'] as String,
      triggerData: (json['triggerData'] as Map<String, dynamic>?) ?? {},
      promptText: json['promptText'] as String? ?? '',
      contextText: json['contextText'] as String? ?? '',
    );
  }
}

/// Action stats for tracking engagement
class ActionStats {
  final int insightsActedOn;
  final int conversationsHad;

  ActionStats({
    required this.insightsActedOn,
    required this.conversationsHad,
  });

  factory ActionStats.fromJson(Map<String, dynamic> json) {
    return ActionStats(
      insightsActedOn: json['insightsActedOn'] as int? ?? 0,
      conversationsHad: json['conversationsHad'] as int? ?? 0,
    );
  }
}

/// This week's focus - actionable insight
class WeeklyFocus {
  final String text;
  final String source;

  WeeklyFocus({
    required this.text,
    required this.source,
  });

  factory WeeklyFocus.fromJson(Map<String, dynamic> json) {
    return WeeklyFocus(
      text: json['text'] as String? ?? '',
      source: json['source'] as String? ?? '',
    );
  }
}

/// Value alignment for the values section
class ValueAlignment {
  final String id;
  final String name;
  final String status; // 'aligned' | 'exploring' | 'important'
  final double alignment; // 0-100
  final String insight;
  final int questions;
  final bool isPriority;

  ValueAlignment({
    required this.id,
    required this.name,
    required this.status,
    required this.alignment,
    required this.insight,
    required this.questions,
    required this.isPriority,
  });

  factory ValueAlignment.fromJson(Map<String, dynamic> json) {
    return ValueAlignment(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String? ?? 'exploring',
      alignment: (json['alignment'] as num?)?.toDouble() ?? 50.0,
      insight: json['insight'] as String? ?? '',
      questions: json['questions'] as int? ?? 0,
      isPriority: json['isPriority'] as bool? ?? false,
    );
  }
}

/// Upcoming insight for "What's Coming" roadmap
class UpcomingInsight {
  final String id;
  final String title;
  final String unlockCondition;
  final int current;
  final int required;

  UpcomingInsight({
    required this.id,
    required this.title,
    required this.unlockCondition,
    required this.current,
    required this.required,
  });

  factory UpcomingInsight.fromJson(Map<String, dynamic> json) {
    return UpcomingInsight(
      id: json['id'] as String,
      title: json['title'] as String,
      unlockCondition: json['unlockCondition'] as String? ?? '',
      current: json['current'] as int? ?? 0,
      required: json['required'] as int? ?? 1,
    );
  }
}

/// Profile stats
class ProfileStats {
  final int totalQuizzes;
  final int questionsExplored;
  final int totalDiscoveries;
  final int unlockedDimensions;
  final int? nextUnlockAt;

  ProfileStats({
    required this.totalQuizzes,
    required this.questionsExplored,
    required this.totalDiscoveries,
    required this.unlockedDimensions,
    this.nextUnlockAt,
  });

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    return ProfileStats(
      totalQuizzes: json['totalQuizzes'] as int? ?? 0,
      questionsExplored: json['questionsExplored'] as int? ?? 0,
      totalDiscoveries: json['totalDiscoveries'] as int? ?? 0,
      unlockedDimensions: json['unlockedDimensions'] as int? ?? 0,
      nextUnlockAt: json['nextUnlockAt'] as int?,
    );
  }
}

/// Progressive reveal state
class ProgressiveReveal {
  final String level; // 'new' | 'early' | 'growing' | 'established'
  final bool showDimensions;
  final bool showLoveLanguages;
  final bool showFullProfile;
  final String? nextMilestone;

  ProgressiveReveal({
    required this.level,
    required this.showDimensions,
    required this.showLoveLanguages,
    required this.showFullProfile,
    this.nextMilestone,
  });

  factory ProgressiveReveal.fromJson(Map<String, dynamic> json) {
    return ProgressiveReveal(
      level: json['level'] as String? ?? 'new',
      showDimensions: json['showDimensions'] as bool? ?? false,
      showLoveLanguages: json['showLoveLanguages'] as bool? ?? false,
      showFullProfile: json['showFullProfile'] as bool? ?? false,
      nextMilestone: json['nextMilestone'] as String?,
    );
  }
}

/// Complete framed profile
class UsProfile {
  final List<FramedDimension> dimensions;
  final FramedLoveLanguage? loveLanguages;
  final List<FramedDiscovery> discoveries;
  final List<FramedPerception> partnerPerceptions;
  final List<GrowthEdge> growthEdges;
  final List<ConversationStarter> conversationStarters;
  final ProfileStats stats;
  final ProgressiveReveal progressiveReveal;
  final String userRole; // 'user1' or 'user2'
  final ActionStats actionStats;
  final WeeklyFocus? weeklyFocus;
  final List<ValueAlignment> values;
  final List<UpcomingInsight> upcomingInsights;

  UsProfile({
    required this.dimensions,
    this.loveLanguages,
    required this.discoveries,
    required this.partnerPerceptions,
    this.growthEdges = const [],
    required this.conversationStarters,
    required this.stats,
    required this.progressiveReveal,
    required this.userRole,
    required this.actionStats,
    this.weeklyFocus,
    required this.values,
    required this.upcomingInsights,
  });

  /// Check if this is a Day 1 experience (new user with minimal data)
  bool get isDay1 => stats.totalQuizzes <= 1;

  factory UsProfile.fromJson(Map<String, dynamic> json, String userRole) {
    final profile = json['profile'] as Map<String, dynamic>? ?? {};
    final starters = json['starters'] as List<dynamic>? ?? [];

    return UsProfile(
      dimensions: (profile['dimensions'] as List<dynamic>?)
              ?.map((e) => FramedDimension.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      loveLanguages: profile['loveLanguages'] != null
          ? FramedLoveLanguage.fromJson(
              profile['loveLanguages'] as Map<String, dynamic>)
          : null,
      discoveries: (profile['discoveries'] as List<dynamic>?)
              ?.map((e) => FramedDiscovery.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      partnerPerceptions: (profile['partnerPerceptions'] as List<dynamic>?)
              ?.map((e) => FramedPerception.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      growthEdges: (profile['growthEdges'] as List<dynamic>?)
              ?.map((e) => GrowthEdge.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      conversationStarters: starters
          .map((e) => ConversationStarter.fromJson(e as Map<String, dynamic>))
          .toList(),
      stats: ProfileStats.fromJson(
          profile['stats'] as Map<String, dynamic>? ?? {}),
      progressiveReveal: ProgressiveReveal.fromJson(
          profile['progressiveReveal'] as Map<String, dynamic>? ?? {}),
      userRole: userRole,
      actionStats: ActionStats.fromJson(
          profile['actionStats'] as Map<String, dynamic>? ?? {}),
      weeklyFocus: profile['weeklyFocus'] != null
          ? WeeklyFocus.fromJson(profile['weeklyFocus'] as Map<String, dynamic>)
          : null,
      values: (profile['values'] as List<dynamic>?)
              ?.map((e) => ValueAlignment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      upcomingInsights: (profile['upcomingInsights'] as List<dynamic>?)
              ?.map((e) => UpcomingInsight.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Quick stats for profile entry card preview
class UsProfileQuickStats {
  final int discoveryCount;
  final int dimensionCount;
  final int? valueAlignmentPercent;
  final bool hasData;
  final bool hasNewContent;

  UsProfileQuickStats({
    required this.discoveryCount,
    required this.dimensionCount,
    this.valueAlignmentPercent,
    required this.hasData,
    this.hasNewContent = false,
  });
}

// =============================================================================
// Service
// =============================================================================

/// Service for fetching and caching Us Profile data
class UsProfileService {
  static final UsProfileService _instance = UsProfileService._internal();
  factory UsProfileService() => _instance;
  UsProfileService._internal();

  static final ApiClient _apiClient = ApiClient();

  // Hive keys
  static const String _appMetadataBox = 'app_metadata';
  static const String _usProfileKey = 'us_profile';
  static const String _usProfileFetchedAtKey = 'us_profile_fetched_at';
  static const String _usProfileLastViewedAtKey = 'us_profile_last_viewed_at';
  static const String _usProfileLastViewedHashKey = 'us_profile_last_viewed_hash';

  /// Fetch profile from API
  ///
  /// Returns cached data if available and recent (< 5 minutes old)
  /// Otherwise fetches from server
  Future<UsProfile?> fetchProfile({bool forceRefresh = false}) async {
    try {
      final box = Hive.box(_appMetadataBox);

      // Check cache unless force refresh
      if (!forceRefresh) {
        final cachedAt = box.get(_usProfileFetchedAtKey) as DateTime?;
        final cached = box.get(_usProfileKey) as Map?;

        if (cachedAt != null &&
            cached != null &&
            DateTime.now().difference(cachedAt).inMinutes < 5) {
          Logger.debug('Using cached Us Profile', service: 'usprofile');
          final data = Map<String, dynamic>.from(cached);
          return UsProfile.fromJson(data, data['userRole'] as String? ?? 'user1');
        }
      }

      // Fetch from API
      Logger.debug('Fetching Us Profile from API...', service: 'usprofile');
      final response = await _apiClient.get('/api/us-profile');

      if (!response.success || response.data == null) {
        Logger.error('Failed to fetch Us Profile',
            error: response.error, service: 'usprofile');
        return null;
      }

      final data = response.data as Map<String, dynamic>;
      final userRole = data['userRole'] as String? ?? 'user1';

      // Cache the response
      await box.put(_usProfileKey, data);
      await box.put(_usProfileFetchedAtKey, DateTime.now());

      Logger.success('Us Profile fetched and cached', service: 'usprofile');
      return UsProfile.fromJson(data, userRole);
    } catch (e) {
      Logger.error('Error fetching Us Profile', error: e, service: 'usprofile');
      return null;
    }
  }

  /// Force recalculate profile on server
  Future<UsProfile?> recalculateProfile() async {
    try {
      Logger.debug('Requesting Us Profile recalculation...', service: 'usprofile');
      final response = await _apiClient.post('/api/us-profile');

      if (!response.success || response.data == null) {
        Logger.error('Failed to recalculate Us Profile',
            error: response.error, service: 'usprofile');
        return null;
      }

      final data = response.data as Map<String, dynamic>;
      final userRole = data['userRole'] as String? ?? 'user1';

      // Cache the response
      final box = Hive.box(_appMetadataBox);
      await box.put(_usProfileKey, data);
      await box.put(_usProfileFetchedAtKey, DateTime.now());

      Logger.success('Us Profile recalculated and cached', service: 'usprofile');
      return UsProfile.fromJson(data, userRole);
    } catch (e) {
      Logger.error('Error recalculating Us Profile', error: e, service: 'usprofile');
      return null;
    }
  }

  /// Get quick stats from cached profile (for entry card preview)
  /// Returns null if no cached profile exists
  UsProfileQuickStats? getCachedQuickStats() {
    try {
      final box = Hive.box(_appMetadataBox);
      final cached = box.get(_usProfileKey) as Map?;
      if (cached == null) return null;

      final data = Map<String, dynamic>.from(cached);

      // Extract quick stats
      final discoveries =
          (data['discoveries'] as List<dynamic>?)?.length ?? 0;
      final dimensions =
          (data['dimensions'] as List<dynamic>?)?.length ?? 0;
      final values = (data['values'] as List<dynamic>?) ?? [];

      // Calculate average alignment from values
      int alignmentSum = 0;
      int alignmentCount = 0;
      for (final v in values) {
        final percent = v['alignmentPercent'] as int?;
        if (percent != null) {
          alignmentSum += percent;
          alignmentCount++;
        }
      }
      final avgAlignment =
          alignmentCount > 0 ? (alignmentSum / alignmentCount).round() : null;

      return UsProfileQuickStats(
        discoveryCount: discoveries,
        dimensionCount: dimensions,
        valueAlignmentPercent: avgAlignment,
        hasData: discoveries > 0 || dimensions > 0,
        hasNewContent: hasNewContentSinceLastView(),
      );
    } catch (e) {
      Logger.error('Error getting cached quick stats',
          error: e, service: 'usprofile');
      return null;
    }
  }

  /// Generate a simple hash of profile content for change detection
  String _generateProfileContentHash(Map<String, dynamic> data) {
    final discoveries = (data['discoveries'] as List<dynamic>?)?.length ?? 0;
    final dimensions = (data['dimensions'] as List<dynamic>?)?.length ?? 0;
    final starters = (data['conversationStarters'] as List<dynamic>?)?.length ?? 0;
    final values = (data['values'] as List<dynamic>?)?.length ?? 0;
    // Simple hash based on counts - will detect new content
    return '$discoveries-$dimensions-$starters-$values';
  }

  /// Mark the profile as viewed (call when user opens UsProfileScreen)
  Future<void> markProfileViewed() async {
    try {
      final box = Hive.box(_appMetadataBox);
      await box.put(_usProfileLastViewedAtKey, DateTime.now());

      // Store hash of current content
      final cached = box.get(_usProfileKey) as Map?;
      if (cached != null) {
        final data = Map<String, dynamic>.from(cached);
        final hash = _generateProfileContentHash(data);
        await box.put(_usProfileLastViewedHashKey, hash);
      }

      Logger.debug('Profile marked as viewed', service: 'usprofile');
    } catch (e) {
      Logger.error('Error marking profile viewed', error: e, service: 'usprofile');
    }
  }

  /// Check if there's new content since the last time user viewed the profile
  bool hasNewContentSinceLastView() {
    try {
      final box = Hive.box(_appMetadataBox);
      final lastViewedHash = box.get(_usProfileLastViewedHashKey) as String?;
      final cached = box.get(_usProfileKey) as Map?;

      // If never viewed, any content is "new"
      if (lastViewedHash == null && cached != null) {
        return true;
      }

      // If no cached data, nothing new
      if (cached == null) {
        return false;
      }

      // Compare hashes
      final data = Map<String, dynamic>.from(cached);
      final currentHash = _generateProfileContentHash(data);
      return currentHash != lastViewedHash;
    } catch (e) {
      Logger.error('Error checking for new content', error: e, service: 'usprofile');
      return false;
    }
  }

  /// Get the last time the profile was viewed
  DateTime? getLastViewedAt() {
    try {
      final box = Hive.box(_appMetadataBox);
      return box.get(_usProfileLastViewedAtKey) as DateTime?;
    } catch (e) {
      return null;
    }
  }

  /// Dismiss a conversation starter
  Future<bool> dismissStarter(String starterId) async {
    try {
      final response = await _apiClient.post(
        '/api/us-profile/starter/$starterId',
        body: {'action': 'dismiss'},
      );

      if (!response.success) {
        Logger.error('Failed to dismiss starter',
            error: response.error, service: 'usprofile');
        return false;
      }

      // Invalidate cache
      final box = Hive.box(_appMetadataBox);
      await box.delete(_usProfileFetchedAtKey);

      return true;
    } catch (e) {
      Logger.error('Error dismissing starter', error: e, service: 'usprofile');
      return false;
    }
  }

  /// Mark a conversation starter as discussed
  Future<bool> markStarterDiscussed(String starterId) async {
    try {
      final response = await _apiClient.post(
        '/api/us-profile/starter/$starterId',
        body: {'action': 'discussed'},
      );

      if (!response.success) {
        Logger.error('Failed to mark starter discussed',
            error: response.error, service: 'usprofile');
        return false;
      }

      // Invalidate cache
      final box = Hive.box(_appMetadataBox);
      await box.delete(_usProfileFetchedAtKey);

      return true;
    } catch (e) {
      Logger.error('Error marking starter discussed', error: e, service: 'usprofile');
      return false;
    }
  }

  /// Clear cache (for testing/debugging)
  Future<void> clearCache() async {
    final box = Hive.box(_appMetadataBox);
    await box.delete(_usProfileKey);
    await box.delete(_usProfileFetchedAtKey);
    Logger.info('Us Profile cache cleared', service: 'usprofile');
  }
}

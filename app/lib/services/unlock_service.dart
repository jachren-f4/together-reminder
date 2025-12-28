import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'api_client.dart';
import '../utils/logger.dart';

/// Represents the unlock state for a couple's onboarding progression.
///
/// Each feature is unlocked sequentially after completing the previous one:
/// Pairing → Welcome Quiz → Classic + Affirmation → You or Me → Linked → Word Search → Steps
class UnlockState {
  final String coupleId;
  final bool welcomeQuizCompleted;
  final bool classicQuizUnlocked;
  final bool classicQuizCompleted;
  final bool affirmationQuizUnlocked;
  final bool affirmationQuizCompleted;
  final bool youOrMeUnlocked;
  final bool linkedUnlocked;
  final bool wordSearchUnlocked;
  final bool stepsUnlocked;
  final bool onboardingCompleted;
  final bool lpIntroShown;

  const UnlockState({
    required this.coupleId,
    this.welcomeQuizCompleted = false,
    this.classicQuizUnlocked = false,
    this.classicQuizCompleted = false,
    this.affirmationQuizUnlocked = false,
    this.affirmationQuizCompleted = false,
    this.youOrMeUnlocked = false,
    this.linkedUnlocked = false,
    this.wordSearchUnlocked = false,
    this.stepsUnlocked = false,
    this.onboardingCompleted = false,
    this.lpIntroShown = false,
  });

  /// Create from API response JSON
  factory UnlockState.fromJson(Map<String, dynamic> json) {
    return UnlockState(
      coupleId: json['coupleId'] as String? ?? '',
      welcomeQuizCompleted: json['welcomeQuizCompleted'] as bool? ?? false,
      classicQuizUnlocked: json['classicQuizUnlocked'] as bool? ?? false,
      classicQuizCompleted: json['classicQuizCompleted'] as bool? ?? false,
      affirmationQuizUnlocked: json['affirmationQuizUnlocked'] as bool? ?? false,
      affirmationQuizCompleted: json['affirmationQuizCompleted'] as bool? ?? false,
      youOrMeUnlocked: json['youOrMeUnlocked'] as bool? ?? false,
      linkedUnlocked: json['linkedUnlocked'] as bool? ?? false,
      wordSearchUnlocked: json['wordSearchUnlocked'] as bool? ?? false,
      stepsUnlocked: json['stepsUnlocked'] as bool? ?? false,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      lpIntroShown: json['lpIntroShown'] as bool? ?? false,
    );
  }

  /// Default state for existing users - all features unlocked
  factory UnlockState.allUnlocked(String coupleId) {
    return UnlockState(
      coupleId: coupleId,
      welcomeQuizCompleted: true,
      classicQuizUnlocked: true,
      classicQuizCompleted: true,
      affirmationQuizUnlocked: true,
      affirmationQuizCompleted: true,
      youOrMeUnlocked: true,
      linkedUnlocked: true,
      wordSearchUnlocked: true,
      stepsUnlocked: true,
      onboardingCompleted: true,
      lpIntroShown: true,
    );
  }

  /// Check if a feature is unlocked
  bool isFeatureUnlocked(UnlockableFeature feature) {
    switch (feature) {
      case UnlockableFeature.welcomeQuiz:
        return true; // Always available after pairing
      case UnlockableFeature.classicQuiz:
        return classicQuizUnlocked;
      case UnlockableFeature.affirmationQuiz:
        return affirmationQuizUnlocked;
      case UnlockableFeature.youOrMe:
        return youOrMeUnlocked;
      case UnlockableFeature.linked:
        return linkedUnlocked;
      case UnlockableFeature.wordSearch:
        return wordSearchUnlocked;
      case UnlockableFeature.steps:
        return stepsUnlocked;
    }
  }

  /// Get the unlock criteria text for a locked feature
  String getUnlockCriteria(UnlockableFeature feature) {
    switch (feature) {
      case UnlockableFeature.welcomeQuiz:
        return 'Available now';
      case UnlockableFeature.classicQuiz:
      case UnlockableFeature.affirmationQuiz:
        return 'Complete Welcome Quiz first';
      case UnlockableFeature.youOrMe:
        return 'Complete quizzes first';
      case UnlockableFeature.linked:
        return 'Complete You or Me first';
      case UnlockableFeature.wordSearch:
        return 'Complete crossword first';
      case UnlockableFeature.steps:
        return 'Complete Word Search first';
    }
  }

  /// Get the current guidance target (next uncompleted activity in the onboarding chain).
  ///
  /// Returns [GuidanceTarget.none] if all activities are complete or if
  /// the next activity isn't unlocked yet.
  ///
  /// Progression: Classic → Affirmation → You or Me → Linked → Word Search
  /// (Steps is skipped in guidance)
  GuidanceTarget get currentGuidanceTarget {
    // Daily quizzes - completion directly tracked
    if (!classicQuizCompleted) return GuidanceTarget.classicQuiz;
    if (!affirmationQuizCompleted) return GuidanceTarget.affirmationQuiz;

    // Side quests - derive completion from unlock chain
    // If youOrMe is unlocked but linked is not, user needs to do youOrMe
    if (!youOrMeUnlocked) return GuidanceTarget.none; // Not unlocked yet, wait
    if (!linkedUnlocked) return GuidanceTarget.youOrMe;
    if (!wordSearchUnlocked) return GuidanceTarget.linked;
    if (!onboardingCompleted) return GuidanceTarget.wordSearch;

    return GuidanceTarget.none; // All done!
  }

  /// Get the guidance ribbon text for the current target.
  ///
  /// Returns "Start Here" for Classic Quiz (first activity),
  /// "Continue Here" for all subsequent activities,
  /// or null if no guidance needed.
  String? get guidanceText {
    final target = currentGuidanceTarget;
    if (target == GuidanceTarget.none) return null;
    if (target == GuidanceTarget.classicQuiz) return 'Start Here';
    return 'Continue Here';
  }

  @override
  String toString() {
    return 'UnlockState(coupleId: $coupleId, welcomeQuizCompleted: $welcomeQuizCompleted, '
        'classicQuizUnlocked: $classicQuizUnlocked, youOrMeUnlocked: $youOrMeUnlocked, '
        'linkedUnlocked: $linkedUnlocked, wordSearchUnlocked: $wordSearchUnlocked, '
        'stepsUnlocked: $stepsUnlocked, onboardingCompleted: $onboardingCompleted)';
  }
}

/// Features that can be unlocked during onboarding
enum UnlockableFeature {
  welcomeQuiz,
  classicQuiz,
  affirmationQuiz,
  youOrMe,
  linked,
  wordSearch,
  steps,
}

/// Target for onboarding guidance (ribbon + floating hand)
enum GuidanceTarget {
  classicQuiz, // "Start Here"
  affirmationQuiz, // "Continue Here"
  youOrMe, // "Continue Here"
  linked, // "Continue Here"
  wordSearch, // "Continue Here"
  none, // All done, no guidance needed
}

/// Triggers that unlock features
enum UnlockTrigger {
  welcomeQuiz, // Unlocks classic_quiz + affirmation_quiz
  dailyQuiz, // Unlocks you_or_me
  youOrMe, // Unlocks linked
  linked, // Unlocks word_search
  wordSearch, // Unlocks steps
}

/// Result from completing an unlock trigger
class UnlockResult {
  final bool success;
  final int lpAwarded;
  final List<String> newlyUnlocked;
  final UnlockState unlockState;

  const UnlockResult({
    required this.success,
    required this.lpAwarded,
    required this.newlyUnlocked,
    required this.unlockState,
  });

  factory UnlockResult.fromJson(Map<String, dynamic> json) {
    return UnlockResult(
      success: json['success'] as bool? ?? false,
      lpAwarded: json['lpAwarded'] as int? ?? 0,
      newlyUnlocked: (json['newlyUnlocked'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      unlockState: UnlockState.fromJson(
          json['unlockState'] as Map<String, dynamic>? ?? {}),
    );
  }

  bool get hasNewUnlocks => newlyUnlocked.isNotEmpty;
}

/// Service for managing feature unlock state during onboarding.
///
/// Uses in-memory caching with server as source of truth.
/// Both partners share the same unlock state.
class UnlockService {
  static final UnlockService _instance = UnlockService._internal();
  factory UnlockService() => _instance;
  UnlockService._internal();

  final ApiClient _apiClient = ApiClient();

  /// Cached unlock state (in-memory only, no Hive)
  UnlockState? _cachedState;

  /// Callbacks for UI updates when unlock state changes
  /// Multiple widgets can register to be notified (e.g., DailyQuestsWidget, HomeScreen)
  final List<VoidCallback> _onUnlockChangedCallbacks = [];

  /// Add a callback for unlock state changes
  /// Remember to call removeOnUnlockChanged in dispose()
  void addOnUnlockChanged(VoidCallback callback) {
    if (!_onUnlockChangedCallbacks.contains(callback)) {
      _onUnlockChangedCallbacks.add(callback);
    }
  }

  /// Remove a callback for unlock state changes
  void removeOnUnlockChanged(VoidCallback callback) {
    _onUnlockChangedCallbacks.remove(callback);
  }

  /// @deprecated Use addOnUnlockChanged/removeOnUnlockChanged instead
  /// Kept for backwards compatibility during migration
  void setOnUnlockChanged(VoidCallback? callback) {
    // Clear all and set single callback (legacy behavior)
    _onUnlockChangedCallbacks.clear();
    if (callback != null) {
      _onUnlockChangedCallbacks.add(callback);
    }
  }

  /// Notify all registered callbacks
  void _notifyUnlockChanged() {
    for (final callback in _onUnlockChangedCallbacks) {
      callback();
    }
  }

  /// Get unlock state (from cache or server)
  ///
  /// [forceRefresh] - If true, always fetches from server
  Future<UnlockState?> getUnlockState({bool forceRefresh = false}) async {
    // Return cached state if available and not forcing refresh
    if (_cachedState != null && !forceRefresh) {
      return _cachedState;
    }

    try {
      final response = await _apiClient.get<UnlockState>(
        '/api/unlocks',
        parser: (json) => UnlockState.fromJson(json),
      );

      if (response.success && response.data != null) {
        _cachedState = response.data;
        Logger.debug(
            'Fetched unlock state: ${_cachedState?.onboardingCompleted}',
            service: 'unlock');
        return _cachedState;
      } else {
        Logger.warn('Failed to fetch unlock state: ${response.error}',
            service: 'unlock');
        return null;
      }
    } catch (e) {
      Logger.error('Error fetching unlock state: $e', service: 'unlock');
      return null;
    }
  }

  /// Check if a specific feature is unlocked
  Future<bool> isUnlocked(UnlockableFeature feature) async {
    final state = await getUnlockState();
    return state?.isFeatureUnlocked(feature) ?? true; // Default to unlocked for existing users
  }

  /// Check if onboarding is completed
  Future<bool> isOnboardingCompleted() async {
    final state = await getUnlockState();
    return state?.onboardingCompleted ?? true; // Default to true for existing users
  }

  /// Check if LP intro has been shown
  Future<bool> hasLpIntroBeenShown() async {
    final state = await getUnlockState();
    return state?.lpIntroShown ?? true; // Default to true for existing users
  }

  /// Mark LP intro as shown
  Future<void> markLpIntroShown() async {
    try {
      final response = await _apiClient.patch<UnlockState>(
        '/api/unlocks',
        body: {'lpIntroShown': true},
        parser: (json) => UnlockState.fromJson(json),
      );

      if (response.success && response.data != null) {
        _cachedState = response.data;
        Logger.debug('Marked LP intro as shown', service: 'unlock');
      }
    } catch (e) {
      Logger.error('Error marking LP intro shown: $e', service: 'unlock');
    }
  }

  /// Notify server of a completion and get unlock result
  ///
  /// Returns the unlock result with any newly unlocked features and LP awarded.
  /// For [UnlockTrigger.dailyQuiz], provide the [quizType] ('classic' or 'affirmation')
  /// to track which quiz type was completed.
  Future<UnlockResult?> notifyCompletion(UnlockTrigger trigger, {String? quizType}) async {
    try {
      final triggerName = _triggerToString(trigger);
      Logger.debug('Notifying completion: $triggerName${quizType != null ? ' (type: $quizType)' : ''}', service: 'unlock');

      final body = <String, dynamic>{'trigger': triggerName};
      if (quizType != null) {
        body['quizType'] = quizType;
      }

      final response = await _apiClient.post<UnlockResult>(
        '/api/unlocks/complete',
        body: body,
        parser: (json) => UnlockResult.fromJson(json),
      );

      if (response.success && response.data != null) {
        final result = response.data!;

        // Update cached state
        _cachedState = result.unlockState;

        // Notify all listeners
        if (result.hasNewUnlocks) {
          Logger.info(
              'Unlocked: ${result.newlyUnlocked.join(', ')} (+${result.lpAwarded} LP)',
              service: 'unlock');
          _notifyUnlockChanged();
        }

        return result;
      } else {
        Logger.warn('Failed to notify completion: ${response.error}',
            service: 'unlock');
        return null;
      }
    } catch (e) {
      Logger.error('Error notifying completion: $e', service: 'unlock');
      return null;
    }
  }

  /// Clear cached state (call on logout)
  void clearCache() {
    _cachedState = null;
  }

  /// Get cached state synchronously (may be null)
  UnlockState? get cachedState => _cachedState;

  /// Track which unlock celebrations this user has seen (stored locally in Hive)
  /// This is per-user because both partners should see the celebration
  static const String _seenCelebrationsKey = 'seen_unlock_celebrations';

  /// Check if user has seen a specific unlock celebration
  bool hasSeenCelebration(String unlockName) {
    try {
      final box = Hive.box('app_metadata');
      final seen = box.get(_seenCelebrationsKey, defaultValue: <String>[]);
      return (seen as List).contains(unlockName);
    } catch (e) {
      Logger.error('Error checking seen celebration: $e', service: 'unlock');
      return false;
    }
  }

  /// Mark a celebration as seen for this user
  Future<void> markCelebrationSeen(String unlockName) async {
    try {
      final box = Hive.box('app_metadata');
      final seen = List<String>.from(
          box.get(_seenCelebrationsKey, defaultValue: <String>[]) as List);
      if (!seen.contains(unlockName)) {
        seen.add(unlockName);
        await box.put(_seenCelebrationsKey, seen);
        Logger.debug('Marked celebration as seen: $unlockName',
            service: 'unlock');
      }
    } catch (e) {
      Logger.error('Error marking celebration seen: $e', service: 'unlock');
    }
  }

  /// Check if You or Me unlock should show celebration
  /// Returns true if feature is unlocked but user hasn't seen the celebration yet
  Future<bool> shouldShowYouOrMeCelebration() async {
    final state = await getUnlockState(forceRefresh: true);
    if (state == null) return false;

    // Check if You or Me is unlocked but user hasn't seen the celebration
    return state.youOrMeUnlocked && !hasSeenCelebration('you_or_me');
  }

  String _triggerToString(UnlockTrigger trigger) {
    switch (trigger) {
      case UnlockTrigger.welcomeQuiz:
        return 'welcome_quiz';
      case UnlockTrigger.dailyQuiz:
        return 'daily_quiz';
      case UnlockTrigger.youOrMe:
        return 'you_or_me';
      case UnlockTrigger.linked:
        return 'linked';
      case UnlockTrigger.wordSearch:
        return 'word_search';
    }
  }
}

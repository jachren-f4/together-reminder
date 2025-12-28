import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';
import 'storage_service.dart';
import 'api_client.dart';
import 'linked_service.dart';
import 'word_search_service.dart';

/// Unified polling service for the home screen
///
/// Consolidates all home screen polling into a single timer:
/// - Daily quest completion status
/// - Linked game turn state
/// - Word Search game turn state
///
/// Benefits:
/// - Single network request batch per poll interval
/// - Reduced battery/bandwidth usage
/// - Centralized change detection
/// - Widgets subscribe to topics they care about
class HomePollingService extends ChangeNotifier {
  static final HomePollingService _instance = HomePollingService._internal();
  factory HomePollingService() => _instance;
  HomePollingService._internal();

  // Dependencies (lazy initialized)
  final StorageService _storage = StorageService();
  final ApiClient _apiClient = ApiClient();
  final LinkedService _linkedService = LinkedService();
  final WordSearchService _wordSearchService = WordSearchService();

  // Polling configuration
  static const Duration _pollingInterval = Duration(seconds: 5);
  Timer? _pollingTimer;
  bool _isPolling = false;
  int _subscriberCount = 0;

  // Cached state for change detection
  String? _lastLinkedTurnUserId;
  String? _lastLinkedStatus;
  String? _lastWsTurnUserId;
  String? _lastWsStatus;
  Map<String, bool> _lastQuestCompletions = {};
  Map<String, String> _lastQuestMatchIds = {}; // Track matchId per quest type

  // Topic-specific callbacks (for widgets that need fine-grained updates)
  final Map<String, Set<VoidCallback>> _topicListeners = {
    'dailyQuests': {},
    'sideQuests': {},
    'linked': {},
    'wordSearch': {},
  };

  /// Subscribe to polling updates
  ///
  /// Call this in widget initState. The service auto-starts when first subscriber joins.
  void subscribe() {
    _subscriberCount++;
    Logger.debug('HomePollingService: subscriber joined (count: $_subscriberCount)', service: 'polling');

    if (_subscriberCount == 1) {
      _startPolling();
    }
  }

  /// Unsubscribe from polling updates
  ///
  /// Call this in widget dispose. The service auto-stops when last subscriber leaves.
  void unsubscribe() {
    _subscriberCount--;
    Logger.debug('HomePollingService: subscriber left (count: $_subscriberCount)', service: 'polling');

    if (_subscriberCount <= 0) {
      _subscriberCount = 0;
      _stopPolling();
    }
  }

  /// Subscribe to a specific topic for fine-grained updates
  void subscribeToTopic(String topic, VoidCallback callback) {
    _topicListeners[topic]?.add(callback);
  }

  /// Unsubscribe from a specific topic
  void unsubscribeFromTopic(String topic, VoidCallback callback) {
    _topicListeners[topic]?.remove(callback);
  }

  /// Force an immediate poll (e.g., when returning from a game screen)
  /// This bypasses the _isPolling check to work even before subscribers join
  Future<void> pollNow() async {
    await _pollOnce();
  }

  /// Single poll that always executes (doesn't check _isPolling)
  Future<void> _pollOnce() async {
    Logger.debug('⏱️ pollNow() executing...', service: 'polling');

    try {
      bool hasQuestChanges = false;
      bool hasLinkedChanges = false;
      bool hasWsChanges = false;

      // Poll daily quests
      hasQuestChanges = await _pollDailyQuests();

      // Poll Linked game state
      hasLinkedChanges = await _pollLinkedGame();

      // Poll Word Search game state
      hasWsChanges = await _pollWordSearchGame();

      Logger.debug('⏱️ pollNow() results: quests=$hasQuestChanges, linked=$hasLinkedChanges, ws=$hasWsChanges', service: 'polling');

      // Notify listeners based on what changed (same as _poll())
      if (hasQuestChanges) {
        _notifyTopic('dailyQuests');
      }

      if (hasLinkedChanges) {
        _notifyTopic('linked');
        _notifyTopic('sideQuests');
      }

      if (hasWsChanges) {
        _notifyTopic('wordSearch');
        _notifyTopic('sideQuests');
      }

      // Always notify general listeners if anything changed
      if (hasQuestChanges || hasLinkedChanges || hasWsChanges) {
        notifyListeners();
      }

      Logger.debug('⏱️ pollNow() completed', service: 'polling');
    } catch (e) {
      Logger.error('pollNow() error', error: e, service: 'polling');
    }
  }

  void _startPolling() {
    if (_isPolling) return;
    _isPolling = true;

    Logger.debug('HomePollingService: starting polling', service: 'polling');

    // Initial poll
    _poll();

    // Set up periodic polling
    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      _poll();
    });
  }

  void _stopPolling() {
    if (!_isPolling) return;
    _isPolling = false;

    Logger.debug('HomePollingService: stopping polling', service: 'polling');

    _pollingTimer?.cancel();
    _pollingTimer = null;

    // Clear cached state
    _lastLinkedTurnUserId = null;
    _lastLinkedStatus = null;
    _lastWsTurnUserId = null;
    _lastWsStatus = null;
    _lastQuestCompletions = {};
    _lastQuestMatchIds = {};
  }

  /// Main polling function - fetches all state and notifies on changes
  Future<void> _poll() async {
    if (!_isPolling) return;

    Logger.debug('⏱️ Poll cycle starting...', service: 'polling');

    try {
      bool hasQuestChanges = false;
      bool hasLinkedChanges = false;
      bool hasWsChanges = false;

      // 1. Poll daily quest status
      hasQuestChanges = await _pollDailyQuests();

      // 2. Poll Linked game state (if active)
      hasLinkedChanges = await _pollLinkedGame();

      // 3. Poll Word Search game state (if active)
      hasWsChanges = await _pollWordSearchGame();

      Logger.debug('⏱️ Poll results: quests=$hasQuestChanges, linked=$hasLinkedChanges, ws=$hasWsChanges', service: 'polling');

      // Notify listeners based on what changed
      if (hasQuestChanges) {
        _notifyTopic('dailyQuests');
      }

      if (hasLinkedChanges) {
        _notifyTopic('linked');
        _notifyTopic('sideQuests');
      }

      if (hasWsChanges) {
        _notifyTopic('wordSearch');
        _notifyTopic('sideQuests');
      }

      // Always notify general listeners (ChangeNotifier pattern)
      if (hasQuestChanges || hasLinkedChanges || hasWsChanges) {
        notifyListeners();
      }
    } catch (e) {
      Logger.error('HomePollingService: poll error', error: e, service: 'polling');
    }
  }

  /// Poll daily quest completion status
  Future<bool> _pollDailyQuests() async {
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    if (user == null || partner == null) {
      return false;
    }

    try {
      final response = await _apiClient.get('/api/sync/quest-status');

      if (!response.success || response.data == null) {
        return false;
      }

      final questsData = response.data['quests'] as List<dynamic>?;
      if (questsData == null || questsData.isEmpty) {
        return false;
      }

      bool anyChanges = false;
      final newCompletions = <String, bool>{};

      final newMatchIds = <String, String>{};

      for (final questData in questsData) {
        final questType = questData['questType'] as String?;
        final partnerCompleted = questData['partnerCompleted'] as bool? ?? false;
        final userCompleted = questData['userCompleted'] as bool? ?? false;
        final matchId = questData['matchId'] as String?;
        final matchStatus = questData['status'] as String?;

        Logger.debug(
          '📊 Poll received: $questType status=$matchStatus user=$userCompleted partner=$partnerCompleted matchId=$matchId',
          service: 'polling',
        );

        if (questType == null) continue;

        final key = '${questType}_partner';
        newCompletions[key] = partnerCompleted;

        // Track matchId for this quest type
        if (matchId != null) {
          newMatchIds[questType] = matchId;
        }

        // Check if partner completion changed
        if (_lastQuestCompletions[key] != partnerCompleted) {
          anyChanges = true;
        }

        // Get local quest
        final localQuests = _storage.getTodayQuests();
        final normalizedQuestType = questType == 'you_or_me' ? 'youOrMe' : questType;
        final matchingQuest = localQuests.where((q) => q.formatType == normalizedQuestType).firstOrNull;

        if (matchingQuest == null) continue;

        // Check if this is a NEW match (different matchId than before)
        // This happens when couple starts a new quiz after completing the previous one
        final previousMatchId = _lastQuestMatchIds[questType];
        final isNewMatch = matchId != null && previousMatchId != null && matchId != previousMatchId;

        if (isNewMatch) {
          Logger.debug('HomePollingService: NEW MATCH detected for $questType - resetting completions (was: $previousMatchId, now: $matchId)', service: 'polling');
          // Reset local quest state for the new match
          matchingQuest.userCompletions = {};
          matchingQuest.status = 'pending';
          // Use explicit box.put() instead of HiveObject.save() to ensure persistence
          await _storage.saveDailyQuest(matchingQuest);
          anyChanges = true;
        }

        // Now sync completion states from server
        final completions = matchingQuest.userCompletions ?? {};
        bool questUpdated = false;

        // Check if user was already tracked as completed locally BEFORE any syncing
        // This distinguishes between:
        // 1. "Partner just completed while user was waiting" (user was already locally marked)
        // 2. "First sync after login with already-completed quests" (nothing was locally marked)
        final wasUserAlreadyLocallyCompleted = completions[user.id] == true;

        // Sync user completion (in case it got out of sync)
        if (userCompleted && completions[user.id] != true) {
          completions[user.id] = true;
          questUpdated = true;
        }

        // Sync partner completion
        // Track if partner JUST completed (for pending results flag)
        final partnerJustCompleted = partnerCompleted && completions[partner.id] != true;
        if (partnerJustCompleted) {
          completions[partner.id] = true;
          questUpdated = true;
        }

        // Update status based on match status from server
        if (matchStatus == 'completed' && matchingQuest.status != 'completed') {
          matchingQuest.status = 'completed';
          questUpdated = true;
        } else if (completions[user.id] == true && completions[partner.id] == true && matchingQuest.status != 'completed') {
          matchingQuest.status = 'completed';
          questUpdated = true;
        }

        if (questUpdated) {
          matchingQuest.userCompletions = completions;
          // Use explicit box.put() instead of HiveObject.save() to ensure persistence
          await _storage.saveDailyQuest(matchingQuest);
          anyChanges = true;
          Logger.debug('HomePollingService: updated quest $questType - user:$userCompleted partner:$partnerCompleted status:${matchingQuest.status}', service: 'polling');
        }

        // CRITICAL: If user was ALREADY locally marked as done and partner JUST completed, set pending results flag
        // This ensures "RESULTS ARE READY!" shows even if the waiting screen didn't set it
        // (e.g., user went back to home before waiting screen's async setPending completed)
        //
        // IMPORTANT: We use wasUserAlreadyLocallyCompleted (not just userCompleted) to avoid
        // setting the flag on initial sync after login. On first sync, both completions are being
        // synced from server - this is NOT a "partner just completed while user was waiting" scenario.
        if (wasUserAlreadyLocallyCompleted && partnerJustCompleted && matchId != null) {
          // Map quest type to content type key used for pending results
          String? contentType;
          if (questType == 'classic') {
            contentType = 'classic_quiz';
          } else if (questType == 'affirmation') {
            contentType = 'affirmation_quiz';
          } else if (questType == 'you_or_me') {
            contentType = 'you_or_me';
          }

          if (contentType != null) {
            // Only set if not already set (don't overwrite)
            final existingPending = _storage.getPendingResultsMatchId(contentType);
            if (existingPending == null) {
              await _storage.setPendingResultsMatchId(contentType, matchId);
              Logger.debug('HomePollingService: SET PENDING FLAG for $contentType (partner just completed, matchId=$matchId)', service: 'polling');
            }
          }
        }
      }

      _lastQuestMatchIds = newMatchIds;

      _lastQuestCompletions = newCompletions;
      return anyChanges;
    } catch (e) {
      Logger.error('HomePollingService: quest poll error', error: e, service: 'polling');
      return false;
    }
  }

  /// Poll Linked game state
  Future<bool> _pollLinkedGame() async {
    final linkedMatch = _storage.getActiveLinkedMatch();

    Logger.debug(
      '🔗 Linked Poll: cached match=${linkedMatch?.matchId ?? "none"}, status=${linkedMatch?.status ?? "none"}, turn=${linkedMatch?.currentTurnUserId ?? "none"}',
      service: 'polling',
    );

    try {
      if (linkedMatch == null || linkedMatch.status != 'active') {
        // No local cache - try to fetch from server (partner may have started a game)
        Logger.debug('🔗 Linked Poll: no cached match, checking server...', service: 'polling');

        try {
          final gameState = await _linkedService.getOrCreateMatch();
          final newTurnUserId = gameState.match.currentTurnUserId;
          final newStatus = gameState.match.status;

          Logger.debug(
            '🔗 Linked Poll: server returned match - turn=$newTurnUserId, status=$newStatus',
            service: 'polling',
          );

          // Check if this is a new match we didn't know about
          final hasChanges = _lastLinkedTurnUserId != newTurnUserId ||
                             _lastLinkedStatus != newStatus;

          if (hasChanges) {
            Logger.debug(
              '🔗 Linked Poll: NEW MATCH DETECTED - turn=$newTurnUserId, status=$newStatus',
              service: 'polling',
            );
          }

          _lastLinkedTurnUserId = newTurnUserId;
          _lastLinkedStatus = newStatus;

          return hasChanges;
        } catch (e) {
          // Cooldown or no match available - this is normal
          Logger.debug('🔗 Linked Poll: no match available (cooldown or none exists)', service: 'polling');
          final hadState = _lastLinkedTurnUserId != null;
          _lastLinkedTurnUserId = null;
          _lastLinkedStatus = null;
          return hadState;
        }
      }

      // Have cached match - poll for updates
      Logger.debug('🔗 Linked Poll: calling API for match ${linkedMatch.matchId}', service: 'polling');
      await _linkedService.pollMatchState(linkedMatch.matchId);

      // Re-read from Hive after poll
      final updatedMatch = _storage.getActiveLinkedMatch();
      final newTurnUserId = updatedMatch?.currentTurnUserId;
      final newStatus = updatedMatch?.status;

      Logger.debug(
        '🔗 Linked Poll: API returned - turn=$newTurnUserId, status=$newStatus (was: turn=$_lastLinkedTurnUserId, status=$_lastLinkedStatus)',
        service: 'polling',
      );

      final hasChanges = _lastLinkedTurnUserId != newTurnUserId ||
                         _lastLinkedStatus != newStatus;

      if (hasChanges) {
        Logger.debug(
          '🔗 Linked Poll: CHANGE DETECTED - turn: $_lastLinkedTurnUserId→$newTurnUserId, status: $_lastLinkedStatus→$newStatus',
          service: 'polling',
        );
      }

      _lastLinkedTurnUserId = newTurnUserId;
      _lastLinkedStatus = newStatus;

      return hasChanges;
    } catch (e) {
      Logger.error('🔗 Linked Poll: API error', error: e, service: 'polling');
      return false;
    }
  }

  /// Poll Word Search game state
  Future<bool> _pollWordSearchGame() async {
    final wsMatch = _storage.getActiveWordSearchMatch();

    Logger.debug(
      '🔎 WS Poll: cached match=${wsMatch?.matchId ?? "none"}, status=${wsMatch?.status ?? "none"}, turn=${wsMatch?.currentTurnUserId ?? "none"}',
      service: 'polling',
    );

    try {
      if (wsMatch == null || wsMatch.status != 'active') {
        // No local cache - try to fetch from server (partner may have started a game)
        Logger.debug('🔎 WS Poll: no cached match, checking server...', service: 'polling');

        try {
          final gameState = await _wordSearchService.getOrCreateMatch();
          final newTurnUserId = gameState.match.currentTurnUserId;
          final newStatus = gameState.match.status;

          Logger.debug(
            '🔎 WS Poll: server returned match - turn=$newTurnUserId, status=$newStatus',
            service: 'polling',
          );

          // Check if this is a new match we didn't know about
          final hasChanges = _lastWsTurnUserId != newTurnUserId ||
                             _lastWsStatus != newStatus;

          if (hasChanges) {
            Logger.debug(
              '🔎 WS Poll: NEW MATCH DETECTED - turn=$newTurnUserId, status=$newStatus',
              service: 'polling',
            );
          }

          _lastWsTurnUserId = newTurnUserId;
          _lastWsStatus = newStatus;

          return hasChanges;
        } catch (e) {
          // Cooldown or no match available - this is normal
          Logger.debug('🔎 WS Poll: no match available (cooldown or none exists)', service: 'polling');
          final hadState = _lastWsTurnUserId != null;
          _lastWsTurnUserId = null;
          _lastWsStatus = null;
          return hadState;
        }
      }

      // Have cached match - poll for updates
      Logger.debug('🔎 WS Poll: calling API for match ${wsMatch.matchId}', service: 'polling');
      await _wordSearchService.pollMatchState(wsMatch.matchId);

      // Re-read from Hive after poll
      final updatedMatch = _storage.getActiveWordSearchMatch();
      final newTurnUserId = updatedMatch?.currentTurnUserId;
      final newStatus = updatedMatch?.status;

      Logger.debug(
        '🔎 WS Poll: API returned - turn=$newTurnUserId, status=$newStatus (was: turn=$_lastWsTurnUserId, status=$_lastWsStatus)',
        service: 'polling',
      );

      final hasChanges = _lastWsTurnUserId != newTurnUserId ||
                         _lastWsStatus != newStatus;

      if (hasChanges) {
        Logger.debug(
          '🔎 WS Poll: CHANGE DETECTED - turn: $_lastWsTurnUserId→$newTurnUserId, status: $_lastWsStatus→$newStatus',
          service: 'polling',
        );
      }

      _lastWsTurnUserId = newTurnUserId;
      _lastWsStatus = newStatus;

      return hasChanges;
    } catch (e) {
      Logger.error('🔎 WS Poll: API error', error: e, service: 'polling');
      return false;
    }
  }

  /// Notify listeners subscribed to a specific topic
  void _notifyTopic(String topic) {
    final listeners = _topicListeners[topic];
    if (listeners != null) {
      for (final callback in listeners) {
        callback();
      }
    }
  }

  /// Get current turn user ID for Linked game (for widget key generation)
  String? get linkedTurnUserId => _lastLinkedTurnUserId;

  /// Get current turn user ID for Word Search game (for widget key generation)
  String? get wordSearchTurnUserId => _lastWsTurnUserId;

  // Debug getters
  bool get isPolling => _isPolling;
  int get subscriberCount => _subscriberCount;
  String? get lastLinkedStatus => _lastLinkedStatus;
  String? get lastWsStatus => _lastWsStatus;
  Map<String, int> get topicListenerCounts => {
    'dailyQuests': _topicListeners['dailyQuests']?.length ?? 0,
    'sideQuests': _topicListeners['sideQuests']?.length ?? 0,
    'linked': _topicListeners['linked']?.length ?? 0,
    'wordSearch': _topicListeners['wordSearch']?.length ?? 0,
  };
}

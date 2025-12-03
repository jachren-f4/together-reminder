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
  Future<void> pollNow() async {
    await _poll();
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

      for (final questData in questsData) {
        final questType = questData['questType'] as String?;
        final partnerCompleted = questData['partnerCompleted'] as bool? ?? false;

        if (questType == null) continue;

        final key = '${questType}_partner';
        newCompletions[key] = partnerCompleted;

        // Check if partner completion changed
        if (_lastQuestCompletions[key] != partnerCompleted) {
          anyChanges = true;
        }

        // Update local quest if partner completed
        if (partnerCompleted) {
          final localQuests = _storage.getTodayQuests();
          final normalizedQuestType = questType == 'you_or_me' ? 'youOrMe' : questType;
          final matchingQuest = localQuests.where((q) => q.formatType == normalizedQuestType).firstOrNull;

          if (matchingQuest != null) {
            final completions = matchingQuest.userCompletions ?? {};
            if (completions[partner.id] != true) {
              completions[partner.id] = true;
              matchingQuest.userCompletions = completions;

              // Check if both completed
              if (completions[user.id] == true && completions[partner.id] == true) {
                matchingQuest.status = 'completed';
              }

              await matchingQuest.save();
              anyChanges = true;
              Logger.debug('HomePollingService: updated quest $questType - partner completed', service: 'polling');
            }
          }
        }
      }

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

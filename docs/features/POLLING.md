# Polling Architecture

This document describes how TogetherRemind handles real-time updates between partners using HTTP polling instead of WebSockets or Firebase Realtime Database.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [HomePollingService](#homepollingservice)
4. [Game Screen Polling](#game-screen-polling)
5. [API Endpoints](#api-endpoints)
6. [Change Detection](#change-detection)
7. [Widget Integration](#widget-integration)
8. [Debugging](#debugging)
9. [Best Practices](#best-practices)

---

## Overview

### Why Polling?

The app uses HTTP polling instead of WebSockets or Firebase RTDB for several reasons:

1. **Simplicity** - No persistent connections to manage
2. **Reliability** - Works through any proxy/firewall
3. **Cost** - No real-time database charges
4. **Battery** - Controlled, predictable network usage
5. **Offline handling** - Graceful degradation

### Polling Types

| Type | Location | Interval | Purpose |
|------|----------|----------|---------|
| Home Polling | HomePollingService | 5 seconds | Quest status, turn-based games |
| Game Polling | Individual services | 5-10 seconds | In-game turn changes |
| Steps Polling | StepsSyncService | 60 seconds | Health data sync |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter App                              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌─────────────────────────────────────────────────────┐   │
│   │              HomePollingService                      │   │
│   │         (Singleton, ChangeNotifier)                  │   │
│   ├─────────────────────────────────────────────────────┤   │
│   │  - Polls every 5 seconds when subscribers exist     │   │
│   │  - Fetches: quests, linked, word search             │   │
│   │  - Notifies topics: dailyQuests, sideQuests, etc    │   │
│   │  - Caches last state for change detection           │   │
│   └─────────────────────────────────────────────────────┘   │
│              │                                               │
│              ▼                                               │
│   ┌─────────────────────────────────────────────────────┐   │
│   │           Topic Listeners (Widgets)                  │   │
│   ├─────────────────────────────────────────────────────┤   │
│   │  dailyQuests → DailyQuestsWidget                    │   │
│   │  sideQuests  → SideQuestsWidget                     │   │
│   │  linked      → QuestCard (Linked)                   │   │
│   │  wordSearch  → QuestCard (Word Search)              │   │
│   └─────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                       API Server                             │
├─────────────────────────────────────────────────────────────┤
│  GET /api/sync/quest-status     → Quest completion status    │
│  GET /api/sync/game/status      → All game states            │
│  GET /api/sync/linked/{matchId} → Linked game state          │
│  GET /api/sync/word-search/{id} → Word Search game state     │
└─────────────────────────────────────────────────────────────┘
```

---

## HomePollingService

The central polling service for the home screen. It's a singleton that manages all home-related polling.

### Location
`lib/services/home_polling_service.dart`

### Key Features

- **Singleton pattern** - Single instance shared across app
- **Subscriber-based** - Only polls when widgets are listening
- **Topic system** - Fine-grained notifications per data type
- **Change detection** - Only notifies when data actually changes

### Lifecycle

```dart
// Widget subscribes in initState
@override
void initState() {
  super.initState();
  _pollingService.subscribe();
  _pollingService.subscribeToTopic('dailyQuests', _onQuestUpdate);
}

// Widget unsubscribes in dispose
@override
void dispose() {
  _pollingService.unsubscribeFromTopic('dailyQuests', _onQuestUpdate);
  _pollingService.unsubscribe();
  super.dispose();
}
```

### Topics

| Topic | Updates When | Widgets |
|-------|--------------|---------|
| `dailyQuests` | Quest status changes | DailyQuestsWidget |
| `sideQuests` | Linked/WS turn changes | SideQuestsWidget |
| `linked` | Linked game state changes | QuestCard, LinkedGameScreen |
| `wordSearch` | Word Search state changes | QuestCard, WordSearchScreen |

### Manual Polling

Force an immediate poll (e.g., when returning from a game):

```dart
await HomePollingService().pollNow();
```

### Poll Cycle

Each 5-second poll cycle:

1. **Poll Daily Quests** → `GET /api/sync/quest-status`
   - Fetches quest completion for all game types
   - Updates local Hive quests if partner completed
   - Detects new matches (resets local state)

2. **Poll Linked Game** → `LinkedService.pollMatchState()`
   - Only if active match exists
   - Updates turn status in Hive
   - Notifies if turn changed

3. **Poll Word Search** → `WordSearchService.pollMatchState()`
   - Same as Linked

4. **Notify Listeners** → Callbacks called based on what changed

---

## Game Screen Polling

Individual game screens use their own polling for in-game updates.

### GamePollingMixin

A standardized mixin for game screen polling.

**Location:** `lib/mixins/game_polling_mixin.dart`

**Usage:**

```dart
class _LinkedGameScreenState extends State<LinkedGameScreen>
    with GamePollingMixin {

  @override
  Duration get pollInterval => const Duration(seconds: 10);

  @override
  bool get shouldPoll => !_isLoading && _gameState != null && !_gameState!.isMyTurn;

  @override
  Future<void> onPollUpdate() async {
    final newState = await _service.pollMatchState(_matchId);
    if (mounted) setState(() => _gameState = newState);
  }

  @override
  void initState() {
    super.initState();
    startPolling();
  }

  @override
  void dispose() {
    cancelPolling();
    super.dispose();
  }
}
```

### Game-Specific Services

| Game | Service | Poll Method |
|------|---------|-------------|
| Classic Quiz | QuizMatchService | `pollMatchState(matchId, quizType)` |
| Affirmation Quiz | QuizMatchService | `pollMatchState(matchId, quizType)` |
| You or Me | YouOrMeMatchService | `pollMatchState(matchId)` |
| Linked | LinkedService | `pollMatchState(matchId)` |
| Word Search | WordSearchService | `pollMatchState(matchId)` |

### UnifiedGameService

Underlying service that handles polling for quiz-like games.

**Location:** `lib/services/unified_game_service.dart`

Features:
- Timer-based polling with configurable interval
- Callback-based updates
- Automatic cleanup on dispose

---

## API Endpoints

### Quest Status (Home Polling)

```
GET /api/sync/quest-status?date=2025-12-19
```

**Response:**
```json
{
  "quests": [
    {
      "questId": "quiz_classic_001",
      "questType": "classic",
      "status": "completed",
      "userCompleted": true,
      "partnerCompleted": true,
      "matchId": "uuid-here",
      "matchPercentage": 80,
      "lpAwarded": 30
    }
  ],
  "totalLp": 1160,
  "userId": "...",
  "partnerId": "...",
  "date": "2025-12-19"
}
```

### Game Status (All Games)

```
GET /api/sync/game/status?date=2025-12-19&type=classic
```

**Response:**
```json
{
  "games": [...],
  "completedCounts": {
    "classic": 5,
    "affirmation": 3,
    "you_or_me": 4,
    "linked": 2,
    "word_search": 1
  },
  "available": [...],
  "totalLp": 1160
}
```

### Individual Game State

```
GET /api/sync/linked/{matchId}
GET /api/sync/word-search/{matchId}
GET /api/sync/quiz/{sessionId}
GET /api/sync/you-or-me/{sessionId}
```

---

## Change Detection

### How Changes are Detected

HomePollingService caches the last known state and compares:

```dart
// Cached state
Map<String, bool> _lastQuestCompletions = {};
Map<String, String> _lastQuestMatchIds = {};
String? _lastLinkedTurnUserId;
String? _lastLinkedStatus;
```

**Quest Changes:**
```dart
// Check if partner completion changed
if (_lastQuestCompletions[key] != partnerCompleted) {
  anyChanges = true;
}
```

**Turn-Based Game Changes:**
```dart
final hasChanges = _lastLinkedTurnUserId != newTurnUserId ||
                   _lastLinkedStatus != newStatus;
```

### New Match Detection

When a couple starts a new game (after completing the previous):

```dart
final isNewMatch = matchId != null &&
                   previousMatchId != null &&
                   matchId != previousMatchId;

if (isNewMatch) {
  // Reset local quest state
  matchingQuest.userCompletions = {};
  matchingQuest.status = 'pending';
  await _storage.saveDailyQuest(matchingQuest);
}
```

---

## Widget Integration

### DailyQuestsWidget

```dart
class _DailyQuestsWidgetState extends State<DailyQuestsWidget>
    with RouteAware {
  final HomePollingService _pollingService = HomePollingService();

  @override
  void initState() {
    super.initState();
    _pollingService.subscribe();
    _pollingService.subscribeToTopic('dailyQuests', _onQuestUpdate);
  }

  void _onQuestUpdate() {
    if (mounted) {
      setState(() {});  // Trigger rebuild with new data
      LovePointService.fetchAndSyncFromServer();
    }
  }

  @override
  void dispose() {
    _pollingService.unsubscribeFromTopic('dailyQuests', _onQuestUpdate);
    _pollingService.unsubscribe();
    super.dispose();
  }
}
```

### QuestCard Turn Updates

QuestCard reads turn state synchronously from Hive on every build:

```dart
@override
Widget build(BuildContext context) {
  // Re-read turn state on every build (Hive read is fast)
  if (widget.quest.type == QuestType.linked) {
    _loadTurnBasedGameState();
  }
  // ...
}
```

The polling service triggers parent rebuild → QuestCard rebuilds → reads fresh Hive data.

### Key Pattern: ValueKey for Forced Rebuilds

Hive returns the same object instances. Use ValueKey to force widget recreation:

```dart
return QuestCard(
  key: ValueKey('${quest.id}_$completionCount_$isLocked'),
  quest: quest,
  // ...
);
```

---

## Debugging

### Enable Polling Logs

In `lib/utils/logger.dart`, enable the 'polling' service:

```dart
static const Map<String, bool> _serviceVerbosity = {
  'polling': true,  // Enable polling logs
  // ...
};
```

### Log Output

```
⏱️ Poll cycle starting...
📊 Poll received: classic status=completed user=true partner=true matchId=abc123
📊 Poll received: you_or_me status=active user=true partner=false matchId=def456
🔗 Linked Poll: cached match=xyz789, status=active, turn=user123
🔎 WS Poll: no cached match, checking server...
⏱️ Poll results: quests=true, linked=false, ws=false
```

### Debug Getters

```dart
final service = HomePollingService();
print('Is polling: ${service.isPolling}');
print('Subscribers: ${service.subscriberCount}');
print('Topic listeners: ${service.topicListenerCounts}');
```

---

## Best Practices

### 1. Always Unsubscribe

```dart
@override
void dispose() {
  _pollingService.unsubscribe();  // REQUIRED
  super.dispose();
}
```

Failure to unsubscribe leads to:
- Memory leaks
- Polling continuing when not needed
- Callbacks on disposed widgets

### 2. Use pollNow() After Navigation

When returning from a game screen, force immediate poll:

```dart
@override
void didPopNext() {
  super.didPopNext();
  _pollingService.pollNow();  // Immediate refresh
}
```

### 3. Avoid Duplicate Polling

Home screen widgets should use HomePollingService. Game screens should use their own polling. Never both simultaneously for the same data.

### 4. Handle Network Errors Silently

Polling failures shouldn't disturb users:

```dart
try {
  await onPollUpdate();
} catch (e) {
  // Silent failure - next poll will try again
  Logger.debug('Poll failed, will retry', service: 'polling');
}
```

### 5. Cache Futures for FutureBuilder

When using FutureBuilder in widgets that rebuild due to polling:

```dart
// WRONG - blinks on every setState
FutureBuilder(future: _fetchData(), ...)

// CORRECT - cache the Future
Future<Data>? _cachedFuture;
void _refreshCache() => _cachedFuture = _fetchData();

// Only refresh when data changes
if (hasChanges && mounted) { _refreshCache(); setState(() {}); }

// In build:
FutureBuilder(future: _cachedFuture ?? _fetchData(), ...)
```

### 6. Save to Hive After Polling

Ensure polling results are persisted:

```dart
// After polling, save to Hive
await StorageService().saveLinkedMatch(_gameState!.match);

// This ensures other widgets see the update
```

---

## Flow Diagrams

### Partner Completion Detection

```
Partner completes You or Me
         │
         ▼
Server updates quiz_matches table
         │
         ▼
HomePollingService polls /api/sync/quest-status
         │
         ▼
Detects partnerCompleted: true
         │
         ▼
Updates local quest in Hive:
  - userCompletions[partnerId] = true
  - status = 'completed'
         │
         ▼
_notifyTopic('dailyQuests')
         │
         ▼
DailyQuestsWidget._onQuestUpdate()
         │
         ▼
setState(() {}) triggers rebuild
         │
         ▼
QuestCard shows "COMPLETED" badge
```

### Turn Change Detection (Linked/Word Search)

```
Partner makes move
         │
         ▼
Server updates linked_matches.current_turn_user_id
         │
         ▼
HomePollingService polls LinkedService.pollMatchState()
         │
         ▼
LinkedService fetches /api/sync/linked/{matchId}
         │
         ▼
Updates LinkedMatch in Hive
         │
         ▼
HomePollingService detects turn change:
  _lastLinkedTurnUserId != newTurnUserId
         │
         ▼
_notifyTopic('linked')
_notifyTopic('sideQuests')
         │
         ▼
QuestCard rebuilds, reads new turn from Hive
         │
         ▼
Shows "Your turn!" or "Waiting for partner"
```

---

## Files Reference

| File | Purpose |
|------|---------|
| `lib/services/home_polling_service.dart` | Main home screen polling |
| `lib/services/unified_game_service.dart` | Quiz game polling |
| `lib/services/quiz_match_service.dart` | Classic/Affirmation quiz service |
| `lib/services/you_or_me_match_service.dart` | You or Me service |
| `lib/services/linked_service.dart` | Linked puzzle service |
| `lib/services/word_search_service.dart` | Word Search service |
| `lib/services/steps_sync_service.dart` | Steps Together polling |
| `lib/mixins/game_polling_mixin.dart` | Reusable polling mixin |
| `api/app/api/sync/quest-status/route.ts` | Quest status endpoint |
| `api/app/api/sync/game/status/route.ts` | Game status endpoint |

---

**Last Updated:** 2025-12-19

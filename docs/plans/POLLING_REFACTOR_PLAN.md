# Polling System Refactoring Plan

## Executive Summary

The current polling system has grown organically and now has significant issues:
- **3 separate polling systems** (HomePollingService, UnifiedGameService, StepsSyncService)
- **Race conditions** in callback management
- **Inconsistent patterns** between game types
- **Memory leaks** (LP callback not cleaned up)
- **No batching** of API requests

This plan outlines a phased refactoring approach.

---

## Current Architecture Problems

### 1. Multiple Polling Systems

```
Current:
┌─────────────────────┐   ┌─────────────────────┐   ┌─────────────────────┐
│ HomePollingService  │   │ UnifiedGameService  │   │  StepsSyncService   │
│    (5s interval)    │   │    (5s interval)    │   │   (60s interval)    │
│                     │   │                     │   │                     │
│ • Daily quests      │   │ • Quiz waiting      │   │ • Steps data        │
│ • Linked (home)     │   │ • You-or-Me waiting │   │ • Partner steps     │
│ • Word Search (home)│   │                     │   │                     │
└─────────────────────┘   └─────────────────────┘   └─────────────────────┘
         │                         │                         │
         ▼                         ▼                         ▼
   Home Screen              Waiting Screens             Steps Screen
         │
         │ ALSO uses GamePollingMixin for:
         ▼
┌─────────────────────┐
│  Game Screens       │
│  (10s interval)     │
│  • Linked           │
│  • Word Search      │
└─────────────────────┘
```

**Problems:**
- Duplicate polling for Linked/Word Search (home AND game screens)
- Different intervals (5s home, 10s game)
- Three separate timer management systems

### 2. Callback Race Condition

**File:** `unified_game_service.dart:526-601`

```dart
// PROBLEM: Only ONE callback stored
void _onStateUpdate;  // Single callback

startPolling() {
  _onStateUpdate = onUpdate;  // Overwrites previous
}

stopPolling() {
  _onStateUpdate = null;  // Clears for ALL screens
}
```

**Scenario:**
1. Waiting screen starts polling, sets callback
2. Game screen disposes, calls stopPolling()
3. Callback is null, waiting screen stops receiving updates

### 3. Pending Results Flag Set in 6 Places

| Location | When Set |
|----------|----------|
| quiz_match_waiting_screen initState | Entering waiting |
| quiz_match_waiting_screen handleCompletion | Partner completes |
| you_or_me_match_waiting_screen initState | Entering waiting |
| you_or_me_match_waiting_screen handleCompletion | Partner completes |
| linked_game_screen navigateToCompletion | Game ends |
| home_polling_service (NEW) | Auto-detect completion |

**Problem:** No single source of truth, race conditions possible.

### 4. Memory Leak

**File:** `home_screen.dart:210`

```dart
// LP callback set but NEVER cleared
LovePointService.setLPChangeCallback(() {
  if (mounted) setState(() {});
});

// dispose() does NOT clear it
```

---

## Proposed Architecture

### Phase 1: Quick Fixes (No Breaking Changes)

**Goal:** Fix critical bugs without restructuring.

#### 1.1 Fix Memory Leak in HomeScreen

```dart
// home_screen.dart dispose()
@override
void dispose() {
  // ... existing cleanup ...
  LovePointService.clearLPChangeCallback();  // ADD THIS
  super.dispose();
}
```

#### 1.2 Protect Callback in UnifiedGameService

```dart
// Current: Single callback cleared by any stopPolling()
// Fix: Guard callback by matchId

final Map<String, Function?> _matchCallbacks = {};

void startPolling({required String matchId, required Function onUpdate}) {
  _matchCallbacks[matchId] = onUpdate;
  // ...
}

void stopPolling({required String matchId}) {
  _matchCallbacks.remove(matchId);  // Only removes THIS match's callback
}

void _pollOnce() {
  final callback = _matchCallbacks[_currentPollingMatchId];
  if (callback != null) callback(state);
}
```

#### 1.3 Replace print() with Logger

Files to update:
- `unified_game_service.dart` - 10 print statements
- `quiz_match_waiting_screen.dart` - 5 print statements
- `you_or_me_match_waiting_screen.dart` - 4 print statements

#### 1.4 Unify Polling Intervals

| Service | Current | Proposed |
|---------|---------|----------|
| HomePollingService | 5s | 5s |
| UnifiedGameService | 5s | 5s |
| GamePollingMixin | 10s default | 5s default |
| YouOrMeMatchService | 10s | 5s |
| StepsSyncService | 60s | 60s (unchanged) |

---

### Phase 2: Consolidate Pending Results Flag

**Goal:** Single source of truth for pending results.

#### 2.1 Remove Flag Setting from Waiting Screens

```dart
// REMOVE from quiz_match_waiting_screen.dart initState and handleCompletion
// REMOVE from you_or_me_match_waiting_screen.dart initState and handleCompletion
// KEEP only in home_polling_service.dart (auto-detection)
```

#### 2.2 Set Flag When Entering Game (Not Waiting)

Better approach: Set flag when user STARTS the game (first answer), not waiting screen.

```dart
// In game screen, after first answer submitted:
if (_isFirstAnswer && !_flagSet) {
  await StorageService().setPendingResultsMatchId(contentType, matchId);
  _flagSet = true;
}
```

This ensures flag is set even if user never sees waiting screen.

#### 2.3 Clear Flag Only in Results Screen

Single clear location: results screen initState (already exists).

---

### Phase 3: Unify Game Screen Polling

**Goal:** Game screens use HomePollingService instead of separate polling.

#### 3.1 Add Game Topics to HomePollingService

```dart
// home_polling_service.dart
final Map<String, Set<VoidCallback>> _topicListeners = {
  'dailyQuests': {},
  'sideQuests': {},
  'linked': {},
  'wordSearch': {},
  'linkedGame': {},      // NEW: For LinkedGameScreen
  'wordSearchGame': {},  // NEW: For WordSearchGameScreen
  'quizGame': {},        // NEW: For QuizMatchGameScreen
  'youOrMeGame': {},     // NEW: For YouOrMeMatchGameScreen
};
```

#### 3.2 Game Screens Subscribe to Topics

```dart
// linked_game_screen.dart
@override
void initState() {
  super.initState();
  _pollingService.subscribe();
  _pollingService.subscribeToTopic('linkedGame', _onPollUpdate);
}

void _onPollUpdate() {
  // Refresh game state from Hive
  final match = StorageService().getActiveLinkedMatch();
  if (match != null) {
    setState(() => _gameState = _buildStateFromMatch(match));
  }
}
```

#### 3.3 Remove GamePollingMixin

After game screens use topics, mixin is no longer needed.

---

### Phase 4: Batch API Requests

**Goal:** Single API call for all polling data.

#### 4.1 New Unified Polling Endpoint

```
GET /api/sync/poll
Response:
{
  "dailyQuests": [...],
  "linked": {...},
  "wordSearch": {...},
  "totalLp": 1160,
  "timestamp": "2025-12-19T07:30:00Z"
}
```

#### 4.2 HomePollingService Uses Single Request

```dart
Future<void> _poll() async {
  final response = await _apiClient.get('/api/sync/poll');

  // Process all data in one atomic update
  final data = response.data;

  bool questsChanged = await _processDailyQuests(data['dailyQuests']);
  bool linkedChanged = await _processLinked(data['linked']);
  bool wsChanged = await _processWordSearch(data['wordSearch']);

  // Notify appropriate topics
  if (questsChanged) _notifyTopic('dailyQuests');
  if (linkedChanged) _notifyTopic('linked');
  if (wsChanged) _notifyTopic('wordSearch');
}
```

---

### Phase 5: State Machine for Polling

**Goal:** Clear lifecycle states for polling.

```dart
enum PollingState {
  idle,        // Not polling
  starting,    // Initial poll in progress
  polling,     // Regular polling active
  paused,      // Temporarily stopped (app backgrounded)
  completed,   // All games completed for today
  error,       // Polling failed, will retry
}

class HomePollingService {
  PollingState _state = PollingState.idle;

  void subscribe() {
    if (_state == PollingState.idle) {
      _state = PollingState.starting;
      _initialPoll().then((_) => _state = PollingState.polling);
    }
  }

  void pause() {
    if (_state == PollingState.polling) {
      _state = PollingState.paused;
      _stopTimer();
    }
  }

  void resume() {
    if (_state == PollingState.paused) {
      _state = PollingState.polling;
      _startTimer();
    }
  }
}
```

---

### Phase 6: Long-Term - WebSocket/SSE

**Goal:** Real-time updates instead of polling.

```dart
// Future architecture:
class RealtimeService {
  WebSocketChannel? _channel;

  void connect(String coupleId) {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://api.example.com/realtime/$coupleId')
    );

    _channel!.stream.listen((message) {
      final event = json.decode(message);
      switch (event['type']) {
        case 'partner_completed':
          _handlePartnerCompleted(event);
          break;
        case 'turn_changed':
          _handleTurnChanged(event);
          break;
        case 'lp_updated':
          _handleLpUpdated(event);
          break;
      }
    });
  }
}
```

---

## Implementation Priority

### Immediate (This Week)

| Task | Effort | Impact | File |
|------|--------|--------|------|
| Fix LP callback memory leak | 5 min | High | home_screen.dart |
| Replace print() with Logger | 30 min | Medium | 3 files |
| Protect callback by matchId | 1 hour | High | unified_game_service.dart |

### Short-Term (Next 2 Weeks)

| Task | Effort | Impact | File |
|------|--------|--------|------|
| Unify polling intervals to 5s | 30 min | Medium | 3 services |
| Consolidate pending flag to polling | 2 hours | High | Multiple |
| Add request timeout | 1 hour | Medium | api_client.dart |

### Medium-Term (Next Month)

| Task | Effort | Impact | File |
|------|--------|--------|------|
| Game screens use HomePollingService | 4 hours | High | 4 screens |
| Remove GamePollingMixin | 1 hour | Medium | Delete file |
| Batch API endpoint | 4 hours | High | API + service |

### Long-Term (Future)

| Task | Effort | Impact |
|------|--------|--------|
| Polling state machine | 8 hours | Medium |
| WebSocket/SSE real-time | 3 days | High |
| Offline-first with sync | 1 week | High |

---

## Files to Modify

### Phase 1 Files

```
lib/screens/home_screen.dart
  - Line 210: Clear LP callback in dispose

lib/services/unified_game_service.dart
  - Lines 526-601: Add matchId to callback map
  - Lines 554-598: Replace print with Logger

lib/screens/quiz_match_waiting_screen.dart
  - Lines 62, 106, 112, 127, 132: Replace print with Logger

lib/screens/you_or_me_match_waiting_screen.dart
  - Lines 89-92: Replace print with Logger

lib/services/you_or_me_match_service.dart
  - Line 108: Change interval from 10s to 5s
```

### Phase 2 Files

```
lib/screens/quiz_match_waiting_screen.dart
  - Lines 99-103, 144-145: Remove pending flag setting

lib/screens/you_or_me_match_waiting_screen.dart
  - Lines 87-94, 140-141: Remove pending flag setting

lib/screens/quiz_match_game_screen.dart
  - Add: Set pending flag on first answer

lib/screens/you_or_me_match_game_screen.dart
  - Add: Set pending flag on first answer
```

### Phase 3 Files

```
lib/services/home_polling_service.dart
  - Add new topics for game screens
  - Add poll methods for active games

lib/screens/linked_game_screen.dart
  - Replace GamePollingMixin with topic subscription

lib/screens/word_search_game_screen.dart
  - Replace GamePollingMixin with topic subscription

lib/mixins/game_polling_mixin.dart
  - DELETE after migration
```

---

## Testing Checklist

### Phase 1 Tests

- [ ] LP callback clears on HomeScreen dispose (no leak)
- [ ] Waiting screen continues receiving updates after game screen dispose
- [ ] All print statements removed from production logs
- [ ] Polling intervals consistent at 5s

### Phase 2 Tests

- [ ] Pending flag set when user answers first question
- [ ] Flag NOT set in waiting screen
- [ ] Flag cleared only in results screen
- [ ] "RESULTS ARE READY!" shows correctly after partner completes

### Phase 3 Tests

- [ ] Game screens update when HomePollingService polls
- [ ] Turn changes detected within 5 seconds
- [ ] No duplicate updates when on game screen
- [ ] Memory usage stable (no mixin overhead)

### Phase 4 Tests

- [ ] Single API call returns all data
- [ ] Network usage reduced by ~60%
- [ ] All notifications still work correctly
- [ ] Graceful fallback if endpoint fails

---

## Metrics to Track

| Metric | Current | Phase 1 | Phase 4 Target |
|--------|---------|---------|----------------|
| API calls per 30s (home) | 6+ | 6 | 6 |
| API calls per 30s (game) | 9+ | 6 | 6 |
| Memory leaks | 1 known | 0 | 0 |
| Polling systems | 3 | 3 | 1 |
| Callback race conditions | Yes | No | No |

---

## Rollback Plan

Each phase can be rolled back independently:

- **Phase 1:** Revert individual file changes
- **Phase 2:** Re-add flag setting to waiting screens
- **Phase 3:** Re-add GamePollingMixin, revert topic changes
- **Phase 4:** Keep old endpoints, revert to multiple calls

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2025-12-19 | Fix LP leak first | High impact, minimal effort |
| 2025-12-19 | Keep Steps separate | 60s interval is intentional |
| 2025-12-19 | Don't add WebSocket yet | Polling works, complexity not justified |

---

**Last Updated:** 2025-12-19

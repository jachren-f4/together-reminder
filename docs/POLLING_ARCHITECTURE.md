# Polling Architecture

**Timer-based polling implementations across the TogetherRemind codebase**

Last Updated: 2025-12-01 (Added FutureBuilder Anti-Blink Pattern)

---

## Table of Contents

1. [Overview](#overview)
2. [Polling Summary by Interval](#polling-summary-by-interval)
3. [Flutter App Polling](#flutter-app-polling)
   - [Daily Quests Widget](#1-daily-quests-widget)
   - [Linked Card Widget](#2-linked-card-widget)
   - [Linked Countdown Timer](#3-linked-countdown-timer)
   - [Unified Game Service](#4-unified-game-service)
   - [Quiz API Service](#5-quiz-api-service)
   - [Steps Sync Service](#6-steps-sync-service)
   - [You-or-Me API Service](#7-you-or-me-api-service)
   - [Linked Game Screen](#8-linked-game-screen)
   - [Auth Service](#9-auth-service)
   - [Steps Counter Screen](#10-steps-counter-screen)
   - [New Home Screen](#11-new-home-screen)
   - [Word Search Game Screen](#12-word-search-game-screen)
   - [Pairing Screen](#13-pairing-screen)
4. [Backend Polling](#backend-polling)
   - [Rate Limiter Cleanup](#14-rate-limiter-cleanup)
5. [Common Patterns](#common-patterns)
6. [Potential Optimizations](#potential-optimizations)

---

## Overview

The app uses timer-based polling to sync data between partners since we migrated away from Firebase Realtime Database. All sync now uses Supabase API with polling intervals ranging from 1 second to 5 minutes depending on the use case.

**Key Design Principles:**
- Conditional polling - only active when needed (e.g., during partner's turn)
- Auto-stop on completion - polling stops when game/session completes
- Proper cleanup - all timers cancelled in `dispose()` methods
- Silent failure handling - polling errors logged but don't crash the app

---

## Polling Summary by Interval

| Interval | Components | Purpose |
|----------|------------|---------|
| **1 second** | Pairing countdown | Code expiry display |
| **3 seconds** | Pairing status | Check if partner paired |
| **5 seconds** | Daily quests, Home screen side quests, Unified game service | Partner completions, turn detection |
| **10 seconds** | Linked card/screen, Word search, Quiz API, You-or-Me API | Game state during partner's turn |
| **60 seconds** | Steps sync, Auth token refresh, Steps counter screen | Background sync, token refresh |
| **1 minute** | Countdown timer widget | Cooldown display updates |
| **5 minutes** | Rate limiter (backend) | Memory cleanup |

---

## Flutter App Polling

### 1. Daily Quests Widget

**File:** `app/lib/widgets/daily_quests_widget.dart`

**Lines:** 40, 81-83, 169

**Polling Interval:** 5 seconds

**Purpose:** Polls Supabase for partner quest completion status. Detects when partner completes quiz/affirmation/you-or-me quests and updates the UI accordingly.

**Start Condition:** Timer starts in `_startPolling()` during `initState`

**Stop Condition:** `dispose()` calls `_pollingTimer?.cancel()`

```dart
// Line 40: Polling interval definition
static const Duration _pollingInterval = Duration(seconds: 5);

// Lines 81-83: Timer setup
_pollingTimer = Timer.periodic(_pollingInterval, (_) {
  _pollQuestStatus();
});

// Line 169: Cleanup
@override
void dispose() {
  _pollingTimer?.cancel();
  super.dispose();
}
```

**What's Polled:**
- Endpoint: `/api/sync/quest-status`
- Detects partner quest completions
- Updates `userCompletions` map
- Syncs LP from server when partner completes

---

### 2. Linked Card Widget

**File:** `app/lib/widgets/linked_card.dart`

**Lines:** 41, 87-92, 51

**Polling Interval:** 10 seconds

**Purpose:** Polls for partner's Linked game state when waiting for their turn.

**Start Condition:** Activates only when it's partner's turn in `_updatePolling()`

**Stop Condition:** Cancelled in `dispose()`

```dart
// Line 87: Conditional polling - only during partner's turn
if (_gameState != null && !_gameState!.isMyTurn && !_gameState!.match.isCompleted) {
  _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
    if (mounted) {
      _loadGameState(silent: true);
    }
  });
}
```

**Key Detail:** Polling is conditional - only runs when:
- Game state exists
- It's NOT the current user's turn
- Match is not completed

---

### 3. Linked Countdown Timer

**File:** `app/lib/widgets/linked/countdown_timer.dart`

**Lines:** 26, 52-54, 46

**Polling Interval:** 1 minute

**Purpose:** Updates countdown timer display for next puzzle availability (cooldown period).

**Start Condition:** Started in `_startTimer()`

**Stop Condition:** Auto-cancels when countdown reaches zero or `dispose()` called

```dart
// Line 52: Updates display every minute
_timer = Timer.periodic(const Duration(minutes: 1), (_) {
  _updateRemaining();
});

// Lines 70-72: Auto-cancel when complete
if (_remaining == Duration.zero) {
  _timer?.cancel();
  widget.onComplete?.call();
}
```

---

### 4. Unified Game Service

**File:** `app/lib/services/unified_game_service.dart`

**Lines:** 520-524, 538-542, 560-564

**Polling Interval:** Configurable, default 5 seconds

**Purpose:** Generic polling service for Quiz Match, You-or-Me Match, and other games. Provides a unified interface for game state polling.

**Start Condition:** `startPolling()` method called with game type and match ID

**Stop Condition:** `stopPolling()` or auto-stops on completion

```dart
// Lines 538-541: Periodic polling setup
_pollTimer = Timer.periodic(
  Duration(seconds: intervalSeconds),
  (_) => _pollOnce(gameType, matchId),
);

// Lines 550-552: Auto-stop on completion
if (state.state.isCompleted) {
  Logger.info('Match completed, stopping polling', service: 'game');
  stopPolling();
}

// Lines 560-564: Manual stop
void stopPolling() {
  _pollTimer?.cancel();
  _pollTimer = null;
  _onStateUpdate = null;
}
```

---

### 5. Quiz API Service

**File:** `app/lib/services/quiz_api_service.dart`

**Lines:** 331-347, 351-355

**Polling Interval:** Configurable, default 10 seconds

**Purpose:** Polls quiz session state from server when waiting for partner to complete their answers.

**Start Condition:** `startPolling()` method called with session ID

**Stop Condition:** `stopPolling()` or auto-stops on session completion

```dart
// Lines 331-347: Timer and polling logic
_pollTimer = Timer.periodic(
  Duration(seconds: intervalSeconds),
  (_) async {
    try {
      final state = await pollSessionState(sessionId);
      _onStateUpdate?.call(state);

      if (state.isCompleted) {
        Logger.info('Session completed, stopping polling', service: 'quiz');
        stopPolling();
      }
    } catch (e) {
      Logger.error('Polling error', error: e, service: 'quiz');
    }
  },
);
```

---

### 6. Steps Sync Service

**File:** `app/lib/services/steps_sync_service.dart`

**Lines:** 49-54, 57-61

**Polling Interval:** 60 seconds (default, customizable)

**Purpose:** Polls for partner's step data updates to show their progress in Steps Together feature.

**Start Condition:** `startPolling()` method

**Stop Condition:** `stopPolling()` cancels timer

```dart
// Lines 49-54: Periodic step polling
_pollingTimer = Timer.periodic(interval, (_) {
  loadPartnerDataFromServer();
});

// Lines 57-61: Cleanup
void stopPolling() {
  _pollingTimer?.cancel();
  _pollingTimer = null;
  Logger.debug('StepsSyncService polling stopped', service: 'steps');
}
```

---

### 7. You-or-Me API Service

**File:** `app/lib/services/you_or_me_api_service.dart`

**Lines:** 425-442, 446-450

**Polling Interval:** Configurable, default 10 seconds

**Purpose:** Polls You-or-Me game session state to detect partner responses.

**Start Condition:** `startPolling()` method called with session ID

**Stop Condition:** `stopPolling()` or auto-stops on completion

```dart
// Lines 425-442: Polling loop
_pollTimer = Timer.periodic(
  Duration(seconds: intervalSeconds),
  (_) async {
    try {
      final state = await pollSessionState(sessionId);
      _onStateUpdate?.call(state);

      if (state.isCompleted) {
        Logger.info('Session completed, stopping polling', service: 'you_or_me');
        stopPolling();
      }
    } catch (e) {
      Logger.error('Polling error', error: e, service: 'you_or_me');
    }
  },
);
```

---

### 8. Linked Game Screen

**File:** `app/lib/screens/linked_game_screen.dart`

**Lines:** 54, 70-74, 64

**Polling Interval:** 10 seconds

**Purpose:** Polls for partner's move updates during active Linked gameplay.

**Start Condition:** `_startPolling()` called in `_loadGameState()`

**Stop Condition:** `dispose()` cancels timer

```dart
// Line 54: Interval constant
static const _pollInterval = Duration(seconds: 10);

// Lines 70-74: Conditional polling during partner's turn
if (!_isLoading && !_isSubmitting && _gameState != null && !_gameState!.isMyTurn) {
  _pollForUpdate();
}
```

**Key Detail:** Only polls when waiting for partner's turn, not during own turn.

---

### 9. Auth Service

**File:** `app/lib/services/auth_service.dart`

**Lines:** 520-530, 537

**Polling Interval:** 60 seconds

**Purpose:** Background token expiry check and automatic refresh before token expires.

**Start Condition:** `_startRefreshTimer()` called after authentication

**Stop Condition:** `dispose()` cancels timer

```dart
// Lines 520-530: Token refresh polling
_refreshTimer = Timer.periodic(
  const Duration(seconds: 60),
  (timer) async {
    if (_authState == AuthState.authenticated) {
      if (await isTokenExpiringSoon()) {
        debugPrint('🔄 Token expiring soon - refreshing in background');
        await refreshToken();
      }
    }
  },
);
```

---

### 10. Steps Counter Screen

**File:** `app/lib/screens/steps_counter_screen.dart`

**Lines:** 79-82

**Polling Interval:** 60 seconds

**Purpose:** Syncs step data periodically while the steps screen is displayed.

**Start Condition:** `_startSyncTimer()` in `initState`

**Stop Condition:** Disposed with widget

```dart
// Lines 79-82: Periodic sync
_syncTimer = Timer.periodic(const Duration(seconds: 60), (_) {
  _refreshData();
});
```

---

### 11. New Home Screen

**File:** `app/lib/screens/new_home_screen.dart`

**Lines:** 65, 150-152, 162-213

**Polling Interval:** 5 seconds

**Purpose:** Polls for Linked and Word Search match state changes. Detects turn changes and completion status for side quest games.

**Start Condition:** `_startSideQuestPolling()` during `initState`

**Stop Condition:** Disposed with screen

```dart
// Line 65: Interval constant
static const Duration _sideQuestPollingInterval = Duration(seconds: 5);

// Lines 150-152: Timer setup with FutureBuilder cache initialization
void _startSideQuestPolling() {
  _refreshSideQuestsFuture();  // Initialize cached Future
  _pollSideQuestGameState();   // Initial poll
  _sideQuestPollingTimer = Timer.periodic(_sideQuestPollingInterval, (_) {
    _pollSideQuestGameState();
  });
}
```

**Polling Logic (Lines 162-213):**
- Captures state BEFORE polling to detect actual changes
- Polls `linkedService.pollMatchState()` and `wordSearchService.pollMatchState()`
- Compares before/after state: `currentTurnUserId`, `status`
- Only calls `setState()` if actual changes detected (prevents FutureBuilder blink)
- Refreshes cached `_sideQuestsFuture` only when data changes

**FutureBuilder Anti-Blink Pattern (Fixed 2025-12-01):**

The Side Quests carousel uses `FutureBuilder` which creates a new Future on every build. Without caching, any `setState()` call from Daily Quests polling (every 5s) would cause the carousel to blink (show loading spinner → content → loading spinner).

```dart
// Cached Future to prevent FutureBuilder from rebuilding on every setState
Future<List<DailyQuest>>? _sideQuestsFuture;

/// Refresh the cached side quests Future (call when data changes)
void _refreshSideQuestsFuture() {
  _sideQuestsFuture = _getSideQuests();
}

// In _pollSideQuestGameState():
// Capture state before polling
final linkedTurnBefore = linkedBefore?.currentTurnUserId;
final wsTurnBefore = wsBefore?.currentTurnUserId;

// ... poll both services ...

// Only rebuild if there were actual changes
final hasChanges = linkedTurnBefore != linkedTurnAfter ||
    wsTurnBefore != wsTurnAfter ||
    linkedBefore?.status != linkedAfter?.status ||
    wsBefore?.status != wsAfter?.status;

if (hasChanges && mounted) {
  _refreshSideQuestsFuture();  // Update cached Future
  setState(() {});              // Trigger rebuild
}

// In _buildSideQuestsCarousel():
return FutureBuilder<List<DailyQuest>>(
  future: _sideQuestsFuture ?? _getSideQuests(),  // Use cached Future
  builder: (context, snapshot) {
    // Only show loading on initial load, not on rebuilds
    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    // ... render carousel with existing data
  },
);
```

**Why Daily Quests doesn't blink:** Daily Quests widget (`daily_quests_widget.dart`) only calls `setState()` when `anyUpdates == true` (line 155-156), preventing unnecessary rebuilds.

---

### 12. Word Search Game Screen

**File:** `app/lib/screens/word_search_game_screen.dart`

**Lines:** 58, 139-143, 131

**Polling Interval:** 10 seconds

**Purpose:** Polls for partner's word search move updates during gameplay.

**Start Condition:** `_startPolling()` method

**Stop Condition:** `dispose()` cancels timer

```dart
// Line 58: Interval constant
static const _pollInterval = Duration(seconds: 10);

// Lines 139-143: Conditional polling during partner's turn
if (!_isLoading && !_isSubmitting && _gameState != null && !_gameState!.isMyTurn) {
  _pollForUpdate();
}
```

---

### 13. Pairing Screen

**File:** `app/lib/screens/pairing_screen.dart`

**Lines:** 193-213, 218-238

**Polling Intervals:**
- Countdown: 1 second (code expiry display)
- Pairing status check: 3 seconds

**Purpose:**
- Countdown timer for pairing code expiry visualization
- Poll for pairing completion when partner enters code

**Start Conditions:** `_startCountdownTimer()` and `_startPairingStatusPolling()`

**Stop Conditions:** Auto-cancel on expiry or successful pairing

```dart
// Lines 193-213: Countdown timer (1 second)
_countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
  if (_generatedCode!.isExpired) {
    timer.cancel();
    // Handle expiry - regenerate code or show message
  }
});

// Lines 218-238: Pairing status polling (3 seconds)
_pairingStatusTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
  final status = await _couplePairingService.getStatus();
  if (status != null) {
    timer.cancel(); // Stop on successful pairing
    // Navigate to next screen
  }
});
```

---

## Backend Polling

### 14. Rate Limiter Cleanup

**File:** `api/lib/auth/rate-limit.ts`

**Lines:** 20-27

**Polling Interval:** 5 minutes (300,000 ms)

**Purpose:** Cleans up expired rate limit entries from in-memory store to prevent memory leaks.

**Note:** Uses Node.js `setInterval` which runs for the lifetime of the server process.

```typescript
// Lines 20-27: Cleanup interval
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of rateLimitStore.entries()) {
    if (entry.resetAt < now) {
      rateLimitStore.delete(key);
    }
  }
}, 5 * 60 * 1000); // 5 minutes
```

---

## Common Patterns

### 1. Conditional Polling

Most game polling only activates when waiting for partner:

```dart
// Only poll when it's NOT my turn
if (_gameState != null && !_gameState!.isMyTurn && !_gameState!.match.isCompleted) {
  _startPolling();
}
```

### 2. Auto-Stop on Completion

Polling automatically stops when the game/session completes:

```dart
if (state.isCompleted) {
  Logger.info('Session completed, stopping polling', service: 'game');
  stopPolling();
}
```

### 3. Proper Cleanup in dispose()

All Flutter timers are cancelled when the widget is disposed:

```dart
@override
void dispose() {
  _pollingTimer?.cancel();
  super.dispose();
}
```

### 4. Silent Failure Handling

Polling errors are logged but don't crash the app:

```dart
try {
  final state = await pollSessionState(sessionId);
  _onStateUpdate?.call(state);
} catch (e) {
  Logger.error('Polling error', error: e, service: 'quiz');
  // Continue polling - don't crash
}
```

### 5. Mounted Check

Prevent setState on unmounted widgets:

```dart
_pollingTimer = Timer.periodic(interval, (_) {
  if (mounted) {
    _loadGameState(silent: true);
  }
});
```

### 6. FutureBuilder Cache Pattern (Anti-Blink)

**Problem:** `FutureBuilder` creates a new Future on every `build()`. When polling triggers `setState()`, the widget rebuilds, FutureBuilder gets a new Future, and shows loading state briefly → UI blinks.

**Solution:** Cache the Future and only refresh it when data actually changes:

```dart
// 1. Cache the Future as instance variable
Future<List<Data>>? _cachedFuture;

// 2. Refresh method - call only when data changes
void _refreshCachedFuture() {
  _cachedFuture = _fetchData();
}

// 3. In polling: compare before/after state
Future<void> _poll() async {
  final stateBefore = _getState();
  await _fetchFromServer();
  final stateAfter = _getState();

  // Only rebuild if actual changes
  final hasChanges = stateBefore != stateAfter;
  if (hasChanges && mounted) {
    _refreshCachedFuture();  // Update cache
    setState(() {});          // Rebuild with new Future
  }
}

// 4. In build: use cached Future, only show loading on initial
FutureBuilder<List<Data>>(
  future: _cachedFuture ?? _fetchData(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
      return LoadingWidget();  // Only on initial load
    }
    return ContentWidget(data: snapshot.data ?? []);
  },
);
```

**Implementation:** See `new_home_screen.dart` for `_sideQuestsFuture` caching.

---

## Potential Optimizations

### 1. Visibility-Based Polling

**Issue:** `daily_quests_widget.dart` and `new_home_screen.dart` poll continuously while visible (5s interval).

**Optimization:** Use `VisibilityDetector` or `WidgetsBindingObserver` to pause polling when app is backgrounded:

```dart
class _MyWidgetState extends State<MyWidget> with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopPolling();
    } else if (state == AppLifecycleState.resumed) {
      _startPolling();
    }
  }
}
```

### 2. Exponential Backoff

**Issue:** Fixed polling intervals don't adapt to activity.

**Optimization:** Implement exponential backoff when no changes detected:

```dart
int _pollCount = 0;
Duration _currentInterval = Duration(seconds: 5);

void _poll() {
  // If no changes after several polls, slow down
  if (_pollCount > 5) {
    _currentInterval = Duration(seconds: min(30, _currentInterval.inSeconds * 2));
  }
}
```

### 3. Deduplicate Overlapping Polls

**Issue:** Quiz API (10s) + You-or-Me API (10s) + Unified Game Service (5s) may overlap.

**Optimization:** Consider consolidating into a single polling service with different callbacks.

### 4. WebSocket for Real-Time Updates

**Future Enhancement:** Replace polling with WebSocket/SSE for true real-time updates:
- Supabase Realtime subscriptions
- Reduce server load
- Instant partner notifications

### 5. Smart Polling Based on Partner Activity

**Optimization:** If partner hasn't been active for a while (based on `last_active` timestamp), reduce polling frequency.

---

## Related Documentation

- [Game Client-Server Architecture](./GAME_CLIENT_SERVER_ARCHITECTURE.md)
- [Steps, Linked, Word Search Architecture](./STEPS_LINKED_WORDSEARCH_ARCHITECTURE.md)
- [Quest System V2](./QUEST_SYSTEM_V2.md)

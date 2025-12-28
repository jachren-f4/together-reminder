# Polling Architecture

## Quick Reference

| Item | Location |
|------|----------|
| Game Polling Mixin | `lib/mixins/game_polling_mixin.dart` |
| Home Polling Service | `lib/services/home_polling_service.dart` |
| Unified Game Service | `lib/services/unified_game_service.dart` |
| Side Quest Base | `lib/services/side_quest_service_base.dart` |

---

## Polling Patterns

### 1. Game Screen Polling (GamePollingMixin)
For turn-based games during partner's turn:

```dart
class _GameScreenState extends State<GameScreen> with GamePollingMixin {
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

### 2. Home Screen Polling (HomePollingService)
For quest card updates while on home screen:

```dart
// Subscribe when widget mounts
_pollingService.subscribe();
_pollingService.subscribeToTopic('dailyQuests', _onQuestUpdate);

// Unsubscribe when widget disposes
_pollingService.unsubscribeFromTopic('dailyQuests', _onQuestUpdate);
_pollingService.unsubscribe();

// Force immediate poll (e.g., on return from game)
_pollingService.pollNow();
```

### 3. Service-Level Polling (UnifiedGameService)
For waiting screens that need state updates:

```dart
_unifiedService.startPolling(
  gameType: gameType,
  matchId: matchId,
  onUpdate: (response) => _onStateUpdate?.call(_convertToGameState(response)),
  intervalSeconds: 5,
);

// Stop with matchId to protect against cross-screen interference
_unifiedService.stopPolling(matchId: matchId);
```

---

## Key Rules

### 1. FutureBuilder Anti-Blink Pattern
When using FutureBuilder in widgets that rebuild due to polling:

```dart
// ❌ WRONG - blinks on every setState
FutureBuilder(future: _fetchData(), ...)  // New Future every build

// ✅ CORRECT - cache the Future
Future<Data>? _cachedFuture;

void _refreshCache() => _cachedFuture = _fetchData();

// Only refresh when data actually changes:
if (hasChanges && mounted) {
  _refreshCache();
  setState(() {});
}

// In build:
FutureBuilder(future: _cachedFuture ?? _fetchData(), ...)
```

### 2. Protect Singleton Callbacks
When service is singleton, protect callbacks from cross-screen interference:

```dart
// Set callback FIRST before any cleanup
_onStateUpdate = onUpdate;

// Only clear callback if THIS instance stopped polling
void stopPolling({String? matchId}) {
  final wasStopped = _unifiedService.stopPolling(matchId: matchId);
  if (wasStopped) {
    _onStateUpdate = null;  // Only clear if we actually stopped
  }
}
```

### 3. Use `mounted` Guards
Always check `mounted` before setState in async callbacks:

```dart
@override
Future<void> onPollUpdate() async {
  final newState = await _service.pollMatchState(_matchId);
  if (mounted) {  // Critical!
    setState(() => _gameState = newState);
  }
}
```

### 4. Stop Polling Before Navigation
Cancel polling before navigating away:

```dart
void _navigateToResults() {
  cancelPolling();  // Stop first
  Navigator.of(context).pushReplacement(ResultsScreen(...));
}
```

### 5. RouteAware for Refresh on Return
Use RouteAware to refresh when returning from pushed screens:

```dart
class _WidgetState extends State<Widget> with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    // Returning from a pushed route
    _pollingService.pollNow();
    setState(() {});
  }
}
```

---

## Common Bugs & Fixes

### 1. Waiting Screen Stuck
**Symptom:** Partner completes but waiting screen doesn't advance.

**Cause:** Callback cleared by game screen dispose.

**Fix:** Use matchId parameter in stopPolling:
```dart
_service.stopPolling(matchId: widget.matchId);
```

### 2. Quest Cards Blinking
**Symptom:** Cards flash/blink every few seconds.

**Cause:** New Future created on every build.

**Fix:** Cache the Future:
```dart
Future<List<Quest>>? _questsFuture;
```

### 3. Memory Leak
**Symptom:** Multiple timers running after navigation.

**Cause:** Forgot to cancel polling in dispose.

**Fix:** Always cancel in dispose:
```dart
@override
void dispose() {
  cancelPolling();
  super.dispose();
}
```

### 4. State Updated After Dispose
**Symptom:** "setState called after dispose" error.

**Cause:** Async callback runs after widget disposed.

**Fix:** Add mounted check:
```dart
if (mounted) setState(() {});
```

---

## Polling Intervals

| Context | Interval | Justification |
|---------|----------|---------------|
| Game waiting screen | 5s | User actively waiting |
| Turn-based game | 10s | Less urgent, save battery |
| Home screen quests | 30s | Background sync |
| Steps data | 60s | HealthKit updates slowly |

---

## File Reference

| File | Purpose |
|------|---------|
| `game_polling_mixin.dart` | Standardized game polling |
| `home_polling_service.dart` | Unified home screen polling |
| `unified_game_service.dart` | Service-level polling for games |
| `side_quest_service_base.dart` | Base class with polling helpers |

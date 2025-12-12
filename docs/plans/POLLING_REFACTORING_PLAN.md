# Polling Architecture Refactoring Plan

## Status: PHASE 1 COMPLETE (Bug Fixed 2025-12-12)

## Problem Statement

The current codebase has **4 different polling patterns** that evolved organically, leading to:
- Confusing code that's hard to debug
- Multiple redundant polls running simultaneously
- Inconsistent completion detection logic
- The "stuck on waiting screen" bug

## Current Architecture (Problematic)

### Pattern A: Service-Based Polling (Quiz/YouOrMe)
```
WaitingScreen → Service.startPolling() → UnifiedGameService → Timer.periodic → callback
```
- QuizMatchWaitingScreen, YouOrMeMatchWaitingScreen
- Each screen creates its own polling timer via service

### Pattern B: Manual Timer (Welcome Quiz)
```
WaitingScreen → Timer.periodic() → Service.getQuizData()
```
- WelcomeQuizWaitingScreen
- Direct timer, no service wrapper

### Pattern C: Topic Pub/Sub (Home Screen)
```
Screen → HomePollingService.subscribe() → Timer.periodic → topic callbacks
```
- NewHomeScreen subscribes to topics
- HomePollingService orchestrates multiple service calls

### Pattern D: Orchestrated (Side Quests)
```
HomePollingService → LinkedService/WordSearchService.poll()
```
- Services don't poll themselves
- HomePollingService calls them periodically

## Proposed Architecture: Unified State Polling

### Single API Endpoint
```
GET /api/sync/state
```

Returns ALL relevant state in one call:
```json
{
  "lp": 1234,
  "dailyQuests": {
    "classic": { "userCompleted": true, "partnerCompleted": false, "matchId": "..." },
    "affirmation": { "userCompleted": false, "partnerCompleted": false },
    "youOrMe": { "userCompleted": true, "partnerCompleted": true, "matchId": "..." }
  },
  "sideQuests": {
    "linked": { "matchId": "...", "isMyTurn": true, "status": "in_progress" },
    "wordSearch": { "matchId": "...", "isMyTurn": false, "status": "in_progress" }
  },
  "activeMatch": {
    "type": "classic",
    "matchId": "...",
    "status": "completed",
    "userAnswered": true,
    "partnerAnswered": true,
    "results": { ... }
  },
  "welcomeQuiz": {
    "userCompleted": true,
    "partnerCompleted": false
  }
}
```

### Single Polling Service
```dart
class UnifiedPollingService {
  static final _instance = UnifiedPollingService._();
  factory UnifiedPollingService() => _instance;

  Timer? _timer;
  final _listeners = <String, Set<Function>>{};
  AppState? _lastState;

  void subscribe(String topic, Function callback);
  void unsubscribe(String topic, Function callback);

  // Topics: 'lp', 'dailyQuests', 'sideQuests', 'activeMatch', 'welcomeQuiz'
}
```

### Screen Integration
```dart
// Waiting screen - just subscribes to 'activeMatch' topic
class QuizMatchWaitingScreen extends StatefulWidget {
  @override
  void initState() {
    UnifiedPollingService().subscribe('activeMatch', _onMatchUpdate);
  }

  void _onMatchUpdate(ActiveMatchState state) {
    if (state.status == 'completed') {
      _navigateToResults(state);
    }
  }
}

// Home screen - subscribes to multiple topics
class NewHomeScreen extends StatefulWidget {
  @override
  void initState() {
    UnifiedPollingService().subscribe('dailyQuests', _onQuestsUpdate);
    UnifiedPollingService().subscribe('sideQuests', _onSideQuestsUpdate);
    UnifiedPollingService().subscribe('lp', _onLpUpdate);
  }
}
```

## Benefits

1. **One poll, one timer** - No more multiple timers competing
2. **Server does the work** - One DB query returns all state
3. **Consistent completion detection** - Server determines completion status
4. **Easier debugging** - One place to add logging
5. **Reduced API calls** - One call every 5s instead of 3-4 separate calls

## Migration Plan

### Phase 1: Fix Immediate Bug (NOW)
- Debug why waiting screen doesn't detect completion
- Root cause is likely in the callback chain or state comparison

### Phase 2: Create Unified API Endpoint
- Create `/api/sync/state` that returns all relevant state
- Keep existing endpoints for backward compatibility

### Phase 3: Create UnifiedPollingService
- Single service with topic-based pub/sub
- Calls new unified endpoint

### Phase 4: Migrate Screens One-by-One
1. QuizMatchWaitingScreen
2. YouOrMeMatchWaitingScreen
3. WelcomeQuizWaitingScreen
4. NewHomeScreen

### Phase 5: Remove Old Code
- Delete individual polling from QuizMatchService, YouOrMeMatchService
- Delete HomePollingService
- Remove redundant service polling methods

## Bug Investigation Results (FIXED 2025-12-12)

### Symptom
User finishes quiz first → goes to waiting screen → partner finishes → waiting screen doesn't navigate to results

### Root Cause: Singleton Callback Chain Interference

**Two-layer bug in singleton services:**

1. **Layer 1: Timer killed by wrong screen**
   - `UnifiedGameService` is a singleton with one shared `_pollTimer`
   - When navigating from GameScreen → WaitingScreen:
     - WaitingScreen.initState() calls startPolling() ✓
     - GameScreen.dispose() calls stopPolling() ✗ KILLS TIMER
   - **Fix:** Added `_currentPollingMatchId` tracking, `force` param, matchId-based stop

2. **Layer 2: Callback cleared by wrong screen**
   - `QuizMatchService` is ALSO a singleton with one shared `_onStateUpdate`
   - Even when Layer 1 fix prevented timer stop, `stopPolling()` still ran `_onStateUpdate = null`
   - Result: Timer fires → callback is NULL → waiting screen never notified
   - **Fix:** `stopPolling()` returns bool, only clear callback if `wasStopped == true`

### Files Changed
- `app/lib/services/unified_game_service.dart:584-601` - Added matchId tracking, bool return
- `app/lib/services/quiz_match_service.dart:136-143` - Conditional callback clearing
- `app/lib/widgets/auth_wrapper.dart:82-86` - Web page refresh fix (separate issue)

### Why This Architecture Is Fragile
See "Proposed Architecture" section for recommended refactoring approaches.

---

## Files to Modify (Future Refactor)

### New Files
- `api/app/api/sync/state/route.ts` - Unified state endpoint
- `app/lib/services/unified_polling_service.dart` - New polling service

### Modified Files
- `app/lib/screens/quiz_match_waiting_screen.dart`
- `app/lib/screens/you_or_me_match_waiting_screen.dart`
- `app/lib/screens/welcome_quiz_waiting_screen.dart`
- `app/lib/screens/new_home_screen.dart`

### Deleted Files (After Migration)
- `app/lib/services/home_polling_service.dart`
- Polling methods in `quiz_match_service.dart`, `you_or_me_match_service.dart`

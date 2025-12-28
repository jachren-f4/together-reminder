# System Overview: Polling, Waiting Screens, Quest Cards & Guidance

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [All Possible Quest States](#all-possible-quest-states)
3. [Polling System](#polling-system)
4. [Waiting Screens](#waiting-screens)
5. [Pending Results System](#pending-results-system)
6. [Quest Card Status Determination](#quest-card-status-determination)
7. [Guidance Hand System](#guidance-hand-system)
8. [State Transition Diagram](#state-transition-diagram)
9. [Current Issues & Edge Cases](#current-issues--edge-cases)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         HOME SCREEN                                      │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ DailyQuestsWidget                                                │    │
│  │  - Subscribes to HomePollingService                              │    │
│  │  - Uses RouteAware to refresh on didPopNext()                   │    │
│  │  - Determines guidance hand via _getGuidanceState()             │    │
│  │                                                                  │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │    │
│  │  │ QuestCard    │  │ QuestCard    │  │ QuestCard    │           │    │
│  │  │ (Classic)    │  │ (Affirmation)│  │ (You or Me)  │           │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘           │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ Side Quests Carousel (in HomeScreen)                             │    │
│  │  - _getSideQuests() builds quest list                           │    │
│  │  - Polls via HomePollingService for turn changes                │    │
│  │                                                                  │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │    │
│  │  │ Steps Card   │  │ Linked Card  │  │ WordSearch   │           │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘           │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     HomePollingService (Singleton)                       │
│  - 5 second polling interval                                            │
│  - Reference counting: auto-start/stop based on subscribers             │
│  - Topics: dailyQuests, sideQuests, linked, wordSearch                  │
│  - Change detection via cached state comparison                         │
│                                                                          │
│  _poll() every 5s:                                                       │
│    1. _pollDailyQuests() → API: /api/sync/quest-status                  │
│    2. _pollLinkedGame() → LinkedService.pollMatchState()                │
│    3. _pollWordSearchGame() → WordSearchService.pollMatchState()        │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## All Possible Quest States

### Main Daily Quests (Quiz, You or Me)

| State | userCompletions | bothCompleted | pendingResults | Badge Shows |
|-------|-----------------|---------------|----------------|-------------|
| **Fresh** | {} | false | false | "Begin Together" |
| **User Playing** | (in game) | false | false | (user is in game screen) |
| **User Waiting** | {userId: true} | false | true* | "Waiting for Partner" |
| **Results Ready** | {userId: true, partnerId: true} | true | true | "RESULTS ARE READY!" |
| **Completed** | {userId: true, partnerId: true} | true | false | "Completed ✓" |

*pendingResults flag is SET when user navigates to waiting screen

### Turn-Based Side Quests (Linked, Word Search)

| State | match.status | currentTurnUserId | pendingResults | Badge Shows |
|-------|--------------|-------------------|----------------|-------------|
| **No Game** | null | null | false | "Start new puzzle" |
| **My Turn** | active | userId | false | "Partner is waiting" |
| **Partner's Turn** | active | partnerId | false | "Waiting for Partner" |
| **Results Ready** | completed | null | true | "RESULTS ARE READY!" |
| **Completed** | completed | null | false | "Completed ✓" |

---

## Polling System

### HomePollingService

**Location:** `lib/services/home_polling_service.dart`

**Key Characteristics:**
- Singleton with reference counting
- 5-second polling interval
- Auto-start when first subscriber joins, auto-stop when last leaves
- Topic-based callbacks for fine-grained updates

**Subscribers:**
```dart
// In widget initState:
_pollingService.subscribe();
_pollingService.subscribeToTopic('dailyQuests', _onQuestUpdate);

// In widget dispose:
_pollingService.unsubscribeFromTopic('dailyQuests', _onQuestUpdate);
_pollingService.unsubscribe();
```

**Poll Cycle:**
1. `_pollDailyQuests()` - Checks `/api/sync/quest-status` for partner completions
2. `_pollLinkedGame()` - Updates Linked match state from server
3. `_pollWordSearchGame()` - Updates Word Search match state from server
4. Notifies topics that had changes

### Waiting Screen Polling (Separate from Home)

Waiting screens have their OWN polling via game services:

```dart
// In QuizMatchWaitingScreen:
_service.startPolling(
  matchId: widget.matchId,
  onUpdate: _onStateUpdate,  // Callback when state changes
  intervalSeconds: 5,
  quizType: widget.quizType,
);
```

**Critical:** Both polling systems can run simultaneously when user is on waiting screen, but HomePollingService callbacks won't fire because user isn't on home screen.

---

## Waiting Screens

### Three Types

| Screen | File | Game Type | Polling |
|--------|------|-----------|---------|
| QuizMatchWaitingScreen | `quiz_match_waiting_screen.dart` | Classic/Affirmation | QuizMatchService |
| YouOrMeMatchWaitingScreen | `you_or_me_match_waiting_screen.dart` | You or Me | YouOrMeMatchService |
| WelcomeQuizWaitingScreen | `welcome_quiz_waiting_screen.dart` | Welcome Quiz | Manual polling |

### Waiting Screen Flow

```
Game Screen
    │
    ▼ (user submits, partner not done)
┌─────────────────────────────────────┐
│         Waiting Screen              │
│                                     │
│  1. Set pending results flag        │
│  2. Start polling                   │
│  3. Show "Waiting for Partner"      │
│                                     │
│  On poll callback:                  │
│    if (state.isCompleted) {         │
│      _handleCompletion(state)       │
│    }                                │
└─────────────────────────────────────┘
    │
    ▼ (partner completes)
┌─────────────────────────────────────┐
│      _handleCompletion()            │
│                                     │
│  1. Set pending results flag (again)│
│  2. Sync LP from server             │
│  3. Update local quest status       │
│  4. Navigate to Results Screen      │
└─────────────────────────────────────┘
```

### Guards Against Double Navigation

```dart
bool _isHandlingCompletion = false;  // Guard flag

void _onStateUpdate(GameState state) {
  if (!mounted) return;
  if (_isHandlingCompletion) return;  // Already handling

  if (state.isCompleted) {
    _isHandlingCompletion = true;
    _service.stopPolling();
    _handleCompletion(state);
  }
}
```

---

## Pending Results System

### Purpose

Track when a user needs to view results for a completed match. This handles:
1. User on waiting screen when partner completes → show results
2. User kills app on waiting screen → show "RESULTS ARE READY!" on home
3. User returns to home after partner completed while they were away

### Storage

**Location:** `lib/services/storage_service.dart`

```dart
// Map of contentType -> matchId
// Stored in Hive 'app_metadata' box under key 'pending_results_match_ids'

Map<String, String> getPendingResultsMatchIds()
Future<void> setPendingResultsMatchId(String contentType, String matchId)
String? getPendingResultsMatchId(String contentType)
bool hasPendingResults(String contentType)
Future<void> clearPendingResultsMatchId(String contentType)
```

### Content Types

| Content Type | Game |
|--------------|------|
| `classic_quiz` | Classic Quiz |
| `affirmation_quiz` | Affirmation Quiz |
| `you_or_me` | You or Me |
| `linked` | Linked |
| `word_search` | Word Search |

### When Flags Are Set

| Location | When | Why |
|----------|------|-----|
| Game Screen | Before navigating to waiting | User might kill app on waiting screen |
| Waiting Screen `_handleCompletion` | When completion detected | Redundant but safe |
| Home Screen `_getSideQuests()` | When polling detects completed game | Partner made final move |

### When Flags Are Cleared

| Location | When |
|----------|------|
| Results Screen `initState` | User views results |
| Tap Handler | Match not actually completed (stale flag) |

---

## Quest Card Status Determination

### Location
`lib/widgets/quest_card.dart` - `_buildStatusBadge()`

### Priority Order

```dart
Widget _buildStatusBadge(...) {
  // 1. FIRST: Turn-based active game (Linked/Word Search)
  if (isTurnBased && _hasActiveGame) {
    if (_isMyTurn) return "Partner is waiting";
    else return "Waiting for Partner";
  }

  // 2. SECOND: Pending results (requires BOTH flag set AND quest completed)
  if (contentType != null && bothCompleted && hasPendingResults(contentType)) {
    return "RESULTS ARE READY!";
  }

  // 3. THIRD: Both completed (user already saw results)
  if (bothCompleted) {
    return "Completed ✓";
  }

  // 4. FOURTH: User completed, waiting for partner
  if (userCompleted && !bothCompleted) {
    return "Waiting for Partner";
  }

  // 5. FIFTH: Partner completed first (partner's turn badge)
  if (partnerCompleted && !userCompleted) {
    return "Partner is waiting";
  }

  // 6. DEFAULT: Fresh quest
  return "Begin Together";
}
```

### Critical: `bothCompleted && hasPendingResults`

The pending results badge ONLY shows when BOTH conditions are true:
- `bothCompleted = true` (quest is actually done)
- `hasPendingResults(contentType) = true` (flag is set)

This prevents showing "RESULTS ARE READY!" before partner has actually completed.

---

## Guidance Hand System

### Location
`lib/widgets/daily_quests_widget.dart` - `_getGuidanceState()`

### Priority Order

```dart
({bool showGuidance, String? guidanceText}) _getGuidanceState(DailyQuest quest) {
  // 1. No unlock state yet → suppress all
  if (_unlockState == null) return suppress;

  // 2. Any quest waiting for partner → suppress ALL guidance
  if (anyWaitingForPartner) return suppress;

  // 3. Any pending results → show ONLY on that quest (priority order)
  if (anyPending) {
    if (thisQuest has pending && earlier quests don't) return show;
    else return suppress;
  }

  // 4. Normal guidance flow → show on current target
  if (quest matches currentGuidanceTarget) return show;

  return suppress;
}
```

### Pending Results Priority

When multiple pending results exist:
1. Classic Quiz (highest priority)
2. Affirmation Quiz
3. You or Me (lowest priority)

```dart
// Only show on affirmation if classic doesn't have pending
if (quest.formatType == 'affirmation' && hasAffirmationPending && !hasClassicPending) {
  return show;
}
```

### Waiting for Partner Suppression

If ANY quest is in "waiting for partner" state, ALL guidance is suppressed:

```dart
final anyWaitingForPartner = allQuests.any((q) {
  final userCompleted = q.hasUserCompleted(userId);
  final bothCompleted = q.isCompleted;
  return userCompleted && !bothCompleted;
});
if (anyWaitingForPartner) return suppress;
```

---

## State Transition Diagram

### Main Quest (Quiz/You or Me)

```
┌─────────────┐
│   FRESH     │  userCompletions: {}
│  (Begin     │  pendingResults: false
│  Together)  │
└──────┬──────┘
       │ User taps card
       ▼
┌─────────────┐
│   IN GAME   │  (User is playing)
│             │
└──────┬──────┘
       │ User submits answers
       │
       ├────────────────────────────────┐
       │ Partner already done           │ Partner not done
       ▼                                ▼
┌─────────────┐                  ┌─────────────┐
│  RESULTS    │                  │   WAITING   │  userCompletions: {user: true}
│  (Direct)   │                  │  (Waiting   │  pendingResults: true
│             │                  │  for Partner│  Badge: "Waiting for Partner"
└──────┬──────┘                  └──────┬──────┘
       │                                │
       │                                │ Partner completes
       │                                │ (detected by polling)
       │                                ▼
       │                         ┌─────────────┐
       │                         │  RESULTS    │  userCompletions: {user, partner}
       │                         │  READY      │  bothCompleted: true
       │                         │             │  pendingResults: true
       │                         │             │  Badge: "RESULTS ARE READY!"
       │                         └──────┬──────┘
       │                                │
       └────────────────────────────────┘
                       │ User views Results Screen
                       ▼
                ┌─────────────┐
                │  COMPLETED  │  pendingResults: false
                │  (✓)        │  Badge: "Completed ✓"
                └─────────────┘
```

### Edge Case: User Leaves Waiting Screen Before Partner Completes

```
┌─────────────┐
│   WAITING   │  pendingResults: true (set when entering waiting)
└──────┬──────┘
       │ User goes back to home (or kills app)
       ▼
┌─────────────┐
│   HOME      │  Badge: "Waiting for Partner"
│   (waiting) │  pendingResults: true (persisted in Hive)
└──────┬──────┘
       │ HomePollingService detects partner completion
       │ Quest becomes bothCompleted=true
       ▼
┌─────────────┐
│   HOME      │  bothCompleted: true
│   (ready)   │  pendingResults: true
│             │  Badge: "RESULTS ARE READY!"
└─────────────┘
```

---

## Current Issues & Edge Cases

### Issue 1: Return Home Button Not Working (Under Investigation)

**Symptom:** After automatic navigation from waiting screen to results, "Return Home" button doesn't work.

**Possible Causes:**
1. Navigation context issues after `pushReplacement`
2. Route stack in unexpected state
3. Widget disposal timing

**Debug Logging Added:**
```dart
onPressed: () {
  print('🏠 Return Home button tapped');
  print('🏠 Navigator.canPop: ${Navigator.of(context).canPop()}');
  Navigator.of(context).popUntil((route) {
    print('🏠 Checking route: ${route.settings.name}, isFirst: ${route.isFirst}');
    return route.isFirst;
  });
}
```

### Issue 2: Stale Pending Results Flag (Previous Day)

**Scenario:**
1. Day 1: User sets pending flag for match1, never views results
2. Day 2: New quests generated
3. User opens app → old flag still exists → might show wrong state

**Potential Fix:** Clear pending results flags when new daily quests are generated.

### Issue 3: Double Polling When on Waiting Screen

**Not Actually a Problem:**
- Waiting screen polls its specific match
- HomePollingService continues but callbacks don't fire (user not on home)
- When user returns, home polling will detect the completion

### Issue 4: Race Condition - Both Users Complete Simultaneously

**Handled By:**
- Server uses `ON CONFLICT DO NOTHING` for quest uploads
- Each user gets their own match state from server
- LP awarded once per couple (server-side tracking)

### Issue 5: Turn-Based Game Partner Never Sees "RESULTS ARE READY!"

**Fixed In:** `home_screen.dart` - `_getSideQuests()`

When polling detects a completed Linked/Word Search game, set the pending results flag for the partner who didn't make the final move.

---

## File Reference

| File | Purpose |
|------|---------|
| `lib/services/home_polling_service.dart` | Unified home screen polling |
| `lib/services/storage_service.dart` | Hive storage including pending results |
| `lib/widgets/daily_quests_widget.dart` | Daily quests display + guidance hand |
| `lib/widgets/quest_card.dart` | Individual quest card + status badges |
| `lib/screens/quiz_match_waiting_screen.dart` | Quiz waiting screen |
| `lib/screens/you_or_me_match_waiting_screen.dart` | You or Me waiting screen |
| `lib/screens/quiz_match_results_screen.dart` | Quiz results screen |
| `lib/screens/home_screen.dart` | Home screen including side quests |

---

## Changelog

| Date | Change |
|------|--------|
| 2025-12-17 | Initial comprehensive documentation |

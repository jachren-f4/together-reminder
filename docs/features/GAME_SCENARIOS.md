# Game Scenarios Documentation

This document describes all possible scenarios for how games flow, what users see, and what state changes occur.

---

## Table of Contents

1. [Game Types Overview](#game-types-overview)
2. [Home Screen Polling System](#home-screen-polling-system)
3. [Quiz Games (Classic & Affirmation)](#quiz-games-classic--affirmation)
4. [You or Me](#you-or-me)
5. [Turn-Based Games (Linked & Word Search)](#turn-based-games-linked--word-search)
6. [Welcome Quiz (Onboarding)](#welcome-quiz-onboarding)
7. [Guidance Hand Scenarios](#guidance-hand-scenarios)
8. [Edge Cases & Error Scenarios](#edge-cases--error-scenarios)

---

## Game Types Overview

| Game | Type | Daily/Side | Questions | Completion |
|------|------|------------|-----------|------------|
| Classic Quiz | Bulk submit | Daily (Slot 0) | 5 | Both submit once |
| Affirmation Quiz | Bulk submit | Daily (Slot 1) | 5 | Both submit once |
| You or Me | Bulk submit | Daily (Slot 2) | 5 | Both submit once |
| Linked | Turn-based | Side Quest | Varies | Puzzle solved |
| Word Search | Turn-based | Side Quest | Varies | All words found |
| Welcome Quiz | Bulk submit | Onboarding | 5 | Both submit once |

---

## Home Screen Polling System

### Overview

The home screen (`home_screen.dart`) uses `HomePollingService` to periodically check for updates from the server. This is how the app knows when a partner has completed a quest.

### Polling Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         HOME SCREEN                                      │
│                                                                          │
│   DailyQuestsWidget              HomeScreen                             │
│   (subscribes to polling)        (subscribes to polling)                │
│           │                              │                              │
│           └──────────────┬───────────────┘                              │
│                          ▼                                              │
│                 HomePollingService                                       │
│                 (singleton, 5-second interval)                          │
│                          │                                              │
│           ┌──────────────┼──────────────┐                               │
│           ▼              ▼              ▼                               │
│   _pollDailyQuests()  _pollLinkedGame()  _pollWordSearchGame()         │
│           │              │              │                               │
│           ▼              ▼              ▼                               │
│   GET /quest-status   LinkedService    WordSearchService                │
│                       .pollMatchState() .pollMatchState()               │
└─────────────────────────────────────────────────────────────────────────┘
```

### Daily Quest Status Polling

**API Endpoint:** `GET /api/sync/quest-status`

**Called:** Every 5 seconds by `HomePollingService._pollDailyQuests()`

**Request:**
```
GET /api/sync/quest-status?date=2025-12-17
Authorization: Bearer <token>
```

**Response:**
```json
{
  "quests": [
    {
      "questId": "q_classic_001",
      "questType": "classic",
      "status": "completed",
      "userCompleted": true,
      "partnerCompleted": true,
      "matchId": "uuid-of-match",
      "matchPercentage": 80,
      "lpAwarded": 30
    },
    {
      "questId": "q_affirmation_001",
      "questType": "affirmation",
      "status": "in_progress",
      "userCompleted": true,
      "partnerCompleted": false,
      "matchId": "uuid-of-match",
      "matchPercentage": null,
      "lpAwarded": 0
    },
    {
      "questId": "yom_001",
      "questType": "you_or_me",
      "status": "pending",
      "userCompleted": false,
      "partnerCompleted": false,
      "matchId": null,
      "matchPercentage": null,
      "lpAwarded": 0
    }
  ],
  "totalLp": 1160,
  "userId": "user-uuid",
  "partnerId": "partner-uuid",
  "date": "2025-12-17"
}
```

### Quest Status Values

| Status | Meaning | Database Condition |
|--------|---------|-------------------|
| `pending` | No one has started | No match exists for this quest |
| `in_progress` | At least one person started | Match exists, status != 'completed' |
| `completed` | Both finished | Match status = 'completed' |

### Per-User Completion Flags

| Field | Meaning |
|-------|---------|
| `userCompleted` | Current user has submitted answers |
| `partnerCompleted` | Partner has submitted answers |

**How determined (server-side):**
```typescript
// For the current user
const userAnswered = isPlayer1
  ? (match.player1_answer_count || 0) > 0
  : (match.player2_answer_count || 0) > 0;

// For the partner
const partnerAnswered = isPlayer1
  ? (match.player2_answer_count || 0) > 0
  : (match.player1_answer_count || 0) > 0;
```

### Client-Side Processing

**Location:** `HomePollingService._pollDailyQuests()` in `lib/services/home_polling_service.dart`

```dart
Future<bool> _pollDailyQuests() async {
  // 1. Call API
  final response = await _apiClient.get('/api/sync/quest-status');

  // 2. For each quest in response
  for (final questData in questsData) {
    final questType = questData['questType'];        // 'classic', 'affirmation', 'you_or_me'
    final partnerCompleted = questData['partnerCompleted'];

    // 3. Check if partner completion changed
    if (_lastQuestCompletions[key] != partnerCompleted) {
      anyChanges = true;
    }

    // 4. If partner completed, update local Hive storage
    if (partnerCompleted) {
      final matchingQuest = localQuests.where(...).firstOrNull;
      if (matchingQuest != null) {
        matchingQuest.userCompletions[partnerId] = true;

        // 5. If BOTH completed, mark quest as completed
        if (userCompletions[userId] == true && userCompletions[partnerId] == true) {
          matchingQuest.status = 'completed';
        }

        await matchingQuest.save();
      }
    }
  }

  // 6. Return whether anything changed
  return anyChanges;
}
```

### What Triggers Quest Card Updates

```
1. HomePollingService._poll() runs (every 5 seconds)
              │
              ▼
2. _pollDailyQuests() detects partnerCompleted changed
              │
              ▼
3. Updates Hive: quest.userCompletions[partnerId] = true
              │
              ▼
4. Returns anyChanges = true
              │
              ▼
5. _notifyTopic('dailyQuests') fires
              │
              ▼
6. DailyQuestsWidget._onQuestUpdate() called
              │
              ▼
7. setState(() {}) triggers rebuild
              │
              ▼
8. Quest cards re-read from Hive and show updated badges
```

### Side Quest Polling (Linked & Word Search)

**Different from daily quests:** Side quests poll individual match state, not a status endpoint.

**Linked:**
```dart
await _linkedService.pollMatchState(linkedMatch.matchId);
// Updates: currentTurnUserId, status, grid state
// Stored in: Hive via StorageService().saveLinkedMatch()
```

**Word Search:**
```dart
await _wordSearchService.pollMatchState(wsMatch.matchId);
// Updates: currentTurnUserId, status, found words
// Stored in: Hive via StorageService().saveWordSearchMatch()
```

### Polling Flow Diagram

```
Every 5 seconds:
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│   _poll()                                                                │
│      │                                                                   │
│      ├─── _pollDailyQuests() ──────────────────────────────────────────┐│
│      │         │                                                        ││
│      │         ▼                                                        ││
│      │    GET /api/sync/quest-status                                    ││
│      │         │                                                        ││
│      │         ▼                                                        ││
│      │    Response: { quests: [...], totalLp: X }                       ││
│      │         │                                                        ││
│      │         ▼                                                        ││
│      │    For each quest:                                               ││
│      │      - Check if partnerCompleted changed                         ││
│      │      - Update Hive if partner completed                          ││
│      │      - Mark quest 'completed' if both done                       ││
│      │         │                                                        ││
│      │         ▼                                                        ││
│      │    Return: hasQuestChanges                                       ││
│      │                                                                   ││
│      ├─── _pollLinkedGame() ───────────────────────────────────────────┐││
│      │         │                                                        │││
│      │         ▼                                                        │││
│      │    If active match exists:                                       │││
│      │      LinkedService.pollMatchState(matchId)                       │││
│      │    Else:                                                         │││
│      │      Try to fetch (partner may have started)                     │││
│      │         │                                                        │││
│      │         ▼                                                        │││
│      │    Compare: currentTurnUserId, status changed?                   │││
│      │         │                                                        │││
│      │         ▼                                                        │││
│      │    Return: hasLinkedChanges                                      │││
│      │                                                                   │││
│      ├─── _pollWordSearchGame() ───────────────────────────────────────┐│││
│      │         │                                                        ││││
│      │         ▼                                                        ││││
│      │    (Same logic as Linked)                                        ││││
│      │         │                                                        ││││
│      │         ▼                                                        ││││
│      │    Return: hasWsChanges                                          ││││
│      │                                                                   ││││
│      └─────────────────────────────────────────────────────────────────┘│││
│                                                                          │││
│   If any changes:                                                        │││
│      - _notifyTopic('dailyQuests') if quest changes                     │││
│      - _notifyTopic('sideQuests') if linked/ws changes                  │││
│      - notifyListeners() for general subscribers                        │││
│                                                                          │││
└─────────────────────────────────────────────────────────────────────────┘│││
```

### Local State vs Server State

| Data | Server (Supabase) | Local (Hive) |
|------|-------------------|--------------|
| Quest completion | `quiz_matches` table | `DailyQuest.userCompletions` |
| Match status | `quiz_matches.status` | `DailyQuest.status` |
| LP total | `couples.total_lp` | `ArenaService._lovePoints` |
| Turn-based games | `linked_matches` / `word_search_matches` | `LinkedMatch` / `WordSearchMatch` |

**Server is source of truth.** Polling syncs server → local.

---

## Quiz Games (Classic & Affirmation)

### Scenario 1: Normal Flow - User Completes First

**Setup:** Fresh quiz, neither user has played

**User A's Flow:**
```
1. Home Screen
   - Quest card shows: "Begin Together"
   - Guidance hand: Points to this quest (if it's the current target)

2. Tap Quest Card
   - Navigate to: Quiz Intro Screen

3. Tap "Let's Play"
   - Navigate to: Quiz Game Screen
   - API call: getOrCreateMatch()
   - Response: New match created, 5 questions loaded

4. Answer all 5 questions, tap Submit
   - API call: submitAnswers()
   - Response: { userAnswered: true, partnerAnswered: false, isCompleted: false }
   - Action: Set pending results flag
   - Navigate to: Waiting Screen

5. Waiting Screen
   - Shows: "Waiting for [Partner Name]"
   - Polling: Every 5 seconds via QuizMatchService
   - Pending flag: SET (contentType: 'classic_quiz' or 'affirmation_quiz')

6. Partner completes (detected by polling)
   - Polling response: { isCompleted: true }
   - Action: Stop polling, sync LP from server, update local quest
   - Navigate to: Results Screen

7. Results Screen
   - Shows: Match percentage, LP earned, answer comparison
   - Action: Clear pending results flag
   - Action: Check for unlocks (You or Me)

8. Tap "Return Home"
   - Navigate to: Home Screen
   - Quest card shows: "Completed ✓"
```

**User B's Flow (completes second):**
```
1. Home Screen
   - Quest card shows: "Begin Together" (or "[Partner] is waiting" if polling detected)

2-4. Same as User A (intro → game → submit)

5. After Submit
   - Response: { userAnswered: true, partnerAnswered: true, isCompleted: true }
   - Action: Set pending results flag (will be cleared immediately)
   - Navigate to: Results Screen (directly, skip waiting)

6-8. Same as User A
```

---

### Scenario 2: User Completes First, Leaves Waiting Screen

**Setup:** User A submits, then goes back to home before User B completes

**User A's Flow:**
```
1-5. Same as Scenario 1 (submit → waiting screen)

6. User taps "Return Home" on Waiting Screen
   - Navigate to: Home Screen
   - Pending flag: STILL SET
   - Quest card shows: "Waiting for Partner"
   - Guidance hand: SUPPRESSED (user is waiting)

7. User B completes (User A on home screen)
   - HomePollingService detects partner completion
   - Quest updated: bothCompleted = true
   - Quest card shows: "RESULTS ARE READY!" (because bothCompleted && pendingFlag)

8. User A taps quest card
   - Code checks pending flag: EXISTS
   - Polls match state: isCompleted = true
   - Navigate to: Results Screen

9. Results Screen
   - Action: Clear pending results flag
   - Tap "Return Home" → Quest card shows: "Completed ✓"
```

---

### Scenario 3: User Kills App on Waiting Screen

**Setup:** User A submits, is on waiting screen, kills app

**User A's Flow:**
```
1-5. Same as Scenario 1 (submit → waiting screen)

6. User kills app
   - Pending flag: PERSISTED in Hive
   - Polling: Stopped (app killed)

7. User B completes while User A's app is closed

8. User A reopens app
   - Navigate to: Home Screen (not waiting screen)
   - HomePollingService starts, detects quest is completed
   - Quest card shows: "RESULTS ARE READY!" (bothCompleted && pendingFlag)

9-10. Same as Scenario 2 (tap → results → clear flag)
```

---

### Scenario 4: User Completes Second (Partner Already Done)

**Setup:** User B already completed and is waiting

**User A's Flow:**
```
1. Home Screen
   - Quest card shows: "[Partner] is waiting" (if polling detected)
   - OR "Begin Together" (if not yet detected)

2. Tap Quest Card → Intro → Game

3. API call: getOrCreateMatch()
   - Response: Match exists, partnerAnswered: true

4. Answer all questions, tap Submit
   - Response: { isCompleted: true, matchPercentage: X, lpEarned: 30 }
   - Navigate to: Results Screen (directly, NO waiting screen)
   - Pending flag: NOT SET (no need, going directly to results)

5. Results Screen → Return Home
   - Quest card shows: "Completed ✓"
```

---

### Scenario 5: User Reopens Game After Submitting

**Setup:** User A already submitted, reopens game screen

**User A's Flow:**
```
1. Home Screen
   - Quest card shows: "Waiting for Partner" (or "RESULTS ARE READY!")

2. Tap Quest Card

3. If pending results flag exists:
   - Poll match state
   - If completed → Navigate to Results Screen
   - If not completed → Clear stale flag, continue to intro

4. If no pending flag OR flag cleared:
   - Navigate to: Intro Screen → Game Screen

5. Game Screen loads
   - API call: getOrCreateMatch()
   - Response: { userAnswered: true, ... }
   - Redirect based on state:
     - isCompleted: true → Results Screen
     - isCompleted: false → Waiting Screen
```

---

## You or Me

### Scenario 6: Normal You or Me Flow

Same as Quiz scenarios, but:
- 5 questions (same as quizzes)
- Content type: `you_or_me`
- Answer encoding: 0 = partner ("you"), 1 = self ("me")
- Server inverts Player 2's answers before comparison

**Key Differences:**
```
Submit Response includes:
- userAnswers: [0, 1, 0, ...] (raw user selections)
- partnerAnswers: [1, 0, 1, ...] (raw partner selections)
- matchPercentage: Server-calculated (after inversion)

DO NOT recalculate match percentage client-side!
```

---

## Turn-Based Games (Linked & Word Search)

### Scenario 7: Normal Turn-Based Flow

**Setup:** No active game, User A starts first

**User A's Flow:**
```
1. Home Screen (Side Quests)
   - Quest card shows: "Start new puzzle"

2. Tap Quest Card → Intro Screen

3. Tap "Start Game"
   - API call: getOrCreateMatch()
   - Response: New match, currentTurnUserId = User A

4. Game Screen
   - User A makes move(s)
   - API call: submitTurn()
   - Response: { currentTurnUserId: User B }
   - Match saved to Hive

5. Return to Home
   - Quest card shows: "Waiting for [Partner]"
   - Polling: HomePollingService checks turn changes
```

**User B's Flow:**
```
1. Home Screen (Side Quests)
   - Polling detects active match
   - Quest card shows: "[Partner] is waiting" (it's User B's turn)

2. Tap Quest Card → Game Screen (directly, no intro for active games)

3. Make moves, submit turn
   - Cycle continues until puzzle solved
```

---

### Scenario 8: Turn-Based Game Completes

**Setup:** User A makes final winning move

**User A's Flow (makes final move):**
```
1. Game Screen - makes winning move
   - API call: submitTurn()
   - Response: { status: 'completed' }
   - Action: Set pending results flag
   - Navigate to: Completion Screen

2. Completion Screen
   - Shows: Results, LP earned
   - Action: Clear pending results flag

3. Return Home
   - Quest card shows: "Completed ✓" (or starts new game after cooldown)
```

**User B's Flow (partner made final move):**
```
1. Home Screen
   - Was showing: "Waiting for [Partner]" (User B's turn next)
   - Polling detects: status = 'completed'
   - _getSideQuests() sets pending flag (User B didn't make final move)
   - Quest card shows: "RESULTS ARE READY!"

2. Tap Quest Card
   - Code checks pending flag: EXISTS
   - Navigate to: Completion Screen

3. Completion Screen
   - Action: Clear pending results flag
   - Return Home → Quest card shows: "Completed ✓"
```

---

### Scenario 9: User B Never Sees "RESULTS ARE READY!" (Bug - Now Fixed)

**Previous Bug:**
```
- User A makes final move → sets pending flag → sees completion
- User B on home → polling detects completion
- BUT: Pending flag only set by player who makes final move
- User B's quest card showed "Completed ✓" directly (no "RESULTS ARE READY!")
```

**Fix Applied:**
```dart
// In home_screen.dart _getSideQuests():
if (activeLinkedMatch.status == 'completed') {
  // Set pending results flag if not already set
  // This catches the case where partner made the final move
  if (!_storage.hasPendingResults('linked')) {
    await _storage.setPendingResultsMatchId('linked', activeLinkedMatch.matchId);
  }
}
```

---

## Welcome Quiz (Onboarding)

### Scenario 10: Welcome Quiz Flow

**Setup:** New couple, just completed pairing

**User A's Flow:**
```
1. After Pairing
   - Navigate to: Welcome Quiz Intro Screen

2. Tap "Let's Play"
   - Navigate to: Welcome Quiz Game Screen
   - 5 questions, same mechanics as regular quiz

3. Submit answers
   - If partner not done → Welcome Quiz Waiting Screen
   - If partner done → Welcome Quiz Results Screen

4. Welcome Quiz Results Screen
   - Shows: Match percentage
   - Action: Trigger unlock (Classic + Affirmation quizzes)
   - Action: Show unlock celebration

5. Navigate to Home
   - Shows: LP Intro Overlay (first time seeing LP)
   - Daily quests now visible
```

**Key Differences from Regular Quiz:**
- No daily quest card (one-time flow)
- Unlocks Classic + Affirmation quizzes on completion
- Shows LP intro overlay on home after completion
- Uses `PopScope(canPop: false)` - user cannot go back

---

## Guidance Hand Scenarios

### Scenario 11: Normal Onboarding Progression

```
1. After Welcome Quiz
   - Guidance target: Classic Quiz
   - Hand points to: Classic Quiz card

2. After Classic Quiz completed
   - Guidance target: Affirmation Quiz
   - Hand points to: Affirmation Quiz card

3. After Affirmation Quiz completed
   - Guidance target: You or Me
   - Hand points to: You or Me card
   - You or Me unlocks

4. After You or Me completed
   - Guidance target: Linked (or none if not unlocked)
   - Hand points to: Linked card in Side Quests
```

---

### Scenario 12: Guidance with Pending Results

**Setup:** User completed Classic Quiz, killed app on waiting, partner completed

```
1. Home Screen
   - Classic Quiz: "RESULTS ARE READY!" (bothCompleted && pendingFlag)
   - Affirmation Quiz: "Begin Together"
   - You or Me: Locked

2. Guidance Hand Logic:
   - Check pending results: classic_quiz = true
   - Hand points to: Classic Quiz (with "Continue Here" text)
   - Affirmation Quiz: NO hand (suppressed)

3. User taps Classic Quiz → Results → clears flag

4. Guidance Hand Logic (after):
   - Check pending results: none
   - Normal flow: Points to Affirmation Quiz
```

---

### Scenario 13: Guidance Suppressed While Waiting

**Setup:** User completed Classic Quiz, waiting for partner

```
1. Home Screen
   - Classic Quiz: "Waiting for Partner" (userCompleted && !bothCompleted)
   - Affirmation Quiz: "Begin Together"

2. Guidance Hand Logic:
   - Check: anyWaitingForPartner = true
   - ALL guidance suppressed
   - No hand shown on any quest

3. Partner completes Classic Quiz

4. Home Screen (after polling)
   - Classic Quiz: "RESULTS ARE READY!"
   - Guidance: Points to Classic Quiz ("Continue Here")
```

---

### Scenario 14: Multiple Pending Results

**Setup:** User completed Classic AND Affirmation, both have pending results

```
1. Home Screen
   - Classic Quiz: "RESULTS ARE READY!"
   - Affirmation Quiz: "RESULTS ARE READY!"

2. Guidance Hand Logic:
   - Check pending: classic = true, affirmation = true
   - Priority: Classic > Affirmation > You or Me
   - Hand points to: Classic Quiz ONLY

3. User views Classic results → clears classic flag

4. Guidance Hand Logic (after):
   - Check pending: affirmation = true
   - Hand points to: Affirmation Quiz

5. User views Affirmation results → clears affirmation flag

6. Normal guidance resumes
```

---

## Edge Cases & Error Scenarios

### Scenario 15: Network Error During Submit

```
1. User answers all questions, taps Submit
2. Network error occurs
3. Error shown to user
4. User can retry
5. Pending flag: NOT SET (submit didn't succeed)
```

### Scenario 16: App Killed During Submit

```
1. User taps Submit
2. API call in progress
3. User kills app

Possible outcomes:
A) Submit succeeded server-side:
   - User reopens → Game screen → getOrCreateMatch() → redirect to waiting/results

B) Submit failed server-side:
   - User reopens → Game screen → can answer and submit again
```

### Scenario 17: Stale Pending Flag (Previous Day)

```
1. Day 1: User completes quiz, doesn't view results
2. Day 2: New quests generated

State:
- Pending flag: Still set with Day 1's matchId
- Day 2 quest: bothCompleted = false (fresh quest)

Quest card check:
- bothCompleted(false) && pendingFlag(true) → false
- Shows: "Begin Together" (correct!)

On tap:
- Polls Day 1's matchId
- If completed → Shows Day 1 results (user never saw them)
- If not completed → Clears stale flag, continues to Day 2 quiz
```

### Scenario 18: Both Users Complete Simultaneously

```
1. User A and User B both submit within seconds

Server handling:
- First submit: Stores answers, returns { partnerAnswered: false }
- Second submit: Stores answers, marks completed, awards LP

Client handling:
- User who submitted "first" (got partnerAnswered: false):
  - Goes to waiting screen
  - Immediate poll detects completion
  - Navigates to results

- User who submitted "second" (got isCompleted: true):
  - Goes directly to results

Both see results correctly.
```

### Scenario 19: Unlock Celebration Blocking Navigation

**Potential Issue:**
```
1. User completes Affirmation Quiz (both quizzes now done)
2. Results screen loads
3. _checkForUnlock() runs:
   - Notifies server of completion
   - Checks shouldShowYouOrMeCelebration() → true
   - Shows celebration overlay
4. If celebration not dismissed properly → Return Home button blocked
```

**To Debug:**
- Check if 🏠 logs appear when tapping button
- If no logs → overlay is blocking taps
- Check celebration dialog dismiss logic

---

## State Reference Tables

### Pending Results Flags

| Content Type | Set When | Cleared When |
|--------------|----------|--------------|
| `classic_quiz` | Navigate to waiting OR completion detected | Results screen initState |
| `affirmation_quiz` | Navigate to waiting OR completion detected | Results screen initState |
| `you_or_me` | Navigate to waiting OR completion detected | Results screen initState |
| `linked` | Navigate to completion OR polling detects completion | Completion screen |
| `word_search` | Navigate to completion OR polling detects completion | Completion screen |

### Quest Card Badge Priority

| Priority | Condition | Badge |
|----------|-----------|-------|
| 1 | Turn-based + active + my turn | "[Partner] is waiting" |
| 2 | Turn-based + active + partner's turn | "Waiting for [Partner]" |
| 3 | bothCompleted + pendingFlag | "RESULTS ARE READY!" |
| 4 | bothCompleted + !pendingFlag | "Completed ✓" |
| 5 | userCompleted + !bothCompleted | "Waiting for Partner" |
| 6 | partnerCompleted + !userCompleted | "[Partner] is waiting" |
| 7 | Default | "Begin Together" |

### Guidance Hand Priority

| Priority | Condition | Action |
|----------|-----------|--------|
| 1 | Unlock state not loaded | Suppress all |
| 2 | Any quest waiting for partner | Suppress all |
| 3 | Classic has pending results | Show on Classic only |
| 4 | Affirmation has pending (no classic) | Show on Affirmation only |
| 5 | You or Me has pending (no quiz pending) | Show on You or Me only |
| 6 | Normal guidance target | Show on target quest |

---

## File Locations

| Component | File |
|-----------|------|
| Quiz Game Screen | `lib/screens/quiz_match_game_screen.dart` |
| Quiz Waiting Screen | `lib/screens/quiz_match_waiting_screen.dart` |
| Quiz Results Screen | `lib/screens/quiz_match_results_screen.dart` |
| You or Me Game Screen | `lib/screens/you_or_me_match_game_screen.dart` |
| You or Me Waiting Screen | `lib/screens/you_or_me_match_waiting_screen.dart` |
| Linked Game Screen | `lib/screens/linked_game_screen.dart` |
| Word Search Game Screen | `lib/screens/word_search_game_screen.dart` |
| Daily Quests Widget | `lib/widgets/daily_quests_widget.dart` |
| Quest Card | `lib/widgets/quest_card.dart` |
| Home Screen (Side Quests) | `lib/screens/home_screen.dart` |
| Home Polling Service | `lib/services/home_polling_service.dart` |
| Storage Service | `lib/services/storage_service.dart` |

---

## Changelog

| Date | Change |
|------|--------|
| 2025-12-17 | Initial scenarios documentation |

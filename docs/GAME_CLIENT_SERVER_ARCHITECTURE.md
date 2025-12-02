# Game Client-Server Architecture

**Comprehensive analysis of daily quests, classic quiz, affirmation quiz, and you-or-me game flows.**

Last Updated: 2025-12-01

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Daily Quest Generation & Sync](#1-daily-quest-generation--sync)
3. [Classic Quiz Flow](#2-classic-quiz-flow)
4. [Affirmation Quiz Flow](#3-affirmation-quiz-flow)
5. [You-or-Me Flow](#4-you-or-me-flow)
6. [Love Points System](#5-love-points-system)
7. [Complete Request/Response Sequences](#6-complete-requestresponse-sequences)
8. [Key Design Patterns](#7-key-design-patterns)
9. [Critical Implementation Notes](#8-critical-implementation-notes)
10. [File Reference](#9-file-reference)

---

## Architecture Overview

| Component | Pattern |
|-----------|---------|
| **Game API** | Unified endpoint `/api/sync/game/{type}/play` for all 3 game types |
| **LP Awards** | Server-authoritative with idempotency via `relatedId` |
| **Quest Sync** | First device generates, second loads via polling |
| **Completion Sync** | 5s polling on waiting screens, 30s on home screen |

---

## 1. Daily Quest Generation & Sync

### Architecture
- **First-device-generates, second-device-loads pattern** via Supabase API
- Generation happens in Flutter (client), quests synced via API to Supabase, second device polls for sync

### Flutter Service Files

**`app/lib/services/quest_sync_service.dart`**
- `syncTodayQuests()` (Lines 29-118): Polls Supabase for existing quests, handles device priority (second device waits 3 seconds, retries at 2 seconds if still empty)
- `saveQuestsToSupabase()` (Lines 121-155): POST quests to API with denormalized metadata (`formatType`, `quizName`)
- `_loadQuestsFromSupabase()` (Lines 158-204): Parses API response and saves to Hive

**`app/lib/services/daily_quest_service.dart`**
- `getTodayQuests()`: Fetches from Hive storage
- `completeQuestForUser()` (Lines 77-141): Marks user complete, checks if both done
- **NOTE**: LP is NOT awarded here - server awards it

**`app/lib/widgets/daily_quests_widget.dart`**
- `initState()` (Lines 42-50): Starts 30-second polling timer
- `_pollQuestStatus()` (Lines 86-153): GET /api/sync/quest-status every 30s
- Uses `RouteAware` pattern (Lines 52-72) for UI refresh when returning from quest screens

### API Routes

**`api/app/api/sync/daily-quests/route.ts`**
- **POST** (Lines 5-73): Saves quests to `daily_quests` table
- **GET** (Lines 117-150): Fetches quests for date
- **PATCH** (Lines 76-115): Updates content_id for a quest

**`api/app/api/sync/quest-status/route.ts`**
- **GET** (Lines 39-116): Returns completion status for polling
  - Fetches from `quiz_matches` table
  - Returns: questId, questType, status, userCompleted, partnerCompleted, matchId, lpAwarded
  - Also returns `totalLp` from `couples.total_lp`

### Sequence Flow

```
First Device (Alice):
1. App detects no quests for today
2. Generates 3 quests locally (classic, affirmation, you_or_me)
3. POST /api/sync/daily-quests → Supabase
4. Quests saved to daily_quests table

Second Device (Bob - waits 3 seconds):
1. syncTodayQuests() detects second device (alphabetically sorted user IDs)
2. Waits 3 seconds, then GET /api/sync/daily-quests
3. If empty, waits 2 more seconds and retries
4. Loads quests from Supabase, saves to local Hive
5. Both devices now have identical quests (same IDs)
```

---

## 2. Classic Quiz Flow

### Flutter Services

**`app/lib/services/unified_game_service.dart`**
- **Entry point for all game types** (classic, affirmation, you_or_me)
- `startGame(gameType)` (Lines 366-381): POST /api/sync/game/{type}/play with empty request
- `submitAnswers()` (Lines 388-415): POST with matchId + answers
  - **Lines 405-408**: Calls `LovePointService.fetchAndSyncFromServer()` if game completed
- `getGameStatus()` (Lines 481-511): GET /api/sync/game/status (all games for date)
  - **Line 504**: Syncs LP via `LovePointService.syncTotalLP()`

**`app/lib/services/quiz_match_service.dart`**
- Wrapper around UnifiedGameService for backward compatibility
- `getOrCreateMatch()` (Lines 22-36): Calls UnifiedGameService.startGame()
- `submitAnswers()` (Lines 62-89): Calls UnifiedGameService.submitAnswers()
- `pollMatchState()` (Lines 39-55): For waiting screens

### Flutter UI Screens

**`app/lib/screens/quiz_match_game_screen.dart`**
- `_loadGameState()` (Lines 87-139): Calls `_service.getOrCreateMatch(widget.quizType)`
- `_submitAnswers()` (Lines 174-225): Submits answers, updates local quest status
- `_updateLocalQuestStatus()` (Lines 228-267): Calls `DailyQuestService.completeQuestForUser()`

**`app/lib/screens/quiz_match_waiting_screen.dart`**
- `_startPolling()` (Lines 79-92): 5-second polling interval
- `_handleCompletion()` (Lines 95-116): Calls `LovePointService.fetchAndSyncFromServer()`

### API Routes

**`api/app/api/sync/game/{type}/play/route.ts`**
- **POST** handler with 4 request variants:
  1. Start new: `{localDate}` → creates match, returns quiz
  2. Submit answers: `{matchId, answers}` → scores answers, awards LP if both answered
  3. Start + submit: `{localDate, answers}` → both in one call
  4. Get state: `{matchId}` → returns match state only

**`api/lib/game/handler.ts`**

**GAME_CONFIG** (Lines 70-98):
```typescript
classic: { branches: ['lighthearted', 'deep', 'spicy'], lpReward: 30, isTurnBased: false }
affirmation: { branches: ['practical', 'emotional', 'spiritual'], lpReward: 30, isTurnBased: false }
you_or_me: { branches: ['playful', 'reflective', 'intimate'], lpReward: 30, isTurnBased: true }
```

Key functions:
- `getOrCreateMatch()` (Lines 206-269): Finds/creates match in quiz_matches
- `submitAnswers()` (Lines 311-379): Updates answers, calculates match%, awards LP
- `calculateMatchPercentage()` (Lines 381-399): Compares answers (with inversion for you_or_me)

### Sequence Flow

```
Start Game:
1. QuizMatchGameScreen._loadGameState() calls getOrCreateMatch('classic')
2. POST /api/sync/game/classic/play {localDate}
3. Server: getOrCreateMatch() finds/creates match in quiz_matches
4. Server: loadQuiz() reads classic-quiz/lighthearted/quiz_X.json
5. Response: {match, state, quiz, isNew}
6. Screen shows questions

User Answers:
1. QuizMatchGameScreen._nextQuestion() calls _submitAnswers()
2. POST /api/sync/game/classic/play {matchId, answers}
3. Server: submitAnswers() updates answers, calculates matchPercentage if both answered
4. If both answered:
   - calculateMatchPercentage() compares both answer arrays
   - awardLP(coupleId, 30, 'classic_complete', matchId)
   - status = 'completed'
5. Response: {match, state, result (if completed)}
6. If not completed: Navigate to QuizMatchWaitingScreen
7. If completed: Navigate to QuizMatchResultsScreen

Waiting (Polling):
1. QuizMatchWaitingScreen._startPolling() with 5s interval
2. GET /api/sync/game/classic/play {matchId}
3. Server: builds state from match
4. If isCompleted=true:
   - Client calls LovePointService.fetchAndSyncFromServer()
   - Navigate to QuizMatchResultsScreen
```

---

## 3. Affirmation Quiz Flow

### Architecture
- **Identical to Classic Quiz** except questType='affirmation'
- Uses same UnifiedGameService and quiz_matches table
- Different branch progression and question set

### Key Differences from Classic
- **Branches**: practical, emotional, spiritual (vs classic: lighthearted, deep, spicy)
- **LP reward**: 30 LP (same as classic)
- **Questions loaded from**: affirmation/{branch}/quiz_X.json
- **Activity type**: 'affirmation_quiz' (stored in branch_progression table)

### Files Involved
- `app/lib/services/affirmation_quiz_bank.dart`: Question bank (6 quizzes, 30 questions)
- `app/lib/services/unified_game_service.dart`: Main service (shared)
- `app/lib/screens/affirmation_intro_screen.dart`: Intro screen
- `app/lib/screens/quiz_match_game_screen.dart`: Game screen (reused from classic)
- API routes: Same `/api/sync/game/affirmation/play` endpoint

---

## 4. You-or-Me Flow

### Architecture
- **Same unified game API** as classic/affirmation
- **Key difference**: Answers are RELATIVE (user taps "You"=0 or "Me"=1, relative to that player)
- **Server inverts player2 answers** before comparison

### Answer Encoding

```
User taps "You" → sends 0 (picking partner)
User taps "Me"  → sends 1 (picking self)
Both partners picking the SAME PERSON send DIFFERENT values
```

**Example:**
- TestiY picks "Jokke" (partner) → sends 0
- Jokke picks "Jokke" (self) → sends 1
- Without inversion: 0≠1 = no match
- With server inversion: 0==0 = match

### Server Inversion Logic

```typescript
// api/lib/game/handler.ts:391-393
const compareP2 = gameType === 'you_or_me'
  ? p2.map(v => v === 0 ? 1 : 0)  // Invert: 0→1, 1→0
  : p2;
```

### Flutter Services

**`app/lib/services/you_or_me_match_service.dart`**
- `getOrCreateMatch()` (Lines 22-31): Calls UnifiedGameService.startGame(GameType.you_or_me)
- `submitAllAnswers()` (Lines 53-83): Converts string answers to indices, submits bulk

### Key Features
- **first_player_id**: Stored in couples table, determines who plays first
- **isTurnBased**: true in GAME_CONFIG
- **Bulk submission**: User answers all questions, then submits all at once

### Match Calculation Example

```
Alice answers: [0, 1, 0] = [You, Me, You]
Bob answers:   [0, 0, 0] = [You, You, You]

Alice is Player1, Bob is Player2
Bob's answers inverted: [1, 1, 1]

Comparison: [0≠1, 1≠1, 0≠1] = 0% match

vs if Bob picked: [0, 1, 0] (same as Alice)
Inverted: [1, 0, 1]
Comparison: [0≠1, 1=1, 0≠1] = 1 match = 33%
```

---

## 5. Love Points System

### Architecture
- **Server-authoritative**: LP stored at couple level (`couples.total_lp`), NOT per-user
- **Single row per couple**: Atomic updates prevent race conditions
- **Idempotent**: relatedId prevents double-counting on retries

### LP Awards Per Game Type

| Game | LP | Source String | File |
|------|-----|---------------|------|
| Classic Quiz | 30 | `classic_complete` | `quiz-match/submit/route.ts` |
| Affirmation | 30 | `affirmation_complete` | `quiz-match/submit/route.ts` |
| You-or-Me | 30 | `you_or_me_complete` | `you-or-me-match/submit/route.ts` |
| Linked | 30 | `linked_complete` | `linked/submit/route.ts` |
| Word Search | 30 | `word_search_complete` | `word-search/submit/route.ts` |
| Steps Together | 15-30 | `steps_complete` | `steps/route.ts` |

**Maximum daily LP:** 165-180 LP

### Flutter Service

**`app/lib/services/love_point_service.dart`**

Key methods:
- `syncTotalLP()` (Lines 208-255): Compares local vs server LP, updates Hive, shows banner
- `fetchAndSyncFromServer()` (Lines 260-279): GET /api/sync/game/status, calls syncTotalLP()
- `setLPChangeCallback()` (Lines 196-198): Registers callback for UI updates

### API Utility

**`api/lib/lp/award.ts`**

```typescript
async function awardLP(
  coupleId: string,
  amount: number,
  source: string,
  relatedId?: string
): Promise<AwardLPResult>
```

- **Idempotency check** (Lines 44-66): Queries for existing transaction with same source + relatedId
- **Atomic update** (Lines 69-76): `UPDATE couples SET total_lp = total_lp + $1`
- **Transaction logging** (Lines 84-105): Records for audit trail

### Sync Flow

```
1. Game completes → Server awards LP
   awardLP(coupleId, 30, 'classic_complete', matchId)
   → UPDATE couples SET total_lp = total_lp + 30

2. Client detects completion
   UnifiedGameService.submitAnswers() sees isCompleted=true

3. Client syncs LP
   LovePointService.fetchAndSyncFromServer()
   → GET /api/sync/game/status
   → Response: {totalLp: 1190}

4. Client updates local
   syncTotalLP(1190)
   → Updates user.lovePoints in Hive
   → Shows "+30 LP" banner
   → Calls _onLPChanged callback
   → UI updates via setState()
```

---

## 6. Complete Request/Response Sequences

### Classic Quiz Complete Flow

```
ALICE (First Device)
├─ POST /api/sync/game/classic/play {localDate: "2025-11-29"}
│  ├─ Server: getOrCreateMatch(couple, 'classic', "2025-11-29")
│  ├─ Server: loadQuiz('classic', 'lighthearted', quiz_X)
│  └─ Response: {match, quiz, state: {canSubmit: true, userAnswered: false}}
│
├─ Show 5 questions, user answers all
│
├─ POST /api/sync/game/classic/play {matchId: uuid, answers: [0,2,1,3,1]}
│  ├─ Server: submitAnswers()
│  ├─ Update quiz_matches: player1_answers = [0,2,1,3,1]
│  ├─ Both answered? NO
│  └─ Response: {state: {userAnswered: true, partnerAnswered: false, isCompleted: false}}
│
├─ Navigate to QuizMatchWaitingScreen
└─ Start polling GET /api/sync/game/classic/play {matchId}

BOB (Second Device)
├─ POST /api/sync/game/classic/play {localDate: "2025-11-29"}
│  └─ Response: {match (same UUID), quiz (same questions)}
│
├─ Show same 5 questions, user answers all
│
├─ POST /api/sync/game/classic/play {matchId: uuid, answers: [1,2,1,2,0]}
│  ├─ Server: submitAnswers()
│  ├─ Both answered? YES
│  ├─ matchPercentage = 60% (3/5 matches)
│  ├─ awardLP(coupleId, 30, 'classic_complete', matchId)
│  └─ Response: {state: {isCompleted: true}, result: {matchPercentage: 60, lpEarned: 30}}
│
├─ UnifiedGameService detects isCompleted=true
├─ Calls LovePointService.fetchAndSyncFromServer()
├─ syncTotalLP() → shows "+30 LP" banner
└─ Navigate to QuizMatchResultsScreen

ALICE (Polling Detected)
├─ GET /api/sync/game/classic/play {matchId}
├─ Response: {state: {isCompleted: true}, result: {...}}
├─ _handleCompletion() → fetchAndSyncFromServer()
├─ syncTotalLP() → shows "+30 LP" banner
└─ Navigate to QuizMatchResultsScreen
```

---

## 7. Key Design Patterns

### 1. Server-Authoritative LP
- All LP awards happen on server
- Clients only sync from server
- Prevents double-counting on retries
- Both partners always see identical LP

### 2. Unified Game API
- Single endpoint handles: start, submit, poll
- Works for classic, affirmation, you_or_me
- Shared quiz_matches table
- Config per game type (branches, LP, turn-based flag)

### 3. Idempotent LP Awards
- `relatedId` (matchId) + `source` + 24h window prevents duplicates
- Safe to retry requests without doubling LP

### 4. Polling-Based Sync
- DailyQuestsWidget: 30-second poll for partner quest completion
- QuizMatchWaitingScreen: 5-second poll for partner game completion
- GameStatus endpoint: Returns all games + totalLp

### 5. RouteAware Pattern
- DailyQuestsWidget uses `didPopNext()` to refresh when returning from quiz screens
- Ensures fresh data from Hive after navigation

### 6. Relative Answer Encoding (You-or-Me)
- User taps "You" = picking partner (0)
- User taps "Me" = picking self (1)
- Server inverts player2 before comparison
- Both picking same person = match

### 7. Denormalized Metadata (Quests)
- Quests stored with `formatType` + `quizName` in metadata
- Partner device loads quests from API without local session lookup
- Prevents "session not found" errors on second device

---

## 8. Critical Implementation Notes

### DO NOT

| Rule | Why |
|------|-----|
| Call `LovePointService.awardPoints()` locally | Causes double-count (server already awards) |
| Compare raw you_or_me answers without inversion | Wrong match calculation |
| Use session lookup for quest titles | Partner has no local sessions |
| Use synchronous `isAuthenticated` check | Race condition after OTP |

### DO

| Rule | Implementation |
|------|----------------|
| Call `fetchAndSyncFromServer()` on game completion | `unified_game_service.dart:405-408` |
| Award LP server-side with relatedId | `api/lib/lp/award.ts` |
| Use RouteAware for quest card refresh | `daily_quests_widget.dart:52-72` |
| Poll 30s for quest completion, 5s for game | Widget and waiting screen |
| Store LP at couple level | `couples.total_lp` |

---

## 9. File Reference

### Flutter - Game Services

| File | Purpose | Key Functions |
|------|---------|---------------|
| `unified_game_service.dart` | Core game API | startGame, submitAnswers, getGameStatus |
| `quiz_match_service.dart` | Classic/Affirmation wrapper | getOrCreateMatch, pollMatchState |
| `you_or_me_match_service.dart` | You-or-Me wrapper | submitAllAnswers (bulk) |

### Flutter - Quest Services

| File | Purpose | Key Functions |
|------|---------|---------------|
| `quest_sync_service.dart` | Quest sync to Supabase | syncTodayQuests, saveQuestsToSupabase |
| `daily_quest_service.dart` | Local quest management | completeQuestForUser, getTodayQuests |

### Flutter - LP Service

| File | Purpose | Key Functions |
|------|---------|---------------|
| `love_point_service.dart` | LP sync & management | syncTotalLP, fetchAndSyncFromServer |

### Flutter - Screens

| File | Purpose |
|------|---------|
| `quiz_match_game_screen.dart` | Quiz gameplay |
| `quiz_match_waiting_screen.dart` | Waiting + polling |
| `you_or_me_match_game_screen.dart` | You-or-Me gameplay |

### Flutter - Widgets

| File | Purpose |
|------|---------|
| `daily_quests_widget.dart` | Quest UI + 30s polling |

### API - Routes

| Endpoint | File | Purpose |
|----------|------|---------|
| `/sync/game/{type}/play` | `game/{type}/play/route.ts` | Unified game endpoint |
| `/sync/game/status` | `game/status/route.ts` | Poll all games + LP |
| `/sync/daily-quests` | `daily-quests/route.ts` | Quest CRUD |
| `/sync/quest-status` | `quest-status/route.ts` | Quest completion poll |

### API - Libraries

| File | Purpose | Key Functions |
|------|---------|---------------|
| `lib/game/handler.ts` | Shared game logic | getOrCreateMatch, submitAnswers, calculateMatchPercentage |
| `lib/lp/award.ts` | LP utility | awardLP (idempotent) |

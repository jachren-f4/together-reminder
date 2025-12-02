# Steps Together, Linked & Word Search Architecture

**Comprehensive analysis of client/server interactions for Steps Together, Linked crossword, and Word Search games.**

Last Updated: 2025-12-01

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Steps Together Flow](#1-steps-together-flow)
3. [Linked Crossword Flow](#2-linked-crossword-flow)
4. [Word Search Flow](#3-word-search-flow)
5. [Love Points Architecture](#4-love-points-architecture)
6. [Branch Rotation Logic](#5-branch-rotation-logic)
7. [Comparison Table](#6-comparison-table)
8. [File Reference](#7-file-reference)

---

## Architecture Overview

| Aspect | Steps Together | Linked | Word Search |
|--------|----------------|--------|-------------|
| **Turn-Based** | No | Yes | Yes (3 words/turn) |
| **Cooldown** | N/A | Daily | Daily |
| **LP Amount** | 15-30 (variable) | 30 (fixed) | 30 (fixed) |
| **LP Timing** | On claim | On completion | On completion |
| **Branches** | None | 3 | 3 |
| **Polling** | 60s | 10s | 10s |

---

## 1. Steps Together Flow

### 1.1 Architecture
- HealthKit/Health Connect → Flutter → Supabase API
- Manual claim triggers LP award
- Partner data synced via polling

### 1.2 Flutter Services

**`app/lib/services/steps_sync_service.dart`**

Key methods:
- `performFullSync()` (lines 155-171): Orchestrates sync
  1. Reads HealthKit via `_healthService.syncTodaySteps()`
  2. Reads yesterday's steps
  3. Pushes to server via `syncStepsToServer()`
  4. Syncs connection status
- `syncStepsToServer()` (lines 91-120): POST `/api/sync/steps`
- `loadPartnerDataFromServer()` (lines 206-267): GET `/api/sync/steps`
- `startPolling()` (lines 41-54): 60-second polling interval
- `markClaimedInServer()` (lines 174-203): Claim reward

**`app/lib/services/steps_health_service.dart`**
- HealthKit data reading
- Permission handling

### 1.3 Flutter Screen

**`app/lib/screens/steps_counter_screen.dart`**
- Calls `_stepsService.syncSteps()` every 60 seconds
- Shows dual-ring animation for user vs partner steps
- Displays claim button when reward available

### 1.4 API Route

**`api/app/api/sync/steps/route.ts`**

**POST /api/sync/steps** handles three operations:

1. **Connection Status** (lines 57-75)
   ```typescript
   { operation: 'connection', isConnected, connectedAt }
   ```
   - Upserts to `steps_connections` table

2. **Daily Steps** (lines 80-105)
   ```typescript
   { operation: 'steps', dateKey, steps, lastSyncAt }
   ```
   - Inserts/updates `steps_daily` table

3. **Claim Reward** (lines 110-143)
   ```typescript
   { operation: 'claim', dateKey, combinedSteps, lpEarned }
   ```
   - Inserts to `steps_rewards` with UNIQUE constraint
   - **Awards LP**: `awardLP(coupleId, lpEarned, 'steps_claim', dateKey)`
   - Returns `{ alreadyClaimed: true }` if duplicate

**GET /api/sync/steps** (lines 151-240)
```typescript
{
  connection: { user, partner },
  today: { user: { steps, lastSync }, partner: { steps, lastSync } },
  yesterday: { user: { steps }, partner: { steps } },
  claim: { ... } | null
}
```

### 1.5 Database Tables

| Table | Purpose |
|-------|---------|
| `steps_daily` | Per-user daily steps (couple_id, user_id, date_key, steps) |
| `steps_connections` | HealthKit connection status |
| `steps_rewards` | Claim records (UNIQUE on couple_id + date_key) |

### 1.6 LP Award

- **Who**: Server (on claim)
- **When**: User clicks claim button
- **Amount**: 15-30 LP (variable based on step count)
- **Idempotency**: UNIQUE constraint prevents double-claim

### 1.7 Sequence Flow

```
User Device:
1. HealthKit reads step count
2. POST /api/sync/steps { operation: 'steps', steps: 5432 }
3. Server updates steps_daily

Partner Polling (60s):
4. GET /api/sync/steps
5. Server returns both users' steps
6. UI shows combined progress

Claim (next day):
7. User taps claim button
8. POST /api/sync/steps { operation: 'claim', lpEarned: 25 }
9. Server: awardLP(coupleId, 25, 'steps_claim', dateKey)
10. Server: UPDATE couples SET total_lp = total_lp + 25
11. Client: fetchAndSyncFromServer() → updates LP counter
```

---

## 2. Linked Crossword Flow

### 2.1 Architecture
- Turn-based: players alternate placing letters
- Server validates against hidden solution
- Branch rotation: casual → romantic → adult

### 2.2 Flutter Service

**`app/lib/services/linked_service.dart`**

Key methods:
- `getOrCreateMatch()` (lines 102-159): POST `/api/sync/linked`
  - Handles cooldown check
  - Returns `LinkedGameState` with match + puzzle
- `pollMatchState()` (lines 162-192): GET `/api/sync/linked/$matchId` (10s)
- `submitTurn()` (lines 241-260): POST `/api/sync/linked/submit`
  - Body: `{ matchId, placements: [{ cellIndex, letter }] }`
- `useHint()` (lines 264-284): POST `/api/sync/linked/hint`

### 2.3 Flutter Screen

**`app/lib/screens/linked_game_screen.dart`**
- Stores draft placements in `_draftPlacements`
- Polls every 10s when NOT user's turn
- On completion: calls `LovePointService.fetchAndSyncFromServer()`

### 2.4 API Routes

**POST /api/sync/linked** - Create/Get Match (lines 269-414)

1. Find couple
2. Get next puzzle (respects branch progression)
3. Check cooldown → returns `{ code: 'COOLDOWN_ACTIVE' }` if active
4. Load puzzle from `data/puzzles/linked/{branch}/{puzzleId}.json`
5. Create match in `linked_matches`:
   - Empty board state `{}`
   - Initial rack: 5 random letters
   - First player per couple preference
6. Return `LinkedGameState` (**NO SOLUTION SENT**)

**POST /api/sync/linked/submit** - Submit Turn (lines 146-407)

1. Transaction: `BEGIN/COMMIT/ROLLBACK`
2. Lock match for update
3. Validate turn ownership
4. Load puzzle **with solution** (for validation only)
5. Validate placements:
   - Letters in rack
   - Match puzzle solution
6. Score: 10 pts/letter + word bonuses
7. **Check completion** (all cells locked):
   - **Award LP**: `awardLP(coupleId, 30, 'linked_complete', matchId)`
   - **Advance branch**: `(completions + 1) % 3`
   - Determine winner by score
8. Generate new rack, switch turns
9. Update match and record move

**Response:**
```typescript
{
  success: true,
  results: [{ cellIndex, correct }],
  pointsEarned: number,
  completedWords: [{ word, cells, bonus }],
  gameComplete: boolean,
  nextRack: string[] | null,
  nextBranch: 0-2 | null  // Only if complete
}
```

### 2.5 Puzzle Data Structure

**Path**: `api/data/puzzles/linked/{branch}/puzzle_XXX.json`

```json
{
  "title": "Puzzle Title",
  "size": { "rows": 9, "cols": 7 },
  "puzzleId": "puzzle_001",
  "clues": {
    "1": { "type": "emoji", "content": "🥂", "arrow": "down", "target_index": 8 }
  },
  "grid": [".", "T", ".", "H", "O", "P", "E", ...],  // Solution (server only)
  "gridnums": [0, 1, 0, 0, 2, ...]
}
```

### 2.6 Database Tables

| Table | Purpose |
|-------|---------|
| `linked_matches` | Match state, board, scores, current turn |
| `linked_moves` | Audit trail of all moves |
| `branch_progression` | Track current branch per couple |

### 2.7 Sequence Flow

```
Start Game:
1. POST /api/sync/linked { localDate }
2. Server: finds/creates match, loads puzzle
3. Response: { match, puzzle (no solution), state }
4. Screen shows crossword grid

User's Turn:
5. User drags letters from rack to cells
6. POST /api/sync/linked/submit { matchId, placements }
7. Server: validates against solution
8. Server: scores (10 pts/letter + word bonuses)
9. If game complete:
   - awardLP(coupleId, 30, 'linked_complete', matchId)
   - Advance branch: casual → romantic → adult
10. Response: { results, pointsEarned, completedWords, gameComplete }

Partner's Turn (Polling):
11. GET /api/sync/linked/$matchId (every 10s)
12. Detect turn change → enable input
```

---

## 3. Word Search Flow

### 3.1 Architecture
- Turn-based: 3 words per turn
- Server validates word positions
- Branch rotation: everyday → passionate → naughty

### 3.2 Flutter Service

**`app/lib/services/word_search_service.dart`**

Key methods:
- `getOrCreateMatch()` (lines 81-128): POST `/api/sync/word-search`
- `pollMatchState()` (lines 131-147): GET `/api/sync/word-search/$matchId` (10s)
- `submitWord()` (lines 157-179): POST `/api/sync/word-search/submit`
  - Body: `{ matchId, word, positions: [{ row, col }] }`
  - Throws `NotYourTurnException` on 403
- `useHint()` (lines 182-195): POST `/api/sync/word-search/hint`

### 3.3 Flutter Screen

**`app/lib/screens/word_search_game_screen.dart`**
- User selects words by dragging across grid
- Tracks selection in `_selectedPositions`
- Polls every 10s during partner's turn
- On completion: calls `LovePointService.fetchAndSyncFromServer()`

### 3.4 API Routes

**POST /api/sync/word-search** - Create/Get Match (lines 166-300+)

1. Find couple
2. Get next puzzle (respects branch progression)
3. Check cooldown
4. Load puzzle from `data/puzzles/word-search/{branch}/ws_XXX.json`
5. Create match in `word_search_matches`:
   - Empty `found_words: []`
   - `words_found_this_turn: 0`
   - Each player gets 3 hints
6. Return `WordSearchGameState` (**grid + word list only, NO positions**)

**POST /api/sync/word-search/submit** - Submit Word (lines 93-344+)

1. Transaction safety
2. Lock match, validate turn (403 if not their turn)
3. Load puzzle **with positions** (for validation)
4. Validate word:
   - Exists in puzzle
   - Not already found
   - Positions match
5. Score: `word.length * 10`
6. Track in `found_words` array
7. **Check turn completion** (3 words):
   - Switch turns
   - Reset `words_found_this_turn`
8. **Check game completion** (12 words):
   - **Award LP**: `awardLP(coupleId, 30, 'word_search_complete', matchId)`
   - **Advance branch**: `(completions + 1) % 3`
   - Winner by **score** (not word count)
9. Update match, record move

**Response:**
```typescript
{
  success: true,
  valid: boolean,
  pointsEarned: number,
  wordsFoundThisTurn: number,
  turnComplete: boolean,
  gameComplete: boolean,
  colorIndex: number,
  nextBranch: 0-2 | null
}
```

### 3.5 Puzzle Data Structure

**Path**: `api/data/puzzles/word-search/{branch}/ws_XXX.json`

```json
{
  "puzzleId": "ws_001",
  "title": "Theme Title",
  "theme": "Theme description",
  "size": { "rows": 10, "cols": 10 },
  "grid": ["A", "B", "C", ...],
  "words": {
    "LOVE": "0,R",      // startIndex,direction (R=right, D=down, etc.)
    "HEART": "10,D"
  }
}
```

### 3.6 Database Tables

| Table | Purpose |
|-------|---------|
| `word_search_matches` | Match state, found_words, scores, hints |
| `word_search_moves` | Audit trail |
| `branch_progression` | Track current branch (activityType='wordSearch') |

### 3.7 Sequence Flow

```
Start Game:
1. POST /api/sync/word-search { localDate }
2. Server: finds/creates match, loads puzzle
3. Response: { match, puzzle (grid + word list only), state }
4. Screen shows word search grid

User Finds Word:
5. User drags across letters
6. POST /api/sync/word-search/submit { matchId, word, positions }
7. Server: validates positions against solution
8. Server: scores (word.length * 10)
9. If 3 words found this turn:
   - Switch turns
10. If 12 total words:
   - awardLP(coupleId, 30, 'word_search_complete', matchId)
   - Advance branch: everyday → passionate → naughty
11. Response: { valid, pointsEarned, turnComplete, gameComplete }

Partner's Turn (Polling):
12. GET /api/sync/word-search/$matchId (every 10s)
13. Detect turn change → enable input
```

---

## 4. Love Points Architecture

### Single Source of Truth
`couples.total_lp` - one atomic value per couple

### Award Utility
**`api/lib/lp/award.ts`**

```typescript
async function awardLP(
  coupleId: string,
  amount: number,
  source: string,
  relatedId?: string
): Promise<AwardLPResult>
```

**Flow:**
1. Check idempotency: `(source, relatedId)` in last 24h
2. If not duplicate: `UPDATE couples SET total_lp = total_lp + $amount`
3. Record transaction for audit
4. Return `{ success, newTotal, awarded, alreadyAwarded }`

### LP Awards by Game

| Game | Amount | Source String | Trigger |
|------|--------|---------------|---------|
| Steps | 15-30 | `steps_claim` | Claim button |
| Linked | 30 | `linked_complete` | All cells locked |
| Word Search | 30 | `word_search_complete` | 12 words found |

### Flutter Sync

After game completion:
1. `LovePointService.fetchAndSyncFromServer()`
2. GET `/api/sync/game/status` → returns `totalLp`
3. `syncTotalLP()` updates Hive, shows banner, triggers callback

---

## 5. Branch Rotation Logic

### Linked Game
```sql
-- On completion
INSERT INTO branch_progression
  (couple_id, activity_type, current_branch, total_completions, max_branches)
VALUES ($1, 'linked', 0, 1, 3)
ON CONFLICT (couple_id, activity_type)
DO UPDATE SET
  total_completions = branch_progression.total_completions + 1,
  current_branch = (branch_progression.total_completions + 1) % 3
```

**Sequence:** casual (0) → romantic (1) → adult (2) → casual (0) → ...

### Word Search
```sql
-- Same pattern with activity_type = 'wordSearch'
```

**Sequence:** everyday (0) → passionate (1) → naughty (2) → everyday (0) → ...

### Default Branch
If no progression record exists: returns first branch (0)

---

## 6. Comparison Table

| Aspect | Steps Together | Linked | Word Search |
|--------|----------------|--------|-------------|
| **Game Type** | Cooperative | Turn-based competitive | Turn-based competitive |
| **Turn Length** | N/A | Until submit | 3 words |
| **Completion** | Manual claim | All cells locked | 12 words found |
| **Scoring** | N/A | 10 pts/letter + word bonus | 10 pts/letter |
| **Winner** | N/A | By score | By score |
| **Hints** | N/A | Vision power-ups | 3 per player |
| **Cooldown** | N/A | Daily (env var) | Daily (env var) |
| **Branch Rotation** | N/A | On completion | On completion |
| **Data Hidden** | N/A | Solution | Word positions |
| **LP Source** | `steps_claim` | `linked_complete` | `word_search_complete` |

---

## 7. File Reference

### Flutter Services

| File | Purpose |
|------|---------|
| `services/steps_sync_service.dart` | Steps HealthKit sync + API |
| `services/steps_health_service.dart` | HealthKit data read |
| `services/linked_service.dart` | Linked match orchestration |
| `services/word_search_service.dart` | Word Search orchestration |

### Flutter Screens

| File | Purpose |
|------|---------|
| `screens/steps_counter_screen.dart` | Steps UI + 60s polling |
| `screens/linked_game_screen.dart` | Linked UI + 10s polling |
| `screens/word_search_game_screen.dart` | Word Search UI + 10s polling |

### API Routes

| Endpoint | File | Purpose |
|----------|------|---------|
| POST/GET `/sync/steps` | `steps/route.ts` | Steps sync, claim |
| POST/GET `/sync/linked` | `linked/route.ts` | Match creation/state |
| POST `/sync/linked/submit` | `linked/submit/route.ts` | Turn + LP |
| POST/GET `/sync/word-search` | `word-search/route.ts` | Match creation/state |
| POST `/sync/word-search/submit` | `word-search/submit/route.ts` | Word + LP |

### Shared Utilities

| File | Purpose |
|------|---------|
| `api/lib/lp/award.ts` | Idempotent LP award |
| `api/lib/lp/config.ts` | LP reward constants |

### Puzzle Data

| Path | Content |
|------|---------|
| `api/data/puzzles/linked/{branch}/` | Linked puzzles with solutions |
| `api/data/puzzles/word-search/{branch}/` | Word search puzzles with positions |

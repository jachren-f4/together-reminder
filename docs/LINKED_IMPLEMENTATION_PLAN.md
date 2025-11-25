# Linked Game Implementation Plan

**Game**: Turn-based arroword (Scandinavian crossword) puzzle for couples
**Storage**: Supabase-only (no Firebase for game state)
**Sync**: 10-second polling (like Memory Flip)
**Display**: Always-active Side Quest card (5 states) + Full game screen (grid, drag & drop, completion)
**Phases**: 13 implementation phases (Card: 1-6, Game Screen: 7-13)
**Status**: Complete Specification - Ready for Full Implementation

---

## 1. Architecture Overview

| Layer | Technology | Pattern |
|-------|------------|---------|
| **Flutter Models** | Hive (typeId 23-25) | Follow `memory_flip.dart` |
| **Flutter Service** | HTTP + AuthService | Follow `memory_flip_service.dart` |
| **Flutter UI** | Stack + InteractiveViewer | Custom grid rendering |
| **API** | Next.js API Routes | Follow `/api/sync/memory-flip/` |
| **Database** | Supabase PostgreSQL | `linked_matches` table |
| **Puzzles** | JSON files on API | `/api/data/puzzles/arroword_test.json` |

---

## 2. Turn Mechanics (Key Difference from Memory Flip)

| Aspect | Memory Flip | Linked |
|--------|-------------|--------|
| Turn trigger | Flip 2 cards | Place letters from 5-letter rack |
| Turn end | After every move | When rack empty OR "READY" pressed |
| Incorrect handling | N/A | Bounces back to rack (retry allowed) |
| Timeout | 5 hours | None |
| New puzzle | Daily | After completion (same puzzle until done) |

**Flow:**
1. Server deals 5 letters from remaining empty cells
2. Player drags letters to grid (draft = yellow)
3. Player presses "READY" to submit
4. Server validates: correct → lock (green), incorrect → bounce back
5. If rack empty → deal new rack, switch turn
6. If rack has letters → same player continues (can press READY to yield)

---

## 3. Database Schema

### Table: `linked_matches`

```sql
CREATE TABLE linked_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,
  puzzle_id TEXT NOT NULL,  -- References JSON file name

  -- Game state
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed')),
  board_state JSONB DEFAULT '{}'::jsonb,  -- {"8": "D", "15": "O"} locked letters
  current_rack TEXT[] DEFAULT '{}',        -- ["A", "B", "C", "D", "E"]

  -- Turn management
  current_turn_user_id UUID REFERENCES auth.users(id),
  turn_number INT DEFAULT 1,

  -- Scoring
  player1_score INT DEFAULT 0,
  player2_score INT DEFAULT 0,

  -- Power-ups
  player1_vision INT DEFAULT 2,
  player2_vision INT DEFAULT 2,

  -- Completion
  locked_cell_count INT DEFAULT 0,
  total_answer_cells INT NOT NULL,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,

  UNIQUE(couple_id, puzzle_id)  -- One match per puzzle per couple
);

CREATE TABLE linked_moves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID REFERENCES linked_matches(id) ON DELETE CASCADE,
  player_id UUID REFERENCES auth.users(id),
  placements JSONB NOT NULL,  -- [{"index": 8, "char": "D", "correct": true}]
  points_earned INT NOT NULL,
  words_completed JSONB DEFAULT '[]',
  turn_number INT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 4. API Endpoints

### POST `/api/sync/linked` - Start/Get Match
- Returns existing active match OR creates new one
- Loads puzzle from JSON file
- Uses `CouplePreferencesService.getFirstPlayerId()` for first player
- **Response excludes `grid` (solution)** - only sends `gridnums` and `clues`

### GET `/api/sync/linked/[matchId]` - Poll State
- Returns current board state, rack, scores, turn info
- Used for 10s polling

### POST `/api/sync/linked/submit` - Submit Turn
- Validates placements against solution (server-side)
- Returns results: `[{index, char, correct}, ...]`
- Calculates word completion bonuses
- Deals new rack if current rack depleted
- Switches turn if rack empty

### POST `/api/sync/linked/vision` - Use Power-up
- Returns valid indices for current rack letters
- Decrements vision count

---

## 5. Scoring Rules

| Action | Points |
|--------|--------|
| Correct letter | +10 |
| Incorrect letter | 0 (bounces back) |
| Word completion | +(word_length × 10) bonus |

---

## 6. Flutter File Structure

```
app/lib/
├── models/
│   ├── linked.dart           # LinkedMatch, LinkedPuzzle (Hive)
│   └── linked.g.dart         # Generated
├── services/
│   └── linked_service.dart   # API calls, GameState
├── screens/
│   ├── linked_intro_screen.dart
│   └── linked_game_screen.dart
└── widgets/
    └── linked/
        ├── linked_grid.dart       # Stack-based grid
        ├── clue_cell.dart         # Colored cell with arrow
        ├── answer_cell.dart       # DragTarget, states
        ├── rack_widget.dart       # Draggable tiles
        ├── active_clue_banner.dart
        ├── scoreboard.dart
        └── arrow_painter.dart
```

---

## 7. Grid Rendering Architecture

**Widget hierarchy:**
```
LinkedGameScreen
└── Column
    ├── ActiveClueBanner (shows clues for selected cell)
    ├── Expanded: InteractiveViewer (zoom/pan)
    │   └── LinkedGrid (Stack)
    │       ├── Positioned ClueCell widgets (colored, with arrow)
    │       └── Positioned AnswerCell widgets (DragTarget)
    └── BottomHUD
        ├── RackWidget (Draggable tiles)
        └── ActionBar (Shuffle, Vision, Ready)
```

**Cell rendering logic:**
```dart
if (gridnums[index] > 0) → ClueCell (look up clues[gridnums[index]])
else if (grid[index] != ".") → AnswerCell (playable)
else → SizedBox.shrink() (void)
```

---

## 8. Puzzle JSON Format

Location: `docs/arroword_test.json`

```json
{
  "size": { "rows": 9, "cols": 7 },
  "grid": [".", ".", ".", "D", "R", "I", "P", ...],  // Solution (63 chars)
  "gridnums": [0, 1, 2, 0, 3, 0, 4, ...],            // Clue references
  "clues": {
    "1": { "type": "text", "content": "Clue text", "arrow": "down", "target_index": 8 }
  }
}
```

---

## 9. Key Algorithms

### Rack Generation
```typescript
function generateRack(grid, boardState, gridnums): string[] {
  const available = [];
  for (let i = 0; i < grid.length; i++) {
    if (gridnums[i] > 0 || grid[i] === '.') continue;  // Skip clue/void
    if (boardState[i]) continue;                        // Skip locked
    available.push(grid[i].toUpperCase());
  }
  return shuffle(available).slice(0, 5);
}
```

### Word Completion Detection
```typescript
function detectCompletedWords(newBoard, oldBoard, clues): CompletedWord[] {
  const completed = [];
  for (const [clueId, clue] of Object.entries(clues)) {
    const wordCells = getWordCells(clue.target_index, clue.arrow);
    const wasComplete = wordCells.every(i => oldBoard[i]);
    const isNowComplete = wordCells.every(i => newBoard[i]);
    if (isNowComplete && !wasComplete) {
      completed.push({ clueId, length: wordCells.length, bonus: wordCells.length * 10 });
    }
  }
  return completed;
}
```

### Parent Clue Lookup (for Active Banner)
```typescript
function findParentClues(index, gridnums, clues, cols): { across?, down? } {
  // Scan left for "across" clue, scan up for "down" clue
}
```

---

## 10. Anti-Cheat Measures

1. **Solution never sent to client** - API returns `gridnums` and `clues`, not `grid`
2. **Server-side validation** - All letter placements validated against solution
3. **Rack validation** - Server verifies placed letters were in dealt rack
4. **Transaction locking** - `FOR UPDATE` prevents race conditions
5. **Move audit table** - All moves recorded for replay/forensics

---

## 11. Critical Files to Read Before Implementation

| File | Purpose |
|------|---------|
| `api/app/api/sync/memory-flip/route.ts` | API pattern for start/get match |
| `api/app/api/sync/memory-flip/move/route.ts` | Transaction pattern for moves |
| `app/lib/services/memory_flip_service.dart` | Service pattern with GameState |
| `app/lib/screens/memory_flip_game_screen.dart` | Screen with polling, turn UI |
| `app/lib/models/memory_flip.dart` | Hive model pattern |
| `app/lib/services/couple_preferences_service.dart` | First player lookup |
| `api/lib/auth/dev-middleware.ts` | Auth middleware pattern |

---

## 12. Side Quest Card Implementation Tasks

### Phase 1: Data Layer (Dependencies: Section 3 - Database)
- [ ] Update Hive model `linked.dart` to include all fields needed for card states
  - [ ] `matchId`, `puzzleId`, `status`
  - [ ] `currentTurnUserId`, `lockedCellCount`, `totalAnswerCells`
  - [ ] `player1Score`, `player2Score`
  - [ ] `currentRack` (array of strings)
  - [ ] `completedAt`, `nextPuzzleAvailableAt`
- [ ] Add `LinkedCardState` enum (YourTurnFresh, PartnerTurnFresh, YourTurnInProgress, PartnerTurnInProgress, Completed)
- [ ] Generate Hive adapters: `flutter pub run build_runner build`

### Phase 2: Service Layer (Dependencies: Phase 1)
- [ ] Add card-specific methods to `linked_service.dart`:
  - [ ] `getCardState()` - Determines which of 5 states to display
  - [ ] `getProgressPercentage()` - Calculates `locked_cell_count / total_answer_cells * 100`
  - [ ] `getRackCount()` - Returns `current_rack.length`
  - [ ] `getNextPuzzleCountdown()` - Formats time remaining as "Xh Ym"
- [ ] Add polling mechanism (10-second intervals, same as `memory_flip_service.dart`)
  - [ ] `startPolling()` - Calls `GET /api/sync/linked/[matchId]` every 10s
  - [ ] `stopPolling()` - Cleanup when card not visible
  - [ ] State change callbacks for card updates

### Phase 3: UI Components (Dependencies: Phase 2)
- [ ] Create `app/lib/widgets/linked_card.dart` (main card widget)
  - [ ] Stateful widget with polling lifecycle
  - [ ] Call `startPolling()` in `initState()`, `stopPolling()` in `dispose()`
  - [ ] Build method switches on `CardState` enum
- [ ] Create `app/lib/widgets/linked/` subdirectory for card components:
  - [ ] `progress_ring.dart` - White circle overlay with percentage (top-right)
  - [ ] `partner_badge.dart` - Circle with partner initial + name text
  - [ ] `completion_badge.dart` - Checkmark badge (inverted colors)
  - [ ] `score_row.dart` - "You: 240" vs "Partner: 280" layout
  - [ ] `countdown_timer.dart` - Formats and displays "Next puzzle in Xh Ym"

### Phase 4: Card State Renderers (Dependencies: Phase 3)
- [ ] Implement 5 card state builders in `linked_card.dart`:
  - [ ] `_buildYourTurnFresh()` - 2px border, "Your Turn" badge, "Start the puzzle"
  - [ ] `_buildPartnerTurnFresh()` - 1px border, Partner badge, "Waiting for {partner}"
  - [ ] `_buildYourTurnInProgress()` - 2px border, progress ring, "{N} letters in rack", scores
  - [ ] `_buildPartnerTurnInProgress()` - 1px border, partner badge, "Waiting...", scores
  - [ ] `_buildCompleted()` - 1px border, checkmark badge, countdown, final scores

### Phase 5: Integration (Dependencies: Phase 4)
- [ ] Add to Side Quests carousel in `new_home_screen.dart`:
  - [ ] Insert `LinkedCard()` widget after daily quests section
  - [ ] Ensure 60% peek carousel behavior
  - [ ] Add to carousel item list
- [ ] Add tap handlers:
  - [ ] Your turn → Navigate to `LinkedGameScreen`
  - [ ] Partner's turn → Navigate to `LinkedGameScreen` (read-only mode)
  - [ ] Completed → Navigate to completed puzzle review
- [ ] Test all state transitions:
  - [ ] Fresh → In Progress (after first move)
  - [ ] Your Turn ↔ Partner's Turn (turn switching)
  - [ ] In Progress → Completed (puzzle finished)
  - [ ] Completed → Fresh (new puzzle assigned)

### Phase 6: Visual Polish (Dependencies: Phase 5)
- [ ] Verify border thickness signaling (2px action / 1px passive)
- [ ] Verify badge styling (white/gray/inverted backgrounds)
- [ ] Verify progressive disclosure (fresh = no scores, in-progress = scores)
- [ ] Test polling updates (should update within 10 seconds of state change)
- [ ] Add card image: `/assets/raw_images/cropped/Connection Basics.png`
- [ ] Test accessibility (screen reader announces state changes)

---

## 13. Game Screen Implementation Tasks

These phases build the actual gameplay screen (accessed by tapping the card). Implement AFTER Phase 6 (Card Visual Polish) is complete.

### Phase 7: Grid Rendering System (Dependencies: Phase 1-2)
- [ ] Create `app/lib/widgets/linked/linked_grid.dart`
  - [ ] `Stack` widget for absolute positioning
  - [ ] Calculate cell positions: `(row, col) → (x, y)` pixels
  - [ ] Grid dimensions: 7 cols × 9 rows = 63 cells
  - [ ] Cell size calculation based on screen width
- [ ] Create `app/lib/widgets/linked/clue_cell.dart`
  - [ ] Gray background (#E8E8E8)
  - [ ] Abbreviated clue text (Arial, 8px, weight 800)
  - [ ] Arrow indicator: ▼ (down) or ▶ (across) at cell edge
  - [ ] Position arrow based on `clues[clueId].arrow` direction
- [ ] Create `app/lib/widgets/linked/answer_cell.dart`
  - [ ] Three states: Empty (white), Draft (yellow), Locked (green)
  - [ ] `DragTarget<String>` for letter drops
  - [ ] Letter display (Georgia, 22px, weight 700)
  - [ ] 2px black border
- [ ] Create `app/lib/widgets/linked/void_cell.dart`
  - [ ] Black background (#222222)
  - [ ] Non-interactive `Container`
- [ ] Implement cell rendering logic in `linked_grid.dart`:
  ```dart
  if (gridnums[index] > 0) → ClueCell(clues[gridnums[index]])
  else if (grid[index] != ".") → AnswerCell(...)
  else → VoidCell()
  ```

### Phase 8: Drag & Drop System (Dependencies: Phase 7)
- [ ] Create `app/lib/widgets/linked/rack_widget.dart`
  - [ ] 5 fixed tile slots (42×42px each, 8px gap)
  - [ ] `Draggable<String>` for each letter tile
  - [ ] Empty slot: Gray background, dashed border
  - [ ] Filled tile: Yellow background, 2px black border
  - [ ] Letter text: Georgia, 20px, weight 700
- [ ] Implement drag state management in `linked_game_screen.dart`:
  - [ ] `Map<int, PlacedLetter> draftPlacements` - Track placements
  - [ ] `List<String?> currentRack` - Current rack state
  - [ ] `onAccept()` handler for AnswerCell DragTarget
  - [ ] `onDragStarted()` for visual feedback (50% opacity)
- [ ] Implement three drag operations:
  - [ ] **Rack → Grid**: Remove from rack, add to `draftPlacements`
  - [ ] **Grid → Grid**: Move between cells in `draftPlacements`
  - [ ] **Grid → Rack**: Remove from `draftPlacements`, return to rack
- [ ] Add visual feedback:
  - [ ] Valid drop target: Blue background (#E3F2FD), blue border
  - [ ] Invalid drop target: No highlight
  - [ ] Draft placement: Yellow with pulse animation (0.9s loop)

### Phase 9: Turn Submission & Validation (Dependencies: Phase 8)
- [ ] Create `app/lib/widgets/linked/action_bar.dart`
  - [ ] "Submit Turn" button (disabled if no placements)
  - [ ] "💡 Hint (2)" button (shows remaining count)
  - [ ] "Shuffle Rack" button (optional)
- [ ] Implement submission flow in `linked_service.dart`:
  - [ ] `submitTurn(matchId, placements)` method
  - [ ] POST to `/api/sync/linked/submit`
  - [ ] Request: `[{ cellIndex, letter }, ...]`
  - [ ] Response: `{ results: [{cellIndex, correct}], pointsEarned, completedWords, newScore }`
- [ ] Implement validation animations in `linked_game_screen.dart`:
  - [ ] **Correct letter**: Green flash → scale 1.1x → lock in place → change to green background
  - [ ] **Incorrect letter**: Shake left-right 4x → bounce back to rack → remove from grid
  - [ ] **Word complete**: All word cells pulse green → scale 1.15x → show bonus points
- [ ] Update local state after submission:
  - [ ] Merge correct placements into `lockedCells`
  - [ ] Return incorrect letters to rack
  - [ ] Update scores with animation
  - [ ] Clear `draftPlacements`
  - [ ] Switch turn indicator

### Phase 10: Hint Power-Up & Scoring (Dependencies: Phase 9)
- [ ] Implement hint functionality in `linked_service.dart`:
  - [ ] `useHint(matchId)` method
  - [ ] POST to `/api/sync/linked/hint`
  - [ ] Response: `{ validCells: number[], hintsRemaining: number }`
- [ ] Add hint visual effect in `linked_game_screen.dart`:
  - [ ] Highlight valid cells with blue glow (2-second animation)
  - [ ] Use `AnimatedContainer` with `BoxShadow` for glow
  - [ ] Decrement hint counter in UI
- [ ] Create `app/lib/widgets/linked/scoreboard.dart`
  - [ ] Display both players' scores
  - [ ] "You: 180" and "Partner: 280" layout
  - [ ] Active player indicator: Green dot or highlight
  - [ ] Score bump animation when points earned (scale 1.2x)
- [ ] Implement scoring logic:
  - [ ] +10 points per correct letter
  - [ ] +(word_length × 10) bonus per completed word
  - [ ] Show floating "+50" text at score when points earned

### Phase 11: Completion Screen (Dependencies: Phase 10)
- [ ] Create `app/lib/screens/linked_completion_screen.dart`
  - [ ] Full-screen overlay with black background (80% opacity)
  - [ ] Confetti animation: 50 black/gray particles falling, rotating
  - [ ] Circular checkmark badge (pop animation on entry)
  - [ ] "COMPLETE" title (24px, weight 700)
  - [ ] "Puzzle Finished" subtitle (14px, gray)
- [ ] Add final scores display:
  - [ ] Winner box: Black background, white text, larger size
  - [ ] Loser box: White background, black text, smaller size
  - [ ] Score values displayed prominently
- [ ] Add stats section:
  - [ ] Words completed (count from completed words array)
  - [ ] Total turns (from match data)
  - [ ] Time elapsed (calculate from `started_at` → `completed_at`)
- [ ] Implement completion trigger in `linked_game_screen.dart`:
  - [ ] Check if `lockedCellCount === totalAnswerCells` after submission
  - [ ] If true: Navigate to `LinkedCompletionScreen`
  - [ ] Pass final match data (scores, stats, winner)
- [ ] Add "Back to Home" button:
  - [ ] Pops to home screen
  - [ ] Updates card state to "Completed"
- [ ] Implement Love Points award:
  - [ ] Server awards +30 LP on completion (one-time)
  - [ ] Show "+30 LP" notification when returning to home

### Phase 12: Polling & Partner View (Dependencies: Phase 11)
- [ ] Implement polling in `linked_game_screen.dart`:
  - [ ] Start 10-second timer when it's partner's turn
  - [ ] Call `GET /api/sync/linked/[matchId]` every 10s
  - [ ] Stop polling when it becomes your turn
  - [ ] Stop polling when game completes
- [ ] Handle state updates from polling:
  - [ ] Update `lockedCells` (partner's correct placements appear)
  - [ ] Update scores (partner's points appear)
  - [ ] Update turn indicator ("Your Turn" vs "Partner's Turn")
  - [ ] Generate new rack when turn switches to you
- [ ] Create "Partner's Turn" UI state:
  - [ ] Disable all interactions (no drag & drop)
  - [ ] Show "Waiting for {partner}'s move" message
  - [ ] Display partner's avatar with pulsing indicator
  - [ ] Show current scores
  - [ ] Grid is read-only but shows all locked cells
- [ ] Implement optimistic updates:
  - [ ] Your moves update UI immediately (don't wait for polling)
  - [ ] Server response confirms or corrects

### Phase 13: Integration & Testing (Dependencies: Phase 12)
- [ ] Add Linked to Activities screen:
  - [ ] Create "Linked" game card
  - [ ] Tap handler: Navigate to `LinkedGameScreen`
  - [ ] Show "Active" badge if match exists
- [ ] Wire up card tap navigation in `linked_card.dart`:
  - [ ] Your turn (fresh/in-progress) → `LinkedGameScreen` (editable)
  - [ ] Partner's turn → `LinkedGameScreen` (read-only)
  - [ ] Completed → `LinkedCompletionScreen`
- [ ] Create API integration test (`app/test/linked_game_integration_test.dart`):
  - [ ] Test: Create match, get initial rack
  - [ ] Test: Submit valid placements, verify locked
  - [ ] Test: Submit invalid placements, verify bounce back
  - [ ] Test: Complete word, verify bonus points
  - [ ] Test: Use hint, verify valid cells returned
  - [ ] Test: Complete puzzle, verify +30 LP awarded
- [ ] Create shell script test (`api/scripts/test_linked_game.sh`):
  - [ ] Test full turn cycle (Alice submits → Bob polls → Bob's turn)
  - [ ] Test hint endpoint
  - [ ] Test completion trigger
- [ ] Manual testing checklist:
  - [ ] Drag letter from rack to grid → appears yellow
  - [ ] Submit turn → correct letters turn green, incorrect shake
  - [ ] Complete word → all word cells pulse, bonus shown
  - [ ] Partner's turn → grid updates on poll, can't interact
  - [ ] Use hint → valid cells glow blue
  - [ ] Complete puzzle → confetti screen appears, +30 LP awarded

---

## 14. PRD Reference

Full PRD: `docs/Linked_PRD.md`
Full UI Card Spec: `mockups/crossword/CROSSWORD_CARD_UI_SPEC.md`
Full Gameplay Spec: `docs/LINKED_GAME_DETAILED_SPEC.md`

---

**Created**: 2025-11-25
**Last Updated**: 2025-11-25 (Added Game Screen Implementation - Phases 7-13)

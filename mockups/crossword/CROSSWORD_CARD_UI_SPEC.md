# Crossword Card UI Specification

**Feature:** Crossword puzzle side quest card in carousel
**Location:** Side Quests section (60% peek carousel)
**Reward:** Fixed +30 Love Points per completed puzzle
**Last Updated:** 2025-11-25

---

## Overview

The Crossword card displays in the Side Quests carousel and represents an always-active, turn-based word puzzle that couples solve together. Unlike daily quests, there is **always an active crossword puzzle** assigned to one partner or the other. The card updates in real-time based on game state and whose turn it is.

### Key Principles

1. **Always Active:** No "available" state - puzzle is always assigned to someone
2. **Turn-Based:** Clear visual distinction between "Your Turn" and "Partner's Turn"
3. **Progressive Disclosure:** Fresh puzzles show minimal info, in-progress puzzles show scores/progress
4. **Fixed Reward:** Always +30 Love Points (displayed on all states)
5. **Black & White Only:** No colors, maintains app's monochrome aesthetic
6. **100% Opacity:** All states at full opacity, visual hierarchy through borders/badges

---

## Card States

### 1. Your Turn (Fresh Puzzle)

**File:** `01-your-turn-fresh.html`

**Condition:**
```
puzzle.status === 'active'
AND puzzle.current_turn_user_id === currentUser.id
AND puzzle.locked_cell_count === 0
```

**Visual Elements:**
- Image: Connection Basics.png (black & white)
- Border: **2px solid black** (thick border = action required)
- Badge: "Your Turn" (white background, black text, black border)
- Title: "Crossword"
- Description: "Start the puzzle"
- Reward: "+30"
- No progress indicator
- No scores displayed

**User Action:** Tap to open game screen and begin placing letters

**Backend Data Required:**
```typescript
{
  matchId: string,
  puzzleId: string,
  currentTurnUserId: string,
  status: 'active',
  lockedCellCount: 0,
  totalAnswerCells: number
}
```

---

### 2. Partner's Turn (Fresh Puzzle)

**File:** `02-partner-turn-fresh.html`

**Condition:**
```
puzzle.status === 'active'
AND puzzle.current_turn_user_id === partnerId
AND puzzle.locked_cell_count === 0
```

**Visual Elements:**
- Image: Connection Basics.png (black & white)
- Border: **1px solid black** (thin border = waiting state)
- Badge: Partner's initial in circle + "Taija's Turn" (gray background, gray text, black border)
- Title: "Crossword"
- Description: "Waiting for Taija to start"
- Reward: "+30"
- No progress indicator
- No scores displayed

**User Action:** Tap to view empty puzzle board (read-only)

**Backend Data Required:**
```typescript
{
  matchId: string,
  puzzleId: string,
  currentTurnUserId: string,
  partnerName: string,
  partnerInitial: string,
  status: 'active',
  lockedCellCount: 0,
  totalAnswerCells: number
}
```

---

### 3. Your Turn (In Progress)

**File:** `03-your-turn-in-progress.html`

**Condition:**
```
puzzle.status === 'active'
AND puzzle.current_turn_user_id === currentUser.id
AND puzzle.locked_cell_count > 0
```

**Visual Elements:**
- Image: Connection Basics.png with overlay
- Progress Ring: White circle (top-right) showing completion % (e.g., "42%")
- Border: **2px solid black** (thick border = action required)
- Badge: "Your Turn" (white background, black text)
- Title: "Crossword"
- Description: "5 letters in your rack" (dynamic count)
- Reward: "+30"
- Score Row: Current scores for both players
  - "You: 240"
  - "Taija: 280"
  - Gray background box with light border

**User Action:** Tap to continue game and place letters from rack

**Backend Data Required:**
```typescript
{
  matchId: string,
  currentTurnUserId: string,
  currentRack: string[], // e.g., ["A", "B", "C", "D", "E"]
  lockedCellCount: number,
  totalAnswerCells: number,
  player1Score: number,
  player2Score: number,
  status: 'active'
}
```

**Dynamic Elements:**
- Progress %: `Math.round((lockedCellCount / totalAnswerCells) * 100)`
- Rack count: `currentRack.length` (e.g., "5 letters in your rack")
- Scores: Show current player's score vs partner's score

---

### 4. Partner's Turn (In Progress)

**File:** `04-partner-turn-in-progress.html`

**Condition:**
```
puzzle.status === 'active'
AND puzzle.current_turn_user_id === partnerId
AND puzzle.locked_cell_count > 0
```

**Visual Elements:**
- Image: Connection Basics.png with overlay
- Progress Ring: White circle (top-right) showing completion % (e.g., "42%")
- Border: **1px solid black** (thin border = waiting state)
- Badge: Partner's initial + "Taija's Turn" (gray background, gray text)
- Title: "Crossword"
- Description: "Waiting for Taija's move"
- Reward: "+30"
- Score Row: Current scores for both players
  - "You: 240"
  - "Taija: 280"

**User Action:** Tap to view current puzzle state (read-only, cannot place letters)

**Backend Data Required:**
```typescript
{
  matchId: string,
  currentTurnUserId: string,
  partnerName: string,
  partnerInitial: string,
  lockedCellCount: number,
  totalAnswerCells: number,
  player1Score: number,
  player2Score: number,
  status: 'active'
}
```

---

### 5. Completed

**File:** `05-completed.html`

**Condition:**
```
puzzle.status === 'completed'
OR puzzle.locked_cell_count === puzzle.total_answer_cells
```

**Visual Elements:**
- Image: Connection Basics.png with overlay
- Completion Badge: White circle (top-right) with checkmark "✓"
- Border: **1px solid black** (thin border = no action required)
- Badge: "✓ Completed" (black background, white text - inverted)
- Title: "Crossword"
- Description: "Next puzzle in 8h 24m" (dynamic countdown)
- Reward: "+30"
- Score Row: **Final** scores for both players
  - "You: 240"
  - "Taija: 280"

**User Action:** Tap to review completed puzzle

**Backend Data Required:**
```typescript
{
  matchId: string,
  status: 'completed',
  completedAt: Date,
  nextPuzzleAvailableAt: Date,
  player1Score: number,
  player2Score: number
}
```

**Dynamic Elements:**
- Next puzzle countdown: Calculate `nextPuzzleAvailableAt - now`
- Format: "Xh Ym" (e.g., "8h 24m", "23h 45m", "59m")
- If < 1 hour: Show minutes only (e.g., "45m")
- If > 24 hours: Show days (e.g., "2d 3h")

---

## Visual Hierarchy Rules

### Border Thickness as Signaling
- **2px border:** Action required (your turn) - draws attention
- **1px border:** Passive state (partner's turn or completed) - less prominent

### Badge Styling
- **"Your Turn":** White background, black text, black border (clean, actionable)
- **"Partner's Turn":** Gray background (#f0f0f0), gray text (#666), includes partner initial in black circle
- **"Completed":** Black background, white text (inverted to signal finality)

### Progress Indicators
- **Fresh puzzles:** No progress ring, no scores
- **In progress:** Progress ring (top-right), scores displayed
- **Completed:** Checkmark badge (top-right), final scores

---

## State Transitions

```
[New Puzzle Assigned to User]
    ↓
State 1: Your Turn (Fresh)
    ↓ [User makes first move]
State 3: Your Turn (In Progress)
    ↓ [User completes turn]
State 4: Partner's Turn (In Progress)
    ↓ [Partner completes turn]
State 3: Your Turn (In Progress)
    ↓ [Repeat until puzzle complete]
State 5: Completed
    ↓ [Cooldown period expires]
[New Puzzle Assigned] → State 1 or State 2
```

```
[New Puzzle Assigned to Partner]
    ↓
State 2: Partner's Turn (Fresh)
    ↓ [Partner makes first move]
State 4: Partner's Turn (In Progress)
    ↓ [Partner completes turn]
State 3: Your Turn (In Progress)
    ↓ [Continue alternating turns...]
State 5: Completed
```

---

## Polling & Real-Time Updates

The card should poll for updates every **10 seconds** (consistent with Memory Flip pattern).

**What to poll:**
- `current_turn_user_id` - Detect turn changes
- `locked_cell_count` - Update progress %
- `player1_score` / `player2_score` - Update scores
- `status` - Detect completion
- `current_rack` - Update rack count (if user's turn)

**When to transition states:**
- If `current_turn_user_id` changes → Switch between State 3 ↔ State 4
- If `locked_cell_count` changes from 0 → >0 → Switch from State 1/2 to State 3/4
- If `status` becomes 'completed' → Switch to State 5

---

## Edge Cases

### 1. First-Time User (Never Played Crossword)
**Behavior:** Show State 1 or State 2 depending on who puzzle is assigned to
**Note:** Assignment uses `CouplePreferencesService.getFirstPlayerId()` to determine initial player

### 2. Partner Never Started
**Behavior:** Remain in State 2 indefinitely
**Consideration:** Could add a "nudge partner" action after 24 hours

### 3. Puzzle Completed But Next Not Yet Available
**Behavior:** State 5 with countdown timer
**Display:** "Next puzzle in Xh Ym"

### 4. Network Error During Poll
**Behavior:** Keep showing last known state
**Visual:** No error shown on card (handle at app level)

### 5. Mid-Turn (Letters in Rack But Not Submitted)
**Behavior:** State 3 continues to show
**Description:** "5 letters in your rack" (or however many remain)

---

## Accessibility

### Text Alternatives
- Progress ring: Announce "42% complete"
- Partner badge: Announce "Taija's turn"
- Completion badge: Announce "Puzzle completed"

### Touch Targets
- Entire card is tappable (minimum 60% of carousel width)
- No small interactive elements within card

### Color Contrast
- Black text on white: WCAG AAA
- White text on black badge: WCAG AAA
- Gray text on gray background: Should meet WCAG AA minimum

---

## Implementation Checklist

### Flutter Models Required
- [ ] `CrosswordMatch` (Hive typeId, similar to `MemoryPuzzle`)
- [ ] `CrosswordPuzzle` (metadata only - solution stays on server)
- [ ] Fields: `matchId`, `puzzleId`, `currentTurnUserId`, `lockedCellCount`, `totalAnswerCells`, `player1Score`, `player2Score`, `currentRack`, `status`, `completedAt`, `nextPuzzleAvailableAt`

### Service Layer
- [ ] `CrosswordService` following `memory_flip_service.dart` pattern
- [ ] Polling mechanism (10-second intervals)
- [ ] State management with `GameState` enum
- [ ] API calls: `GET /api/sync/linked/[matchId]`

### UI Components
- [ ] `CrosswordCard` widget (stateful, handles polling)
- [ ] Progress ring overlay (conditional rendering)
- [ ] Partner initial badge component (reusable)
- [ ] Score row component
- [ ] Countdown timer formatter (for "Next puzzle in..." text)

### API Endpoints
- [ ] `GET /api/sync/linked/[matchId]` - Poll current state
- [ ] Returns all data needed for card states
- [ ] Does NOT include puzzle solution (anti-cheat)

---

## Design Assets

**Image:** `/assets/raw_images/cropped/Connection Basics.png`
- Black and white illustration
- Copied to `/mockups/crossword/Connection Basics.png` for mockups

**Typography:**
- Title: 16px, weight 600, "Crossword"
- Description: 12px, italic, color #666
- Reward: 14px, weight 700, "+30"
- Badge: 11px, weight 600, uppercase, 0.5px letter-spacing
- Scores: 18px, weight 700 (values), 10px uppercase (labels)

**Spacing:**
- Card padding: 16px
- Section gaps: 12px (between header and scores)
- Score row padding: 8px
- Badge padding: 6px 12px

---

## References

### HTML Mockups
1. `mockups/crossword/01-your-turn-fresh.html`
2. `mockups/crossword/02-partner-turn-fresh.html`
3. `mockups/crossword/03-your-turn-in-progress.html`
4. `mockups/crossword/04-partner-turn-in-progress.html`
5. `mockups/crossword/05-completed.html`

### Related Documentation
- Implementation Plan: `docs/LINKED_IMPLEMENTATION_PLAN.md`
- PRD: `docs/Linked_PRD.md`
- Similar Pattern: Memory Flip game (`app/lib/services/memory_flip_service.dart`)

### Architecture Patterns to Follow
- Service: `app/lib/services/memory_flip_service.dart` (polling, state management)
- API: `api/app/api/sync/memory-flip/route.ts` (match state endpoint)
- Models: `app/lib/models/memory_flip.dart` (Hive patterns)

---

**Created:** 2025-11-25
**Status:** UI Specification Complete - Ready for Implementation

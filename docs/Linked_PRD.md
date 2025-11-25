Here is the definitive **Product Requirements Document (PRD)** for the "Linked" game module.

You can save this file as `Linked_PRD.md` and share it with your coding agent or development team. It aligns perfectly with your specific JSON structure and Supabase/Flutter architecture.

***

# Product Requirements Document: "Linked" (TogetherRemind)

**Version:** 5.0 (Complete Specification: Card + Game Screen + Gameplay)
**Date:** November 25, 2025
**Target Platform:** Flutter (Mobile Client)
**Backend:** Supabase (PostgreSQL + Edge Functions)
**Input Format:** Custom Extended Arroword JSON

---

## 1. Executive Summary

**Linked** is a turn-based, tactical word game for couples embedded within the **TogetherRemind** app.
*   **The Format:** Picture/Text Arroword (Scandinavian Crossword). Clues are embedded inside the grid cells.
*   **The Core Loop:** Partners take turns placing 5 letters from a generated "rack" onto a shared grid.
*   **The Difficulty:** "Hard Mode". Validation only occurs upon submission. Incorrect letters bounce back.
*   **The Goal:** Cooperate to solve the puzzle, but compete for the highest score by tactically completing words ("Sniping").

---

## 2. Data Specification (The JSON Engine)

The system relies on parsing a specific JSON structure (e.g., `quality-arroword_test.json`). The frontend must use a **Layered Logic** approach to render the grid.

### 2.1 Grid Topology & Coordinates
The input is a flattened 1D array.
*   **Mapping:** `index = (y * cols) + x`.
*   **L-Frame Constraint:**
    *   **Row 0 ($y=0$)** is reserved for Down Clues.
    *   **Col 0 ($x=0$)** is reserved for Across Clues.
    *   **Cell (0,0)** is always Void.
    *   *Implication:* Answers can only exist where $x \ge 1$ and $y \ge 1$.

### 2.2 The Two-Layer Rendering Logic
To determine what to draw at any given `index`:

**Layer 1: The UI Type (`gridnums` array)**
*   Checks **"Is this a Clue Box?"**
*   If `gridnums[index] > 0`:
    *   This is a **CLUE CELL**.
    *   **Action:** Render a colored box. Look up content in `clues[gridnums[index]]`.
    *   **Visuals:** Display text/image and an arrow pointing in `clues[...].arrow` direction.
*   If `gridnums[index] == 0`:
    *   Proceed to Layer 2.

**Layer 2: The Logic Type (`grid` array)**
*   Checks **"Is this a Playable Box?"**
*   If `grid[index] == "."`:
    *   This is a **VOID/EMPTY CELL**. (Non-interactive).
*   If `grid[index] != "."`:
    *   This is an **ANSWER CELL**.
    *   **Action:** Render a White Box (Input Field).
    *   **Validation:** The correct letter is the character found at `grid[index]`.

---

## 3. Game Mechanics

### 3.1 Turn Start: The Deal
*   **Server-Side Logic (Edge Function):**
    1.  Fetch current `board_state` (letters locked in).
    2.  Scan the `grid` array for **Empty Answer Cells**.
    3.  **Constraint:** Ignore any index where $x=0$ or $y=0$.
    4.  **Selection:** Randomly pick 5 letters from the valid empty spots.
    5.  **Result:** Update `matches.current_rack`.

### 3.2 Gameplay: Drafting (Hard Mode)
*   **Interaction:** Drag-and-drop tiles from Rack to Grid.
*   **State:** Dropped tiles appear **Yellow (Draft)**.
*   **Constraint:** No validation occurs. User can place "Z" where "A" belongs.
*   **Restriction:** Tiles can only be dropped on **White Answer Cells** that are currently empty.

### 3.3 Turn End: Submission & Scoring
*   **User Action:** Tap "READY".
*   **Server Logic:**
    1.  **Validation:** Compare placed letters against `grid` solution.
        *   *Correct:* Lock letter (**Green**). Award **10 points**.
        *   *Incorrect:* Reject letter (Bounce back to rack/pool). Award **0 points**.
    2.  **Word Completion Bonus:**
        *   Check `clues` definitions. For every word affected by this move:
        *   If all cells from `target_index` to end-of-word are now filled:
        *   Award Bonus: **(Word Length × 10) points**.
    3.  **Win Condition:** If total locked cells == total answer cells, mark Match as Completed.

### 3.4 Power-Up: "Vision"
*   **Inventory:** 2 per player per match.
*   **Action:** Highlights valid targets.
*   **Logic:**
    1.  Take current rack letters (e.g., A, B).
    2.  Scan grid for empty spots where Solution is A or B.
    3.  Apply "Pulse Animation" to those cells for 5 seconds.

---

## 4. User Interface (UI) Specification

### 4.1 The Grid (Arroword Style)
*   **Clue Cells:**
    *   Background: Pastel Brand Color.
    *   Text: Condensed font (Roboto Condensed), centered.
    *   Arrow: CSS/Canvas triangle on the border pointing towards the answer.
*   **Answer Cells:**
    *   Empty: White background, thin border.
    *   Draft: Yellow background.
    *   Locked: Green background.

### 4.2 The Active Clue Banner (Accessibility Requirement)
Since Clue Cells are small, reading them can be hard.
*   **Trigger:** When user taps an Answer Cell.
*   **Action:**
    *   Calculate the "Across Parent" (Scan left until `gridnums > 0` or Edge).
    *   Calculate the "Down Parent" (Scan up until `gridnums > 0` or Edge).
*   **Display:** A Banner at the top of the screen showing the **Full Text** of both clues in large font.

### 4.3 HUD Elements
*   **Top:** Scoreboard (P1 vs P2). Avatar of active player glows.
*   **Bottom:** Rack (Draggable tiles) + Action Bar (Shuffle, Vision, Ready).

---

## 5. Backend Architecture (Supabase)

### 5.1 Database Schema
We require two primary tables.

**Table: `puzzles`**
*   `id`: UUID
*   `json_data`: JSONB (Stores the full JSON file content)
*   `theme`: Text

**Table: `matches`**
*   `id`: UUID
*   `puzzle_id`: UUID (FK to puzzles)
*   `couple_id`: UUID
*   `status`: 'active' | 'completed'
*   `current_turn_user_id`: UUID
*   `board_state`: JSONB (Map of locked cells: `{"index_8": "D", "index_9": "R"}`)
*   `current_rack`: JSONB (List: `["A", "B", "C", "D", "E"]`)
*   `scores`: JSONB (`{"p1": 120, "p2": 90}`)
*   `powerups`: JSONB (`{"p1_vision": 2, "p2_vision": 2}`)

### 5.2 Edge Functions (API)

**Function: `start_match`**
*   Selects a puzzle the couple hasn't played.
*   Initializes `matches` row.
*   Calls `generate_rack()` logic.

**Function: `submit_turn`**
*   Input: `{ match_id, placements: [{index: 8, char: "D"}] }`
*   Validates placements.
*   Updates `board_state` and `scores`.
*   Switches turn.
*   Calls `generate_rack()` for the next player.

---

## 6. Side Quest Card Integration

**Linked** appears as an always-active quest card in the Side Quests carousel (below Daily Quests on the home screen).

### 6.1 Card Behavior
*   **Always Active:** Unlike daily quests, there is always a Linked puzzle assigned to one partner or the other
*   **Turn-Based Display:** Card updates in real-time to show whose turn it is
*   **Fixed Reward:** +30 Love Points per completed puzzle (displayed on all states)
*   **Visual Style:** Black & white only, 100% opacity, hierarchy through borders/badges
*   **Polling:** 10-second updates to reflect game state changes

### 6.2 Five Card States

| State | Condition | Visual Cues |
|-------|-----------|-------------|
| **Your Turn (Fresh)** | `current_turn_user_id == user.id` AND `locked_cell_count == 0` | **2px black border**, "Your Turn" badge, "Start the puzzle" description |
| **Partner's Turn (Fresh)** | `current_turn_user_id == partner.id` AND `locked_cell_count == 0` | **1px black border**, Partner's initial + name badge, "Waiting for {partner} to start" |
| **Your Turn (In Progress)** | `current_turn_user_id == user.id` AND `locked_cell_count > 0` | **2px black border**, Progress ring (%), "{N} letters in your rack", Scores displayed |
| **Partner's Turn (In Progress)** | `current_turn_user_id == partner.id` AND `locked_cell_count > 0` | **1px black border**, Partner badge, "Waiting for {partner}'s move", Scores displayed |
| **Completed** | `status == 'completed'` | **1px black border**, Checkmark badge (inverted colors), "Next puzzle in Xh Ym", Final scores |

### 6.3 Visual Hierarchy Rules
*   **Border Thickness as Signaling:**
    *   **2px border:** Action required (your turn) - draws attention
    *   **1px border:** Passive state (partner's turn or completed)
*   **Progressive Disclosure:**
    *   Fresh puzzles: No progress ring, no scores
    *   In progress: Progress ring (top-right), scores for both players
    *   Completed: Checkmark badge, final scores, countdown to next puzzle
*   **Badge Styling:**
    *   "Your Turn": White background, black text
    *   "Partner's Turn": Gray background, gray text, includes partner initial
    *   "Completed": Black background, white text (inverted)

### 6.4 Technical Requirements
*   **Data Source:** `GET /api/sync/linked/[matchId]` (10-second polling)
*   **Dynamic Elements:**
    *   Progress %: `Math.round((locked_cell_count / total_answer_cells) * 100)`
    *   Rack count: `current_rack.length` letters
    *   Countdown timer: `next_puzzle_available_at - now` (format: "Xh Ym")
*   **Tap Behavior:**
    *   Your turn (fresh/in-progress): Opens game screen
    *   Partner's turn: Opens read-only game view
    *   Completed: Opens completed puzzle review

### 6.5 Reference
Full UI specification: `mockups/crossword/CROSSWORD_CARD_UI_SPEC.md`

---

## 7. Game Screen & Gameplay Mechanics

### 7.1 Game Flow

**Initialization:**
1. Check for existing active match for couple
2. If none exists: Create new match, select puzzle, assign first player via `CouplePreferencesService`
3. If exists: Load match state, determine whose turn, show appropriate UI

**Turn Cycle:**
- **Your Turn:** Receive rack of 5 letters → Place letters on grid (drag & drop) → Submit turn → Server validates → Correct letters lock (green), incorrect bounce back → Points awarded → Turn passes to partner
- **Partner's Turn:** UI shows waiting state → Poll every 10 seconds → When partner submits, updated grid appears → Turn indicator updates to "Your Turn"

**Turn End Conditions:**
- Player places letters and presses "Submit Turn"
- Player presses "Submit Turn" with fewer than 5 letters (yields remaining)
- No timeouts - player must actively end turn

### 7.2 Grid Rendering

**Cell Types:**
- **Void**: Black/dark, non-interactive filler
- **Clue**: Gray with abbreviated text + direction arrow (▼ down, ▶ across)
- **Answer (Empty)**: White, drop target for letters
- **Answer (Draft)**: Yellow, player's unsubmitted placement
- **Answer (Locked)**: Green, correctly placed, permanent

**Grid Structure:** 7 cols × 9 rows = 63 cells (see Section 2.1 for L-Frame constraint)

**Index Mapping:** `index = (row * cols) + col`

### 7.3 Letter Rack System

**Rack Generation (Server-Side):**
1. Find all unfilled answer cells
2. Get their solution letters
3. Shuffle and select up to 5 letters
4. **Critical**: Rack only contains letters that are actually needed on the board

**Rules:**
- Only valid letters (no decoys)
- Duplicates allowed if puzzle needs multiple instances
- Dynamic sizing (may have <5 letters near completion)
- Server-generated to prevent cheating

### 7.4 Drag & Drop Mechanics

**Supported Operations:**
- **Rack → Grid**: Drag letter tile to empty answer cell
- **Grid → Grid**: Rearrange draft letters before submission
- **Grid → Rack**: Return draft letter to rack (undo placement)

**Visual Feedback:**
- Dragging: Source at 50% opacity
- Valid drop target: Blue background + border
- Draft placement: Yellow with pulse animation
- Locked letter: Green, non-draggable

### 7.5 Turn Submission & Validation

**Flow:**
1. Collect all placed letters `{ cellIndex, letter }`
2. Send to server via `POST /api/sync/linked/submit`
3. Server validates each placement against solution
4. Response includes: `{ cellIndex, correct }[]`, points earned, completed words
5. Client animations: Green flash (correct), shake + bounce back (incorrect)

**Scoring:**
- Correct letter: +10 points
- Word completion: +(word_length × 10) bonus
- Example: Place "P" completing "DRIP" (4 letters) = +10 + 40 = +50 points

### 7.6 Hint Power-Up

**Functionality:**
- **Allocation**: 2 hints per player per match
- **Action**: Tap "💡 Hint" button
- **Effect**: Highlights all valid cells for current rack letters (blue glow, 2 seconds)
- **API**: `POST /api/sync/linked/hint` returns `{ validCells: number[], hintsRemaining: number }`

### 7.7 Game Completion

**Trigger:** All answer cells are locked (correctly filled)

**Immediate Actions:**
1. Stop polling
2. Calculate final scores, determine winner
3. Award +30 Love Points to couple
4. Show completion screen with confetti animation

**Completion Screen Elements:**
- Falling confetti (50 particles)
- Circular checkmark badge (pop animation)
- "COMPLETE" title with "Puzzle Finished" subtitle
- Winner highlighted (black background), loser below
- Stats: Words found, total turns, time elapsed
- "Back to Home" button

**Partner's View:** When partner opens app later, card shows "Complete - Tap to see results" → navigates to completion screen

### 7.8 Visual Design

**Color Palette:**
- Void cells: #222222
- Clue cells: #E8E8E8
- Answer cells: #FFFFFF
- Draft cells: #FFEE58 (yellow)
- Locked cells: #81C784 (green)
- Drop target: #E3F2FD (light blue)

**Typography:**
- Clue text: Arial, 8px, weight 800
- Answer letters: Georgia, 22px, weight 700
- Rack letters: Georgia, 20px, weight 700

**Spacing:**
- Grid gap: 2px, Grid padding: 2px
- Rack tile size: 42×42px, Rack gap: 8px
- Container max-width: 390px (iPhone 14 size)

### 7.9 Reference
Full gameplay specification: `docs/LINKED_GAME_DETAILED_SPEC.md`

---

## 8. Implementation Steps for Agent

1.  **JSON Parser (Flutter):** Create a Dart model that parses the 1D arrays (`grid`, `gridnums`) into a 2D Grid structure, respecting the L-Frame.
2.  **Grid Renderer (Flutter):** Build the visual grid handling the 3 cell states (Void, Clue, Answer).
3.  **Parent Lookup Logic (Flutter):** Implement the algorithm to find the specific Clue ID for any given Answer Cell (for the Active Banner).
4.  **Backend Logic (Supabase):** Implement the `submit_turn` RPC function to handle validation and scoring server-side to prevent cheating.
5.  **Side Quest Card (Flutter):** Build the quest card widget with 5 states, polling mechanism, and proper visual hierarchy.
6.  **Drag & Drop System (Flutter):** Implement drag & drop for rack ↔ grid interactions with visual feedback.
7.  **Turn Submission Flow (Flutter):** Build submission logic, animation system (correct/incorrect/word complete).
8.  **Completion Screen (Flutter):** Create full-screen completion UI with confetti animation, final scores, stats.
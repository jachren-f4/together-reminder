# Linked Game - Detailed Implementation Specification

**Version:** 1.0
**Last Updated:** 2025-11-25
**Status:** Ready for Implementation

---

## Table of Contents

1. [Overview](#overview)
2. [Game Flow](#game-flow)
3. [Grid Layout & Rendering](#grid-layout--rendering)
4. [Letter Rack System](#letter-rack-system)
5. [Drag & Drop Mechanics](#drag--drop-mechanics)
6. [Turn Submission & Validation](#turn-submission--validation)
7. [Scoring System](#scoring-system)
8. [Hint Power-Up](#hint-power-up)
9. [Polling & Synchronization](#polling--synchronization)
10. [Game Completion](#game-completion)
11. [Love Points Integration](#love-points-integration)
12. [Visual Design Reference](#visual-design-reference)
13. [Data Structures](#data-structures)
14. [API Endpoints](#api-endpoints)

---

## Overview

Linked is a turn-based arroword (Scandinavian crossword) puzzle game where couples collaborate to complete a shared crossword puzzle. Players take turns placing letters from their rack onto the grid, earning points for correct placements and word completions.

### Key Characteristics

- **Turn-based**: Players alternate turns, no timeouts
- **Shared puzzle**: Both players work on the same puzzle
- **Server-validated**: Solution never sent to client; server validates all placements
- **Cooperative scoring**: Both players contribute to completing the puzzle
- **10-second polling**: State synchronized via polling (like Memory Flip)

---

## Game Flow

### 1. Game Initialization

```
┌─────────────────────────────────────────────────────────┐
│  Player opens Linked from Activities screen             │
│                         ↓                               │
│  Check for existing active match for couple             │
│                         ↓                               │
│  ┌─────────────────┐    ┌─────────────────┐            │
│  │ No active match │    │ Active match    │            │
│  │                 │    │ exists          │            │
│  └────────┬────────┘    └────────┬────────┘            │
│           ↓                      ↓                      │
│  Create new match          Load match state             │
│  Select puzzle             Determine whose turn         │
│  Assign first player       Show appropriate UI          │
│  (via CouplePreferences)                               │
└─────────────────────────────────────────────────────────┘
```

### 2. Turn Cycle

```
┌─────────────────────────────────────────────────────────┐
│  YOUR TURN                                              │
│  ─────────                                              │
│  1. Receive rack of 5 letters (from remaining needed)   │
│  2. Place letters on grid (drag & drop)                 │
│  3. Rearrange placements as needed                      │
│  4. Press "Submit Turn" when ready                      │
│  5. Server validates each placement                     │
│  6. Correct letters lock (green), wrong bounce back     │
│  7. Points awarded                                      │
│  8. Turn passes to partner                              │
│                                                         │
│  PARTNER'S TURN                                         │
│  ──────────────                                         │
│  1. UI shows "Partner's Turn" state                     │
│  2. Poll every 10 seconds for state changes             │
│  3. When partner submits, receive updated grid          │
│  4. See their correct placements appear                 │
│  5. Turn indicator updates to "Your Turn"               │
│  6. New rack generated from remaining letters           │
└─────────────────────────────────────────────────────────┘
```

### 3. Turn End Conditions

A turn ends when the player:
- Places all 5 letters and presses "Submit Turn"
- Presses "Submit Turn" with fewer than 5 letters placed (yields remaining)
- **Note**: No timeout - player must actively end their turn

---

## Grid Layout & Rendering

### Cell Types

| Type | Appearance | Behavior |
|------|------------|----------|
| **Void** | Black/dark | Non-interactive, fills empty space |
| **Clue** | Gray with text | Displays abbreviated clue + direction arrow |
| **Answer (Empty)** | White | Drop target for letters |
| **Answer (Draft)** | Yellow | Player's unsubmitted placement |
| **Answer (Locked)** | Green | Correctly placed, permanent |

### Grid Structure (7×9 = 63 cells)

```
Row 0: [void, clue↓, clue↓, void, clue↓, void, clue↓]
Row 1: [clue→, ans,  ans,  ans,  ans,  void, ans ]
Row 2: [clue→, ans,  ans,  void, ans,  void, ans ]
Row 3: [clue→, ans,  ans,  void, ans,  void, ans ]
Row 4: [void, clue↓, ans,  clue↓, ans, clue↓, ans ]
Row 5: [void, ans,  void, ans,  void, ans,  void]
Row 6: [void, ans,  clue→, ans, clue→, ans, clue↓]
Row 7: [clue→, ans, void, ans,  clue→, ans,  ans ]
Row 8: [clue→, ans, clue→, ans,  ans,  ans,  ans ]
```

### Clue Cell Rendering

- **Font**: Arial, 8px, weight 800, uppercase
- **Arrow indicator**: Small ▼ (down) or ▶ (across) positioned at edge
- **Text**: Abbreviated clue (e.g., "DOM PARTNER", "FLUID FLOW")
- **Tap action**: Could show full clue in banner (optional enhancement)

### Index Calculation

```javascript
// Convert row, col to flat index
index = row * 7 + col

// Convert index to row, col
row = Math.floor(index / 7)
col = index % 7
```

---

## Letter Rack System

### Rack Generation Algorithm

The rack must only contain letters that are **actually needed** on the board:

```javascript
function generateRackFromRemainingLetters() {
    const neededLetters = [];

    // Find all unfilled answer cells and get their solution letters
    GRID_LAYOUT.forEach((cell, index) => {
        if (cell.type === 'answer' && !cell.locked && SOLUTION[index]) {
            neededLetters.push(SOLUTION[index]);
        }
    });

    // Shuffle and take up to 5 letters
    const shuffled = neededLetters.sort(() => Math.random() - 0.5);
    const rack = shuffled.slice(0, 5);

    // Pad with nulls if fewer than 5 letters remain
    while (rack.length < 5) {
        rack.push(null);
    }

    return rack;
}
```

### Key Rules

1. **Only valid letters**: Rack contains only letters that have valid placements
2. **Duplicates allowed**: If puzzle needs 3 E's, rack may contain multiple E's
3. **Dynamic sizing**: As puzzle nears completion, rack may have fewer than 5 letters
4. **Server-generated**: In production, server generates rack to prevent cheating

### Rack Display

- **5 tile slots** (fixed width)
- **Filled tile**: Yellow background, 2px black border, letter displayed
- **Empty slot**: Gray background, dashed border

---

## Drag & Drop Mechanics

### From Rack to Grid

```javascript
// Drag start from rack
draggedLetter = {
    letter: rackLetters[index],
    rackIndex: index,
    fromRack: true
};

// Drop on empty answer cell
if (cell.type === 'answer' && !cell.locked && !placedLetters[cellIndex]) {
    placedLetters[cellIndex] = {
        letter: draggedLetter.letter,
        rackIndex: draggedLetter.rackIndex
    };
    rackLetters[draggedLetter.rackIndex] = null;
}
```

### From Grid to Grid (Rearranging)

Draft letters can be moved between cells before submission:

```javascript
// Drag start from draft cell
draggedLetter = {
    letter: placed.letter,
    rackIndex: placed.rackIndex,
    fromRack: false,
    fromCell: cellIndex
};

// Drop on different empty cell
delete placedLetters[draggedLetter.fromCell];
placedLetters[newCellIndex] = {
    letter: draggedLetter.letter,
    rackIndex: draggedLetter.rackIndex
};
```

### From Grid Back to Rack

```javascript
// Drag draft letter to empty rack slot OR click draft letter
rackLetters[draggedLetter.rackIndex] = draggedLetter.letter;
delete placedLetters[cellIndex];
```

### Visual Feedback

| State | Visual |
|-------|--------|
| Dragging from rack | Rack tile at 50% opacity |
| Valid drop target | Blue background, blue border |
| Invalid drop target | No highlight |
| Draft placement | Yellow pulsing animation |

---

## Turn Submission & Validation

### Submission Flow

```
┌─────────────────────────────────────────────────────────┐
│  Player presses "Submit Turn"                           │
│                         ↓                               │
│  Collect all placed letters: { cellIndex, letter }      │
│                         ↓                               │
│  Send to server for validation                          │
│                         ↓                               │
│  Server checks each placement against SOLUTION          │
│                         ↓                               │
│  ┌─────────────────┐    ┌─────────────────┐            │
│  │ Correct         │    │ Incorrect       │            │
│  │ placement       │    │ placement       │            │
│  └────────┬────────┘    └────────┬────────┘            │
│           ↓                      ↓                      │
│  Lock cell (green)         Shake animation              │
│  +10 points                Return letter to rack        │
│  Check word completion     No points                    │
└─────────────────────────────────────────────────────────┘
```

### Validation Response

```typescript
interface SubmitResponse {
    results: {
        cellIndex: number;
        correct: boolean;
    }[];
    pointsEarned: number;
    completedWords: {
        word: string;
        cells: number[];
        bonus: number;
    }[];
    newScore: number;
    gameComplete: boolean;
    nextTurn: 'player1' | 'player2';
}
```

### Animations

| Event | Animation |
|-------|-----------|
| Correct letter | Green flash, scale up 1.1x, lock in place |
| Incorrect letter | Shake left-right 4x, bounce back to rack |
| Word complete | All word cells pulse green, scale 1.15x |

---

## Scoring System

### Point Values

| Action | Points |
|--------|--------|
| Correct letter placement | +10 |
| Complete a word | +(word_length × 10) bonus |

### Examples

- Place "I" correctly → +10 points
- Place "P" correctly, completing "DRIP" (4 letters) → +10 (letter) + 40 (word bonus) = +50 points

### Score Display

- Shown in header: "You: 180" and "Taija: 140"
- Active player indicated with green dot or highlight
- Score bumps up with animation when points earned

---

## Hint Power-Up

### Functionality

When player taps "Hint" button:

1. Find all empty answer cells
2. For each cell, check if any rack letter matches the solution
3. Highlight valid cells with blue glow for 2 seconds
4. Decrement hint counter

### Implementation

```javascript
function useHint() {
    if (hintsLeft <= 0) {
        showToast('No hints left!');
        return;
    }

    hintsLeft--;

    const availableLetters = rackLetters.filter(l => l !== null);
    const validCells = [];

    GRID_LAYOUT.forEach((cell, idx) => {
        if (cell.type === 'answer' && !cell.locked && !placedLetters[idx]) {
            const solution = SOLUTION[idx];
            if (solution && availableLetters.includes(solution)) {
                validCells.push(idx);
            }
        }
    });

    // Highlight valid cells for 2 seconds
    highlightCells(validCells, 2000);
}
```

### Hint Allocation

- **Per match**: 2 hints per player
- **Display**: "💡 Hint (2)" in action bar

---

## Polling & Synchronization

### Polling Strategy

- **Interval**: Every 10 seconds (matches Memory Flip pattern)
- **When**: Only during partner's turn
- **What**: Full match state including grid, scores, whose turn

### State Sync Response

```typescript
interface MatchState {
    matchId: string;
    puzzleId: string;
    status: 'active' | 'completed';
    currentTurn: 'player1' | 'player2';
    player1Score: number;
    player2Score: number;
    lockedCells: { [cellIndex: number]: string }; // Revealed letters
    lastUpdated: string; // ISO timestamp
}
```

### Optimistic Updates

- Player's own moves update UI immediately
- Server response confirms or corrects
- Partner's moves appear on next poll

---

## Game Completion

### Completion Trigger

Game completes when **all answer cells are locked** (correctly filled).

### Immediate Actions

1. **Stop polling**
2. **Calculate final scores**
3. **Determine winner** (higher score wins)
4. **Award Love Points** (30 LP to couple)
5. **Show completion screen immediately**

### Completion Screen (completion-v1-fullscreen)

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│              [Falling confetti animation]               │
│                                                         │
│                    ┌─────────┐                          │
│                    │    ✓    │  (Badge with checkmark)  │
│                    └─────────┘                          │
│                                                         │
│                    COMPLETE                             │
│                  Puzzle Finished                        │
│                                                         │
│   ┌─────────────────────────────────────────────┐      │
│   │  YOU                              180       │      │
│   │  Winner                                     │      │
│   ├─────────────────────────────────────────────┤      │
│   │  Taija                            140       │      │
│   └─────────────────────────────────────────────┘      │
│                                                         │
│         12 Words    8 Turns    4:32 Time               │
│                                                         │
│              ┌───────────────────┐                      │
│              │   BACK TO HOME    │                      │
│              └───────────────────┘                      │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Partner's Completion View

When the partner (who wasn't present for the final move) opens the app:

1. **Home screen shows completed Linked card**
2. **Card displays**: "Linked Complete - Tap to see results"
3. **On tap**: Navigate directly to completion screen
4. **Same completion UI**: Shows final scores, winner, stats
5. **After dismissal**: Card removed from home screen

### Completion Screen Elements

| Element | Description |
|---------|-------------|
| **Confetti** | 50 black/gray particles falling, rotating |
| **Badge** | Circular checkmark, pop animation |
| **Title** | "COMPLETE" with "Puzzle Finished" subtitle |
| **Scores** | Winner highlighted (black background), loser below |
| **Stats** | Words found, total turns, time elapsed |
| **Action** | Single "Back to Home" button |

---

## Love Points Integration

### Award Trigger

Love Points are awarded **once per completed puzzle match**:

| Event | LP Awarded |
|-------|-----------|
| Couple completes a Linked puzzle | +30 LP |

### Implementation

```typescript
// On game completion (server-side)
async function handleGameComplete(matchId: string, coupleId: string) {
    // Update match status
    await updateMatchStatus(matchId, 'completed');

    // Award Love Points (only once)
    await awardLovePoints(coupleId, 30, 'linked_puzzle_complete');

    // Both players see +30 LP notification when viewing completion
}
```

### Display

- LP award shown on completion screen (optional enhancement)
- Notification banner: "+30 LP" when returning to home

---

## Visual Design Reference

### Color Palette

| Element | Color |
|---------|-------|
| Primary background | #FFFFFF |
| Primary text | #000000 |
| Void cells | #222222 |
| Clue cells | #E8E8E8 |
| Answer cells | #FFFFFF |
| Draft cells | #FFEE58 (yellow) |
| Locked cells | #81C784 (green) |
| Locked text | #1B5E20 |
| Drop target | #E3F2FD (light blue) |
| Borders | #000000 |

### Typography

| Element | Font | Size | Weight |
|---------|------|------|--------|
| Clue text | Arial | 8px | 800 |
| Answer letters | Georgia | 22px | 700 |
| Rack letters | Georgia | 20px | 700 |
| Score display | Georgia | 13px | 700 |
| Button text | Georgia | 11px | 600 |

### Spacing

- Grid gap: 2px
- Grid padding: 2px
- Rack tile size: 42×42px
- Rack gap: 8px
- Container max-width: 390px (iPhone 14)
- Container max-height: 844px

---

## Data Structures

### Puzzle JSON Format

```json
{
    "author": "Crossword Maker GPT",
    "title": "Adult Intimacy Quality Arroword",
    "size": { "rows": 9, "cols": 7 },
    "clues": {
        "1": {
            "type": "text",
            "content": "Dominant partner",
            "arrow": "down",
            "target_index": 8
        }
    },
    "grid": [".", ".", ".", ".", ".", ".", ".", ".", "D", "R", "I", "P", ".", "W", ...],
    "gridnums": [0, 1, 2, 0, 3, 0, 4, 5, 0, 0, 0, 0, 0, 0, ...]
}
```

### Match State (Supabase)

```sql
CREATE TABLE linked_matches (
    id UUID PRIMARY KEY,
    couple_id UUID REFERENCES couples(id),
    puzzle_id TEXT NOT NULL,
    status TEXT DEFAULT 'active', -- 'active', 'completed'
    current_turn TEXT NOT NULL, -- 'player1', 'player2'
    player1_id UUID NOT NULL,
    player2_id UUID NOT NULL,
    player1_score INT DEFAULT 0,
    player2_score INT DEFAULT 0,
    locked_cells JSONB DEFAULT '{}', -- {cellIndex: letter}
    player1_rack TEXT[], -- Current rack letters
    player2_rack TEXT[],
    hints_player1 INT DEFAULT 2,
    hints_player2 INT DEFAULT 2,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## API Endpoints

### POST /api/sync/linked

Start or get existing match.

**Request:**
```json
{
    "coupleId": "uuid",
    "userId": "uuid"
}
```

**Response:**
```json
{
    "matchId": "uuid",
    "puzzle": { /* puzzle data without solution */ },
    "state": { /* current match state */ },
    "yourTurn": true,
    "rack": ["I", "P", "M", "E", "A"]
}
```

### GET /api/sync/linked/[matchId]

Poll for state updates.

**Response:**
```json
{
    "state": { /* current match state */ },
    "yourTurn": false,
    "rack": null // Only included when it's your turn
}
```

### POST /api/sync/linked/submit

Submit turn placements.

**Request:**
```json
{
    "matchId": "uuid",
    "placements": [
        { "cellIndex": 10, "letter": "I" },
        { "cellIndex": 11, "letter": "P" }
    ]
}
```

**Response:**
```json
{
    "results": [
        { "cellIndex": 10, "correct": true },
        { "cellIndex": 11, "correct": true }
    ],
    "pointsEarned": 50,
    "completedWords": [
        { "word": "DRIP", "cells": [8,9,10,11], "bonus": 40 }
    ],
    "newScore": 180,
    "gameComplete": false,
    "nextRack": ["S", "K", "W", "O", "R"]
}
```

### POST /api/sync/linked/hint

Use hint power-up.

**Request:**
```json
{
    "matchId": "uuid"
}
```

**Response:**
```json
{
    "validCells": [18, 27, 45],
    "hintsRemaining": 1
}
```

---

## Implementation Checklist

### Phase 1: Data Layer
- [ ] Create Hive models (LinkedMatch, LinkedPuzzle)
- [ ] Create database migration
- [ ] Copy puzzle JSON to api/data/puzzles/

### Phase 2: API
- [ ] Puzzle loader utility
- [ ] Start/get match endpoint
- [ ] Poll state endpoint
- [ ] Submit turn endpoint
- [ ] Hint endpoint

### Phase 3: Flutter Service
- [ ] LinkedService class
- [ ] Local Hive caching
- [ ] Polling timer

### Phase 4: UI Widgets
- [ ] LinkedGrid (grid rendering)
- [ ] ClueCell (clue display with arrow)
- [ ] AnswerCell (drag target)
- [ ] RackWidget (draggable tiles)
- [ ] Scoreboard
- [ ] ActionBar

### Phase 5: Game Screen
- [ ] LinkedGameScreen layout
- [ ] Drag & drop state management
- [ ] Submit turn flow
- [ ] Animations (correct/incorrect/word complete)
- [ ] Completion screen

### Phase 6: Integration
- [ ] Add to Activities screen
- [ ] Home screen card for active/completed matches
- [ ] Love Points integration

---

## Reference Mockups

| File | Purpose |
|------|---------|
| `mockups/crossword/basic-v6-combined.html` | Final gameplay layout |
| `mockups/crossword/interactive-gameplay.html` | Interactive prototype with full logic |
| `mockups/crossword/completion-v1-fullscreen.html` | Completion screen design |

---

*Document created based on interactive mockup development session, 2025-11-25*

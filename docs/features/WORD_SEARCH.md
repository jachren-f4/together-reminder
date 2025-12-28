# Word Search Game

## Quick Reference

| Item | Location |
|------|----------|
| Service | `lib/services/word_search_service.dart` |
| Model | `lib/models/word_search.dart` |
| Game Screen | `lib/screens/word_search_game_screen.dart` |
| Completion Screen | `lib/screens/word_search_completion_screen.dart` |
| API Routes | `api/app/api/sync/word-search/*.ts` |
| Puzzle Content | `api/data/puzzles/word-search/{branch}/` |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Word Search Game                             │
│                                                                  │
│   Turn-based word finding puzzle                                │
│   Partners take turns finding hidden words                      │
│                                                                  │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│   │   Grid       │    │   Words      │    │   Hints          │  │
│   │   (letters)  │    │   (to find)  │    │   (reveal cell)  │  │
│   └──────────────┘    └──────────────┘    └──────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Game Mechanics

### Turn-Based Play
1. Server determines who goes first
2. Player finds words in the grid
3. Each player finds X words per turn
4. Turn switches after finding required words
5. Game completes when all words found

### Scoring
- **Per word found:** Points based on word length
- **Hints:** Reveal first letter of unfound word
- **Completion LP:** 30 LP shared when puzzle is completed

### Branches
Themed puzzle content with progression:
- **everyday** → **passionate** → **naughty** → (cycles back)

---

## Data Flow

### Starting a Game
```
User taps Word Search Side Quest
         │
         ▼
WordSearchGameScreen
         │
         ▼
_service.getOrCreateMatch()
         │
         ▼
POST /api/sync/word-search
  { localDate: "2024-12-16" }
         │
         ▼
Return match + puzzle + gameState
```

### Submitting a Word
```
User drags to select word
         │
         ▼
_service.submitWord(matchId, word, positions)
         │
         ▼
POST /api/sync/word-search/submit
  { matchId, word, positions: [{row, col}...] }
         │
    ┌────┴────────────────────────┐
    ▼                             ▼
Word Valid                   Invalid
Update found words           Show error
Check turn/completion
```

### Using a Hint
```
User taps hint button
         │
         ▼
_service.useHint(matchId)
         │
         ▼
POST /api/sync/word-search/hint
         │
         ▼
Return revealed cell position
Highlight on grid
```

---

## Key Rules

### 1. Similar to Linked
Word Search follows the same patterns as Linked:
- Extends `SideQuestServiceBase`
- Uses `GamePollingMixin` for turn polling
- Shows partner dialog when it's not your turn
- Saves match to Hive for quest cards

### 2. Turn Completion
Players must find a set number of words per turn:

```dart
if (result.turnComplete) {
  // Switch to partner's turn
  _showTurnComplete = true;
  startPolling();
}
```

### 3. Word Selection via Drag (Two-Phase System)
Words are selected by dragging across cells using a two-phase detection system:

**Phase 1 (First 2 cells):** Direct hit-testing
- Checks which cell the finger is actually inside
- More accurate for establishing direction
- Prevents accidental diagonal detection when user intends straight lines

**Phase 2 (Cells 3+):** Direction-based detection
- Uses vector from last cell center to finger position
- Enforces straight-line constraint along established direction
- Allows smooth continuation along the locked direction

```dart
if (_selectedPositions.length < 2) {
  // Phase 1: Direct hit-test - which cell is finger in?
  nextCell = _getCellFromPosition(details.globalPosition);
  if (!_isAdjacent(lastCell, nextCell)) return;
} else {
  // Phase 2: Direction-based detection along the line
  nextCell = _getNextCellByDirection(lastCell, localPos);
}
```

**Why two phases?**
- The first two cells establish the direction (horizontal, vertical, or diagonal)
- Using direct hit-testing for these cells ensures the user's intended direction is captured accurately
- Once direction is locked, projection-based detection provides smooth, stable selection

---

## Common Bugs & Fixes

### 1. Accidental Diagonal Selection When Drawing Straight Lines
**Symptom:** User tries to draw straight down/across, but selection snaps to diagonal and gets stuck.

**Cause:** Direction-based detection for the 2nd cell was too sensitive to slight finger movement. The angle calculation had a wide diagonal zone (22°-68°), so minor horizontal drift when drawing vertically would trigger diagonal detection. Once 2 cells locked a diagonal direction, straight movement couldn't continue.

**Fix:** Two-phase selection system (implemented 2024-12-19):
- Phase 1: Use direct hit-testing for first 2 cells (which cell is finger actually in?)
- Phase 2: Use direction-based detection only after direction is established

```dart
if (_selectedPositions.length < 2) {
  // Direct hit-test - prevents accidental diagonal
  nextCell = _getCellFromPosition(details.globalPosition);
} else {
  // Direction established, use projection
  nextCell = _getNextCellByDirection(lastCell, localPos);
}
```

### 2. Hint Not Highlighting
**Symptom:** Hint returns success but no cell highlights.

**Cause:** Hint position not applied to UI state.

**Fix:** Update hint state after API call:
```dart
setState(() => _hintPosition = result.position);
```

### 3. Turn Not Switching
**Symptom:** Same player keeps finding words.

**Cause:** `wordsRemainingThisTurn` not tracked.

**Fix:** Check turn state after each word:
```dart
if (gameState.wordsRemainingThisTurn == 0) {
  _switchTurn();
}
```

---

## API Reference

### POST /api/sync/word-search
Create or get active match.

**Response:**
```json
{
  "match": {
    "matchId": "uuid",
    "puzzleId": "ws_everyday_001",
    "status": "active",
    "currentTurnUserId": "user-uuid"
  },
  "puzzle": {
    "grid": [["A","B",...],["C","D",...],...],
    "words": ["LOVE", "HEART", "PASSION", ...]
  },
  "gameState": {
    "isMyTurn": true,
    "wordsRemainingThisTurn": 2,
    "myWordsFound": 3,
    "partnerWordsFound": 2
  }
}
```

### POST /api/sync/word-search/submit
Submit found word.

**Request:**
```json
{
  "matchId": "uuid",
  "word": "LOVE",
  "positions": [
    {"row": 0, "col": 0},
    {"row": 0, "col": 1},
    {"row": 0, "col": 2},
    {"row": 0, "col": 3}
  ]
}
```

### POST /api/sync/word-search/hint
Use hint to reveal cell.

**Response:**
```json
{
  "success": true,
  "position": {"row": 2, "col": 5},
  "hintsRemaining": 2
}
```

---

## Branch Rotation

Branches advance on puzzle completion:

```
everyday → passionate → naughty → everyday → ...
```

Same cooldown system as Linked.

---

## File Reference

| File | Purpose |
|------|---------|
| `word_search_service.dart` | API communication |
| `word_search.dart` | Match, puzzle, position models |
| `word_search_game_screen.dart` | Grid UI with drag selection |
| `word_search_completion_screen.dart` | End-of-puzzle celebration |

---

## Changelog

### 2024-12-19: Two-Phase Selection System
**Problem:** When drawing words vertically or horizontally, slight finger movement would cause the selection to snap to diagonal. Once diagonal direction was locked, the selection couldn't follow straight movements.

**Root Cause:** The direction detection algorithm (`_getNextCellByDirection`) used angle-based calculation with a wide diagonal zone (22°-68°). Even minor horizontal drift when drawing vertically triggered diagonal detection for the 2nd cell.

**Solution:** Implemented two-phase selection:
- **Phase 1 (cells 1-2):** Direct hit-testing - checks which cell the finger is actually inside
- **Phase 2 (cells 3+):** Direction-based detection along the established line

**Files Changed:**
- `lib/screens/word_search_game_screen.dart` - Updated `_handlePanUpdate()` method

**Impact:** Much more accurate direction detection. Users can now reliably draw straight lines without accidental diagonal snapping.

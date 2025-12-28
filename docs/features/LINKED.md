# Linked (Arroword Puzzle)

## Quick Reference

| Item | Location |
|------|----------|
| Service | `lib/services/linked_service.dart` |
| Base Class | `lib/services/side_quest_service_base.dart` |
| Model | `lib/models/linked.dart` |
| Game Screen | `lib/screens/linked_game_screen.dart` |
| Completion Screen | `lib/screens/linked_completion_screen.dart` |
| Widgets | `lib/widgets/linked/*.dart` |
| API Routes | `api/app/api/sync/linked/*.ts` |
| Puzzle Loader | `api/lib/puzzle/loader.ts` |
| Puzzle Content | `api/data/puzzles/linked/{branch}/` |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Linked Game                                  │
│                                                                  │
│   Turn-based arroword puzzle                                    │
│   Partners take turns placing letters                           │
│                                                                  │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│   │   Grid       │    │   Rack       │    │   Score          │  │
│   │   (puzzle)   │    │   (letters)  │    │   (per word)     │  │
│   └──────────────┘    └──────────────┘    └──────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    LinkedService (extends SideQuestServiceBase)
                              │
                              ▼
                    POST /api/sync/linked
                    POST /api/sync/linked/submit
                    GET  /api/sync/linked/{matchId}
```

---

## Game Mechanics

### Turn-Based Play
1. Server determines who goes first (alternates between games)
2. Player places letters from their rack onto the grid
3. When all rack letters are placed, turn is submitted
4. Partner is notified, takes their turn
5. Repeat until puzzle is complete

### Scoring
- **Per word completed:** Points based on word length
- **Vision system:** Each player sees a portion of the puzzle
- **Completion LP:** 30 LP shared when puzzle is completed

### Branches
Themed puzzle content with progression:
- **casual** → **romantic** → **adult** → (cycles back to casual)

---

## Clue Formats

### Single-Direction Clues (Standard)
A clue pointing in one direction:

```json
{ "type": "emoji", "content": "🌟", "arrow": "across", "target_index": 10 }
{ "type": "text", "content": "Come ___", "arrow": "down", "target_index": 15 }
```

### Dual-Direction Clues
A single cell containing both ACROSS and DOWN clues (Scandinavian/Arroword style):

```json
"7": {
  "across": { "type": "emoji", "content": "🌟", "target_index": 10 },
  "down": { "type": "text", "content": "LO_E", "target_index": 16 }
}
```

**Detection:** Check for `arrow` key at top level. If present → single format. If absent → dual format.

**Rendering:** Horizontal split layout with across clue on top, down clue on bottom, separated by a divider line.

### Emoji + Text Hints
When an emoji clue points to a single letter (not a full word), include a text hint:

```json
{ "type": "emoji", "content": "🍑", "text": "_SS", "arrow": "across", "target_index": 22 }
```

**Examples:**
- 🍑 _SS → Answer is "A" (from ASS)
- ❤️ LO_E → Answer is "V" (from LOVE)
- 🛏️ _ED → Answer is "B" (from BED)

**Rendering (Variant 1 - Offset Stack):**
- Regular cells: Emoji (22px) left-aligned on top, text hint (14px) right-aligned on bottom
- Split cells: Inline emoji (14px) + text (9px) side-by-side

**Works with both formats:**
```json
// Single-direction with text hint
{ "type": "emoji", "content": "🍑", "text": "_SS", "arrow": "across", "target_index": 22 }

// Dual-direction with text hint
"20": {
  "across": { "type": "text", "content": "Side ___ side", "target_index": 47 },
  "down": { "type": "emoji", "content": "❤️", "text": "LO_E", "target_index": 53 }
}
```

---

## Data Flow

### Starting a Game
```
User taps Linked Side Quest
         │
         ▼
LinkedGameScreen
         │
         ▼
_service.getOrCreateMatch()
         │
         ▼
POST /api/sync/linked
  { localDate: "2024-12-16" }
         │
    ┌────┴────────────────────────┐
    ▼                             ▼
Match Exists                 Create New Match
(return existing)            (load puzzle, assign first turn)
    │                             │
    └─────────────┬───────────────┘
                  ▼
         LinkedGameState
         (match + puzzle + gameState)
```

### Submitting a Turn
```
User places all letters on grid
         │
         ▼
_service.submitTurn(matchId, placements)
         │
         ▼
POST /api/sync/linked/submit
  { matchId: "uuid", placements: [...] }
         │
         ▼
Server validates & scores
         │
    ┌────┴────────────────────────┐
    ▼                             ▼
Turn Accepted               Game Completed
Switch to partner           Award LP (30)
    │                             │
    ▼                             ▼
Show "turn complete" dialog   LinkedCompletionScreen
Wait for partner
```

### Polling During Partner's Turn
```
GamePollingMixin active (shouldPoll = !isMyTurn)
         │
         ▼ (every 10s)
         │
GET /api/sync/linked/{matchId}
         │
         ▼
Check if it's now our turn
         │
    ┌────┴────────────────────────┐
    ▼                             ▼
isMyTurn = true            Still partner's turn
    │                             │
    ▼                             ▼
Show "It's your turn!"      Continue polling
Update UI
```

---

## Key Rules

### 1. Save Match to Hive After Turn
After submitting a turn, save the match to Hive for side quest cards:

```dart
// In _handleSubmit after setState with _updateStateFromResult()
await StorageService().saveLinkedMatch(_gameState!.match);
```

This is critical for `quest_card.dart` to show correct turn status.

### 2. Turn Detection in Quest Card
Quest cards check `currentTurnUserId` synchronously:

```dart
// In quest_card.dart
final match = StorageService().getActiveLinkedMatch();
final isMyTurn = match?.currentTurnUserId == currentUserId;
```

### 3. Cooldown System
Branch cooldown prevents rapid puzzle completion:

```dart
// Server checks cooldown before creating new match
if (isCooldownActive) {
  throw CooldownActiveException('Wait for cooldown');
}
```

Toggle via env: `PUZZLE_COOLDOWN_ENABLED=true`

### 4. Partner First Dialog
If entering when it's partner's turn, show dialog:

```dart
if (!gameState.isMyTurn) {
  _showPartnerFirst = true;  // Dialog with "Wait" or "Go Back"
}
```

### 5. LP Sync on Completion
LP is awarded server-side. Sync before navigating:

```dart
Future<void> _navigateToCompletionWithLPSync(LinkedMatch match) async {
  await LovePointService.fetchAndSyncFromServer();
  if (!mounted) return;
  Navigator.of(context).pushReplacement(LinkedCompletionScreen(...));
}
```

---

## Common Bugs & Fixes

### 1. Quest Card Shows Wrong Turn
**Symptom:** Side quest card says "Your turn" but it's partner's turn.

**Cause:** Match not saved to Hive after turn submission.

**Fix:** Save after submit:
```dart
await StorageService().saveLinkedMatch(_gameState!.match);
```

### 2. Stuck on Partner's Turn
**Symptom:** Partner completed turn but UI doesn't update.

**Cause:** Polling not active or callback not triggering rebuild.

**Fix:** Check `GamePollingMixin`:
```dart
@override
bool get shouldPoll => !_isLoading && _gameState != null && !_gameState!.isMyTurn;

@override
Future<void> onPollUpdate() async {
  final newState = await _service.pollMatchState(_gameState!.match.matchId);
  if (mounted) setState(() => _gameState = newState);
}
```

### 3. Cooldown Not Respected
**Symptom:** User can start new puzzle immediately after completing one.

**Cause:** `PUZZLE_COOLDOWN_ENABLED` not set.

**Fix:** Set in API `.env`:
```bash
PUZZLE_COOLDOWN_ENABLED=true
```

### 4. Letters Don't Submit
**Symptom:** Tap submit but nothing happens.

**Cause:** Not all rack letters placed.

**Fix:** Validate placement count:
```dart
final canSubmit = _draftPlacements.length == rack.length && !_isSubmitting;
```

### 5. Score Not Updating
**Symptom:** Words completed but score stays at 0.

**Cause:** Using local score calculation instead of server.

**Fix:** Use server-provided scores:
```dart
myScore: gameStateData['myScore'] ?? 0,
partnerScore: gameStateData['partnerScore'] ?? 0,
```

---

## Debugging Tips

### Check Game State
```dart
debugPrint('Match ID: ${_gameState?.match.matchId}');
debugPrint('Status: ${_gameState?.match.status}');
debugPrint('My Turn: ${_gameState?.isMyTurn}');
debugPrint('Current Turn User: ${_gameState?.match.currentTurnUserId}');
debugPrint('My Score: ${_gameState?.myScore}');
debugPrint('Partner Score: ${_gameState?.partnerScore}');
```

### View API Response
```bash
# Get match state
curl "https://api-joakim-achrens-projects.vercel.app/api/sync/linked/MATCH_ID" \
  -H "Authorization: Bearer <token>"

# Create/get match
curl -X POST "https://api-joakim-achrens-projects.vercel.app/api/sync/linked" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"localDate": "2024-12-16"}'
```

### Force New Puzzle
1. Delete match: `DELETE FROM linked_matches WHERE couple_id = 'uuid'`
2. Reset branch: Update `branch_progressions` table
3. Restart app

---

## API Reference

### POST /api/sync/linked
Create or get active match.

**Request:**
```json
{ "localDate": "2024-12-16" }
```

**Response:**
```json
{
  "match": {
    "matchId": "uuid",
    "puzzleId": "l_casual_001",
    "status": "active",
    "boardState": { "0": "A", "1": "B", ... },
    "currentRack": ["L", "O", "V", "E"],
    "currentTurnUserId": "user-uuid",
    "turnNumber": 3,
    "player1Score": 15,
    "player2Score": 12
  },
  "puzzle": {
    "grid": [...],
    "clues": [...]
  },
  "gameState": {
    "isMyTurn": true,
    "canPlay": true,
    "myScore": 15,
    "partnerScore": 12,
    "progressPercent": 45
  }
}
```

### POST /api/sync/linked/submit
Submit turn with letter placements.

**Request:**
```json
{
  "matchId": "uuid",
  "placements": [
    { "cellIndex": 5, "letter": "L" },
    { "cellIndex": 6, "letter": "O" },
    { "cellIndex": 7, "letter": "V" },
    { "cellIndex": 8, "letter": "E" }
  ]
}
```

**Response:**
```json
{
  "success": true,
  "match": { ... },
  "result": {
    "isGameComplete": false,
    "wordsCompleted": ["LOVE"],
    "pointsEarned": 4,
    "newRack": ["H", "A", "P", "Y"]
  }
}
```

### GET /api/sync/linked/{matchId}
Poll match state.

**Response:** Same as POST `/api/sync/linked`

---

## Screen Flow

```
┌────────────────┐     ┌────────────────┐     ┌────────────────┐
│  Side Quest    │────>│  Game Screen   │────>│  My Turn?      │
│  Card (tap)    │     │  (load state)  │     │                │
└────────────────┘     └────────────────┘     └────────────────┘
                                                      │
                              ┌───────────────────────┤
                              ▼                       ▼
                         No (partner)              Yes
                              │                       │
                              ▼                       ▼
                    ┌────────────────┐     ┌────────────────┐
                    │ Partner First  │     │  Play Turn     │
                    │ Dialog         │     │  (place tiles) │
                    └────────────────┘     └────────────────┘
                              │                       │
                              ▼                       ▼
                         Wait/Leave          Submit Turn
                              │                       │
                              ▼                       ▼
                    ┌────────────────┐     ┌────────────────┐
                    │  Polling...    │     │ Turn Complete  │
                    │  (10s)         │     │ Dialog         │
                    └────────────────┘     └────────────────┘
                              │                       │
                              └───────────┬───────────┘
                                          ▼
                                   ┌────────────────┐
                                   │ Game Complete? │
                                   └────────────────┘
                                          │
                              ┌───────────┴───────────┐
                              ▼                       ▼
                         Yes                        No
                              │                       │
                              ▼                       ▼
                    ┌────────────────┐         Return to
                    │ Completion     │         waiting/home
                    │ Screen (+30 LP)│
                    └────────────────┘
```

---

## Branch Rotation

Branches advance on puzzle completion:

```
casual → romantic → adult → casual → ...
```

Server tracks progression in `branch_progressions` table.

---

## File Reference

| File | Purpose |
|------|---------|
| `linked_service.dart` | API communication, match management |
| `side_quest_service_base.dart` | Common side quest logic |
| `linked.dart` | Match, puzzle, clue models (incl. `text` field for hints) |
| `linked_game_screen.dart` | Main game UI with grid, rack, clue rendering |
| `linked_completion_screen.dart` | End-of-puzzle celebration |
| `answer_cell.dart` | Individual grid cell widget |
| `turn_complete_dialog.dart` | Dialog after turn submission |
| `partner_first_dialog.dart` | Dialog when entering on partner's turn |
| `game_polling_mixin.dart` | Standardized polling logic |
| `api/app/api/sync/linked/route.ts` | API route with `getPuzzleForClient()` (handles dual clues) |
| `docs/PUZZLE_JSON_FORMAT_UPDATE.md` | Full JSON format specification |

---

## LinkedClue Model

```dart
class LinkedClue {
  final int number;        // Clue number
  final String type;       // 'text' or 'emoji'
  final String content;    // Clue text or emoji
  final String? text;      // Optional text hint for emoji clues (e.g., "_SS")
  final String arrow;      // 'across' or 'down'
  final int targetIndex;   // Grid index where answer starts
  final int length;        // Number of letters in answer

  bool get hasTextHint => type == 'emoji' && text != null && text!.isNotEmpty;
}
```

**Factory methods:**
- `LinkedClue.fromJson()` - Parse single-direction format
- `LinkedClue.fromJsonDirection()` - Parse dual-direction format

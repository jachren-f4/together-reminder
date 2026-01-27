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
| Puzzle Order (legacy) | `api/data/puzzles/linked/{branch}/puzzle-order.json` |
| Puzzle Order (v2) | `api/data/puzzles/linked/{branch}/puzzle-order-v2.json` |

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

## Grid Size Progression

New players start with smaller, easier puzzles and graduate to larger ones:

### Progression Order

| # | Puzzle IDs | Grid Size | Difficulty |
|---|------------|-----------|------------|
| 1-4 | `puzzle_5x7_001` - `puzzle_5x7_004` | 5×7 (35 cells) | Easy |
| 5-8 | `puzzle_6x8_001` - `puzzle_6x8_004` | 6×8 (48 cells) | Medium |
| 9+ | `puzzle_001` onwards | 7×9 (63 cells) | Full |

### How It Works

1. **Client** sends `gridProgression: true` in POST request:
   ```dart
   // linked_service.dart
   final response = await apiRequest(
     'POST',
     '/api/sync/linked',
     body: { 'gridProgression': true },
   );
   ```

2. **Server** checks the flag and loads the appropriate puzzle order:
   ```typescript
   // route.ts
   const orderFileName = gridProgression
     ? 'puzzle-order-v2.json'   // 5×7 → 6×8 → 7×9
     : 'puzzle-order.json';      // 7×9 only (legacy)
   ```

3. **Puzzle order files** define the sequence:
   ```
   api/data/puzzles/linked/{branch}/puzzle-order-v2.json  // New progression
   api/data/puzzles/linked/{branch}/puzzle-order.json     // Legacy (7×9 first)
   ```

### Puzzle JSON Format

All puzzle sizes use the same JSON format. The `size` field determines dimensions:

```json
{
  "size": {
    "rows": 7,    // Height (y-axis)
    "cols": 5     // Width (x-axis)
  },
  "grid": [
    ".", ".", ".", ".", ".",     // Row 0 (5 cells)
    ".", "C", "A", "T", "S",     // Row 1
    ".", "O", ".", "O", "T",     // Row 2
    ".", "C", "O", "L", "A",     // Row 3
    ".", "A", "S", ".", "M",     // Row 4
    ".", ".", "L", "A", "P",     // Row 5
    ".", "D", "O", "E", "S"      // Row 6
  ],
  "gridnums": [ ... ],           // 35 numbers for 5×7
  "clues": { ... },
  "puzzleId": "puzzle_5x7_001"
}
```

**Grid array layout:** Row-major order, `grid[row * cols + col]`

### Supported Sizes

| Size | Cells | Use Case |
|------|-------|----------|
| 5×7 | 35 | Starter puzzles for new players |
| 6×8 | 48 | Intermediate difficulty |
| 7×9 | 63 | Standard full-size puzzles |

The game screen automatically adapts to any grid size - cell dimensions and layout are calculated from `puzzle.size`.

### File Locations

```
api/data/puzzles/linked/
├── casual/
│   ├── puzzle-order.json      # Legacy order (7×9 first)
│   ├── puzzle-order-v2.json   # New progression (5×7 → 6×8 → 7×9)
│   ├── puzzle_5x7_001.json    # Starter puzzles
│   ├── puzzle_5x7_002.json
│   ├── puzzle_5x7_003.json
│   ├── puzzle_5x7_004.json
│   ├── puzzle_6x8_001.json    # Medium puzzles
│   ├── puzzle_6x8_002.json
│   ├── puzzle_6x8_003.json
│   ├── puzzle_6x8_004.json
│   ├── puzzle_001.json        # Full-size puzzles
│   └── ...
├── romantic/
│   └── (same structure)
└── adult/
    └── (same structure)
```

### Adding New Puzzle Sizes

To add a new size (e.g., 8×10):

1. **Create puzzle JSON** with correct `size.rows` and `size.cols`
2. **Name consistently:** `puzzle_8x10_001.json`
3. **Update `puzzle-order-v2.json`** to include new puzzles in desired position
4. **Copy to all branches** (casual, romantic, adult)

The game screen handles any rectangular grid - no code changes needed.

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

## Importing Puzzles from Crossword Builder

### Source Location
Puzzles are generated using Crossword Maker GPT and stored at:
```
/Users/joakimachren/Desktop/crosswordmaker_gpt/output/puzzle-{NNN}/
```

Each puzzle folder contains:
- `puzzle_{NNN}.json` - The puzzle data (this is what we import)
- `puzzle_{NNN}.html` - HTML preview
- `grid.html` - Grid visualization
- `state.json` - Internal builder state (not needed)

### Import Mapping

The source uses different numbering than our system. Track the mapping here:

#### 5×7 Starter Puzzles (all branches)
| Source | Our System | Size | Imported |
|--------|------------|------|----------|
| puzzle-126 | puzzle_5x7_002 | 5×7 | ✅ |
| puzzle-128 | puzzle_5x7_003 | 5×7 | ✅ |
| puzzle-129 | puzzle_5x7_004 | 5×7 | ✅ |

*Note: puzzle_5x7_001 was created manually*

#### 6×8 Medium Puzzles (all branches)
| Source | Our System | Size | Imported |
|--------|------------|------|----------|
| puzzle-136 | puzzle_6x8_001 | 6×8 | ✅ |
| puzzle-137 | puzzle_6x8_002 | 6×8 | ✅ |
| puzzle-138 | puzzle_6x8_003 | 6×8 | ✅ |
| puzzle-139 | puzzle_6x8_004 | 6×8 | ✅ |

#### 7×9 Full-Size Puzzles (romantic branch)
| Source (crosswordmaker_gpt) | Our System (romantic branch) | Imported |
|-----------------------------|------------------------------|----------|
| puzzle-001 to puzzle-046 | puzzle_001 to puzzle_034 | ✅ |
| puzzle-047 | puzzle_035 | ✅ |
| puzzle-048 | puzzle_036 | ✅ |
| puzzle-049 | puzzle_037 | ✅ |
| puzzle-050 | puzzle_038 | ✅ |
| puzzle-051 | puzzle_039 | ✅ |
| puzzle-069 | puzzle_040 | ✅ |
| puzzle-070 | puzzle_041 | ✅ |
| puzzle-071 | puzzle_042 | ✅ |
| puzzle-072 | puzzle_043 | ✅ |
| puzzle-073 | puzzle_044 | ✅ |
| puzzle-074 | puzzle_045 | ✅ |
| puzzle-075 | puzzle_046 | ✅ |
| puzzle-076 | puzzle_047 | ✅ |
| puzzle-077 | puzzle_048 | ✅ |
| puzzle-078 | puzzle_049 | ✅ |
| puzzle-097 | puzzle_050 | ✅ |
| puzzle-098 | puzzle_051 | ✅ |
| puzzle-099 | puzzle_052 | ✅ |
| puzzle-100 | puzzle_053 | ✅ |
| puzzle-102 | puzzle_054 | ✅ |
| puzzle-104 | puzzle_055 | ✅ |
| puzzle-107 | puzzle_056 | ✅ |
| puzzle-108 | puzzle_057 | ✅ |
| puzzle-117 | puzzle_058 | ✅ |
| puzzle-119 | puzzle_059 | ✅ |

**Next puzzle to import:** Source puzzle-120 → puzzle_060

### Import Steps

1. **Check available puzzles:**
   ```bash
   # List source folders with JSON files
   for dir in /Users/joakimachren/Desktop/crosswordmaker_gpt/output/puzzle-*; do
     if ls "$dir"/*.json 2>/dev/null | grep -qv state.json; then
       echo "$(basename $dir): $(ls "$dir"/*.json | grep -v state.json)"
     fi
   done
   ```

2. **Copy and rename:**
   ```bash
   cd /Users/joakimachren/Desktop/togetherremind/api/data/puzzles/linked/romantic
   cp /Users/joakimachren/Desktop/crosswordmaker_gpt/output/puzzle-{SOURCE}/puzzle_{SOURCE}.json puzzle_{TARGET}.json
   ```

3. **Update puzzleId in the JSON:**
   ```bash
   sed -i '' 's/"puzzleId": "puzzle_{SOURCE}"/"puzzleId": "puzzle_{TARGET}"/' puzzle_{TARGET}.json
   ```

4. **Update puzzle-order.json:**
   Add the new puzzle ID to the array in `puzzle-order.json`.

5. **Update this mapping table** with the new entry.

### Format Notes

The JSON format from Crossword Maker GPT is **identical** to our system format. No transformation needed beyond:
- Renaming the file
- Updating the `puzzleId` field inside the JSON

### Emoji Enhancement

After importing puzzles, review text clues for emoji opportunities. Good emoji candidates are:

| Text Clue Pattern | Emoji | Answer Examples |
|-------------------|-------|-----------------|
| Card suit, Hearts | ❤️ | HEARTS |
| Oak, Tree | 🌳 | TREE |
| Foot part | 🦶 | TOE |
| Child, Son | 👦 | SON, KID |
| Fiery, Hot | 🔥 | ARDENT, HEATED |
| Basket | 🧺 | CRATE, HAMPER |
| Riches, Wealth | 💰 | WEALTH, MONEY |
| Wall art, Picture | 🖼️ | MURAL |
| Horses | 🐴 | MARES, STEEDS |
| Frost, Ice | ❄️ | ICE |
| Jewel, Gem | 💎 | GEM, GEMS |
| Mouse, Rodent | 🐭 | RODENT |
| Stadium, Arena | 🏟️ | ARENA |
| Sofa, Couch | 🛋️ | SETTEE, COUCH |
| Steps, Stairs | 🪜 | TREADS, STAIR |
| Gift, Present | 🎁 | TALENT, AWARD |
| Stop, Halt | 🛑 | END, HALT |
| Barrel, Keg | 🛢️ | KEG |
| Legume, Pea | 🫛 | PEA |
| Home, House | 🏠 | DIGS, ABODE |
| Cubes, Ice | 🧊 | ICE |
| Brew, Beer | 🍺 | ALE, TEA |
| Fete, Party | 🎉 | GALA |
| Feast, Meal | 🍽️ | GALA, MEAL |

**To convert a text clue to emoji:**
```json
// Before
{ "type": "text", "content": "Jewel", "arrow": "across", "target_index": 22 }

// After
{ "type": "emoji", "content": "💎", "arrow": "across", "target_index": 22 }
```

**Emojis added to puzzles 035-049 (Jan 2026):**
- puzzle_035: ❤️, 🌳, 🦶
- puzzle_036: 👦
- puzzle_037: 🧺, 🔥
- puzzle_038: 💰
- puzzle_039: 🖼️, 🐴
- puzzle_040: 🐜, 🍵 (original)
- puzzle_041: 👽 (original), ❄️, 💎
- puzzle_042: 🍵, 🇨🇦 (original), 🌳, 🐭
- puzzle_043: 🎵 (original)
- puzzle_044: 🇪🇺 (original), 🏟️, 🛋️, 🪜
- puzzle_045: 🎁, 🛑, 🛢️
- puzzle_046: 🫛, 💎
- puzzle_047: 🏠 (×2), 🧊
- puzzle_048: 🍺, 🎉
- puzzle_049: 🛋️, 🍽️

**Emojis added to puzzles 005-034 (Jan 2026):**
- puzzle_005: 🖼️ (Gallery piece), 🏰 (Palace)
- puzzle_014: 🐢 (Turtle), 💋 (Mwah!)
- puzzle_019: 🌹 (Roses)
- puzzle_020: 🦌 (Deer), 🥚 (Eggs), 🤡 (Clown)
- puzzle_022: 🏖️ (Beach)
- puzzle_024: ❄️ (Frost), 🍞 (Bread)
- puzzle_027: 🍷 (Merlot)
- puzzle_030: 🏨 (Inn)
- puzzle_032: ❤️ (Heart)
- puzzle_033: 🌳 (Shade tree), 😊 (Grins)

**Emojis added to puzzles 050-059 (Jan 2026):**
- puzzle_050: 🫧 (Bubbles), 🪿 (Goose)
- puzzle_052: 👻 (Ghost!)
- puzzle_053: ⛸️ (Rink)

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

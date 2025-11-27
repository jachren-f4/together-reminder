# Word Search Game - Implementation Plan

**Status:** Draft
**Based on:** Linked Game Architecture
**Date:** 2025-11-26

---

> **⚠️ IMPORTANT: Visual Reference**
>
> Before implementing the UI, **open and interact with the HTML mockup**:
> ```
> mockups/wordsearch/word-search-game.html
> ```
>
> This mockup demonstrates:
> - Exact visual styling (colors, typography, spacing)
> - Touch/click selection behavior
> - Floating selection bubble
> - Word bank layout and found-word styling
> - Turn progress indicator
> - Animations (word found overlay, floating points, shake on invalid)
> - Completion screen
>
> **Open it in a browser and click through all interactions before coding.**

---

## Table of Contents

1. [Game Overview](#1-game-overview)
2. [Database Schema](#2-database-schema)
3. [API Endpoints](#3-api-endpoints)
4. [Puzzle Data Format](#4-puzzle-data-format)
5. [Flutter Models](#5-flutter-models)
6. [Flutter Service](#6-flutter-service)
7. [Flutter UI](#7-flutter-ui)
8. [Turn Flow](#8-turn-flow)
9. [Implementation Phases](#9-implementation-phases)

---

## 1. Game Overview

### Core Mechanics

| Aspect | Specification |
|--------|---------------|
| Grid Size | 10x10 |
| Total Words | 12 |
| Words Per Turn | 3 (mandatory) |
| Total Turns | 4 (2 per player) |
| Turn Order | Alternating (Alice → Bob → Alice → Bob) |
| Yield/Skip | Not allowed - must find 3 words |
| Hints | 2-3 per player (reveals first letter position) |

### Key Differences from Linked Game

| Linked Game | Word Search |
|-------------|-------------|
| Place letters from rack | Select letters on grid |
| Letters locked one-by-one | Words locked as complete units |
| Clue cells guide placement | Word list guides search |
| Rack replenishes each turn | Grid is static |
| Points per letter + word bonus | Points per word found |

### Collaboration Pattern

When stuck, players reach out to partner outside the app (screenshot via WhatsApp, etc.) to fulfill their 3-word requirement. This creates organic conversation moments.

---

## 2. Database Schema

### Supabase Migration: `word_search_matches`

```sql
-- Migration: 0XX_word_search_game.sql

CREATE TABLE word_search_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  puzzle_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed')),

  -- Game state
  found_words JSONB NOT NULL DEFAULT '[]',           -- Array of {word, foundBy, turnNumber}
  current_turn_user_id UUID,
  turn_number INT NOT NULL DEFAULT 1,
  words_found_this_turn INT NOT NULL DEFAULT 0,      -- 0-3, resets each turn

  -- Scores (words found count)
  player1_words_found INT NOT NULL DEFAULT 0,
  player2_words_found INT NOT NULL DEFAULT 0,

  -- Hints
  player1_hints INT NOT NULL DEFAULT 3,
  player2_hints INT NOT NULL DEFAULT 3,

  -- Players (denormalized for query efficiency)
  player1_id UUID NOT NULL,
  player2_id UUID NOT NULL,

  -- Completion
  winner_id UUID,                                    -- Who found more (or tie)

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,

  -- Constraints
  UNIQUE(couple_id, puzzle_id)                       -- One active match per puzzle per couple
);

-- Move audit trail
CREATE TABLE word_search_moves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES word_search_matches(id) ON DELETE CASCADE,
  player_id UUID NOT NULL,
  words_found JSONB NOT NULL,                        -- Array of words found this turn
  turn_number INT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_word_search_matches_couple ON word_search_matches(couple_id);
CREATE INDEX idx_word_search_matches_status ON word_search_matches(status);
CREATE INDEX idx_word_search_moves_match ON word_search_moves(match_id);

-- RLS Policies (similar to linked_matches)
ALTER TABLE word_search_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE word_search_moves ENABLE ROW LEVEL SECURITY;
```

### Found Words JSONB Structure

```json
[
  {
    "word": "FOREPLAY",
    "foundBy": "user-uuid-123",
    "turnNumber": 1,
    "positions": [
      {"row": 0, "col": 9},
      {"row": 0, "col": 8},
      ...
    ],
    "colorIndex": 0
  },
  ...
]
```

---

## 3. API Endpoints

### Route Structure

```
/api/sync/word-search/
├── route.ts           # GET (poll) / POST (create or get match)
├── [matchId]/
│   └── route.ts       # GET (poll specific match)
├── submit/
│   └── route.ts       # POST (submit found word)
└── hint/
    └── route.ts       # POST (use hint)
```

### POST `/api/sync/word-search` - Get or Create Match

**Request:** (user from auth header)

**Response:**
```typescript
{
  success: true,
  isNewMatch: boolean,
  match: {
    matchId: string,
    puzzleId: string,
    status: 'active' | 'completed',
    foundWords: FoundWord[],
    currentTurnUserId: string,
    turnNumber: number,
    wordsFoundThisTurn: number,
    player1WordsFound: number,
    player2WordsFound: number,
    player1Hints: number,
    player2Hints: number,
    player1Id: string,
    player2Id: string,
    createdAt: string,
    completedAt: string | null
  },
  puzzle: {
    puzzleId: string,
    title: string,
    grid: string[][],              // 10x10 letter grid
    words: string[],               // 12 target words (no positions - client finds them)
    size: { rows: 10, cols: 10 }
  },
  gameState: {
    isMyTurn: boolean,
    canPlay: boolean,
    wordsRemainingThisTurn: number,  // 3 - wordsFoundThisTurn
    myWordsFound: number,
    partnerWordsFound: number,
    myHints: number,
    partnerHints: number,
    progressPercent: number          // foundWords.length / 12 * 100
  }
}
```

### POST `/api/sync/word-search/submit` - Submit Found Word

**Request:**
```typescript
{
  matchId: string,
  word: string,
  positions: Array<{ row: number, col: number }>
}
```

**Response:**
```typescript
{
  success: true,
  valid: boolean,                    // Was the word valid and not already found?
  pointsEarned: number,              // Word length * 10
  wordsFoundThisTurn: number,        // 1, 2, or 3
  turnComplete: boolean,             // true if wordsFoundThisTurn === 3
  gameComplete: boolean,             // true if all 12 words found
  nextTurnUserId: string | null,     // Partner's ID if turn switched
  colorIndex: number,                // Color for this word's highlight
  winnerId: string | null            // If game complete
}
```

**Server Validation:**
1. Check it's the player's turn
2. Check word is in puzzle's word list
3. Check word not already found
4. Validate positions trace the word correctly
5. Lock word, update counts
6. If 3rd word this turn: switch turns, reset counter
7. If 12th word total: complete game, determine winner

### POST `/api/sync/word-search/hint` - Use Hint

**Request:**
```typescript
{
  matchId: string
}
```

**Response:**
```typescript
{
  success: true,
  hint: {
    word: string,                    // A random unfound word
    firstLetterPosition: { row: number, col: number }
  },
  hintsRemaining: number
}
```

### GET `/api/sync/word-search/[matchId]` - Poll Match State

Same response as POST create, used for polling during partner's turn.

---

## 4. Puzzle Data Format

### File Location

```
/api/data/puzzles/word-search/
├── ws_001.json
├── ws_002.json
├── ...
└── puzzle-order.json
```

### Puzzle JSON Structure (Compact Format)

Follows the same pattern as Linked puzzles: flat grid string + index-based positions.

```json
{
  "puzzleId": "ws_001",
  "title": "Intimate Connections",
  "theme": "intimate",
  "size": { "rows": 10, "cols": 10 },
  "grid": "SXYALPEROFVNEROTICSKIMPULSELUBNSKLIABECTANGUEVIXLIGNISATIOIORNAKSOFTMAOELIUPURACSLUSTORNXYBDESIRESE",
  "words": {
    "FOREPLAY": "9,L",
    "INTIMACY": "20,D",
    "EROTIC": "15,R",
    "DESIRE": "93,R",
    "LUST": "83,R",
    "CLIMAX": "99,U",
    "SENSUAL": "45,DR",
    "ORGASM": "71,UL",
    "PLEASURE": "52,DR",
    "PASSION": "5,DL",
    "ROMANCE": "18,D",
    "TENDER": "34,DR"
  }
}
```

### Grid String Format

- **100 characters** for 10x10 grid
- Read left-to-right, top-to-bottom
- Index calculation: `index = (row * cols) + col`

```
Index:  0  1  2  3  4  5  6  7  8  9
        S  X  Y  A  L  P  E  R  O  F   (row 0)
       10 11 12 13 14 15 16 17 18 19
        V  N  E  R  O  T  I  C  S  K   (row 1)
       20 21 22 23 24 25 26 27 28 29
        I  M  P  U  L  S  E  L  U  B   (row 2)
       ...
```

### Word Position Format

Each word value is `"startIndex,direction"`:

| Direction | Code | Index Delta |
|-----------|------|-------------|
| Right | `R` | +1 |
| Left | `L` | -1 |
| Down | `D` | +cols (+10) |
| Up | `U` | -cols (-10) |
| Diagonal down-right | `DR` | +cols+1 (+11) |
| Diagonal down-left | `DL` | +cols-1 (+9) |
| Diagonal up-right | `UR` | -cols+1 (-9) |
| Diagonal up-left | `UL` | -cols-1 (-11) |

**Example:** `"FOREPLAY": "9,L"` means:
- Start at index 9 (letter F in row 0)
- Go Left (-1 each step)
- Positions: 9 → 8 → 7 → 6 → 5 → 4 → 3 → 2
- Spells: F-O-R-E-P-L-A-Y

### Server-Side Helper Functions

```typescript
// Direction deltas for a 10-column grid
const DIRECTION_DELTAS: Record<string, number> = {
  'R': 1, 'L': -1, 'D': 10, 'U': -10,
  'DR': 11, 'DL': 9, 'UR': -9, 'UL': -11
};

// Get all indices for a word
function getWordIndices(startIndex: number, direction: string, length: number): number[] {
  const delta = DIRECTION_DELTAS[direction];
  return Array.from({ length }, (_, i) => startIndex + (i * delta));
}

// Convert index to row/col (for client response)
function indexToPosition(index: number, cols: number): { row: number, col: number } {
  return {
    row: Math.floor(index / cols),
    col: index % cols
  };
}

// Validate player's selection matches word position
function validateSelection(
  word: string,
  playerPositions: Array<{ row: number, col: number }>,
  puzzle: WordSearchPuzzle
): boolean {
  const [startIndex, direction] = puzzle.words[word].split(',');
  const expectedIndices = getWordIndices(parseInt(startIndex), direction, word.length);
  const expectedPositions = expectedIndices.map(i => indexToPosition(i, puzzle.size.cols));

  // Check positions match (in order)
  return playerPositions.every((pos, i) =>
    pos.row === expectedPositions[i].row && pos.col === expectedPositions[i].col
  );
}
```

### Client-Side Grid Access

```dart
// In WordSearchPuzzle class
String letterAt(int row, int col) {
  final index = (row * cols) + col;
  return grid[index];
}

// Or with index directly
String letterAtIndex(int index) => grid[index];
```

### What Client Receives vs Server Stores

| Data | Client | Server |
|------|--------|--------|
| Grid | Full string (100 chars) | Full string |
| Word list | Array of words only | Word + positions |
| Positions | Must discover by selection | Used for validation |

**Client response (stripped positions):**
```json
{
  "puzzle": {
    "puzzleId": "ws_001",
    "title": "Intimate Connections",
    "size": { "rows": 10, "cols": 10 },
    "grid": "SXYALPEROF...",
    "words": ["FOREPLAY", "INTIMACY", "EROTIC", ...]
  }
}
```

### File Size Comparison

| Format | Size |
|--------|------|
| Verbose (2D array + position objects) | ~2,000 bytes |
| Compact (flat string + index,direction) | ~500 bytes |
| **Savings** | **~75%** |

---

## 5. Flutter Models

### File: `lib/models/word_search.dart`

```dart
import 'package:hive/hive.dart';

part 'word_search.g.dart';

// ============================================
// FOUND WORD (embedded in match)
// ============================================

@HiveType(typeId: 25)  // Next available after LinkedMatch (23) and LinkedMove (24)
class WordSearchFoundWord extends HiveObject {
  @HiveField(0)
  late String word;

  @HiveField(1)
  late String foundByUserId;

  @HiveField(2)
  late int turnNumber;

  @HiveField(3, defaultValue: [])
  List<Map<String, int>> positions;  // [{row: 0, col: 5}, ...]

  @HiveField(4, defaultValue: 0)
  int colorIndex;
}

// ============================================
// MATCH (persisted in Hive)
// ============================================

@HiveType(typeId: 26)
class WordSearchMatch extends HiveObject {
  @HiveField(0)
  late String matchId;

  @HiveField(1)
  late String puzzleId;

  @HiveField(2, defaultValue: 'active')
  String status;

  @HiveField(3, defaultValue: [])
  List<WordSearchFoundWord> foundWords;

  @HiveField(4)
  String? currentTurnUserId;

  @HiveField(5, defaultValue: 1)
  int turnNumber;

  @HiveField(6, defaultValue: 0)
  int wordsFoundThisTurn;

  @HiveField(7, defaultValue: 0)
  int player1WordsFound;

  @HiveField(8, defaultValue: 0)
  int player2WordsFound;

  @HiveField(9, defaultValue: 3)
  int player1Hints;

  @HiveField(10, defaultValue: 3)
  int player2Hints;

  @HiveField(11)
  late String player1Id;

  @HiveField(12)
  late String player2Id;

  @HiveField(13)
  String? winnerId;

  @HiveField(14)
  late DateTime createdAt;

  @HiveField(15)
  DateTime? completedAt;

  // Helpers
  bool get isCompleted => status == 'completed';
  int get totalWordsFound => foundWords.length;
  int get wordsRemainingThisTurn => 3 - wordsFoundThisTurn;
  double get progressPercent => totalWordsFound / 12.0;
}

// ============================================
// PUZZLE (runtime only, not persisted)
// ============================================

class WordSearchPuzzle {
  final String puzzleId;
  final String title;
  final String? theme;
  final int rows;
  final int cols;
  final String grid;           // Flat string, 100 chars for 10x10
  final List<String> words;    // Just the words, no positions (client must find)

  WordSearchPuzzle({
    required this.puzzleId,
    required this.title,
    this.theme,
    required this.rows,
    required this.cols,
    required this.grid,
    required this.words,
  });

  factory WordSearchPuzzle.fromJson(Map<String, dynamic> json) {
    final size = json['size'] as Map<String, dynamic>;

    return WordSearchPuzzle(
      puzzleId: json['puzzleId'],
      title: json['title'],
      theme: json['theme'],
      rows: size['rows'],
      cols: size['cols'],
      grid: json['grid'] as String,
      words: (json['words'] as List<dynamic>).cast<String>(),
    );
  }

  // Get letter at row/col
  String letterAt(int row, int col) {
    final index = (row * cols) + col;
    return grid[index];
  }

  // Get letter at flat index
  String letterAtIndex(int index) => grid[index];

  // Convert index to row/col
  ({int row, int col}) indexToPosition(int index) {
    return (row: index ~/ cols, col: index % cols);
  }

  // Convert row/col to index
  int positionToIndex(int row, int col) => (row * cols) + col;
}

// ============================================
// CARD STATE (for home screen widget)
// ============================================

enum WordSearchCardState {
  yourTurnFresh,           // Your turn, 0 words found this turn
  yourTurnInProgress,      // Your turn, 1-2 words found this turn
  partnerTurnFresh,        // Partner's turn, waiting
  partnerTurnInProgress,   // Partner's turn, polling
  completed,               // All 12 words found
}

// ============================================
// GAME STATE (combined API response)
// ============================================

class WordSearchGameState {
  final WordSearchMatch match;
  final WordSearchPuzzle? puzzle;
  final bool isMyTurn;
  final bool canPlay;
  final int wordsRemainingThisTurn;
  final int myWordsFound;
  final int partnerWordsFound;
  final int myHints;
  final int partnerHints;
  final int progressPercent;

  WordSearchGameState({
    required this.match,
    this.puzzle,
    required this.isMyTurn,
    required this.canPlay,
    required this.wordsRemainingThisTurn,
    required this.myWordsFound,
    required this.partnerWordsFound,
    required this.myHints,
    required this.partnerHints,
    required this.progressPercent,
  });
}
```

---

## 6. Flutter Service

### File: `lib/services/word_search_service.dart`

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/word_search.dart';
import '../config/api_config.dart';
import 'auth_service.dart';
import 'storage_service.dart';

class WordSearchService {
  static final WordSearchService _instance = WordSearchService._internal();
  factory WordSearchService() => _instance;
  WordSearchService._internal();

  final String _baseUrl = '${ApiConfig.baseUrl}/api/sync/word-search';

  // ============================================
  // GET OR CREATE MATCH
  // ============================================

  Future<WordSearchGameState> getOrCreateMatch() async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: await AuthService().getAuthHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get/create match: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final match = _parseMatch(data['match']);
    final puzzle = data['puzzle'] != null
      ? WordSearchPuzzle.fromJson(data['puzzle'])
      : null;

    // Cache locally
    await StorageService().saveWordSearchMatch(match);

    return WordSearchGameState(
      match: match,
      puzzle: puzzle,
      isMyTurn: data['gameState']['isMyTurn'],
      canPlay: data['gameState']['canPlay'],
      wordsRemainingThisTurn: data['gameState']['wordsRemainingThisTurn'],
      myWordsFound: data['gameState']['myWordsFound'],
      partnerWordsFound: data['gameState']['partnerWordsFound'],
      myHints: data['gameState']['myHints'],
      partnerHints: data['gameState']['partnerHints'],
      progressPercent: data['gameState']['progressPercent'],
    );
  }

  // ============================================
  // POLL MATCH STATE
  // ============================================

  Future<WordSearchGameState> pollMatchState(String matchId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/$matchId'),
      headers: await AuthService().getAuthHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to poll match: ${response.body}');
    }

    final data = jsonDecode(response.body);
    // ... same parsing as getOrCreateMatch
  }

  // ============================================
  // SUBMIT FOUND WORD
  // ============================================

  Future<WordSearchSubmitResult> submitWord({
    required String matchId,
    required String word,
    required List<Map<String, int>> positions,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/submit'),
      headers: {
        ...await AuthService().getAuthHeaders(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'matchId': matchId,
        'word': word,
        'positions': positions,
      }),
    );

    if (response.statusCode == 403) {
      throw NotYourTurnException();
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to submit word: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return WordSearchSubmitResult(
      valid: data['valid'],
      pointsEarned: data['pointsEarned'],
      wordsFoundThisTurn: data['wordsFoundThisTurn'],
      turnComplete: data['turnComplete'],
      gameComplete: data['gameComplete'],
      colorIndex: data['colorIndex'],
      winnerId: data['winnerId'],
    );
  }

  // ============================================
  // USE HINT
  // ============================================

  Future<WordSearchHintResult> useHint(String matchId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/hint'),
      headers: {
        ...await AuthService().getAuthHeaders(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'matchId': matchId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to use hint: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return WordSearchHintResult(
      word: data['hint']['word'],
      firstLetterPosition: data['hint']['firstLetterPosition'],
      hintsRemaining: data['hintsRemaining'],
    );
  }

  // ============================================
  // HELPERS
  // ============================================

  WordSearchMatch _parseMatch(Map<String, dynamic> json) {
    // ... parse JSON to WordSearchMatch
  }
}

// Result classes
class WordSearchSubmitResult {
  final bool valid;
  final int pointsEarned;
  final int wordsFoundThisTurn;
  final bool turnComplete;
  final bool gameComplete;
  final int colorIndex;
  final String? winnerId;

  WordSearchSubmitResult({...});
}

class WordSearchHintResult {
  final String word;
  final Map<String, int> firstLetterPosition;
  final int hintsRemaining;

  WordSearchHintResult({...});
}

class NotYourTurnException implements Exception {}
```

---

## 7. Flutter UI - Detailed Visual Specification

> **📱 Live Reference:** Open `mockups/wordsearch/word-search-game.html` in a browser alongside this spec. The mockup is the source of truth for visual behavior.

### Overview

The Word Search game screen follows the Linked game's visual patterns exactly for consistency across the app. The screen is divided into four main sections stacked vertically:

1. **Header** - Navigation, title, and scores
2. **Game Area** - The 10x10 letter grid with selection overlay
3. **Word Bank** - List of 12 target words to find
4. **Bottom Bar** - Hint button and turn progress indicator

---

### Color System (via BrandLoader)

| Color Token | Hex Value | Usage |
|-------------|-----------|-------|
| `surface` | #FFFFFF | Header bg, game area bg, word bank bg, bottom bar bg |
| `background` | #1A1A1A | (Not used - grid area is now white) |
| `textPrimary` | #1A1A1A | Main text, header border, cell borders |
| `textSecondary` | #666666 | Secondary labels, cell borders, inactive states |
| `textTertiary` | #999999 | Tertiary text |
| `textOnPrimary` | #FFFFFF | Text on colored backgrounds |
| `success` | #4CAF50 | Active turn indicator, found word overlay, correct feedback |
| `error` | #F44336 | Invalid selection feedback |
| `warning` | #FF9800 | Current selection highlight (orange tint) |
| `info` | #2196F3 | Hint highlights (blue tint) |
| `borderLight` | #E0E0E0 | Grid gaps, word bank borders |
| `divider` | #E0E0E0 | Section dividers |
| `disabled` | #BDBDBD | Disabled button states |

**Found Word Color Rotation:**
| Index | Color | Hex |
|-------|-------|-----|
| 0 | Indigo | #5C6BC0 |
| 1 | Green | #66BB6A |
| 2 | Orange | #FFA726 |
| 3 | Purple | #AB47BC |
| 4 | Red | #EF5350 |

---

### Typography (Georgia Font Family)

| Element | Font Size | Weight | Letter Spacing | Color |
|---------|-----------|--------|----------------|-------|
| Header title "WORD SEARCH" | 18px | 400 | 2px | textPrimary |
| Back button "←" | 20px | 400 | - | textPrimary |
| Score labels "You: 3" | 13px | 400 (inactive) / 700 (active) | - | textPrimary |
| Grid letters | 18px | 700 | - | textPrimary |
| Floating bubble text | 16px | 600 | 2px | textOnPrimary |
| Word bank title | 10px | 400 | 1px | textSecondary |
| Word bank items | 11px | 600 | 1px | textPrimary / found color |
| Hint button text | 11px | 600 | 1px | textPrimary |
| Turn progress text | 11px | 600 | 1px | textOnPrimary |
| Floating points "+80" | 16px | bold | - | textOnPrimary |
| Word overlay "FOREPLAY +80" | 20px | bold | - | textOnPrimary |

---

### Section 1: Header

**Visual Appearance:**
```
┌─────────────────────────────────────────────────────────┐
│  ←   WORD SEARCH                    • You: 3   They: 2  │
└─────────────────────────────────────────────────────────┘
     │        │                       │    │        │
     │        │                       │    │        └── Partner score (13px, w400)
     │        │                       │    └── Your score (13px, w700 bold)
     │        │                       └── Green dot (6x6px, success color)
     │        └── Title (18px, w400, letterSpacing 2)
     └── Back button (20px)
```

**Specifications:**
- **Background:** `surface` (white)
- **Padding:** 16px horizontal, 12px vertical
- **Bottom border:** 2px solid `textPrimary`
- **Layout:** Row with spacer between title and scores

**Score Display:**
- Active player has green dot (6x6px circle) + bold text (w700)
- Inactive player has normal weight text (w400)
- Gap between scores: 16px

**Code Structure:**
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  decoration: BoxDecoration(
    color: BrandLoader().colors.surface,
    border: Border(bottom: BorderSide(
      color: BrandLoader().colors.textPrimary,
      width: 2,
    )),
  ),
  child: Row(children: [
    // Back button
    GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Text('←', style: TextStyle(fontSize: 20)),
    ),
    SizedBox(width: 12),
    // Title
    Text('WORD SEARCH', style: TextStyle(
      fontSize: 18, fontWeight: FontWeight.w400,
      letterSpacing: 2, fontFamily: 'Georgia',
    )),
    Spacer(),
    // Scores
    _buildScoreDisplay(),
  ]),
)
```

---

### Section 2: Game Area

**Visual Appearance:**
```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│                    [FOREPL]                             │  ← Floating bubble
│                                                         │
│    ┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐          │
│    │ S │ X │ Y │ A │ L │ P │ E │ R │ O │ F │          │
│    ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤          │
│    │ V │ N │ E │ R │ O │ T │ I │ C │ S │ K │          │
│    ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤          │
│    │ I │ M │ P │ U │ L │ S │ E │ L │ U │ B │          │  ← 10x10 Grid
│    ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤          │
│    │ . │ . │ . │ . │ . │ . │ . │ . │ . │ . │          │
│    └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘          │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Container Specifications:**
- **Background:** `surface` (white)
- **Padding:** 16px all sides
- **No border** around the grid (clean look)

**Floating Selection Bubble:**
- **Position:** Centered horizontally, 16px from top of game area
- **Background:** `textPrimary` (black)
- **Text color:** `textOnPrimary` (white)
- **Padding:** 8px horizontal, 8px vertical
- **Font:** 16px, w600, letterSpacing 2, uppercase
- **Visibility:** Only shown while user is selecting letters
- **Transition:** 150ms opacity fade

**Grid Specifications:**
- **Dimensions:** 10 columns × 10 rows
- **Cell gap:** 2px (shows `borderLight` color between cells)
- **Grid background:** `borderLight` (#E0E0E0) - visible as gaps
- **No outer border** around the entire grid

**Individual Cell:**
- **Aspect ratio:** 1:1 (square)
- **Background:** `surface` (white) - default state
- **Border:** 1.5px solid `textSecondary`
- **Letter:** Centered, 18px, w700, Georgia, `textPrimary`

**Cell States:**

| State | Background | Border | Notes |
|-------|------------|--------|-------|
| **Default** | `surface` (white) | 1.5px `textSecondary` | Normal cell |
| **Selecting** | `warning` @ 20% opacity | 2px `textPrimary` | Currently being selected |
| **Hint Highlight** | `info` @ 20% opacity | 3px `info` | Pulsing animation |
| **Part of Found Word** | `surface` | 1.5px `textSecondary` | Has colored line overlay |

**Selection Line Overlay (SVG):**
- **Stroke width:** 26px
- **Stroke linecap:** round (creates pill shape)
- **During selection:** `warning` color @ 50% opacity
- **Found word:** Rotating colors @ 35% opacity
- **Z-index:** Above cells (10), below floating bubble

---

### Section 3: Word Bank

**Visual Appearance:**
```
┌─────────────────────────────────────────────────────────┐
│  FIND THESE WORDS                              0 / 12   │
│  ┌──────────┬──────────┬──────────┐                     │
│  │ FOREPLAY │ INTIMACY │ PLEASURE │                     │
│  ├──────────┼──────────┼──────────┤                     │
│  │ SENSUAL  │  ORGASM  │  EROTIC  │                     │
│  ├──────────┼──────────┼──────────┤                     │
│  │  CLIMAX  │  DESIRE  │   LUST   │                     │
│  ├──────────┼──────────┼──────────┤                     │
│  │ PASSION  │ ROMANCE  │  TENDER  │                     │
│  └──────────┴──────────┴──────────┘                     │
└─────────────────────────────────────────────────────────┘
```

**Container Specifications:**
- **Background:** `surface` (white)
- **Padding:** 12px horizontal, 12px vertical
- **Bottom border:** 1px solid `divider`

**Title Row:**
- **Left text:** "FIND THESE WORDS" - 10px, uppercase, letterSpacing 1, `textSecondary`
- **Right text:** "X / 12" - same style, shows progress

**Word Grid:**
- **Layout:** 3 columns × 4 rows
- **Gap:** 8px between items
- **Margin top:** 12px below title

**Word Item:**
- **Padding:** 6px vertical, 4px horizontal
- **Border:** 1px solid `borderLight`
- **Background:** `surface` (white)
- **Text:** 11px, w600, uppercase, letterSpacing 1, centered

**Word Item States:**

| State | Text Style | Border | Background |
|-------|------------|--------|------------|
| **Not Found** | `textPrimary` | `borderLight` | `surface` |
| **Found** | Strike-through, rotating color | Same as text color | `surface` |
| **Hinted** | `textPrimary` | `info` | `info` @ 10% opacity |

**Found Word Colors:**
Words cycle through 5 colors in order:
1. Indigo (#5C6BC0)
2. Green (#66BB6A)
3. Orange (#FFA726)
4. Purple (#AB47BC)
5. Red (#EF5350)

Both the line overlay on the grid AND the word in the bank use the same color.

---

### Section 4: Bottom Bar

**Visual Appearance:**
```
┌─────────────────────────────────────────────────────────┐
│  ┌─────────────┐   ┌──────────────────────────────────┐ │
│  │ 💡 Hint (3) │   │      ●●○   2/3 FOUND            │ │
│  └─────────────┘   └──────────────────────────────────┘ │
│       flex: 1              flex: 2                      │
└─────────────────────────────────────────────────────────┘
```

**Container Specifications:**
- **Background:** `surface` (white)
- **Padding:** 16px horizontal, 12px vertical (+ safe area bottom)
- **Top border:** 1px solid `divider`
- **Layout:** Row with 12px gap between buttons

**Hint Button (flex: 1):**
- **Background:** `surface` (white)
- **Border:** 1px solid `textPrimary`
- **Padding:** 12px vertical
- **Content:** Row of [💡 emoji (14px)] + [Hint text (11px, w600)] + [(3) count (9px)]
- **Hover:** Background becomes `textPrimary`, text becomes `textOnPrimary`
- **Disabled:** Border and text become `disabled` color

**Turn Progress (flex: 2):**
- **Background:** `textPrimary` (black) when your turn
- **Background:** `surface` (white) when partner's turn
- **Border:** 1px solid `textPrimary`
- **Padding:** 12px vertical
- **Content:** Row of [Progress dots] + [Status text]

**Progress Dots:**
- **3 dots** representing 0/3, 1/3, 2/3, 3/3 words found this turn
- **Size:** 8px × 8px circles
- **Gap:** 4px between dots
- **Filled dot:** Full opacity (white when your turn, gray when waiting)
- **Empty dot:** 40% opacity

**Status Text:**
- Your turn: "X/3 FOUND" in white
- Partner's turn: "{NAME}'S TURN" in `textSecondary`

---

### Animations

#### 1. Floating Points Animation
**Trigger:** When a word is successfully found
**Duration:** 1200ms

```
Start: opacity 1, translateY 0, scale 0.5
  30%: scale 1.2 (elastic overshoot)
  60%: opacity 1, translateY -20px
 100%: opacity 0, translateY -60px, scale 1
```

**Visual:**
- Green badge (`success` background)
- Text: "+{points}" (e.g., "+80")
- Padding: 4px vertical, 8px horizontal
- Border radius: 12px
- Box shadow: color @ 40% opacity, blur 8px, offset (0, 2)
- Position: Centered over the grid

#### 2. Word Found Overlay
**Trigger:** When a word is successfully found
**Duration:** 1600ms

```
  0%: opacity 0, scale 0.8
 20%: opacity 1, scale 1.0
 80%: opacity 1, scale 1.0
100%: opacity 0, scale 1.0
```

**Visual:**
- Green background (`success`)
- Text: "{WORD} +{points}" (e.g., "FOREPLAY +80")
- Font: Georgia, 20px, bold
- Padding: 12px vertical, 24px horizontal
- Border radius: 8px
- Box shadow: `success` @ 40% opacity, blur 12px, spread 2px
- Position: Centered on game area

#### 3. Selection Line Drawing
**Trigger:** As user drags finger across cells
**Duration:** Immediate (follows finger)

- Line drawn from first selected cell center to last selected cell center
- Color: `warning` @ 50% opacity
- Stroke width: 26px
- Linecap: round

#### 4. Invalid Selection Shake
**Trigger:** When user releases selection that doesn't match any word
**Duration:** 400ms

```
  0%: translateX 0
 20%: translateX 8px
 40%: translateX -6px
 60%: translateX 4px
 80%: translateX -2px
100%: translateX 0
```

Applied to the entire grid container.

#### 5. Hint Pulse
**Trigger:** When hint is used, applied to first letter cell
**Duration:** 1200ms (loops 2-3 times)

```
  0%: scale 1.0
 50%: scale 1.05
100%: scale 1.0
```

- Easing: ease-in-out
- Also applied to the word in the word bank

---

### Completion Screen Overlay

**Trigger:** When all 12 words are found
**Background:** Black @ 90% opacity

**Content (centered vertically):**

1. **Badge Circle**
   - Size: 100px × 100px
   - Border: 4px solid white
   - Content: "✓" checkmark, 48px, white, w300
   - Animation: Pop in with elastic bounce

2. **Title**
   - Text: "COMPLETE"
   - Font: 32px, w400, letterSpacing 4px, white

3. **Subtitle**
   - Text: "PUZZLE FINISHED"
   - Font: 14px, letterSpacing 2px, `textTertiary`

4. **Score Display**
   - Width: 280px
   - Winner row: White background, black text
   - Loser row: Transparent background, white text
   - Padding: 16px per row

5. **Action Buttons**
   - 3 buttons: Home 🏠, Share 📤, Replay 🔄
   - Size: 56px × 56px each
   - Border: 2px solid white
   - Background: Transparent (white on hover)
   - Gap: 12px between buttons

---

### State Management

```dart
class _WordSearchGameScreenState extends State<WordSearchGameScreen> {
  // Game data from API
  WordSearchGameState? _gameState;

  // Selection tracking
  List<GridPosition> _currentSelection = [];
  bool _isSelecting = false;
  String _selectionText = '';  // Displayed in floating bubble

  // Found words (for display)
  final List<FoundWordDisplay> _foundWordsDisplay = [];
  // Each contains: word, positions[], colorIndex

  // Hint state
  int? _hintHighlightIndex;  // Grid index of highlighted cell
  String? _hintedWord;       // Word being hinted

  // Animation state
  bool _showWordOverlay = false;
  String? _overlayWord;
  int? _overlayPoints;
  final List<FloatingPoint> _floatingPoints = [];

  // Polling (during partner's turn)
  Timer? _pollTimer;  // 10-second interval
}
```

---

### Touch Interaction Flow

1. **Touch Start**
   - Record starting cell position
   - Begin selection with single cell
   - Show floating bubble with single letter
   - Highlight cell with `warning` background

2. **Touch Move**
   - Validate next cell is adjacent (including diagonal)
   - Validate direction is consistent (straight line only)
   - If going backward, remove last cell from selection
   - Update floating bubble text
   - Extend selection line

3. **Touch End**
   - Read selected letters as string
   - Also check reversed string (words can be found backwards)
   - If matches unfound word in word list:
     - Submit to API
     - Show floating points animation
     - Show word found overlay
     - Draw permanent colored line
     - Mark word as found in word bank
     - Update turn progress
   - If no match:
     - Play shake animation
     - Clear selection

4. **Turn Complete (3 words found)**
   - Reset `wordsFoundThisTurn` to 0
   - Switch `isMyTurn` to false
   - Update bottom bar to show "{PARTNER}'S TURN"
   - Start 10-second polling timer
   - Send push notification to partner

---

### Home Screen Card: `lib/widgets/word_search_card.dart`

**Card States:**

| State | Badge | Content | Action |
|-------|-------|---------|--------|
| **Your Turn (Fresh)** | "Your Turn" (white) | "Find 3 words to continue" | Tap to play |
| **Your Turn (In Progress)** | "Your Turn" | Progress ●●○, scores | Tap to play |
| **Partner's Turn** | Partner name + 🟢 | "Waiting for {name}" | Polls every 10s |
| **Completed** | "Completed" (black) | Final scores | Shows results |

---

## 8. Turn Flow

### Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        GAME START                               │
│  - API creates match with couple_id, puzzle_id                  │
│  - first_player from couples.first_player_id preference         │
│  - turn_number = 1, words_found_this_turn = 0                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      ALICE'S TURN (Turn 1)                      │
│  - wordsRemainingThisTurn = 3                                   │
│  - Find word → Submit → Server validates → Lock word            │
│  - wordsFoundThisTurn++                                         │
│  - Repeat until wordsFoundThisTurn === 3                        │
│  - Server switches turn to Bob                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              │     NOTIFICATION TO BOB       │
              │   "Your turn in Word Search!" │
              └───────────────┬───────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       BOB'S TURN (Turn 2)                       │
│  - Same flow: find 3 words                                      │
│  - Alice polls every 10s waiting                                │
│  - After 3 words, turn switches back to Alice                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     ALICE'S TURN (Turn 3)                       │
│  - 6 words already found (3 by each)                            │
│  - Alice finds 3 more                                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      BOB'S TURN (Turn 4)                        │
│  - 9 words found                                                │
│  - Bob finds final 3 words                                      │
│  - Server marks game as completed                               │
│  - Winner determined (most words = tie breaker by who finished) │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       GAME COMPLETE                             │
│  - Both players see completion screen                           │
│  - Final scores displayed                                       │
│  - Love Points awarded                                          │
│  - Next puzzle unlocked                                         │
└─────────────────────────────────────────────────────────────────┘
```

### Server-Side Turn Submission Logic

```typescript
// POST /api/sync/word-search/submit

async function submitWord(matchId, userId, word, positions) {
  return await db.transaction(async (tx) => {
    // 1. Lock match row
    const match = await tx.query(
      'SELECT * FROM word_search_matches WHERE id = $1 FOR UPDATE',
      [matchId]
    );

    // 2. Validate turn
    if (match.current_turn_user_id !== userId) {
      throw new ForbiddenError('Not your turn');
    }

    // 3. Validate word exists in puzzle
    const puzzle = loadPuzzle(match.puzzle_id);
    if (!puzzle.words.includes(word)) {
      return { valid: false, reason: 'Word not in puzzle' };
    }

    // 4. Validate not already found
    const foundWords = JSON.parse(match.found_words);
    if (foundWords.some(fw => fw.word === word)) {
      return { valid: false, reason: 'Already found' };
    }

    // 5. Validate positions match word in grid
    if (!validatePositions(puzzle, word, positions)) {
      return { valid: false, reason: 'Invalid positions' };
    }

    // 6. Lock the word
    const colorIndex = foundWords.length % 5;
    foundWords.push({
      word,
      foundBy: userId,
      turnNumber: match.turn_number,
      positions,
      colorIndex
    });

    // 7. Update counts
    const newWordsFoundThisTurn = match.words_found_this_turn + 1;
    const isPlayer1 = userId === match.player1_id;
    const newPlayerWordsFound = isPlayer1
      ? match.player1_words_found + 1
      : match.player2_words_found + 1;

    // 8. Check if turn complete (3 words)
    const turnComplete = newWordsFoundThisTurn === 3;

    // 9. Check if game complete (12 words)
    const gameComplete = foundWords.length === 12;

    // 10. Determine next state
    let updates = {
      found_words: JSON.stringify(foundWords),
      words_found_this_turn: turnComplete ? 0 : newWordsFoundThisTurn,
      [isPlayer1 ? 'player1_words_found' : 'player2_words_found']: newPlayerWordsFound,
    };

    if (turnComplete && !gameComplete) {
      updates.current_turn_user_id = isPlayer1 ? match.player2_id : match.player1_id;
      updates.turn_number = match.turn_number + 1;
    }

    if (gameComplete) {
      updates.status = 'completed';
      updates.completed_at = new Date();
      updates.winner_id = determineWinner(match, newPlayerWordsFound, isPlayer1);
    }

    // 11. Update match
    await tx.query('UPDATE word_search_matches SET ... WHERE id = $1', [...]);

    // 12. Record move
    await tx.query('INSERT INTO word_search_moves ...', [...]);

    // 13. Send notification if turn switched
    if (turnComplete && !gameComplete) {
      await sendPushNotification(
        isPlayer1 ? match.player2_id : match.player1_id,
        'Your turn in Word Search!'
      );
    }

    return {
      valid: true,
      pointsEarned: word.length * 10,
      wordsFoundThisTurn: turnComplete ? 0 : newWordsFoundThisTurn,
      turnComplete,
      gameComplete,
      colorIndex,
      winnerId: gameComplete ? updates.winner_id : null
    };
  });
}
```

---

## 9. Implementation Phases

> **Testing Philosophy:** Each phase ends with comprehensive automated tests that the implementing agent MUST run before proceeding. Do not ask the user to test - run the tests yourself using Bash, curl, flutter commands, etc.

---

### Phase 1: Database & API Foundation

**Implementation:**
- [ ] Create Supabase migration `012_word_search_game.sql`
- [ ] Create puzzle JSON files (start with 3 puzzles)
- [ ] Create puzzle-order.json for word search
- [ ] Implement POST `/api/sync/word-search` (create/get match)
- [ ] Implement GET `/api/sync/word-search/[matchId]` (poll)

**Testing (run these yourself):**
- [ ] Verify migration SQL is valid (check for syntax errors)
- [ ] Verify puzzle JSON files are valid JSON: `cat api/data/puzzles/word-search/*.json | jq .`
- [ ] Verify each puzzle has exactly 100 characters in grid: `jq -r '.grid | length' api/data/puzzles/word-search/ws_*.json`
- [ ] Verify each puzzle has exactly 12 words: `jq '.words | keys | length' api/data/puzzles/word-search/ws_*.json`
- [ ] Start API server and test endpoint: `curl -X POST http://localhost:3000/api/sync/word-search -H "X-Dev-User-Id: c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28"`

---

### Phase 2: Core API Logic

**Implementation:**
- [ ] Implement POST `/api/sync/word-search/submit` (word submission)
- [ ] Implement turn switching logic
- [ ] Implement game completion logic
- [ ] Implement POST `/api/sync/word-search/hint`
- [ ] Add move audit trail
- [ ] Write API test script `api/scripts/test_word_search_api.sh`

**Testing (run these yourself):**
- [ ] Run full API test script: `cd api && ./scripts/test_word_search_api.sh`
- [ ] Verify test output shows all green checkmarks
- [ ] Test invalid word submission returns `valid: false`
- [ ] Test submitting on wrong turn returns 403 NOT_YOUR_TURN
- [ ] Test hint decrements hint count correctly
- [ ] Test turn switches after exactly 3 words
- [ ] Manually verify database state: check `word_search_matches` table has correct data

---

### Phase 3: Flutter Models & Service

**Implementation:**
- [ ] Create `lib/models/word_search.dart` with Hive annotations
- [ ] Run `flutter pub run build_runner build --delete-conflicting-outputs`
- [ ] Register Hive adapters in `main.dart`
- [ ] Create `lib/services/word_search_service.dart`
- [ ] Add storage methods to `StorageService`

**Testing (run these yourself):**
- [ ] Verify no Dart analysis errors: `cd app && flutter analyze lib/models/word_search.dart`
- [ ] Verify no Dart analysis errors: `cd app && flutter analyze lib/services/word_search_service.dart`
- [ ] Verify Hive adapters generated: `ls app/lib/models/word_search.g.dart`
- [ ] Verify app compiles: `cd app && flutter build apk --debug 2>&1 | head -50`
- [ ] Verify no duplicate Hive typeIds by checking existing models

---

### Phase 4: Flutter UI - Home Card

**Implementation:**
- [ ] Create `lib/widgets/word_search_card.dart`
- [ ] Implement 4 visual states (yourTurnFresh, yourTurnInProgress, partnerTurn, completed)
- [ ] Add polling timer for partner's turn (10 second interval)
- [ ] Integrate into home screen (second side quest slot)

**Testing (run these yourself):**
- [ ] Verify no Dart analysis errors: `cd app && flutter analyze lib/widgets/word_search_card.dart`
- [ ] Verify app compiles with new widget: `cd app && flutter build apk --debug 2>&1 | head -50`
- [ ] Verify widget is exported/imported correctly in home screen
- [ ] Search for any hardcoded strings that should use localization
- [ ] Verify color references use BrandLoader (not hardcoded hex)

---

### Phase 5: Flutter UI - Game Screen

**Implementation:**
- [ ] **FIRST: Review `mockups/wordsearch/word-search-game.html`** - read file and understand all interactions
- [ ] Create `lib/screens/word_search_game_screen.dart`
- [ ] Implement 10x10 grid rendering
- [ ] Implement touch selection (GestureDetector with pan)
- [ ] Implement floating selection bubble
- [ ] Implement word bank display (3x4 grid)
- [ ] Implement found word highlighting with color rotation
- [ ] Implement turn progress indicator (bottom bar)
- [ ] Add hint functionality
- [ ] Add animations (word overlay, floating points, shake)

**Testing (run these yourself):**
- [ ] Verify no Dart analysis errors: `cd app && flutter analyze lib/screens/word_search_game_screen.dart`
- [ ] Verify app compiles: `cd app && flutter build apk --debug 2>&1 | head -50`
- [ ] Verify all imports resolve correctly
- [ ] Verify navigation route is registered
- [ ] Check that grid renders 100 cells (10x10)
- [ ] Verify color constants match mockup CSS variables
- [ ] Verify font sizes match mockup specifications

---

### Phase 6: Integration & Polish

**Implementation:**
- [ ] Wire up push notifications for turn switching
- [ ] Create completion screen overlay
- [ ] Add Love Points reward on completion (30 LP)
- [ ] Polish animations and transitions
- [ ] Add error handling for network failures
- [ ] Add loading states

**Testing (run these yourself):**
- [ ] Full app compilation: `cd app && flutter build apk --debug`
- [ ] Run flutter analyze on entire app: `cd app && flutter analyze`
- [ ] Verify LP service integration by checking imports
- [ ] Verify notification service integration
- [ ] Test API error responses are handled gracefully
- [ ] Run API test script one more time: `cd api && ./scripts/test_word_search_api.sh`

---

### Phase 7: Content & Launch

**Implementation:**
- [ ] Create 10+ additional puzzle variations
- [ ] Add Word Search to daily quest rotation (optional)
- [ ] Update CLAUDE.md with Word Search documentation
- [ ] Create user-facing help text

**Testing (run these yourself):**
- [ ] Verify all puzzle JSON files are valid: `for f in api/data/puzzles/word-search/ws_*.json; do jq . "$f" > /dev/null && echo "✓ $f" || echo "✗ $f"; done`
- [ ] Verify puzzle-order.json includes all puzzles
- [ ] Verify each puzzle grid is exactly 100 chars
- [ ] Verify each puzzle has exactly 12 words
- [ ] Verify no duplicate puzzle IDs
- [ ] Final flutter analyze: `cd app && flutter analyze`
- [ ] Final API test: `cd api && ./scripts/test_word_search_api.sh`

---

## Design Decisions (Confirmed)

| Question | Decision |
|----------|----------|
| **Love Points** | 30 LP per completed game (matches Linked) |
| **Daily Quest** | Side quest, second from left (next to Linked) |
| **Progression** | Linear puzzle progression (like Linked) |
| **Timer** | No timer - pure relaxed play |
| **Grid Size** | Always 10x10 |

---

## References

- Linked Game Implementation: `lib/screens/linked_game_screen.dart`
- Linked API: `api/app/api/sync/linked/`
- Linked Models: `lib/models/linked.dart`
- HTML Mockup: `mockups/wordsearch/word-search-game.html`

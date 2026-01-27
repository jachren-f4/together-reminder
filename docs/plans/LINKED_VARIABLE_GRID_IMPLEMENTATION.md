# Linked Variable Grid Size - Implementation Plan

**Date:** 2025-01-21
**Related:** `LINKED_VARIABLE_GRID_SIZE_INVESTIGATION.md`

---

## Overview

This document provides step-by-step implementation details for adding difficulty progression to Linked puzzles via variable grid sizes.

**Goal:** First 4 puzzles are 5×7, next 4 are 6×8, rest are 7×9 (current size)

---

## Part 1: Flutter App Changes

### Required Changes: **MINIMAL**

The Flutter app already supports variable grid sizes for rendering. The only change needed is adding a feature flag for backwards compatibility (see Part 8).

Here's why rendering works without changes:

#### Grid Rendering (`linked_game_screen.dart`)

```dart
// Already uses dynamic dimensions
final cols = puzzle.cols;
final rows = puzzle.rows;

AspectRatio(
  aspectRatio: cols / rows,  // Adapts to any ratio
  child: GridView.builder(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: cols,  // Variable
    ),
    itemCount: cols * rows,  // Variable
  ),
)
```

#### Model (`linked.dart`)

```dart
class LinkedPuzzle {
  final int rows;
  final int cols;
  int get totalCells => rows * cols;

  factory LinkedPuzzle.fromJson(Map<String, dynamic> json) {
    final size = json['size'] as Map<String, dynamic>;
    return LinkedPuzzle(
      rows: size['rows'] as int,
      cols: size['cols'] as int,
    );
  }
}
```

#### Clue Positioning

Clue cells are calculated dynamically:
- Across clues: `targetIndex - 1`
- Down clues: `targetIndex - puzzle.cols`

**No Flutter code changes required for rendering variable sizes.** However, see Part 9 for UI improvements to make smaller grids display with larger cells.

See Part 8 for the feature flag change needed for backwards compatibility.

---

## Part 2: Server Changes

### Required Changes: **MINIMAL**

The API already handles variable grid sizes correctly for puzzle loading and validation. The only change needed is reading the feature flag and loading the appropriate puzzle order file (see Part 8).

#### Puzzle Loading (`api/app/api/sync/linked/route.ts`)

```typescript
function loadPuzzle(puzzleId: string, branch?: string): any {
  // Loads any puzzle file - no size assumptions
  const puzzlePath = join(process.cwd(), 'data', 'puzzles', 'linked', branchFolder, `${puzzleId}.json`);
  return JSON.parse(readFileSync(puzzlePath, 'utf-8'));
}
```

#### Answer Cell Counting

```typescript
function countAnswerCells(puzzle: any): number {
  const { grid, gridnums } = puzzle;
  for (let i = 0; i < grid.length; i++) {
    const row = Math.floor(i / puzzle.size.cols);  // Dynamic
    const col = i % puzzle.size.cols;              // Dynamic
    if (row === 0 || col === 0) continue;          // Frame detection
    if (grid[i] === '.') continue;                 // Void cells
    count++;
  }
  return count;
}
```

#### Rack Generation (`api/app/api/sync/linked/submit/route.ts`)

```typescript
function generateRack(puzzle: any, boardState, maxSize = 5): string[] {
  const { grid, size } = puzzle;
  for (let i = 0; i < grid.length; i++) {
    const row = Math.floor(i / size.cols);  // Dynamic
    const col = i % size.cols;              // Dynamic
    if (row === 0 || col === 0) continue;
    // ...
  }
}
```

**No API code changes required for puzzle handling.** See Part 8 for the feature flag change needed for backwards compatibility.

---

## Part 3: JSON Format for Different Grid Sizes

### Current Format (7×9 = 63 cells)

```json
{
  "puzzleId": "puzzle_001",
  "author": "Crossword Maker GPT",
  "title": "AI-Built Puzzle",
  "size": {
    "rows": 9,
    "cols": 7
  },
  "grid": [
    ".", ".", ".", ".", ".", ".", ".",
    ".", "D", "E", "S", "I", "R", "E",
    ".", "A", "D", "O", "R", "E", "R",
    ".", ".", "E", ".", "E", "G", "G",
    ".", "O", "N", "E", ".", "S", "O",
    ".", "U", ".", "N", "O", ".", ".",
    ".", "A", "L", ".", "G", "E", "M",
    ".", "R", "E", "A", "L", "L", "Y",
    ".", "C", "I", "N", "E", "M", "A"
  ],
  "gridnums": [
    0, 1, 2, 3, 4, 5, 6,
    7, 0, 0, 0, 0, 0, 0,
    8, 0, 0, 0, 0, 0, 0,
    0, 9, 0, 10, 0, 0, 0,
    11, 0, 0, 0, 12, 0, 0,
    13, 0, 14, 0, 0, 15, 16,
    17, 0, 0, 18, 0, 0, 0,
    19, 0, 0, 0, 0, 0, 0,
    20, 0, 0, 0, 0, 0, 0
  ],
  "clues": { ... }
}
```

### 5×7 Format (Beginner - 35 cells)

```json
{
  "puzzleId": "puzzle_5x7_001",
  "author": "Crossword Maker GPT",
  "title": "Beginner Puzzle",
  "size": {
    "rows": 7,
    "cols": 5
  },
  "grid": [
    ".", ".", ".", ".", ".",
    ".", "L", "O", "V", "E",
    ".", "I", ".", ".", ".",
    ".", "K", "I", "S", "S",
    ".", "E", ".", "U", ".",
    ".", ".", "H", "U", "G",
    ".", "Y", "E", "S", "."
  ],
  "gridnums": [
    0, 1, 2, 3, 4,
    5, 0, 0, 0, 0,
    0, 0, 6, 0, 0,
    7, 0, 0, 0, 0,
    0, 0, 8, 0, 9,
    10, 0, 0, 0, 0,
    0, 0, 0, 0, 0
  ],
  "clues": {
    "1": { "type": "emoji", "content": "❤️", "arrow": "down", "target_index": 6 },
    "2": { "type": "text", "content": "Want", "arrow": "down", "target_index": 7 },
    "5": { "type": "text", "content": "Adore", "arrow": "across", "target_index": 6 },
    "7": { "type": "emoji", "content": "💋", "arrow": "across", "target_index": 16 }
  }
}
```

**Key differences:**
- `size.rows`: 7 instead of 9
- `size.cols`: 5 instead of 7
- `grid`: 35 elements instead of 63
- `gridnums`: 35 elements instead of 63
- Clue `target_index` values recalculated for new grid width

### 6×8 Format (Intermediate - 48 cells)

```json
{
  "puzzleId": "puzzle_6x8_001",
  "author": "Crossword Maker GPT",
  "title": "Intermediate Puzzle",
  "size": {
    "rows": 8,
    "cols": 6
  },
  "grid": [
    ".", ".", ".", ".", ".", ".",
    ".", "H", "E", "A", "R", "T",
    ".", "U", ".", "D", ".", ".",
    ".", "G", "I", "O", "R", "E",
    ".", ".", "F", "R", ".", ".",
    ".", "C", "A", "E", ".", ".",
    ".", "U", "R", ".", "S", "O",
    ".", "T", "E", "N", "D", "."
  ],
  "gridnums": [
    0, 1, 2, 3, 4, 5,
    6, 0, 0, 0, 0, 0,
    0, 0, 7, 0, 0, 0,
    8, 0, 0, 0, 0, 0,
    0, 9, 0, 0, 10, 0,
    11, 0, 0, 0, 0, 12,
    0, 0, 0, 13, 0, 0,
    14, 0, 0, 0, 0, 0
  ],
  "clues": { ... }
}
```

### Index Calculation Formula

For a grid with `cols` columns:
- **Row from index:** `Math.floor(index / cols)`
- **Column from index:** `index % cols`
- **Index from row,col:** `row * cols + col`

**Example for down clue starting at row 1, col 2:**
- 5-col grid: `1 * 5 + 2 = 7`
- 6-col grid: `1 * 6 + 2 = 8`
- 7-col grid: `1 * 7 + 2 = 9`

---

## Part 4: Puzzle Ordering System

### How It Works

Each branch has a `puzzle-order.json` file:

```
api/data/puzzles/linked/
├── casual/
│   ├── puzzle-order.json
│   ├── puzzle_001.json
│   ├── puzzle_002.json
│   └── ...
├── romantic/
│   ├── puzzle-order.json
│   └── ...
└── adult/
    ├── puzzle-order.json
    └── ...
```

The `puzzle-order.json` controls which puzzle is served next:

```json
{
  "puzzles": [
    "puzzle_001",
    "puzzle_002",
    "puzzle_003",
    ...
  ]
}
```

The API iterates through this list and returns the first uncompleted puzzle for the couple.

### Updated Puzzle Order for Difficulty Progression

To implement the difficulty progression, update `puzzle-order.json` in each branch:

```json
{
  "puzzles": [
    "puzzle_5x7_001",
    "puzzle_5x7_002",
    "puzzle_5x7_003",
    "puzzle_5x7_004",
    "puzzle_6x8_001",
    "puzzle_6x8_002",
    "puzzle_6x8_003",
    "puzzle_6x8_004",
    "puzzle_001",
    "puzzle_002",
    "puzzle_003",
    ...
  ]
}
```

### File Naming Convention

Suggested naming to make sizes clear:

| Size | Naming Pattern | Examples |
|------|---------------|----------|
| 5×7 (beginner) | `puzzle_5x7_NNN.json` | `puzzle_5x7_001.json`, `puzzle_5x7_002.json` |
| 6×8 (intermediate) | `puzzle_6x8_NNN.json` | `puzzle_6x8_001.json`, `puzzle_6x8_002.json` |
| 7×9 (standard) | `puzzle_NNN.json` | `puzzle_001.json` (existing) |

**Alternative:** Use numeric ranges
- 001-004: beginner (5×7)
- 005-008: intermediate (6×8)
- 009+: standard (7×9)

---

## Part 5: Step-by-Step Implementation

### Step 1: Create 5×7 Puzzles

For each branch (casual, romantic, adult):

1. **Generate puzzles** using Crossword Maker GPT with prompt:
   > "Create a 5×7 crossword puzzle (7 rows, 5 columns) with simple 3-4 letter words about [theme]. Use emoji clues where possible. Format as JSON with size, grid, gridnums, and clues."

2. **Save files:**
   ```
   api/data/puzzles/linked/casual/puzzle_5x7_001.json
   api/data/puzzles/linked/casual/puzzle_5x7_002.json
   api/data/puzzles/linked/casual/puzzle_5x7_003.json
   api/data/puzzles/linked/casual/puzzle_5x7_004.json
   ```

3. **Verify JSON structure:**
   - `size.rows` = 7
   - `size.cols` = 5
   - `grid` has exactly 35 elements
   - `gridnums` has exactly 35 elements
   - Clue `target_index` values are correct for 5-column width

### Step 2: Create 6×8 Puzzles

Same process with different dimensions:

1. **Generate puzzles** with prompt:
   > "Create a 6×8 crossword puzzle (8 rows, 6 columns) with medium-difficulty words about [theme]."

2. **Save files:**
   ```
   api/data/puzzles/linked/casual/puzzle_6x8_001.json
   ...
   ```

3. **Verify:**
   - `size.rows` = 8
   - `size.cols` = 6
   - `grid` has exactly 48 elements
   - `gridnums` has exactly 48 elements

### Step 3: Update puzzle-order.json

For each branch, prepend the new puzzles:

**Before:**
```json
{
  "puzzles": [
    "puzzle_001",
    "puzzle_002",
    ...
  ]
}
```

**After:**
```json
{
  "puzzles": [
    "puzzle_5x7_001",
    "puzzle_5x7_002",
    "puzzle_5x7_003",
    "puzzle_5x7_004",
    "puzzle_6x8_001",
    "puzzle_6x8_002",
    "puzzle_6x8_003",
    "puzzle_6x8_004",
    "puzzle_001",
    "puzzle_002",
    ...
  ]
}
```

### Step 4: Test Locally

1. **Reset couple progress:**
   ```bash
   cd api && npx tsx scripts/reset_couple_progress.ts
   ```

2. **Start API locally:**
   ```bash
   cd api && npm run dev
   ```

3. **Run app and verify:**
   - First puzzle should be 5×7
   - Complete it, next should still be 5×7 (puzzles 1-4)
   - After puzzle 4, puzzle 5 should be 6×8
   - After puzzle 8, puzzle 9 should be 7×9

### Step 5: Deploy

1. Copy new puzzle files to production
2. Update `puzzle-order.json` files
3. Deploy API (if using Vercel, just push to git)

---

## Part 6: Puzzle Content Guidelines

### 5×7 Beginner Puzzles

- **Words:** 3-4 letters max
- **Clues:** Simple, mostly emoji
- **Theme:** Basic relationship words (LOVE, HUG, KISS, YES, etc.)
- **Answer cells:** ~15-20 (excluding frame and voids)

### 6×8 Intermediate Puzzles

- **Words:** 3-5 letters
- **Clues:** Mix of emoji and simple text
- **Theme:** Slightly more varied vocabulary
- **Answer cells:** ~25-30

### 7×9 Standard Puzzles

- **Words:** 3-7 letters
- **Clues:** Full range including text clues
- **Theme:** Current content
- **Answer cells:** ~35-40

---

## Part 7: Validation Checklist

Before deploying, verify each puzzle:

- [ ] `puzzleId` matches filename
- [ ] `size.rows` × `size.cols` = `grid.length`
- [ ] `size.rows` × `size.cols` = `gridnums.length`
- [ ] Row 0 is all `"."` (clue frame top)
- [ ] Column 0 is all `"."` (clue frame left)
- [ ] Each clue's `target_index` points to valid answer cell
- [ ] For down clues: `target_index - cols` is in clue frame (row 0)
- [ ] For across clues: `target_index - 1` is in clue frame (col 0)
- [ ] All answer letters are uppercase A-Z
- [ ] Void cells are `"."`

### Validation Script (Optional)

```typescript
// api/scripts/validate_puzzle.ts
import { readFileSync } from 'fs';

function validatePuzzle(path: string) {
  const puzzle = JSON.parse(readFileSync(path, 'utf-8'));
  const { rows, cols } = puzzle.size;
  const expectedCells = rows * cols;

  console.assert(puzzle.grid.length === expectedCells,
    `Grid has ${puzzle.grid.length} cells, expected ${expectedCells}`);
  console.assert(puzzle.gridnums.length === expectedCells,
    `Gridnums has ${puzzle.gridnums.length} cells, expected ${expectedCells}`);

  // Check frame
  for (let i = 0; i < cols; i++) {
    console.assert(puzzle.grid[i] === '.', `Row 0 col ${i} should be void`);
  }
  for (let r = 0; r < rows; r++) {
    console.assert(puzzle.grid[r * cols] === '.', `Row ${r} col 0 should be void`);
  }

  console.log(`✓ ${path} validated`);
}
```

---

## Part 8: Backwards Compatibility

### The Problem

When deploying to Vercel, both old and new app builds will hit the same API. If we change `puzzle-order.json` to serve 5×7 puzzles first, the App Store review build (which expects 7×9) will get the wrong puzzles.

### Solution: Feature Flag via Request Parameter

New app builds send a flag indicating they support the difficulty progression. The API uses this to decide which puzzle order file to load.

### File Structure

```
api/data/puzzles/linked/casual/
├── puzzle-order.json      # Original: 7×9 first (for old builds)
├── puzzle-order-v2.json   # New: 5×7 → 6×8 → 7×9 (for new builds)
├── puzzle_5x7_001.json
├── puzzle_5x7_002.json
├── puzzle_6x8_001.json
├── puzzle_001.json        # Existing 7×9
└── ...
```

### Flutter Change

In `linked_service.dart`, add a flag to the API request:

```dart
// When calling POST /api/sync/linked
Future<LinkedGameState?> getOrCreateMatch(String localDate) async {
  final response = await _apiClient.post(
    '/api/sync/linked',
    body: {
      'localDate': localDate,
      'gridProgression': true,  // NEW: Enable difficulty progression
    },
  );
  // ...
}
```

**Only new builds will have this flag.** Old builds in App Store review won't send it.

### API Change

In `api/app/api/sync/linked/route.ts`, modify `loadPuzzleOrder()`:

```typescript
function loadPuzzleOrder(branch: string, gridProgression: boolean = false): string[] {
  const branchFolder = branch || 'casual';

  // Use v2 order file if client supports grid progression
  const orderFileName = gridProgression ? 'puzzle-order-v2.json' : 'puzzle-order.json';

  const orderPath = join(
    process.cwd(),
    'data', 'puzzles', 'linked',
    branchFolder,
    orderFileName
  );

  try {
    const orderData = JSON.parse(readFileSync(orderPath, 'utf-8'));
    return orderData.puzzles || [];
  } catch (error) {
    console.error(`Failed to load puzzle order from ${orderPath}`);
    return [];
  }
}
```

Then in the POST handler, read the flag from the request body:

```typescript
export async function POST(request: NextRequest) {
  // ...
  const body = await request.json();
  const { localDate, gridProgression } = body;

  // Pass flag to puzzle order loader
  const puzzleOrder = loadPuzzleOrder(branch, gridProgression === true);
  // ...
}
```

### Puzzle Order Files

**`puzzle-order.json`** (original, for old builds):
```json
{
  "puzzles": [
    "puzzle_001",
    "puzzle_002",
    "puzzle_003",
    ...
  ]
}
```

**`puzzle-order-v2.json`** (new, for new builds):
```json
{
  "puzzles": [
    "puzzle_5x7_001",
    "puzzle_5x7_002",
    "puzzle_5x7_003",
    "puzzle_5x7_004",
    "puzzle_6x8_001",
    "puzzle_6x8_002",
    "puzzle_6x8_003",
    "puzzle_6x8_004",
    "puzzle_001",
    "puzzle_002",
    "puzzle_003",
    ...
  ]
}
```

### Deployment Sequence

1. **Create puzzle content:**
   - Add 5×7 puzzle files
   - Add 6×8 puzzle files
   - Create `puzzle-order-v2.json` in each branch

2. **Deploy API to Vercel:**
   - Push API changes (new order file loader logic)
   - Old builds continue to get `puzzle-order.json` (7×9 first)
   - Nothing changes for App Store reviewer

3. **Release new Flutter build:**
   - Add `gridProgression: true` to API calls
   - Build and upload to TestFlight
   - New TestFlight builds get `puzzle-order-v2.json` (5×7 first)

4. **After App Store approval:**
   - The approved build becomes the new baseline
   - Future users get the difficulty progression

### Testing Matrix

| Build | API Flag | Puzzle Order File | First Puzzle |
|-------|----------|-------------------|--------------|
| App Store Review (old) | Not sent | `puzzle-order.json` | 7×9 |
| TestFlight (new) | `gridProgression: true` | `puzzle-order-v2.json` | 5×7 |
| Production (after approval) | `gridProgression: true` | `puzzle-order-v2.json` | 5×7 |

### Why Request Parameter (Not Build Number)

Using `gridProgression: true` in the request body is preferred over checking app version/build numbers because:
- Explicit opt-in is clearer
- No need to track which build number introduces the feature
- Easy to test locally by toggling the flag
- Can be feature-flagged in the app if needed

---

## Part 9: Full-Width Grid Rendering

### The Goal

Make the grid always fill the full screen width, with cell size dynamically calculated based on the number of columns. Smaller grids (fewer columns) = larger cells.

| Grid | Columns | Cell Size (on 390px wide screen) |
|------|---------|----------------------------------|
| 5×7 | 5 | ~74px per cell |
| 6×8 | 6 | ~61px per cell |
| 7×9 | 7 | ~52px per cell |

### Current Implementation

The current code uses `AspectRatio` which maintains proportions but doesn't guarantee full width:

```dart
// Current: linked_game_screen.dart lines 728-749
child: Center(
  child: AspectRatio(
    aspectRatio: cols / rows,
    child: GridView.builder(...)
  ),
)
```

### New Implementation

Replace `AspectRatio` with `LayoutBuilder` to calculate dimensions based on available width:

```dart
Widget _buildGrid() {
  final puzzle = _gameState!.puzzle!;
  final cols = puzzle.cols;
  final rows = puzzle.rows;
  final boardState = _gameState!.match.boardState;

  // Spacing constants
  const double horizontalPadding = 16.0;  // Total left + right padding
  const double cellSpacing = 2.0;

  return LayoutBuilder(
    builder: (context, constraints) {
      // Calculate cell size to fill available width
      final availableWidth = constraints.maxWidth - horizontalPadding;
      final totalSpacing = cellSpacing * (cols - 1);
      final cellSize = (availableWidth - totalSpacing) / cols;

      // Calculate grid height based on cell size
      final gridHeight = (cellSize * rows) + (cellSpacing * (rows - 1));

      return Container(
        key: _gridKey,
        color: BrandLoader().colors.background,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding / 2, vertical: 8),
        child: SizedBox(
          width: availableWidth,
          height: gridHeight,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: cellSpacing,
              crossAxisSpacing: cellSpacing,
            ),
            itemCount: cols * rows,
            itemBuilder: (context, index) {
              return _buildCell(index, puzzle, boardState);
            },
          ),
        ),
      );
    },
  );
}
```

### Us2 Brand Version

Same approach for `_buildUs2Grid()`:

```dart
Widget _buildUs2Grid(LinkedPuzzle puzzle, int cols, int rows, Map<String, String> boardState) {
  const double horizontalPadding = 16.0;
  const double framePadding = 12.0;  // Frame padding (6 outer + 4 inner + borders)
  const double cellSpacing = 2.0;

  return LayoutBuilder(
    builder: (context, constraints) {
      // Account for frame padding when calculating cell size
      final availableWidth = constraints.maxWidth - horizontalPadding - framePadding;
      final totalSpacing = cellSpacing * (cols - 1);
      final cellSize = (availableWidth - totalSpacing) / cols;
      final gridHeight = (cellSize * rows) + (cellSpacing * (rows - 1));

      // Total height including frame
      final totalHeight = gridHeight + framePadding;

      return Container(
        key: _gridKey,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding / 2, vertical: 4),
        child: SizedBox(
          width: constraints.maxWidth - horizontalPadding,
          height: totalHeight,
          child: Container(
            decoration: BoxDecoration(
              gradient: Us2Theme.gridFrameGradient,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Us2Theme.goldBorder, width: 1.5),
              boxShadow: Us2Theme.gridFrameShadow,
            ),
            padding: const EdgeInsets.all(6),
            child: Container(
              decoration: BoxDecoration(
                color: Us2Theme.goldMid,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: cellSpacing,
                    crossAxisSpacing: cellSpacing,
                  ),
                  itemCount: cols * rows,
                  itemBuilder: (context, index) {
                    return _buildCell(index, puzzle, boardState);
                  },
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
```

### Visual Comparison

**Before (AspectRatio):**
- Grid maintains aspect ratio
- May have horizontal margins on wider screens
- Cell size depends on both width AND height constraints

**After (Full-Width):**
- Grid always fills screen width (minus padding)
- Cell size = `availableWidth / cols`
- 5-column grid has ~40% larger cells than 7-column grid
- Grid height adjusts based on rows × cellSize

### Cell Size Examples

For a typical iPhone (390px logical width) with 16px total padding:

| Grid | Cols | Available Width | Cell Size | Grid Height |
|------|------|-----------------|-----------|-------------|
| 5×7 | 5 | 374px | ~74px | ~526px |
| 6×8 | 6 | 374px | ~61px | ~496px |
| 7×9 | 7 | 374px | ~52px | ~478px |

### Scrolling Consideration

If the grid becomes taller than the available screen space (unlikely with these sizes), ensure the parent widget allows scrolling:

```dart
// In the screen's build method, wrap grid section in SingleChildScrollView if needed
SingleChildScrollView(
  child: Column(
    children: [
      _buildGrid(),
      _buildRack(),
      // ...
    ],
  ),
)
```

### Testing Checklist

- [ ] 5×7 grid fills full width with large cells
- [ ] 6×8 grid fills full width with medium cells
- [ ] 7×9 grid fills full width (same as current behavior)
- [ ] Cells remain square (not stretched)
- [ ] Clue text/emoji scales appropriately in larger cells
- [ ] Grid frame (Us2) looks correct at all sizes
- [ ] No overflow on small screens
- [ ] Grid + rack + other UI elements fit on screen

---

## Part 10: Tutorial Overlay Compatibility

### How It Currently Works

The `LinkedTutorialOverlay` uses `GlobalKey` to find widget positions at runtime:

```dart
// linked_tutorial_overlay.dart
Rect? _getWidgetRect(GlobalKey key) {
  final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
  final position = renderBox.localToGlobal(Offset.zero);
  final size = renderBox.size;
  return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
}
```

The spotlight highlight is drawn at the actual position of the clue cell, regardless of grid size. **This part is already dynamic and will work correctly.**

### The Potential Issue

The tutorial card is centered on screen:

```dart
Center(
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 30),
    child: Container(/* tutorial card */)
  ),
)
```

With a 5×7 grid:
- Cells are ~40% larger than 7×9
- The clue cell being highlighted is at the top of the grid
- The grid itself is taller (bigger cells × rows)
- The tutorial card (centered) might overlap the highlighted clue cell

### Verification Steps

1. **Test with 5×7 grid** - Check if step 1 (clue highlight) overlaps with the tutorial card
2. **Test with 6×8 grid** - Same check
3. **Test on different screen sizes** - Small phones may have more overlap risk

### Solution If Overlap Occurs

If the tutorial card overlaps the highlighted element, modify `LinkedTutorialOverlay` to position the card dynamically:

```dart
Widget build(BuildContext context) {
  final step = _tutorialSteps[_currentStep];
  final isLastStep = _currentStep == _tutorialSteps.length - 1;

  // Get highlight position to avoid overlap
  final highlightRect = _getHighlightRect(step.spotlightType);
  final screenHeight = MediaQuery.of(context).size.height;

  // Determine if card should be above or below the highlight
  final cardAbove = highlightRect != null &&
      highlightRect.center.dy > screenHeight / 2;

  return Material(
    color: Colors.transparent,
    child: Stack(
      children: [
        // Semi-transparent overlay
        Positioned.fill(
          child: Container(color: Colors.black.withOpacity(0.5)),
        ),

        // Spotlight highlight
        if (step.spotlightType != _SpotlightType.none)
          _buildSpotlightHighlight(step.spotlightType),

        // Tutorial card - positioned to avoid overlap
        Positioned(
          left: 30,
          right: 30,
          top: cardAbove ? 60 : null,      // Above: near top of screen
          bottom: cardAbove ? null : 100,  // Below: near bottom of screen
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              // ... rest of card
            ),
          ),
        ),
      ],
    ),
  );
}

Rect? _getHighlightRect(_SpotlightType type) {
  final key = switch (type) {
    _SpotlightType.clue => widget.clueKey,
    _SpotlightType.letterRack => widget.rackKey,
    _SpotlightType.submitButton => widget.submitKey,
    _SpotlightType.none => null,
  };
  return key != null ? _getWidgetRect(key) : null;
}
```

### Per-Step Positioning

For more control, define card position per tutorial step:

```dart
static const _tutorialSteps = [
  _TutorialStep(
    title: 'Read the Clues',
    description: '...',
    spotlightType: _SpotlightType.clue,
    cardPosition: _CardPosition.bottom,  // Card below highlight
  ),
  _TutorialStep(
    title: 'Drag Your Letters',
    description: '...',
    spotlightType: _SpotlightType.letterRack,
    cardPosition: _CardPosition.top,  // Card above rack
  ),
  _TutorialStep(
    title: 'Take Turns',
    description: '...',
    spotlightType: _SpotlightType.submitButton,
    cardPosition: _CardPosition.top,  // Card above submit button
  ),
];
```

### Testing Checklist for Tutorial

- [ ] Step 1 (clue highlight): Card doesn't overlap highlighted clue cell
- [ ] Step 2 (rack highlight): Card doesn't overlap letter rack
- [ ] Step 3 (submit button): Card doesn't overlap submit button
- [ ] All steps work on 5×7, 6×8, and 7×9 grids
- [ ] All steps work on small screens (iPhone SE size)
- [ ] Highlight rectangle correctly sized for larger clue cells

---

## Summary

| Component | Changes Required |
|-----------|------------------|
| Flutter app | Add `gridProgression: true` to linked API calls |
| Flutter app | Update grid rendering to use full-width layout (Part 9) |
| Flutter app | Verify/fix tutorial overlay positioning (Part 10) |
| API server | Read flag, load appropriate puzzle-order file |
| Database | None |
| Puzzle JSON files | Create new 5×7 and 6×8 files |
| puzzle-order.json | Keep original, create new `puzzle-order-v2.json` |

The implementation ensures:
- App Store review build continues working with 7×9 puzzles
- New TestFlight builds can test the difficulty progression
- Smaller grids display with larger, more readable cells
- No disruption to existing users until they update

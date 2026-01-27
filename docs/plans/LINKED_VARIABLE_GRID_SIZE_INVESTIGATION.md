# Linked (Crossword) Variable Grid Size Investigation

**Date:** 2025-01-21
**Status:** Investigation Complete
**Goal:** Assess feasibility of 5×7 → 6×8 → 7×9 progression for Linked puzzles

---

## Executive Summary

**Feasibility:** ✅ **HIGHLY FEASIBLE** - The system is already architected to support variable grid sizes. No hardcoded dimensions in the rendering logic.

**Current State:** All Linked puzzles use a fixed **9 rows × 7 cols** grid (63 cells total).

**What's Needed:** Only puzzle content creation and reordering. No code changes required.

---

## Current Architecture

### Grid Size: 9×7 (All Puzzles)

Verified across all puzzle files:
- `api/data/puzzles/linked/casual/` - 29 puzzles, all 9×7
- `api/data/puzzles/linked/romantic/` - 59 puzzles, all 9×7
- `api/data/puzzles/linked/adult/` - puzzles, all 9×7

### JSON Format

Grid dimensions are parameterized in the JSON:

```json
{
  "puzzleId": "puzzle_001",
  "title": "AI-Built Puzzle",
  "author": "Crossword Maker GPT",
  "size": {
    "rows": 9,
    "cols": 7
  },
  "clues": { ... },
  "grid": [ /* 63 cells */ ],
  "gridnums": [ ... ],
  "cellTypes": [ ... ]
}
```

The `size` field already supports any dimensions - it's just that all current puzzles happen to use 9×7.

---

## What Already Supports Variable Sizes

### Flutter Grid Rendering

`linked_game_screen.dart` uses **dynamic sizing** with zero hardcoded dimensions:

```dart
// Line 715-716
final cols = puzzle.cols;  // Read from puzzle object
final rows = puzzle.rows;  // Read from puzzle object

// Line 728-729
AspectRatio(
  aspectRatio: cols / rows,  // Dynamic aspect ratio
  child: GridView.builder(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: cols,  // Variable column count
    ),
    itemCount: cols * rows,  // Variable total cells
  ),
)
```

A 5×7 grid will automatically render with larger cells than a 7×9 grid.

### Puzzle Model

`linked.dart` fully supports variable sizes:

```dart
class LinkedPuzzle {
  final int rows;
  final int cols;

  int get totalCells => rows * cols;

  factory LinkedPuzzle.fromJson(Map<String, dynamic> json) {
    final size = json['size'] as Map<String, dynamic>;
    return LinkedPuzzle(
      rows: size['rows'] as int,  // Variable
      cols: size['cols'] as int,  // Variable
    );
  }
}
```

### API Backend

All grid calculations in `api/app/api/sync/linked/route.ts` use `puzzle.size.cols` and `puzzle.size.rows` dynamically:

```typescript
function countAnswerCells(puzzle: any): number {
  for (let i = 0; i < grid.length; i++) {
    const row = Math.floor(i / puzzle.size.cols);  // Dynamic
    const col = i % puzzle.size.cols;              // Dynamic
    // ...
  }
}
```

### Rack Generation

```typescript
function generateRack(puzzle: any, boardState, maxSize = 5): string[] {
  const { grid, size } = puzzle;
  for (let i = 0; i < grid.length; i++) {
    const row = Math.floor(i / size.cols);
    const col = i % size.cols;
    if (row === 0 || col === 0) continue;  // Frame detection works for any size
  }
}
```

### Database Schema

`linked_matches` table makes **no assumptions about grid size**:

```sql
CREATE TABLE linked_matches (
  board_state JSONB,       -- Stores cell index → letter (works for any size)
  current_rack TEXT[],     -- Variable-length array
  total_answer_cells INT,  -- Calculated per puzzle
);
```

### Clue System

Clues use target indices that work for any grid size:

```json
{ "type": "emoji", "content": "🌟", "arrow": "across", "target_index": 10 }
```

Clue cell calculation is dynamic:
- For across: `targetIndex - 1`
- For down: `targetIndex - cols` (uses puzzle's actual column count)

---

## Proposed Grid Progression

| Puzzle Range | Grid Size | Cells | Difficulty |
|--------------|-----------|-------|------------|
| 1-4 | 5×7 | 35 | Beginner |
| 5-8 | 6×8 | 48 | Intermediate |
| 9+ | 7×9 | 63 | Standard |

**Note:** The current 9×7 grid has 63 cells. The proposed "standard" 7×9 has the same cell count, just different aspect ratio (wider vs taller).

---

## Implementation Approach

### Option A: Single Branch with Mixed Sizes (Recommended)

Keep current branch structure, just reorder puzzles:

```
puzzle-order.json:
[
  "puzzle_small_001",   // 5×7 (beginner)
  "puzzle_small_002",   // 5×7
  "puzzle_small_003",   // 5×7
  "puzzle_small_004",   // 5×7
  "puzzle_med_001",     // 6×8 (intermediate)
  "puzzle_med_002",     // 6×8
  "puzzle_med_003",     // 6×8
  "puzzle_med_004",     // 6×8
  "puzzle_001",         // 7×9 (standard, existing)
  "puzzle_002",         // 7×9
  ...
]
```

**Pros:**
- Simplest to implement
- Uses existing puzzle-order system
- No database changes

### Option B: Separate Difficulty Sub-Branches

Create new folder structure:

```
api/data/puzzles/linked/
├── casual/
│   ├── beginner/      (5×7 puzzles)
│   ├── intermediate/  (6×8 puzzles)
│   └── standard/      (7×9 puzzles)
├── romantic/
│   ├── beginner/
│   ├── intermediate/
│   └── standard/
└── adult/
    ├── beginner/
    ├── intermediate/
    └── standard/
```

**Pros:**
- Cleaner organization
- Easier to manage difficulty tiers

**Cons:**
- Requires API changes to handle sub-branches

---

## What Needs to Be Done

### Content Creation (No Code Changes)

1. **Create 5×7 puzzles** (beginner tier)
   - 4 puzzles per branch (casual, romantic, adult)
   - Use Crossword Maker GPT with size constraints
   - Simpler clues, shorter words

2. **Create 6×8 puzzles** (intermediate tier)
   - 4 puzzles per branch
   - Medium complexity clues

3. **Update puzzle-order.json**
   - Place new small puzzles at positions 1-4
   - Place new medium puzzles at positions 5-8
   - Existing 9×7 puzzles become positions 9+

### Testing

| Test Case | What to Verify |
|-----------|----------------|
| 5×7 grid rendering | Grid displays correctly, cells are larger |
| 6×8 grid rendering | Aspect ratio looks good |
| Clue positioning | Across/down clues render in correct cells |
| Turn submission | Letter placement validation works |
| Completion detection | Game completes at correct cell count |
| LP rewards | Awards correctly for all grid sizes |
| Mixed sizes in sequence | Transitioning between sizes works |

---

## Clue Frame Consideration

Linked puzzles have a **clue frame** (row 0 and col 0 contain clues, not answers):

```
Current 9×7:
  [C][C][C][C][C][C][C]   <- Row 0: all clue cells
  [C][A][A][A][A][A][A]   <- Col 0: clue cells, rest are answers
  [C][A][A][A][A][A][A]
  ...

Proposed 5×7:
  [C][C][C][C][C][C][C]   <- Same pattern, just smaller
  [C][A][A][A][A][A][A]
  [C][A][A][A][A][A][A]
  [C][A][A][A][A][A][A]
  [C][A][A][A][A][A][A]
```

The frame detection code (`row === 0 || col === 0`) works for any grid size.

---

## Puzzle Generation with Crossword Maker GPT

Current puzzles are generated using Crossword Maker GPT. To create smaller puzzles:

1. **Specify grid size in prompt:**
   > "Create a 5×7 crossword puzzle with simple 3-4 letter words"

2. **JSON format is identical** - just change the `size` field:
   ```json
   {
     "size": { "rows": 5, "cols": 7 }
   }
   ```

3. **Import process unchanged:**
   - Copy JSON to `api/data/puzzles/linked/{branch}/`
   - Update `puzzleId` in the file
   - Add to `puzzle-order.json`

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Small grids feel too easy | Use more cryptic clues, maintain word variety |
| Aspect ratio looks odd | Test on multiple screen sizes |
| Existing progress disrupted | New puzzles go to front of queue; completed puzzles stay completed |
| Partner sees different size | Both see same puzzle - sizes are per-puzzle, not per-user |

---

## Files Reference

### No Changes Needed

| File | Why It Works |
|------|--------------|
| `app/lib/screens/linked_game_screen.dart` | Uses dynamic `puzzle.cols`/`puzzle.rows` |
| `app/lib/models/linked.dart` | Stores and uses variable dimensions |
| `app/lib/services/linked_service.dart` | Size-agnostic |
| `api/app/api/sync/linked/route.ts` | All calculations use `puzzle.size` |
| `api/app/api/sync/linked/submit/route.ts` | Dynamic column-based indexing |
| `api/supabase/migrations/011_linked_game.sql` | No size assumptions |

### Content to Create/Modify

| File | Change |
|------|--------|
| `api/data/puzzles/linked/{branch}/puzzle_small_*.json` | New 5×7 puzzles |
| `api/data/puzzles/linked/{branch}/puzzle_med_*.json` | New 6×8 puzzles |
| `api/data/puzzles/linked/{branch}/puzzle-order.json` | Reorder to put small/medium first |

---

## Conclusion

Variable grid sizes for Linked are **highly feasible** and require **no code changes**.

The entire system (Flutter UI, API, database) is already architected to handle any grid dimensions. The `size` field in puzzle JSON is read dynamically throughout the codebase.

**To implement:**
1. Create 5×7 beginner puzzles (4 per branch)
2. Create 6×8 intermediate puzzles (4 per branch)
3. Update `puzzle-order.json` to sequence them before existing puzzles
4. Deploy new puzzle files

The hardest part will be creating quality beginner puzzles with appropriate difficulty for smaller grids.

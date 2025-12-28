# Dual-Direction Clues Implementation Plan

**Status:** Ready for Implementation
**Created:** 2024-12-19
**Estimated Effort:** 2-3 hours

---

## Overview

Add support for dual-direction clue cells in Linked puzzles, where a single cell can contain both an ACROSS clue (pointing right) and a DOWN clue (pointing downward). The UI will use **Variant 1: Horizontal Split** layout.

### Current State
- UI already supports split clue rendering via `_buildSplitClueCell()` in `linked_game_screen.dart:715-739`
- `LinkedPuzzle` has `getSplitClues()` method that returns `[acrossClue, downClue]`
- JSON parsing only supports single-direction format with `arrow` field

### Target State
- JSON parsing supports both formats transparently
- Existing single-direction puzzles continue to work unchanged
- New dual-direction puzzles render correctly with horizontal split layout

---

## JSON Format Reference

### Single-Direction (Existing)
```json
"7": {
  "type": "emoji",
  "content": "🌟",
  "arrow": "across",
  "target_index": 10
}
```

### Dual-Direction (New)
```json
"7": {
  "across": {
    "type": "emoji",
    "content": "🌟",
    "target_index": 10
  },
  "down": {
    "type": "text",
    "content": "LO_E",
    "target_index": 16
  }
}
```

**Detection:** Check for `arrow` key at top level. If present → single format. If absent → dual format.

---

## Phase 1: Update Model Parsing

**File:** `lib/models/linked.dart`

### Task 1.1: Update `LinkedPuzzle.fromJson()` to Handle Both Formats

**Current code (lines 304-325):**
```dart
factory LinkedPuzzle.fromJson(Map<String, dynamic> json) {
  final cluesJson = json['clues'] as Map<String, dynamic>;

  final clues = cluesJson.map((key, value) {
    final clueNum = int.tryParse(key) ?? 0;
    return MapEntry(
      key,
      LinkedClue.fromJson(value as Map<String, dynamic>, clueNumber: clueNum),
    );
  });
  // ...
}
```

**Problem:** This creates one `LinkedClue` per clue number, but dual-direction clues need TWO `LinkedClue` objects per clue number.

**Solution:** Change parsing to detect format and create multiple clues when needed.

```dart
factory LinkedPuzzle.fromJson(Map<String, dynamic> json) {
  final size = json['size'] as Map<String, dynamic>;
  final cluesJson = json['clues'] as Map<String, dynamic>;

  // Parse clues - may create multiple LinkedClue objects per clue number
  final Map<String, LinkedClue> clues = {};

  for (final entry in cluesJson.entries) {
    final clueNumStr = entry.key;
    final clueNum = int.tryParse(clueNumStr) ?? 0;
    final clueData = entry.value as Map<String, dynamic>;

    // Detect format: single-direction has 'arrow', dual has 'across'/'down'
    if (clueData.containsKey('arrow')) {
      // Single-direction format (original)
      clues[clueNumStr] = LinkedClue.fromJson(clueData, clueNumber: clueNum);
    } else {
      // Dual-direction format (new)
      // Create separate clue entries with direction suffix for internal tracking
      if (clueData.containsKey('across')) {
        final acrossData = clueData['across'] as Map<String, dynamic>;
        clues['${clueNumStr}_across'] = LinkedClue.fromJsonDirection(
          acrossData,
          clueNumber: clueNum,
          direction: 'across',
        );
      }
      if (clueData.containsKey('down')) {
        final downData = clueData['down'] as Map<String, dynamic>;
        clues['${clueNumStr}_down'] = LinkedClue.fromJsonDirection(
          downData,
          clueNumber: clueNum,
          direction: 'down',
        );
      }
    }
  }

  return LinkedPuzzle(
    puzzleId: json['puzzleId'] ?? 'unknown',
    title: json['title'] ?? 'Linked Puzzle',
    author: json['author'] ?? 'Unknown',
    rows: size['rows'] as int,
    cols: size['cols'] as int,
    clues: clues,
    cellTypes: List<String>.from(json['cellTypes'] ?? []),
  );
}
```

### Task 1.2: Add `LinkedClue.fromJsonDirection()` Factory

Add a new factory method for parsing dual-direction format:

```dart
/// Parse from dual-direction format (no 'arrow' field, direction provided separately)
factory LinkedClue.fromJsonDirection(
  Map<String, dynamic> json, {
  required int clueNumber,
  required String direction,
}) {
  return LinkedClue(
    number: clueNumber,
    type: json['type'] as String? ?? 'text',
    content: json['content'] as String? ?? '',
    arrow: direction,  // 'across' or 'down'
    targetIndex: json['target_index'] as int? ?? 0,
    length: json['length'] as int? ?? 0,
  );
}
```

### Task 1.3: Verify `_cluesByClueCellIndex` Lookup Still Works

The constructor already iterates `clues.values` and builds the lookup map. With the new parsing:
- Single-direction: One clue per number → one entry in lookup
- Dual-direction: Two clues per number (with `_across`/`_down` suffix) → two entries in lookup at same cell index

The existing `getSplitClues()` method should work unchanged since it iterates clues at a cell and checks `isAcross`/`isDown`.

**Verify:** No changes needed to constructor or lookup methods.

---

### Phase 1 Testing

- [ ] **Test 1.1:** Parse existing single-direction puzzle JSON → clues load correctly
- [ ] **Test 1.2:** Parse new dual-direction puzzle JSON → both across and down clues created
- [ ] **Test 1.3:** Mixed puzzle with both formats → all clues parsed correctly
- [ ] **Test 1.4:** `getCluesAtCell()` returns both clues for dual-direction cell
- [ ] **Test 1.5:** `getSplitClues()` returns `[acrossClue, downClue]` in correct order
- [ ] **Test 1.6:** `isSplitClueCell()` returns true for dual-direction cells
- [ ] **Test 1.7:** Single-direction cells still work with `getClueAtCell()`

---

## Phase 2: Verify UI Rendering

**File:** `lib/screens/linked_game_screen.dart`

The UI already handles split clues! Verify the flow works:

### Task 2.1: Trace the Rendering Path

1. `_buildCell()` (line 581) checks `puzzle.isClueCell(index)`
2. If clue cell, checks `puzzle.getSplitClues(index)` (line 589)
3. If split clues exist → calls `_buildSplitClueCell(acrossClue, downClue)` (line 591)
4. Otherwise → calls `_buildClueCell(clue)` for single clue (line 597)

**Expected:** No code changes needed. The existing UI should "just work" with the updated parsing.

### Task 2.2: Verify Split Clue Cell Rendering

`_buildSplitClueCell()` (lines 715-739) renders:
- Top half: across clue with ▶ arrow
- Divider line
- Bottom half: down clue with ▼ arrow

`_buildSplitClueHalf()` (lines 742-799) renders each half with:
- Centered content (smaller font for split cells)
- Arrow indicator in appropriate corner

**Expected:** No changes needed. Matches Variant 1 design.

### Task 2.3: Verify Tap Dialog for Split Clues

`_showSplitClueDialog()` (lines 803-835) shows:
- Dialog title "Split Clue"
- Both clues with arrow indicators

**Expected:** No changes needed.

---

### Phase 2 Testing

- [ ] **Test 2.1:** Load puzzle with single-direction clues → renders as before
- [ ] **Test 2.2:** Load puzzle with dual-direction clue → split cell renders with horizontal layout
- [ ] **Test 2.3:** Tap split clue cell → dialog shows both clues
- [ ] **Test 2.4:** Both halves show correct content and arrow direction
- [ ] **Test 2.5:** Mixed puzzle renders correctly (some split, some single)
- [ ] **Test 2.6:** Emoji clues in split cells render at appropriate size
- [ ] **Test 2.7:** Long text clues truncate gracefully in split cells

---

## Phase 3: Create Test Puzzle

**File:** `api/data/puzzles/linked/{branch}/puzzle_test_dual.json` (new)

### Task 3.1: Create Sample Dual-Direction Puzzle

Create a small test puzzle (e.g., 5x5) that uses both formats:
- At least one dual-direction clue cell
- At least one single-direction clue cell
- Mix of text and emoji clues

### Task 3.2: Validate JSON Schema

Ensure the puzzle follows the format in `docs/PUZZLE_JSON_FORMAT_UPDATE.md`.

---

### Phase 3 Testing

- [ ] **Test 3.1:** Test puzzle loads without JSON parsing errors
- [ ] **Test 3.2:** All clue cells render correctly
- [ ] **Test 3.3:** Game is playable (answers can be placed)
- [ ] **Test 3.4:** Hint system works with dual-direction clues
- [ ] **Test 3.5:** Word completion detection works for both directions

---

## Phase 4: Edge Cases & Polish

### Task 4.1: Handle Partial Dual Clues

A dual-format clue might have only `across` OR only `down` (not both). Ensure parsing handles:
```json
"7": {
  "across": { "type": "text", "content": "LOVE", "target_index": 10 }
  // No "down" key
}
```

This should create a single clue, rendered as a normal clue cell (not split).

### Task 4.2: Validate `target_index` Consistency

For dual clues at cell X:
- Across clue: `target_index` should be X+1 (answer starts to the right)
- Down clue: `target_index` should be X+cols (answer starts below)

Add validation logging if indices seem inconsistent.

### Task 4.3: Accessibility

- Ensure screen readers announce both clues when split cell is focused
- Verify tap target is large enough for both halves

---

### Phase 4 Testing

- [ ] **Test 4.1:** Partial dual clue (only across) → renders as single clue cell
- [ ] **Test 4.2:** Partial dual clue (only down) → renders as single clue cell
- [ ] **Test 4.3:** Invalid target_index logs warning but doesn't crash
- [ ] **Test 4.4:** VoiceOver/TalkBack reads split clue content correctly
- [ ] **Test 4.5:** Existing puzzles still work after all changes

---

## Implementation Checklist

### Files to Modify

| File | Changes |
|------|---------|
| `lib/models/linked.dart` | Update `LinkedPuzzle.fromJson()`, add `LinkedClue.fromJsonDirection()` |
| `lib/screens/linked_game_screen.dart` | No changes expected (verify only) |

### Files to Create

| File | Purpose |
|------|---------|
| `api/data/puzzles/linked/casual/puzzle_test_dual.json` | Test puzzle with dual-direction clues |

### Backward Compatibility

- ✅ Single-direction puzzles continue to work unchanged
- ✅ Mixed puzzles (some single, some dual) supported
- ✅ No database migrations required
- ✅ No API changes required (puzzle JSON is loaded from static files)

---

## Rollback Plan

If issues arise:
1. Revert changes to `lib/models/linked.dart`
2. Dual-direction puzzles will fail to parse (no split clues shown)
3. Single-direction puzzles continue to work

---

## Next Steps After Completion

1. Create production dual-direction puzzles for each branch
2. Update puzzle authoring documentation
3. Consider puzzle editor support for dual-direction clues

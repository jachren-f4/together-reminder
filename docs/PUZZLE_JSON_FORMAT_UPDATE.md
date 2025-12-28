# Puzzle JSON Format Update: Dual-Direction Clues

## Overview

The puzzle JSON format has been extended to support **dual-direction clues** - a single clue cell that contains both an ACROSS and DOWN clue pointing to different answers. This is common in Scandinavian/Arroword-style crosswords where space is limited.

The format is **fully backward compatible**. Existing single-direction clues continue to work unchanged.

---

## Format Specification

### Single-Direction Clue (Original Format)

A clue pointing in one direction only:

```json
"7": {
  "type": "emoji",
  "content": "🌟",
  "arrow": "across",
  "target_index": 10
}
```

**Fields:**
- `type`: `"text"` or `"emoji"`
- `content`: The clue text or emoji
- `arrow`: `"across"` or `"down"`
- `target_index`: Grid index where the answer starts

---

### Dual-Direction Clue (New Format)

A clue cell with both ACROSS and DOWN clues:

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

**Structure:**
- Top-level keys are `"across"` and/or `"down"` (instead of having an `"arrow"` field)
- Each direction contains: `type`, `content`, `target_index`
- A clue can have just `"across"`, just `"down"`, or both

---

## How to Detect Which Format a Clue Uses

Check for the presence of the `"arrow"` key at the top level of the clue object:

- **If `"arrow"` exists** → Single-direction format (original)
  - Read `type`, `content`, `arrow`, and `target_index` directly from the clue object

- **If `"arrow"` does NOT exist** → Dual-direction format (new)
  - Look for `"across"` and/or `"down"` keys
  - Each direction key contains its own `type`, `content`, and `target_index`

---

## Grid Numbers (`gridnums`)

The `gridnums` array is **unchanged**. Each cell has at most one clue number, regardless of whether that clue has one or two directions.

Example: Cell at grid position with gridnum `7` may contain a dual-direction clue. Looking up clue `"7"` in the clues object reveals it has both `across` and `down` sub-clues.

---

## Complete Example

```json
{
  "clues": {
    "1": { "type": "emoji", "content": "🥂", "arrow": "down", "target_index": 8 },
    "2": { "type": "text", "content": "S__ said", "arrow": "down", "target_index": 10 },
    "7": {
      "across": { "type": "emoji", "content": "🌟", "target_index": 10 },
      "down": { "type": "text", "content": "LO_E", "target_index": 16 }
    },
    "18": {
      "across": { "type": "text", "content": "W_NT", "target_index": 38 },
      "down": { "type": "text", "content": "_RGY", "target_index": 44 }
    }
  }
}
```

In this example:
- Clues `1` and `2` use single-direction format (have `"arrow"` field)
- Clues `7` and `18` use dual-direction format (have `"across"` and `"down"` keys)

---

## Backward Compatibility

- **No migration required** for existing puzzles - the old format continues to work
- New puzzles may use either format, or mix both formats in the same puzzle
- The parser should handle both formats transparently

---

## Validation Rules

**Single-direction clues must have:**
- `type` (either `"text"` or `"emoji"`)
- `content` (the clue string or emoji)
- `arrow` (either `"across"` or `"down"`)
- `target_index` (valid grid index from 0 to rows×cols-1)

**Dual-direction clues must have:**
- At least one of: `"across"` or `"down"` (can have both)
- Must NOT have `"arrow"` at the top level
- Each direction object must contain: `type`, `content`, `target_index`

---

## Reference

See `pipeline/puzzle_001_updated.json` for a complete working example with both formats.

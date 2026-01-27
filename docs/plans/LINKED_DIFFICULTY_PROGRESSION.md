# Linked (Crossword) Difficulty Progression

**Status:** Future Project
**Origin:** Playtest Feedback Session 1 (2025-01-20)
**Priority:** Deferred

---

## Issue Identified

First puzzles too hard for beginners. Users suggested a graduated difficulty progression:
- Start with smaller grids (4x6)
- Progress to medium (5x7)
- Then standard size (6x8+)

---

## Current State

- Fixed puzzle sizes from content
- No graduated difficulty for new users
- All puzzles presented at same complexity level

---

## Proposed Solution

### Grid Size Progression

| Puzzle # | Grid Size | Notes |
|----------|-----------|-------|
| 1-4 | 4x6 | Beginner - fewer cells, simpler clues |
| 5-8 | 5x7 | Intermediate - moderate complexity |
| 9+ | 6x8+ | Standard - full difficulty |

### Implementation Requirements

1. **Content Creation**
   - Need new "beginner" puzzle content with smaller grids
   - Simpler clues for early puzzles
   - May need emoji-only clues for visual clarity

2. **Puzzle Loading Logic**
   - Track user's puzzle completion count
   - Select appropriate difficulty based on progress
   - File: `api/lib/puzzle/loader.ts`

3. **Grid Rendering**
   - Ensure UI scales properly for different grid sizes
   - File: `app/lib/screens/linked_game_screen.dart`

---

## Mockup Required

`mockups/phase4/linked_grid_sizes.html`
- Visual comparison of 4x6, 5x7, 6x8 grids
- Show how clues fit at each size
- Mobile viewport representation

---

## Files to Modify

| File | Changes |
|------|---------|
| `api/data/puzzles/linked/*.json` | New beginner puzzle content |
| `api/lib/puzzle/loader.ts` | Difficulty selection logic |
| `app/lib/screens/linked_game_screen.dart` | Grid size handling (if needed) |

---

## Dependencies

- Requires puzzle content creation (design/writing work)
- May need content creator or AI-assisted puzzle generation
- Should be tested with actual beginners

---

## Notes

This is a content/data change more than a UI change. The main work is creating appropriate beginner-level puzzle content with smaller grids and simpler clues.

---

*Extracted from: `docs/feedback_session_1.md` (Phase 4.3)*
*Created: 2025-01-20*

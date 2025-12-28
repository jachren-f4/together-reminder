# Linked

## Overview

Linked is a collaborative crossword puzzle side quest. Partners take turns solving clues to fill in the grid together.

### How It Works

1. A crossword puzzle is presented with clues (text hints or emoji hints)
2. Partners take turns—one solves a clue, then it's the other's turn
3. Progress is shared in real-time
4. Puzzle completes when all words are filled

### Turn-Based Collaboration

Unlike quizzes where both answer independently, Linked requires **active cooperation**:
- You can't finish alone—you need your partner
- Each contribution builds on the other's work
- Creates anticipation ("let me see what they solved!")

---

## Value Proposition

**"Work together on a puzzle—a shared accomplishment you build turn by turn."**

### What Makes Linked Engaging

| Aspect | Value |
|--------|-------|
| Collaboration | Feel like a team solving something together |
| Anticipation | Waiting for partner's turn creates engagement |
| Shared victory | Completing the puzzle is a joint accomplishment |
| Mental stimulation | Light brain exercise as a couple activity |

### The Goal

After completing a Linked puzzle, couples should:
- Feel they accomplished something together
- Have experienced a non-competitive shared activity
- Possibly have learned a new word or had a "aha!" moment

---

## Branches

Linked uses **theme-based branches** that affect word selection:

| Branch | Tone | Word Themes |
|--------|------|-------------|
| `casual` | Everyday | Common words, everyday concepts |
| `romantic` | Sweet | Love-related words, relationship terms |
| `adult` | Intimate | Suggestive words, mature themes |

### Branch Cycling

Branches rotate: casual → romantic → adult → casual → ...

---

## Content Guidelines

### Puzzle Structure

Each puzzle contains:
- **Grid**: Letter grid with empty cells and blocked cells
- **Clues**: Hints pointing to words (text or emoji)
- **Answers**: Words that fit into the grid

### Clue Types

| Type | Example | Best For |
|------|---------|----------|
| Text hint | "Divide in two" → HALF | Traditional crossword feel |
| Emoji hint | "🌟" → STAR | Quick, visual, accessible |
| Fill-in-blank | "Come ___" → OVER | Phrase completion |
| Letter pattern | "W_NT" → WANT | Partial reveal |

### Good Clue Criteria

| Criteria | Why |
|----------|-----|
| Fair difficulty | Solvable but requires thought |
| Clear answer | One obvious correct word |
| Appropriate to branch | Romantic branch = love-themed words |
| Varied clue types | Mix of text, emoji, fill-in-blank |

### Difficulty Balance

Puzzles should have:
- 2-3 easy clues (quick wins, momentum)
- 3-4 medium clues (satisfying to solve)
- 1-2 harder clues (sense of accomplishment)

### Branch-Specific Content

**Casual**: Everyday vocabulary
- Words: HOME, WORK, TIME, PLAY, FOOD
- Clues: Common phrases, obvious emojis

**Romantic**: Love and relationship themes
- Words: HEART, KISS, LOVE, DATE, SWEET
- Clues: Romantic phrases, heart emojis

**Adult**: Mature themes (tasteful)
- Words: DESIRE, PASSION, TOUCH, NIGHT
- Clues: Suggestive but not explicit

---

## Technical Reference

### File Locations

| Location | Purpose |
|----------|---------|
| `api/data/puzzles/linked/{branch}/puzzle_001.json` | Puzzle content |
| `lib/screens/linked_game_screen.dart` | Game UI |
| `lib/services/linked_service.dart` | Game logic |
| `docs/features/LINKED.md` | Feature documentation |

### Puzzle File Format

```json
{
  "puzzleId": "puzzle_001",
  "title": "Casual Puzzle #1",
  "size": { "rows": 9, "cols": 7 },
  "grid": [".", ".", "T", "H", "E", ".", ".", ...],
  "gridnums": [0, 0, 1, 0, 0, 2, 0, ...],
  "clues": {
    "1": { "type": "emoji", "content": "🥂", "arrow": "down", "target_index": 8 },
    "2": { "type": "text", "content": "This ___ that", "arrow": "down", "target_index": 11 }
  }
}
```

### Clue Fields

| Field | Description |
|-------|-------------|
| `type` | "emoji" or "text" |
| `content` | The hint (emoji character or text string) |
| `arrow` | Direction: "across" or "down" |
| `target_index` | Starting cell index in grid |

---

**Last Updated:** 2025-12-17

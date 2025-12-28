# Word Search

## Overview

Word Search is a side quest where partners find hidden words in a letter grid. It's a relaxing, collaborative puzzle activity.

### How It Works

1. A grid of letters is presented with a list of words to find
2. Partners take turns finding words (or play independently)
3. Words can be hidden horizontally, vertically, or diagonally
4. Puzzle completes when all words are found

### Casual Collaboration

Word Search is lower-pressure than Linked:
- Can be played more independently
- Finding words feels satisfying
- Relaxing puzzle experience

---

## Value Proposition

**"A relaxing word puzzle to enjoy together—find the hidden words as a team."**

### What Makes Word Search Engaging

| Aspect | Value |
|--------|-------|
| Relaxing | Low-stress puzzle activity |
| Satisfying | Finding hidden words feels good |
| Thematic | Words relate to love/relationships |
| Quick wins | Each word found is a small victory |

### The Goal

After completing a Word Search, couples should:
- Feel relaxed and accomplished
- Have noticed the thematic words (love-related)
- Possibly sparked conversation from a word theme

---

## Branches

Word Search uses **tone-based branches** affecting word selection:

| Branch | Tone | Word Themes |
|--------|------|-------------|
| `everyday` | Casual | Daily life, simple relationship words |
| `passionate` | Romantic | Love, romance, affection |
| `naughty` | Playful/adult | Suggestive, intimate themes |

### Branch Cycling

Branches rotate: everyday → passionate → naughty → everyday → ...

---

## Content Guidelines

### Word Selection Criteria

| Criteria | Why |
|----------|-----|
| On-theme | Words should fit the branch theme |
| Varied length | Mix of short (4-5) and longer (7-8) words |
| Recognizable | Common vocabulary, easily spotted |
| Relationship-relevant | Connect to couple/love themes |

### Branch-Specific Words

**Everyday**: Daily relationship life
- WALK, CHAT, DATE, COUPLE, CONTENT
- THANKFUL, TOUCH, GIFT, WEEKEND

**Passionate**: Romance and love
- HEART, KISS, ADORE, PASSION, DESIRE
- ROMANCE, SWEET, CHERISH, EMBRACE

**Naughty**: Playful intimacy
- FLIRT, TEASE, TEMPT, SEDUCE
- (Keep tasteful—suggestive, not explicit)

### Grid Design

| Aspect | Guideline |
|--------|-----------|
| Size | 10x10 is standard, readable on mobile |
| Word count | 10-12 words per puzzle |
| Directions | Include horizontal, vertical, and diagonal |
| Difficulty | Most words should be findable within 2-3 minutes |

### Word Placement

Words can be placed in multiple directions:
- `R` = Right (horizontal)
- `D` = Down (vertical)
- `DR` = Diagonal down-right
- `DL` = Diagonal down-left
- `U` = Up (vertical, reversed)
- `L` = Left (horizontal, reversed)
- `UR` = Diagonal up-right
- `UL` = Diagonal up-left

---

## Technical Reference

### File Locations

| Location | Purpose |
|----------|---------|
| `api/data/puzzles/word-search/{branch}/ws_001.json` | Puzzle content |
| `lib/screens/word_search_game_screen.dart` | Game UI |
| `lib/services/word_search_service.dart` | Game logic |
| `docs/features/WORD_SEARCH.md` | Feature documentation |

### Puzzle File Format

```json
{
  "puzzleId": "ws_001",
  "title": "Daily Love I",
  "theme": "everyday",
  "size": { "rows": 10, "cols": 10 },
  "grid": "VSCPYJHLAPWYAWALKUTTPEKOFQGFO...",
  "words": {
    "CONTENT": "36,L",
    "WALK": "13,R",
    "COUPLE": "80,R"
  }
}
```

### Word Placement Format

Each word entry: `"WORD": "startIndex,direction"`

- `startIndex`: Position in the flat grid string (0-indexed)
- `direction`: Letter code for direction (R, D, DR, etc.)

Example: `"WALK": "13,R"` means WALK starts at index 13 and goes right.

---

**Last Updated:** 2025-12-17

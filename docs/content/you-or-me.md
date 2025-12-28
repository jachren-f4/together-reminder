# You or Me

## Overview

You or Me is a side quest where partners answer "Who is more likely to..." questions by choosing either "You" (their partner) or "Me" (themselves). Answers are compared to see if partners agree on who does what.

### How It Works

1. Both partners see the same prompts like "Who is more likely to laugh at their own jokes?"
2. Each person picks either "You" (partner) or "Me" (self)
3. Answers are compared:
   - **Match**: Both agree on who it is (both said "Me" about themselves, or both pointed to the same person)
   - **Mismatch**: They disagree about who fits the description

### The Mechanic's Charm

The fun comes from seeing if you have the same perception of your dynamic:
- "We both think you're the messy one" → Shared understanding
- "We both think WE'RE the romantic one" → Playful disagreement
- "I think you're stubborn, you think I am" → Neither wants to admit it!

---

## Value Proposition

**"Playfully discover how you see your dynamic—and whether you agree on who's who."**

### What Makes Prompts Fun

The best You or Me questions create moments of:
- **Recognition**: "Yes, that's totally you!"
- **Playful debate**: "Wait, you think YOU'RE the patient one?!"
- **Self-awareness**: "Okay fine, I am the one who loses things"

### The Goal

After completing You or Me, couples should:
- Have laughed together about their dynamic
- Discovered perceptions they share (and don't share)
- Have fodder for playful teasing

---

## Branches

You or Me uses **tone-based branches**:

| Branch | Tone | Content Focus |
|--------|------|---------------|
| `playful` | Fun, silly | Quirks, funny habits, harmless traits |
| `reflective` | Thoughtful | Strengths, relationship roles, tendencies |
| `intimate` | Flirtatious | Romantic dynamics, attraction, desire |
| `lighthearted` | Easy, casual | Simple everyday observations |
| `connection` | Meaningful | Emotional dynamics, support patterns |
| `attachment` | Secure | Trust, reliability, commitment behaviors |
| `growth` | Aspirational | Goals, ambitions, who pushes whom |

---

## Content Guidelines

### Prompt Structure

All prompts follow the pattern:
- **Prompt prefix**: "Who is more..." or "Who would..."
- **Content**: The trait or behavior being evaluated

```json
{
  "prompt": "Who is more...",
  "content": "Likely to laugh at their own jokes"
}
```

### Good Prompt Criteria

| Criteria | Good Example | Why |
|----------|--------------|-----|
| Observable | "Likely to forget where they put their keys" | Both can evaluate from experience |
| Debatable | "The romantic one in our relationship" | Partners might disagree! |
| Playful framing | "Likely to eat the last slice without asking" | Fun to argue about |
| Not judgmental | "More spontaneous" | Neither answer is "bad" |

### Poor Prompt Criteria

| Criteria | Poor Example | Why |
|----------|--------------|-----|
| Obvious answer | "More likely to give birth" (hetero couple) | No fun if answer is predetermined |
| Mean-spirited | "More selfish" | Creates conflict, not connection |
| Too vague | "Better" | Better at what? |
| Uncomfortable truth | "More likely to cheat" | Not playful, genuinely concerning |

### Tone Guidelines by Branch

**Playful**: Keep it silly and harmless
- "More likely to dance in public"
- "More likely to cry at commercials"
- "More likely to binge a whole season in one sitting"

**Reflective**: Acknowledge real strengths and roles
- "The one who stays calmer in a crisis"
- "More likely to remember important dates"
- "The better listener"

**Intimate**: Flirtatious but tasteful
- "More likely to initiate physical affection"
- "The one who gives better massages"
- "More romantic overall"

---

## Examples

### Good Playful Prompt

```json
{
  "prompt": "Who would...",
  "content": "Get more competitive during board games"
}
```

**Why it works:**
- Observable behavior both can evaluate
- Playful—neither answer is bad
- Creates fun teasing potential

### Good Reflective Prompt

```json
{
  "prompt": "Who is more...",
  "content": "Likely to apologize first after an argument"
}
```

**Why it works:**
- Reveals how they see conflict dynamics
- Match = shared understanding of pattern
- Mismatch = interesting conversation about perception

### Poor Prompt

```json
{
  "prompt": "Who is more...",
  "content": "Difficult to live with"
}
```

**Why it fails:**
- Negative framing
- Picking "You" feels accusatory
- Picking "Me" feels like fishing for reassurance
- Not fun, just uncomfortable

---

## Technical Reference

### Answer Encoding

Important: You or Me uses **relative encoding**:
- User taps "You" → sends 0 (pointing to partner)
- User taps "Me" → sends 1 (pointing to self)
- Server inverts for comparison

See `api/lib/game/handler.ts:381-399` for server-side logic.

### File Locations

| Location | Purpose |
|----------|---------|
| `api/data/puzzles/you-or-me/{branch}/quiz_001.json` | Server-side content |
| `lib/services/you_or_me_match_service.dart` | Game logic |

### Quiz File Format

```json
{
  "quizId": "quiz_001",
  "title": "Playful Quiz 1",
  "branch": "playful",
  "questions": [
    {
      "id": "quiz_001_q1",
      "category": "personality",
      "prompt": "Who is more...",
      "content": "Likely to laugh at their own jokes"
    }
  ]
}
```

---

**Last Updated:** 2025-12-17

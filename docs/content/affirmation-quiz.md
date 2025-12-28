# Affirmation Quiz

## Overview

The Affirmation Quiz is a daily quest where both partners rate statements on an agree/disagree scale. Answers are compared to reveal shared perspectives and differences.

### How It Works

1. Both partners receive the same 5 statements
2. Each person rates how much they agree/disagree **for themselves**
3. Uses a 5-point scale: Strongly Disagree → Disagree → Neutral → Agree → Strongly Agree
4. Answers are compared when both complete
5. Result shows alignment percentage

### Key Difference from Classic Quiz

- Classic Quiz: Multiple choice options (discrete categories)
- Affirmation Quiz: Scale-based responses (degree of agreement)

This format works better for **beliefs, attitudes, and values** rather than preferences.

---

## Value Proposition

**"Understand how your partner sees the world and where your perspectives align."**

### What Makes Statements Valuable

Affirmation statements reveal **attitudes and beliefs** that affect how partners navigate life together:

| Statement Type | Match Means | Mismatch Means |
|---------------|-------------|----------------|
| "I prefer quiet mornings" | We're aligned on morning energy | One of us needs adjustment/understanding |
| "I believe in planning ahead" | Shared approach to life | We'll need to negotiate spontaneity vs. structure |
| "Physical touch is important to me" | Both prioritize physical connection | One may feel neglected without knowing why |

### The Goal

After completing an Affirmation Quiz, couples should:
- Understand each other's attitudes and values better
- Recognize where they're naturally aligned
- Identify areas that may need discussion or compromise

---

## Branches

Affirmation Quiz uses **thematic branches**:

| Branch | Focus | Content Style |
|--------|-------|---------------|
| `lighthearted` | Daily habits, lifestyle | Easy, low-stakes statements |
| `playful` | Fun preferences, quirks | Light and amusing |
| `emotional` | Feelings, emotional needs | Deeper self-awareness |
| `practical` | Life management, decisions | Pragmatic topics |
| `spiritual` | Beliefs, meaning, purpose | Reflective and deeper |
| `connection` | Relationship dynamics | About the partnership |
| `attachment` | Security, commitment | Trust and stability |
| `growth` | Aspirations, development | Forward-looking |

---

## Lighthearted Branch Content

The lighthearted branch contains 12 quizzes (60 statements) organized by theme:

| Quiz | Theme | Sample Statement |
|------|-------|------------------|
| 001 | Energy & Recharging | "I need alone time to recharge, even from people I love" |
| 002 | Support & Comfort | "When I'm upset, I want comfort before solutions" |
| 003 | Communication Styles | "I think out loud and process by talking" |
| 004 | Quality Time | "I feel connected even when we're doing separate things in the same room" |
| 005 | Social Life | "I need advance notice before social commitments" |
| 006 | Home & Space | "A tidy space helps me think clearly and feel calm" |
| 007 | Planning & Structure | "Last-minute plans stress me out" |
| 008 | Handling Conflict | "I need time to cool down before discussing something that upset me" |
| 009 | Affection & Connection | "I need regular reassurance that I'm loved" |
| 010 | Stress & Coping | "When stressed, I tend to withdraw and get quiet" |
| 011 | Growth & Change | "I find it hard to accept criticism, even constructive feedback" |
| 012 | Relationship Priorities | "Feeling understood is more important to me than being agreed with" |

### Why These Themes Work

Each theme focuses on **patterns that affect daily life together**:

| Theme | Match Insight | Mismatch Insight |
|-------|---------------|------------------|
| Energy & Recharging | "We both need space to recharge" | "I need alone time, you need togetherness—now I understand" |
| Support & Comfort | "We both want the same kind of support" | "You want solutions, I want comfort first" |
| Handling Conflict | "We both need time to cool down" | "You want to talk now, I need space—explains past friction" |
| Affection & Connection | "We show love the same way" | "I need words, you show through actions" |

---

## Content Guidelines

### Statement Structure

Statements should be:
- First-person perspective: "I prefer...", "I believe...", "I feel..."
- Clear enough to rate on agree/disagree scale
- Not questions—statements to evaluate

### Good Statement Criteria

| Criteria | Good Example | Why |
|----------|--------------|-----|
| Reveals attitude | "I need time to process before discussing problems" | Shows communication style |
| Affects relationship | "Physical affection is how I feel most connected" | Partner can act on this |
| Scale makes sense | "I'm at my best in the morning" | Clear spectrum from disagree to agree |
| Not obvious | "Adventure is more important than comfort" | People genuinely differ on this |

### Poor Statement Criteria

| Criteria | Poor Example | Why |
|----------|--------------|-----|
| Trivially true | "I enjoy feeling loved" | Everyone would agree |
| Too specific | "I like coffee at 7am" | Scale doesn't fit well |
| No relationship relevance | "The sky is blue" | Knowing alignment adds nothing |
| Leading/judgmental | "I don't waste money" | Loaded language |

### Scale Considerations

The 5-point scale works best when:
- People genuinely fall across the spectrum
- Both extremes are valid positions
- The middle (Neutral) is a legitimate stance

---

## Examples

### Good Lighthearted Statement

```json
{
  "text": "When I'm upset, I want comfort before solutions",
  "type": "scale",
  "scaleLabels": ["Strongly Disagree", "Disagree", "Neutral", "Agree", "Strongly Agree"]
}
```

**Why it works:**
- People genuinely differ on this
- Directly affects how partner should respond
- Match → "We both want the same thing when upset"
- Mismatch → "Now I understand why my advice felt unwelcome"

### Good Emotional Statement

```json
{
  "text": "I need to process difficult feelings on my own before talking about them",
  "type": "scale",
  "scaleLabels": ["Strongly Disagree", "Disagree", "Neutral", "Agree", "Strongly Agree"]
}
```

**Why it works:**
- Reveals emotional processing style
- Directly affects how partner should respond during hard times
- Mismatch is illuminating: "I thought you were shutting me out, but you just needed time"

### Poor Statement

```json
{
  "text": "I enjoy trying new restaurants regularly",
  "type": "scale"
}
```

**Why it fails:**
- Entertainment preference, low relationship stakes
- Match → "Cool, we both like dining out" (so what?)
- Mismatch → Doesn't reveal anything important about supporting each other

---

## Technical Reference

### File Locations

| Location | Purpose |
|----------|---------|
| `api/data/puzzles/affirmation/{branch}/affirmation_001.json` | Server-side content |
| `app/assets/brands/togetherremind/data/affirmation/{branch}/` | App-side assets |
| `lib/services/affirmation_quiz_bank.dart` | Content loading |

### Quiz File Format

```json
{
  "quizId": "affirmation_001",
  "title": "Energy & Recharging",
  "category": "lighthearted",
  "branch": "lighthearted",
  "description": "How you restore and maintain your energy",
  "questions": [
    {
      "id": "affirmation_001_q1",
      "text": "I need alone time to recharge, even from people I love",
      "type": "scale",
      "scaleLabels": ["Strongly Disagree", "Disagree", "Neutral", "Agree", "Strongly Agree"]
    }
  ]
}
```

---

**Last Updated:** 2025-12-17
**Lighthearted Branch Rewritten:** 2025-12-17

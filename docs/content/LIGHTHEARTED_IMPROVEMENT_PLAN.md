# Lighthearted Branch Improvement Plan

This document outlines the plan to improve the Classic Quiz lighthearted branch content.

---

## Problem Statement

The current lighthearted quiz questions focus on **surface-level trivia** where alignment/difference is meaningless:

| Current Question | Issue |
|-----------------|-------|
| "What's my favorite sandwich?" | Match = coincidence, Mismatch = irrelevant |
| "Coffee or tea?" | Fun but reveals nothing useful |
| "Favorite sport to watch?" | Knowing this doesn't help the relationship |

### The Core Problem

The mechanic is: **"80% match! You answered 4/5 similarly!"**

For this to be valuable, matches and mismatches must **reveal something useful about living together**.

---

## Goal

Transform lighthearted questions to reveal **patterns that affect the relationship** while keeping the tone **fun and accessible**.

### New Value Proposition

> "Discover where you naturally align and where you differ—on things that actually matter for your life together."

### Target Feeling

After completing a lighthearted quiz, couples should:
- Learn something actionable about each other
- Have a natural conversation starter
- Understand each other's needs/preferences better
- **NOT** just know random trivia facts

---

## Content Categories

Replace current categories (`favorites`, `preferences`, `would_you_rather`) with:

| Category | Focus | Example Question |
|----------|-------|------------------|
| `self_care` | How each person recharges and recovers | "When I've had a long day, what helps me unwind?" |
| `connection` | How to stay connected during daily life | "How do I prefer us to stay connected during busy days?" |
| `lifestyle` | Weekend and free time preferences | "What kind of weekend sounds best to me?" |
| `together` | How you make decisions and plans as a couple | "When we're making plans together, I usually prefer to..." |
| `social` | Social preferences and comfort levels | "In social situations, I'm most comfortable when..." |
| `support` | How each person likes to be supported | "When something's bothering me, what helps most?" |
| `energy` | Energy patterns and rhythms | "What time of day am I at my best?" |
| `communication` | Communication preferences | "When I'm upset, I prefer to..." |

---

## Answer Option Guidelines

Since Classic Quiz is multiple-choice, options must:

### Do
- Represent **genuine categories** people fall into
- Cover the realistic spectrum of answers
- Feel like "choosing your type" not "picking from arbitrary options"

### Don't
- List arbitrary specific items (pizza, sushi, tacos)
- Force people into overly narrow boxes
- Make one option obviously "better"

### Good Example

```json
{
  "text": "When I've had a long day, what helps me unwind?",
  "choices": [
    "Quiet time alone",
    "Talking about my day",
    "Physical activity or movement",
    "Comfort food or a treat",
    "Distraction (TV, games, scrolling)"
  ]
}
```

### Poor Example

```json
{
  "text": "What's my favorite food?",
  "choices": [
    "Pizza",
    "Sushi",
    "Pasta",
    "Tacos",
    "Other"
  ]
}
```

---

## Quiz-by-Quiz Rewrite Plan

### File Locations

- Server: `api/data/puzzles/classic-quiz/lighthearted/quiz_001.json` through `quiz_012.json`
- App assets: `app/assets/brands/togetherremind/data/classic-quiz/lighthearted/questions.json`

### Quiz Themes

Each quiz should have a loose theme for coherence:

| Quiz | Theme | Sample Topics |
|------|-------|---------------|
| quiz_001 | Daily Life Patterns | Unwinding, staying connected, weekends |
| quiz_002 | Energy & Support | Recharging, stress handling, support needs |
| quiz_003 | Communication | Expressing feelings, processing conflict |
| quiz_004 | Support & Care | What helps when stressed, how to comfort |
| quiz_005 | Decision Making | Planning vs. spontaneity, leading vs. following |
| quiz_006 | Morning & Evening | Morning routines, bedtime preferences |
| quiz_007 | Quality Time | Date nights, together activities |
| quiz_008 | Home Life | Household preferences, living together |
| quiz_009 | Celebrations | Birthdays, milestones, surprises |
| quiz_010 | Travel & Adventure | Travel styles, adventure appetite |
| quiz_011 | Money & Priorities | Spending priorities, financial attitudes |
| quiz_012 | Future Dreams | Life goals, aspirations (light version) |

---

## Sample Rewritten Quiz (quiz_001)

### Current Content (to replace)

```json
{
  "quizId": "quiz_001",
  "title": "Lighthearted Quiz 1",
  "questions": [
    { "text": "Do I prefer sweet or savory snacks?", ... },
    { "text": "Do I prefer texting or calling?", ... },
    { "text": "What's my favorite sport to watch?", ... },
    { "text": "Do I prefer planning or spontaneity?", ... },
    { "text": "What's my preferred social group size?", ... }
  ]
}
```

### New Content

```json
{
  "quizId": "quiz_001",
  "title": "Daily Life Patterns",
  "branch": "lighthearted",
  "questions": [
    {
      "id": "quiz_001_q1",
      "text": "When I've had a long day, what helps me unwind?",
      "choices": [
        "Quiet time alone",
        "Talking about my day",
        "Physical activity or movement",
        "Comfort food or a treat",
        "Distraction (TV, games, scrolling)"
      ],
      "category": "self_care"
    },
    {
      "id": "quiz_001_q2",
      "text": "How do I prefer us to stay connected during busy days?",
      "choices": [
        "Quick check-in texts",
        "A phone call, even if brief",
        "Save it for quality time later",
        "Sharing memes or funny things",
        "Other / It depends"
      ],
      "category": "connection"
    },
    {
      "id": "quiz_001_q3",
      "text": "What kind of weekend sounds best to me?",
      "choices": [
        "Adventure and exploring",
        "Social plans with friends/family",
        "Cozy and low-key at home",
        "Productive (errands, projects)",
        "A mix - no strong preference"
      ],
      "category": "lifestyle"
    },
    {
      "id": "quiz_001_q4",
      "text": "When we're making plans together, I usually prefer to...",
      "choices": [
        "Plan everything in advance",
        "Have a loose plan, stay flexible",
        "Decide in the moment",
        "Let you take the lead",
        "Other / It depends"
      ],
      "category": "together"
    },
    {
      "id": "quiz_001_q5",
      "text": "In social situations, I'm most comfortable when...",
      "choices": [
        "It's just the two of us",
        "We're with a few close friends",
        "There's a bigger group with energy",
        "I can come and go as I please",
        "Other / It varies"
      ],
      "category": "social"
    }
  ]
}
```

---

## Implementation Checklist

- [x] Finalize question content for all 12 quizzes (60 questions total) ✅ 2025-12-17
- [x] Update `api/data/puzzles/classic-quiz/lighthearted/quiz_*.json` files ✅ 2025-12-17
- [ ] Update `app/assets/brands/togetherremind/data/classic-quiz/lighthearted/questions.json` (if needed)
- [ ] Update HolyCouples brand if applicable
- [ ] Test on device to verify questions display correctly
- [ ] Verify match percentage mechanic still works as expected

---

## Success Criteria

After implementation, the lighthearted branch should:

1. **Feel accessible**: Not emotionally heavy, easy to answer
2. **Reveal useful patterns**: Matches/mismatches tell you something
3. **Spark conversation**: Natural follow-ups like "I didn't know that about you"
4. **Work with the mechanic**: Match percentage feels meaningful

---

## Implementation Status

**Status: IMPLEMENTED** ✅

All 12 quizzes (60 questions) have been rewritten and deployed to `api/data/puzzles/classic-quiz/lighthearted/`.

### Remaining Tasks
- Test on device to verify questions display correctly
- Verify match percentage mechanic still works as expected
- Update HolyCouples brand if needed

---

**Last Updated:** 2025-12-17
**Implemented:** 2025-12-17

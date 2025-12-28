# Classic Quiz

## Overview

The Classic Quiz is a daily quest where both partners answer the same multiple-choice questions about themselves. Answers are compared to show alignment.

### How It Works

1. Both partners receive the same 5-question quiz
2. Each person answers questions **about themselves** (not guessing about partner)
3. Answers are compared when both complete
4. Result shows match percentage: "80% match! You answered 4/5 similarly!"

### Key Insight

The value comes from **what alignment and differences reveal**, not from the match percentage itself.

---

## Value Proposition

**"Discover where you naturally align and where you differ—on things that actually matter for your life together."**

### What Makes a Match Meaningful

| Question Type | Match Means | Mismatch Means |
|--------------|-------------|----------------|
| Surface trivia | "We both like pizza" | "You like sushi, I like tacos" |
| **Meaningful** | "We recharge the same way" | "Now I understand why you need alone time" |

A mismatch is not a failure—it's **illuminating**. Good questions make differences feel like discoveries, not problems.

### The Goal

After completing a Classic Quiz, couples should:
- Learn something new about each other (or confirm something important)
- Have a natural conversation starter ("I didn't know you felt that way about...")
- Understand each other's needs, preferences, or perspectives better

---

## Branches

Classic Quiz uses a **depth progression** branch system:

| Branch | Tone | Content Focus |
|--------|------|---------------|
| `lighthearted` | Fun, easy, accessible | Everyday preferences, lifestyle compatibility |
| `meaningful` | Thoughtful, reflective | Values, emotional needs, relationship dynamics |
| `spicy` | Playful, intimate | Physical intimacy, desires, romantic preferences |
| `connection` | Deep, vulnerable | Love languages, emotional bonds, trust |
| `attachment` | Secure, reassuring | Security needs, commitment, future together |
| `growth` | Aspirational | Goals, dreams, personal development |

### Branch Cycling

Couples progress through branches based on completion count. The exact rotation is defined in `lib/models/branch_progression_state.dart`.

---

## Branch: Lighthearted

### Target Tone
- Fun and easy
- Low emotional stakes
- Good for new couples or quick daily engagement

### Content Focus
Questions about everyday preferences and lifestyle compatibility where alignment/difference actually tells you something useful about living together.

### Implemented Quiz Themes

The lighthearted branch contains 12 quizzes (60 questions) organized by theme:

| Quiz | Theme | Sample Question |
|------|-------|-----------------|
| 001 | Daily Life Patterns | "When I've had a long day, what helps me unwind?" |
| 002 | Energy & Support | "When something's bothering me, what helps most?" |
| 003 | Communication Styles | "When I'm upset, I prefer to..." |
| 004 | Showing Care | "I feel most loved when you..." |
| 005 | Decisions & Planning | "When making a big decision, I usually..." |
| 006 | Morning & Evening | "In the morning, I need..." |
| 007 | Quality Time | "I feel closest to you when we're..." |
| 008 | Home Life | "My tolerance for mess at home is..." |
| 009 | Celebrations & Milestones | "For my birthday, I'd prefer..." |
| 010 | Travel & Adventure | "My ideal vacation style is..." |
| 011 | Money & Priorities | "When it comes to spending money, I'm usually..." |
| 012 | Dreams & Goals | "Where do I see us in 5 years?" |

### Good Question Criteria

Questions should reveal **patterns that affect the relationship**:

| Category | Example | Why It Works |
|----------|---------|--------------|
| Energy & recharging | "When I've had a long day, what helps me unwind?" | Affects how you support each other |
| Communication | "How do I prefer us to stay connected during busy days?" | Directly about the relationship |
| Lifestyle | "What kind of weekend sounds best to me?" | Affects shared time planning |
| Social preferences | "In social situations, I'm most comfortable when..." | Helps navigate social events together |
| Decision-making | "When we're making plans together, I usually prefer to..." | Affects how you collaborate |

### Poor Question Criteria

Avoid questions where alignment/difference is meaningless:

| Category | Example | Why It's Weak |
|----------|---------|---------------|
| Arbitrary favorites | "What's my favorite sandwich?" | Who cares if you both like BLT? |
| Trivia | "What's my favorite sport to watch?" | Knowing this doesn't help the relationship |
| Binary preferences | "Coffee or tea?" | Fun but reveals nothing useful |
| Generic would-you-rather | "Would you rather have wings or gills?" | Entertainment only, no insight |

### Answer Options Guidelines

Since this is multiple-choice, options must:
- Represent **genuine categories** people fall into
- Cover the realistic spectrum of answers
- Not feel arbitrary or limiting

**Good options** (for "How do you unwind?"):
- Quiet time alone
- Talking about my day
- Physical activity
- Comfort food or treats
- Distraction (TV, games)

**Poor options** (for "Favorite food?"):
- Pizza, Sushi, Pasta, Tacos
- (These are arbitrary—why these four?)

---

## Branch: Meaningful

### Target Tone
- Thoughtful and reflective
- Medium emotional depth
- Encourages vulnerability without being heavy

### Content Focus
Questions about values, emotional needs, and how partners relate to each other.

### Good Question Examples
- "What topic do I wish we talked about more?"
- "When do I feel closest to you?"
- "What part of our relationship makes me feel most secure?"
- "How do I typically show that I care?"

---

## Branch: Spicy

### Target Tone
- Playful and flirtatious
- Intimate but not explicit
- Fun exploration of physical/romantic connection

### Content Focus
Questions about physical intimacy, romantic preferences, and desires—keeping it tasteful.

### Good Question Examples
- "What's my favorite way to be shown affection?"
- "When do I feel most attracted to you?"
- "What kind of date night puts me in a romantic mood?"

---

## Content Guidelines

### Question Structure

All questions should be phrased from the answerer's perspective:
- "What helps **me** unwind?" (answering about self)
- NOT "What helps your partner unwind?" (guessing about other)

### The "So What?" Test

Before adding a question, ask: **"If we match, so what? If we differ, so what?"**

- ✅ "How do I handle stress?" → Match = easy coexistence, Mismatch = now you understand my needs
- ❌ "Favorite color?" → Match = coincidence, Mismatch = irrelevant

### Conversation Potential

Good questions naturally lead to follow-up conversation:
- "I didn't know you needed alone time to recharge—I thought you were upset with me"
- "We both value quality time over gifts—that's good to know for birthdays"

### Multiple Choice Constraints

Remember: Options must work as genuine categories. If a question requires open-ended answers to be meaningful, it's not right for Classic Quiz.

---

## Examples

### Good Lighthearted Question

```json
{
  "text": "When I've had a long day, what helps me unwind?",
  "choices": [
    "Quiet time alone",
    "Talking about my day",
    "Physical activity or movement",
    "Comfort food or a treat",
    "Distraction (TV, games, scrolling)"
  ],
  "category": "self_care"
}
```

**Why it works:**
- Options represent real patterns people have
- Match → "Great, we both need the same thing"
- Mismatch → "Now I understand why you retreat to the bedroom—you need quiet, not me"

### Poor Lighthearted Question

```json
{
  "text": "What's my favorite type of sandwich?",
  "choices": [
    "Turkey",
    "BLT",
    "Grilled cheese",
    "Veggie",
    "Other / Something else"
  ],
  "category": "favorites"
}
```

**Why it fails:**
- Options are arbitrary (why these sandwiches?)
- Match → "Cool, we both like grilled cheese" (so what?)
- Mismatch → "You like turkey, I like BLT" (who cares?)
- No conversation potential, no relationship insight

---

## Technical Reference

### File Locations

| Location | Purpose |
|----------|---------|
| `api/data/puzzles/classic-quiz/{branch}/quiz_001.json` | Server-side quiz content |
| `app/assets/brands/togetherremind/data/classic-quiz/{branch}/` | App-side assets & manifests |
| `lib/services/quiz_service.dart` | Quiz game logic |
| `lib/screens/quiz_match_game_screen.dart` | Quiz UI |

### Quiz File Format

```json
{
  "quizId": "quiz_001",
  "title": "Lighthearted Quiz 1",
  "branch": "lighthearted",
  "questions": [
    {
      "id": "quiz_001_q1",
      "text": "Question text here",
      "choices": ["Option 1", "Option 2", "Option 3", "Option 4", "Other"],
      "category": "category_name"
    }
  ]
}
```

### Related Documentation

- [BRANCH_MANIFEST_GUIDE.md](../BRANCH_MANIFEST_GUIDE.md) - Technical manifest system
- [DAILY_QUESTS.md](../features/DAILY_QUESTS.md) - Quest generation and sync

---

**Last Updated:** 2025-12-17

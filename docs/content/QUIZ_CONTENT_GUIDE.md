# Quiz Content Creation Guide

## Purpose

This guide ensures new quiz questions contribute meaningfully to the Us Profile. Every question is an opportunity to enrich the couple's profile data.

---

## Quick Reference: What Each Tag Does

| Tag | Profile Feature | Example |
|-----|-----------------|---------|
| `dimension` | Dimension spectrum positions | "How You Process Stress" |
| `category` | Discovery grouping & filtering | "Lifestyle", "Values", "Future" |
| `stakes` | Discovery card styling & guidance depth | High-stakes get multi-step approach |
| `valueCategory` | "Where You Align" percentages | "Honesty & Trust: 92%" |
| `traitLabel` | "Through Partner's Eyes" traits | "Adventurous", "Organized" |

---

## The 6 Dimensions

Dimensions show where each partner falls on a spectrum. If your question reveals something about these traits, tag it.

### 1. Stress Processing
**Spectrum:** Internal Processor ↔ External Processor

| Left Pole (Internal) | Right Pole (External) |
|---------------------|----------------------|
| Needs quiet time to process | Wants to talk it through |
| Thinks before speaking | Thinks out loud |
| Journals, walks alone | Calls a friend, vents |

**Tag:** `"dimension": "stress_processing"`

### 2. Conflict Approach
**Spectrum:** Cool Down First ↔ Address Immediately

| Left Pole (Cool Down) | Right Pole (Address) |
|----------------------|---------------------|
| Needs space after disagreement | Wants to resolve right away |
| "Let's talk later" | "Let's fix this now" |
| Avoids heated moments | Leans into conflict |

**Tag:** `"dimension": "conflict_approach"`

### 3. Social Energy
**Spectrum:** Recharge Alone ↔ Recharge with Others

| Left Pole (Alone) | Right Pole (Others) |
|-------------------|---------------------|
| Introvert tendencies | Extrovert tendencies |
| Small gatherings | Big parties |
| Quiet weekends | Social weekends |

**Tag:** `"dimension": "social_energy"`

### 4. Planning Style
**Spectrum:** Spontaneous ↔ Structured

| Left Pole (Spontaneous) | Right Pole (Structured) |
|------------------------|------------------------|
| Go with the flow | Plan ahead |
| Last-minute decisions | Itineraries and lists |
| Flexible | Organized |

**Tag:** `"dimension": "planning_style"`

### 5. Support Style (Future)
**Spectrum:** Fix It ↔ Listen

| Left Pole (Fix It) | Right Pole (Listen) |
|-------------------|---------------------|
| Offers solutions | Offers empathy |
| Problem-solver | Emotional supporter |
| "Have you tried..." | "That sounds hard..." |

**Tag:** `"dimension": "support_style"`

### 6. Space Needs (Future)
**Spectrum:** Together Time ↔ Independence

| Left Pole (Together) | Right Pole (Independence) |
|---------------------|--------------------------|
| Prefers doing things together | Values alone time |
| Shared hobbies | Separate interests |
| Joined at the hip | Comfortable apart |

**Tag:** `"dimension": "space_needs"`

---

## How to Tag a Dimension Question

```json
{
  "id": "quiz_042_q3",
  "text": "When I'm stressed about work, I usually...",
  "choices": [
    "Need quiet time alone first",
    "Want to talk it through with someone",
    "Go for a walk to clear my head",
    "Distract myself with something fun"
  ],
  "category": "self_care",
  "metadata": {
    "dimension": "stress_processing",
    "poleMapping": ["left", "right", "left", null]
  }
}
```

**poleMapping rules:**
- `"left"` = answer indicates left pole tendency
- `"right"` = answer indicates right pole tendency
- `null` = answer is neutral, doesn't inform this dimension

---

## Categories for Discoveries

When partners answer differently, a "discovery" is created. The `category` determines how it's grouped in the UI.

### Allowed Categories

| Category | Use For | Example Questions |
|----------|---------|-------------------|
| `lifestyle` | Daily habits, routines, preferences | Morning routine, weekend plans |
| `entertainment` | Movies, music, hobbies, leisure | Favorite genres, how to relax |
| `social` | Friendships, gatherings, socializing | Party size, friend time |
| `communication` | How you talk, express, listen | Texting habits, sharing feelings |
| `values` | Core beliefs, priorities, principles | Honesty, family, ambition |
| `future` | Life plans, goals, dreams | Where to live, career, family |
| `emotional` | Feelings, support, vulnerability | How to comfort, expressing love |
| `conflict` | Disagreements, tension, resolution | Fighting style, apologizing |
| `intimacy` | Physical affection, closeness | Touch, romance, connection |
| `family` | Parents, siblings, in-laws, kids | Family traditions, parenting |
| `money` | Finances, spending, saving | Budgeting, splurging, goals |
| `daily_life` | Household, chores, logistics | Cleaning, cooking, errands |

---

## Stakes Levels

Stakes determine how discoveries are displayed and what guidance is provided.

### Light Stakes
**Use for:** Fun, low-pressure topics where differences are easy to navigate.

```json
"metadata": {
  "stakes": "light"
}
```

**Examples:**
- Movie preferences
- Food favorites
- Morning person vs night owl
- Travel style

**Profile behavior:** Simple "Try This" action

### Medium Stakes
**Use for:** Topics that matter but aren't life-altering.

```json
"metadata": {
  "stakes": "medium"
}
```

**Examples:**
- Social preferences
- Household routines
- Communication styles
- How to spend weekends

**Profile behavior:** "Try This" + timing suggestion

### High Stakes
**Use for:** Topics that touch on life direction, deep values, or sensitive areas.

```json
"metadata": {
  "stakes": "high"
}
```

**Examples:**
- Having children
- Where to live long-term
- Financial philosophy
- Career priorities
- Religious/spiritual values
- Relationship with in-laws

**Profile behavior:** "Big Topic" badge, multi-step guidance, optional counselor prompt

---

## Value Categories

These power the "Where You Align" section showing shared values.

### Allowed Value Categories

| valueCategory | Meaning |
|--------------|---------|
| `honesty_trust` | Truthfulness, reliability, keeping promises |
| `quality_time` | Prioritizing time together |
| `family` | Family relationships, traditions |
| `personal_growth` | Self-improvement, learning |
| `adventure` | New experiences, travel, spontaneity |
| `security` | Stability, safety, predictability |
| `independence` | Personal space, autonomy |
| `ambition` | Career, achievement, success |
| `spirituality` | Faith, meaning, purpose |
| `health` | Physical/mental wellness |

### How to Tag

```json
{
  "text": "How important is it to always be honest, even when it's uncomfortable?",
  "choices": ["Essential", "Very important", "Somewhat important", "Depends"],
  "metadata": {
    "valueCategory": "honesty_trust",
    "valueMapping": [1.0, 0.8, 0.5, 0.3]
  }
}
```

---

## Trait Labels (You-or-Me Questions)

These power the "Through Partner's Eyes" section.

```json
{
  "prompt": "Who is more likely to...",
  "content": "Plan a surprise date night",
  "metadata": {
    "traitLabel": "Romantic planner"
  }
}
```

**Good trait labels:**
- Short (1-3 words)
- Positive or neutral framing
- Descriptive, not judgmental

| Good | Bad |
|------|-----|
| "Adventurous eater" | "Picky" |
| "Early riser" | "Lazy sleeper" |
| "Emotionally open" | "Cries a lot" |
| "Detail-oriented" | "Obsessive" |

---

## Complete Example: Well-Tagged Question

```json
{
  "id": "quiz_050_q7",
  "text": "When we disagree about something important, I prefer to...",
  "choices": [
    "Take some time to cool down before discussing",
    "Talk it through right away while it's fresh",
    "Write down my thoughts first, then talk",
    "Sleep on it and revisit tomorrow"
  ],
  "category": "conflict",
  "metadata": {
    "dimension": "conflict_approach",
    "poleMapping": ["left", "right", "left", "left"],
    "stakes": "medium",
    "valueCategory": "honesty_trust"
  }
}
```

**What this enables:**
- ✅ Contributes to "Conflict Approach" dimension
- ✅ Appears in "Conflict" discovery filter
- ✅ Shows timing suggestion (medium stakes)
- ✅ Contributes to "Honesty & Trust" value alignment

---

## Minimum Viable Question

If you're creating questions quickly, at minimum include:

```json
{
  "id": "unique_id",
  "text": "Question text",
  "choices": ["A", "B", "C", "D"],
  "category": "lifestyle"
}
```

This will:
- ✅ Generate discoveries when partners differ
- ✅ Appear in category filters
- ❌ Won't contribute to dimensions
- ❌ Won't inform values
- ❌ Will default to "light" stakes

---

## Checklist Before Adding Questions

- [ ] Does this question have a `category`?
- [ ] If it reveals a personality spectrum, did I add `dimension` + `poleMapping`?
- [ ] If it's about sensitive topics, did I set `stakes: "high"`?
- [ ] If it reveals core values, did I add `valueCategory`?
- [ ] For You-or-Me: does it have a positive `traitLabel`?

---

## Questions That Don't Need Much Tagging

Some questions are just for fun and discovery. That's fine! Not every question needs to power a profile metric.

**Simple discovery questions:**
- "What's your ideal vacation?"
- "Breakfast food preference?"
- "Favorite season?"

Just give them a `category` and let them generate discoveries naturally.

---

*Guide created: January 2026*
*Related: `docs/plans/CONTENT_SCALING_STRATEGY.md`*

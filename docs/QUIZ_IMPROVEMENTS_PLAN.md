# Quiz Improvements Plan

**Date:** 2025-12-02
**Status:** Planning
**Related:** `docs/QUIZ_CONTENT_ANALYSIS.md`

---

## Executive Summary

This document outlines the implementation plan for improving the quiz experience across all three quiz types (Classic, Affirmation, You-or-Me) with focus on:

1. **Results screen reframing** — Shift from judgment to discovery
2. **Therapeutic vs casual differentiation** — Visual and tonal distinction
3. **New therapeutic content** — Connection, Attachment, and Growth branches

---

## Part 1: Results Screen Improvements

### 1.1 Core Principle

**Before:** Score as judgment ("You got 7/10 correct")
**After:** Score as discovery ("You discovered 3 new things about each other")

### 1.2 Framing by Quiz Type

| Quiz Type | Tone | Low Score Framing | Competition OK? |
|-----------|------|-------------------|-----------------|
| Classic Casual | Playful | "Surprises!" | Yes |
| Classic Therapeutic | Warm | "Discoveries" | No |
| Affirmation Casual | Reflective | "Different perspectives" | No |
| Affirmation Therapeutic | Gentle | "Different experiences" | No |
| You-or-Me Casual | Fun | "Debate material!" | Yes |
| You-or-Me Therapeutic | Curious | "Different perceptions" | No |

### 1.3 Message Copy by Score Range

#### Classic Quiz — Casual (Lighthearted, Deeper, Spicy)

| Score | Message |
|-------|---------|
| 9-10 | "You two are scary good" |
| 7-8 | "Solid! You've been paying attention" |
| 5-6 | "A few surprises in there!" |
| 3-4 | "Looks like you learned something new today" |
| 0-2 | "Plot twist! Time to compare notes" |

#### Classic Quiz — Therapeutic (Connection)

| Score | Message |
|-------|---------|
| 9-10 | "You really see each other" |
| 7-8 | "You know each other well — and learned even more today" |
| 5-6 | "Some beautiful discoveries here" |
| 3-4 | "You uncovered some new layers today" |
| 0-2 | "Lots to explore together — that's a gift" |

#### Affirmation Quiz — Casual (Emotional, Practical, Spiritual)

| Alignment | Message |
|-----------|---------|
| 5/5 | "Completely in sync on this one" |
| 4/5 | "Mostly aligned — with room to talk" |
| 3/5 | "Some different perspectives here" |
| 1-2/5 | "You see things differently — worth exploring" |

#### Affirmation Quiz — Therapeutic (Attachment)

| Alignment | Message |
|-----------|---------|
| 5/5 | "You feel similarly about your connection" |
| 4/5 | "Mostly aligned — and aware of each other" |
| 3/5 | "Some different experiences here" |
| 1-2/5 | "You're experiencing things differently right now" |

#### You-or-Me — Casual (Playful, Reflective)

| Agreement | Message |
|-----------|---------|
| 9-10/10 | "You two are totally in sync!" |
| 7-8/10 | "Mostly agreed — a few debates ahead" |
| 5-6/10 | "Split down the middle! This could get interesting" |
| 3-4/10 | "You see yourselves very differently!" |
| 0-2/10 | "Opposite views! Time to make your case" |

#### You-or-Me — Therapeutic (Growth)

| Agreement | Message |
|-----------|---------|
| 9-10/10 | "You see your patterns clearly together" |
| 7-8/10 | "Mostly aligned on how you work as a couple" |
| 5-6/10 | "Some different views on your dynamics" |
| 3-4/10 | "You perceive your patterns differently" |
| 0-2/10 | "Very different perspectives — lots to explore" |

### 1.4 Universal Rules

1. **Never use "wrong" or "incorrect"** — use "different," "surprise," "discovery"
2. **Low scores get more supportive framing** — more words to prevent negative interpretation
3. **Always offer a conversation prompt** — especially on mismatches
4. **LP awarded regardless of score** — effort, not accuracy, is rewarded
5. **Therapeutic quizzes use softer language** — "experiences," "perspectives," "invitations"

---

## Part 2: UI Differentiation (Therapeutic vs Casual)

### 2.1 Quest Card Differentiation

Therapeutic quests need visual distinction on the home screen carousel.

| Element | Casual Quest | Therapeutic Quest |
|---------|--------------|-------------------|
| Badge | None or activity name | "Deeper" badge |
| Border | Standard 1px | Subtle accent (2px or colored) |
| Icon style | Playful emoji | Softer/warmer emoji |
| Subtitle | Activity description | "Connect on a deeper level" |

### 2.2 Intro Screen (First-Time Therapeutic)

When user plays their first therapeutic quest of each type, show a brief framing screen:

**Purpose:**
- Set expectations for deeper content
- Remove pressure of "right answers"
- Frame as connection opportunity

**Content varies by quiz type:**

| Quiz Type | Intro Message |
|-----------|---------------|
| Connection (Classic) | "These questions go deeper — they're designed to help you truly know each other. There are no wrong answers." |
| Attachment (Affirmation) | "This quiz explores how you each experience your connection. Your feelings are valid, even when they differ." |
| Growth (You-or-Me) | "These questions explore your patterns as a couple. It's about understanding, not judging." |

### 2.3 Results Screen Structure

#### Casual Quizzes — Primary Screen

```
┌─────────────────────────────────────┐
│                                     │
│         [Score: 7/10]               │
│                                     │
│   "[Playful message]"               │
│                                     │
│         + 30 LP                     │
│                                     │
│   [See the Surprises]               │
│                                     │
└─────────────────────────────────────┘
```

#### Therapeutic Quizzes — Primary Screen

```
┌─────────────────────────────────────┐
│                                     │
│         [Score: 6/10]               │
│                                     │
│   "[Warm message]"                  │
│                                     │
│   [Supportive subtext about         │
│    the value of discovery]          │
│                                     │
│         + 30 LP                     │
│                                     │
│   [Explore What You Learned]        │
│                                     │
└─────────────────────────────────────┘
```

#### Details Screen — Mismatch Display

**Casual:** Simple display with playful commentary
```
Sarah thought: "Pizza"
Mike actually: "Sushi"
```

**Therapeutic:** Includes conversation prompt
```
You guessed: Space alone
Sarah said: Someone to listen

💬 "What helps most when you're stressed?"
```

---

## Part 3: New Therapeutic Content

### 3.1 Content Summary

| Activity | Branch | Questions | Status |
|----------|--------|-----------|--------|
| Classic Quiz | Connection | 50 | JSON complete in analysis doc |
| Affirmation | Attachment | 30 (6 quizzes) | Table format in analysis doc |
| You-or-Me | Growth | 30 | Table format in analysis doc |

**Total new therapeutic content:** 110 items

### 3.2 Content Creation Tasks

- [ ] Create `classic-quiz/connection/questions.json` from analysis doc
- [ ] Create `affirmation/attachment/quizzes.json` with full JSON structure
- [ ] Create `you-or-me/growth/questions.json` with full JSON structure
- [ ] Create manifest.json files for each new branch

### 3.3 Branch Rotation Integration

Therapeutic branches integrate into existing rotation:

| Position | Classic Quiz | Affirmation | You-or-Me |
|----------|--------------|-------------|-----------|
| 0 | Lighthearted | Emotional | Playful |
| 1 | Deeper | Practical | Reflective |
| 2 | Spicy | Spiritual | Intimate |
| 3 | **Connection** | **Attachment** | **Growth** |

Formula: `currentBranch = totalCompletions % 4`

---

## Part 4: Implementation Tasks

### Phase 1: Design & Mockups

- [ ] **Quest card mockups** — Casual vs therapeutic visual differentiation
- [ ] **Intro screen mockups** — First-time therapeutic quest framing
- [ ] **Results screen mockups** — All 6 quiz type variants
  - [ ] Classic Casual results
  - [ ] Classic Therapeutic results
  - [ ] Affirmation Casual results
  - [ ] Affirmation Therapeutic results
  - [ ] You-or-Me Casual results
  - [ ] You-or-Me Therapeutic results
- [ ] **Details/mismatch screen mockups** — Casual vs therapeutic framing

### Phase 2: Content Creation

- [ ] Finalize Connection branch JSON (50 questions) — mostly done
- [ ] Create Attachment branch JSON (30 statements, 6 quizzes)
- [ ] Create Growth branch JSON (30 questions)
- [ ] Write all score-range messages for each quiz type
- [ ] Write conversation prompts for therapeutic mismatches

### Phase 3: Backend Updates

- [ ] Add `isTherapeutic` flag to branch configuration
- [ ] Update results calculation to use new message copy
- [ ] Add conversation prompt field to mismatch responses
- [ ] Update branch rotation to include new branches (if not 4-branch already)

### Phase 4: Frontend Updates

- [ ] Update quest card component with therapeutic badge/styling
- [ ] Create intro screen component for first therapeutic quest
- [ ] Update results screen with new message logic
- [ ] Update details screen with conversation prompts
- [ ] Track "has seen intro" per therapeutic branch type

### Phase 5: Testing

- [ ] Test all score ranges show correct messages
- [ ] Test therapeutic intro only shows once per branch type
- [ ] Test branch rotation includes therapeutic branches
- [ ] Test conversation prompts display correctly
- [ ] User testing for emotional response to new framing

---

## Part 5: Mockup Specifications

### 5.1 Quest Card Mockups Needed

| Mockup | Description |
|--------|-------------|
| `quest-card-casual.html` | Standard quest card (current design) |
| `quest-card-therapeutic.html` | Quest card with "Deeper" badge and subtle differentiation |
| `quest-card-comparison.html` | Side-by-side comparison of both styles |

### 5.2 Intro Screen Mockups Needed

| Mockup | Description |
|--------|-------------|
| `intro-connection.html` | First-time Connection quiz intro |
| `intro-attachment.html` | First-time Attachment quiz intro |
| `intro-growth.html` | First-time Growth quiz intro |

### 5.3 Results Screen Mockups Needed

| Mockup | Description |
|--------|-------------|
| `results-classic-casual.html` | Classic quiz casual results (high/mid/low scores) |
| `results-classic-therapeutic.html` | Classic quiz therapeutic results |
| `results-affirmation-casual.html` | Affirmation casual results |
| `results-affirmation-therapeutic.html` | Affirmation therapeutic results |
| `results-youorme-casual.html` | You-or-Me casual results |
| `results-youorme-therapeutic.html` | You-or-Me therapeutic results |

### 5.4 Details Screen Mockups Needed

| Mockup | Description |
|--------|-------------|
| `details-casual.html` | Mismatch display for casual quizzes |
| `details-therapeutic.html` | Mismatch display with conversation prompts |

---

## Success Metrics

After implementation, monitor:

1. **Completion rates** — Do therapeutic quizzes have similar completion to casual?
2. **Return engagement** — Do users return after low-score therapeutic quizzes?
3. **Qualitative feedback** — Do users feel judged or curious after mismatches?
4. **Conversation prompt engagement** — Do users tap "Explore" on therapeutic results?

---

## Open Questions

1. **Badge wording** — "Deeper" confirmed, but should it vary by quiz type?
2. **Intro screen frequency** — Show once ever, or once per month?
3. **Conversation prompts** — Pre-written per question, or generic per quiz type?
4. **Score visibility** — Show numerical score on therapeutic, or just message?

---

## Appendix: File Locations

**Content files:**
```
app/assets/brands/togetherremind/data/
├── classic-quiz/
│   └── connection/questions.json  ← NEW
├── affirmation/
│   └── attachment/quizzes.json    ← NEW
└── you-or-me/
    └── growth/questions.json      ← NEW
```

**Mockup files:**
```
mockups/quiz-improvements/
├── quest-cards/
├── intro-screens/
├── results-screens/
└── details-screens/
```

---

## Changelog

| Date | Change |
|------|--------|
| 2025-12-02 | Initial plan created |

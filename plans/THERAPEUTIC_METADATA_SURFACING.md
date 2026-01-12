# Therapeutic Metadata Surfacing

## Overview

This document captures ideas for surfacing the therapeutic metadata from quizzes throughout the Us 2.0 app. Mockups have been created in `/mockups/Therapeutical-Views/`.

## Available Metadata from Quizzes

| Field | Description |
|-------|-------------|
| `rationale` | Why this question matters psychologically |
| `framework` | Psychological basis (gottman, attachment_theory, love_languages, etc.) |
| `whenDifferent` | Guidance when partners answer differently |
| `whenSame` | Insight when partners match |
| `journalPrompt` | Reflection question for deeper exploration |
| `dimension` | Personality dimension being measured |
| `poleMapping` | How each answer maps to dimension poles |

## Proposed Features

### 1. Quiz Results with Insights
**Mockup:** `quiz-results-insights.html`

Post-quiz screen showing aligned vs. different answers with therapeutic context for each question.

**Metadata Used:** `whenDifferent`, `whenSame`, `framework`

**Implementation Notes:**
- Show match indicator (aligned/different) for each question
- Display both partners' answers side-by-side
- Include insight section with therapeutic explanation
- Add "Save to Journal" action for reflection prompts

---

### 2. Journal Prompts Feed
**Mockup:** `journal-prompts-feed.html`

Journal section populated with personalized prompts generated from quiz questions where partners differed.

**Metadata Used:** `journalPrompt`, `rationale`

**Implementation Notes:**
- Prioritize prompts from questions where partners differed
- Show source quiz for each prompt
- Include context explaining why this prompt was generated
- Tabs: New, Saved, Completed, Discuss

---

### 3. Discussion Cards
**Mockup:** `discussion-cards.html`

"Worth Discussing" swipeable cards surfaced when partners differ on key questions.

**Metadata Used:** `whenDifferent`, `rationale`

**Implementation Notes:**
- Card stack UI (swipeable)
- Show both partners' answers
- Include "Why this matters" insight box
- Provide conversation starters
- "Mark Discussed" to track progress

---

### 4. Question Deep Dive
**Mockup:** `question-deep-dive.html`

Expandable insight panel after answering each question during quiz gameplay.

**Metadata Used:** `rationale`, `framework`

**Implementation Notes:**
- Collapsed hint: "Tap to learn why this question matters"
- Expanded panel shows:
  - Framework badge (e.g., "Based on Attachment Theory")
  - Psychology explanation
  - What each answer choice suggests
  - Reflection prompt
- "Save to Journal" action

---

### 5. Us Profile: Dimensions
**Mockup:** `us-profile-dimensions.html`

Visual compatibility profile built from dimension/poleMapping data across all quizzes.

**Metadata Used:** `dimension`, `poleMapping`

**Implementation Notes:**
- Aggregate scores across multiple quizzes
- Spectrum visualization for each dimension
- Status badges: Aligned, Different, Complementary
- Compatibility summary card
- "Learn more" links for each dimension

---

### 6. Weekly Insights Report
**Mockup:** `weekly-insights-report.html`

Aggregated patterns and personalized insights delivered weekly.

**Metadata Used:** All metadata fields

**Implementation Notes:**
- Stats: Quizzes completed, matched answers, topics to discuss
- Key pattern highlight (e.g., pursuer-distancer dynamic)
- Pattern cards with colored indicators (positive/growth/attention)
- Framework insights aggregated from multiple quizzes
- Reflection prompts for the week
- Could be delivered via push notification

---

## Additional Ideas (Not Yet Mocked)

### Framework Learning Cards
Unlock mini-lessons about Gottman, Attachment Theory, etc. as users complete more quizzes.
> "You've explored 5 questions about attachment. Here's what attachment theory says about your pattern..."

### Couple's Therapy Topics
For couples in therapy: export a summary of key differences with `whenDifferent` insights to discuss with their therapist.

### Growth Tracking Over Time
If users re-take quizzes, show how their answers (and alignment) has changed.
> "6 months ago you said X, now you say Y."

### Date Night Conversation Deck
Turn journal prompts into a "conversation card" feature for date nights. Swipe through prompts, discuss together.

---

## Implementation Priority (Suggested)

1. **Quiz Results with Insights** - Low effort, high value, natural extension of existing results screen
2. **Question Deep Dive** - Adds depth during gameplay without changing flow
3. **Journal Prompts Feed** - Leverages existing journal feature
4. **Discussion Cards** - New feature but high engagement potential
5. **Weekly Insights Report** - Requires aggregation logic, good retention driver
6. **Us Profile: Dimensions** - Most complex, needs significant backend work

---

## Status

- [x] Mockups created (Jan 2025)
- [ ] User research / feedback on mockups
- [ ] Technical design
- [ ] Implementation

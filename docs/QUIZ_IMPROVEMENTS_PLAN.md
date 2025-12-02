# Quiz Improvements Plan

**Date:** 2025-12-02
**Status:** Planning
**Related:** `docs/QUIZ_CONTENT_ANALYSIS.md`

---

## Executive Summary

This document outlines the implementation plan for improving the quiz experience across all three quiz types (Classic, Affirmation, You-or-Me) with focus on:

1. **Results screen redesign** — Replace current simple results with full details inline (Option C)
2. **Therapeutic vs casual differentiation** — "Deeper" badge on quest cards and intro screens
3. **New therapeutic content** — Connection, Attachment, and Growth branches

---

## Part 1: UI Changes Overview

### 1.1 Summary of Changes

| Screen | Change | Scope |
|--------|--------|-------|
| **Quest Card** | Add "Deeper" badge overlay on image for therapeutic branches | Minor |
| **Intro Screen** | Add "Deeper" badge below video (next to activity badge) | Minor |
| **Results Screen** | Full redesign — score + question details inline (replaces current) | Major |

### 1.2 What Stays the Same

- Quest card layout, styling, and structure (only add badge overlay)
- Intro screen video, stats card, "How It Works" steps, footer
- Navigation flow between screens

---

## Part 2: Quest Card Changes

### 2.1 Current State

The quest card (`lib/widgets/quest_card.dart`) displays:
- Quest image (170px max height)
- Title + description
- LP reward badge
- Status badge (Your Turn, Completed, etc.)

### 2.2 Change Required

**Add a "Deeper" badge overlay** on the quest image for therapeutic branches only.

**Mockup Reference:** `mockups/quiz_improvements/quest-cards/quest-card-comparison.html`

#### Visual Specification

```
┌─────────────────────────────────────┐
│ ┌────────┐                          │
│ │ Deeper │  ← Black badge, top-left │
│ └────────┘                          │
│                                     │
│         [Quest Image]               │
│            💫                       │
│                                     │
├─────────────────────────────────────┤
│  Connection Quiz                    │
│  Discover each other's inner world  │
│                             +30 LP  │
├─────────────────────────────────────┤
│  [Your Turn]                        │
└─────────────────────────────────────┘
```

#### Badge Styling

```dart
// Position: Absolute, top-left of image area
// Offset: 12px from top, 12px from left
Container(
  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  color: Colors.black,  // EditorialStyles.ink
  child: Text(
    'DEEPER',
    style: TextStyle(
      color: Colors.white,
      fontSize: 9,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
    ),
  ),
)
```

#### Implementation

**File to modify:** `app/lib/widgets/quest_card.dart`

**Logic:**
1. Determine if current branch is therapeutic (Connection, Attachment, or Growth)
2. If therapeutic, render "Deeper" badge positioned over the quest image
3. No other changes to quest card

**Therapeutic branch detection:**
```dart
bool isTherapeuticBranch(String? branch) {
  const therapeuticBranches = ['connection', 'attachment', 'growth'];
  return branch != null && therapeuticBranches.contains(branch.toLowerCase());
}
```

---

## Part 3: Intro Screen Changes

### 3.1 Current State

The intro screens (`quiz_intro_screen.dart`, `affirmation_intro_screen.dart`, `you_or_me_match_intro_screen.dart`) display:
- Header with "DAILY QUEST" label
- Hero video that fades to grayscale emoji
- Activity badge (e.g., "Classic Quiz")
- Title from manifest
- Description
- Stats card
- "How It Works" steps
- Footer with Begin button

### 3.2 Change Required

**Add "Deeper" badge** next to the activity badge for therapeutic branches.

**Mockup Reference:** `mockups/quiz_improvements/intro-screens/intro-therapeutic-additions.html`

#### Visual Specification

```
┌─────────────────────────────────────┐
│  ← DAILY QUEST                      │
├─────────────────────────────────────┤
│                                     │
│         [Video / 💫]                │
│                                     │
├─────────────────────────────────────┤
│                                     │
│  ┌──────────────┐ ┌────────┐        │
│  │ Classic Quiz │ │ Deeper │        │
│  └──────────────┘ └────────┘        │
│                                     │
│  Connection Quiz                    │
│                                     │
│  Answer questions about yourself... │
│  These questions go a little deeper │
│  — discover what you truly know     │
│  about each other's inner world.    │
│                                     │
```

#### Badge Row Implementation

```dart
// Badges row - add "Deeper" badge for therapeutic branches
Row(
  children: [
    EditorialBadge(
      label: 'Classic Quiz',  // or 'Affirmation', 'You or Me'
      isInverted: true,
    ),
    if (isTherapeuticBranch(widget.branch)) ...[
      SizedBox(width: 8),
      EditorialBadge(
        label: 'Deeper',
        isInverted: true,
      ),
    ],
  ],
)
```

### 3.3 Description Copy Updates

For therapeutic branches, update the description text:

**Classic Quiz (Connection):**
> "Answer questions about yourself, then [Partner] will try to predict your answers. These questions go a little deeper — discover what you truly know about each other's inner world."

**Affirmation (Attachment):**
> "Rate how much you agree with each statement about your relationship. This quiz explores how you each experience your connection — your sense of safety, trust, and closeness."

**You-or-Me (Growth):**
> "For each question, choose who it applies to more. These questions explore your patterns as a couple — how you support each other, handle challenges, and grow together."

### 3.4 Optional: First-Time Therapeutic Note

For the first time a user encounters a therapeutic branch, optionally show a brief note:

```dart
// Show only if user hasn't seen this therapeutic intro before
if (isTherapeuticBranch && !hasSeenTherapeuticIntro) {
  Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Color(0xFFF8F6F2),  // Warm cream
      border: Border(left: BorderSide(color: Colors.black, width: 3)),
    ),
    child: Text(
      'There are no wrong answers here. Just be curious about your partner.',
      style: TextStyle(fontStyle: FontStyle.italic),
    ),
  )
}
```

**Storage key:** `has_seen_therapeutic_intro_[branch_type]` (e.g., `has_seen_therapeutic_intro_connection`)

---

## Part 4: Results Screen Redesign (Option C)

### 4.1 Current State

The current results screen (`quiz_match_results_screen.dart`) shows:
- "Quiz Complete!" title
- Match percentage (e.g., "70%")
- Generic description based on percentage
- LP earned
- "Return Home" button

**It does NOT show:**
- Individual question breakdowns
- What user guessed vs what partner answered
- Conversation prompts

### 4.2 New Design: Full Details Inline

Replace the current results screen with a new design that includes:
1. Score summary at top
2. Score-appropriate message (varies by casual/therapeutic)
3. LP reward
4. Scrollable list of all questions with answers
5. Conversation prompts for mismatches (therapeutic only)
6. "Done" button at bottom

**Mockup References:**
- `mockups/quiz_improvements/results-screens/results-classic-casual.html`
- `mockups/quiz_improvements/results-screens/results-classic-therapeutic.html`
- `mockups/quiz_improvements/results-screens/results-affirmation-casual.html`
- `mockups/quiz_improvements/results-screens/results-affirmation-therapeutic.html`
- `mockups/quiz_improvements/results-screens/results-youorme-casual.html`
- `mockups/quiz_improvements/results-screens/results-youorme-therapeutic.html`
- `mockups/quiz_improvements/details-screens/details-casual.html`
- `mockups/quiz_improvements/details-screens/details-therapeutic.html`

### 4.3 Results Screen Structure

```
┌─────────────────────────────────────┐
│  ← [Quiz Title]               [X]   │  ← Header
├─────────────────────────────────────┤
│                                     │
│  [Deeper]  ← Only for therapeutic   │
│                                     │
│            💫                       │
│                                     │
│         7 / 10                      │  ← Score
│                                     │
│  "A few surprises in there!"        │  ← Message (varies by score)
│                                     │
│  You discovered 3 things you        │  ← Subtext
│  didn't know about each other.      │
│                                     │
│       ┌─────────────────┐           │
│       │    + 30 LP      │           │  ← LP Reward
│       └─────────────────┘           │
│                                     │
├─────────────────────────────────────┤
│  WHAT YOU LEARNED                   │  ← Section header
├─────────────────────────────────────┤
│                                     │
│  "What's my favorite pizza?"        │  ← Question
│  You guessed: Pepperoni             │
│  Actually: Mushrooms                │
│  🍕 Noted for next pizza night!     │  ← Playful comment (casual)
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  "What do I need when stressed?"    │  ← Question
│  You guessed: Space alone           │
│  Sarah said: Someone to listen      │
│                                     │
│  ┌─────────────────────────────────┐│
│  │ 💛 "When you're stressed, what  ││  ← Conversation prompt
│  │    helps most?"                 ││     (therapeutic only)
│  │                                 ││
│  │ This isn't about being "right"  ││
│  │ — it's an invitation to         ││
│  │ understand.                     ││
│  └─────────────────────────────────┘│
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  "What's my go-to comfort show?"    │
│  You guessed: The Office            │
│  Actually: The Office               │
│  ✓ You knew this!                   │  ← Match indicator
│                                     │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────────┐│
│  │            Done                 ││  ← Button
│  └─────────────────────────────────┘│
│                                     │
└─────────────────────────────────────┘
```

### 4.4 Message Copy by Score Range

#### Classic Quiz — Casual (Lighthearted, Deeper, Spicy)

| Score | Message | Subtext |
|-------|---------|---------|
| 9-10 | "You two are scary good" | "Only [X] surprise in there!" |
| 7-8 | "Solid! You've been paying attention" | "You discovered [X] things you didn't know." |
| 5-6 | "A few surprises in there!" | "You discovered [X] things you didn't know about each other." |
| 3-4 | "Looks like you learned something new today" | "Lots of new things to remember!" |
| 0-2 | "Plot twist! Time to compare notes" | "Looks like there's lots to learn — that's half the fun!" |

#### Classic Quiz — Therapeutic (Connection)

| Score | Message | Subtext |
|-------|---------|---------|
| 9-10 | "You really see each other" | "You've built something beautiful — a deep understanding of each other's inner world." |
| 7-8 | "You know each other well — and learned even more today" | "Knowing someone deeply is a lifelong journey." |
| 5-6 | "Some beautiful discoveries here" | "Knowing someone deeply is a lifelong journey. Today you got a little closer." |
| 3-4 | "You uncovered some new layers today" | "These questions revealed new things to explore together." |
| 0-2 | "Lots to explore together — that's a gift" | "These questions revealed new layers to discover. That's what growing closer looks like." |

#### Affirmation Quiz — Casual (Emotional, Practical, Spiritual)

| Alignment | Message | Subtext |
|-----------|---------|---------|
| 5/5 | "Completely in sync on this one" | "You see your relationship the same way — that's a strong foundation." |
| 4/5 | "Mostly aligned — with room to talk" | "You shared how you see your relationship." |
| 3/5 | "Some different perspectives here" | "You shared how you see your relationship. The differences are worth exploring." |
| 1-2/5 | "You see things differently — worth exploring" | "Differences aren't problems — they're starting points for conversation." |

#### Affirmation Quiz — Therapeutic (Attachment)

| Alignment | Message | Subtext |
|-----------|---------|---------|
| 5/5 | "You feel similarly about your connection" | "You're experiencing your bond in the same way — that's a beautiful sign of attunement." |
| 4/5 | "Mostly aligned — and aware of each other" | "This quiz reflects how you each feel." |
| 3/5 | "Some different experiences here" | "This quiz reflects how you each *feel* — and feelings are always valid, even when they differ." |
| 1-2/5 | "You're experiencing things differently right now" | "Neither of you is wrong. These differences are invitations to understand each other better." |

#### You-or-Me — Casual (Playful, Reflective)

| Agreement | Message | Subtext |
|-----------|---------|---------|
| 9-10/10 | "You two are totally in sync!" | "You see your dynamic the same way — impressive teamwork." |
| 7-8/10 | "Mostly agreed — a few debates ahead" | "You've got some debates ahead!" |
| 5-6/10 | "Split down the middle! This could get interesting" | "You've got some debates ahead — may the best argument win!" |
| 3-4/10 | "You see yourselves very differently!" | "Time to compare notes!" |
| 0-2/10 | "Opposite views! Time to make your case" | "You see things completely differently — this is going to be a fun conversation!" |

#### You-or-Me — Therapeutic (Growth)

| Agreement | Message | Subtext |
|-----------|---------|---------|
| 9-10/10 | "You see your patterns clearly together" | "You're attuned to how you work as a couple — that awareness is a strength." |
| 7-8/10 | "Mostly aligned on how you work as a couple" | "You see your dynamic similarly." |
| 5-6/10 | "Some different views on your dynamics" | "How we see ourselves vs. how our partner sees us often differs — and that's OK." |
| 3-4/10 | "You perceive your patterns differently" | "These are opportunities to learn how your partner experiences your relationship." |
| 0-2/10 | "Very different perspectives — lots to explore" | "You perceive your patterns differently. These are opportunities to understand each other better." |

### 4.5 Question Item Display

#### For Matches (Correct Answers)

```dart
Column(
  children: [
    Text(question.text),  // "What's my favorite pizza?"
    Row(children: [
      Text('You guessed: ', style: labelStyle),
      Text(userAnswer, style: correctStyle),  // Green
    ]),
    Row(children: [
      Text('Actually: ', style: labelStyle),
      Text(partnerAnswer, style: correctStyle),  // Green
    ]),
    MatchIndicator(text: '✓ You knew this!'),  // Green background
  ],
)
```

#### For Mismatches — Casual

```dart
Column(
  children: [
    Text(question.text),
    Row(children: [
      Text('You guessed: ', style: labelStyle),
      Text(userAnswer, style: incorrectStyle),  // Red
    ]),
    Row(children: [
      Text('Actually: ', style: labelStyle),
      Text(partnerAnswer, style: correctStyle),  // Green
    ]),
    PlayfulComment(text: 'Noted for next pizza night! 🍕'),  // Italic, gray
  ],
)
```

#### For Mismatches — Therapeutic

```dart
Column(
  children: [
    Text(question.text),
    Row(children: [
      Text('You guessed: ', style: labelStyle),
      Text(userAnswer),
    ]),
    Row(children: [
      Text('${partnerName} said: ', style: labelStyle),
      Text(partnerAnswer),
    ]),
    MismatchIndicator(text: 'Different perspectives'),  // Warm orange background
    ConversationPrompt(
      icon: '💛',
      prompt: '"When you're stressed, what helps most?"',
      note: 'This isn't about being "right" — it's an invitation to understand.',
    ),
  ],
)
```

### 4.6 Conversation Prompts

For therapeutic quizzes, mismatches include a conversation prompt box:

**Styling:**
```dart
Container(
  margin: EdgeInsets.only(top: 16),
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Color(0xFFFAF8F5),  // Warm cream
    border: Border(left: BorderSide(color: Colors.black, width: 3)),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('💛', style: TextStyle(fontSize: 16)),
      SizedBox(height: 8),
      Text(
        promptText,  // e.g., '"When you're stressed, what helps most?"'
        style: TextStyle(fontStyle: FontStyle.italic, fontSize: 14),
      ),
      SizedBox(height: 8),
      Text(
        'This isn't about being "right" — it's an invitation to understand.',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
    ],
  ),
)
```

**Prompt sources:**
- **Option A:** Generic prompts per quiz type (simpler)
- **Option B:** Per-question prompts stored in JSON (more work, better UX)

Recommendation: Start with Option A (generic prompts), iterate to Option B later.

**Generic prompts by quiz type:**

| Quiz Type | Generic Prompt |
|-----------|----------------|
| Connection | "What would help you understand this about each other better?" |
| Attachment | "What would help you feel more [topic] in your relationship?" |
| Growth | "How does each of you experience this pattern?" |

### 4.7 Affirmation-Specific Display

For Affirmation quizzes, show alignment bars instead of text answers:

```dart
Column(
  children: [
    Text(statement.text),  // "I can reach my partner when I need them"
    SizedBox(height: 12),
    // User's rating
    Row(
      children: [
        Text('You:', style: labelStyle),
        SizedBox(width: 8),
        RatingBar(value: userRating, maxValue: 5),  // Visual bar
        Text('${userRating}/5'),
      ],
    ),
    // Partner's rating
    Row(
      children: [
        Text('${partnerName}:', style: labelStyle),
        SizedBox(width: 8),
        RatingBar(value: partnerRating, maxValue: 5),
        Text('${partnerRating}/5'),
      ],
    ),
    // Alignment indicator
    if ((userRating - partnerRating).abs() <= 1)
      MatchIndicator(text: '✓ You see this similarly')
    else
      MismatchIndicator(text: 'Different experiences'),
  ],
)
```

### 4.8 You-or-Me-Specific Display

For You-or-Me quizzes, show who each person picked:

```dart
Column(
  children: [
    Text(question.text),  // "Who's the better cook?"
    SizedBox(height: 12),
    Row(
      children: [
        Text('${userName} said: ', style: labelStyle),
        Text(userPick == 'self' ? 'Me 👈' : '${partnerName} 👉'),
      ],
    ),
    Row(
      children: [
        Text('${partnerName} said: ', style: labelStyle),
        Text(partnerPick == 'self' ? 'Me 👈' : '${userName} 👉'),
      ],
    ),
    // Show result
    if (userPick == partnerPick)
      MatchIndicator(text: '✓ You agree!')
    else if (userPick == 'self' && partnerPick == 'self')
      MismatchIndicator(text: 'Both said themselves!')
    else
      MismatchIndicator(text: 'Opposite views!'),
  ],
)
```

### 4.9 Files to Modify

| File | Changes |
|------|---------|
| `lib/screens/quiz_match_results_screen.dart` | Full redesign — add question details inline |
| `lib/screens/you_or_me_match_results_screen.dart` | Full redesign — add question details inline |
| `lib/models/quiz_match.dart` | May need to ensure question/answer data is available |
| `lib/services/quiz_match_service.dart` | May need to return full question details in results |

### 4.10 Data Requirements

The results screen needs access to:

```dart
class QuizResultsData {
  final int score;           // e.g., 7
  final int totalQuestions;  // e.g., 10
  final int lpEarned;        // e.g., 30
  final String branch;       // e.g., 'connection'
  final bool isTherapeutic;  // e.g., true
  final List<QuestionResult> questions;
}

class QuestionResult {
  final String questionText;
  final String userAnswer;
  final String partnerAnswer;
  final bool isMatch;
  final String? conversationPrompt;  // For therapeutic mismatches
}
```

**API consideration:** The server may need to return full question details in the completion response, not just the match percentage.

---

## Part 5: Implementation Phases

### Phase 1: Fix Existing Content Bugs

Before adding new content, fix the issues identified in `docs/QUIZ_CONTENT_ANALYSIS.md`:

**Files:**
- `app/assets/brands/togetherremind/data/classic-quiz/lighthearted/questions.json`
- `app/assets/brands/togetherremind/data/classic-quiz/deeper/questions.json`
- `app/assets/brands/togetherremind/data/you-or-me/*/questions.json`

**Issues to fix:**

#### 1a. Classic Quiz ID Gap (Lighthearted)

The lighthearted branch has a gap in question IDs: q1-q15, then jumps to q51-q180.

**Task:** Review if this is intentional. If not, renumber or fill the gap (q16-q50).

#### 1b. Missing Questions in Deeper Branch

The deeper branch is missing some questions that exist in lighthearted:
- Missing q63 (scent/perfume type)
- Missing q66 (comfort food)
- Missing q69 (favorite way to learn)
- Missing q72 (type of sandwich)
- Missing q75 (guilty pleasure)

**Task:** Add missing questions to deeper branch, or document why they're excluded.

#### 1c. You-or-Me Thematic Overlap

Similar questions appear across branches:

| Question | Branch 1 | Branch 2 |
|----------|----------|----------|
| "Apologize first" | playful (yom_q019) | intimate (yom_intimate_013) |
| "Stay up late talking" | playful (yom_q028) | intimate (yom_intimate_014) |
| "Better listener" | reflective (yom_q049) | intimate (yom_intimate_018) |

**Task:** Remove duplicates from one branch or differentiate the framing.

**Reference:** `docs/QUIZ_CONTENT_ANALYSIS.md` → "Critical Issues" and "Minor Issues" sections

---

### Phase 2: Quest Card Badge

**Files:**
- `lib/widgets/quest_card.dart`

**Tasks:**
1. Add `isTherapeuticBranch()` helper function
2. Add positioned "Deeper" badge container over quest image
3. Conditionally render badge for therapeutic branches

**Test:** Verify badge appears on Connection/Attachment/Growth quest cards only.

---

### Phase 3: Intro Screen Badge

**Files:**
- `lib/screens/quiz_intro_screen.dart`
- `lib/screens/affirmation_intro_screen.dart`
- `lib/screens/you_or_me_match_intro_screen.dart`

**Tasks:**
1. Modify badge section to render two badges in a Row
2. Add "Deeper" badge conditionally for therapeutic branches
3. Update description copy for therapeutic branches
4. (Optional) Add first-time therapeutic note with storage tracking

**Test:** Verify "Deeper" badge and updated copy appear for therapeutic branches.

---

### Phase 4: Results Screen Redesign

**Files:**
- `lib/screens/quiz_match_results_screen.dart` (major rewrite)
- `lib/screens/you_or_me_match_results_screen.dart` (major rewrite)
- Possibly: `lib/models/quiz_match.dart`, API routes

**Tasks:**
1. Create new results screen layout with score header + scrollable details
2. Implement message copy logic based on score ranges
3. Implement question list with match/mismatch styling
4. Add conversation prompts for therapeutic mismatches
5. Ensure API returns full question/answer data
6. Handle Affirmation rating bars
7. Handle You-or-Me pick display

**Test:**
- All score ranges show correct messages
- Matches show green styling
- Mismatches show appropriate styling (playful for casual, prompts for therapeutic)
- Scrolling works with many questions
- LP display is correct

---

### Phase 5: Therapeutic Content Creation

**Files to create:**
```
app/assets/brands/togetherremind/data/
├── classic-quiz/connection/
│   ├── questions.json    ← 50 questions
│   └── manifest.json
├── affirmation/attachment/
│   ├── quizzes.json      ← 6 quizzes × 5 statements = 30
│   └── manifest.json
└── you-or-me/growth/
    ├── questions.json    ← 30 questions
    └── manifest.json
```

#### 4a. Connection Branch (Classic Quiz) — READY

**Status:** Full JSON with 5 options per question already written in `docs/QUIZ_CONTENT_ANALYSIS.md`

**Content:** 50 questions across 5 themes:
- Theme 1: Dreams & Aspirations (conn_001 - conn_010)
- Theme 2: Worries & Stresses (conn_011 - conn_020)
- Theme 3: Values & Beliefs (conn_021 - conn_030)
- Theme 4: Emotional Needs (conn_031 - conn_040)
- Theme 5: History & Identity (conn_041 - conn_050)

**Task:** Copy JSON from analysis doc into `questions.json` file.

**Source:** `docs/QUIZ_CONTENT_ANALYSIS.md` → Search for "Theme 1: Dreams & Aspirations"

#### 4b. Attachment Branch (Affirmation) — NEEDS EXPANSION

**Status:** Table format in analysis doc, needs conversion to full JSON

**Content:** 6 quizzes × 5 statements = 30 total:
- Quiz 1: "Are You There For Me?" (Accessibility)
- Quiz 2: "Can I Count On You?" (Responsiveness)
- Quiz 3: "Do I Matter To You?" (Engagement)
- Quiz 4: "Can We Repair?" (Repair)
- Quiz 5: "Do I Trust You?" (Trust)
- Quiz 6: "Am I Safe With You?" (Security)

**Task:** Convert table format to full `quizzes.json` structure matching existing affirmation format.

**Source:** `docs/QUIZ_CONTENT_ANALYSIS.md` → Search for "Affirmation: Attachment Branch"

**JSON structure needed:**
```json
{
  "quizzes": [
    {
      "id": "attachment_accessibility",
      "title": "Are You There For Me?",
      "subtitle": "Can I reach you when I need you?",
      "category": "accessibility",
      "statements": [
        {
          "id": "att_001",
          "text": "My partner is emotionally available when I need them.",
          "dimension": "responsiveness"
        }
        // ... 4 more statements
      ]
    }
    // ... 5 more quizzes
  ]
}
```

#### 4c. Growth Branch (You-or-Me) — NEEDS EXPANSION

**Status:** Table format in analysis doc, needs conversion to full JSON

**Content:** 30 questions across themes:
- Conflict & Repair patterns
- Vulnerability & Support
- Dreams & Growth
- Daily Dynamics

**Task:** Convert table format to full `questions.json` structure matching existing You-or-Me format.

**Source:** `docs/QUIZ_CONTENT_ANALYSIS.md` → Search for "You-or-Me: Growth Branch"

**JSON structure needed:**
```json
[
  {
    "id": "growth_001",
    "question": "Who finds it harder to ask for help?",
    "category": "vulnerability",
    "difficulty": 2
  }
  // ... 29 more questions
]
```

#### 4d. Manifest Files

Each new branch needs a `manifest.json`:

```json
{
  "displayName": "Connection",
  "title": "Connection Quiz",
  "description": "Discover each other's inner world",
  "video": "connection-intro.mp4",
  "fallbackEmoji": "💫",
  "isTherapeutic": true
}
```

**Videos:** Either create new videos or reuse existing branch videos initially.

**Reference:** See `docs/QUIZ_CONTENT_ANALYSIS.md` Part 2 for full question/statement lists.

---

### Phase 5: Branch Rotation Update

**Effort:** ~1-2 hours

**Files:**
- `lib/services/quest_type_manager.dart`
- Possibly: branch configuration files

**Tasks:**
1. Add Connection, Attachment, Growth to branch rotation
2. Update rotation formula: `currentBranch = totalCompletions % 4`
3. Mark new branches as therapeutic in configuration

---

## Part 6: Mockup File Reference

All mockups are located in `mockups/quiz_improvements/`:

### Quest Cards
| File | Description |
|------|-------------|
| `quest-cards/quest-card-comparison.html` | Side-by-side casual vs therapeutic with "Deeper" badge |

### Intro Screens
| File | Description |
|------|-------------|
| `intro-screens/intro-therapeutic-additions.html` | Shows badge additions to existing intro screen structure |

### Results Screens
| File | Description |
|------|-------------|
| `results-screens/results-classic-casual.html` | Classic quiz casual — high/mid/low score variants |
| `results-screens/results-classic-therapeutic.html` | Classic quiz therapeutic — warm discovery framing |
| `results-screens/results-affirmation-casual.html` | Affirmation casual — alignment dots display |
| `results-screens/results-affirmation-therapeutic.html` | Affirmation therapeutic — validates both perspectives |
| `results-screens/results-youorme-casual.html` | You-or-Me casual — playful debate framing |
| `results-screens/results-youorme-therapeutic.html` | You-or-Me therapeutic — pattern exploration |

### Details Screens (Question Breakdown)
| File | Description |
|------|-------------|
| `details-screens/details-casual.html` | Question breakdown with playful comments for mismatches |
| `details-screens/details-therapeutic.html` | Question breakdown with conversation prompts for mismatches |

**Note:** The details screens show the **inline question list** portion that goes inside the new results screen (Option C), not a separate screen.

---

## Part 7: Open Questions — RESOLVED

| Question | Decision |
|----------|----------|
| Badge wording | "Deeper" — confirmed |
| Intro screen changes | Badge + copy only, keep video and structure |
| Results screen approach | Option C — full redesign with details inline |
| Conversation prompts | Start with generic per quiz type, iterate later |

---

## Appendix A: Therapeutic Branch Detection

```dart
/// Returns true if the branch is a therapeutic branch
bool isTherapeuticBranch(String? branch) {
  if (branch == null) return false;
  const therapeuticBranches = ['connection', 'attachment', 'growth'];
  return therapeuticBranches.contains(branch.toLowerCase());
}

/// Returns therapeutic description suffix for intro screens
String? getTherapeuticDescription(String? branch) {
  switch (branch?.toLowerCase()) {
    case 'connection':
      return 'These questions go a little deeper — discover what you truly know about each other\'s inner world.';
    case 'attachment':
      return 'This quiz explores how you each experience your connection — your sense of safety, trust, and closeness.';
    case 'growth':
      return 'These questions explore your patterns as a couple — how you support each other, handle challenges, and grow together.';
    default:
      return null;
  }
}
```

---

## Appendix B: Score Message Helper

```dart
/// Returns the appropriate message for a score
String getScoreMessage({
  required int score,
  required int total,
  required bool isTherapeutic,
  required String quizType,  // 'classic', 'affirmation', 'youorme'
}) {
  final percentage = (score / total * 100).round();

  if (quizType == 'classic') {
    if (isTherapeutic) {
      // Connection branch messages
      if (percentage >= 90) return 'You really see each other';
      if (percentage >= 70) return 'You know each other well — and learned even more today';
      if (percentage >= 50) return 'Some beautiful discoveries here';
      if (percentage >= 30) return 'You uncovered some new layers today';
      return 'Lots to explore together — that\'s a gift';
    } else {
      // Casual branch messages
      if (percentage >= 90) return 'You two are scary good';
      if (percentage >= 70) return 'Solid! You\'ve been paying attention';
      if (percentage >= 50) return 'A few surprises in there!';
      if (percentage >= 30) return 'Looks like you learned something new today';
      return 'Plot twist! Time to compare notes';
    }
  }
  // ... similar for affirmation and youorme
}
```

---

## Changelog

| Date | Change |
|------|--------|
| 2025-12-02 | Initial plan created |
| 2025-12-02 | Updated with Option C decision — results screen full redesign |
| 2025-12-02 | Added detailed implementation specs and mockup references |

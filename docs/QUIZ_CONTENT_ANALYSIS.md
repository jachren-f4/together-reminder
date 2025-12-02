# Quiz Content Analysis Report

**Date:** 2025-12-01
**Scope:** All Classic Quiz, Affirmation Quiz, and You-or-Me question JSON files for both TogetherRemind and HolyCouples brands

---

## Executive Summary

This analysis reviewed all quiz question content across both brands to identify duplicates, quality issues, and potential concerns. Key findings include:

- **Critical:** HolyCouples is missing significant content (no spiritual affirmation quizzes, missing You-or-Me intimate)
- **Critical:** Multiple files are exact duplicates across brands (no brand differentiation)
- **Major:** HolyCouples classic-quiz "spicy" branch does not exist
- **Minor:** Some thematic overlap in questions, but generally acceptable variety

---

## File Inventory

### TogetherRemind Brand

| Activity | Branch | File | Question Count |
|----------|--------|------|----------------|
| Classic Quiz | lighthearted | questions.json | 180 questions |
| Classic Quiz | deeper | questions.json | 160 questions |
| Classic Quiz | spicy | questions.json | 180 questions |
| Affirmation | emotional | quizzes.json | 6 quizzes × 5 questions = 30 |
| Affirmation | practical | quizzes.json | 6 quizzes × 5 questions = 30 |
| Affirmation | spiritual | quizzes.json | 6 quizzes × 5 questions = 30 |
| You-or-Me | playful | questions.json | 30 questions |
| You-or-Me | reflective | questions.json | 30 questions |
| You-or-Me | intimate | questions.json | 30 questions |

### HolyCouples Brand

| Activity | Branch | File | Question Count | Status |
|----------|--------|------|----------------|--------|
| Classic Quiz | lighthearted | questions.json | ~180 questions | Exists |
| Classic Quiz | deeper | questions.json | ~160 questions | Exists |
| Classic Quiz | spicy | questions.json | N/A | **MISSING** |
| Affirmation | emotional | quizzes.json | 6 quizzes × 5 = 30 | Exists (duplicate) |
| Affirmation | practical | quizzes.json | 6 quizzes × 5 = 30 | Exists (duplicate) |
| Affirmation | spiritual | quizzes.json | N/A | **MISSING** (only manifest.json exists) |
| You-or-Me | playful | questions.json | 30 questions | Exists (duplicate) |
| You-or-Me | reflective | questions.json | 30 questions | Exists |
| You-or-Me | intimate | questions.json | N/A | **MISSING** |

---

## Critical Issues

### 1. Missing HolyCouples Content

**Severity: CRITICAL**

The following files do not exist for HolyCouples:

1. **`classic-quiz/spicy/questions.json`** - No spicy quiz content
2. **`affirmation/spiritual/quizzes.json`** - Only `manifest.json` exists, no actual quiz content
3. **`you-or-me/intimate/questions.json`** - No intimate You-or-Me content

**Impact:** HolyCouples users will experience errors or empty content when accessing these branches.

**Recommendation:** Either:
- Create HolyCouples-specific content for these branches (recommended for brand differentiation)
- Copy TogetherRemind files as a temporary fix
- Update the app to not offer these branches for HolyCouples

---

### 2. Exact Duplicate Files Across Brands

**Severity: CRITICAL**

The following files are **byte-for-byte identical** between TogetherRemind and HolyCouples:

| Activity | Branch | Finding |
|----------|--------|---------|
| Affirmation | emotional | Identical content |
| Affirmation | practical | Identical content |
| You-or-Me | playful | Identical content (same IDs: yom_q001-q030) |

**Impact:** No brand differentiation for a significant portion of content. HolyCouples is a religious-focused brand but shares secular content with TogetherRemind.

**Recommendation:**
- HolyCouples affirmation quizzes could include faith-based questions
- You-or-Me playful questions could be tailored to HolyCouples audience

---

## Major Issues

### 3. ID Numbering Gap in TogetherRemind Classic Quiz (Lighthearted)

**Severity: MAJOR**

The lighthearted classic quiz has a large gap in question IDs:
- Questions q1-q15, then jumps to q51-q180
- Missing IDs: q16-q50 (35 questions)

This appears intentional (questions are in the deeper branch with those IDs), but could cause confusion during maintenance.

**Recommendation:** Document the ID allocation scheme or renumber for consistency.

---

### 4. Missing Questions in TogetherRemind Deeper Branch

**Severity: MAJOR**

The deeper branch is missing some question IDs that exist in lighthearted:
- Missing q63 (scent/perfume type)
- Missing q66 (comfort food)
- Missing q69 (favorite way to learn)
- Missing q72 (type of sandwich)
- Missing q75 (guilty pleasure)
- etc.

Some questions have different difficulty levels in different files.

**Recommendation:** Review and reconcile the question sets for completeness.

---

## Minor Issues

### 5. Thematic Overlap in You-or-Me Questions

**Severity: MINOR**

Some questions have similar themes across branches:

| Question | Branch 1 | Branch 2 |
|----------|----------|----------|
| "Apologize first" | playful (yom_q019) | intimate (yom_intimate_013) |
| "Stay up late talking" | playful (yom_q028) | intimate (yom_intimate_014) |
| "Better listener" | reflective (yom_q049) | intimate (yom_intimate_018) |

**Impact:** Users may feel they're answering similar questions across branches.

**Recommendation:** Consider differentiating the framing or removing duplicates from one branch.

---

### 6. Inconsistent Category Naming

**Severity: MINOR**

Classic Quiz categories vary between files:
- `favorites`, `memories`, `preferences`, `daily_habits`, `future`, `would_you_rather`

Affirmation categories:
- `trust`, `emotional_support`, `communication`, `growth`, etc.

You-or-Me categories:
- `personality`, `actions`, `scenarios`, `comparative`

**Impact:** Category filtering may behave inconsistently if these are used in the UI.

**Recommendation:** Document the expected categories per activity type.

---

### 7. "Would You Rather" Format Inconsistency

**Severity: MINOR**

The "would_you_rather" questions in classic quiz use only 2 options, while other questions use 4-5 options. This is correct for the format but worth noting for UI handling.

Example:
```json
{
  "id": "q161",
  "question": "Would I rather: Beach vacation or Mountain retreat?",
  "options": ["Beach vacation", "Mountain retreat"]
}
```

---

## Quality Assessment

### Classic Quiz Questions

**Strengths:**
- Good variety of topics (favorites, memories, preferences, daily habits, future)
- Appropriate difficulty progression (1-3 scale)
- Consistent "Other / Something else" escape option
- Well-structured would-you-rather binary choices

**Areas for Improvement:**
- Some questions are very similar (e.g., multiple "favorite way to..." questions)
- Spicy branch is relationship/romance focused but tasteful

### Affirmation Quizzes

**Strengths:**
- Well-structured with clear categories (trust, growth, communication, support)
- Consistent 5-question format per quiz
- Good progression of emotional depth

**Areas for Improvement:**
- All questions use scale format only - could add variety
- Spiritual branch only exists for TogetherRemind

### You-or-Me Questions

**Strengths:**
- Clear distinction between branches (playful → reflective → intimate)
- Consistent prompt patterns ("Who's more...", "Who would...", "Who's more likely to...", "Which of you...")
- Good ID structure (playful: q001-030, reflective: q031-060, intimate: intimate_001-030)

**Areas for Improvement:**
- Some overlap between branches as noted above
- HolyCouples intimate branch missing

---

## Recommendations Summary

### Immediate Actions (P0)

1. **Create missing HolyCouples content files** or disable those branches in the app
2. **Add HolyCouples spiritual quizzes.json** (currently only manifest exists)

### Short-term Actions (P1)

3. **Differentiate HolyCouples content** - Add faith-based questions for affirmation and You-or-Me
4. **Review and deduplicate** similar questions across You-or-Me branches

### Long-term Actions (P2)

5. **Document ID allocation scheme** for classic quiz questions
6. **Create category documentation** for filtering consistency
7. **Consider brand-specific classic quiz content** if brands diverge further

---

## File Locations Reference

```
app/assets/brands/
├── togetherremind/data/
│   ├── classic-quiz/
│   │   ├── lighthearted/questions.json
│   │   ├── deeper/questions.json
│   │   └── spicy/questions.json
│   ├── affirmation/
│   │   ├── emotional/quizzes.json
│   │   ├── practical/quizzes.json
│   │   └── spiritual/quizzes.json
│   └── you-or-me/
│       ├── playful/questions.json
│       ├── reflective/questions.json
│       └── intimate/questions.json
│
└── holycouples/data/
    ├── classic-quiz/
    │   ├── lighthearted/questions.json
    │   ├── deeper/questions.json
    │   └── spicy/              ❌ MISSING
    ├── affirmation/
    │   ├── emotional/quizzes.json   (duplicate of TR)
    │   ├── practical/quizzes.json   (duplicate of TR)
    │   └── spiritual/              ❌ MISSING (only manifest)
    └── you-or-me/
        ├── playful/questions.json   (duplicate of TR)
        ├── reflective/questions.json
        └── intimate/               ❌ MISSING
```

---

## Couples Therapy Perspective: Therapeutic Quality Analysis

*The following analysis evaluates the question content through the lens of evidence-based couples therapy frameworks including Gottman Method, Emotionally Focused Therapy (EFT), and attachment theory.*

---

### Overall Therapeutic Assessment

**Current State: B- (Good foundation, significant missed opportunities)**

The existing questions serve as decent conversation starters but largely miss opportunities to facilitate the deeper emotional connection, vulnerability, and understanding that characterize transformative couples work. The questions tend to be **surface-level and fact-based** rather than **feeling-based and connective**.

---

### Critical Therapeutic Issues

#### 1. Classic Quiz: Too Trivia-Focused, Not Connection-Focused

**The Problem:**
Most classic quiz questions read like a dating show trivia game rather than a relationship-building exercise:
- "What's my favorite pizza topping?"
- "What's my favorite ice cream flavor?"
- "What time do I usually wake up?"

**Why This Matters:**
In Gottman's research, couples who thrive have deep "Love Maps" — detailed knowledge of each other's inner worlds, dreams, fears, and values. Knowing your partner's pizza preference is surface-level. Knowing *why* certain foods bring them comfort, or what memories are attached to them, builds actual intimacy.

**Therapeutic Reframe Examples:**

| Current Question | Therapeutically Improved Version |
|------------------|----------------------------------|
| "What's my favorite food?" | "What food reminds me most of feeling safe and loved as a child?" |
| "What's my favorite holiday?" | "Which holiday traditions matter most to me and why?" |
| "What time do I usually wake up?" | "What does my morning routine reveal about how I prepare to face the world?" |
| "What's my favorite color?" | "What colors make me feel calm, energized, or happy — and why?" |

**The Shift:** Move from **"What"** to **"What + Why + Feeling"**

---

#### 2. You-or-Me: Competitive Framing Undermines Connection

**The Problem:**
The You-or-Me format inherently sets up comparison and potential defensiveness:
- "Who's more organized?"
- "Who's the better cook?"
- "Who's more emotional?"

**Why This Matters:**
Comparison questions can trigger:
- **Defensiveness** ("I'm not THAT disorganized!")
- **Criticism** (reinforces negative labels)
- **Contempt** (eye-rolling at partner's perceived weaknesses)

These are three of Gottman's "Four Horsemen" that predict relationship failure.

**Therapeutic Reframe Strategy:**

Instead of comparison, shift to **appreciation and curiosity**:

| Current (Comparative) | Improved (Appreciative/Curious) |
|-----------------------|---------------------------------|
| "Who's more organized?" | "What do each of us bring to keeping our life running smoothly?" |
| "Who's the better listener?" | "When do I feel most heard by you?" |
| "Who's more emotional?" | "How do we each process and express feelings differently?" |
| "Who apologizes first?" | "What helps us reconnect after we've hurt each other?" |

**Alternative Format:** Consider a "What I Love About Us" frame:
- "One thing my partner does that makes me feel cared for is..."
- "A strength my partner brings to our relationship that I don't have is..."

---

#### 3. Affirmation Quizzes: Right Format, Needs Deeper Content

**The Strength:**
The scale-based affirmation format ("Rate how much you agree...") is therapeutically sound. It:
- Invites reflection rather than right/wrong answers
- Allows partners to see where they're aligned or misaligned
- Creates conversation openings

**The Gap:**
The current affirmations are somewhat generic and don't target the specific attachment needs that drive relationship satisfaction:

Current examples:
- "We laugh together without effort."
- "I feel comfortable being myself around my partner."

**Missing Dimensions (Based on EFT and Attachment Theory):**

1. **Accessibility** - "Are you there for me?"
   - "When I reach out, my partner responds."
   - "I know my partner will drop what they're doing if I really need them."

2. **Responsiveness** - "Can I rely on you?"
   - "My partner tunes into my emotions even when I don't say anything."
   - "When I'm struggling, my partner notices and asks about it."

3. **Engagement** - "Do I matter to you?"
   - "My partner shows me I'm a priority, not an afterthought."
   - "I feel special and chosen by my partner."

4. **Repair** - How we handle ruptures
   - "After disagreements, we find our way back to each other."
   - "I trust that conflict won't break us."

5. **Dreams and Meaning**
   - "My partner knows my biggest dreams and fears."
   - "We share a vision for our future."

---

#### 4. Missing: Bids for Connection & Turning Toward

**Critical Gap:**
Gottman's research shows the #1 predictor of relationship success is how partners respond to each other's "bids for connection" — small moments of reaching out.

**No questions address:**
- How partners respond when one shares good news (active constructive responding)
- How partners respond when one is stressed
- Small daily rituals of connection
- How partners handle interruptions or distraction

**Suggested Questions to Add:**

For Classic Quiz:
- "When I share exciting news with my partner, how do they typically respond?"
- "What's the small daily ritual that makes me feel most connected to my partner?"
- "When I'm stressed, what does my partner do that helps most?"

For Affirmation:
- "When I share something I'm excited about, my partner celebrates with me."
- "My partner puts down their phone/stops what they're doing when I want to talk."
- "We have small rituals that keep us connected (morning coffee, goodnight kiss, etc.)."

---

#### 5. Missing: Vulnerability and Deeper Emotional Content

**The Problem:**
Even the "intimate" and "deeper" branches avoid true emotional vulnerability:

Current "intimate" questions:
- "Who's more likely to cry during an emotional moment?"
- "Who needs more reassurance after an argument?"

These still compare rather than invite vulnerability.

**What's Missing:**

**Fear and Insecurity:**
- "What's my deepest fear about our relationship?"
- "When do I feel most insecure with you?"
- "What from my past makes trusting difficult?"

**Longing and Need:**
- "What do I most need from you that I struggle to ask for?"
- "When do I feel most loved by you?"
- "What would help me feel safer being vulnerable with you?"

**Repair and Forgiveness:**
- "What's been hardest for me to forgive?"
- "What do I need when we're disconnected?"
- "How do I know when we've truly repaired after a fight?"

**Dreams and Meaning:**
- "What dream of mine do you support that means the most to me?"
- "What do I hope people say about our relationship?"
- "What am I most proud of about us?"

---

### Improvement Plan: Phased Approach

---

## Phase 1: Quick Wins (1-2 weeks, content changes only)

**Goal:** Improve therapeutic value with minimal code changes. Focus on content updates to existing JSON files.

---

### 1.1 Add "Why" Follow-Up Prompts to Classic Quiz

**What:** Add an optional `followUp` field to existing questions that deepens the conversation.

**Schema Change:**
```json
{
  "id": "q1",
  "question": "What's my favorite food?",
  "options": ["Pizza", "Sushi", "Pasta", "Tacos", "Other"],
  "followUp": "What memory or feeling does this food connect to for me?",
  "category": "favorites",
  "difficulty": 1
}
```

**Implementation:**
- Add `followUp` field to 50 highest-impact questions across all branches
- UI can display this after answer reveal: "Discuss together: [followUp text]"
- No code changes required if UI ignores unknown fields; otherwise minor UI update

**Specific Questions to Add Follow-Ups (Priority Order):**

| Question ID | Current Question | Follow-Up Prompt |
|-------------|------------------|------------------|
| q1 | "What's my favorite food?" | "What memory or feeling does this food connect to?" |
| q2 | "What's my favorite movie?" | "What does this movie say about what I value or long for?" |
| q51 | "What's my biggest pet peeve?" | "What need of mine gets violated when this happens?" |
| q52 | "What's my love language?" | "Can you share a time you made me feel loved this way?" |
| q55 | "What's my dream vacation?" | "What would experiencing this together mean to us?" |
| q56 | "What's my biggest fear?" | "How can you help me feel safe about this?" |
| q61 | "What makes me feel appreciated?" | "When did you last make me feel this way?" |
| q131 | "Where would I want to live?" | "What kind of life together does this represent?" |
| q155 | "What fear do I have about our future?" | "What reassurance do I need from you about this?" |

**Files to Update:**
- `togetherremind/data/classic-quiz/lighthearted/questions.json`
- `togetherremind/data/classic-quiz/deeper/questions.json`
- `togetherremind/data/classic-quiz/spicy/questions.json`
- Mirror to HolyCouples where applicable

---

### 1.2 Reframe 10 Most Problematic You-or-Me Questions

**What:** Replace competitive/judgmental questions with appreciative alternatives.

**The 10 Questions to Rewrite:**

| ID | Current (Problematic) | Rewritten (Appreciative) | Why It's Better |
|----|----------------------|--------------------------|-----------------|
| yom_q002 | "Who's more... Organized" | "Who helps keep our life running smoothly in their own way?" | Values both styles |
| yom_q013 | "Who's more... Emotional" | "Who expresses feelings more openly?" | Removes judgment |
| yom_q019 | "Who would... Apologize first after an argument" | "Who tends to reach out first when we're disconnected?" | Frames as positive |
| yom_q043 | "Who's more likely to... Win an argument" | "Who tends to be more persistent in discussions?" | Neutral framing |
| yom_q032 | "Who's more likely to... Forget an anniversary" | "Who relies more on reminders for special dates?" | No blame |
| yom_q046 | "Which of you... Is the better dancer" | "Who's more likely to pull the other onto the dance floor?" | Action vs. judgment |
| yom_q047 | "Which of you... Is the better cook" | "Who's more adventurous in the kitchen?" | Removes competition |
| yom_q056 | "Which of you... Is the better driver" | "Who's more confident behind the wheel?" | Subjective, not ranked |
| yom_intimate_023 | "Which of you... Is more afraid of losing the other" | "Who needs more reassurance about our bond?" | Frames as need, not weakness |
| yom_intimate_027 | "Which of you... Would sacrifice more for the other" | "How do we each show devotion in our own ways?" | Both valued |

**Files to Update:**
- `togetherremind/data/you-or-me/playful/questions.json`
- `togetherremind/data/you-or-me/reflective/questions.json`
- `togetherremind/data/you-or-me/intimate/questions.json`
- `holycouples/data/you-or-me/playful/questions.json`
- `holycouples/data/you-or-me/reflective/questions.json`

---

### 1.3 Add "Bids for Connection" Affirmation Quiz

**What:** Create a new quiz within the emotional affirmation branch focused on Gottman's "turning toward" research.

**New Quiz to Add:**

```json
{
  "id": "bids_connection",
  "name": "Turning Toward",
  "category": "connection",
  "difficulty": 1,
  "formatType": "affirmation",
  "imagePath": "assets/images/quests/feel-good-foundations.png",
  "description": "How we respond to each other's bids for connection",
  "questions": [
    {
      "question": "When I reach out to share something, my partner responds with interest.",
      "questionType": "scale",
      "options": [],
      "correctAnswer": null
    },
    {
      "question": "My partner notices when something is bothering me, even if I don't say anything.",
      "questionType": "scale",
      "options": [],
      "correctAnswer": null
    },
    {
      "question": "We have small daily rituals that keep us connected (morning coffee, goodnight kiss, etc.).",
      "questionType": "scale",
      "options": [],
      "correctAnswer": null
    },
    {
      "question": "When something good happens to me, my partner celebrates with genuine enthusiasm.",
      "questionType": "scale",
      "options": [],
      "correctAnswer": null
    },
    {
      "question": "I feel like a priority in my partner's life, not an afterthought.",
      "questionType": "scale",
      "options": [],
      "correctAnswer": null
    }
  ]
}
```

**Files to Update:**
- `togetherremind/data/affirmation/emotional/quizzes.json` (add to quizzes array)
- `holycouples/data/affirmation/emotional/quizzes.json` (add to quizzes array)

---

### 1.4 Add "Repair & Safety" Affirmation Quiz

**What:** Create quiz focused on how couples handle conflict and repair.

**New Quiz to Add:**

```json
{
  "id": "repair_safety",
  "name": "Navigating Hard Moments",
  "category": "repair",
  "difficulty": 1,
  "formatType": "affirmation",
  "imagePath": "assets/images/quests/feel-good-foundations.png",
  "description": "How we handle disagreements and reconnect",
  "questions": [
    {
      "question": "I trust that we can work through disagreements without damaging our relationship.",
      "questionType": "scale",
      "options": [],
      "correctAnswer": null
    },
    {
      "question": "After conflict, we find our way back to each other.",
      "questionType": "scale",
      "options": [],
      "correctAnswer": null
    },
    {
      "question": "I feel safe bringing up difficult topics with my partner.",
      "questionType": "scale",
      "options": [],
      "correctAnswer": null
    },
    {
      "question": "My partner takes responsibility when they've hurt me.",
      "questionType": "scale",
      "options": [],
      "correctAnswer": null
    },
    {
      "question": "We can disagree without it threatening our sense of 'us'.",
      "questionType": "scale",
      "options": [],
      "correctAnswer": null
    }
  ]
}
```

---

### 1.5 Enhance Existing Affirmation Questions

**What:** Rewrite 15 existing affirmation questions to be more specific and vulnerability-inviting.

**Rewrites:**

| Quiz | Current | Rewritten |
|------|---------|-----------|
| gentle_beginnings | "I enjoy learning small new things about my partner every day." | "I'm still curious about my partner's inner world." |
| gentle_beginnings | "Being with my partner feels natural and relaxed." | "I can be my full, unfiltered self around my partner." |
| warm_vibes | "We share positive emotions regularly." | "When something good happens, my partner is the first person I want to tell." |
| simple_joys | "Small joys help strengthen our bond." | "The ordinary moments with my partner feel meaningful." |
| getting_comfortable | "I feel accepted as I am." | "I don't have to perform or pretend to earn my partner's love." |
| playful_moments | "Playfulness helps us stay close." | "We still flirt and play like we did at the beginning." |
| feelgood_foundations | "I feel good about the way we interact." | "Our daily interactions leave me feeling connected, not drained." |
| spiritual_gratitude | "I feel thankful for the little things my partner does." | "I regularly notice and appreciate the effort my partner puts into us." |
| spiritual_growth | "Our relationship helps me become a better person." | "My partner inspires me to grow in ways I couldn't alone." |
| spiritual_values | "I feel connected to my partner on a deeper level." | "My partner knows my deepest hopes and fears." |
| spiritual_purpose | "I believe we're meant to be together." | "I can't imagine building my life with anyone else." |
| spiritual_support | "I feel my partner truly understands me at a deep level." | "My partner 'gets' me in ways others don't." |
| spiritual_support | "I feel safe sharing my deepest thoughts with my partner." | "I can be vulnerable without fear of judgment or rejection." |
| practical_teamwork | "We handle responsibilities as a team." | "I trust my partner to carry their share without me having to ask." |
| practical_decisions | "We make decisions together effectively." | "I feel heard and valued when we make decisions together." |

---

## Phase 2: Content Enhancement (2-4 weeks, new content + minor features)

**Goal:** Create new question sets and quiz types that address therapeutic gaps.

---

### 2.1 Create "Love Maps" Classic Quiz Branch

**What:** A new branch of Classic Quiz focused specifically on deep knowledge of partner's inner world.

**New File:** `classic-quiz/love-maps/questions.json`

**Question Categories:**
1. **Dreams & Aspirations** (10 questions)
2. **Fears & Worries** (10 questions)
3. **Formative Experiences** (10 questions)
4. **Current Stressors** (10 questions)
5. **Sources of Joy** (10 questions)

**Sample Questions:**

```json
[
  {
    "id": "lm_001",
    "question": "What's my biggest dream that I haven't fully shared with you?",
    "options": [
      "A career or creative ambition",
      "A place I want to live or travel",
      "Something about our future together",
      "A personal transformation I want",
      "Other / Something else"
    ],
    "followUp": "What would achieving this dream mean to me?",
    "category": "dreams",
    "difficulty": 2
  },
  {
    "id": "lm_002",
    "question": "What worry keeps me up at night that I rarely talk about?",
    "options": [
      "Something about my health or family",
      "Concerns about our relationship",
      "Work or financial stress",
      "Fear about the future",
      "Other / Something else"
    ],
    "followUp": "How can you help me feel less alone with this worry?",
    "category": "fears",
    "difficulty": 2
  },
  {
    "id": "lm_003",
    "question": "What experience from my childhood still affects me today?",
    "options": [
      "A difficult family dynamic",
      "A formative friendship or relationship",
      "An achievement or failure",
      "A loss or disappointment",
      "Other / Something else"
    ],
    "followUp": "How does understanding this help you understand me better?",
    "category": "formative",
    "difficulty": 3
  },
  {
    "id": "lm_004",
    "question": "What's stressing me most right now that I might be hiding?",
    "options": [
      "Work pressure",
      "Health or body concerns",
      "Family or friend issues",
      "Something about us",
      "Other / Something else"
    ],
    "followUp": "What kind of support would help most right now?",
    "category": "stressors",
    "difficulty": 2
  },
  {
    "id": "lm_005",
    "question": "What small thing brings me unexpected joy that you might not know about?",
    "options": [
      "A specific sensory experience (smell, sound, taste)",
      "A quiet activity or hobby",
      "A type of connection or conversation",
      "Something nostalgic",
      "Other / Something else"
    ],
    "followUp": "How could you help me experience this joy more often?",
    "category": "joy",
    "difficulty": 1
  }
]
```

**Full Question List (50 questions):** See Appendix A below.

---

### 2.2 Therapeutically-Improved You-or-Me Questions (Maintains Two-Choice Format)

**What:** Reframe existing You-or-Me questions to reduce competitiveness while **keeping the exact same "You" or "Me" two-button format**.

**Key insight:** The issue isn't the two-choice format—it's the *framing* of questions. By changing from judgmental comparisons ("Who's better at...") to observational patterns ("Who tends to..."), we remove the competitive sting while maintaining the simple gameplay.

---

#### How Users Experience This

**Current (Competitive):**
```
Screen shows:
┌─────────────────────────────────────┐
│     Who's more organized?           │
│                                     │
│    [  YOU  ]     [  ME  ]           │
└─────────────────────────────────────┘
```
*Problem: Implies one person is "better" and the other is "worse"*

**Improved (Observational):**
```
Screen shows:
┌─────────────────────────────────────┐
│  Who tends to take charge of        │
│  planning and organizing?           │
│                                     │
│    [  YOU  ]     [  ME  ]           │
└─────────────────────────────────────┘
```
*Solution: Observes a pattern without judging it as good or bad*

---

#### Before/After Examples (Same Two-Choice Format)

| Current Question | Improved Question |
|-----------------|-------------------|
| "Who's more organized?" | "Who tends to create structure in our daily routines?" |
| "Who's more emotional?" | "Who tends to express feelings more openly?" |
| "Who's more patient?" | "Who tends to stay calm when things take longer?" |
| "Who's more ambitious?" | "Who tends to dream bigger about the future?" |
| "Who's better listener?" | "Who tends to ask more follow-up questions?" |
| "Who would apologize first?" | "Who tends to reach out first after tension?" |

---

#### Full JSON Example (Maintains Existing Format)

```json
{
  "questions": [
    {
      "id": "yom_appreciative_001",
      "prompt": "Who tends to...",
      "content": "Create cozy moments for us",
      "category": "contributions"
    },
    {
      "id": "yom_appreciative_002",
      "prompt": "Who tends to...",
      "content": "Keep us laughing when things get stressful",
      "category": "contributions"
    },
    {
      "id": "yom_appreciative_003",
      "prompt": "Who tends to...",
      "content": "Remember the little things that matter",
      "category": "contributions"
    },
    {
      "id": "yom_appreciative_004",
      "prompt": "Who tends to...",
      "content": "Reach out first when we've been apart",
      "category": "connection"
    },
    {
      "id": "yom_appreciative_005",
      "prompt": "Who tends to...",
      "content": "Notice when something's bothering the other",
      "category": "attunement"
    }
  ]
}
```

**Note:** This uses the **exact same JSON structure** as the existing You-or-Me questions. No code changes required—just content updates.

---

#### Implementation Options

**Option A: Replace existing questions (recommended)**
- Update content in `playful/`, `reflective/`, `intimate/` branches
- Zero code changes
- Immediate impact

**Option B: Add new "appreciative" branch**
- Add 4th branch: `you-or-me/appreciative/questions.json`
- Requires updating `branchFolderNames` in `branch_progression_state.dart`
- Allows A/B testing

**See Appendix C for complete 90-question set (30 per branch) with therapeutically-improved rewrites.**

---

### 2.3 Therapeutically-Improved Intimate Branch (Maintains Two-Choice Format)

**What:** Reframe the intimate You-or-Me questions to invite vulnerability and deeper connection while **keeping the exact same "You" or "Me" two-button format**.

**Updates to:** `you-or-me/intimate/questions.json`

**Key insight:** Intimate questions can explore deep topics while still using "Who tends to..." framing. The intimacy comes from the *topic*, not from changing the format.

---

#### How Users Experience This

**Current (Comparison-focused):**
```
Screen shows:
┌─────────────────────────────────────┐
│  Which of you is more romantic      │
│  at heart?                          │
│                                     │
│    [  YOU  ]     [  ME  ]           │
└─────────────────────────────────────┘
```
*Problem: Creates a "winner" and "loser" on emotional topics*

**Improved (Vulnerability-inviting):**
```
Screen shows:
┌─────────────────────────────────────┐
│  Who tends to need more             │
│  reassurance after we've been apart?│
│                                     │
│    [  YOU  ]     [  ME  ]           │
└─────────────────────────────────────┘
```
*Solution: Invites honest reflection without judgment*

---

#### Before/After Examples (Same Two-Choice Format)

| Current Question | Improved Question |
|-----------------|-------------------|
| "Who's more romantic at heart?" | "Who tends to create romantic moments?" |
| "Who's more afraid of losing the other?" | "Who tends to need more reassurance about us?" |
| "Who's the better listener?" | "Who tends to hold space when the other is struggling?" |
| "Who falls deeper in love over time?" | "Who tends to express growing appreciation?" |
| "Who would sacrifice more?" | "Who tends to put the other's needs first?" |

---

#### Full JSON Example (30 Questions for Intimate Branch)

```json
{
  "questions": [
    {
      "id": "yom_intimate_v2_001",
      "prompt": "Who tends to...",
      "content": "Need more reassurance after we've been apart",
      "category": "attachment"
    },
    {
      "id": "yom_intimate_v2_002",
      "prompt": "Who tends to...",
      "content": "Reach out first when sensing distance between us",
      "category": "attachment"
    },
    {
      "id": "yom_intimate_v2_003",
      "prompt": "Who tends to...",
      "content": "Express vulnerability more openly",
      "category": "vulnerability"
    },
    {
      "id": "yom_intimate_v2_004",
      "prompt": "Who tends to...",
      "content": "Hold space when the other is struggling",
      "category": "support"
    },
    {
      "id": "yom_intimate_v2_005",
      "prompt": "Who tends to...",
      "content": "Initiate deep conversations about us",
      "category": "connection"
    },
    {
      "id": "yom_intimate_v2_006",
      "prompt": "Who tends to...",
      "content": "Notice when something feels off between us",
      "category": "attunement"
    },
    {
      "id": "yom_intimate_v2_007",
      "prompt": "Who tends to...",
      "content": "Break the silence first after tension",
      "category": "repair"
    },
    {
      "id": "yom_intimate_v2_008",
      "prompt": "Who tends to...",
      "content": "Dream out loud about our future together",
      "category": "dreams"
    },
    {
      "id": "yom_intimate_v2_009",
      "prompt": "Who tends to...",
      "content": "Create safety for hard conversations",
      "category": "safety"
    },
    {
      "id": "yom_intimate_v2_010",
      "prompt": "Who tends to...",
      "content": "Express gratitude for the small things",
      "category": "appreciation"
    }
  ]
}
```

**Note:** Uses the **exact same JSON structure** as existing You-or-Me questions. No code changes required.

**Themes covered:**
- **Attachment** (10 questions): Reassurance, closeness, security
- **Repair** (10 questions): Conflict recovery, forgiveness, reconnection
- **Dreams** (10 questions): Future, meaning, shared vision

**See Appendix C for the complete 30-question intimate branch rewrite.**

---

### 2.4 Add Attachment-Focused Affirmation Branch

**What:** New affirmation category based on A.R.E. (Accessibility, Responsiveness, Engagement) from EFT.

**New File:** `affirmation/attachment/quizzes.json`

**5 Quizzes:**

1. **"Are You There For Me?"** (Accessibility)
   - "My partner is available when I need them."
   - "I can reach my partner emotionally."
   - "My partner makes time for me."
   - "I don't have to compete for my partner's attention."
   - "My partner is present, not distracted, when we're together."

2. **"Can I Rely On You?"** (Responsiveness)
   - "My partner responds to my emotional needs."
   - "My partner comforts me when I'm upset."
   - "My partner takes my concerns seriously."
   - "My partner adjusts when they see I'm struggling."
   - "My partner's responses match what I need."

3. **"Do I Matter To You?"** (Engagement)
   - "I feel valued and important to my partner."
   - "My partner is genuinely interested in my inner world."
   - "My partner prioritizes our relationship."
   - "I feel special and chosen."
   - "My partner invests in keeping our connection strong."

4. **"Can We Handle Hard Things?"** (Repair)
   - "We recover well from disagreements."
   - "I trust we can work through anything."
   - "Conflict doesn't threaten our bond."
   - "We both take responsibility when we mess up."
   - "Our relationship is resilient."

5. **"Are We Building Something?"** (Meaning)
   - "We share a vision for our future."
   - "We're creating something meaningful together."
   - "Our relationship has purpose beyond just us."
   - "We have shared dreams we're working toward."
   - "I know my role in my partner's life story."

---

## Phase 3: Structural Improvements (Significant feature work)

**Goal:** Add features that enhance the therapeutic impact of the quiz experience.

---

### 3.1 Post-Quiz Discussion Prompts

**What:** After quiz completion, show a guided discussion prompt based on results. Each quiz type has different mechanics and needs tailored prompts.

---

#### 3.1.1 Classic Quiz Discussion Prompts

**How Classic Quiz works:**
- Partner A answers questions about Partner B (e.g., "What's Alex's favorite food?")
- Partner B answers questions about Partner A (e.g., "What's Jamie's favorite food?")
- Results show: correct/incorrect for each question
- Score: percentage of questions each partner got right

**What users see after completing:**
```
┌─────────────────────────────────────────────────┐
│  Results                                        │
│                                                 │
│  Alex got 7/10 about Jamie                      │
│  Jamie got 8/10 about Alex                      │
│                                                 │
│  ✓ Favorite food - Both correct!                │
│  ✓ Dream vacation - Both correct!               │
│  ✗ Biggest current stress - Alex missed         │
│  ✓ Childhood memory - Both correct!             │
│  ...                                            │
└─────────────────────────────────────────────────┘
```

**Discussion prompts by result type:**

**When both got it right:**
```
┌─────────────────────────────────────────────────┐
│  💬 Discussion Moment                           │
│                                                 │
│  You both knew: "What's my biggest current      │
│  stress right now?"                             │
│                                                 │
│  Share: How did you know this about each        │
│  other? When did you last talk about it?        │
└─────────────────────────────────────────────────┘
```

**When one or both missed:**
```
┌─────────────────────────────────────────────────┐
│  💬 Learning Moment                             │
│                                                 │
│  You discovered: Alex's comfort food is         │
│  actually "Mom's lasagna" - Jamie guessed       │
│  "pizza"                                        │
│                                                 │
│  Share: Alex, what makes this food special      │
│  to you? Is there a memory attached?            │
└─────────────────────────────────────────────────┘
```

**JSON structure for Classic Quiz prompts:**
```json
{
  "questionId": "q47",
  "question": "What's my biggest current stress?",
  "discussionPrompts": {
    "bothCorrect": "How did you know this? When did you last talk about it?",
    "oneMissed": "{knower}, what clues helped you know this? {learner}, were you surprised?",
    "bothMissed": "This is something you're both still learning! Take a moment to share."
  }
}
```

---

#### 3.1.2 Affirmation Quiz Discussion Prompts

**How Affirmation Quiz works:**
- Both partners rate the same statements on a 1-5 scale
- Example: "I feel comfortable being myself around my partner" → ⭐⭐⭐⭐⭐
- Results show: side-by-side ratings for each statement
- No "correct" answer - it's about alignment and perception

**What users see after completing:**
```
┌─────────────────────────────────────────────────┐
│  "Gentle Beginnings" Results                    │
│                                                 │
│  Statement                    Alex    Jamie     │
│  ─────────────────────────────────────────────  │
│  "I feel comfortable being    ⭐⭐⭐⭐⭐   ⭐⭐⭐⭐    │
│   myself around my partner"                     │
│                                                 │
│  "We laugh together           ⭐⭐⭐⭐⭐   ⭐⭐⭐⭐⭐   │
│   without effort"                               │
│                                                 │
│  "My partner makes time       ⭐⭐⭐     ⭐⭐⭐⭐⭐   │
│   for what matters to me"     ← Gap detected    │
└─────────────────────────────────────────────────┘
```

**Discussion prompts by result type:**

**When ratings align (both high):**
```
┌─────────────────────────────────────────────────┐
│  💬 Celebration Moment                          │
│                                                 │
│  You both rated highly: "We laugh together      │
│  without effort"                                │
│                                                 │
│  Share: What's a recent moment that made        │
│  you both laugh? What do you love about         │
│  your humor together?                           │
└─────────────────────────────────────────────────┘
```

**When ratings diverge (gap of 2+):**
```
┌─────────────────────────────────────────────────┐
│  💬 Understanding Moment                        │
│                                                 │
│  You rated differently: "My partner makes       │
│  time for what matters to me"                   │
│  Alex: ⭐⭐⭐  |  Jamie: ⭐⭐⭐⭐⭐                   │
│                                                 │
│  This isn't about right or wrong - you          │
│  simply experience this differently.            │
│                                                 │
│  Alex, can you share what "making time"         │
│  looks like to you? What would help you         │
│  feel it more?                                  │
└─────────────────────────────────────────────────┘
```

**When both rate low (2 or below):**
```
┌─────────────────────────────────────────────────┐
│  💬 Growth Moment                               │
│                                                 │
│  You both rated lower: "We share our            │
│  worries openly with each other"                │
│                                                 │
│  This is an area you can grow in together.      │
│                                                 │
│  What makes it hard to share worries?           │
│  What would make it feel safer?                 │
└─────────────────────────────────────────────────┘
```

**JSON structure for Affirmation prompts:**
```json
{
  "quizId": "gentle_beginnings",
  "questions": [
    {
      "statement": "I feel comfortable being myself around my partner.",
      "discussionPrompts": {
        "bothHigh": "What helps you feel so comfortable? Share a moment when you felt fully yourself.",
        "divergent": "{lowerRater}, what would help you feel more comfortable being yourself?",
        "bothLow": "What holds you back from being fully yourself? What would help?"
      }
    }
  ]
}
```

---

#### 3.1.3 You-or-Me Discussion Prompts

**How You-or-Me works:**
- Both partners answer the same question with "You" or "Me"
- Example: "Who tends to reach out first after tension?" → [YOU] or [ME]
- Results show: whether partners agreed or disagreed
- The fun is seeing if you perceive yourselves the same way

**What users see after completing:**
```
┌─────────────────────────────────────────────────┐
│  Results: 7/10 Matched!                         │
│                                                 │
│  "Who tends to reach out       Alex: You        │
│   first after tension?"        Jamie: Me        │
│                                ✓ Matched!       │
│                                                 │
│  "Who tends to plan            Alex: Me         │
│   surprises?"                  Jamie: Me        │
│                                ✗ Different!     │
│                                (both said Me)   │
└─────────────────────────────────────────────────┘
```

**Discussion prompts by result type:**

**When partners matched:**
```
┌─────────────────────────────────────────────────┐
│  💬 Insight Moment                              │
│                                                 │
│  You agreed: Jamie tends to reach out first     │
│  after tension.                                 │
│                                                 │
│  Jamie, what makes you the one to reach out?    │
│  Alex, how does it feel when Jamie does this?   │
│  Is there anything you'd want to change?        │
└─────────────────────────────────────────────────┘
```

**When both said "Me" (both think they do it):**
```
┌─────────────────────────────────────────────────┐
│  💬 Discovery Moment                            │
│                                                 │
│  Interesting! You both said "Me" for:           │
│  "Who tends to plan surprises?"                 │
│                                                 │
│  You both feel like the surprise-planner!       │
│  Share a surprise you each planned recently.    │
│  Maybe you're both more thoughtful than you     │
│  give yourselves credit for?                    │
└─────────────────────────────────────────────────┘
```

**When both said "You" (both think the other does it):**
```
┌─────────────────────────────────────────────────┐
│  💬 Discovery Moment                            │
│                                                 │
│  Interesting! You both said "You" for:          │
│  "Who tends to keep us laughing?"               │
│                                                 │
│  You both see the other as the funny one!       │
│  What does your partner do that makes you       │
│  laugh? Tell each other.                        │
└─────────────────────────────────────────────────┘
```

**JSON structure for You-or-Me prompts:**
```json
{
  "questionId": "yom_appreciative_007",
  "prompt": "Who tends to...",
  "content": "Reach out first after tension",
  "discussionPrompts": {
    "matched": "{chosen}, what makes you the one to do this? {other}, how does it feel?",
    "bothSaidMe": "You both feel like you do this! Share an example each.",
    "bothSaidYou": "You both see this in each other! Tell each other what you notice."
  }
}
```

---

#### 3.1.4 Implementation Summary

| Quiz Type | Result Types | Prompt Focus |
|-----------|--------------|--------------|
| **Classic Quiz** | Both correct, one missed, both missed | Learning about each other |
| **Affirmation** | Both high, divergent, both low | Perception alignment |
| **You-or-Me** | Matched, both said Me, both said You | Self-perception vs partner-perception |

**UI Flow (all quiz types):**
1. Complete quiz → See results screen
2. Tap "Discuss Together" button
3. Cycle through 2-3 discussion prompts
4. Optional: Save insights to "Our Story" journal

---

---

# Part 2: Therapeutic Content Creation Plan

This section outlines the new therapeutic content needed to power features like the Relationship Dimensions Dashboard, while keeping existing casual content intact.

---

## Content Strategy Overview

### Guiding Principles

1. **Separate branches** — Casual content (pizza preferences, favorite colors) stays in existing branches. New therapeutic branches are added alongside them.

2. **Framework-driven** — Content draws from three evidence-based frameworks:
   - **Gottman Method** — Love Maps, Fondness & Admiration, Turning Toward, Repair
   - **Attachment Theory (EFT)** — A.R.E. (Accessibility, Responsiveness, Engagement)
   - **Love Languages** — 5 ways people give/receive love

3. **Dimension-mapped** — Every therapeutic question maps to one of 5 relationship dimensions for dashboard tracking.

4. **Volume target** — 200-300 new therapeutic questions across all quiz types.

---

## The 5 Relationship Dimensions

All therapeutic content maps to these dimensions, enabling the Relationship Dimensions Dashboard:

| Dimension | What It Measures | Frameworks Used |
|-----------|------------------|-----------------|
| **Feeling Known** | How deeply partners understand each other's inner world | Gottman Love Maps |
| **Appreciation** | How valued and admired partners feel | Gottman Fondness & Admiration, Love Languages |
| **Responsiveness** | How available and attuned partners are to each other | EFT A.R.E., Gottman Turning Toward |
| **Repair** | How well couples recover from conflict | Gottman Repair, EFT safe haven |
| **Shared Vision** | How aligned partners are on meaning and future | Gottman Shared Meaning |

---

## Content Creation Plan by Quiz Type

### Overview Table

| Quiz Type | Existing Content | New Therapeutic Branches | New Questions |
|-----------|------------------|-------------------------|---------------|
| **Classic Quiz** | 3 branches (lighthearted, deeper, spicy) ~520 questions | 1 branch: "connection" | 50 questions |
| **Affirmation** | 3 branches (emotional, practical, spiritual) ~90 questions | 2 branches: "attachment", "appreciation" | 60 questions (12 quizzes × 5) |
| **You-or-Me** | 3 branches (playful, reflective, intimate) ~90 questions | 2 branches: "growth", "repair" | 60 questions |
| **TOTAL** | ~700 questions | 5 new branches | **170 new items** |

*(Daily Deck is optional and can be added in a future release — see Section 6)*

---

## 1. Classic Quiz: "Connection" Branch (50 Questions)

**Purpose:** Deep "Love Maps" questions that help partners truly know each other's inner world.

**Dimension mapping:** All questions map to "Feeling Known"

**Structure:** 50 questions across 5 themes, 10 questions each

**File location:** `assets/brands/togetherremind/data/classic-quiz/connection/questions.json`

---

### Theme 1: Dreams & Aspirations (10 questions)
*"What does my partner dream about, hope for, and aspire to?"*

```json
[
  {
    "id": "conn_001",
    "question": "What's my biggest dream for the next 5 years?",
    "options": [
      "Career growth or a major professional achievement",
      "Starting or growing our family",
      "Travel, adventure, or new experiences",
      "Financial security or a big purchase (home, etc.)",
      "Other / Something else"
    ],
    "category": "dreams",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_002",
    "question": "What's something I've always wanted to try but haven't yet?",
    "options": [
      "A creative pursuit (art, music, writing)",
      "An adventurous activity (skydiving, travel, etc.)",
      "Learning a new skill (language, instrument, craft)",
      "A lifestyle change (new career, moving, etc.)",
      "Other / Something else"
    ],
    "category": "dreams",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_003",
    "question": "What would my ideal typical day look like?",
    "options": [
      "Peaceful and slow—time for myself and relaxation",
      "Productive and fulfilling—accomplishing meaningful work",
      "Social and connected—time with loved ones",
      "Adventurous and spontaneous—something new and exciting",
      "Other / Something else"
    ],
    "category": "dreams",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_004",
    "question": "What accomplishment am I most proud of?",
    "options": [
      "Something in my education or career",
      "A personal challenge I overcame",
      "A relationship I built or maintained",
      "Something creative I made or achieved",
      "Other / Something else"
    ],
    "category": "dreams",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_005",
    "question": "What skill do I wish I had?",
    "options": [
      "A creative skill (music, art, writing)",
      "A practical skill (cooking, fixing things, etc.)",
      "A social skill (public speaking, networking)",
      "A physical skill (sport, dance, fitness)",
      "Other / Something else"
    ],
    "category": "dreams",
    "difficulty": 1,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_006",
    "question": "What's my biggest career or life aspiration right now?",
    "options": [
      "Getting promoted or advancing professionally",
      "Changing careers or starting something new",
      "Achieving better work-life balance",
      "Building something of my own (business, project)",
      "Other / Something else"
    ],
    "category": "dreams",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_007",
    "question": "If I could live anywhere for a year, where would it be?",
    "options": [
      "A big, vibrant city",
      "A peaceful countryside or small town",
      "Somewhere by the ocean or beach",
      "A different country or culture entirely",
      "Other / Something else"
    ],
    "category": "dreams",
    "difficulty": 1,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_008",
    "question": "What cause or issue do I care most deeply about?",
    "options": [
      "Environmental or climate issues",
      "Social justice or equality",
      "Mental health or well-being",
      "Education or children's welfare",
      "Other / Something else"
    ],
    "category": "dreams",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_009",
    "question": "What's something I want us to experience together someday?",
    "options": [
      "A dream trip or adventure",
      "A major life milestone (home, family, etc.)",
      "Learning something new together",
      "A shared challenge or accomplishment",
      "Other / Something else"
    ],
    "category": "dreams",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_010",
    "question": "What legacy do I hope to leave?",
    "options": [
      "Being remembered as kind and caring",
      "Making a positive impact on the world",
      "Building a strong, loving family",
      "Creating something lasting (work, art, ideas)",
      "Other / Something else"
    ],
    "category": "dreams",
    "difficulty": 3,
    "dimension": "feeling_known"
  }
]
```

---

### Theme 2: Worries & Stresses (10 questions)
*"What weighs on my partner's mind?"*

```json
[
  {
    "id": "conn_011",
    "question": "What's my biggest current worry?",
    "options": [
      "Money or financial security",
      "Work or career pressures",
      "Health (mine or someone I love)",
      "Our relationship or family",
      "Other / Something else"
    ],
    "category": "worries",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_012",
    "question": "What situation in my life currently stresses me most?",
    "options": [
      "Work deadlines or job pressures",
      "Family dynamics or responsibilities",
      "Uncertainty about the future",
      "Not having enough time for myself",
      "Other / Something else"
    ],
    "category": "worries",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_013",
    "question": "What am I most afraid of happening in the next year?",
    "options": [
      "Losing someone I love",
      "Failing at something important to me",
      "Financial hardship or instability",
      "Growing apart or disconnecting",
      "Other / Something else"
    ],
    "category": "worries",
    "difficulty": 3,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_014",
    "question": "What childhood experience still affects me today?",
    "options": [
      "Family dynamics or relationships",
      "A difficult experience or loss",
      "Expectations placed on me",
      "Feeling different or not fitting in",
      "Other / Something else"
    ],
    "category": "worries",
    "difficulty": 3,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_015",
    "question": "What's something I find hard to talk about?",
    "options": [
      "My insecurities or self-doubt",
      "Past experiences that hurt me",
      "Fears about our future",
      "Things I need but struggle to ask for",
      "Other / Something else"
    ],
    "category": "worries",
    "difficulty": 3,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_016",
    "question": "What do I worry about regarding our relationship?",
    "options": [
      "Growing apart over time",
      "Not meeting each other's needs",
      "External pressures affecting us",
      "Repeating patterns from past relationships",
      "Other / Something else"
    ],
    "category": "worries",
    "difficulty": 3,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_017",
    "question": "What situation triggers anxiety for me?",
    "options": [
      "Social situations or being judged",
      "Uncertainty or lack of control",
      "Conflict or confrontation",
      "Feeling overwhelmed with responsibilities",
      "Other / Something else"
    ],
    "category": "worries",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_018",
    "question": "What do I wish I could change about my current life situation?",
    "options": [
      "My work or career path",
      "Where we live or our living situation",
      "How much free time I have",
      "A relationship or family dynamic",
      "Other / Something else"
    ],
    "category": "worries",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_019",
    "question": "What's weighing on me that I haven't fully shared yet?",
    "options": [
      "Stress about work or finances",
      "Concerns about my health or well-being",
      "Something about our relationship",
      "A personal struggle or insecurity",
      "Other / Something else"
    ],
    "category": "worries",
    "difficulty": 3,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_020",
    "question": "What do I need most when I'm stressed?",
    "options": [
      "Space and time alone to decompress",
      "Physical comfort (hugs, closeness)",
      "Someone to listen without fixing",
      "Distraction and fun to take my mind off it",
      "Other / Something else"
    ],
    "category": "worries",
    "difficulty": 2,
    "dimension": "feeling_known"
  }
]
```

---

### Theme 3: Values & Beliefs (10 questions)
*"What matters most to my partner?"*

```json
[
  {
    "id": "conn_021",
    "question": "What value is most important to me in life?",
    "options": [
      "Honesty and authenticity",
      "Kindness and compassion",
      "Freedom and independence",
      "Security and stability",
      "Other / Something else"
    ],
    "category": "values",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_022",
    "question": "What do I believe makes a relationship work?",
    "options": [
      "Open and honest communication",
      "Trust and loyalty",
      "Shared values and goals",
      "Effort and commitment from both sides",
      "Other / Something else"
    ],
    "category": "values",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_023",
    "question": "What's a belief I hold that not everyone understands?",
    "options": [
      "Something about relationships or love",
      "A spiritual or philosophical belief",
      "A view on how to live life",
      "An unpopular opinion I feel strongly about",
      "Other / Something else"
    ],
    "category": "values",
    "difficulty": 3,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_024",
    "question": "What do I think is the meaning of a good life?",
    "options": [
      "Deep, meaningful relationships",
      "Making a positive impact on others",
      "Personal growth and becoming my best self",
      "Enjoying experiences and finding happiness",
      "Other / Something else"
    ],
    "category": "values",
    "difficulty": 3,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_025",
    "question": "What principle would I never compromise on?",
    "options": [
      "Honesty—I can't tolerate lying",
      "Respect—everyone deserves dignity",
      "Loyalty—I stand by those I love",
      "Fairness—I believe in doing what's right",
      "Other / Something else"
    ],
    "category": "values",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_026",
    "question": "What matters more to me: security or adventure?",
    "options": [
      "Security—I value stability and predictability",
      "Adventure—I crave new experiences",
      "Mostly security with some adventure",
      "Mostly adventure with a foundation of security",
      "Other / It depends"
    ],
    "category": "values",
    "difficulty": 1,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_027",
    "question": "How important is family to me compared to other things?",
    "options": [
      "Family is my top priority above all else",
      "Very important, but I balance it with other things",
      "Important, but I also prioritize my own needs",
      "I define 'family' broadly—chosen family matters too",
      "Other / Something else"
    ],
    "category": "values",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_028",
    "question": "What role does spirituality or meaning play in my life?",
    "options": [
      "Very central—it guides my decisions",
      "Important but private—I don't talk about it much",
      "I'm still exploring what I believe",
      "Not very important—I focus on practical matters",
      "Other / Something else"
    ],
    "category": "values",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_029",
    "question": "What do I value most about our relationship?",
    "options": [
      "The emotional safety and trust",
      "The fun and joy we share",
      "The support and partnership",
      "The growth we inspire in each other",
      "Other / Something else"
    ],
    "category": "values",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_030",
    "question": "What makes me feel like my life has purpose?",
    "options": [
      "Contributing to something bigger than myself",
      "Nurturing relationships and being there for others",
      "Pursuing my passions and interests",
      "Growing and learning continuously",
      "Other / Something else"
    ],
    "category": "values",
    "difficulty": 3,
    "dimension": "feeling_known"
  }
]
```

---

### Theme 4: Emotional Needs (10 questions)
*"What does my partner need to feel loved and secure?"*

```json
[
  {
    "id": "conn_031",
    "question": "What makes me feel most loved?",
    "options": [
      "Words of affirmation and appreciation",
      "Physical affection and closeness",
      "Quality time and undivided attention",
      "Acts of service and thoughtful gestures",
      "Other / Something else"
    ],
    "category": "emotional_needs",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_032",
    "question": "What do I need after a hard day?",
    "options": [
      "Space to decompress alone first",
      "A hug and physical comfort",
      "Someone to listen and validate me",
      "Distraction—let's do something fun",
      "Other / Something else"
    ],
    "category": "emotional_needs",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_033",
    "question": "How do I prefer to receive comfort when I'm upset?",
    "options": [
      "Physical closeness—hold me",
      "Words of reassurance and support",
      "Problem-solving—help me fix it",
      "Just being present without saying much",
      "Other / Something else"
    ],
    "category": "emotional_needs",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_034",
    "question": "What makes me feel appreciated?",
    "options": [
      "Being told specifically what you value about me",
      "Small thoughtful gestures that show you're thinking of me",
      "Being asked for my opinion or input",
      "Having my efforts noticed without me pointing them out",
      "Other / Something else"
    ],
    "category": "emotional_needs",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_035",
    "question": "What do I need to feel connected to you?",
    "options": [
      "Regular quality time together",
      "Deep conversations about real things",
      "Physical affection throughout the day",
      "Knowing you're thinking of me when we're apart",
      "Other / Something else"
    ],
    "category": "emotional_needs",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_036",
    "question": "How do I know you're really listening to me?",
    "options": [
      "You put away distractions and make eye contact",
      "You ask follow-up questions",
      "You remember and bring it up later",
      "You respond with empathy, not solutions",
      "Other / Something else"
    ],
    "category": "emotional_needs",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_037",
    "question": "What makes me feel safe in our relationship?",
    "options": [
      "Consistency—knowing what to expect from you",
      "Openness—you share your thoughts and feelings",
      "Reassurance—you remind me you're committed",
      "Respect—you never belittle or dismiss me",
      "Other / Something else"
    ],
    "category": "emotional_needs",
    "difficulty": 3,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_038",
    "question": "What's the best way to cheer me up?",
    "options": [
      "Make me laugh or be silly together",
      "Plan something fun or spontaneous",
      "Give me affection and closeness",
      "Do something thoughtful without being asked",
      "Other / Something else"
    ],
    "category": "emotional_needs",
    "difficulty": 1,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_039",
    "question": "What do I need when I'm upset with you?",
    "options": [
      "Space to cool down before talking",
      "For you to acknowledge my feelings first",
      "To talk it through right away",
      "A gesture that shows you care, even mid-conflict",
      "Other / Something else"
    ],
    "category": "emotional_needs",
    "difficulty": 3,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_040",
    "question": "What makes me feel truly seen by you?",
    "options": [
      "When you notice small things about me",
      "When you understand how I'm feeling without me explaining",
      "When you remember things that matter to me",
      "When you accept all of me, even the hard parts",
      "Other / Something else"
    ],
    "category": "emotional_needs",
    "difficulty": 3,
    "dimension": "feeling_known"
  }
]
```

---

### Theme 5: History & Identity (10 questions)
*"What has shaped who my partner is?"*

```json
[
  {
    "id": "conn_041",
    "question": "What's a defining moment from my childhood?",
    "options": [
      "A family experience that shaped my values",
      "A challenge or hardship I overcame",
      "A moment of joy or achievement",
      "Something that changed how I see myself",
      "Other / Something else"
    ],
    "category": "history",
    "difficulty": 3,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_042",
    "question": "Who has influenced me most in life?",
    "options": [
      "A parent or family member",
      "A teacher, mentor, or coach",
      "A close friend",
      "Someone I admire from afar (author, leader, etc.)",
      "Other / Something else"
    ],
    "category": "history",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_043",
    "question": "What experience changed how I see the world?",
    "options": [
      "Traveling or living somewhere different",
      "A loss or difficult life event",
      "A relationship that taught me something",
      "An achievement or personal breakthrough",
      "Other / Something else"
    ],
    "category": "history",
    "difficulty": 3,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_044",
    "question": "What's my happiest memory from before we met?",
    "options": [
      "A childhood moment with family",
      "An adventure or trip",
      "An achievement I'm proud of",
      "A time with close friends",
      "Other / Something else"
    ],
    "category": "history",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_045",
    "question": "What challenge made me who I am today?",
    "options": [
      "Family difficulties growing up",
      "A personal failure or setback",
      "Health struggles (mine or someone close)",
      "A period of uncertainty or big change",
      "Other / Something else"
    ],
    "category": "history",
    "difficulty": 3,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_046",
    "question": "What do I wish more people understood about me?",
    "options": [
      "That I feel things more deeply than I show",
      "That my quietness isn't disinterest",
      "That I need more support than I ask for",
      "That my confidence isn't as solid as it seems",
      "Other / Something else"
    ],
    "category": "history",
    "difficulty": 3,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_047",
    "question": "What's something I rarely share but shapes who I am?",
    "options": [
      "An insecurity I carry",
      "A past experience that still affects me",
      "A dream I'm afraid to say out loud",
      "A part of my identity I keep private",
      "Other / Something else"
    ],
    "category": "history",
    "difficulty": 3,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_048",
    "question": "What would surprise people to learn about me?",
    "options": [
      "A hidden talent or interest",
      "Something from my past",
      "How I really feel inside",
      "A secret dream or ambition",
      "Other / Something else"
    ],
    "category": "history",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_049",
    "question": "What part of my identity am I most proud of?",
    "options": [
      "My resilience—I've overcome a lot",
      "My kindness—I care deeply about others",
      "My curiosity—I'm always learning",
      "My authenticity—I'm true to myself",
      "Other / Something else"
    ],
    "category": "history",
    "difficulty": 2,
    "dimension": "feeling_known"
  },
  {
    "id": "conn_050",
    "question": "What do I want you to always remember about me?",
    "options": [
      "How much I love you",
      "That I always tried my best",
      "The way we made each other laugh",
      "That you made my life better",
      "Other / Something else"
    ],
    "category": "history",
    "difficulty": 3,
    "dimension": "feeling_known"
  }
]
```

---

## 2. Affirmation: "Attachment" Branch (30 Questions / 6 Quizzes)

**Purpose:** Measure and strengthen the A.R.E. secure attachment bonds.

**Dimension mapping:** Maps to "Responsiveness"

### Quiz 1: "Are You There For Me?" (Accessibility)
*Can I reach you when I need you?*

| Statement | Dimension |
|-----------|-----------|
| My partner is emotionally available when I need them. | responsiveness |
| I don't have to compete for my partner's attention. | responsiveness |
| My partner makes time for me even when busy. | responsiveness |
| I can reach my partner when something is wrong. | responsiveness |
| My partner is present, not distracted, when we're together. | responsiveness |

### Quiz 2: "Can I Count On You?" (Responsiveness)
*Will you respond to my needs?*

| Statement | Dimension |
|-----------|-----------|
| My partner responds when I express a need. | responsiveness |
| My partner comforts me when I'm upset. | responsiveness |
| My partner takes my concerns seriously. | responsiveness |
| My partner adjusts when they see I'm struggling. | responsiveness |
| My partner's responses match what I actually need. | responsiveness |

### Quiz 3: "Do I Matter To You?" (Engagement)
*Am I special and prioritized?*

| Statement | Dimension |
|-----------|-----------|
| I feel valued and important to my partner. | responsiveness |
| My partner is genuinely interested in my inner world. | responsiveness |
| My partner prioritizes our relationship. | responsiveness |
| I feel special and chosen by my partner. | responsiveness |
| My partner invests in keeping our connection strong. | responsiveness |

### Quiz 4: "Safe Harbor" (Security)
*Can I be vulnerable with you?*

| Statement | Dimension |
|-----------|-----------|
| I feel safe sharing my fears with my partner. | responsiveness |
| My partner doesn't judge me when I'm struggling. | responsiveness |
| I can be my full self without fear of rejection. | responsiveness |
| My partner holds space for my difficult emotions. | responsiveness |
| I trust my partner with my vulnerabilities. | responsiveness |

### Quiz 5: "Turning Toward" (Bids for Connection)
*Do we respond to each other's small moments?*

| Statement | Dimension |
|-----------|-----------|
| When I share something, my partner engages with it. | responsiveness |
| My partner notices when I want attention. | responsiveness |
| We respond to each other's small bids for connection. | responsiveness |
| My partner puts down distractions when I need them. | responsiveness |
| We don't dismiss each other's small moments. | responsiveness |

### Quiz 6: "Still Choosing You" (Commitment)
*Do we both feel secure in our bond?*

| Statement | Dimension |
|-----------|-----------|
| I know my partner is committed to us. | responsiveness |
| Our bond feels stable and secure. | responsiveness |
| I don't question whether my partner wants to be with me. | responsiveness |
| We face challenges as a team. | responsiveness |
| I trust that we'll work through whatever comes. | responsiveness |

---

## 3. Affirmation: "Appreciation" Branch (30 Questions / 6 Quizzes)

**Purpose:** Strengthen fondness, admiration, and feeling valued.

**Dimension mapping:** Maps to "Appreciation"

### Quiz 1: "Seen & Valued"
*Do I feel truly appreciated?*

| Statement | Dimension |
|-----------|-----------|
| My partner notices the things I do for us. | appreciation |
| I feel appreciated for who I am, not just what I do. | appreciation |
| My partner expresses gratitude regularly. | appreciation |
| I know my partner values having me in their life. | appreciation |
| My partner sees my efforts, even the small ones. | appreciation |

### Quiz 2: "Words of Affirmation"
*Do we build each other up with words?*

| Statement | Dimension |
|-----------|-----------|
| My partner tells me things they love about me. | appreciation |
| I hear words of encouragement from my partner. | appreciation |
| My partner compliments me genuinely. | appreciation |
| We speak kindly to each other, even when frustrated. | appreciation |
| My partner's words make me feel good about myself. | appreciation |

### Quiz 3: "Acts of Love"
*Do our actions show appreciation?*

| Statement | Dimension |
|-----------|-----------|
| My partner does thoughtful things for me. | appreciation |
| I feel cared for through my partner's actions. | appreciation |
| My partner helps me in practical ways. | appreciation |
| We show love through what we do, not just what we say. | appreciation |
| My partner's actions match their words. | appreciation |

### Quiz 4: "Quality Presence"
*Do we give each other real attention?*

| Statement | Dimension |
|-----------|-----------|
| My partner gives me their full attention. | appreciation |
| We have meaningful time together regularly. | appreciation |
| My partner is truly present when we're together. | appreciation |
| I feel prioritized in my partner's life. | appreciation |
| We protect our time together from distractions. | appreciation |

### Quiz 5: "Admiration"
*Do we genuinely admire each other?*

| Statement | Dimension |
|-----------|-----------|
| I admire qualities in my partner. | appreciation |
| My partner respects the way I handle things. | appreciation |
| We speak positively about each other to others. | appreciation |
| I'm proud to be with my partner. | appreciation |
| My partner makes me feel like I'm good at what I do. | appreciation |

### Quiz 6: "Celebration"
*Do we celebrate each other?*

| Statement | Dimension |
|-----------|-----------|
| My partner celebrates my wins, big and small. | appreciation |
| We acknowledge each other's achievements. | appreciation |
| My partner gets genuinely excited for my success. | appreciation |
| We mark milestones and special moments together. | appreciation |
| My partner makes me feel like my wins matter. | appreciation |

---

## 4. You-or-Me: "Growth" Branch (30 Questions)

**Purpose:** Explore how partners contribute to each other's growth and the relationship's future.

**Dimension mapping:** Maps to "Shared Vision"

### Structure: 3 themes, 10 questions each

**Theme 1: Supporting Each Other's Growth (10 questions)**

| ID | Prompt | Content | Dimension |
|----|--------|---------|-----------|
| yom_growth_001 | Who tends to... | Encourage the other to try new things | shared_vision |
| yom_growth_002 | Who tends to... | Push us outside our comfort zone | shared_vision |
| yom_growth_003 | Who tends to... | Support the other's personal goals | shared_vision |
| yom_growth_004 | Who tends to... | Celebrate the other's growth | shared_vision |
| yom_growth_005 | Who tends to... | Give honest feedback, even when hard | shared_vision |
| yom_growth_006 | Who tends to... | Believe in the other's potential | shared_vision |
| yom_growth_007 | Who tends to... | Help the other see their blind spots | shared_vision |
| yom_growth_008 | Who tends to... | Make space for the other to change | shared_vision |
| yom_growth_009 | Who tends to... | Learn new things together | shared_vision |
| yom_growth_010 | Who tends to... | Inspire the other to be better | shared_vision |

**Theme 2: Building Our Future (10 questions)**

| ID | Prompt | Content | Dimension |
|----|--------|---------|-----------|
| yom_growth_011 | Who tends to... | Dream about our future together | shared_vision |
| yom_growth_012 | Who tends to... | Plan for the long-term | shared_vision |
| yom_growth_013 | Who tends to... | Start conversations about our goals | shared_vision |
| yom_growth_014 | Who tends to... | Keep us aligned on what we want | shared_vision |
| yom_growth_015 | Who tends to... | Make sacrifices for our shared future | shared_vision |
| yom_growth_016 | Who tends to... | Take initiative on shared goals | shared_vision |
| yom_growth_017 | Who tends to... | Keep us moving forward together | shared_vision |
| yom_growth_018 | Who tends to... | Balance individual and couple goals | shared_vision |
| yom_growth_019 | Who tends to... | Imagine us growing old together | shared_vision |
| yom_growth_020 | Who tends to... | Make our relationship a priority | shared_vision |

**Theme 3: Creating Meaning (10 questions)**

| ID | Prompt | Content | Dimension |
|----|--------|---------|-----------|
| yom_growth_021 | Who tends to... | Create traditions for us | shared_vision |
| yom_growth_022 | Who tends to... | Find deeper meaning in our relationship | shared_vision |
| yom_growth_023 | Who tends to... | Connect us to something bigger | shared_vision |
| yom_growth_024 | Who tends to... | Build rituals that matter | shared_vision |
| yom_growth_025 | Who tends to... | Remember what makes us special | shared_vision |
| yom_growth_026 | Who tends to... | Bring purpose to our everyday life | shared_vision |
| yom_growth_027 | Who tends to... | Celebrate what we've built | shared_vision |
| yom_growth_028 | Who tends to... | Keep our story alive | shared_vision |
| yom_growth_029 | Who tends to... | Make ordinary moments meaningful | shared_vision |
| yom_growth_030 | Who tends to... | Think about the legacy we're creating | shared_vision |

---

## 5. You-or-Me: "Repair" Branch (30 Questions)

**Purpose:** Explore how partners handle conflict, repair, and reconnection.

**Dimension mapping:** Maps to "Repair"

### Structure: 3 themes, 10 questions each

**Theme 1: During Conflict (10 questions)**

| ID | Prompt | Content | Dimension |
|----|--------|---------|-----------|
| yom_repair_001 | Who tends to... | Stay calm when things get heated | repair |
| yom_repair_002 | Who tends to... | Take a break before saying something hurtful | repair |
| yom_repair_003 | Who tends to... | Express hurt without attacking | repair |
| yom_repair_004 | Who tends to... | Listen even when upset | repair |
| yom_repair_005 | Who tends to... | Try to understand the other's perspective | repair |
| yom_repair_006 | Who tends to... | Name what's really bothering them | repair |
| yom_repair_007 | Who tends to... | Avoid the "silent treatment" | repair |
| yom_repair_008 | Who tends to... | Stick to the issue, not bring up old stuff | repair |
| yom_repair_009 | Who tends to... | Signal "I'm not going anywhere" during fights | repair |
| yom_repair_010 | Who tends to... | De-escalate with humor or tenderness | repair |

**Theme 2: Making Repair (10 questions)**

| ID | Prompt | Content | Dimension |
|----|--------|---------|-----------|
| yom_repair_011 | Who tends to... | Reach out first after a fight | repair |
| yom_repair_012 | Who tends to... | Say sorry and mean it | repair |
| yom_repair_013 | Who tends to... | Acknowledge their part in the problem | repair |
| yom_repair_014 | Who tends to... | Check in to make sure we're okay | repair |
| yom_repair_015 | Who tends to... | Offer a genuine repair gesture | repair |
| yom_repair_016 | Who tends to... | Accept the other's apology fully | repair |
| yom_repair_017 | Who tends to... | Let go without holding grudges | repair |
| yom_repair_018 | Who tends to... | Talk about what happened, not just move on | repair |
| yom_repair_019 | Who tends to... | Learn from disagreements | repair |
| yom_repair_020 | Who tends to... | Make changes after feedback | repair |

**Theme 3: Reconnection (10 questions)**

| ID | Prompt | Content | Dimension |
|----|--------|---------|-----------|
| yom_repair_021 | Who tends to... | Initiate physical reconnection after distance | repair |
| yom_repair_022 | Who tends to... | Say "I love you" first after tension | repair |
| yom_repair_023 | Who tends to... | Suggest doing something together after a hard time | repair |
| yom_repair_024 | Who tends to... | Remind us of what we have | repair |
| yom_repair_025 | Who tends to... | Bring us back to "normal" faster | repair |
| yom_repair_026 | Who tends to... | Make the other feel forgiven | repair |
| yom_repair_027 | Who tends to... | Reassure the other after an argument | repair |
| yom_repair_028 | Who tends to... | Create safety after rupture | repair |
| yom_repair_029 | Who tends to... | Keep perspective on what matters | repair |
| yom_repair_030 | Who tends to... | Strengthen us after we've struggled | repair |

---

## 6. Daily Deck Cards (60 Cards) — OPTIONAL / FUTURE RELEASE

> **Note:** This feature is optional for the initial launch. The therapeutic content in sections 1-5 can ship without the Daily Deck. This section is preserved for future reference.

**Purpose:** Daily micro-interactions that strengthen connection without requiring a full quiz.

**Structure:** 10 cards per dimension, rotates through all 5 dimensions

**UI Mockups:** See `/mockups/daily-deck-variant-*.html` for 6 design variants

### Feeling Known (10 cards)
| Card | Action |
|------|--------|
| 1 | Ask your partner: "What's weighing on you right now?" |
| 2 | Ask your partner: "What are you looking forward to?" |
| 3 | Share something you've never told your partner before. |
| 4 | Ask your partner: "What's one thing you wish I understood better about you?" |
| 5 | Ask your partner about a favorite childhood memory. |
| 6 | Share a dream you have for your future together. |
| 7 | Ask your partner: "What do you need from me this week?" |
| 8 | Tell your partner about something that shaped who you are. |
| 9 | Ask your partner: "What's something you used to love but haven't done in a while?" |
| 10 | Share one fear you have that your partner might not know about. |

### Appreciation (10 cards)
| Card | Action |
|------|--------|
| 1 | Tell your partner three things you appreciate about them. |
| 2 | Notice something your partner did today and thank them for it. |
| 3 | Send your partner a message about why you're grateful for them. |
| 4 | Tell your partner something you admire about how they handle things. |
| 5 | Share a memory of your partner that makes you smile. |
| 6 | Compliment your partner on something other than their appearance. |
| 7 | Tell your partner what you're proud of them for. |
| 8 | Share what you love about your partner's character. |
| 9 | Acknowledge an effort your partner made recently. |
| 10 | Tell your partner: "Something I love about us is..." |

### Responsiveness (10 cards)
| Card | Action |
|------|--------|
| 1 | When your partner shares something today, put down your phone and fully engage. |
| 2 | Ask your partner: "How can I support you today?" |
| 3 | Notice a bid for connection from your partner and turn toward it. |
| 4 | Give your partner your undivided attention for 10 minutes. |
| 5 | Ask your partner: "Is there anything you need from me that you haven't asked for?" |
| 6 | Check in with your partner about how they're really doing. |
| 7 | Respond to something your partner shares with a follow-up question. |
| 8 | Let your partner vent without trying to fix anything. |
| 9 | Notice your partner's mood and adjust accordingly. |
| 10 | Do something for your partner before they ask. |

### Repair (10 cards)
| Card | Action |
|------|--------|
| 1 | If there's any lingering tension, reach out first. |
| 2 | Apologize for something small you did recently. |
| 3 | Ask your partner: "Is there anything unresolved between us?" |
| 4 | Tell your partner: "I appreciate how we handled that disagreement." |
| 5 | Share what you've learned from a recent conflict. |
| 6 | Ask your partner: "What do you need from me after we argue?" |
| 7 | Acknowledge something your partner was right about. |
| 8 | Reassure your partner that you're committed, even when things are hard. |
| 9 | Discuss a conflict style you want to work on together. |
| 10 | Tell your partner: "I'm grateful we can work through hard things." |

### Shared Vision (10 cards)
| Card | Action |
|------|--------|
| 1 | Share a dream you have for your future together. |
| 2 | Ask your partner: "Where do you see us in 5 years?" |
| 3 | Discuss a tradition you'd like to start as a couple. |
| 4 | Talk about a value that's important to both of you. |
| 5 | Ask your partner: "What do you want our relationship to be known for?" |
| 6 | Plan something together, even if it's small. |
| 7 | Discuss one goal you want to accomplish as a team. |
| 8 | Ask your partner: "What makes our relationship unique?" |
| 9 | Share what you love about the life you're building together. |
| 10 | Talk about something meaningful you want to experience together. |

---

## Content Production Summary

### Total New Content for Launch: 170 Items

| Content Type | Branch/Deck | Questions | Dimension Mapped |
|--------------|-------------|-----------|------------------|
| Classic Quiz | connection | 50 | Feeling Known |
| Affirmation | attachment | 30 (6 quizzes) | Responsiveness |
| Affirmation | appreciation | 30 (6 quizzes) | Appreciation |
| You-or-Me | growth | 30 | Shared Vision |
| You-or-Me | repair | 30 | Repair |
| **TOTAL (Launch)** | | **170** | |
| *Daily Deck (Future)* | *all dimensions* | *60* | *All 5* |

### Dimension Coverage (Launch)

| Dimension | Classic Quiz | Affirmation | You-or-Me | Launch Total | *+Daily Deck* |
|-----------|--------------|-------------|-----------|--------------|---------------|
| Feeling Known | 50 | — | — | 50 | *+10* |
| Appreciation | — | 30 | — | 30 | *+10* |
| Responsiveness | — | 30 | — | 30 | *+10* |
| Repair | — | — | 30 | 30 | *+10* |
| Shared Vision | — | — | 30 | 30 | *+10* |
| **Total** | 50 | 60 | 60 | **170** | *+60* |

---

## Implementation Phases

### Phase 1: Content Creation (Content work only)
- [ ] Write all 50 Classic Quiz "connection" questions with answer options
- [ ] Write all 12 Affirmation quizzes (attachment + appreciation)
- [ ] Write all 60 You-or-Me questions (growth + repair)
- [ ] Review all content for therapeutic quality and tone

### Phase 2: Branch Integration (Code + content)
- [ ] Add "connection" to Classic Quiz branch rotation
- [ ] Add "attachment" and "appreciation" to Affirmation branch rotation
- [ ] Add "growth" and "repair" to You-or-Me branch rotation
- [ ] Update `branch_progression_state.dart` with new branches
- [ ] Create JSON files in proper folder structure

### Phase 3: Dimension Dashboard (Feature work — optional)
- [ ] Add `dimension` field to question data structures
- [ ] Build dimension scoring logic
- [ ] Create dashboard UI
- [ ] Implement "Strengthen This Area" recommendations

### Phase 4: Daily Deck Feature (Future — optional)
- [ ] Build Daily Deck UI (see mockups in `/mockups/daily-deck-variant-*.html`)
- [ ] Implement card rotation logic
- [ ] Add partner completion tracking
- [ ] Create notification reminders

---

## Content Cadence Strategy

### Guiding Principle: Mix from Day 1

Therapeutic content is the **core value prop**, not a premium upsell or unlock. Couples should experience meaningful depth within their first 2-3 days to understand why the app is worth using.

**Approach:** Interleave casual and therapeutic branches in the normal rotation. No gating, no skipping.

---

### Branch Rotation (Updated)

| Quiz Type | Branches (in rotation order) | Type |
|-----------|------------------------------|------|
| **Classic Quiz** | lighthearted | Casual |
| | connection | **Therapeutic** |
| | deeper | Casual |
| | spicy | Casual |
| **Affirmation** | emotional | Casual |
| | attachment | **Therapeutic** |
| | practical | Casual |
| | appreciation | **Therapeutic** |
| | spiritual | Casual |
| **You-or-Me** | playful | Casual |
| | growth | **Therapeutic** |
| | reflective | Casual |
| | repair | **Therapeutic** |
| | intimate | Casual |

**Result:** ~40% of quests are therapeutic. A couple doing daily quests hits therapeutic content by day 2-3.

---

### UI Differentiation: Casual vs Therapeutic

Therapeutic quests should be **visually distinct** so couples know they're entering a different mode.

#### Visual Markers (Quest Card)

| Element | Casual | Therapeutic |
|---------|--------|-------------|
| **Card border** | Standard (1px black) | Thicker or double border |
| **Badge/label** | None or "Fun" | "Deeper" or "Connection" badge |
| **Color accent** | Neutral/playful | Warmer tone (gold, deep blue, etc.) |
| **Icon** | Standard quest icon | Heart, connection, or depth icon |

#### Example Quest Card States

**Casual Quest:**
```
┌─────────────────────────────────────┐
│  [🎯 Image]                         │
│                                     │
│  Lighthearted Quiz                  │
│  "Test how well you know each other"│
│                                     │
│  [Your Turn]              +30 LP    │
└─────────────────────────────────────┘
```

**Therapeutic Quest:**
```
┌─────────────────────────────────────┐
│ ┌─────────────────────────────────┐ │
│ │  [💫 Image]                     │ │
│ │                                 │ │
│ │  Connection Quiz      [DEEPER]  │ │
│ │  "Discover your partner's       │ │
│ │   inner world"                  │ │
│ │                                 │ │
│ │  [Your Turn]            +30 LP  │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
  ↑ Double border or accent color
```

#### First Therapeutic Quest: Intro Screen

When a couple encounters their **first** therapeutic quest, show a brief framing screen:

```
┌─────────────────────────────────────┐
│                                     │
│           💫                        │
│                                     │
│    This quest goes deeper.          │
│                                     │
│    These questions help you         │
│    truly understand each other—     │
│    your dreams, fears, and what     │
│    makes you feel loved.            │
│                                     │
│    Take your time. Be honest.       │
│                                     │
│        [ Let's Begin ]              │
│                                     │
└─────────────────────────────────────┘
```

This intro only shows **once per quest type** (first Connection quiz, first Attachment affirmation, etc.), not every time.

---

### No Skipping

Therapeutic quests are part of the rotation and cannot be skipped. This ensures:
- All couples experience the core value
- No "I'll do the easy one" avoidance pattern
- Therapeutic content is normalized, not optional

---

### Cadence Summary

| Day | Quest Type Example | Mode |
|-----|-------------------|------|
| 1 | Lighthearted Quiz | Casual |
| 2 | Connection Quiz | **Therapeutic** (first intro shown) |
| 3 | Playful You-or-Me | Casual |
| 4 | Attachment Affirmation | **Therapeutic** |
| 5 | Deeper Quiz | Casual |
| 6 | Growth You-or-Me | **Therapeutic** |
| 7 | Emotional Affirmation | Casual |
| ... | Rotation continues | ~40% therapeutic |

---

## Questions To Consider — RESOLVED

All questions have been addressed:

1. ~~**Answer options for Connection branch**~~ — ✅ **DONE**: Full 5-option multi-choice created for all 50 questions (see Theme 1-5 JSON above)

2. ~~**Brand differentiation**~~ — ✅ **DECIDED**: No HolyCouples work for now. Build TogetherRemind therapeutic content first.

3. ~~**Therapeutic badge wording**~~ — ✅ **CONFIRMED**: Current wording is fine.

---

### 3.2 Relationship Dimensions Dashboard

**What:** Track couple's scores over time on key relationship health dimensions.

**Dimensions to Track:**
1. **Feeling Known** (from Love Maps questions)
2. **Appreciation** (from Fondness & Admiration)
3. **Responsiveness** (from A.R.E. quizzes)
4. **Repair Confidence** (from Conflict/Repair quizzes)
5. **Shared Vision** (from Meaning quizzes)

**Data Model:**
```typescript
interface RelationshipDimension {
  dimension: 'known' | 'appreciation' | 'responsiveness' | 'repair' | 'vision';
  score: number; // 1-5 average
  trend: 'improving' | 'stable' | 'declining';
  lastUpdated: Date;
  history: { date: Date; score: number }[];
}
```

**UI:**
- Simple radar chart or bar graph showing current scores
- Trend indicators (up/down arrows)
- "Strengthen This Area" button linking to relevant quizzes

---

### 3.3 "Gottman Card Deck" Daily Feature

**What:** Daily micro-interaction based on Gottman's card deck categories.

**Categories:**
1. **Love Maps** — "Ask your partner about their current biggest stress"
2. **Fondness & Admiration** — "Tell your partner three things you appreciate about them"
3. **Turning Toward** — "When your partner shares something today, put down your phone and respond fully"
4. **Stress-Reducing Conversation** — "Spend 20 minutes discussing your day without problem-solving"
5. **Dreams Within Conflict** — "Share a dream you have that relates to an ongoing disagreement"
6. **Creating Shared Meaning** — "Discuss a ritual or tradition you'd like to start"

**Implementation:**
- One card per day, rotating through categories
- Partner can mark complete and add a note
- Both partners see when the other has completed

---

### 3.4 "Our Story" Narrative Feature

**What:** Help couples create and reflect on their relationship narrative.

**Components:**
1. **How We Met** — Guided questions about origin story
2. **Key Moments** — Timeline of significant relationship events
3. **Challenges Overcome** — Difficulties that made them stronger
4. **What Makes Us Special** — Unique qualities of their relationship
5. **Our Future** — Shared vision and dreams

**Therapeutic Purpose:**
Gottman research shows that couples who tell a positive story about their relationship ("We've been through hard times but always come out stronger") have better outcomes than those with negative narratives ("Things have been hard and we keep struggling").

---

## Appendix A: Full Love Maps Question Set (50 Questions)

### Dreams & Aspirations (10)
1. What's my biggest unfulfilled dream?
2. What career path would I pursue if money didn't matter?
3. Where do I dream of living someday?
4. What experience do I most want to have before I die?
5. What creative pursuit do I wish I had time for?
6. What achievement would make me feel truly proud?
7. What kind of impact do I want to have on the world?
8. What adventure am I too scared to pursue?
9. What does my ideal life look like in 20 years?
10. What dream have I given up on that I secretly still think about?

### Fears & Worries (10)
11. What's my biggest fear about our relationship?
12. What insecurity do I struggle with most?
13. What from my past still haunts me?
14. What do I worry about that I rarely share?
15. What's my biggest fear about the future?
16. What fear holds me back from being fully myself?
17. What am I afraid others will discover about me?
18. What situation triggers my deepest anxiety?
19. What loss would be hardest for me to bear?
20. What vulnerability am I most protective of?

### Formative Experiences (10)
21. What childhood experience shaped who I am most?
22. What was my biggest heartbreak before you?
23. What family dynamic still affects me today?
24. What teacher or mentor influenced me most?
25. What failure taught me the most important lesson?
26. What success am I most proud of from my past?
27. What friendship shaped my understanding of loyalty?
28. What was the hardest year of my life before we met?
29. What did I learn from my parents' relationship?
30. What experience made me who I am in relationships?

### Current Stressors (10)
31. What's weighing on me most right now?
32. What work situation is stressing me out?
33. What health concern do I worry about privately?
34. What family issue is draining my energy?
35. What financial worry keeps me up at night?
36. What friendship is causing me stress?
37. What am I avoiding dealing with?
38. What deadline or obligation feels overwhelming?
39. What aspect of our life together stresses me most?
40. What do I need support with that I haven't asked for?

### Sources of Joy (10)
41. What simple pleasure makes me unexpectedly happy?
42. What type of day is my ideal day?
43. What environment makes me feel most alive?
44. What activity helps me feel like myself again?
45. What small ritual brings me comfort?
46. What makes me laugh no matter what?
47. What sensory experience do I love (smell, taste, touch)?
48. What type of connection fills me up?
49. What hobby or pastime do I wish I did more?
50. What moment with you stands out as pure joy?

---

## Appendix B: Implementation Checklist

### Phase 1 Checklist
- [ ] Add `followUp` field to 50 Classic Quiz questions
- [ ] Rewrite 10 problematic You-or-Me questions
- [ ] Add "Turning Toward" affirmation quiz
- [ ] Add "Navigating Hard Moments" affirmation quiz
- [ ] Rewrite 15 existing affirmation questions
- [ ] Test all updated questions in both brands
- [ ] Update HolyCouples files to match (where appropriate)

### Phase 2 Checklist
- [ ] Create Love Maps Classic Quiz branch (50 questions)
- [ ] Create Appreciation Deck game mode
- [ ] Rewrite Intimate You-or-Me with vulnerability focus
- [ ] Create Attachment-focused affirmation quizzes (5 quizzes)
- [ ] UI updates for new question formats
- [ ] Test new content in both brands

### Phase 3 Checklist
- [ ] Implement post-quiz discussion prompts
- [ ] Build Relationship Dimensions dashboard
- [ ] Create Gottman Card Deck daily feature
- [ ] Build "Our Story" narrative feature
- [ ] Data persistence for tracking over time
- [ ] Analytics for measuring engagement

---

## Appendix C: Complete Question Rewrites (Ready to Use)

This appendix contains production-ready JSON for all three question types, rewritten with therapeutic principles applied.

---

### C.1 Classic Quiz: Therapeutically Improved Questions

**The Problem:** Current questions are trivia-focused ("What's my favorite X?")
**The Solution:** Ask about meaning, feelings, and the "why" behind preferences

**Transformation Pattern:**
| Trivia Question | Therapeutic Question |
|-----------------|---------------------|
| What is the thing? | What does the thing mean to me? |
| What do I prefer? | Why do I prefer it / what need does it meet? |
| What's my favorite X? | What does X reveal about my inner world? |
| What do I like? | When do I feel [positive emotion] with you? |
| What's my habit? | What does my habit say about how I cope/connect? |

**15 Therapeutically Improved Classic Quiz Questions (JSON):**

```json
[
  {
    "id": "q_deep_001",
    "question": "What does my comfort food represent to me?",
    "options": [
      "Nostalgia and childhood memories",
      "A treat I use to celebrate myself",
      "Something that soothes me when stressed",
      "A taste that became part of my identity",
      "Other / Something else"
    ],
    "category": "inner_world",
    "difficulty": 2,
    "tier": 1
  },
  {
    "id": "q_deep_002",
    "question": "What do I value most about holiday celebrations?",
    "options": [
      "Being surrounded by family and loved ones",
      "Traditions and rituals that repeat each year",
      "A break from normal life to recharge",
      "The chance to give and receive thoughtfully",
      "Other / Something else"
    ],
    "category": "values",
    "difficulty": 2,
    "tier": 1
  },
  {
    "id": "q_deep_003",
    "question": "What does my morning routine say about how I face the world?",
    "options": [
      "I need quiet time alone before engaging",
      "I jump straight into action and productivity",
      "I ease in slowly — don't rush me",
      "Mornings are for connection with you",
      "Other / Something else"
    ],
    "category": "daily_rhythms",
    "difficulty": 1,
    "tier": 1
  },
  {
    "id": "q_deep_004",
    "question": "What do I most want to feel on our ideal vacation together?",
    "options": [
      "Completely relaxed and unplugged",
      "Adventurous and discovering new things",
      "Romantic and focused on just us",
      "Culturally enriched and inspired",
      "Other / Something else"
    ],
    "category": "dreams",
    "difficulty": 1,
    "tier": 1
  },
  {
    "id": "q_deep_005",
    "question": "When do I feel most loved by you specifically?",
    "options": [
      "When you tell me what you appreciate about me",
      "When you give me your undivided attention",
      "When you reach out to touch or hold me",
      "When you do something thoughtful unprompted",
      "Other / Something else"
    ],
    "category": "connection",
    "difficulty": 2,
    "tier": 1
  },
  {
    "id": "q_deep_006",
    "question": "What kind of support helps me most when I'm stressed?",
    "options": [
      "Just listen without trying to fix it",
      "Help me think through solutions",
      "Distract me and make me laugh",
      "Take something off my plate",
      "Other / Something else"
    ],
    "category": "emotional_needs",
    "difficulty": 2,
    "tier": 1
  },
  {
    "id": "q_deep_007",
    "question": "What does a perfect lazy day with you look like for me?",
    "options": [
      "Cuddled up watching something together",
      "Doing our own things in the same space",
      "Cooking and eating good food slowly",
      "No plans — just see where the day takes us",
      "Other / Something else"
    ],
    "category": "connection",
    "difficulty": 1,
    "tier": 1
  },
  {
    "id": "q_deep_008",
    "question": "What triggers me to feel disconnected from you?",
    "options": [
      "When you seem distracted or on your phone",
      "When we haven't had quality time together",
      "When conflict goes unresolved",
      "When I feel like an afterthought in your day",
      "Other / Something else"
    ],
    "category": "attachment",
    "difficulty": 3,
    "tier": 2
  },
  {
    "id": "q_deep_009",
    "question": "What do I need most after we've had a disagreement?",
    "options": [
      "Some space to cool down first",
      "To talk it through right away",
      "Physical reconnection (a hug, touch)",
      "A clear acknowledgment that we're okay",
      "Other / Something else"
    ],
    "category": "repair",
    "difficulty": 2,
    "tier": 1
  },
  {
    "id": "q_deep_010",
    "question": "What childhood experience still shapes how I love?",
    "options": [
      "How affection was (or wasn't) shown at home",
      "How my parents handled conflict",
      "Feeling like I had to earn love or approval",
      "A loss or disappointment I'm still healing from",
      "Other / Something else"
    ],
    "category": "formative",
    "difficulty": 3,
    "tier": 2
  },
  {
    "id": "q_deep_011",
    "question": "What fear do I carry about our future together?",
    "options": [
      "That we'll grow apart over time",
      "That life will get too busy for us",
      "That I'll disappoint you somehow",
      "That something outside our control will separate us",
      "Other / Something else"
    ],
    "category": "fears",
    "difficulty": 3,
    "tier": 2
  },
  {
    "id": "q_deep_012",
    "question": "What makes me feel most appreciated by you?",
    "options": [
      "When you notice the effort I put into things",
      "When you brag about me to others",
      "When you thank me for small everyday things",
      "When you show you don't take me for granted",
      "Other / Something else"
    ],
    "category": "appreciation",
    "difficulty": 2,
    "tier": 1
  },
  {
    "id": "q_deep_013",
    "question": "What's my biggest unspoken need in our relationship?",
    "options": [
      "More quality time without distractions",
      "More verbal affirmation and reassurance",
      "More physical affection and closeness",
      "More support for my personal goals",
      "Other / Something else"
    ],
    "category": "needs",
    "difficulty": 3,
    "tier": 2
  },
  {
    "id": "q_deep_014",
    "question": "What moment with you made me feel most truly seen?",
    "options": [
      "When you remembered something small that mattered to me",
      "When you understood what I needed without me saying it",
      "When you stood up for me or defended me",
      "When you celebrated my success as if it were yours",
      "Other / Something else"
    ],
    "category": "connection",
    "difficulty": 2,
    "tier": 1
  },
  {
    "id": "q_deep_015",
    "question": "What does 'home' feel like to me when I'm with you?",
    "options": [
      "Safe — I can let my guard down completely",
      "Warm — I feel accepted and cared for",
      "Fun — we laugh and enjoy each other",
      "Grounded — I know where I belong",
      "Other / Something else"
    ],
    "category": "attachment",
    "difficulty": 2,
    "tier": 1
  }
]
```

---

### C.2 You-or-Me: Complete Rewrite (All 3 Branches)

**The Problem:** Competitive framing ("Who's better/more X?") triggers defensiveness
**The Solution:** Shift to behavioral observations and neutral/appreciative framing

**Transformation Pattern:**
| Problematic Framing | Therapeutic Reframe |
|---------------------|---------------------|
| "Who's more [trait]?" | "Who tends to [behavior]?" |
| "Who's better at X?" | "Who usually takes the lead on X?" |
| "Who's the [superlative]?" | "Who brings more [contribution]?" |
| "Who would [negative]?" | "Who needs more [valid need]?" |
| Trait labels (emotional, disorganized) | Observable behaviors (shows feelings openly, needs reminders) |
| Judgments (better, worse) | Observations (tends to, usually, more likely to) |

#### C.2.1 Playful Branch (30 Questions)

```json
{
  "questions": [
    {
      "id": "yom_p001",
      "prompt": "Who tends to...",
      "content": "Come up with creative solutions to problems",
      "category": "personality"
    },
    {
      "id": "yom_p002",
      "prompt": "Who tends to...",
      "content": "Notice when things are out of place",
      "category": "personality"
    },
    {
      "id": "yom_p003",
      "prompt": "Who's more likely to...",
      "content": "Suggest a last-minute change of plans",
      "category": "personality"
    },
    {
      "id": "yom_p004",
      "prompt": "When we're at a party, who...",
      "content": "Is ready to head home first",
      "category": "personality"
    },
    {
      "id": "yom_p005",
      "prompt": "Who tends to...",
      "content": "Dream big about the future",
      "category": "personality"
    },
    {
      "id": "yom_p006",
      "prompt": "Who's more likely to...",
      "content": "Take a deep breath before reacting",
      "category": "personality"
    },
    {
      "id": "yom_p007",
      "prompt": "Who brings more...",
      "content": "Silliness and laughter to our daily life",
      "category": "personality"
    },
    {
      "id": "yom_p008",
      "prompt": "Who tends to...",
      "content": "Plan romantic gestures",
      "category": "personality"
    },
    {
      "id": "yom_p009",
      "prompt": "When making decisions, who...",
      "content": "Thinks through the practical details first",
      "category": "personality"
    },
    {
      "id": "yom_p010",
      "prompt": "Who's more likely to...",
      "content": "See the bright side of a tough situation",
      "category": "personality"
    },
    {
      "id": "yom_p011",
      "prompt": "Who tends to...",
      "content": "Suggest trying something new",
      "category": "personality"
    },
    {
      "id": "yom_p012",
      "prompt": "Who's more likely to...",
      "content": "Research something thoroughly before deciding",
      "category": "personality"
    },
    {
      "id": "yom_p013",
      "prompt": "Who needs more...",
      "content": "Time to process feelings before discussing them",
      "category": "personality"
    },
    {
      "id": "yom_p014",
      "prompt": "In conversations, who...",
      "content": "Usually has more to say",
      "category": "personality"
    },
    {
      "id": "yom_p015",
      "prompt": "When playing games, who...",
      "content": "Gets more invested in winning",
      "category": "personality"
    },
    {
      "id": "yom_p016",
      "prompt": "Who usually...",
      "content": "Takes the lead on planning our dates",
      "category": "actions"
    },
    {
      "id": "yom_p017",
      "prompt": "Who's more likely to...",
      "content": "Be found in the kitchen cooking",
      "category": "actions"
    },
    {
      "id": "yom_p018",
      "prompt": "On weekends, who...",
      "content": "Is up and moving first",
      "category": "actions"
    },
    {
      "id": "yom_p019",
      "prompt": "After a disagreement, who...",
      "content": "Reaches out to reconnect first",
      "category": "actions"
    },
    {
      "id": "yom_p020",
      "prompt": "At trivia night, who...",
      "content": "Gets excited to answer first",
      "category": "actions"
    },
    {
      "id": "yom_p021",
      "prompt": "Who's more likely to...",
      "content": "Book a spontaneous trip",
      "category": "actions"
    },
    {
      "id": "yom_p022",
      "prompt": "On movie night, who...",
      "content": "Usually picks what we watch",
      "category": "actions"
    },
    {
      "id": "yom_p023",
      "prompt": "Who tends to...",
      "content": "Remember the little dates and details",
      "category": "actions"
    },
    {
      "id": "yom_p024",
      "prompt": "In the morning, who...",
      "content": "Makes the bed (if anyone does)",
      "category": "actions"
    },
    {
      "id": "yom_p025",
      "prompt": "Around the house, who...",
      "content": "Takes care of the living things (plants, pets)",
      "category": "actions"
    },
    {
      "id": "yom_p026",
      "prompt": "When there's a bug, who...",
      "content": "Is called in to handle it",
      "category": "actions"
    },
    {
      "id": "yom_p027",
      "prompt": "On road trips, who...",
      "content": "Takes charge of navigation",
      "category": "actions"
    },
    {
      "id": "yom_p028",
      "prompt": "At night, who...",
      "content": "Wants to keep talking when we should sleep",
      "category": "actions"
    },
    {
      "id": "yom_p029",
      "prompt": "In the morning, who...",
      "content": "Sends the first 'thinking of you' message",
      "category": "actions"
    },
    {
      "id": "yom_p030",
      "prompt": "When we're hungry, who...",
      "content": "Usually decides where we're eating",
      "category": "actions"
    }
  ]
}
```

#### C.2.2 Reflective Branch (30 Questions)

```json
{
  "questions": [
    {
      "id": "yom_r001",
      "prompt": "Who's more likely to...",
      "content": "Turn an ordinary day into an adventure",
      "category": "scenarios"
    },
    {
      "id": "yom_r002",
      "prompt": "Who relies more on...",
      "content": "Reminders and calendars for important dates",
      "category": "scenarios"
    },
    {
      "id": "yom_r003",
      "prompt": "During a movie, who...",
      "content": "Dozes off on the couch first",
      "category": "scenarios"
    },
    {
      "id": "yom_r004",
      "prompt": "Who's more likely to...",
      "content": "Pick up a new hobby or interest",
      "category": "scenarios"
    },
    {
      "id": "yom_r005",
      "prompt": "On a road trip, who...",
      "content": "Would get us happily lost exploring",
      "category": "scenarios"
    },
    {
      "id": "yom_r006",
      "prompt": "During sad movies, who...",
      "content": "Tears up first",
      "category": "scenarios"
    },
    {
      "id": "yom_r007",
      "prompt": "Who tends to...",
      "content": "Get absorbed in their phone for longer stretches",
      "category": "scenarios"
    },
    {
      "id": "yom_r008",
      "prompt": "When shopping, who...",
      "content": "Is more likely to buy something unplanned",
      "category": "scenarios"
    },
    {
      "id": "yom_r009",
      "prompt": "In the shower, who...",
      "content": "Puts on a concert performance",
      "category": "scenarios"
    },
    {
      "id": "yom_r010",
      "prompt": "Who's more likely to...",
      "content": "Check what the stars say about our day",
      "category": "scenarios"
    },
    {
      "id": "yom_r011",
      "prompt": "On a Friday night, who...",
      "content": "Would rather stay in and recharge",
      "category": "scenarios"
    },
    {
      "id": "yom_r012",
      "prompt": "At a new restaurant, who...",
      "content": "Orders something they've never tried",
      "category": "scenarios"
    },
    {
      "id": "yom_r013",
      "prompt": "In a debate, who...",
      "content": "Is more persistent about their point",
      "category": "scenarios"
    },
    {
      "id": "yom_r014",
      "prompt": "Who's more likely to...",
      "content": "Remember lyrics to songs from years ago",
      "category": "scenarios"
    },
    {
      "id": "yom_r015",
      "prompt": "On vacation, who...",
      "content": "Takes a hundred photos to remember it",
      "category": "scenarios"
    },
    {
      "id": "yom_r016",
      "prompt": "On the dance floor, who...",
      "content": "Pulls the other one out to join them",
      "category": "comparative"
    },
    {
      "id": "yom_r017",
      "prompt": "In the kitchen, who...",
      "content": "Is more adventurous with recipes",
      "category": "comparative"
    },
    {
      "id": "yom_r018",
      "prompt": "Who brings more...",
      "content": "Laughter to our everyday moments",
      "category": "comparative"
    },
    {
      "id": "yom_r019",
      "prompt": "When one of us is venting, who...",
      "content": "Is usually the one holding space",
      "category": "comparative"
    },
    {
      "id": "yom_r020",
      "prompt": "Who tends to...",
      "content": "Keep up with what's in style",
      "category": "comparative"
    },
    {
      "id": "yom_r021",
      "prompt": "Who's usually...",
      "content": "Awake and ready earlier in the day",
      "category": "comparative"
    },
    {
      "id": "yom_r022",
      "prompt": "Who tends to...",
      "content": "Come alive when the sun goes down",
      "category": "comparative"
    },
    {
      "id": "yom_r023",
      "prompt": "Who's more comfortable...",
      "content": "Figuring out new technology",
      "category": "comparative"
    },
    {
      "id": "yom_r024",
      "prompt": "Who's more likely to...",
      "content": "Suggest we go for a run or workout",
      "category": "comparative"
    },
    {
      "id": "yom_r025",
      "prompt": "When someone needs advice, who...",
      "content": "Do they usually come to",
      "category": "comparative"
    },
    {
      "id": "yom_r026",
      "prompt": "Behind the wheel, who...",
      "content": "Is more relaxed and confident",
      "category": "comparative"
    },
    {
      "id": "yom_r027",
      "prompt": "Who's more passionate about...",
      "content": "The music we listen to",
      "category": "comparative"
    },
    {
      "id": "yom_r028",
      "prompt": "Who tends to...",
      "content": "Express themselves through creative outlets",
      "category": "comparative"
    },
    {
      "id": "yom_r029",
      "prompt": "When told a secret, who...",
      "content": "Is the vault that never leaks",
      "category": "comparative"
    },
    {
      "id": "yom_r030",
      "prompt": "When it's time for gifts, who...",
      "content": "Puts more thought into finding the perfect one",
      "category": "comparative"
    }
  ]
}
```

#### C.2.3 Intimate Branch (30 Questions)

```json
{
  "questions": [
    {
      "id": "yom_i001",
      "prompt": "When it's late at night, who...",
      "content": "Starts the deep conversations",
      "category": "connection"
    },
    {
      "id": "yom_i002",
      "prompt": "After an argument, who...",
      "content": "Needs more reassurance that we're okay",
      "category": "connection"
    },
    {
      "id": "yom_i003",
      "prompt": "During emotional moments, who...",
      "content": "Shows their feelings more openly",
      "category": "connection"
    },
    {
      "id": "yom_i004",
      "prompt": "In our relationship, who...",
      "content": "Takes the first step into vulnerability",
      "category": "connection"
    },
    {
      "id": "yom_i005",
      "prompt": "On any given day, who...",
      "content": "Says 'I love you' more often",
      "category": "connection"
    },
    {
      "id": "yom_i006",
      "prompt": "After time apart, who...",
      "content": "Reaches out first to reconnect",
      "category": "connection"
    },
    {
      "id": "yom_i007",
      "prompt": "When something's bothering us, who...",
      "content": "Prefers to talk it through rather than let it pass",
      "category": "connection"
    },
    {
      "id": "yom_i008",
      "prompt": "When there's tension, who...",
      "content": "Asks 'are we okay?' first",
      "category": "connection"
    },
    {
      "id": "yom_i009",
      "prompt": "Who tends to...",
      "content": "Remember the small things that matter to the other",
      "category": "connection"
    },
    {
      "id": "yom_i010",
      "prompt": "Who's more likely to...",
      "content": "Plan a surprise that shows they were really listening",
      "category": "connection"
    },
    {
      "id": "yom_i011",
      "prompt": "When we're together, who...",
      "content": "Is quicker to put their phone away",
      "category": "presence"
    },
    {
      "id": "yom_i012",
      "prompt": "Who tends to...",
      "content": "Notice when the other is having a hard day",
      "category": "presence"
    },
    {
      "id": "yom_i013",
      "prompt": "After we've hurt each other, who...",
      "content": "Apologizes first even if not fully at fault",
      "category": "repair"
    },
    {
      "id": "yom_i014",
      "prompt": "Who's more likely to...",
      "content": "Want to stay up late just talking about life",
      "category": "presence"
    },
    {
      "id": "yom_i015",
      "prompt": "Who tends to...",
      "content": "Express love through heartfelt words or notes",
      "category": "expression"
    },
    {
      "id": "yom_i016",
      "prompt": "Who finds it easier to...",
      "content": "Put feelings into words",
      "category": "expression"
    },
    {
      "id": "yom_i017",
      "prompt": "Who craves more...",
      "content": "Physical closeness and affection",
      "category": "needs"
    },
    {
      "id": "yom_i018",
      "prompt": "In conversations, who...",
      "content": "Is usually the one listening and holding space",
      "category": "expression"
    },
    {
      "id": "yom_i019",
      "prompt": "Who experiences love more through...",
      "content": "Words that are spoken",
      "category": "love_language"
    },
    {
      "id": "yom_i020",
      "prompt": "Who experiences love more through...",
      "content": "Actions and gestures",
      "category": "love_language"
    },
    {
      "id": "yom_i021",
      "prompt": "At heart, who is...",
      "content": "The bigger romantic",
      "category": "expression"
    },
    {
      "id": "yom_i022",
      "prompt": "Who feels more...",
      "content": "Protective of what we have together",
      "category": "attachment"
    },
    {
      "id": "yom_i023",
      "prompt": "Who needs more...",
      "content": "Reassurance that we're solid",
      "category": "attachment"
    },
    {
      "id": "yom_i024",
      "prompt": "During hard times, who...",
      "content": "Is the steadier source of comfort",
      "category": "support"
    },
    {
      "id": "yom_i025",
      "prompt": "Over time, who...",
      "content": "Falls more deeply in love",
      "category": "attachment"
    },
    {
      "id": "yom_i026",
      "prompt": "Who holds onto...",
      "content": "Memories and mementos from our journey",
      "category": "meaning"
    },
    {
      "id": "yom_i027",
      "prompt": "Who shows devotion through...",
      "content": "Quiet, everyday acts of care",
      "category": "expression"
    },
    {
      "id": "yom_i028",
      "prompt": "Who spends more time...",
      "content": "Dreaming about our future together",
      "category": "meaning"
    },
    {
      "id": "yom_i029",
      "prompt": "Who tends to be...",
      "content": "More in touch with their own feelings",
      "category": "expression"
    },
    {
      "id": "yom_i030",
      "prompt": "In their own way, who...",
      "content": "Makes the other feel most loved",
      "category": "expression"
    }
  ]
}
```

---

### C.3 Affirmation Quizzes: Complete Rewrite (All 3 Branches)

**The Problem:** Current affirmations are generic and surface-level
**The Solution:** Make them specific, behavioral, and vulnerability-inviting

**Transformation Pattern:**
| Generic Affirmation | Therapeutic Affirmation |
|---------------------|------------------------|
| "We have fun together" | "My partner's laughter makes me feel connected to them" |
| "I feel comfortable" | "I can show my messy, imperfect parts and still feel loved" |
| "We support each other" | "My partner believes in dreams I sometimes doubt myself" |
| Vague positive statement | Specific feeling + specific behavior |
| About "us" in general | About "my partner" doing something specific |

#### C.3.1 Emotional Branch (6 Quizzes, 30 Questions)

```json
{
  "quizzes": [
    {
      "id": "emotional_safety",
      "name": "Feeling Safe",
      "category": "safety",
      "difficulty": 1,
      "formatType": "affirmation",
      "imagePath": "assets/images/quests/feel-good-foundations.png",
      "description": "How safe do you feel being yourself?",
      "questions": [
        {
          "question": "I can show my partner my messy, imperfect parts and still feel loved.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "When I'm struggling, I don't have to hide it from my partner.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "I can admit when I'm wrong without fear of being judged.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "My partner makes me feel safe, not just physically but emotionally.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "I don't have to perform or pretend to earn my partner's love.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        }
      ]
    },
    {
      "id": "feeling_known",
      "name": "Feeling Known",
      "category": "connection",
      "difficulty": 1,
      "formatType": "affirmation",
      "imagePath": "assets/images/quests/feel-good-foundations.png",
      "description": "How well does your partner know your inner world?",
      "questions": [
        {
          "question": "My partner knows what keeps me up at night.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "My partner understands what I need even when I can't articulate it.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "My partner remembers the small things that matter to me.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "My partner 'gets' me in ways others don't.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "I'm still curious about my partner's inner world.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        }
      ]
    },
    {
      "id": "turning_toward",
      "name": "Turning Toward",
      "category": "connection",
      "difficulty": 1,
      "formatType": "affirmation",
      "imagePath": "assets/images/quests/feel-good-foundations.png",
      "description": "How do you respond to each other's bids for connection?",
      "questions": [
        {
          "question": "When I reach out to share something, my partner responds with interest.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "My partner notices when something is bothering me, even if I don't say anything.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We have small daily rituals that keep us connected.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "When something good happens, my partner is the first person I want to tell.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "I feel like a priority in my partner's life, not an afterthought.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        }
      ]
    },
    {
      "id": "appreciation",
      "name": "Feeling Appreciated",
      "category": "appreciation",
      "difficulty": 1,
      "formatType": "affirmation",
      "imagePath": "assets/images/quests/feel-good-foundations.png",
      "description": "How appreciated do you feel?",
      "questions": [
        {
          "question": "My partner regularly tells me what they appreciate about me.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "I feel admired by my partner.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "My partner notices the effort I put into our relationship.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "My partner celebrates my wins with genuine enthusiasm.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "I regularly notice and express appreciation for my partner too.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        }
      ]
    },
    {
      "id": "playfulness",
      "name": "Staying Playful",
      "category": "joy",
      "difficulty": 1,
      "formatType": "affirmation",
      "imagePath": "assets/images/quests/playful-moments.png",
      "description": "How much joy and play is in your relationship?",
      "questions": [
        {
          "question": "My partner's laughter makes me feel connected to them.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We still flirt and play like we did at the beginning.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "The ordinary moments with my partner feel meaningful.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We can be silly together without feeling self-conscious.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "Our daily interactions leave me feeling connected, not drained.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        }
      ]
    },
    {
      "id": "repair",
      "name": "Navigating Hard Moments",
      "category": "repair",
      "difficulty": 1,
      "formatType": "affirmation",
      "imagePath": "assets/images/quests/feel-good-foundations.png",
      "description": "How do you handle disagreements and reconnect?",
      "questions": [
        {
          "question": "I trust that we can work through disagreements without damaging our relationship.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "After conflict, we find our way back to each other.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "I feel safe bringing up difficult topics with my partner.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "My partner takes responsibility when they've hurt me.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We can disagree without it threatening our sense of 'us'.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        }
      ]
    }
  ]
}
```

#### C.3.2 Practical Branch (6 Quizzes, 30 Questions)

```json
{
  "quizzes": [
    {
      "id": "practical_teamwork",
      "name": "Working as a Team",
      "category": "teamwork",
      "difficulty": 1,
      "formatType": "affirmation",
      "imagePath": "assets/images/quests/feel-good-foundations.png",
      "description": "How well do you work together on daily life?",
      "questions": [
        {
          "question": "I trust my partner to carry their share without me having to ask.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We divide responsibilities in a way that feels fair to both of us.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "When one of us is overwhelmed, the other steps up.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We can rely on each other to follow through on commitments.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We're a good team when life gets busy or stressful.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        }
      ]
    },
    {
      "id": "practical_decisions",
      "name": "Making Decisions Together",
      "category": "decisions",
      "difficulty": 1,
      "formatType": "affirmation",
      "imagePath": "assets/images/quests/feel-good-foundations.png",
      "description": "How do you navigate choices together?",
      "questions": [
        {
          "question": "I feel heard and valued when we make decisions together.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We can compromise without either of us feeling steamrolled.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We discuss big decisions before making them.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "I trust my partner's judgment on decisions that affect us both.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We're aligned on what's most important for our shared life.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        }
      ]
    },
    {
      "id": "practical_communication",
      "name": "Communicating Clearly",
      "category": "communication",
      "difficulty": 1,
      "formatType": "affirmation",
      "imagePath": "assets/images/quests/feel-good-foundations.png",
      "description": "How well do you understand each other?",
      "questions": [
        {
          "question": "I can tell my partner what I need without fear of their reaction.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "My partner really listens when I'm trying to explain something.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We check in with each other before making assumptions.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "I feel understood, not just heard, when we talk.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We can navigate misunderstandings without it escalating.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        }
      ]
    },
    {
      "id": "practical_stress",
      "name": "Handling Stress Together",
      "category": "stress",
      "difficulty": 1,
      "formatType": "affirmation",
      "imagePath": "assets/images/quests/feel-good-foundations.png",
      "description": "How do you support each other under pressure?",
      "questions": [
        {
          "question": "My partner knows how to comfort me when I'm stressed.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We don't take our stress out on each other.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "I can vent to my partner without them trying to immediately fix it.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "When life is hard, we pull together rather than apart.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "My partner helps me decompress after difficult days.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        }
      ]
    },
    {
      "id": "practical_independence",
      "name": "Balancing Togetherness",
      "category": "balance",
      "difficulty": 1,
      "formatType": "affirmation",
      "imagePath": "assets/images/quests/feel-good-foundations.png",
      "description": "How do you balance independence and connection?",
      "questions": [
        {
          "question": "We give each other space to pursue individual interests.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "I can have my own friendships without my partner feeling threatened.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We find a healthy balance between 'us time' and 'me time'.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "My partner supports my personal growth, even when it doesn't involve them.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We're two whole people who choose to share a life, not two halves.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        }
      ]
    },
    {
      "id": "practical_future",
      "name": "Planning Our Future",
      "category": "future",
      "difficulty": 1,
      "formatType": "affirmation",
      "imagePath": "assets/images/quests/feel-good-foundations.png",
      "description": "How aligned are you on where you're headed?",
      "questions": [
        {
          "question": "We talk openly about our hopes for the future.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "I feel included in my partner's vision for their life.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We're working toward shared goals that excite us both.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "I can share my dreams without worrying they'll be dismissed.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We're building something meaningful together.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        }
      ]
    }
  ]
}
```

#### C.3.3 Spiritual Branch (6 Quizzes, 30 Questions)

```json
{
  "quizzes": [
    {
      "id": "spiritual_gratitude",
      "name": "Practicing Gratitude",
      "category": "gratitude",
      "difficulty": 1,
      "formatType": "affirmation",
      "imagePath": "assets/images/quests/feel-good-foundations.png",
      "description": "How do you cultivate thankfulness together?",
      "questions": [
        {
          "question": "I regularly notice and appreciate the effort my partner puts into us.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "I tell my partner specifically what I'm grateful for about them.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We don't take each other for granted, even after time together.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "I feel lucky to have my partner in my life.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We pause to appreciate what we have, not just what we want.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        }
      ]
    },
    {
      "id": "spiritual_growth",
      "name": "Growing Together",
      "category": "growth",
      "difficulty": 1,
      "formatType": "affirmation",
      "imagePath": "assets/images/quests/feel-good-foundations.png",
      "description": "How do you help each other become your best selves?",
      "questions": [
        {
          "question": "My partner inspires me to grow in ways I couldn't alone.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We challenge each other to be better, with kindness.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "My partner believes in dreams I sometimes doubt myself.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We're growing in the same direction, not apart.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "Being with my partner has made me a better person.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        }
      ]
    },
    {
      "id": "spiritual_values",
      "name": "Sharing Values",
      "category": "values",
      "difficulty": 1,
      "formatType": "affirmation",
      "imagePath": "assets/images/quests/feel-good-foundations.png",
      "description": "How aligned are your core beliefs?",
      "questions": [
        {
          "question": "We share similar beliefs about what matters most in life.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "My partner knows my deepest hopes and fears.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We respect each other's beliefs, even where they differ.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "Our values guide how we make decisions together.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "I feel understood at a level beyond the surface.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        }
      ]
    },
    {
      "id": "spiritual_purpose",
      "name": "Sharing Purpose",
      "category": "purpose",
      "difficulty": 1,
      "formatType": "affirmation",
      "imagePath": "assets/images/quests/feel-good-foundations.png",
      "description": "What meaning does your relationship create?",
      "questions": [
        {
          "question": "Our relationship gives my life deeper meaning.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We have a shared sense of what we're building together.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "I can't imagine building my life with anyone else.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We talk about the legacy we want to create together.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "I know what role I play in my partner's life story.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        }
      ]
    },
    {
      "id": "spiritual_support",
      "name": "Soulful Support",
      "category": "support",
      "difficulty": 1,
      "formatType": "affirmation",
      "imagePath": "assets/images/quests/feel-good-foundations.png",
      "description": "How deeply do you support each other?",
      "questions": [
        {
          "question": "When I'm at my worst, my partner still treats me with kindness.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "My partner helps me find peace during difficult times.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "I can be vulnerable without fear of judgment or rejection.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "My partner lifts me up when I can't lift myself.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We hold space for each other's pain without trying to fix it.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        }
      ]
    },
    {
      "id": "spiritual_rituals",
      "name": "Meaningful Rituals",
      "category": "rituals",
      "difficulty": 1,
      "formatType": "affirmation",
      "imagePath": "assets/images/quests/feel-good-foundations.png",
      "description": "What traditions make your bond unique?",
      "questions": [
        {
          "question": "We have traditions that are uniquely ours.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "Our rituals help us stay connected even when life is busy.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We celebrate milestones in ways that feel meaningful to us.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "Small daily moments feel sacred when shared with my partner.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        },
        {
          "question": "We make time for what truly matters in our relationship.",
          "questionType": "scale",
          "options": [],
          "correctAnswer": null
        }
      ]
    }
  ]
}
```

---

### Content Gaps to Fill

#### Questions That Should Exist But Don't:

**On Emotional Safety:**
- "When I'm at my worst, my partner still treats me with kindness."
- "I can tell my partner when they've hurt me without fear of their reaction."
- "My partner makes me feel safe, not just physically but emotionally."

**On Feeling Known:**
- "My partner knows what keeps me up at night."
- "My partner understands what I need even when I can't articulate it."
- "My partner remembers the small things that matter to me."

**On Appreciation:**
- "My partner regularly tells me what they appreciate about me."
- "I feel admired by my partner."
- "My partner notices the effort I put into our relationship."

**On Navigating Difference:**
- "We can disagree without disrespecting each other."
- "Our differences make us stronger as a couple."
- "I'm curious about my partner's perspective even when I disagree."

**On Repair:**
- "After we fight, we always find our way back to each other."
- "My partner takes responsibility when they've messed up."
- "Conflict brings us closer once we work through it."

**On Shared Meaning:**
- "We have traditions that are uniquely ours."
- "We're building something meaningful together."
- "I know what role I play in my partner's life story."

---

### Implementation Priority Matrix

| Improvement | Impact | Effort | Priority |
|-------------|--------|--------|----------|
| Add follow-up prompts to existing questions | High | Low | P0 |
| Reframe competitive You-or-Me questions | High | Low | P0 |
| Add "Bids for Connection" affirmations | High | Low | P0 |
| Create repair-focused affirmation quiz | High | Medium | P1 |
| Restructure You-or-Me around appreciation | High | Medium | P1 |
| Add vulnerability-focused intimate questions | High | Medium | P1 |
| Create discussion prompts post-quiz | Medium | Medium | P2 |
| Add progress tracking on dimensions | Medium | High | P2 |
| Full Gottman-style card deck feature | High | High | P3 |

---

### Summary: The Therapeutic North Star

The questions should help couples:

1. **Know each other more deeply** — Not just facts, but fears, dreams, and feelings
2. **Feel safe being vulnerable** — Questions that invite openness, not defensiveness
3. **Express appreciation** — Regular practice of noticing and naming what they value
4. **Navigate differences with curiosity** — Not who's "more" but how they're different
5. **Build confidence in their bond** — Affirm that they can handle hard things together
6. **Create shared meaning** — Connect daily moments to their larger story

Every question should pass this test: *"Will answering this together help this couple feel more connected, understood, and appreciative of each other?"*

If a question only produces a fact ("My partner's favorite color is blue"), it's trivia.
If a question produces understanding ("My partner loves blue because it reminds them of summer days at their grandmother's lake house, which was their only safe place as a kid"), it's connection.

**Aim for connection.**

---

## Appendix D: Option B Implementation Plan — Adding a "Connection" Branch

This appendix details the implementation plan for adding therapeutically-improved questions as a new branch rather than replacing existing content.

---

### D.1 Current Architecture Summary

The app uses a **branch rotation system** where couples cycle through different content branches as they complete activities.

**Key Files:**
- `lib/models/branch_progression_state.dart` — Defines branches per activity type
- `lib/services/branch_progression_service.dart` — Manages branch rotation
- `lib/config/brand/content_paths.dart` — Maps branches to file paths

**Current Branch Configuration:**
```dart
const Map<BranchableActivityType, List<String>> branchFolderNames = {
  BranchableActivityType.classicQuiz: ['lighthearted', 'deeper', 'spicy'],
  BranchableActivityType.affirmation: ['emotional', 'practical', 'spiritual'],
  BranchableActivityType.youOrMe: ['playful', 'reflective', 'intimate'],
  // ...
};
```

**Rotation Logic:**
```dart
currentBranch = totalCompletions % maxBranches;
```
- Completion 0 → Branch 0 (lighthearted)
- Completion 1 → Branch 1 (deeper)
- Completion 2 → Branch 2 (spicy)
- Completion 3 → Branch 0 (lighthearted) — cycles back

---

### D.2 Proposed Change: Add "Connection" Branch

#### Option A: Replace an Existing Branch

Replace `deeper` with `connection` (therapeutically-improved questions):

```dart
BranchableActivityType.classicQuiz: ['lighthearted', 'connection', 'spicy'],
```

**Pros:**
- No rotation logic changes
- Same 3-branch cycle

**Cons:**
- Loses existing "deeper" questions
- Couples mid-cycle might experience jarring content change

#### Option B: Add as 4th Branch

Expand to 4 branches:

```dart
BranchableActivityType.classicQuiz: ['lighthearted', 'deeper', 'connection', 'spicy'],
```

**Pros:**
- Keeps all existing content
- Adds new therapeutic content as enhancement

**Cons:**
- Longer rotation cycle (4 instead of 3)
- Need to update `maxBranches` for existing couples

#### Option C: Replace "Deeper" and Rename

The current `deeper` branch is already "deeper" trivia questions — not therapeutically deep. Rename it:

- `lighthearted` → Fun trivia (keep as-is)
- `deeper` → Rename to `connection` with therapeutic questions
- `spicy` → Romance/intimacy trivia (keep as-is)

**Recommended: Option C** — Most accurate naming, minimal code changes.

---

### D.3 Implementation Steps

#### Step 1: Create New Content Files

**File:** `app/assets/brands/togetherremind/data/classic-quiz/connection/questions.json`

Create directory and file:
```
app/assets/brands/togetherremind/data/classic-quiz/
├── lighthearted/
│   └── questions.json  (existing - keep)
├── connection/          (NEW - replaces 'deeper')
│   └── questions.json  (NEW - therapeutic questions)
└── spicy/
    └── questions.json  (existing - keep)
```

#### Step 2: Update Branch Names in Code

**File:** `lib/models/branch_progression_state.dart`

```dart
// BEFORE
BranchableActivityType.classicQuiz: ['lighthearted', 'deeper', 'spicy'],

// AFTER
BranchableActivityType.classicQuiz: ['lighthearted', 'connection', 'spicy'],
```

#### Step 3: Handle Migration (Optional)

If couples are mid-cycle on the old `deeper` branch, they'll automatically get `connection` content on next load. This is acceptable since both are "deeper" content.

Alternatively, keep the old `deeper/` folder as a fallback:
```dart
String getClassicQuizPath(String branch) {
  // Fallback for old branch name
  if (branch == 'deeper') branch = 'connection';
  return '$_dataPath/classic-quiz/$branch/questions.json';
}
```

#### Step 4: Copy to HolyCouples Brand

```
app/assets/brands/holycouples/data/classic-quiz/
├── lighthearted/
│   └── questions.json
├── connection/          (NEW)
│   └── questions.json
└── spicy/               (may remain empty for this brand)
```

---

### D.4 Content Structure for "Connection" Branch

**Goal:** 50-60 therapeutic questions organized by theme

**Question Categories:**

| Category | Count | Description |
|----------|-------|-------------|
| Inner World | 10 | What things mean to the person (comfort food, holidays, routines) |
| Emotional Needs | 10 | How they need support, love, appreciation |
| Attachment & Safety | 10 | What makes them feel secure, triggers, repair needs |
| Dreams & Fears | 10 | Hopes, worries, aspirations for the future |
| Connection & Presence | 10 | What makes them feel seen, known, prioritized |
| Formative Experiences | 5 | Childhood, past relationships, shaping moments |

**Difficulty Distribution:**
- Tier 1 (Difficulty 1-2): 35 questions — Accessible, not too vulnerable
- Tier 2 (Difficulty 3): 15 questions — Deeper, requires more trust

**Sample Structure:**
```json
{
  "questions": [
    {
      "id": "conn_001",
      "question": "What does my comfort food represent to me?",
      "options": [
        "Nostalgia and childhood memories",
        "A treat I use to celebrate myself",
        "Something that soothes me when stressed",
        "A taste that became part of my identity",
        "Other / Something else"
      ],
      "category": "inner_world",
      "difficulty": 2,
      "tier": 1
    }
    // ... 49 more questions
  ]
}
```

---

### D.5 Full Question Set for "Connection" Branch

Below is the complete 50-question set, ready to use:

```json
{
  "questions": [
    {
      "id": "conn_001",
      "question": "What does my comfort food represent to me?",
      "options": [
        "Nostalgia and childhood memories",
        "A treat I use to celebrate myself",
        "Something that soothes me when stressed",
        "A taste that became part of my identity",
        "Other / Something else"
      ],
      "category": "inner_world",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_002",
      "question": "What do I value most about holiday celebrations?",
      "options": [
        "Being surrounded by family and loved ones",
        "Traditions and rituals that repeat each year",
        "A break from normal life to recharge",
        "The chance to give and receive thoughtfully",
        "Other / Something else"
      ],
      "category": "inner_world",
      "difficulty": 1,
      "tier": 1
    },
    {
      "id": "conn_003",
      "question": "What does my morning routine say about how I face the world?",
      "options": [
        "I need quiet time alone before engaging",
        "I jump straight into action and productivity",
        "I ease in slowly — don't rush me",
        "Mornings are for connection with you",
        "Other / Something else"
      ],
      "category": "inner_world",
      "difficulty": 1,
      "tier": 1
    },
    {
      "id": "conn_004",
      "question": "What do I most want to feel on our ideal vacation together?",
      "options": [
        "Completely relaxed and unplugged",
        "Adventurous and discovering new things",
        "Romantic and focused on just us",
        "Culturally enriched and inspired",
        "Other / Something else"
      ],
      "category": "inner_world",
      "difficulty": 1,
      "tier": 1
    },
    {
      "id": "conn_005",
      "question": "What kind of environment helps me feel most at peace?",
      "options": [
        "Quiet and cozy spaces at home",
        "Being in nature, outdoors",
        "Busy, stimulating environments with people",
        "Anywhere, as long as you're with me",
        "Other / Something else"
      ],
      "category": "inner_world",
      "difficulty": 1,
      "tier": 1
    },
    {
      "id": "conn_006",
      "question": "What does music usually do for me?",
      "options": [
        "Helps me process emotions I can't express",
        "Energizes and motivates me",
        "Connects me to memories and nostalgia",
        "Creates atmosphere for whatever I'm doing",
        "Other / Something else"
      ],
      "category": "inner_world",
      "difficulty": 1,
      "tier": 1
    },
    {
      "id": "conn_007",
      "question": "When I'm overwhelmed, what do I most need?",
      "options": [
        "Space and time alone to decompress",
        "Someone to listen without fixing",
        "Physical comfort (a hug, being held)",
        "Help taking things off my plate",
        "Other / Something else"
      ],
      "category": "emotional_needs",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_008",
      "question": "When do I feel most loved by you specifically?",
      "options": [
        "When you tell me what you appreciate about me",
        "When you give me your undivided attention",
        "When you reach out to touch or hold me",
        "When you do something thoughtful unprompted",
        "Other / Something else"
      ],
      "category": "emotional_needs",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_009",
      "question": "What kind of support helps me most when I'm stressed?",
      "options": [
        "Just listen without trying to fix it",
        "Help me think through solutions",
        "Distract me and make me laugh",
        "Take something off my plate",
        "Other / Something else"
      ],
      "category": "emotional_needs",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_010",
      "question": "What makes me feel most appreciated by you?",
      "options": [
        "When you notice the effort I put into things",
        "When you brag about me to others",
        "When you thank me for small everyday things",
        "When you show you don't take me for granted",
        "Other / Something else"
      ],
      "category": "emotional_needs",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_011",
      "question": "What's my biggest unspoken need in our relationship?",
      "options": [
        "More quality time without distractions",
        "More verbal affirmation and reassurance",
        "More physical affection and closeness",
        "More support for my personal goals",
        "Other / Something else"
      ],
      "category": "emotional_needs",
      "difficulty": 3,
      "tier": 2
    },
    {
      "id": "conn_012",
      "question": "How do I typically show love even when I don't say it?",
      "options": [
        "Through acts of service and helping out",
        "Through physical affection and touch",
        "Through planning things for us to do",
        "Through small gifts or gestures",
        "Other / Something else"
      ],
      "category": "emotional_needs",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_013",
      "question": "What does a perfect lazy day with you look like for me?",
      "options": [
        "Cuddled up watching something together",
        "Doing our own things in the same space",
        "Cooking and eating good food slowly",
        "No plans — just see where the day takes us",
        "Other / Something else"
      ],
      "category": "connection",
      "difficulty": 1,
      "tier": 1
    },
    {
      "id": "conn_014",
      "question": "What triggers me to feel disconnected from you?",
      "options": [
        "When you seem distracted or on your phone",
        "When we haven't had quality time together",
        "When conflict goes unresolved",
        "When I feel like an afterthought in your day",
        "Other / Something else"
      ],
      "category": "attachment",
      "difficulty": 3,
      "tier": 2
    },
    {
      "id": "conn_015",
      "question": "What do I need most after we've had a disagreement?",
      "options": [
        "Some space to cool down first",
        "To talk it through right away",
        "Physical reconnection (a hug, touch)",
        "A clear acknowledgment that we're okay",
        "Other / Something else"
      ],
      "category": "attachment",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_016",
      "question": "What does 'home' feel like to me when I'm with you?",
      "options": [
        "Safe — I can let my guard down completely",
        "Warm — I feel accepted and cared for",
        "Fun — we laugh and enjoy each other",
        "Grounded — I know where I belong",
        "Other / Something else"
      ],
      "category": "attachment",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_017",
      "question": "What helps me feel secure in our relationship?",
      "options": [
        "Regular reassurance that you love me",
        "Consistency and follow-through on promises",
        "Physical closeness and affection",
        "Being included in your plans and decisions",
        "Other / Something else"
      ],
      "category": "attachment",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_018",
      "question": "When I'm upset but not talking, what do I usually need?",
      "options": [
        "Time alone to process before discussing",
        "For you to gently check in on me",
        "Physical comfort without words",
        "To be distracted until I'm ready",
        "Other / Something else"
      ],
      "category": "attachment",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_019",
      "question": "What's my biggest fear about our future together?",
      "options": [
        "That we'll grow apart over time",
        "That life will get too busy for us",
        "That I'll disappoint you somehow",
        "That something outside our control will separate us",
        "Other / Something else"
      ],
      "category": "fears",
      "difficulty": 3,
      "tier": 2
    },
    {
      "id": "conn_020",
      "question": "What insecurity do I carry that affects our relationship?",
      "options": [
        "Not feeling good enough for you",
        "Fear of being abandoned or left",
        "Worry that I'm too much or too needy",
        "Doubt about being truly lovable",
        "Other / Something else"
      ],
      "category": "fears",
      "difficulty": 3,
      "tier": 2
    },
    {
      "id": "conn_021",
      "question": "What worry keeps me up at night that I rarely share?",
      "options": [
        "Something about my health or family",
        "Concerns about our relationship",
        "Work or financial stress",
        "Fear about the future in general",
        "Other / Something else"
      ],
      "category": "fears",
      "difficulty": 3,
      "tier": 2
    },
    {
      "id": "conn_022",
      "question": "What past experience makes trusting more difficult for me?",
      "options": [
        "A previous relationship that hurt me",
        "Family dynamics growing up",
        "Being let down by someone I relied on",
        "General life experiences that taught me to be guarded",
        "Other / Something else"
      ],
      "category": "formative",
      "difficulty": 3,
      "tier": 2
    },
    {
      "id": "conn_023",
      "question": "What childhood experience still shapes how I love?",
      "options": [
        "How affection was (or wasn't) shown at home",
        "How my parents handled conflict",
        "Feeling like I had to earn love or approval",
        "A loss or disappointment I'm still healing from",
        "Other / Something else"
      ],
      "category": "formative",
      "difficulty": 3,
      "tier": 2
    },
    {
      "id": "conn_024",
      "question": "What did I learn about relationships from my parents?",
      "options": [
        "What I want to recreate with you",
        "What I want to do differently",
        "A mix of both good and bad lessons",
        "I'm still figuring that out",
        "Other / Something else"
      ],
      "category": "formative",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_025",
      "question": "What's the most important lesson a past relationship taught me?",
      "options": [
        "What I truly need in a partner",
        "How to communicate better",
        "What red flags to watch for",
        "My own patterns I need to work on",
        "Other / Something else"
      ],
      "category": "formative",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_026",
      "question": "What's my biggest dream for us in 10 years?",
      "options": [
        "A family or home we've built together",
        "Adventures and experiences we've shared",
        "Deep intimacy and partnership",
        "Achieving our individual goals while staying close",
        "Other / Something else"
      ],
      "category": "dreams",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_027",
      "question": "What do I secretly hope you already know about me?",
      "options": [
        "How much I love you even when I don't say it",
        "What I need when I'm struggling",
        "My dreams and what I'm working toward",
        "The little things that make me happy",
        "Other / Something else"
      ],
      "category": "dreams",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_028",
      "question": "What kind of legacy do I want us to create together?",
      "options": [
        "A loving family that lasts generations",
        "A life full of adventure and experiences",
        "Positive impact on our community or the world",
        "A partnership others look up to",
        "Other / Something else"
      ],
      "category": "dreams",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_029",
      "question": "What would my ideal life look like, and where do you fit?",
      "options": [
        "You're the center of it — my person",
        "You're my partner as we both pursue our dreams",
        "You're my anchor while I explore and grow",
        "You're the adventure — we discover life together",
        "Other / Something else"
      ],
      "category": "dreams",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_030",
      "question": "What unfulfilled dream do I still think about?",
      "options": [
        "A career or creative aspiration",
        "A place I want to live or travel to",
        "A version of myself I want to become",
        "Something I want to experience with you",
        "Other / Something else"
      ],
      "category": "dreams",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_031",
      "question": "What moment with you made me feel most truly seen?",
      "options": [
        "When you remembered something small that mattered to me",
        "When you understood what I needed without me saying it",
        "When you stood up for me or defended me",
        "When you celebrated my success as if it were yours",
        "Other / Something else"
      ],
      "category": "connection",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_032",
      "question": "What makes me feel most connected to you?",
      "options": [
        "Deep conversations about life",
        "Laughing together at something silly",
        "Physical closeness and touch",
        "Doing everyday things side by side",
        "Other / Something else"
      ],
      "category": "connection",
      "difficulty": 1,
      "tier": 1
    },
    {
      "id": "conn_033",
      "question": "When do I feel most proud to be with you?",
      "options": [
        "When I see how you treat others with kindness",
        "When you achieve something you worked hard for",
        "When you handle a difficult situation with grace",
        "When you make me laugh in unexpected moments",
        "Other / Something else"
      ],
      "category": "connection",
      "difficulty": 1,
      "tier": 1
    },
    {
      "id": "conn_034",
      "question": "What small thing do you do that means more to me than you realize?",
      "options": [
        "The way you greet me or say goodbye",
        "How you check in on me during the day",
        "The little tasks you do without being asked",
        "How you touch or hold me casually",
        "Other / Something else"
      ],
      "category": "connection",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_035",
      "question": "What's the best way to cheer me up when I'm down?",
      "options": [
        "Make me laugh or be silly with me",
        "Hold me and let me feel your presence",
        "Give me space but check in gently",
        "Help me talk through what's bothering me",
        "Other / Something else"
      ],
      "category": "connection",
      "difficulty": 1,
      "tier": 1
    },
    {
      "id": "conn_036",
      "question": "What do I wish we did more of together?",
      "options": [
        "Adventures and new experiences",
        "Quiet time just being together",
        "Deep conversations about our lives",
        "Playful, silly moments",
        "Other / Something else"
      ],
      "category": "connection",
      "difficulty": 1,
      "tier": 1
    },
    {
      "id": "conn_037",
      "question": "What conversation topic always lights me up?",
      "options": [
        "Our future dreams and plans",
        "Creative ideas or passions I have",
        "Memories we've made together",
        "Deep questions about life and meaning",
        "Other / Something else"
      ],
      "category": "inner_world",
      "difficulty": 1,
      "tier": 1
    },
    {
      "id": "conn_038",
      "question": "How do I typically handle stress?",
      "options": [
        "Withdraw and need alone time",
        "Talk it out with someone I trust",
        "Stay busy and distract myself",
        "Get quiet until I've processed it",
        "Other / Something else"
      ],
      "category": "inner_world",
      "difficulty": 1,
      "tier": 1
    },
    {
      "id": "conn_039",
      "question": "What do I daydream about when I'm alone?",
      "options": [
        "Our future together",
        "Adventures I want to have",
        "Creative projects or ideas",
        "Peaceful, quiet moments",
        "Other / Something else"
      ],
      "category": "inner_world",
      "difficulty": 1,
      "tier": 1
    },
    {
      "id": "conn_040",
      "question": "What's something I'm working on about myself?",
      "options": [
        "Being more open and vulnerable",
        "Managing stress or anxiety better",
        "Being more patient or present",
        "Building confidence in myself",
        "Other / Something else"
      ],
      "category": "inner_world",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_041",
      "question": "What do I need to hear from you more often?",
      "options": [
        "That you're proud of me",
        "That you find me attractive",
        "That you appreciate what I do",
        "That you're not going anywhere",
        "Other / Something else"
      ],
      "category": "emotional_needs",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_042",
      "question": "What's hardest for me to ask for in our relationship?",
      "options": [
        "More time and attention",
        "Physical affection",
        "Reassurance and validation",
        "Help with things I should be able to handle",
        "Other / Something else"
      ],
      "category": "emotional_needs",
      "difficulty": 3,
      "tier": 2
    },
    {
      "id": "conn_043",
      "question": "What's the hardest emotion for me to express?",
      "options": [
        "Sadness or vulnerability",
        "Anger or frustration",
        "Fear or anxiety",
        "Deep love and affection",
        "Other / Something else"
      ],
      "category": "emotional_needs",
      "difficulty": 3,
      "tier": 2
    },
    {
      "id": "conn_044",
      "question": "When conflict arises, what's my first instinct?",
      "options": [
        "Withdraw and avoid until I'm calm",
        "Address it directly right away",
        "Get defensive and protect myself",
        "Try to fix it or smooth things over quickly",
        "Other / Something else"
      ],
      "category": "attachment",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_045",
      "question": "What would help me feel safer being vulnerable with you?",
      "options": [
        "Knowing you won't judge or criticize me",
        "Seeing you be vulnerable first",
        "Reassurance that you still love me after",
        "More time — trust builds slowly for me",
        "Other / Something else"
      ],
      "category": "attachment",
      "difficulty": 3,
      "tier": 2
    },
    {
      "id": "conn_046",
      "question": "What's the most meaningful gift you could give me?",
      "options": [
        "Your undivided time and presence",
        "Something that shows you really listen",
        "An experience we can share together",
        "Words that express how you feel about me",
        "Other / Something else"
      ],
      "category": "connection",
      "difficulty": 1,
      "tier": 1
    },
    {
      "id": "conn_047",
      "question": "What do I hope our relationship teaches me?",
      "options": [
        "How to be truly vulnerable and loved anyway",
        "How to be a better partner and teammate",
        "That I'm worthy of deep, lasting love",
        "How to balance independence with intimacy",
        "Other / Something else"
      ],
      "category": "dreams",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_048",
      "question": "What do I value most about you that I might not say enough?",
      "options": [
        "Your patience with me",
        "How you make me laugh",
        "Your unwavering support",
        "The safety I feel with you",
        "Other / Something else"
      ],
      "category": "connection",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_049",
      "question": "What's one thing I want you to always know, even if I forget to say it?",
      "options": [
        "That I love you more than I show",
        "That you're my favorite person",
        "That I'm grateful for you every day",
        "That I'd choose you all over again",
        "Other / Something else"
      ],
      "category": "connection",
      "difficulty": 2,
      "tier": 1
    },
    {
      "id": "conn_050",
      "question": "What does being 'us' mean to me?",
      "options": [
        "Having a partner who truly knows me",
        "Building a life together with purpose",
        "Facing whatever comes as a team",
        "Being home no matter where we are",
        "Other / Something else"
      ],
      "category": "dreams",
      "difficulty": 2,
      "tier": 1
    }
  ]
}
```

---

### D.6 Applying the Same Approach to Other Activities

The same branch-addition pattern can apply to:

#### You-or-Me: Add "appreciation" Branch

Replace or add to existing branches:
```dart
// Current
BranchableActivityType.youOrMe: ['playful', 'reflective', 'intimate'],

// Option: Replace 'reflective' with 'connection'
BranchableActivityType.youOrMe: ['playful', 'connection', 'intimate'],
```

Content: Use the therapeutically-reframed You-or-Me questions from Appendix C.2.

#### Affirmation: Enhance Existing Branches

The affirmation format is already therapeutically sound (scale-based self-reflection). Update content within existing branches using rewrites from Appendix C.3.

---

### D.7 Implementation Checklist

#### Code Changes

- [ ] Update `branchFolderNames` in `branch_progression_state.dart`
  - Change `'deeper'` to `'connection'` for classicQuiz
- [ ] Optional: Add migration fallback in `content_paths.dart`
- [ ] Run `flutter pub run build_runner build` (if Hive models changed)
- [ ] Test branch rotation still works

#### Content Changes

- [ ] Create `app/assets/brands/togetherremind/data/classic-quiz/connection/` directory
- [ ] Add `questions.json` with 50 therapeutic questions
- [ ] Create `manifest.json` if using branch manifests for media
- [ ] Copy/adapt for HolyCouples brand
- [ ] Keep or archive old `deeper/` folder for reference

#### Testing

- [ ] Test new couple starting fresh → rotates through lighthearted → connection → spicy
- [ ] Test existing couple mid-cycle → continues rotation with new content
- [ ] Verify question loading works for both brands
- [ ] Check no crashes if old `deeper` folder is accessed (fallback)

---

### D.8 Rollout Strategy

**Phase 1: Shadow Launch**
- Add new `connection/` folder alongside existing `deeper/`
- Keep rotation pointing to `deeper` initially
- Internal testing only

**Phase 2: Soft Launch**
- Update branch config to point to `connection`
- Monitor for any issues
- Gather feedback from select users

**Phase 3: Full Launch**
- Archive `deeper/` folder to `_legacy/deeper/`
- Update documentation
- Announce new "Connection Quiz" feature

---

### D.9 Future Enhancements

Once the branch is working:

1. **Add Follow-Up Prompts** — Display `followUp` field on results screen
2. **Track Relationship Dimensions** — Map question categories to health metrics
3. **Discussion Prompts** — Show conversation starters after quiz completion
4. **Progress Over Time** — Track how couples' responses evolve

---

*Option B Implementation Plan completed: 2025-12-02*

---

*Therapeutic analysis completed: 2025-12-01*
*Framework references: Gottman Method, Emotionally Focused Therapy (EFT), Attachment Theory*

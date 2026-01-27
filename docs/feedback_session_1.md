# Playtest Feedback Session 1 - UX Improvement Plan

**Date:** 2025-01-20
**Testers:** Joakim + Girlfriend
**Brand:** Us 2.0
**Flow tested:** Full onboarding → quizzes → games

---

## ⚠️ CODING AGENT INSTRUCTIONS

**CRITICAL: You MUST follow the HTML mockups exactly.**

Each HTML mockup file in `mockups/phase*/` contains:
1. **Before/After visual mockups** - showing exactly what to change
2. **Design notes** - explaining the rationale
3. **📋 Implementation Task List** - step-by-step checklist at the bottom

### How to implement:

1. **Open each HTML mockup file** in a browser to see the visual design
2. **Scroll to the bottom** of each HTML file to find the "📋 Implementation Task List"
3. **Complete EVERY checkbox item** in the task list
4. **Compare your implementation** against the "After" mockup screenshot
5. **Do not skip any mockup file** - each one represents required changes

### Master Implementation Checklist

| Phase | HTML Mockup File | Has Task List? |
|-------|------------------|----------------|
| 1.1 | `mockups/phase1/onboarding_screen.html` | ✅ Yes |
| 1.2 | `mockups/phase1/welcome_quiz_intro.html` | ✅ Yes |
| 1.3 | `mockups/phase1/welcome_quiz_results.html` | ✅ Yes |
| 1.4 | `mockups/phase1/lp_intro_overlay.html` | ✅ Yes |
| 1.5 | `mockups/phase1/paywall_success.html` | ✅ Yes |
| 2.1 | `mockups/phase2/quiz_instructions.html` | ✅ Yes |
| 2.2 | `mockups/phase2/quiz_results_lp.html` | ✅ Yes |
| 3.1-3.2 | `mockups/phase3/you_or_me_buttons.html` | ✅ Yes |
| 4.1 | `mockups/phase4/linked_tutorial.html` | ✅ Yes |
| 4.2 | `mockups/phase4/linked_clues.html` | ✅ Yes |
| 5 | No mockup (code fix only) | N/A |
| 6.1 | `mockups/phase6/steps_messaging.html` | ✅ Yes |

**All mockups now have implementation task lists.** Scroll to the bottom of each HTML file to find the "📋 Implementation Task List" section.

---

## Executive Summary

Playtest revealed recurring UX issues across the app:
1. **Emoji overuse** - Decorative emojis feel cheap/random, not purposeful
2. **Unclear messaging** - LP rewards and Steps Together confuse users
3. **Ergonomics** - Button placement difficult for one-handed use
4. **Missing onboarding** - Games lack tutorials for unfamiliar users
5. **Bugs** - Word Search diagonal selection broken in one direction

This document outlines fixes by app section. Each phase requires HTML mockups for review before implementation.

---

## Phase 1: Onboarding & Welcome Screens

### 1.1 Start Screen (OnboardingScreen)

**Issues identified:**
- Text over video background hard to read
- Animated heart emoji feels "lost" and out of place

**Current state:**
- Video background with gradient overlay
- Single animated ❤ emoji on logo (scale animation with glow)
- 4-5 shadow layers on text for readability

**UX Recommendations:**

| Issue | Recommendation | Priority |
|-------|----------------|----------|
| Text readability | Increase gradient overlay opacity OR add subtle text backdrop | High |
| Heart emoji | Replace with custom illustrated heart icon that matches brand | Medium |
| Animation | Keep scale animation, but use illustrated heart not emoji | Medium |

**Mockup required:** `mockups/phase1/onboarding_screen.html`
- Show improved text contrast
- Show illustrated heart replacing emoji

**Files to modify:**
- `app/lib/widgets/brand/us2/us2_logo.dart` (centralized fix)
- `app/assets/brands/us2/images/` (new heart icon)

---

### 1.1a Heart Logo Usage Analysis

**Codebase analysis** of where the Us 2.0 heart-emoji logo appears:

#### Primary Logo (Us2Logo Widget) — FIX NEEDED
The `Us2Logo` widget in `us2_logo.dart` uses a ♥ text emoji positioned top-right of "Us 2.0" text. This is the component that feels "cheap" and needs the illustrated heart replacement.

| Screen | File | Shares Us2Logo? |
|--------|------|-----------------|
| Onboarding/Landing | `onboarding_screen.dart` | ✅ Yes |
| Home Screen | `us2_home_content.dart` | ✅ Yes |

**Key insight:** Fixing `Us2Logo` widget fixes BOTH screens automatically.

#### LP Reward Badges — NO CHANGE NEEDED
Small ♥ hearts (16-18px) used as functional indicators for "+30 LP on completion" messaging:

| Screen | File | Size | Purpose |
|--------|------|------|---------|
| Linked Intro | `linked_intro_screen.dart:242` | 16px | LP badge indicator |
| Word Search Intro | `word_search_intro_screen.dart:252` | 18px | LP badge indicator |

These are small functional icons next to LP text, not branding. They work fine as simple symbols.

#### Decorative Background — NO CHANGE NEEDED
| Screen | File | Size | Purpose |
|--------|------|------|---------|
| Affirmation Intro | `affirmation_intro_screen.dart:665` | 64px | Grayscale background decoration |

This is a faded decorative element, different use case than the logo.

**Implementation plan:**
1. Create SVG heart icon: `assets/brands/us2/images/heart_icon.svg`
   - Reference: See `mockups/phase1/onboarding_screen.html` for exact SVG path and gradient
   - SVG uses brand gradient: `#FF6B6B` → `#FF9F43`
   - Path: `M16 28C16 28 3 18.5 3 10.5C3 6.36 6.36 3 10.5 3C13.08 3 15.36 4.33 16 6.5C16.64 4.33 18.92 3 21.5 3C25.64 3 29 6.36 29 10.5C29 18.5 16 28 16 28Z`
2. Update `Us2Logo` widget to use `SvgPicture.asset()` instead of ♥ emoji
3. Keep heart animation (scale/pulse) with `filter: drop-shadow()` for glow
4. Both onboarding and home screen update automatically (shared widget)

---

### 1.2 Welcome Quiz Intro Screen

**Issues identified:**
- Circle with emoji hearts doesn't work well
- Should use an actual image/illustration

**Current state:**
- 💕 emoji (80px) in grayscale circle
- 🎯 emoji (24px) in info card
- 5 staggered bounce-in animations (400-1200ms)

**UX Recommendations:**

| Issue | Recommendation | Priority |
|-------|----------------|----------|
| Heart emoji in circle | Replace with illustration (couple silhouette, intertwined hearts, or meaningful image) | High |
| Target emoji in card | Replace with custom icon OR remove entirely | Medium |
| Animation count | Reduce to 2-3 animations max (hero + content + button) | Low |
| Circle container | Either remove or use as frame for illustration | High |

**Mockup required:** `mockups/phase1/welcome_quiz_intro.html`
- Show hero illustration replacing emoji circle
- Show cleaner card without target emoji
- Reduce visual noise

**Files to modify:**
- `app/lib/screens/welcome_quiz_intro_screen.dart`
- `app/lib/widgets/brand/us2/` (new intro screen variant)
- `app/assets/brands/us2/images/` (new illustration)

---

### 1.3 Welcome Quiz Results Screen

**Issues identified:**
- Emoji usage
- Results require scrolling to see

**Current state:**
- 🎯 emoji (40px) in score section
- Scrollable question breakdown
- Confetti + haptics + animations on load

**UX Recommendations:**

| Issue | Recommendation | Priority |
|-------|----------------|----------|
| Target emoji | Replace with custom checkmark/score icon | Medium |
| Scrolling | Collapse results into summary OR use horizontal cards | High |
| Layout | Score prominent at top, breakdown expandable accordion style | High |

**Mockup required:** `mockups/phase1/welcome_quiz_results.html`
- Show non-scrolling layout
- Show accordion-style result breakdown (expand to see details)
- Show score icon replacing emoji

**Files to modify:**
- `app/lib/screens/welcome_quiz_results_screen.dart`

---

### 1.4 LP Intro Overlay

**Issues identified:**
- Too many heart emojis (3 different types)
- Random/decorative feel - should show point collection meaningfully
- Animation overload

**Current state:**
- ✨ sparkle (36px) OR 💗 pulsing heart (48px) depending on brand
- 💗 (16px) inside journey bar as indicator
- 5+ overlapping animations: fade → bounce → meter fill → pulse → badge pop
- Dense text with mixed font sizes (28px, 15px, 14px)

**UX Recommendations:**

| Issue | Recommendation | Priority |
|-------|----------------|----------|
| Pulsing heart emoji | Replace with custom animated LP coin/heart icon | High |
| Heart in progress bar | Replace with custom marker (small heart icon, not emoji) | High |
| Animation count | Remove pulse, simplify badge animation | Medium |
| Typography | Standardize: 24px title, 14px body, single weight | Medium |
| Journey visualization | Make progress bar the hero - LP fills towards destination | High |

**Design direction:**
The LP intro should feel like a "treasure map" or "journey tracker" - not random emojis. The progress bar filling up should be the main visual, with a destination reward image as the goal.

**Mockup required:** `mockups/phase1/lp_intro_overlay.html`
- Show progress bar as hero element
- Custom LP icon replacing all emojis
- Simpler animation (just the meter fill)
- Cleaner typography hierarchy

**Files to modify:**
- `app/lib/widgets/lp_intro_overlay.dart`
- `app/assets/brands/us2/images/` (LP icon)

---

### 1.5 Subscription "You're All Set" Screen

**Issues identified:**
- Red text/element on orange button has poor contrast

**Current state:**
- Salmon/coral card background
- White-to-cream gradient button with pink glow
- Unclear which specific element has the red/orange issue

**UX Recommendations:**

| Issue | Recommendation | Priority |
|-------|----------------|----------|
| Color contrast | Audit button colors - ensure WCAG AA compliance | High |
| Red on orange | If using red accent, switch to white or cream | High |

**Mockup required:** `mockups/phase1/paywall_success.html`
- Show corrected button with proper contrast
- Include color hex codes for dev handoff

**Files to modify:**
- `app/lib/screens/paywall_screen.dart`

---

## Phase 2: Quiz Experience

### 2.1 First-Person Question Clarity

**Issues identified:**
- Unclear that questions are in first-person perspective
- Questions 1 and 4 particularly confusing
- Question 4: unclear who you're answering about (self or partner?)

**Current state:**
- Quiz content defines questions in first-person ("I feel...", "I prefer...")
- No explicit instruction telling users "answer for yourself"
- Some questions may be ambiguous about perspective

**UX Recommendations:**

| Issue | Recommendation | Priority |
|-------|----------------|----------|
| Question perspective | Add brief instruction before first question: "Answer how YOU feel" | High |
| Ambiguous questions | Review question 1 & 4 content, rewrite for clarity | High |
| Visual cue | Add small "About you" badge on question cards | Medium |

**Mockup required:** `mockups/phase2/quiz_instructions.html`
- Show instruction banner before questions
- Show "About you" badge on question cards
- Include rewritten versions of problematic questions

**Files to modify:**
- `app/lib/screens/quiz_match_game_screen.dart` (add instruction)
- Quiz content files (rewrite questions)

---

### 2.2 LP Reward Confusion

**Issues identified:**
- LP awarded even when partners answer differently
- Users don't understand what triggers LP rewards
- Expectation: LP = matching answers (reality: LP = participation)

**Current state:**
- LP awarded for completing quiz, not for matching
- No explanation of LP earning logic
- Results screen shows match/mismatch but LP badge appears regardless

**UX Recommendations:**

| Issue | Recommendation | Priority |
|-------|----------------|----------|
| LP trigger clarity | Add text: "You earned LP for playing together!" | High |
| Match bonus (optional) | Consider: bonus LP for high match % (design decision) | Low |
| Results messaging | Separate LP message from match results | Medium |

**Design decision needed:** Should matching answers give bonus LP?
- **Option A:** LP for participation only (current) - simpler, less pressure
- **Option B:** Base LP + match bonus - gamifies alignment, may feel judgey

**Mockup required:** `mockups/phase2/quiz_results_lp.html`
- Show LP explanation text
- Show clear separation of "Match score" vs "LP earned"
- Show both Option A and Option B designs for decision

**Files to modify:**
- `app/lib/screens/quiz_match_results_screen.dart`
- `app/lib/screens/welcome_quiz_results_screen.dart`

---

## Phase 3: You or Me Game

### 3.1 Button Placement (Ergonomics)

**Issues identified:**
- Buttons at bottom of screen
- Difficult to tap with one hand
- 100px wide buttons may be precision targets

**Current state:**
- Two 100px (110px Us2) side-by-side buttons
- Centered horizontally, positioned below card stack
- Vertical padding: 16px

**UX Recommendations:**

| Issue | Recommendation | Priority |
|-------|----------------|----------|
| Vertical position | Move buttons to thumb-friendly zone (middle 40% of screen) | High |
| Button size | Increase width to 130-140px for easier tapping | Medium |
| Alternative input | Consider: swipe left/right on cards (like Tinder) | Low |

**Mockup required:** `mockups/phase3/you_or_me_buttons.html`
- Show buttons repositioned higher (with measurements)
- Show larger tap targets
- Optional: show swipe gesture alternative

**Files to modify:**
- `app/lib/screens/you_or_me_match_game_screen.dart`

---

### 3.2 Button Emoji Removal

**Issues identified:**
- 🙋 and 🙋‍♀️ emojis on buttons add visual clutter
- Just names would be cleaner

**Current state:**
- 28px (Editorial) / 32px (Us2) emojis above names
- Labels truncate after 8 characters

**UX Recommendations:**

| Issue | Recommendation | Priority |
|-------|----------------|----------|
| Remove emojis | Show names only, larger font | High |
| Button design | Use color differentiation instead (You = pink, Partner = blue?) | Medium |
| Name display | Increase font size now that emoji is removed | Medium |

**Mockup required:** `mockups/phase3/you_or_me_buttons.html` (same file as 3.1)
- Show buttons without emojis
- Show color-coded design
- Show larger name text

**Files to modify:**
- `app/lib/screens/you_or_me_match_game_screen.dart`

---

## Phase 4: Linked (Crossword) Game

### 4.1 Tutorial Requirement

**Issues identified:**
- No tutorial for users unfamiliar with mobile crosswords
- Gesture controls not explained
- Clue display not intuitive

**Current state:**
- No in-game tutorial
- Only partner-first dialog shown
- User must discover mechanics through trial/error

**UX Recommendations:**

| Issue | Recommendation | Priority |
|-------|----------------|----------|
| First-time tutorial | Add 3-4 step overlay tutorial on first play | High |
| Tutorial content | 1) Tap clue to see full text, 2) Tap letters to type, 3) Partner takes turns, 4) Complete puzzle together | High |
| Skip option | Allow "Skip tutorial" for experienced users | Medium |

**Mockup required:** `mockups/phase4/linked_tutorial.html`
- Show 3-4 tutorial overlay steps
- Show hand pointer indicators on key elements
- Show skip button position

**Files to modify:**
- `app/lib/screens/linked_game_screen.dart`
- `app/lib/widgets/` (new tutorial overlay widget)
- Hive storage (track if tutorial seen)

---

### 4.2 Clue Visibility

**Issues identified:**
- DA (👎) emoji in clues too small to read
- Need "tap to see clue bigger" hint

**Current state:**
- Emoji clues rendered inline at puzzle positions
- Clue dialog available but not obvious
- No hint text about tapping

**UX Recommendations:**

| Issue | Recommendation | Priority |
|-------|----------------|----------|
| Emoji size | Increase clue emoji size OR use text description | High |
| Tap affordance | Add subtle "Tap clue" label on first encounter | Medium |
| Clue dialog | Show automatically on long-press OR double-tap | Low |

**Mockup required:** `mockups/phase4/linked_clues.html`
- Show larger clue emoji
- Show "Tap to enlarge" hint
- Show expanded clue dialog design

**Files to modify:**
- `app/lib/screens/linked_game_screen.dart`
- Clue cell rendering logic

---

## Phase 5: Word Search Game

### 5.1 Diagonal Selection Bug

**Issues identified:**
- Words from bottom-left to top-right don't register
- Known bug, still present

**Current state:**
- 8-direction angle snapping: 0°, 45°, 90°, 135°, 180°, 225°, 270°, 315°
- Two-phase gesture: angle detection → direction lock
- Angle calculation: `atan2` → degrees → snap to nearest 45°

**Technical analysis:**
The diagonal selection uses angle snapping at `(angleDeg + 22.5) ~/ 45 * 45`. The issue may be:
- Bottom-left to top-right = ~315° or ~-45°
- Potential: negative angle handling, or angle wrapping at 360°

**UX Recommendations:**

| Issue | Recommendation | Priority |
|-------|----------------|----------|
| Fix diagonal bug | Debug angle calculation for 315° direction | Critical |
| Testing | Add test coverage for all 8 directions | High |
| Visual feedback | Show direction indicator during drag | Low |

**No mockup needed** - this is a code bug fix

**Files to modify:**
- `app/lib/screens/word_search_game_screen.dart` (lines 1012-1172)

---

## Phase 6: Steps (Rename from "Steps Together")

### 6.1 Feature Rename & Messaging Overhaul

**Root cause identified:**
- The word "together" fundamentally implies physical proximity
- Users think they need to walk side-by-side with their partner
- No amount of explanatory copy can overcome this semantic issue
- Feature underutilized due to this core misunderstanding

**Solution:** Rename feature to just **"Steps"** and remove "together" from ALL copy. Plus compact intro layout.

**Layout changes (to avoid scrolling):**
- ❌ Remove sneaker emoji (saves vertical space)
- ❌ Remove Tips card from intro (move to counter screen)
- ✅ Merge clarification into subtitle (single text block)
- ✅ Shorten "How it works" step text

**Current → New naming:**

| Location | Current | New |
|----------|---------|-----|
| Feature name | "Steps Together" | "Steps" |
| Nav/menu | "Steps Together" | "Steps" |
| Intro title | "Steps Together" | "Steps" |

**Current → New messaging:**

| Location | Current Text | New Text |
|----------|--------------|----------|
| Intro subtitle | "Walk together, earn together." | "Walk more, earn more. Your steps automatically combine with your partner's. You don't need to be next to each other!" |
| How it works | Long text | Shortened: "Connect Apple Health" / "Walk throughout the day" / "Claim your reward tomorrow" |
| Counter < 50% | "Keep walking together!" | "Keep walking!" |
| Counter encouragement | (varies) | "Every step counts toward your daily goal." |
| Tips section | "Take a walk together after dinner" | "Take a walk after dinner" or "Go for a morning walk" (shown on counter screen, not intro) |

**Key messaging principles:**
1. Never use "together" - it implies physical proximity
2. Emphasize "automatic" syncing - removes coordination pressure
3. Focus on individual action - "your steps count"
4. Partner mentioned only in context of combining/syncing

**Mockup required:** `mockups/phase6/steps_messaging.html`
- Show compact intro screen: no emoji, no tips card, merged subtitle
- Show "How it works" with shortened step text
- Show counter screen with tips (moved from intro) and no "together" language

**Files to modify:**
- `app/lib/screens/steps_intro_screen.dart`
- `app/lib/screens/steps_counter_screen.dart`
- `app/lib/widgets/brand/us2/us2_bottom_nav.dart` (nav label)
- Any other file referencing "Steps Together" in UI copy

---

## Mockup Checklist

| Phase | Mockup File | Status |
|-------|-------------|--------|
| 1.1 | `mockups/phase1/onboarding_screen.html` | [x] Complete |
| 1.2 | `mockups/phase1/welcome_quiz_intro.html` | [x] Complete |
| 1.3 | `mockups/phase1/welcome_quiz_results.html` | [x] Complete |
| 1.4 | `mockups/phase1/lp_intro_overlay.html` | [x] Complete |
| 1.5 | `mockups/phase1/paywall_success.html` | [x] Complete |
| 2.1 | `mockups/phase2/quiz_instructions.html` | [x] Complete |
| 2.2 | `mockups/phase2/quiz_results_lp.html` | [x] Complete |
| 3.1-3.2 | `mockups/phase3/you_or_me_buttons.html` | [x] Complete |
| 4.1 | `mockups/phase4/linked_tutorial.html` | [x] Complete |
| 4.2 | `mockups/phase4/linked_clues.html` | [x] Complete |
| 6.1 | `mockups/phase6/steps_messaging.html` | [x] Complete |

**Note:** Phase 4.3 (Linked Difficulty Progression) moved to separate project: `docs/plans/LINKED_DIFFICULTY_PROGRESSION.md`

**Note:** Phase 5 (Word Search diagonal bug) requires code fix, not mockup.

---

## Design Decision Required

Before proceeding, please confirm:

1. **LP Match Bonus:** Should matching quiz answers give bonus LP, or keep participation-only rewards?
2. **You or Me swipe:** Add swipe gesture, or buttons-only?
3. **Linked tutorial:** Skippable or mandatory for first-time?

---

## Next Steps

### For Design Review:
1. [x] Review this plan document
2. [x] Make design decisions above
3. [x] Create HTML mockups (11 files)
4. [x] Review mockups with stakeholder

### For Implementation (Coding Agent):

**IMPORTANT: Follow the HTML mockups exactly. Each file has a task list at the bottom.**

1. [ ] **Phase 1.1** - Open `mockups/phase1/onboarding_screen.html`, complete all tasks in the Implementation Task List
2. [ ] **Phase 1.2** - Open `mockups/phase1/welcome_quiz_intro.html`, complete all tasks in the Implementation Task List
3. [ ] **Phase 1.3** - Open `mockups/phase1/welcome_quiz_results.html`, complete all tasks in the Implementation Task List
4. [ ] **Phase 1.4** - Open `mockups/phase1/lp_intro_overlay.html`, complete all tasks in the Implementation Task List
5. [ ] **Phase 1.5** - Open `mockups/phase1/paywall_success.html`, complete all tasks in the Implementation Task List
6. [ ] **Phase 2.1** - Open `mockups/phase2/quiz_instructions.html`, complete all tasks in the Implementation Task List
7. [ ] **Phase 2.2** - Open `mockups/phase2/quiz_results_lp.html`, complete all tasks in the Implementation Task List
8. [ ] **Phase 3** - Open `mockups/phase3/you_or_me_buttons.html`, complete all tasks in the Implementation Task List
9. [ ] **Phase 4.1** - Open `mockups/phase4/linked_tutorial.html`, complete all tasks in the Implementation Task List
10. [ ] **Phase 4.2** - Open `mockups/phase4/linked_clues.html`, complete all tasks in the Implementation Task List
11. [ ] **Phase 5** - Fix Word Search diagonal bug (code only, no mockup)
12. [ ] **Phase 6** - Open `mockups/phase6/steps_messaging.html`, complete all tasks in the Implementation Task List

### Final Verification:
13. [ ] Compare every screen against its "After" mockup
14. [ ] Run app and verify no regressions
15. [ ] Playtest again with same flow

---

*Document created: 2025-01-20*
*Author: Claude (Senior UX Mobile Designer role)*
*Updated: 2025-01-20 - Added coding agent instructions and task lists*

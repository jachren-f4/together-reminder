# Mockup Build Documentation

**Date:** 2025-02-07
**Location:** `mockups/us20variants/`

---

## How These Mockups Were Built

### Design System Source

All mockups are built to match the existing Us 2.0 design system. The design tokens were extracted from:

1. **`mockups/us2-home-v2.html`** — The canonical home screen mockup, which established the visual language
2. **`app/lib/config/brand/us2_theme.dart`** — The Flutter implementation of the design tokens
3. **`app/lib/widgets/brand/us2/us2_section_header.dart`** — The ribbon-style section header pattern

### Key Design Tokens Used

| Token | Value | Source |
|-------|-------|--------|
| Background gradient | `#FFD1C1 → #FFF5F0` | `us2_theme.dart:15-16` |
| Primary pink | `#FF5E62` | `us2_theme.dart:19` |
| Accent gradient | `#FF6B6B → #FF9F43` | `us2_theme.dart:20-21` |
| Card salmon | `#FF7B6B → #FF6B5B` | `us2_theme.dart:24-25` |
| Cream | `#FFF8F0` | `us2_theme.dart:26` |
| Beige (ribbon) | `#F5E6D8` | `us2_theme.dart:27` |
| Text dark | `#3A3A3A` | `us2_theme.dart:30` |
| Text medium | `#5A5A5A` | `us2_theme.dart:31` |
| Text light | `#707070` | `us2_theme.dart:32` |
| Logo font | Pacifico, 52px | `us2_theme.dart:62,67` |
| Heading font | Playfair Display | `us2_theme.dart:63` |
| Body font | Nunito | `us2_theme.dart:64` |

### Component Patterns Matched

| Component | Source | How Matched |
|-----------|--------|-------------|
| Logo glow | `us2_theme.dart:150-171` | Multi-layer text-shadow in CSS |
| Ribbon section header | `us2_section_header.dart:47-63` | CSS triangle border trick + gradient line |
| Quest card carousel | `us2-home-v2.html:308-394` | Horizontal scroll, 82% width, snap |
| Quest pill button | `us2-home-v2.html:367-394` | White-to-cream gradient, pink glow shadow |
| Connection bar | `us2-home-v2.html:174-258` | Pink-orange gradient, gold fill, heart with sparkles |
| Avatar badges | `us2-home-v2.html:121-153` | Positioned absolute, text glow effect |
| Bottom nav gradient | `us2-home-v2.html:469-475` | Gradient clip on active icons |

---

## Mockup Inventory

### 1. `index.html` — Hub Page
- Simple card grid linking to all mockups
- Categorized: New Screens, Full Flows, Modified Screens
- Uses same design tokens for visual consistency

### 2. `partner-name-entry.html` — Replaces Pairing Screen
**What it shows:** The new onboarding step where the user enters their partner's name instead of a pairing code.

**Decisions made:**
- Single text input, not a complex form — keep it as fast as pairing code entry
- Subtitle "You'll play together on this phone. No download needed!" — addresses the key friction point
- "One phone, two players, zero friction" badge — reinforces the value prop
- Success screen shows both avatars with heart — immediate emotional reward
- Step indicator shows "3 of 5" — same position in flow as pairing was

**What it doesn't show:** Birthday entry (kept as optional, same as current), email auth (unchanged).

### 3. `handoff-screen.html` — The Core New Element
**What it shows:** Three variants of the pass-the-phone screen for competitive games (quizzes, You or Me).

**Three variants explored:**

| Variant | Concept | Strengths | Weaknesses |
|---------|---------|-----------|------------|
| **A: Warm Glow** | Dark background, floating avatar, glowing orb, "I'M READY" button | Dramatic, builds anticipation, feels premium | Might feel slow for repeat use |
| **B: Flip Card** | Physical card metaphor, Player 1 done → flip → Player 2's turn | Tactile, fun animation, communicates handoff clearly | Takes more screen interaction |
| **C: Dramatic Reveal** | Dark with spotlight, partner's name in big Pacifico script, swipe to start | Most theatrical, great for the first few times | Swipe gesture may not be intuitive for all users |

**Decision:** Variant A (Warm Glow) recommended as default. It's the clearest UX — one big button, partner name and avatar prominent, can't accidentally see answers.

**Key design decisions:**
- **Dark background** (not the usual warm gradient) — creates visual break between Player 1 and Player 2 turns, makes it impossible to peek at previous answers
- **"I'M READY" button instead of auto-advance** — partner actively opts in, no accidental screen peek
- **"No peeking! 👀" text** — playful tone that sets expectations
- **No back button** — PopScope equivalent in CSS, prevents returning to Player 1's answers

### 4. `quiz-flow.html` — Complete Classic Quiz Flow
**What it shows:** Full interactive flow: Intro → Player 1 answers 5 Qs → Handoff → Player 2 answers 5 Qs → Instant Results.

**Decisions made:**
- **Flow progress bar** at top (5 dots) shows the overall journey, not just questions
- **Player indicator chip** in header shows whose turn it is with colored dot (pink for P1, blue for P2)
- **"Play Together" button** on intro (not "Start Quest") — language reinforces the togetherness
- **Intro shows both players** with arrow between them — communicates the pass flow visually
- **5 mock questions** with real relationship content — demonstrates the actual experience
- **Results include "discuss" prompts** for mismatches — unique to single-phone since both are present
- **Instant results** — no waiting animation, no polling, results appear immediately after Player 2 submits

**What it doesn't show:** LP animation (would need more complex state), sound/haptics (HTML limitation).

### 5. `you-or-me-flow.html` — Complete You or Me Flow
**What it shows:** Full interactive flow with card swiping animations and stamp effects.

**Decisions made:**
- **Card swipe animation** preserved from current app — swipe left for "You", right for "Me"
- **Stamp effect** (emoji appears on card before it swipes away) — tactile feedback
- **Same handoff pattern** as quiz — consistency across games
- **Results show "discuss" prompts** for disagreements — same pattern as quiz
- **4 dilemmas** (matching current app count) — no change to game length

### 6. `home-screen.html` — Modified Home Screen (v2)
**What it shows:** The real Us 2.0 home screen with minimal single-phone modifications.

**Design principle: Minimal changes.** The home screen should look virtually identical to the current two-device version. Changes are surgical:

**Changes made (single-phone mode):**
1. **Mode badge** — Small translucent bar below connection bar: "Playing on one phone" with "Add device →" link
2. **Quest button text** — "Play Together" instead of "Start Quest" / "Begin Together" / "Play Now"
3. **Steps Together locked** — Greyed out with lock icon, "Requires two devices" text, "Set up partner's phone →" button
4. **Bottom nav** — "Poke" tab replaced with "Invite" tab (📱 icon)

**What is NOT changed:**
- Logo, glow effect, heart — identical
- Day label — identical
- Avatars and badges — identical (partner name from local entry instead of server, but visually same)
- Connection bar — identical (LP is couple-level, works the same)
- Section headers (ribbon style) — identical
- Quest card visual design — identical (carousel, salmon gradient, pill button glow)
- Side quest cards — identical for Linked and Word Search

**Interactive compare toggle** at top lets you switch between "Single Phone" and "Two-Device (current)" to see exactly what changes.

**Design tokens matched from `us2_theme.dart`:**
- All CSS variables map directly to the Dart constants
- Ribbon header uses the same triangle cutout technique as `_RibbonPainter`
- Quest button uses the same white-to-cream gradient with pink glow shadow
- Connection bar uses the same gold progress fill with animated heart and sparkles

### 7. `upgrade-prompt.html` — Two-Device Upgrade Flow
**What it shows:** Two screens: the benefits pitch and the pairing code generation.

**Decisions made:**
- **Benefits-first approach** — explain what they gain (Steps, Poke, Anytime play, Notifications) before showing the code
- **"Maybe later" option** prominent — no pressure
- **Pairing code screen reuses existing code system** — same 6-character code, same server flow
- **Step-by-step instructions** for partner — reduces friction
- **"Share Code" button** — uses native share sheet (in real implementation)
- **"Keep playing" note** — reassures user they can continue on one phone while waiting

---

## Mockups NOT Created (and why)

| Screen | Why Skipped |
|--------|-------------|
| Linked couch co-op | Current Linked game screen is already cooperative — just remove "whose turn" indicator. Not enough visual change to warrant a mockup. |
| Word Search co-op | Same reasoning as Linked. |
| Welcome Quiz | Identical to quiz-flow.html but with 10 questions instead of 5. Same handoff pattern. |
| Profile screen | Minimal changes (just remove partner device status). |
| Settings screen | Standard settings list with "Set up partner's device" option. Not visually interesting enough for mockup. |
| Journal | No changes at all. |

---

## Key UX Decisions Log

| # | Decision | Options Considered | Chosen | Rationale |
|---|----------|-------------------|--------|-----------|
| 1 | Handoff screen background | Light (match app) vs Dark | **Dark** | Creates visual break, prevents answer peeking, builds drama |
| 2 | Handoff interaction | Auto-timer vs Tap button vs Swipe | **Tap button** | Most reliable, works for all ages, clear consent to start |
| 3 | Linked/WS in single phone | Pass-the-phone turns vs Couch co-op | **Couch co-op** | These are cooperative games, forced turns add friction not fun |
| 4 | Quest button text | "Start" vs "Play" vs "Play Together" | **"Play Together"** | Reinforces togetherness, differentiates from async mode |
| 5 | Steps Together handling | Remove vs Replace vs Lock with upgrade | **Lock with upgrade** | Creates natural funnel to pairing without blocking content |
| 6 | Bottom nav change | Remove Poke tab vs Replace with Invite | **Replace with Invite** | Keeps 5-tab layout, provides discoverable upgrade path |
| 7 | Home screen changes | Major redesign vs Minimal surgical | **Minimal surgical** | Users who upgrade from one phone to two phones should feel continuity |
| 8 | App architecture | Separate app vs Same app hybrid | **Same app hybrid** | One codebase, one listing, graceful escalation from single to paired |
| 9 | After pairing, single-phone | Remove single-phone option vs Keep both | **Keep both** | Paired users sitting together should still be able to play on one phone |
| 10 | Per-game mode choice | Global toggle vs Per-game choice | **Per-game choice** | More flexible, matches real-world usage (sometimes together, sometimes apart) |

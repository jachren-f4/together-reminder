# Single-Phone Variant - UX Plan

**Date:** 2025-02-07
**Updated:** 2025-02-07
**Status:** Draft v3
**Goal:** Everyone starts on one phone. Pairing is optional, available anytime. Even after pairing, single-phone mode remains available.

---

## Table of Contents

1. [Core Concept](#core-concept)
2. [The Hybrid Model](#the-hybrid-model)
3. [Server Architecture: Two Users Always](#server-architecture-two-users-always)
4. [Onboarding Flow](#onboarding-flow)
5. [Home Screen Changes](#home-screen-changes)
6. [The Pass-the-Phone Pattern](#the-pass-the-phone-pattern)
7. [Game-by-Game UX](#game-by-game-ux)
8. [Features by Mode](#features-by-mode)
9. [Features Modified](#features-modified)
10. [Upgrade to Two Devices](#upgrade-to-two-devices)
11. [Open Questions](#open-questions)
12. [Critical Review: Issues Found](#critical-review-issues-found)

---

## Core Concept

**One phone, two players, zero friction. Two phones whenever you want.**

Not a separate app. Not a separate mode toggle. The same Us 2.0 app starts as single-phone for everyone, and at any point the couple can pair a second device. Even after pairing, they can still grab one phone and play together on the couch.

The tone shifts from "you need two phones to use this" to "grab a phone and play."

### Key Principles

- **Everyone starts on one phone.** No pairing during onboarding. Just enter names and play.
- **Pairing is an upgrade, not a gate.** Available anytime from Settings. Never required.
- **Both modes coexist.** After pairing, users can play on one phone OR two phones. It's a per-session choice.
- **No waiting screens in single-phone mode.** Both players are present. Results are instant.
- **Privacy between turns.** Player 1's answers are hidden before Player 2 plays.
- **Same content, same LP, same progress.** Mode doesn't affect rewards or game state.

---

## The Hybrid Model

This is NOT two separate apps or a hard mode switch. It's one app with graceful escalation:

### Stage 1: Unpaired (default for all new users)
- Single phone only
- Pass-the-phone for quizzes
- Couch co-op for puzzles
- Steps Together locked (needs two devices)
- No poke feature (partner is next to you)
- No polling or waiting screens

### Stage 2: Paired (after partner installs + enters code)
- Both modes available at all times
- When starting a game, both options are there:
  - **"Play Together"** → single-phone pass-the-phone flow (no waiting)
  - **"Play on My Own"** → async two-device flow (waiting screens, polling, poke)
- Steps Together unlocks
- Poke feature activates
- Push notifications for partner activity
- All previous progress preserved

### How mode is detected (not a toggle)
- **Phantom partner:** Server has two users, but partner is a phantom account (`is_phantom_partner = true`) → single-phone only, no async option
- **Real partner (paired):** Partner has their own device → both modes available
- **Paired, partner offline:** Show "Play Together" prominently, "Play on My Own" available
- **Paired, partner online:** Both options equal
- The choice happens naturally per game session, not as a global setting
- **Key:** The server always has two real user IDs. "Unpaired" just means partner hasn't claimed their account yet.

---

## Server Architecture: Two Users Always

### Decision: The backend always has two real users

Even in single-phone mode, the server creates and maintains two real `auth.users` entries and a real `couples` row. This means:

- **Zero schema changes.** `couples.user1_id` and `user2_id` remain `NOT NULL` with FK constraints.
- **All 20+ existing API endpoints work unchanged.** They look up the couple, calculate partnerId, store answers per user — exactly as today.
- **Game history is complete from day one.** Every quiz answer, You-or-Me pick, and Linked turn is correctly attributed to the right user. If the partner later installs on their own phone, all their history is already there.
- **LP system unchanged.** Still couple-level `couples.total_lp`, still daily grants per content type.

### The Phantom User

When User 1 enters their partner's name during onboarding, the server creates a **phantom user** — a real Supabase Auth account that nobody logs into.

| Field | Value |
|-------|-------|
| `email` | `phantom-{uuid}@internal.togetherremind.app` |
| `password` | Random 64-char string (nobody knows it) |
| `raw_user_meta_data.full_name` | Partner's name (entered by User 1) |
| `raw_user_meta_data.is_phantom` | `true` |
| `raw_user_meta_data.created_by` | User 1's ID |

Then the server creates the `couples` row:
```
couples.user1_id = User 1 (real, authenticated)
couples.user2_id = Phantom user (real row, nobody logs in)
couples.total_lp = 0
```

From this point, every game submission works identically to today's flow. The only difference: in single-phone mode, User 1's device submits answers for *both* users in a single API call.

### Phantom User Lifecycle

```
1. CREATION (Onboarding)
   User 1 enters partner name → API creates phantom user + couple
   ↓
2. GAMEPLAY (Single-phone)
   User 1's device sends both answer sets in one API call
   Server writes User 1's answers under user1_id, partner's under user2_id (phantom)
   LP awarded to couple. History tracked per user. Everything normal.
   ↓
3. OPTIONAL: PARTNER INSTALLS (Upgrade to two devices)
   Partner downloads app → creates their own real account → enters pairing code
   Server performs atomic merge:
     - Replace phantom user2_id with real user2_id across all tables
     - Transfer game history, LP transactions
     - Delete phantom auth account
     - Partner's device now syncs all history
   ↓
4. POST-MERGE
   Both modes available. All history preserved. Partner sees everything
   they "played" on one phone, now attributed to their real account.
```

### Concise Change List: Client-Server Communication

**New endpoint:**
1. `POST /api/couples/create-with-phantom` — Called during onboarding after auth. Takes partner's name, creates phantom `auth.users` row + `couples` row. Returns couple ID + phantom user ID.

**Modified endpoints:**
2. All game submit endpoints (`quiz/submit`, `you-or-me/submit`, `linked/submit`, `word-search/submit`, `welcome-quiz/submit`) — Accept optional `onBehalfOf: userId` field. Server validates caller is coupled with that user and user is phantom or couple allows together-mode. Writes answers under that user ID instead of the caller's.

**Modified flow:**
3. `POST /api/couples/join` (partner enters pairing code) — After linking, runs the atomic merge: replaces phantom `user2_id` with real user ID across all tables, deletes phantom auth account.

**Client-side only (no server changes):**
4. Submit Player 1's answers immediately after they finish (before handoff screen).
5. Submit Player 2's answers with `onBehalfOf` after they finish.
6. Skip polling/waiting logic when in together-mode.
7. Detect phantom vs real partner to show/hide async features.

### Single-Phone API Contract (Detail)

Single-phone mode uses **two separate API calls** — the same endpoints as two-device mode. The only difference: both calls come from User 1's device.

**After Player 1 finishes:**
```
POST /api/sync/quiz/submit
Auth: User 1's JWT
Body: {
  sessionId: "...",
  answers: [2, 1, 3, 0, 2]
}
```
→ Server stores Player 1's answers. Returns "waiting for partner" (normal).

**After Player 2 finishes (same device, seconds later):**
```
POST /api/sync/quiz/submit
Auth: User 1's JWT
Body: {
  sessionId: "...",
  answers: [2, 3, 3, 1, 2],
  onBehalfOf: "user2-uuid"
}
```
→ Server validates User 1 is coupled with User 2, stores Player 2's answers under `user2_id`. Both answered → results + LP.

**Why two calls instead of one:**
- **Existing endpoints work almost unchanged** — just add `onBehalfOf` support
- **Player 1's answers are submitted immediately** (before handoff), so they're server-safe even if the app is killed during Player 2's turn
- **Normal game completion logic triggers naturally** — "both answered" detection, LP award, etc.
- **Server doesn't need to know about "together mode"** as a concept — it just sees two submissions arriving quickly

**The `onBehalfOf` field:**
- Only accepted when the caller is in a couple with the target user
- Only accepted when the target user is a phantom OR the couple has opted into together-mode
- Rejected for any other combination (prevents abuse)

### The Merge: Phantom → Real User

When the partner installs and enters a pairing code, the server runs an atomic transaction:

```sql
BEGIN;

-- 1. Update the couple
UPDATE couples SET user2_id = $realUserId WHERE id = $coupleId;

-- 2. Update user_couples lookup
UPDATE user_couples SET user_id = $realUserId WHERE user_id = $phantomId;

-- 3. Update all game history tables
UPDATE quiz_sessions SET player2_id = $realUserId WHERE player2_id = $phantomId;
UPDATE you_or_me_sessions SET player2_id = $realUserId WHERE player2_id = $phantomId;
UPDATE linked_matches SET player2_id = $realUserId WHERE player2_id = $phantomId;
UPDATE word_search_matches SET player2_id = $realUserId WHERE player2_id = $phantomId;

-- 4. Update LP transaction audit trail
UPDATE love_point_transactions SET user_id = $realUserId WHERE user_id = $phantomId;

-- 5. Update any turn-based state
UPDATE linked_matches SET current_turn_user_id = $realUserId
  WHERE current_turn_user_id = $phantomId;
UPDATE word_search_matches SET current_turn_user_id = $realUserId
  WHERE current_turn_user_id = $phantomId;

-- 6. Delete phantom auth account
DELETE FROM auth.users WHERE id = $phantomId;

COMMIT;
```

**Key properties:**
- Atomic — either all tables update or none do
- Idempotent — safe to retry if the transaction fails mid-way
- All game history survives — partner sees their full play history on their new device
- `couples.total_lp` is untouched (it's couple-level, not user-level)

### What Doesn't Change

| Component | Change needed? |
|-----------|---------------|
| `couples` table schema | No |
| Game session tables | No |
| LP award logic (`api/lib/lp/`) | No |
| Daily quest generation | No |
| Unlock system | No |
| Journal / history display | No |
| Connection bar / LP counter | No |

### What's New

| Component | What's added |
|-----------|-------------|
| Onboarding API | New endpoint: create phantom user + couple |
| Game submission | New `-together` endpoints (thin wrappers around existing logic) |
| Pairing flow | Merge logic (phantom → real user, atomic transaction) |
| Flutter app | Together-mode submission calls, handoff screen, mode detection |
| `couples` table | Optional: `is_phantom_partner BOOLEAN DEFAULT false` for easy querying |

---

## Onboarding Flow

### Current (Two-Device)
```
Splash → Name → Email → OTP → Anniversary → Pairing Code → Welcome Quiz → LP Intro → Paywall → Home
                                                    ↑
                                              THE WALL
```

### Single-Phone
```
Splash → Your Name → Partner's Name → Email → OTP → Anniversary → Welcome Quiz → LP Intro → Paywall → Home
```

### Screen-by-Screen

**1. Splash / Onboarding Screen**
- Same as current. "US 2.0" logo, "GET STARTED" button.
- No changes needed.

**2. Your Name Screen (was: NameEntryScreen)**
- "What's your name?" — same as current.
- Single text field + continue.

**3. Partner's Name Screen (NEW - replaces PairingScreen)**
- "What's your partner's name?"
- Single text field.
- Subtitle: *"You'll play together on this phone"*
- This is the moment we capture the partner identity without requiring them to download anything.
- Optional: partner birthday field (for future personalization).

**4. Email + Auth**
- Same as current. One account for the phone owner.
- After auth, server creates a **phantom user** for the partner (using the name from step 3) and a `couples` row linking both. This happens invisibly — the user just sees "Setting up your couple..." for a moment.

**5. Anniversary Screen**
- Same as current. Optional date picker.

**6. Welcome Quiz**
- First use of the **Pass-the-Phone pattern** (see below).
- Both partners answer 10 questions, passing the phone between them.
- Immediate results after both complete. No waiting screen.

**7. LP Intro → Paywall → Home**
- Same as current. No changes needed.

---

## Home Screen Changes

### What Stays the Same
- Hero section (logo, day counter, LP bar)
- Avatar section (both names displayed — sourced from local profile instead of server pair)
- Daily quests section (3 quest cards)
- Side quests section (Linked, Word Search)
- Unlock progression chain
- LP counter and connection bar

### What Changes

| Element | Current | Single-Phone |
|---------|---------|-------------|
| Avatar section | Both avatars from server profiles | Both names from local setup |
| Quest status badges | "YOU ANSWERED" / "PARTNER ANSWERED" / "RESULTS READY" | "READY TO PLAY" / "COMPLETED" |
| Poke tab (bottom nav) | Send poke to partner | **Removed** — replaced with something else or hidden |
| Steps Together card | Both partners' step rings | **Removed** from single-phone mode |
| Polling indicators | Real-time partner status | **Removed** — no async state to poll |

### Quest Card States

Single-phone mode still needs status badges. Player 1 might answer and close the app before handing to Player 2 (battery dies, gets interrupted, etc.). The quest card must communicate this.

| State | Badge | Button | When |
|-------|-------|--------|------|
| Available | — | "PLAY TOGETHER" | Neither player has answered |
| P1 answered, waiting for P2 | "PASS TO [PARTNER]" | "CONTINUE" | P1 submitted, app reopened before P2 played |
| Completed today | "COMPLETED ✓" | Disabled or "PLAY AGAIN" | Both answered, results shown |
| Locked | "🔒" | "LOCKED" | Feature not yet unlocked |
| Cooldown (Linked/WS) | "⏱ 2h 30m" | Disabled | Cooldown active |
| P1's turn (Linked/WS) | "YOUR TURN" | "CONTINUE" | Long game, Player 1's turn next |
| P2's turn (Linked/WS) | "PASS TO [PARTNER]" | "CONTINUE" | Long game, Player 2's turn next |

The key new badge is **"PASS TO [PARTNER]"** — it tells whoever opens the app that the phone needs to be handed over. Tapping "CONTINUE" shows the handoff screen directly.

### Bottom Navigation

| Tab | Current | Single-Phone |
|-----|---------|-------------|
| Home | Same | Same |
| Journal | Same | Same |
| Poke | Send poke | Same — but tapping "Poke" with phantom partner shows upgrade prompt |
| Profile | Same | Same (shows both names, shared LP) |
| Settings | Same | Same + "Set up partner's device" option |

**No layout changes.** Bottom nav stays identical. Two-device features (Poke, Steps Together) remain visible but show a contextual upgrade prompt when the user tries to use them with a phantom partner.

---

## The Pass-the-Phone Pattern

Not a new screen. The existing waiting screens and turn dialogs are reused with a different behavior in together-mode.

### The Flow

```
┌─────────────────────────┐
│  First Player plays       │
│  (answers questions)      │
│                          │
│  Taps "Done" / "Submit"  │
│  → answers sent to server │
└────────────┬─────────────┘
             │
             ▼
┌─────────────────────────┐
│  EXISTING WAITING SCREEN │
│  (modified for together)  │
│                          │
│  "Pass the phone to      │
│   [Partner Name]"         │
│                          │
│  [Partner's avatar/emoji] │
│                          │
│  "I'M READY" button       │
│  (replaces polling)       │
└────────────┬─────────────┘
             │
             ▼
┌─────────────────────────┐
│  Second Player plays      │
│  (answers questions)      │
│                          │
│  Taps "Done" / "Submit"  │
│  → answers sent with      │
│    onBehalfOf             │
└────────────┬─────────────┘
             │
             ▼
┌─────────────────────────┐
│  🎉 RESULTS SCREEN 🎉   │
│                          │
│  Shown immediately.       │
│  Both players see results │
│  together on the couch.   │
└─────────────────────────┘
```

### How Existing Screens Are Reused

| Game type | Existing component | Current behavior | Together-mode behavior |
|-----------|-------------------|-----------------|----------------------|
| Quizzes / You or Me | `game_waiting_screen.dart` | Polls server for partner completion | Shows "Pass to [Partner]" + "I'M READY" button. No polling. |
| Linked | `turn_complete_dialog.dart` | "Turn submitted, waiting for partner" | "Pass to [Partner]" + "I'M READY" button. No polling. |
| Word Search | `turn_complete_dialog.dart` | Same as Linked | Same as Linked |

### Handoff Behavior Details

**What changes on the existing waiting screen / dialog:**
- Replace polling logic with a static "I'M READY" button
- Replace "Waiting for partner..." text with "Pass to [Partner Name]"
- Add playful subtitle: *"No peeking! 👀"*
- Show partner's avatar (large, centered)
- Disable back button (PopScope) — can't go back to see first player's answers

**Privacy:**
- First player's answers are already submitted to server and off-screen
- Back button disabled — can't navigate back to the game screen
- The waiting screen already fully covers the game screen

**Haptics:**
- Light haptic when waiting screen appears
- Medium haptic when "I'M READY" is tapped

### Who Goes First

In single-phone mode, the `first_player_id` setting (from Settings → "Who goes first") determines the turn order for **every game**:

- **Player 1** (first player) always answers first
- **Player 2** always answers second (after handoff)
- This applies to all games: quizzes, You or Me, Linked turns, Word Search turns

Previously in two-device mode, either partner could independently start a quest on their own phone — turn order didn't matter for short games since both played asynchronously. In single-phone mode, the setting has real impact: it determines who picks up the phone first every session.

**Default:** The user who created the account (User 1) is the first player. Changeable anytime in Settings.

**Quest card behavior:** When someone taps "PLAY TOGETHER" on a quest card, the game starts with the first player's turn. The app shows their name: "🎯 [First Player], you're up!" — no ambiguity about who goes first.

---

## Game-by-Game UX

### Classic Quiz (5 questions)

**Current:** Player 1 answers 5 Qs → submit → waiting screen → Player 2 answers on their phone → results.

**Single-Phone:**
```
Quiz Intro ("PLAY TOGETHER")
  ↓
"🎯 [First Player], you're up!" (determined by "who goes first" setting)
  ↓
First Player answers 5 questions (same swipe/tap UI)
  ↓
First Player taps "Submit" → answers sent to server immediately
  ↓
🔒 Handoff Screen: "Pass to [Second Player]!"
  ↓
Second Player taps "I'M READY"
  ↓
"🎯 [Second Player], your turn!"
  ↓
Second Player answers same 5 questions
  ↓
Second Player taps "Submit" → answers sent with onBehalfOf
  ↓
🎉 Instant Results: alignment count, question-by-question comparison
  ↓
Both look at results together. "+30 LP" award.
  ↓
"Back to Home"
```

**Key difference:** No waiting screen. Results are instant. The 5-second polling loop is gone.

---

### Affirmation Quiz (5 questions)

Identical flow to Classic Quiz, just different content. Same pass-the-phone pattern.

---

### You or Me (4 dilemmas)

**Current:** Player 1 picks You/Me for 4 cards → submit → waiting → Player 2 picks → results.

**Single-Phone:**
```
You or Me Intro ("PLAY TOGETHER")
  ↓
Player 1: "Who does this describe more?"
  ↓
Player 1 swipes through 4 dilemma cards, picks You or Me
  ↓
Player 1 taps "Submit"
  ↓
🔒 Handoff Screen: "Pass to [Player 2]!"
  ↓
Player 2 taps "I'M READY"
  ↓
Player 2 swipes through same 4 dilemmas
  ↓
🎉 Instant Results: "You matched on 3 of 4!"
  ↓
Per-dilemma breakdown shown. Both react together.
```

**Bonus opportunity:** After results, show a "Discuss" prompt for each dilemma where they disagreed. *"You disagreed on this one — talk about it!"* This is unique to single-phone since both people are literally sitting together.

---

### Linked (Arroword Puzzle)

**Current:** Player 1 places 5 letters → submit turn → wait for partner → Player 2 places letters → repeat until puzzle done.

**Single-Phone: Same handoff pattern as quizzes.**
```
Linked Intro ("PLAY TOGETHER")
  ↓
Player 1 drags 5 letters from rack to grid
  ↓
"Submit Turn"
  ↓
🔒 Handoff: "Pass to [Player 2]!"
  ↓
Player 2 taps "I'M READY"
  ↓
Player 2 drags 5 letters
  ↓
"Submit Turn"
  ↓
🔒 Handoff: "Pass to [Player 1]!"
  ↓
... repeat until puzzle complete ...
  ↓
🎉 Results: scores, words found
```

**One pattern for every game.** The handoff screen is identical to quizzes — dark screen, partner name, "I'M READY" button. The only difference: Linked has many handoffs per session (one per turn) instead of just one. This keeps each turn private and adds anticipation for what the other player placed.

---

### Word Search

**Same handoff pattern as Linked.** Each player takes turns finding words, passing the phone between turns.

```
Word Search Intro ("PLAY TOGETHER")
  ↓
Player 1 finds words (swipe to select)
  ↓
"Submit Turn"
  ↓
🔒 Handoff: "Pass to [Player 2]!"
  ↓
Player 2 taps "I'M READY"
  ↓
Player 2 finds words
  ↓
"Submit Turn"
  ↓
🔒 Handoff: "Pass to [Player 1]!"
  ↓
... repeat until puzzle complete ...
  ↓
🎉 Results: words found, scores
```

**Consistent with every other game.** No special "co-op" mode. Same handoff, same privacy, same fun.

---

### Welcome Quiz (Onboarding)

Uses the standard Pass-the-Phone pattern since it's the couple's first experience:

```
"Let's get to know you as a couple!"
  ↓
Player 1 answers 10 questions
  ↓
🔒 Handoff: "Now it's [Partner]'s turn!"
  ↓
Player 2 answers 10 questions
  ↓
🎉 Results + LP Intro + Paywall
```

This is the first time they experience the handoff. Make it feel special — maybe a brief animation tutorial: *"When you see this screen, pass the phone to your partner!"*

---

## Features by Mode

Features aren't "removed" — they're mode-dependent. The app adapts based on pairing state.

| Feature | Unpaired (Single Phone) | Paired (Either Mode) |
|---------|------------------------|---------------------|
| **Quizzes/You or Me** | Pass-the-phone flow | Choose: together or async |
| **Linked/Word Search** | Pass-the-phone turns | Choose: together or async |
| **Waiting screens** | Never shown | Only in async mode |
| **Polling** | Disabled | Only in async mode |
| **Poke / Remind** | Hidden (partner is next to you) | Available in async mode |
| **Steps Together** | Locked (needs two devices) | Unlocked |
| **Push notifications** | Disabled | Active for async play |
| **Quest status badges** | Simple: "Play" / "Completed" | Full: "You answered" / "Partner answered" / etc. |
| **Pairing code screen** | Moved to Settings | Done (paired state) |

### Steps Together — Upgrade Nudge

In unpaired mode, Steps Together appears as a locked card with a gentle prompt:
*"Set up partner's phone →"* with subtitle *"Requires two devices"*.

This creates a natural upgrade funnel without blocking any core content.

---

## Features Modified

### LP System
- **No change to amounts or daily caps.** Same 30 LP per content type per day.
- **Server still tracks.** Single-phone mode still syncs with server (for future two-device upgrade).
- **Both players share one LP pool.** Same as current — LP is couple-level, not per-user.

### Profile Screen
- Shows both names (partner name from phantom user's metadata, same as if they were a real user).
- Same LP counter, days together, magnet collection.
- Remove any "partner's device" status indicators.
- Add: **"Set up partner's device"** link (upgrade path).

### Settings Screen
- Add: **"Play on two devices"** section with explanation and setup flow.
- Remove: Any partner device management that doesn't apply.

### Journal
- Same — shows completed games and scores.
- No change needed since it's couple-level history.

### Quest Card Interaction
- Tap card → goes straight to game intro → "PLAY TOGETHER" button.
- No intermediate states about partner status.
- Much simpler state machine.

---

## Upgrade to Two Devices

The critical design goal: **pairing is additive, never disruptive. Single-phone mode remains available forever.**

### How It Works

**On the original phone (Player 1's phone):**
1. Go to Settings → "Set up partner's device"
2. Screen generates a pairing code (same system as current pairing)
3. Shows instructions: *"Ask [Partner] to download Us 2.0 and enter this code"*

**On the partner's new phone (Player 2's phone):**
1. Download app → onboarding
2. Enter name + email (their own account)
3. Enter pairing code from Player 1's screen
4. Server runs the **phantom → real user merge** (see [Server Architecture](#server-architecture-two-users-always)):
   - Replaces phantom `user2_id` with the real partner's user ID across all tables
   - All game history, LP transactions, quiz answers attributed to the phantom are now theirs
   - Atomic transaction — nothing is lost
5. Partner's device syncs all history — they see every game they "played" on one phone

**After pairing, both modes coexist:**
- App detects paired state → unlocks two-device features
- Steps Together becomes available
- Poke feature appears in bottom nav
- Quest cards gain async status badges
- **But "Play Together" is always available** — even paired users can pass the phone
- All previous game history preserved

### The Per-Game Mode Choice (Paired Users)

When a paired user taps a quest card, the game intro screen shows both options:

```
┌─────────────────────────────┐
│       Classic Quiz          │
│  "Communication Styles"     │
│                             │
│  ┌───────────────────────┐  │
│  │  📱 Play Together     │  │
│  │  Both answer now      │  │
│  └───────────────────────┘  │
│                             │
│  ┌───────────────────────┐  │
│  │  📱📱 Play Separately │  │
│  │  Answer on your own   │  │
│  └───────────────────────┘  │
└─────────────────────────────┘
```

- **"Play Together"** → pass-the-phone flow, instant results
- **"Play Separately"** → current async flow with waiting/polling

This is only shown to paired users. Unpaired users go straight to single-phone flow.

### When to Prompt Upgrade

Gentle, non-pushy nudges:

| Moment | Prompt |
|--------|--------|
| Steps Together locked slot | *"Set up partner's phone →"* with *"Requires two devices"* |
| After 7 days of use | Small banner: *"Want to play anytime? Set up [Partner]'s phone →"* |
| Settings screen | Permanent "Play on two devices" option |
| Poke (when tapped with phantom partner) | Promotional popup: "Want to poke [Partner]? Set up their phone!" |
| Steps Together (when tapped with phantom partner) | Same promotional popup |
| Any two-device feature attempted | Contextual upgrade prompt at the moment the user feels the gap |

**Never:** Block content, show unprompted popups, or nag. Upgrade prompts only appear when the user actively tries to use a feature that requires two devices.

---

## UX Comparison Summary

| Aspect | Two-Device (Current) | Single-Phone |
|--------|---------------------|-------------|
| **Vibe** | Async, check-your-phone | Date night, couch activity |
| **Session length** | Quick (answer 5 Qs, wait) | Longer (both play in one sitting) |
| **Waiting** | Seconds to hours | Zero |
| **Results** | Delayed | Instant |
| **Fun moment** | Notification "Results ready!" | Handoff screen anticipation + instant reveal |
| **Engagement model** | Daily check-ins, notifications | Intentional "let's play" sessions |
| **Friction to start** | Download × 2, pair, both play | Download × 1, enter names, play |

---

## Mode Switching & Game State Rules

### Core Rule: Mode is locked per game session

When a paired user starts a game, they choose "Play Together" or "Play Separately." That choice is locked for the duration of that game session. There is no mid-game switching.

### What counts as a "game session"?

| Game | Session = | Duration |
|------|-----------|----------|
| Classic Quiz | All 5 questions + both players' answers + results | ~2 minutes |
| Affirmation Quiz | All 5 questions + both players' answers + results | ~2 minutes |
| You or Me | All 4 dilemmas + both players' picks + results | ~1 minute |
| Linked | The entire puzzle from start to completion | Multiple sessions over hours/days |
| Word Search | The entire puzzle from start to completion | Multiple sessions over hours/days |

### Short games (Quizzes, You or Me): Simple

These complete in one sitting. No mode ambiguity.

- **Single-phone:** Player 1 answers → handoff → Player 2 answers → both answers submitted in one API call → instant results
- **Async:** Player 1 submits → waiting state → Player 2 submits on their phone → results

If a single-phone session is interrupted before Player 2 answers (app killed, Player 2 walks away):
- Player 1's answers are **persisted to local storage** (survive app restart)
- Reopening the quest shows the handoff screen, waiting for Player 2
- Player 1's answers are **NOT submitted to the server** until Player 2 also answers
- If they want to abandon, a "Start Over" option discards Player 1's answers

### Long games (Linked, Word Search): Mode is locked for the whole puzzle

A Linked puzzle can take days to complete across multiple turns. The mode chosen at puzzle start is locked until the puzzle is finished.

| Started as | What happens |
|-----------|--------------|
| **Co-op (single phone)** | Every turn is played together on one screen. Both discuss and place letters. All turns submitted under Player 1's auth with `mode: "coop"`. Must finish the puzzle in co-op. |
| **Turn-based (async)** | Normal two-device turn-taking. Each player submits on their own phone. Must finish the puzzle in turn-based. |

**If a couple wants to switch modes for Linked/Word Search, they must finish (or abandon) the current puzzle first.** The next puzzle can be started in either mode.

### Server-side submission model

| Mode | How answers reach server | Server state |
|------|------------------------|-------------|
| **Single-phone (phantom partner)** | Two calls to same `/submit` endpoint from User 1's device. First as self, second with `onBehalfOf: user2_id`. | Brief "waiting" state between calls (seconds). Normal completion after second call. |
| **Single-phone (paired, "Play Together")** | Identical to above. Two calls from one device. | Identical to above. |
| **Two-device (async)** | Two separate calls to `/submit`, each from their own device with their own auth token. | "Waiting for partner" state between calls (minutes to hours). |

**Key insight:** All three modes look the same to the server — two submissions per game session. The difference is timing (seconds vs hours) and auth (same device vs different devices). No special "together mode" concept needed server-side beyond the `onBehalfOf` validation.

### What about the Welcome Quiz?

The Welcome Quiz always uses single-phone mode (it happens during onboarding, before pairing is possible). Two sequential API calls — User 1's answers first, then User 2's with `onBehalfOf`.

---

## Concise Change List: UI Changes

### New Screens (2)

1. **Partner Name Entry** — Replaces `pairing_screen.dart`. Single text field: "What's your partner's name?" + subtitle "You'll play together on this phone." Creates phantom user via API.
2. **Mode Choice** (paired users only) — On game intro screens, two buttons: "Play Together" (single-phone flow) vs "Play Separately" (async flow). Only shown when partner is a real user, not phantom.

### Modified Screens (10)

4. **Onboarding flow** (`onboarding_screen.dart`) — Navigation change: route to Partner Name Entry instead of Pairing Screen.
5. **Welcome Quiz game** (`welcome_quiz_game_screen.dart`) — Add Player 1/Player 2 turn flow with handoff screen between them. Submit P1 answers immediately, P2 answers with `onBehalfOf`.
6. **Welcome Quiz waiting** (`welcome_quiz_waiting_screen.dart`) — In together-mode: replace polling with "Pass to [Partner]" + "I'M READY" button.
7. **Quiz/You-or-Me game screens** (`quiz_match_game_screen.dart`, `you_or_me_match_game_screen.dart`) — Add player indicator ("First Player's turn" / "Second Player's turn"). Second player's turn submits with `onBehalfOf`.
8. **Game waiting screen** (`game_waiting_screen.dart`) — In together-mode: replace polling with "Pass to [Partner]" + "I'M READY" button. After P2 submits, navigate straight to results.
9. **Linked game** (`linked_game_screen.dart`) — Together-mode: `turn_complete_dialog.dart` shows "Pass to [Partner]" + "I'M READY" instead of polling. Submit partner's turns with `onBehalfOf`.
10. **Word Search game** (`word_search_game_screen.dart`) — Same as Linked.
11. **Home screen** (`home_screen.dart`) — Disable polling when phantom partner. Simplified quest card badges (no "YOUR TURN" / "PARTNER'S TURN").
12. **Profile screen** (`profile_screen.dart`) — Partner name from phantom metadata. Add "Set up partner's device" link.
13. **Settings screen** (`settings_screen.dart`) — Add "Play on two devices" section. Keep "who goes first" (determines who answers first in handoff). Remove unpair option when phantom.

### Modified Widgets (7)

14. **Quest cards** (`quest_card.dart`) — New "PASS TO [PARTNER]" badge for when P1 answered but P2 hasn't (app was closed mid-session). Tapping "CONTINUE" goes to handoff screen. For Linked/WS long games, show whose turn it is.
15. **Daily quests widget** (`daily_quests_widget.dart`) — Disable polling subscriptions when phantom partner.
16. **Poke screen** (`poke_screen.dart`) — Keep as-is but show upgrade prompt when user tries to poke with phantom partner. Same pattern for Steps Together and any other two-device feature.
17. **Avatar section** (`us2_avatar_section.dart`) — Show both names regardless (partner name from phantom user metadata — looks the same as real partner).
18. **Steps Together card** — Tapping shows upgrade prompt when phantom partner.
19. **Upgrade prompt popup** (NEW widget) — Reusable popup shown when any two-device feature is attempted with phantom partner. "Want to [poke/track steps/play async]? Set up [Partner]'s phone!" with "Set Up" and "Maybe Later" buttons.
20. **Results screens** (`quiz_match_results_screen.dart`, `you_or_me_match_results_screen.dart`, `linked_completion_screen.dart`, `word_search_completion_screen.dart`) — Add "Discuss this!" prompts for disagreements (unique to together-mode since both are present).

### Removed/Bypassed (1)

21. **Pairing screen from onboarding** (`pairing_screen.dart`) — No longer in onboarding flow. Pairing code entry only accessible from Settings → "Set up partner's device."

### Summary

| Category | Count |
|----------|-------|
| New screens | 2 |
| Modified screens | 10 |
| Modified widgets | 7 |
| Removed from onboarding | 1 |
| **Total UI touchpoints** | **20** |

---

## Open Questions

- [ ] Should the "handoff screen" have a timer or just a tap? (Timer adds tension but slows things down)
- [ ] For Linked/Word Search couch co-op: track who placed which letters, or just shared score?
- [ ] Daily quest reset: same UTC midnight? Or does "daily" mean "per session" in single-phone?
- [ ] Can users replay completed quizzes in single-phone mode? (Both are present, might want to play more)
- [ ] For the per-game mode choice (paired users): always show both options, or auto-detect based on context?
- [ ] Should the "Invite" tab in bottom nav convert to "Poke" after pairing? Or keep both?
- [x] ~~Should single-phone mode be a separate app?~~ **Resolved: No. Same app, hybrid model.**
- [x] ~~Brand name: same "Us 2.0" or variant?~~ **Resolved: Same brand, same app.**
- [x] ~~How does the server handle single-phone submissions?~~ **Resolved: Phantom user created at onboarding. Two real user IDs always exist. Together-mode endpoints submit both answer sets in one call. See [Server Architecture](#server-architecture-two-users-always).**
- [x] ~~Can users switch modes mid-game?~~ **Resolved: No. Mode locked per session. Finish or abandon first.**

---

## Critical Review: Issues Found

*Reviewed 2025-02-07 from the perspective of an experienced mobile app developer, grounded in the actual codebase.*

### SEVERITY: HIGH — Architecture Blockers

#### ~~1. The "Partner Placeholder" Problem (DATABASE)~~ ✅ RESOLVED

**Resolved:** Phantom user approach adopted. Server always creates two real `auth.users` entries — a phantom account for the partner during onboarding, upgraded via atomic merge when partner installs. Zero schema changes needed. See [Server Architecture](#server-architecture-two-users-always).

#### ~~2. LP System Assumes Two Real Users (BUSINESS LOGIC)~~ ✅ RESOLVED

**Resolved:** Phantom user is a real `auth.users` row, so LP transactions are logged under valid user IDs. When the merge happens, all `love_point_transactions` rows referencing the phantom ID are updated to the real partner's ID in the same atomic transaction. No inconsistency.

#### 3. Who Goes First? (`first_player_id` Race Condition)

**The plan says:** Nothing about this.

**The reality:** The `couples` table has a `first_player_id` field that determines who plays first in games. Currently set during pairing based on who created the invite. In single-phone mode, the primary user is always "Player 1" by default. But what happens when they pair and the *partner* signs up? Does the couple now need to reconfigure who goes first? The `first_player_id` would reference the primary user, but after pairing the partner might want to go first sometimes.

**Impact:** Low-medium. Existing "who goes first" preference in Settings already handles this, but needs review.

---

### SEVERITY: HIGH — UX Issues

#### 4. Onboarding Still Requires Email + OTP

**The plan says:** Remove pairing from onboarding. Flow is `Name → Partner Name → Email → OTP → ...`

**The issue:** The *whole point* is reducing friction. But the user still needs to verify their email with an OTP code during onboarding. For many users who just want to try the app with their partner, this is still a wall — especially since the partner doesn't need an account. "Enter your partner's name and play!" but first... go check your email for a 6-digit code.

**Suggestion:** Consider whether the single-phone flow could work with anonymous/guest auth initially, with email collection deferred to after the first game. Let them *play* first, then ask for email. This dramatically reduces time-to-first-value.

#### 5. Handoff Screen Is a Trust-Based System

**The plan says:** "No peeking! 👀" with back button disabled.

**The issues:**
- **Recent apps / notification drawer:** Player 2 could pull down the notification shade or switch to recent apps to see the previous screen rendered in the app thumbnail. On Android, the recent apps view literally shows a screenshot of the last screen. You need `FLAG_SECURE` (Android) or similar to prevent this.
- **Screen recording:** If the user has screen recording on, Player 1's answers are captured. Can't prevent this, but worth noting.
- **Accidental back gesture:** On Android 13+, the predictive back gesture *shows a preview* of the previous screen before you fully swipe back. `PopScope` prevents the *navigation*, but the *preview animation* might briefly reveal Player 1's answers. Need to test this.
- **App kill during handoff:** If Player 1 answers and hands the phone over, but the app is killed before Player 2 taps "I'M READY" — Player 1's answers need to be persisted. The plan mentions this, but the local storage format needs to be defined. What exactly gets saved? Just answer indices? The full session state?

#### 6. "Abandon" Workflow for Long Games Is Undefined

**The plan says:** "If a couple wants to switch modes for Linked/Word Search, they must finish (or abandon) the current puzzle."

**The issue:** What does "abandon" mean UX-wise? Where is the abandon button? What confirmation do they get? Is it in Settings? In the game screen? What happens to partial progress — is LP lost? Can they accidentally abandon? For a puzzle they've worked on for 3 days, abandoning feels punishing. There's no UI designed for this in any mockup.

**Suggestion:** Add an explicit "Start New Puzzle" option that clearly states progress will be lost. Put it in the game intro screen, not buried in settings. Show how much progress they'd lose ("Puzzle 67% complete — start over?").

---

### SEVERITY: MEDIUM — Technical Issues

#### ~~7. Single-Phone API Calls Need New Auth Model~~ ✅ RESOLVED

**Resolved:** Two separate API calls from the same device, authenticated as User 1, submitting under each user's ID sequentially. User 1's answers submitted immediately after Player 1 finishes. User 2's answers submitted after Player 2 finishes. Server-side, this looks like two normal submissions — same endpoints, same logic. The only difference: both calls come from the same device using User 1's auth token, with User 2's submission specifying `onBehalfOf: user2_id`. The server validates that User 1 is in a couple with User 2 and that User 2 is a phantom (or that the couple has `together_mode` enabled). See [Server Architecture](#server-architecture-two-users-always).

#### 8. Push Token Registration Without Partner Account

**The plan says:** Notifications are disabled for unpaired users.

**The issue:** Currently, push tokens are registered after auth and synced to the server. The server stores tokens per user. If the "partner" is a placeholder with no real device, this works fine (just no token for them). But when the partner eventually installs and pairs, the notification setup needs to correctly link to the *existing* couple — not create a new one. The pairing flow needs to handle:
1. Partner signs up → gets their own auth account
2. Partner enters pairing code → server recognizes this code maps to an existing couple
3. Server replaces the placeholder `user2_id` with the real user's ID
4. All game history, LP transactions, etc. are preserved
5. Push token is now registered for the real partner

This "placeholder upgrade" is the riskiest technical operation in the entire plan.

#### 9. Offline / Poor Connectivity Handling

**The plan says:** "Server still tracks" for LP in single-phone mode.

**The issue:** If both players complete a quiz on one phone but have no internet, the API call fails. In two-device mode, each player submits independently (retry later). In single-phone mode, both answers are in one call — if it fails, the entire session's results are lost. Need a local queue/retry system for single-phone submissions. Player 1's answers are persisted locally per the plan, but Player 2's answers + the combined submission also need to survive connectivity failure.

#### ~~10. Couch Co-op Scoring for Linked/Word Search~~ ✅ RESOLVED

**Resolved:** Co-op mode removed. Linked and Word Search use the same handoff pattern as all other games — pass the phone between turns. Each player's moves are attributed to their own user ID normally. Existing scoring model works unchanged.

---

### SEVERITY: MEDIUM — UX Concerns

#### 11. The "Play Together" vs "Play Separately" Choice (Paired Users)

**The plan says:** Game intro screen shows both options for paired users.

**The concerns:**
- **Decision fatigue:** Every time they want to play, they have to make a choice. For most sessions, they probably have an obvious preference. Consider a "default mode" setting (but the plan explicitly says no global toggle... tension here).
- **Partner expectation mismatch:** Partner is on their phone expecting async play, but Player 1 starts a "Play Together" session. The quest card now shows "completed" on Player 1's phone (both answered) but Partner hasn't played on their own device. Does the partner get a notification? Does their quest card update? They might feel excluded.
- **Discoverability:** If a paired user always picks "Play Separately" (habit), they may never discover that "Play Together" works well. And vice versa.

#### 12. Partner Name Can't Be Changed Easily

**The plan says:** Partner name entered during onboarding.

**The issue:** What if they misspell it? What if the partner goes by a nickname? What if they break up and start using the app with a new partner? There needs to be an edit option in Settings. The partner name is currently sourced from the partner's own Supabase auth profile — in single-phone mode it's locally entered, which means it needs to be stored and editable somewhere. Where? Hive? A new server field?

#### 13. Daily Quest Assignment Without Two Users

**The plan says:** "Same 3 quests per day."

**The issue:** `quest_type_manager.dart` assigns quests based on the couple's progression. But quest generation happens on app open, and currently requires a valid couple with two users. In single-phone mode with a placeholder partner, the quest generation logic needs to work correctly — specifically, the slot allocation (Classic → Affirmation → You or Me) references the couple's history. If the couple was created with a placeholder user, does the history tracking work?

#### 14. Welcome Quiz Special Case Is Fragile

**The plan says:** Welcome Quiz always uses single-phone mode.

**The issue:** The Welcome Quiz currently has its own special submission endpoint (`/api/sync/welcome-quiz/submit`) with different logic from daily quizzes. It awards 30 LP one-time. In the new plan, this becomes the *first* single-phone submission ever. If the placeholder user approach is used, this is also the first time a game is played with a non-real user. Making the very first user experience depend on the newest, least-tested code path is risky.

**Suggestion:** Make the Welcome Quiz purely local for single-phone mode. Store results on device, show them immediately. Sync to server in the background (or when they pair). This removes the server dependency from the critical first-play experience.

---

### SEVERITY: LOW — Nice-to-Have / Polish

#### 15. No "Waiting for Partner to Sit Down" State

In two-device mode, both players are assumed to be ready at their own pace. In single-phone mode, "Play Together" implies they're both present. But what if Player 1 starts a game and Player 2 is in the bathroom? There's no "pause before starting" — once you tap "Play Together," Player 1 starts answering immediately. Consider adding an optional "Ready?" confirmation where both verbally agree before P1 starts.

#### 16. Results Screen Opportunities

**The plan mentions:** "Discuss" prompts for disagreements.

**Opportunity missed:** In single-phone mode, both players are looking at the screen together. The results screen could be much more interactive — tap to reveal answers one by one (dramatic reveal), have a "Who guessed better?" mini-game on the results, etc. The plan treats results as the same screen as two-device mode, but the co-present context allows much richer interaction.

#### 17. Analytics Blind Spot

**The plan doesn't mention:** How to distinguish single-phone vs two-device usage in analytics. Every game event, screen view, and funnel metric needs a `mode` dimension. Without this, you can't answer "do single-phone users convert to paired users?" or "which mode has better retention?" Add `mode: "single" | "together" | "async"` to every analytics event from day one.

#### 18. App Store Screenshots / Description

**Not mentioned:** The Google Play listing currently shows two-phone screenshots and describes pairing. If single-phone is the default experience, the store listing needs to change: "Play together on one phone" as the headline, screenshots showing the handoff screen and instant results. This is arguably the most important change for conversion, since the store listing is what converts installs.

---

### Summary Table

| # | Issue | Severity | Category | Blocking? |
|---|-------|----------|----------|-----------|
| 1 | ~~Partner placeholder — no support in DB schema~~ | ~~HIGH~~ | ~~Architecture~~ | ✅ RESOLVED |
| 2 | ~~LP transactions reference non-existent user~~ | ~~HIGH~~ | ~~Architecture~~ | ✅ RESOLVED |
| 3 | `first_player_id` after pairing upgrade | HIGH | Architecture | No |
| 4 | OTP still required during onboarding | HIGH | UX | No (but defeats purpose) |
| 5 | Handoff screen bypasses (recent apps, predictive back) | HIGH | UX/Security | No |
| 6 | "Abandon" workflow undefined for long games | HIGH | UX | No |
| 7 | ~~New API auth model for together-mode submissions~~ | ~~MEDIUM~~ | ~~Technical~~ | ✅ RESOLVED |
| 8 | Push token + placeholder → real user migration | MEDIUM | Technical | No |
| 9 | Offline submission handling for single-phone | MEDIUM | Technical | No |
| 10 | ~~Co-op scoring model for Linked/Word Search~~ | ~~MEDIUM~~ | ~~Technical~~ | ✅ RESOLVED |
| 11 | Mode choice decision fatigue for paired users | MEDIUM | UX | No |
| 12 | Partner name editing not planned | MEDIUM | UX | No |
| 13 | Quest generation with placeholder user | MEDIUM | Technical | No |
| 14 | Welcome Quiz as first-ever single-phone submission | MEDIUM | Technical | No |
| 15 | No "both ready?" confirmation | LOW | UX | No |
| 16 | Results screen missed opportunity | LOW | UX | No |
| 17 | Analytics mode dimension missing | LOW | Analytics | No |
| 18 | App Store listing needs update | LOW | Marketing | No |

### Recommended Priority for Resolution

**Before implementation:**
1. Decide on placeholder user strategy (Issue #1) — this affects everything
2. Design the together-mode API contract (Issue #7)
3. Define the placeholder → real user migration (Issue #8)
4. Design the abandon flow for long games (Issue #6)

**During implementation:**
5. Add `FLAG_SECURE` / predictive back handling (Issue #5)
6. Build offline retry queue (Issue #9)
7. Add `mode` to all analytics events (Issue #17)
8. Add partner name editing in Settings (Issue #12)

**Before launch:**
9. Update Google Play listing (Issue #18)
10. Consider deferring OTP to after first game (Issue #4)

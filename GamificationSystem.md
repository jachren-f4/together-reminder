# 💞 TogetherRemind Gamification System – MVP Specification (v1.1)

**Author:** Joakim Achrén  
**Date:** November 2025  
**Stage:** MVP  
**Purpose:** Define the gamified layer of the TogetherRemind couples app focused on verified, meaningful, and cooperative engagement.

---

## 🎯 Vision

TogetherRemind transforms everyday couple interactions into meaningful cooperative challenges.  
Users earn **Love Points** and rise on a **global, elastic leaderboard** by completing **authentic, verifiable activities** with their partner.

> “Love Points are earned through effort and authenticity, not repetition or fake taps.”

---

## 💡 Design Principles

1. **Accountability over automation** — effort should be measurable or confirmed by both partners.  
2. **Cooperative goals** — both need to contribute for success.  
3. **No streaks** — instead, time-boxed challenges and floor-based progression.  
4. **Verifiable data** — Apple Health / Google Fit integration where possible.  
5. **Healthy competition** — leaderboard reflects growth and effort over time.  
6. **Emotional reward first** — visual praise, recognition, warmth over points inflation.

---

## 🧩 MVP Core Activities (8 Features)

### 1. Couple Quiz: “How Well Do You Know Me?”
- Both answer identical 3–5 questions privately.
- Answers lock until both submit.
- Scoring based on overlap accuracy (50% = 5 pts, 100% = 20 pts).
- Bonus if both answer within 3-hour window.
- Anti-cheating: timed window, random order, no edit.
- Rewards: Love Points, “Perfect Sync” badge.

### 2. Apple Health / Google Fit Integration
- Both must hit step or sleep goals (≥6,000 steps / ≥7h sleep).
- Only if both meet criteria → reward.
- Anti-cheating: verified data only.
- Rewards: Love Points, “Active Duo” badges.

### 3. Crossword / Word Challenge
- Shared puzzle filled in turns.
- Must finish within time limit.
- Anti-cheating: server validates both actions.
- Rewards: Love Points, “Mind Meld” badge.

### 4. Weekly Love Challenge
- Example: “Complete 40 actions this week.”
- Themes: “Teamwork Week,” “Discovery Week.”
- Anti-cheating: unique event validation.
- Rewards: 2x LP multiplier, badges, tier upgrades.

### 5. Poke System 2.0
- 3 pokes/day per user.
- Only first mutual poke earns points.
- Anti-cheating: token scarcity, cooldowns.
- Rewards: Small LP bonus, “Daily Warmth” visual.

### 6. Timed Trivia Mode
- 30-second trivia answered simultaneously.
- Speed affects LP multiplier.
- Rewards: Love Points, “Quick Thinkers” badge.

### 7. End-of-Week Recap & Praise Ceremony
- AI-generated summary of the week’s activity.
- Optional love reaction.
- Rewards: “Golden Heart” badge, confetti animation.

### 8. Couple Profile Leveling & Vacation Arenas
- Love Points accumulate into levels with vacation-themed arenas:
  - 🏕️ **Cozy Cabin** (0-1,000 LP) - Starting your journey together
  - 🏖️ **Beach Villa** (1,000-2,500 LP) - Building memories
  - ⛵ **Yacht Getaway** (2,500-5,000 LP) - Sailing smoothly
  - 🏔️ **Mountain Penthouse** (5,000-10,000 LP) - Reaching new heights
  - 🏰 **Castle Retreat** (10,000+ LP) - Living the dream together
- Rewards: tier visuals with vacation imagery, ambient sounds, location-based icons.

---

## 🏆 Leaderboard System – “Elastic Progression Model”

### 🎯 Purpose
Persistent leaderboard reflecting real growth with elastic gains and losses.

### ⚙️ Core Mechanics
- **Permanent accumulation** of Love Points (LP).
- **Milestone floors** protect progress: 0 → 1000 → 2000 → 3500 → 5000 LP tiers.
- **Soft decay:** inactivity causes −2% (3 days), −5% (7 days), capped at −10% weekly.
- **Event-based deductions:** missed goals or timeouts reduce LP.
- **Positive balancing:** frequent actions offset decay.
- **Dynamic ranking:** leaderboard updates every 6h; shows rise/fall arrows.

### 🪙 Losing Love Points
Loss results from neglect, not punishment. Decay never passes the couple’s floor threshold. Recoverable, emotionally framed as “connection fading.”

### 🧮 Example
| Scenario | Result |
|-----------|---------|
| Gain +300 LP → Tier 2 floor | Total 1,300 LP (floor 1,000) |
| 7 days inactivity (−5%) | New total 1,235 LP |
| Missed quizzes (−20 LP) | Total 1,215 LP |
| Active week (+200 LP) | Total 1,415 LP |
| Below floor? | LP stays ≥ 1,000 |

### 📊 Leaderboard Display
- Global and Friends views.
- Rank card shows LP, tier, floor, delta, and 4-week chart.
- UI: animated LP counter, arena colors, weekly change arrows.

### 🔐 Technical Structure (Firebase)
```json
{
  "leaderboard": {
    "coupleId": {
      "lovePoints": 3280,
      "arenaTier": 3,
      "floor": 2000,
      "lastActivityDate": "2025-11-10",
      "decayApplied": false
    }
  }
}
```
Functions:
- `applyDecay()` → daily, deducts LP above floor.  
- `updateLeaderboardRank()` → re-sorts ranks & deltas.

### 🏅 Feedback Examples
| Event | Message | Animation |
|--------|----------|------------|
| New floor | “Your bond just grew stronger — this level is forever yours!” | Heart flame ignite |
| LP loss | “You’ve been quiet lately — your connection dims slightly.” | Heart flicker |
| Rank up | “+12 ranks! Others felt your energy 💫” | Upward sparkle |
| Rank down | “You dropped 4 spots — send some love ❤️” | Gentle fade |

---

## 🪙 Reward System Overview

| Type | Trigger | Emotion |
|------|----------|----------|
| Love Points | Completed actions | Feedback |
| Badges | Unique milestones | Pride |
| Arenas | Tier upgrades | Prestige |
| Animations | Visual completion | Delight |
| Weekly Summary | AI reflection | Warmth |

---

## ⚙️ Firebase Implementation Summary

- `validateCoupleEvent()` → verifies paired activity completion.  
- `updateLeaderboard()` → recalculates LP + ranks.  
- `resetWeeklyStats()` → archives data for analysis.  
- `generateWeeklySummary()` → AI praise generator.

---

## 🎨 Visual System

- Arena visuals and color palettes per tier.  
- Heartbeat pulse on level-up.  
- Confetti animation for achievements.  
- Weekly summary card for sharing.

---

## 🧠 Future Expansion

| Feature | Description |
|----------|--------------|
| Photo Recognition Moments | LLM identifies shared memories |
| AI Mood Journal | Daily emotional sync tracking |
| Mini Cooperative Games | Drawing or storytelling modes |
| Seasonal Tournaments | Monthly cosmetic trophies |

---

## 🗓️ MVP Success Criteria

| Metric | Target |
|---------|--------|
| Active couples completing weekly verified actions | ≥ 80% |
| Couples connected to Apple Health / Fit | ≥ 50% |
| Retention | ≥ 40% weekly |
| Invalidated actions | < 2% |
| User sentiment on rewards | ≥ 4.0/5 |

---

## 🗺️ MVP Implementation Plan – Common User Journeys

Based on the flow chart analysis, we will build the gamification system through **5 Common User Journeys** that cover core functionality without building everything at once.

### Journey Overview

1. **Daily Check-in** (Home → Quiz → Results → Profile)
2. **Send Reminder with LP Reward** (Home → Send → Confirmation)
3. **Poke Exchange** (Home → Poke → Mutual Detection)
4. **Weekly Challenge Progress** (Home → Activity → Challenge Progress)
5. **Check Leaderboard Ranking** (Home → Leaderboard → Friends View)

---

### 📅 Phase 1: Core LP System (Week 1-2)

**Goal:** Integrate Love Points into existing features (reminders & pokes)

**Journeys Covered:** #2 (Send Reminder), #3 (Poke Exchange)

**Tasks:**
1. **Data Model Updates**
   - Add `lovePoints` field to User model
   - Add `arenaTier` and `floor` fields
   - Create `LovePointTransaction` model for history
   - Update Hive adapters

2. **LP Service Layer**
   - Create `LovePointService` class
   - Implement `awardPoints(amount, reason)` method
   - Implement `getCurrentTier()` based on vacation arenas
   - Implement `getFloorProtection()` logic

3. **Reminder LP Integration**
   - Award +10 LP when reminder is marked "Done"
   - Award +8 LP when reminder is sent
   - Show "+10 LP" badge in reminder cards
   - Show LP preview in SendReminderScreen

4. **Poke LP Integration**
   - Award +5 LP for mutual pokes (both send within 2min)
   - Award +3 LP for regular poke back
   - Update `PokeService` to track LP rewards
   - Show LP earned in poke confirmation

5. **Profile Screen (Minimal)**
   - Build basic profile screen showing:
     - Total LP counter
     - Current vacation arena tier
     - Progress bar to next tier
     - Floor protection indicator
   - Add to bottom navigation (replace placeholder)

**Deliverables:**
- ✅ Reminders award LP on completion
- ✅ Pokes award LP for mutual interaction
- ✅ Profile screen shows LP, tier, and progress
- ✅ Vacation arena progression (5 tiers)

---

### 📅 Phase 2: First Activity – Couple Quiz (Week 3-4)

**Goal:** Prove the "new activity" pattern with highest-engagement feature

**Journeys Covered:** #1 (Daily Check-in)

**Tasks:**
1. **Quiz Data Model**
   - Create `QuizQuestion` model (question, options, correctAnswer)
   - Create `QuizSession` model (sessionId, questions, answers, status)
   - Create Hive adapters

2. **Quiz Question Bank**
   - Write 50+ couple-focused questions (JSON file)
   - Categories: favorites, memories, preferences, future plans
   - Random selection of 5 questions per session

3. **Quiz Flow Screens**
   - **Quiz Intro Screen**: "How Well Do You Know Me?" with rules
   - **Question Screen**: Show question, 4 options, 3-hour timer
   - **Waiting Screen**: "Waiting for partner to submit..."
   - **Results Screen**: Show match %, comparison, LP earned (5-20 LP)

4. **Cloud Function**
   - `createQuizSession()` → generates questions, notifies both
   - `submitQuizAnswers()` → stores answers, checks if both done
   - `calculateQuizResults()` → compares answers, awards LP

5. **Integration**
   - Add "Couple Quiz" card to Activities screen (or Home screen)
   - Show "Ready" status if no active session
   - Push notification when partner completes quiz

**Deliverables:**
- ✅ Couple Quiz fully functional (4-screen flow)
- ✅ LP awarded based on match accuracy (5-20 LP)
- ✅ "Perfect Sync" badge for 100% match
- ✅ Accessible from Activities or Home screen

---

### 📅 Phase 3: Social Layer – Leaderboard (Week 5)

**Goal:** Add competitive element to drive retention

**Journeys Covered:** #5 (Check Leaderboard Ranking)

**Tasks:**
1. **Firebase Leaderboard Structure**
   - Create `leaderboard` collection in Firestore
   - Store: coupleId, lovePoints, arenaTier, floor, lastActivityDate, rank
   - Cloud function to update ranks every 6 hours

2. **Leaderboard Service**
   - `fetchGlobalLeaderboard()` → top 100 couples
   - `fetchFriendsLeaderboard()` → if friends feature exists
   - `getCurrentRank()` → user's position
   - `getRankDelta()` → change since last update

3. **Leaderboard Screen**
   - Tab switcher: Global / Friends
   - Rank cards showing: rank, couple names, LP, tier, delta (↑↓)
   - Highlight current user's card
   - 4-week mini chart (optional for MVP)

4. **Integration**
   - Add "Leaderboard" to bottom navigation
   - Show rank delta notification ("You moved up 12 spots!")

**Deliverables:**
- ✅ Global leaderboard functional
- ✅ Rank updates every 6 hours
- ✅ User sees their rank and delta
- ✅ Accessible from bottom nav

---

### 📅 Phase 4: Retention Mechanic – Weekly Challenge (Week 6)

**Goal:** Time-boxed goals to encourage regular engagement

**Journeys Covered:** #4 (Weekly Challenge Progress)

**Tasks:**
1. **Challenge Data Model**
   - Create `WeeklyChallenge` model (title, description, goal, progress, endDate)
   - Store active challenge in Hive
   - Cloud function to reset weekly

2. **Challenge Logic**
   - Auto-generate challenge every Monday (e.g., "Complete 40 activities")
   - Track progress: reminders + pokes + quizzes = activity count
   - Award 2x LP multiplier during active challenge
   - Award bonus LP + badge if goal reached

3. **Challenge UI**
   - Collapsible banner on Home screen showing:
     - Challenge title ("Teamwork Week")
     - Progress: "28/40 activities"
     - Days remaining
     - Progress bar
   - Detailed view in Activities screen

4. **Cloud Function**
   - `generateWeeklyChallenge()` → runs Monday 00:00
   - `incrementChallengeProgress()` → called on each activity
   - `completeWeeklyChallenge()` → awards bonus LP

**Deliverables:**
- ✅ Weekly challenge auto-generates
- ✅ Progress tracked across all activities
- ✅ 2x LP multiplier active during challenge
- ✅ Completion awards bonus LP + badge
- ✅ Visible on Home screen banner

---

## 🎯 MVP Feature Completion Checklist

After Phase 4, the MVP will include:

- [x] **Core LP System**
  - [x] LP awarded for reminders
  - [x] LP awarded for pokes
  - [x] Vacation arena progression (5 tiers)
  - [x] Floor protection
  - [x] Profile screen with LP/tier display

- [x] **Activities**
  - [x] Couple Quiz (new activity)
  - [x] Reminders with LP (existing + gamified)
  - [x] Pokes with LP (existing + gamified)

- [x] **Social & Retention**
  - [x] Global leaderboard
  - [x] Rank tracking with deltas
  - [x] Weekly challenges (2x LP multiplier)

- [ ] **Future Phase 5+ Features** (Post-MVP)
  - [ ] Timed Trivia
  - [ ] Crossword Puzzle
  - [ ] Apple Health / Google Fit integration
  - [ ] End-of-Week Recap (AI-generated)
  - [ ] Additional badges & achievements
  - [ ] Decay system (soft LP loss for inactivity)

---

## ✅ Next Steps

**Immediate:** Begin Phase 1 implementation
1. Update Hive data models with LP fields
2. Create `LovePointService` class
3. Integrate LP rewards into `ReminderService` and `PokeService`
4. Build basic Profile screen
5. Test LP earning and tier progression with mock data

**Week 2:** Complete Phase 1 and test with real device pairing

**Week 3-4:** Build Couple Quiz (Phase 2)

**Week 5:** Implement Leaderboard (Phase 3)

**Week 6:** Add Weekly Challenges (Phase 4)

**Week 7+:** Polish, bug fixes, prepare for TestFlight beta

---

**End of Document**

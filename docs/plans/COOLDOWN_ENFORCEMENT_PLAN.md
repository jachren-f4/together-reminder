# 8-Hour Cooldown Enforcement - Implementation Plan

> **Status:** Completed
> **Created:** 2025-01-08
> **Completed:** 2026-01-08
> **Related:** `docs/plans/MAGNET_IMPLEMENTATION_PLAN.md` (Phase 1.4)

---

## Problem Statement

The backend correctly records 8-hour cooldowns after 2 plays per activity type, but the **client never checks or enforces these cooldowns**. Users can play unlimited games because:

1. Intro screens don't check cooldown status before showing "Start" button
2. Quest cards don't display cooldown indicators
3. `MagnetService` has cooldown methods that are **never called**

---

## Current State

### What Works (Backend)
- [x] `recordActivityPlay()` tracks plays and sets cooldowns after 2 plays
- [x] `getCooldownStatus()` returns `canPlay`, `remainingInBatch`, `cooldownEndsAt`
- [x] `/api/magnets` endpoint returns cooldown status for all activity types
- [x] Database schema (`couples.cooldowns` JSONB) stores cooldown state

### What's Missing (Client)
- [x] Pre-game cooldown checks in intro screens
- [x] Cooldown card UI when blocked
- [x] Quest card cooldown badges
- [x] Home screen cooldown status refresh
- [x] Server-side enforcement (safety net)

---

## Implementation Checklist

### Phase 1: Pre-Game Cooldown Checks

#### 1.1 Create Cooldown Card Widget
**File:** `lib/widgets/cooldown_card.dart` (NEW)

- [x] Create `CooldownCard` widget with Us2 styling
- [x] Display remaining time ("Available in 6h 24m")
- [x] Display batch status ("2/2 plays used today")
- [x] Match gradient/styling from Us2 theme
- [x] Add countdown timer that updates every minute

#### 1.2 Classic Quiz Intro Screen
**File:** `lib/screens/quiz_intro_screen.dart`

- [x] Add `CooldownStatus? _cooldownStatus` state variable
- [x] Call `MagnetService().getCooldownStatus(ActivityType.classicQuiz)` in `initState()`
- [x] Show `CooldownCard` instead of start button when `isOnCooldown == true`
- [x] Show "X plays remaining" badge via `RemainingPlaysIndicator` when plays left < 2
- [x] Handle loading state while fetching cooldown

#### 1.3 Affirmation Quiz Intro Screen
**File:** `lib/screens/affirmation_intro_screen.dart`

- [x] Add `CooldownStatus? _cooldownStatus` state variable
- [x] Call `MagnetService().getCooldownStatus(ActivityType.affirmationQuiz)` in `initState()`
- [x] Show `CooldownCard` instead of start button when `isOnCooldown == true`
- [x] Show "X plays remaining" badge via `RemainingPlaysIndicator` when plays left < 2
- [x] Handle loading state while fetching cooldown

#### 1.4 You or Me Intro Screen
**File:** `lib/screens/you_or_me_match_intro_screen.dart`

- [x] Add `CooldownStatus? _cooldownStatus` state variable
- [x] Call `MagnetService().getCooldownStatus(ActivityType.youOrMe)` in `initState()`
- [x] Show `CooldownCard` instead of start button when `isOnCooldown == true`
- [x] Show "X plays remaining" badge via `RemainingPlaysIndicator` when plays left < 2
- [x] Handle loading state while fetching cooldown

---

### Phase 2: UI Indicators

#### 2.1 Quest Card Cooldown Badge
**File:** `lib/widgets/brand/us2/us2_quest_card.dart`

- [x] Accept optional `CooldownStatus?` parameter
- [x] Show "On Cooldown" badge overlay with timer when `isOnCooldown == true`
- [x] Added `_StatusStyle.onCooldown` to status enum
- [x] Keep card tappable (navigates to intro screen with full cooldown info)

#### 2.2 Home Screen Cooldown Refresh
**File:** `lib/screens/home_screen.dart`

- [x] Added `_getCooldownStatus(DailyQuest)` callback method
- [x] Maps quest type to `ActivityType` for cooldown lookup
- [x] Passes callback through `BrandWidgetFactory.us2HomeContent`
- [x] Cooldown status flows to `Us2QuestData` → `Us2QuestCarousel` → `Us2QuestCard`

---

### Phase 3: Server-Side Enforcement (Safety Net)

#### 3.1 Quiz Submit Endpoint
**File:** `api/app/api/sync/quiz/submit/route.ts`

- [x] Import `getCooldownStatus` from `@/lib/magnets`
- [x] Add cooldown check before processing submission (only for new submissions)
- [x] Return `{ error: 'ON_COOLDOWN', code: 'ON_COOLDOWN', cooldownEndsAt, cooldownRemainingMs }` with 429 status
- [x] Allows completing in-progress quizzes (check existing answers first)
- [x] Keep existing `recordActivityPlay()` call after successful submission

#### 3.2 You-or-Me Submit Endpoint
**File:** `api/app/api/sync/you-or-me/submit/route.ts`

- [x] Import `getCooldownStatus` from `@/lib/magnets`
- [x] Add cooldown check before processing submission (only for new submissions)
- [x] Return `{ error: 'ON_COOLDOWN', code: 'ON_COOLDOWN', cooldownEndsAt, cooldownRemainingMs }` with 429 status
- [x] Allows completing in-progress games (check existing answers first)
- [x] Keep existing `recordActivityPlay()` call after successful submission

#### 3.3 Client Error Handling
**Files:** Game result screens

- [ ] Handle `ON_COOLDOWN` error response from API (deferred - client check should prevent this)
- [ ] Show appropriate error message if somehow hit (shouldn't happen with Phase 1)
- [ ] Navigate back to home or show cooldown info

---

### Phase 4: Testing

#### 4.1 Manual Testing Checklist

**Classic Quiz:**
- [ ] Play 1st quiz → see "1 play remaining" badge
- [ ] Play 2nd quiz → cooldown starts, see "On Cooldown" on intro screen
- [ ] Quest card shows cooldown badge with timer
- [ ] Wait 8 hours (or modify DB) → games available again

**Affirmation Quiz:**
- [ ] Play 1st quiz → see "1 play remaining" badge
- [ ] Play 2nd quiz → cooldown starts, see "On Cooldown" on intro screen
- [ ] Quest card shows cooldown badge with timer
- [ ] Wait 8 hours → games available again

**You or Me:**
- [ ] Play 1st game → see "1 play remaining" badge
- [ ] Play 2nd game → cooldown starts, see "On Cooldown" on intro screen
- [ ] Quest card shows cooldown badge with timer
- [ ] Wait 8 hours → games available again

**Cross-Device:**
- [ ] Device A plays 2 quizzes → cooldown starts
- [ ] Device B sees cooldown (server-authoritative)
- [ ] Both devices show same cooldown timer

**Edge Cases:**
- [ ] App restart during cooldown → cooldown persists
- [ ] Poor network → graceful error handling
- [ ] Cooldown expires while on intro screen → refresh shows available

#### 4.2 Automated Tests (Optional)
- [ ] Unit test: `CooldownCard` renders correctly
- [ ] Unit test: `MagnetService.getCooldownStatus()` parses API response
- [ ] Integration test: Quiz intro blocks when on cooldown

---

## Files Summary

### New Files
| File | Purpose |
|------|---------|
| `app/lib/widgets/cooldown_card.dart` | Reusable cooldown display widget with `CooldownCard`, `CooldownBadge`, `RemainingPlaysIndicator` |

### Modified Files
| File | Changes |
|------|---------|
| `app/lib/widgets/brand/us2/us2_intro_screen.dart` | Added cooldown support with `_buildCooldownLayout()` |
| `app/lib/screens/quiz_intro_screen.dart` | Added cooldown check via `MagnetService` |
| `app/lib/screens/affirmation_intro_screen.dart` | Added cooldown check via `MagnetService` |
| `app/lib/screens/you_or_me_match_intro_screen.dart` | Added cooldown check via `MagnetService` |
| `app/lib/widgets/brand/us2/us2_quest_card.dart` | Added `_StatusStyle.onCooldown` and cooldown badge |
| `app/lib/widgets/brand/us2/us2_quest_carousel.dart` | Added `cooldownStatus` to `Us2QuestData` model |
| `app/lib/widgets/brand/us2/us2_home_content.dart` | Added `CooldownCallback` typedef and parameter |
| `app/lib/widgets/brand/brand_widget_factory.dart` | Pass through `getCooldownStatus` callback |
| `app/lib/screens/home_screen.dart` | Added `_getCooldownStatus()` method to map quest types |
| `api/app/api/sync/quiz/submit/route.ts` | Added server-side cooldown check with 429 response |
| `api/app/api/sync/you-or-me/submit/route.ts` | Added server-side cooldown check with 429 response |

### Existing Files (Already Implemented)
| File | Purpose |
|------|---------|
| `api/lib/magnets/cooldowns.ts` | Server cooldown logic |
| `api/supabase/migrations/034_magnet_cooldowns.sql` | Database schema |
| `app/lib/models/cooldown_status.dart` | Client model |
| `app/lib/services/magnet_service.dart` | Has unused cooldown methods |

---

## Implementation Order

1. **Phase 1.1** - Create `CooldownCard` widget first (dependency for intro screens)
2. **Phase 1.2-1.4** - Add cooldown checks to quiz/you-or-me intro screens
3. **Phase 2.1** - Add cooldown badge to quest cards
4. **Phase 2.2** - Wire up home screen cooldown refresh
5. **Phase 3** - Add server-side safety net (optional but recommended)
6. **Phase 4** - Testing

---

## Notes

### Linked & Word Search
These games use a **different cooldown system** (date-based, 1 puzzle per day per branch). This plan does NOT modify their cooldown behavior. The 8-hour batch system only applies to:
- `classic_quiz`
- `affirmation_quiz`
- `you_or_me`

### MagnetService Methods
The following methods in `MagnetService` already exist but are never called:
- `isOnCooldown(ActivityType activityType)`
- `getCooldownStatus(ActivityType activityType)`
- `getRemainingPlays(ActivityType activityType)`
- `getFormattedCooldownTime(ActivityType activityType)`

These should be used by the intro screens after Phase 1 implementation.

---

## Progress Tracking

| Phase | Status | Completed |
|-------|--------|-----------|
| Phase 1.1 - Cooldown Card | Complete | 2026-01-08 |
| Phase 1.2 - Classic Quiz | Complete | 2026-01-08 |
| Phase 1.3 - Affirmation Quiz | Complete | 2026-01-08 |
| Phase 1.4 - You or Me | Complete | 2026-01-08 |
| Phase 2.1 - Quest Card Badge | Complete | 2026-01-08 |
| Phase 2.2 - Home Screen | Complete | 2026-01-08 |
| Phase 3.1 - Quiz API Check | Complete | 2026-01-08 |
| Phase 3.2 - You-or-Me API Check | Complete | 2026-01-08 |
| Phase 3.3 - Client Error Handling | Deferred | N/A |
| Phase 4 - Testing | Pending | Manual testing needed |

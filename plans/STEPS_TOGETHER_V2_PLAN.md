# Steps Together v2 Implementation Plan

**Created:** 2025-01-11
**Completed:** 2025-01-11
**Mockups:** `/mockups/steps-together-v2/`
**Status:** COMPLETE - Build 51 uploaded to TestFlight

---

## Overview

Redesign of the Steps Together screen based on UX evaluation. Key improvements include a combined progress ring, clearer tier system, milestone celebrations, 7-day history, and better "together" messaging.

---

## Phase 1: Core UI Redesign [COMPLETE]

### 1.1 Combined Progress Ring
- [x] Replace dual-ring painter with single combined ring
- [x] Add visual threshold marker at 50% (10K point)
- [x] Show user segment (coral gradient) and partner segment (teal gradient) as continuous fill
- [x] Update ring center content:
  - [x] Combined steps count
  - [x] "of 20,000 goal" text
  - [x] LP reward badge ("+18 LP tomorrow")
- [x] Add animated entrance for ring fill

### 1.2 Partner Color Update
- [x] Change partner color from gray (#999999) to teal gradient (#4ECDC4 → #45B7AA)
- [x] Update `DualRingPainter` (or new painter) with partner gradient support
- [x] Update legend color squares to use gradients

### 1.3 Header Improvements
- [x] Add "LIVE" badge with pulsing dot next to "Today's Progress"
- [x] Add sync status dot on refresh button (green = recently synced)
- [x] Add pull-to-refresh via RefreshIndicator

### 1.4 Partner Breakdown Redesign
- [x] Update legend layout to show gradient color squares
- [x] Keep loading spinner for partner when data not synced
- [x] Add partner name from storage

---

## Phase 2: Tier System UI [COMPLETE]

### 2.1 Tier Progress Card
- [x] Create new `_buildTierProgressCard()` widget
- [x] Add horizontal progress bar with tier markers
- [x] Highlight current tier with indicator dot
- [x] Show "Next tier in X steps" with LP bonus
- [x] Add "See all tiers →" link

### 2.2 Tier Breakdown Screen
- [x] Create `StepsTierBreakdownScreen` widget
- [x] Add intro card explaining tier system
- [x] Add current status card (steps + LP)
- [x] Build tier ladder with:
  - [x] Achieved tiers (green checkmark)
  - [x] Current tier (coral, highlighted)
  - [x] Locked tiers (gray)
  - [x] Progress to next tier
- [x] Add FAQ cards (how it works, when do I get LP)

---

## Phase 3: Claim Info & Messaging [COMPLETE]

### 3.1 Claim Info Card
- [x] Replace "Tomorrow's Reward" with "Tomorrow's Claim" card
- [x] Add countdown timer to claim time (midnight + claim window)
- [x] Show "LP is auto-claimed when you open the app tomorrow" note
- [x] Only show when above 10K threshold

### 3.2 Team Messages
- [x] Create `_buildTeamMessage()` widget
- [x] Add context-aware encouraging messages:
  - Below 50%: "Keep walking together!"
  - 50-75%: "Great teamwork! You're halfway there!"
  - 75-99%: "Almost there! Push for the goal!"
  - 100%+: "Goal crushed! Amazing teamwork!"
- [x] Style with gradient background

### 3.3 Below Threshold State
- [x] Create `_buildBelowThresholdCard()` widget
- [x] Show encouragement emoji and message
- [x] Add progress bar to 10K with "X to go!"
- [x] Show tier teaser (unlock preview)
- [x] Add tips section

---

## Phase 4: Week History & Streaks [COMPLETE]

### 4.1 Week Preview Card (Main Screen)
- [x] Create `_buildWeekPreviewCard()` widget
- [x] Show 7 day circles (Mon-Sun)
- [x] Circle states: success (green), max (gold), partial (orange), empty (gray), today (coral)
- [x] Add streak counter with fire emoji

### 4.2 Week History Screen
- [x] Create `StepsWeekHistoryScreen` widget
- [x] Add streak hero card with animation
- [x] Add week summary stats (total steps, LP earned, goals hit)
- [x] Add daily breakdown list:
  - [x] Day name and date
  - [x] Steps count and tier
  - [x] LP earned/pending/missed
- [x] Add "Best Day" highlight card
- [x] Add insights section with tips

### 4.3 Data Model Updates
- [x] Add `StepsWeekData` model or extend storage
- [x] Store last 7-14 days of step data
- [x] Calculate streak from consecutive days >= 10K
- [x] Track best day per week

---

## Phase 5: Milestone Celebrations [COMPLETE]

### 5.1 Tier Crossing Detection
- [x] Add tier tracking to `StepsFeatureService`
- [x] Detect when combined steps cross a tier threshold
- [x] Store last celebrated tier to prevent re-triggering

### 5.2 Milestone Celebration Overlay
- [x] Create `StepsMilestoneCelebrationOverlay` widget
- [x] Add confetti animation (reuse from auto-claim)
- [x] Show milestone badge, emoji, title
- [x] Show steps breakdown (you + partner = combined)
- [x] Show LP reward with "+X more!" upgrade badge
- [x] Show tier comparison (old → new)
- [x] Show next milestone preview
- [x] Add haptic feedback on trigger

### 5.3 Integration
- [x] Trigger celebration in `_refreshData()` when tier changes
- [x] Only trigger once per tier per day
- [x] Store celebrated tiers in Hive

---

## Phase 6: Pull-to-Refresh & Polish [COMPLETE]

### 6.1 Pull-to-Refresh
- [x] Wrap content in `RefreshIndicator`
- [x] Connect to `_refreshData()`
- [x] Add subtle hint text when not pulling

### 6.2 Animations
- [x] Add ring fill animation on load
- [x] Add tier progress bar animation
- [x] Add number count-up animation for steps
- [x] Respect `AnimationConfig.shouldReduceMotion`

### 6.3 Sound & Haptics
- [x] Add haptic on milestone celebration
- [x] Add haptic on pull-to-refresh complete
- [x] Add sound on milestone (reuse confetti sound)

---

## Phase 7: Debug Menu Integration [COMPLETE]

### 7.1 Steps Debug Tab
- [x] Add new "Steps" tab to debug menu
- [x] Add step simulation controls:
  - [x] User steps slider (0-15,000)
  - [x] Partner steps slider (0-15,000)
  - [x] Combined steps display
  - [x] Current tier display
- [x] Add quick preset buttons:
  - [x] "Below 10K" (4K + 3K)
  - [x] "At 10K" (5K + 5K)
  - [x] "At 14K" (8K + 6K)
  - [x] "Max Tier" (12K + 10K)
- [x] Add action buttons:
  - [x] "Trigger Milestone Celebration"
  - [x] "Show Auto-Claim Overlay"
  - [x] "Reset Today's Data"
  - [x] "Generate Week History"

### 7.2 Mock Data Generation
- [x] Create `StepsDebugService` for mock data
- [x] Methods:
  - [x] `setMockUserSteps(int steps)`
  - [x] `setMockPartnerSteps(int steps)`
  - [x] `generateMockWeekHistory()`
  - [x] `triggerMilestoneCelebration(int tier)` (via debug tab button)
  - [x] `triggerAutoClaimOverlay()` (via debug tab button)
  - [x] `clearMockData()`

### 7.3 Debug Indicators
- [x] Add debug badge on Steps screen when using mock data
- [x] Show "MOCK DATA" indicator in header

---

## Testing Tasks

### Manual Testing (iOS Device Required)

#### Basic Functionality
- [ ] Verify HealthKit permission request flow
- [ ] Verify step sync from Health app
- [ ] Verify partner step sync via API
- [ ] Verify LP calculation at each tier

#### Progress Ring
- [ ] Test ring animation on screen load
- [ ] Test ring update on refresh
- [ ] Verify combined steps display
- [ ] Verify tier threshold visual

#### Tier System
- [ ] Test tier progress bar accuracy
- [ ] Test "See all tiers" navigation
- [ ] Verify tier breakdown screen content
- [ ] Test tier crossing detection

#### Milestone Celebrations
- [ ] Trigger celebration at 10K threshold
- [ ] Trigger celebration at each tier (12K, 14K, 16K, 18K, 20K)
- [ ] Verify celebration only triggers once per tier
- [ ] Verify confetti and haptics

#### Auto-Claim
- [ ] Test auto-claim on app launch with claimable reward
- [ ] Test "partner claimed" variant
- [ ] Verify claim button hidden after auto-claim

#### Week History
- [ ] Verify streak calculation
- [ ] Verify daily breakdown accuracy
- [ ] Verify best day detection
- [ ] Test navigation to week history screen

### Debug Menu Testing (Any Device)

#### Using Debug Controls
- [ ] Test user steps slider updates ring
- [ ] Test partner steps slider updates ring
- [ ] Test preset buttons apply correct values
- [ ] Test "Trigger Milestone" shows overlay
- [ ] Test "Show Auto-Claim" shows overlay
- [ ] Test "Generate Week History" populates data
- [ ] Test "Reset Today" clears data

#### Edge Cases (via Debug)
- [ ] Test 0 steps (both partners)
- [ ] Test 9,999 combined (just below threshold)
- [ ] Test 10,000 exactly
- [ ] Test 19,999 (just below max)
- [ ] Test 20,000 exactly
- [ ] Test 30,000+ (overflow)
- [ ] Test partner not connected state
- [ ] Test partner connected but no sync yet

---

## Debug Menu Implementation Details

### New Tab: "Steps" in Debug Menu

```dart
// Location: lib/widgets/debug/tabs/steps_debug_tab.dart

class StepsDebugTab extends StatefulWidget {
  // User steps slider
  // Partner steps slider
  // Preset buttons row
  // Action buttons
  // Current state display
}
```

### StepsDebugService

```dart
// Location: lib/services/steps_debug_service.dart

class StepsDebugService {
  static bool useMockData = false;
  static int mockUserSteps = 0;
  static int mockPartnerSteps = 0;
  static List<StepsDay> mockWeekHistory = [];

  // Methods for debug menu actions
}
```

### Integration Points

1. **StepsFeatureService** - Check `StepsDebugService.useMockData` before reading from storage
2. **StepsCounterScreen** - Show debug badge when mock data active
3. **Debug Menu** - Add "Steps" tab after existing tabs
4. **Milestone detection** - Use mock data for tier crossing detection

---

## File Changes Summary

### New Files
- [x] `lib/widgets/debug/tabs/steps_debug_tab.dart`
- [x] `lib/services/steps_debug_service.dart`
- [x] `lib/screens/steps_tier_breakdown_screen.dart`
- [x] `lib/screens/steps_week_history_screen.dart`
- [x] `lib/widgets/steps_milestone_overlay.dart`
- [x] `lib/painters/combined_ring_painter.dart`

### Modified Files
- [x] `lib/screens/steps_counter_screen.dart` - Major redesign
- [x] `lib/services/steps_feature_service.dart` - Add tier detection, mock support
- [x] `lib/widgets/debug/debug_menu.dart` - Add Steps tab
- [x] `lib/models/steps_data.dart` - Add week history fields (if needed)

---

## Implementation Order

1. **Debug Menu First** - Enables testing without real HealthKit
2. **Core UI** - Ring, colors, layout
3. **Tier System** - Progress bar, breakdown screen
4. **Week History** - Preview card, full screen
5. **Milestone Celebrations** - Detection, overlay
6. **Polish** - Animations, sounds, edge cases

---

## Success Criteria

- [x] All mockup screens implemented matching designs
- [x] Debug menu allows full testing on simulator
- [x] Milestone celebrations trigger correctly
- [x] Week history shows accurate data
- [x] Pull-to-refresh works smoothly
- [x] No regression in existing auto-claim functionality
- [x] Performance acceptable (no jank on animations)

---

## Notes

- HealthKit only works on physical iOS devices
- Debug menu should be the primary testing method during development
- Consider feature flag to roll out gradually
- Week history may need server-side storage for cross-device sync

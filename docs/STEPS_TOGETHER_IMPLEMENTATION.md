# Steps Together - Implementation Plan

**Feature Overview:** A daily step-tracking feature that combines both partners' steps and rewards them with Love Points based on their combined total.

**Target Platform:** iOS only (HealthKit)

**Note:** This feature is iOS-exclusive. Android users will not see the Steps Together quest card.

**Mockups Location:** `/mockups/steps/selected/`

---

## Table of Contents

1. [Feature Summary](#feature-summary)
2. [User Interface Specifications](#user-interface-specifications)
3. [Data Architecture](#data-architecture)
4. [Implementation Phases](#implementation-phases)
5. [API Endpoints](#api-endpoints)
6. [Testing Checklist](#testing-checklist)

---

## Feature Summary

### Core Concept
- Both partners connect Apple Health (iOS only)
- Steps are tracked throughout the day and synced to Firebase
- Combined steps determine Love Point rewards
- Users claim yesterday's reward when opening the app
- Feature is hidden from Android users

### Reward Tiers
| Combined Steps | Love Points |
|----------------|-------------|
| 10,000 | +15 LP |
| 12,000 | +18 LP |
| 14,000 | +21 LP |
| 16,000 | +24 LP |
| 18,000 | +27 LP |
| 20,000+ | +30 LP (max) |

**Formula:** Base 15 LP at 10K, +3 LP per additional 2K steps, capped at 30 LP.

### Claim Model
- Rewards are claimed for **yesterday's** steps (not today's)
- 48-hour grace period to claim rewards
- Both partners must have synced for reward to be claimable
- Today's steps show as "in progress" with projected reward

---

## User Interface Specifications

### Screen Flow Overview

```
Home Screen (Side Quest Card)
    ↓ tap
Intro Screen (if not connected)
    ↓ connect
Counter Screen (main view)
    ↓ claim button
Reward Claim Screen (celebration)
```

---

### 1. Side Quest Cards (Home Screen Carousel)

These cards appear in the daily quests carousel on the home screen.

#### 1.1 Not Connected State
**Mockup:** [`01-side-quest-not-connected.html`](/mockups/steps/selected/01-side-quest-not-connected.html)

**When shown:** iOS user has not connected Apple Health

**Visual elements:**
- Grayed-out sneaker emoji (👟) with `filter: grayscale(100%)` and `opacity: 0.4`
- "Connect HealthKit" prompt text
- "Earn up to +30 LP daily" subtitle
- Card title: "Steps Together"
- Card subtitle: "Walk together, earn together"
- Reward badge: "+30" (grayed out)
- Action badge: "Connect"

**Tap action:** Navigate to intro screen (neither connected or partner connected variant)

---

#### 1.2 Today's Progress State
**Mockup:** [`02-side-quest-progress.html`](/mockups/steps/selected/02-side-quest-progress.html)

**When shown:** iOS user is connected to Apple Health and tracking steps today

**Visual elements:**
- Dual progress bars (you = black, partner = gray)
- Combined step count (e.g., "12,450 steps")
- Goal indicator: "/ 20,000"
- Projected reward: "Tomorrow: +18 LP"
- Reward badge: "+18" (calculated from current progress)
- Status badge: "In Progress"

**Data bindings:**
- `userSteps`: Current user's step count today
- `partnerSteps`: Partner's step count today
- `combinedSteps`: userSteps + partnerSteps
- `projectedLP`: Calculated from combinedSteps using tier formula

**Tap action:** Navigate to counter screen

---

#### 1.3 Claim Ready State
**Mockup:** [`03-side-quest-claim-ready.html`](/mockups/steps/selected/03-side-quest-claim-ready.html)

**When shown:** Yesterday's reward is ready to claim

**Visual elements:**
- Dark/inverted theme (black background, white text)
- Yesterday's combined steps prominently displayed
- "Claim Now" badge
- Earned LP amount: "+21 LP"
- "Ready to claim" label
- Pulsing/attention-grabbing animation (optional)

**Data bindings:**
- `yesterdaySteps`: Combined steps from yesterday
- `earnedLP`: LP earned from yesterday's steps
- `claimDeadline`: Timestamp for 48-hour expiry

**Tap action:** Navigate to counter screen (with claim section visible)

---

### 2. Intro Screens (First-Time Setup)

Shown when iOS user taps the side quest card and hasn't connected Apple Health yet.

#### 2.1 Neither Partner Connected
**Mockup:** [`03b-intro-neither-connected.html`](/mockups/steps/selected/03b-intro-neither-connected.html)

**When shown:** Neither user nor partner has connected Apple Health

**Visual elements:**
- Footprints illustration (👣) - all faded/inactive
- Two avatar circles, both gray (not connected)
  - "You" - "Not connected"
  - "[Partner name]" - "Not connected"
- Plus sign between avatars
- Equals row with "Up to +30 LP" bubble
- Title: "Steps Together"
- Description explaining the feature
- "How it works" section with 3 numbered steps:
  1. Connect Apple Health to share your step count
  2. Walk throughout the day - steps sync automatically
  3. Open the app tomorrow to claim your combined reward
- Primary button: "Connect Apple Health"
- Secondary button: "Maybe later"

**Primary button action:** Trigger Apple Health (HealthKit) permission request

---

#### 2.2 Partner Already Connected
**Mockup:** [`04-intro-partner-connected.html`](/mockups/steps/selected/04-intro-partner-connected.html)

**When shown:** Partner has connected Apple Health, user has not

**Visual elements:**
- Footprints illustration - some active
- Two avatar circles:
  - "You" - gray circle, "Not connected"
  - "[Partner name]" - black circle with checkmark, "Ready!"
- Title: "Steps Together"
- Description: "[Partner name] is already connected! Join them..."
- "How it works" section (same 3 steps)
- Primary button: "Connect Apple Health"
- Secondary button: "Maybe later"

**Motivation:** Creates social proof and urgency - partner is waiting

---

#### 2.3 Waiting for Partner
**Mockup:** [`05-intro-waiting-for-partner.html`](/mockups/steps/selected/05-intro-waiting-for-partner.html)

**When shown:** User has connected Apple Health, partner has not

**Visual elements:**
- Footprints illustration - some active
- Two avatar circles:
  - "You" - black circle with checkmark, "Connected!"
  - "[Partner name]" - gray circle with hourglass (⏳), "Waiting..."
- Title: "Almost There!"
- Description: "You're connected! Once [Partner] connects too..."
- "Reward Tiers" section showing all tier breakdowns
- Primary button: "Remind [Partner name]"
- Secondary button: "Done"
- Note: "Your steps are being tracked in the meantime"

**Primary button action:** Send push notification to partner

---

### 3. Counter Screens (Main Step Tracking View)

The primary view for tracking daily steps.

#### 3.1 Normal State (Under 20K)
**Mockup:** [`06-counter-normal.html`](/mockups/steps/selected/06-counter-normal.html)

**Visual elements:**

**Header:**
- Back button (←)
- Title: "Steps Together"

**Yesterday Section (if claimable):**
- Section label: "Yesterday" with "Claim Now" badge
- Yesterday's step count (e.g., "14,200")
- Earned reward (e.g., "+21 LP")
- "Ready to claim" label
- Full-width claim button: "Claim +21 Love Points"

**Today Section:**
- Label: "Today · In Progress"
- **Dual-ring progress visualization:**
  - Outer ring (black): User's steps progress
  - Inner ring (gray): Partner's steps progress
  - Size: 280×280px SVG
  - Outer ring radius: 115px
  - Inner ring radius: 90px
  - Stroke width: 14px
- **Center content:**
  - Combined step count (large, e.g., "12,450")
  - Goal text: "/ 20,000"
  - Projected reward: "Tomorrow: +18 LP"
- **Legend:**
  - "You: 7,000" (black square)
  - "[Partner]: 5,450" (gray square)
- **Sync status:**
  - "Last synced just now"
  - "[Partner] synced 15 min ago"

**Ring progress calculation:**
```
outerProgress = min(userSteps / 20000, 1.0)
innerProgress = min(partnerSteps / 20000, 1.0)
outerDashoffset = 720 * (1 - outerProgress)  // circumference ~720
innerDashoffset = 565 * (1 - innerProgress)  // circumference ~565
```

---

#### 3.2 Past 20K State (Goal Exceeded)
**Mockup:** [`07-counter-past-20k.html`](/mockups/steps/selected/07-counter-past-20k.html)

**When shown:** Combined steps exceed 20,000

**Visual elements:**

**Max Reward Banner (replaces yesterday section when no claim pending):**
- Black background
- "Max Tier Reached!" badge
- "Tomorrow you'll earn" text
- "+30 LP" large text

**Today Section:**
- Label: "Today · Goal Exceeded!"
- Dual-ring visualization at 100% (both rings full)
- Center content:
  - Combined step count (e.g., "24,500")
  - Overflow text: "+4,500 over goal"
  - "Goal: 20,000"
- Legend with individual counts
- **Overflow indicator section:**
  - Progress bar at 100% with striped overflow extension
  - "122% of daily goal · Keep going!"

**Tomorrow Preview:**
- "Tomorrow's Reward"
- "Maximum tier achieved"
- "+30 LP"

---

### 4. Reward Claim Screen

Celebration screen when claiming yesterday's reward.

**Mockup:** [`08-reward-claim.html`](/mockups/steps/selected/08-reward-claim.html)

**Visual elements:**

**Header:**
- Back button
- Title: "Claim Reward"

**Full-screen confetti overlay:**
- 30 animated confetti pieces
- Three sizes: large (16px), medium (12px), small (8px)
- Colors: black (#000), dark gray (#666), light gray (#999)
- Animation: 4-second fall with rotation and scale
- Covers entire container, not just hero section

**Hero Section (black background):**
- Large reward amount: "+21" (72px font)
- "Love Points" label
- Tier badge: "14K Tier Reached"

**Content Section:**

**Date header:**
- "Yesterday"
- Full date (e.g., "November 27, 2024")

**Partner breakdown:**
- Two avatar circles side by side
- Each shows:
  - Avatar initial
  - Step count (e.g., "8,200")
  - Name ("You" / "[Partner name]")

**Combined total section:**
- "Combined Steps" label
- Total (e.g., "14,200")
- Progress (e.g., "of 20,000 goal (71%)")

**Claim Section:**
- Full-width button: "Claim Reward"
- Meta info: "Expires in 36 hours" | "Both synced"

**Claim button action:**
1. Award LP to both partners
2. Mark claim as completed
3. Show success animation
4. Navigate back to counter screen or home

---

## Data Architecture

### Firebase RTDB Structure

```
/steps_data/{coupleId}/
  ├── {dateKey}/                    # Format: "2024-11-27"
  │   ├── user1_steps: 8200
  │   ├── user2_steps: 6000
  │   ├── user1_last_sync: 1732720000000
  │   ├── user2_last_sync: 1732719100000
  │   ├── combined_total: 14200
  │   └── claimed: false
  └── connection_status/
      ├── user1_connected: true
      ├── user2_connected: false
      ├── user1_connected_at: 1732700000000
      └── user2_connected_at: null
```

### Hive Local Storage

**Box: `steps_data`**
```dart
@HiveType(typeId: 20)
class StepsDay {
  @HiveField(0)
  String dateKey;           // "2024-11-27"

  @HiveField(1)
  int userSteps;

  @HiveField(2)
  int partnerSteps;

  @HiveField(3)
  DateTime lastSync;

  @HiveField(4)
  DateTime? partnerLastSync;

  @HiveField(5)
  bool claimed;

  @HiveField(6, defaultValue: 0)
  int earnedLP;
}

@HiveType(typeId: 21)
class StepsConnection {
  @HiveField(0)
  bool isConnected;

  @HiveField(1)
  DateTime? connectedAt;

  @HiveField(2)
  bool partnerConnected;

  @HiveField(3)
  DateTime? partnerConnectedAt;
}
```

### LP Calculation Service

```dart
class StepsLPCalculator {
  static int calculateLP(int combinedSteps) {
    if (combinedSteps < 10000) return 0;
    if (combinedSteps >= 20000) return 30;

    // +3 LP per 2000 steps above 10000
    int extraSteps = combinedSteps - 10000;
    int extraTiers = extraSteps ~/ 2000;
    return 15 + (extraTiers * 3);
  }

  static String getTierName(int combinedSteps) {
    if (combinedSteps >= 20000) return "20K";
    if (combinedSteps >= 18000) return "18K";
    if (combinedSteps >= 16000) return "16K";
    if (combinedSteps >= 14000) return "14K";
    if (combinedSteps >= 12000) return "12K";
    if (combinedSteps >= 10000) return "10K";
    return "Below 10K";
  }
}
```

---

## Implementation Phases

### Phase 1: Foundation & HealthKit Integration
**Duration:** Core infrastructure

#### Tasks:
1. **Add dependencies to `pubspec.yaml`:**
   ```yaml
   dependencies:
     health: ^10.2.0  # HealthKit integration
   ```

2. **Create Hive models:**
   - `lib/models/steps_data.dart` - StepsDay, StepsConnection
   - Run `flutter pub run build_runner build`

3. **Create StepsHealthService:**
   - `lib/services/steps_health_service.dart`
   - Check if platform is iOS (hide feature on Android)
   - Request HealthKit permissions
   - Read step count for today
   - Read step count for yesterday
   - Handle permission denied states

4. **Update iOS configuration:**
   - `ios/Runner/Info.plist` - Add HealthKit usage descriptions:
     ```xml
     <key>NSHealthShareUsageDescription</key>
     <string>TogetherRemind reads your step count to combine with your partner's steps and earn Love Points together.</string>
     <key>NSHealthUpdateUsageDescription</key>
     <string>TogetherRemind does not write health data.</string>
     ```
   - `ios/Runner/Runner.entitlements` - Add HealthKit entitlement
   - Enable HealthKit capability in Xcode

5. **Add platform check for Android:**
   - Hide Steps quest card on Android devices
   - Return early from StepsHealthService on non-iOS platforms

#### Phase 1 Testing Checklist:
- [ ] HealthKit permission request shows on iOS
- [ ] Feature is completely hidden on Android
- [ ] Can read today's step count after permission granted
- [ ] Can read yesterday's step count
- [ ] Permission denied state handled gracefully
- [ ] Step count persists to Hive storage
- [ ] Step count displays correctly in debug menu

---

### Phase 2: Firebase Sync & Partner Data
**Duration:** Real-time synchronization

#### Tasks:
1. **Create StepsSyncService:**
   - `lib/services/steps_sync_service.dart`
   - Write user's steps to Firebase RTDB
   - Listen for partner's step updates
   - Merge local and remote data
   - Handle offline/online transitions

2. **Update Firebase RTDB rules:**
   - `database.rules.json` - Add `/steps_data/` path rules
   - Ensure couple members can read/write their data
   - Deploy: `firebase deploy --only database`

3. **Create connection status management:**
   - Track when user connects health data
   - Sync connection status to Firebase
   - Listen for partner connection status

4. **Implement background sync:**
   - Sync steps periodically when app is open
   - Sync on app resume from background
   - Respect battery optimization

#### Phase 2 Testing Checklist:
- [ ] User steps sync to Firebase RTDB
- [ ] Partner steps appear in real-time
- [ ] Combined total calculates correctly
- [ ] Connection status syncs between devices
- [ ] Offline changes sync when back online
- [ ] Last sync timestamps update correctly
- [ ] Firebase rules prevent unauthorized access
- [ ] Two-device test: Alice's steps appear on Bob's device

---

### Phase 3: Side Quest Card Integration
**Duration:** Home screen integration

#### Tasks:
1. **Create StepsQuestCard widget:**
   - `lib/widgets/steps_quest_card.dart`
   - Three visual states based on mockups:
     - Not connected (grayed sneaker)
     - Today's progress (dual bars)
     - Claim ready (dark theme)

2. **Create StepsQuestService:**
   - `lib/services/steps_quest_service.dart`
   - Determine current card state
   - Calculate projected LP
   - Check for claimable rewards

3. **Integrate with DailyQuestsWidget:**
   - Add Steps card to carousel
   - Position based on priority (claim ready = high priority)
   - Handle tap navigation

4. **Add navigation routes:**
   - Route to intro screens
   - Route to counter screen
   - Handle deep linking (optional)

#### Phase 3 Testing Checklist:
- [ ] Not connected card shows when health not connected
- [ ] Progress card shows correct combined steps
- [ ] Progress card shows correct projected LP
- [ ] Claim ready card shows when yesterday's reward available
- [ ] Claim ready card has dark/inverted theme
- [ ] Tap navigates to correct screen based on state
- [ ] Card updates in real-time when partner steps change
- [ ] Card displays partner name correctly

---

### Phase 4: Intro Screens
**Duration:** Onboarding flow

#### Tasks:
1. **Create StepsIntroScreen:**
   - `lib/screens/steps_intro_screen.dart`
   - Three variants based on connection status:
     - Neither connected
     - Partner connected
     - Waiting for partner

2. **Implement visual components:**
   - Footprints illustration (👣 emojis with rotation)
   - Avatar circles with status badges
   - "How it works" / "Reward Tiers" sections

3. **Implement actions:**
   - "Connect Apple Health" button → HealthKit permission request
   - "Remind [Partner]" button → push notification (only if partner is on iOS)
   - "Maybe later" / "Done" → navigate back

4. **Create reminder notification:**
   - Cloud Function to send reminder
   - Notification content: "[Name] wants you to connect Steps Together!"
   - Only send to iOS devices (check platform in FCM token metadata)

#### Phase 4 Testing Checklist:
- [ ] Neither connected screen shows correct visual state
- [ ] Partner connected screen shows partner name and status
- [ ] Waiting for partner screen shows user as connected
- [ ] Connect button triggers HealthKit permission
- [ ] After permission granted, navigates to counter screen
- [ ] Remind button sends notification to partner (iOS partner only)
- [ ] Partner receives and can tap notification
- [ ] Maybe later returns to home without changes
- [ ] Remind button hidden or disabled if partner is on Android

---

### Phase 5: Counter Screen
**Duration:** Main tracking interface

#### Tasks:
1. **Create StepsCounterScreen:**
   - `lib/screens/steps_counter_screen.dart`
   - Yesterday claim section (conditional)
   - Today's progress section
   - Sync status display

2. **Create DualRingProgress widget:**
   - `lib/widgets/steps/dual_ring_progress.dart`
   - SVG-based ring visualization
   - Animated progress updates
   - Center content with combined count

3. **Create StepsLegend widget:**
   - `lib/widgets/steps/steps_legend.dart`
   - Color-coded breakdown
   - Individual step counts

4. **Implement overflow state:**
   - Detect when combined > 20,000
   - Show max banner
   - Display overflow indicator

5. **Add real-time updates:**
   - Stream step data from Firebase
   - Animate ring progress changes
   - Update sync timestamps

#### Phase 5 Testing Checklist:
- [ ] Rings display correct progress percentages
- [ ] Outer ring shows user's steps (black)
- [ ] Inner ring shows partner's steps (gray)
- [ ] Center shows correct combined total
- [ ] Legend shows individual breakdowns
- [ ] Projected LP calculates correctly
- [ ] Yesterday section shows when claim available
- [ ] Sync timestamps update correctly
- [ ] Overflow state shows when past 20K
- [ ] Max banner displays +30 LP
- [ ] Animations are smooth (60fps)

---

### Phase 6: Reward Claim Flow
**Duration:** Claim and celebration

#### Tasks:
1. **Create StepsClaimScreen:**
   - `lib/screens/steps_claim_screen.dart`
   - Full-screen confetti animation
   - Hero section with reward amount
   - Partner breakdown display

2. **Create ConfettiOverlay widget:**
   - `lib/widgets/steps/confetti_overlay.dart`
   - Multiple confetti pieces with varied sizes
   - CSS-like falling animation
   - Looping animation

3. **Implement claim logic:**
   - Validate claim is allowed (not expired, both synced)
   - Award LP via LovePointService
   - Mark day as claimed in Firebase
   - Update local Hive storage

4. **Add claim API endpoint:**
   - `api/app/api/steps/claim/route.ts`
   - Validate claim server-side
   - Atomic LP award to both partners
   - Return success/failure

5. **Handle edge cases:**
   - Claim already processed
   - 48-hour expiry
   - Partner hasn't synced yet

#### Phase 6 Testing Checklist:
- [ ] Confetti animates across entire screen
- [ ] Reward amount displays correctly
- [ ] Partner breakdown shows individual contributions
- [ ] Claim button awards LP to both partners
- [ ] LP counter updates immediately after claim
- [ ] Claimed day marked in Firebase
- [ ] Cannot claim same day twice
- [ ] Expired claims show appropriate message
- [ ] Claim works offline (queued)
- [ ] Two-device test: Both see LP update

---

### Phase 7: Polish & Edge Cases
**Duration:** Final refinements

#### Tasks:
1. **Add loading states:**
   - Skeleton loaders for cards
   - Progress indicators for sync
   - Button loading states

2. **Add error handling:**
   - Health data unavailable
   - Network errors during sync
   - Claim failures

3. **Add accessibility:**
   - VoiceOver/TalkBack labels
   - Semantic descriptions for rings
   - Reduce motion support

4. **Add haptics and sounds:**
   - Claim celebration haptic
   - Progress milestone sounds
   - Button tap feedback

5. **Performance optimization:**
   - Minimize Firebase reads
   - Cache step data locally
   - Debounce sync updates

6. **Add analytics:**
   - Track connection funnel
   - Track claim rates
   - Track daily engagement

#### Phase 7 Testing Checklist:
- [ ] Loading states appear during data fetch
- [ ] Error messages are user-friendly
- [ ] Offline mode works gracefully
- [ ] VoiceOver reads all elements correctly
- [ ] Reduce motion disables animations
- [ ] Haptics fire on claim
- [ ] No excessive Firebase reads
- [ ] Analytics events fire correctly
- [ ] Memory usage is stable
- [ ] Battery impact is minimal

---

## API Endpoints

### POST `/api/steps/sync`
Sync user's step data to server.

**Request:**
```json
{
  "userId": "uuid",
  "coupleId": "uuid",
  "dateKey": "2024-11-27",
  "steps": 8200,
  "timestamp": 1732720000000
}
```

**Response:**
```json
{
  "success": true,
  "partnerSteps": 6000,
  "partnerLastSync": 1732719100000,
  "combinedTotal": 14200
}
```

### POST `/api/steps/claim`
Claim yesterday's step reward.

**Request:**
```json
{
  "userId": "uuid",
  "coupleId": "uuid",
  "dateKey": "2024-11-26"
}
```

**Response:**
```json
{
  "success": true,
  "lpAwarded": 21,
  "tier": "14K",
  "combinedSteps": 14200,
  "userSteps": 8200,
  "partnerSteps": 6000
}
```

### GET `/api/steps/status`
Get current steps status for couple.

**Response:**
```json
{
  "today": {
    "userSteps": 7000,
    "partnerSteps": 5450,
    "combined": 12450,
    "projectedLP": 18
  },
  "yesterday": {
    "combined": 14200,
    "earnedLP": 21,
    "claimed": false,
    "expiresAt": 1732900000000
  },
  "connection": {
    "userConnected": true,
    "partnerConnected": true
  }
}
```

### POST `/api/steps/remind`
Send reminder notification to partner.

**Request:**
```json
{
  "userId": "uuid",
  "coupleId": "uuid"
}
```

**Response:**
```json
{
  "success": true,
  "notificationSent": true
}
```

---

## Testing Checklist

### Unit Tests
- [ ] LP calculation returns correct values for all tiers
- [ ] Date key generation handles timezone correctly
- [ ] Claim expiry calculation is accurate
- [ ] Connection status state machine works

### Integration Tests
- [ ] HealthKit reads actual device steps (iOS only)
- [ ] Firebase sync writes and reads correctly
- [ ] Push notifications deliver successfully
- [ ] LP award updates both partners
- [ ] Feature hidden on Android devices

### End-to-End Tests
- [ ] Full flow: Connect → Track → Claim
- [ ] Two-device sync works in real-time
- [ ] Offline → Online sync recovers
- [ ] Claim works within 48-hour window

### Manual Testing Scenarios
1. **Fresh install:** Both partners connect for first time (iOS)
2. **One connected:** Partner already connected, user joins
3. **Daily tracking:** Steps update throughout day
4. **Claim flow:** Open app next day, claim reward
5. **Max tier:** Both walk 10K+ steps each
6. **Expired claim:** Wait 48+ hours, see expiry message
7. **Offline claim:** Claim while offline, sync later
8. **Android user:** Verify quest card is not shown
9. **Mixed couple:** One iOS, one Android - feature works for iOS user only

---

## File Structure

```
lib/
├── models/
│   └── steps_data.dart              # StepsDay, StepsConnection
├── services/
│   ├── steps_health_service.dart    # HealthKit integration (iOS only)
│   ├── steps_sync_service.dart      # Firebase sync
│   ├── steps_quest_service.dart     # Quest card state + platform check
│   └── steps_lp_calculator.dart     # LP tier calculation
├── screens/
│   ├── steps_intro_screen.dart      # Onboarding flow
│   ├── steps_counter_screen.dart    # Main tracking view
│   └── steps_claim_screen.dart      # Reward celebration
└── widgets/
    └── steps/
        ├── steps_quest_card.dart    # Home carousel card
        ├── dual_ring_progress.dart  # SVG ring visualization
        ├── steps_legend.dart        # Color-coded breakdown
        └── confetti_overlay.dart    # Celebration animation

api/
└── app/api/steps/
    ├── sync/route.ts                # Sync endpoint
    ├── claim/route.ts               # Claim endpoint
    ├── status/route.ts              # Status endpoint
    └── remind/route.ts              # Reminder notification
```

---

## References

### Mockup Files
All UI mockups are located in `/mockups/steps/selected/`:

| Screen | File | Description |
|--------|------|-------------|
| Side Quest - Not Connected | `01-side-quest-not-connected.html` | Grayed sneaker, connect prompt |
| Side Quest - Progress | `02-side-quest-progress.html` | Dual bars, combined count |
| Side Quest - Claim Ready | `03-side-quest-claim-ready.html` | Dark theme, claim emphasis |
| Intro - Neither Connected | `03b-intro-neither-connected.html` | Both avatars gray |
| Intro - Partner Connected | `04-intro-partner-connected.html` | Partner has checkmark |
| Intro - Waiting | `05-intro-waiting-for-partner.html` | User connected, partner waiting |
| Counter - Normal | `06-counter-normal.html` | Dual rings under 20K |
| Counter - Past 20K | `07-counter-past-20k.html` | Max tier, overflow indicator |
| Reward Claim | `08-reward-claim.html` | Full-screen confetti celebration |

### Index Page
`/mockups/steps/selected/index.html` - Overview of all 9 screens with navigation

---

**Document Created:** 2025-11-28
**Last Updated:** 2025-11-28
**Author:** Claude Code

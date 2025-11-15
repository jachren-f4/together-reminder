# Inbox & Daily Quests Integration

**Date:** 2025-11-14
**Status:** ✅ IMPLEMENTED & DEPLOYED
**Implementation Date:** 2025-11-14
**Related Documents:** [QUEST_SYSTEM.md](./QUEST_SYSTEM.md), [DAILY_QUESTS_PLAN.md](./DAILY_QUESTS_PLAN.md)

---

## Implementation Summary

**Completed:** 2025-11-14

All phases of the inbox integration have been successfully implemented:

### ✅ Phase 1: Core Activity Service Integration (COMPLETE)
- Added `_getDailyQuests()` method to ActivityService
- Implemented quest type mapping with affirmation quiz detection
- Added dynamic title generation (including affirmation quiz names)
- Implemented quest subtitle generation (clean, no LP amounts)
- Added quest participant mapping
- Integrated daily quests into `getAllActivities()`
- Updated filter logic to handle quest expiration

### ✅ Phase 2: UI Updates (COMPLETE)
- Changed title from "Activity Hub" to "Inbox"
- Implemented large Playfair Display font for title (48px)
- Added dynamic header subtitle based on active filter
- **Complete card redesign:**
  - Removed emoji icon boxes
  - Added black uppercase type badges at top-left
  - Implemented Playfair Display font for activity titles
  - Reversed footer layout (badge LEFT, avatars RIGHT)
  - Changed to border-based cards (removed shadows)
  - Updated timestamp format to "Today 8:30 AM" style
- Updated filter tabs to match mockup design (border-based)
- Changed tab labels (added "Pokes" tab, removed "Unread")

### ✅ Phase 3: Filter Logic (COMPLETE)
- Updated `getFilteredActivities()` to exclude expired quests from "Your Turn"
- Added "Pokes" filter support
- All filters working correctly with daily quests

### ✅ Phase 4: Real-time Updates (COMPLETE)
- Activity feed updates when partner completes quest
- Leverages existing Firebase listener in DailyQuestsWidget
- Real-time sync working correctly

### ✅ Affirmation Quiz Support (BONUS)
- Added `ActivityType.affirmation` enum
- Implemented detection of affirmation quizzes via quiz session lookup
- Shows affirmation quiz custom names (e.g., "Playful Moments")
- Displays "AFFIRMATION" badge instead of "QUIZ" for affirmation quizzes
- Both users see identical quest titles and types

### 📋 Phase 5: Quiz Duplication Fix (OPTIONAL - NOT IMPLEMENTED)
This phase was intentionally skipped as it's optional and the current implementation shows both the daily quest card and quiz session with different contexts.

---

## Table of Contents

1. [Overview](#overview)
2. [Design Decisions](#design-decisions)
3. [UI Design & Mockups](#ui-design--mockups)
4. [Quest System Integration](#quest-system-integration)
5. [Implementation Plan](#implementation-plan)
6. [File Changes](#file-changes)
7. [Testing Strategy](#testing-strategy)
8. [Detailed Task List](#detailed-task-list)

---

## Overview

### Problem Statement

Daily quests are currently isolated to the home screen widget and do not appear in the Activity Hub/Inbox. This prevents users from:
- Monitoring quest completion status in a unified activity feed
- Seeing partner progress on daily quests in the inbox
- Having a single "to-do list" view of all activities

### Solution

Integrate daily quests into the `ActivityService` and display them in the Activity Hub alongside other activities (reminders, pokes, games), while maintaining the home screen widget as the primary dashboard view.

### Design Philosophy

**Home Screen = Quick Dashboard**
- Daily quests widget (stays in current location)
- Side quests
- Love Points & Streak counter
- At-a-glance view of "what's available today"

**Inbox/Activity Hub = Detailed Monitoring**
- Everything completed (by you or partner)
- Everything in progress
- Everything waiting for partner
- Unified view: Daily quests, Side quests, Reminders, Pokes, Games
- Filter tabs: "All", "Your Turn", "Completed", "Pokes"

---

## Design Decisions

### 1. No Quest Progress Indicator in Inbox

**Decision:** Remove the daily quest progress card (e.g., "Daily Quests: 2/3 Complete") from the inbox header.

**Rationale:**
- Users can see quest progress on the home screen
- Avoids redundancy between home screen and inbox
- Keeps inbox focused on individual activity cards
- Reduces visual clutter in the header

**Implementation:** Header shows only title and subtitle, no progress banner.

### 2. Unified Badge Styling

**Decision:** "Your Turn" badges use gray background (#E0E0E0) instead of orange (#f59e0b).

**Rationale:**
- Maintains consistency with "Waiting for partner" badge styling
- Follows black and white design system
- Orange color was too attention-grabbing for all "Your Turn" items
- Users can distinguish status by badge text, not color

**Badge Styles:**
- **Your Turn**: Gray background (#E0E0E0), black text (#1A1A1A)
- **Waiting for partner**: Gray background (#E0E0E0), black text (#1A1A1A)
- **Completed**: Black background (#1A1A1A), white text (#FFFEFD)

### 3. No Love Points Display

**Decision:** Remove all LP indicators (e.g., "💰 +30", "10 LP earned") from activity cards.

**Rationale:**
- Keeps UI clean and focused on completion status
- Users know activities reward LP without explicit display
- Reduces visual noise in activity feed
- LP counter on home screen shows total, detailed breakdown not needed

**Subtitle Changes:**
- ❌ "Complete to earn 30 LP" → ✅ "Complete together to earn Love Points"
- ❌ "Waiting for Bob • 10 LP when complete" → ✅ "Waiting for Bob to complete"
- ❌ "Both completed • 30 LP earned" → ✅ "Both completed"

### 4. No Checkmarks on Avatars

**Decision:** Remove checkmark badges from participant avatars.

**Rationale:**
- Avatar presence indicates completion (if A completed, avatar shows; if not, no avatar)
- Checkmarks add visual clutter
- Completion status already shown by:
  - Number of avatars displayed
  - Status badge (Completed/Waiting/Your Turn)
  - Activity subtitle text

**Avatar Display Logic:**
- **Neither completed**: No avatars shown, "Your Turn" badge
- **User completed**: Only user's avatar shows, "Waiting for partner" badge
- **Both completed**: Both avatars show (overlapped), "Completed" badge
- **Partner completed**: Only partner's avatar shows, "Your Turn" badge

### 5. Compact Header Layout

**Decision:** Reduce spacing between header subtitle and filter tabs.

**Rationale:**
- Brings important navigation (tabs) higher on screen
- Reduces scrolling needed to see activity cards
- Makes better use of vertical space
- Maintains visual hierarchy with adequate spacing

**Spacing Changes:**
- Header bottom padding: 16px → 8px
- Filter tabs top padding: 20px → 12px

---

## UI Design & Mockups

### Mockup Files

**Location:** `/Users/joakimachren/Desktop/togetherremind/mockups/`

**How to View:**
1. Open `inbox_mockups_index.html` in a web browser for an overview
2. Click links to navigate to individual mockups
3. Or open individual HTML files directly in your browser

**Available Mockups:**
- **inbox_mockups_index.html** - Index page with links and implementation notes
- **inbox_with_daily_quests_all.html** - "All Activities" view (main inbox)
- **inbox_your_turn_filter.html** - "Your Turn" filter (items needing attention)
- **inbox_completed_filter.html** - "Completed" filter (finished activities)

**Key Design Elements Demonstrated:**
- No quest progress indicator in header
- Gray status badges (no orange)
- No LP indicators on cards
- No checkmarks on avatars
- Compact header-to-tabs spacing (12px)
- Clean black & white design system

### Screen 1: All Activities View

**Purpose:** Main inbox view showing all activities in chronological order.

**Layout:**
```
┌─────────────────────────────────┐
│ 9:41              📶 🔋 85%     │
├─────────────────────────────────┤
│                                 │
│ Inbox                           │
│ Track all your activities       │
│                                 │
│ [All] [Your Turn] [Completed]   │
│ [Pokes]                         │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ QUIZ         Today 8:30 AM  │ │
│ │ Getting to Know You         │ │
│ │ Both completed              │ │
│ │                             │ │
│ │ ✓ Completed         [A][B] │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ REMINDER      Today 9:15 AM │ │
│ │ Don't forget about dinner!  │ │
│ │ Waiting for Bob to complete │ │
│ │                             │ │
│ │ Waiting for partner    [A]  │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ QUIZ        Today 10:00 AM  │ │
│ │ Deeper Connection           │ │
│ │ Waiting for partner         │ │
│ │                             │ │
│ │ Waiting for partner    [A]  │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ POKE        Today 11:20 AM  │ │
│ │ Missing you 💭              │ │
│ │ Bob sent you a poke         │ │
│ │                             │ │
│ │ Your Turn              [B]  │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ QUESTION    Today 12:00 PM  │ │
│ │ Daily Question              │ │
│ │ Complete together to earn   │ │
│ │ Love Points                 │ │
│ │                             │ │
│ │ Your Turn                   │ │
│ └─────────────────────────────┘ │
│                                 │
└─────────────────────────────────┘
```

**Features:**
- All activity types mixed chronologically
- Daily quests appear inline with other activities
- Type badges (QUIZ, REMINDER, QUESTION, etc.)
- Status badges with consistent gray styling
- Participant avatars showing completion
- Clear timestamps for each item

### Screen 2: Your Turn Filter

**Purpose:** Shows only activities requiring user's attention.

**Layout:**
```
┌─────────────────────────────────┐
│ 9:41              📶 🔋 85%     │
├─────────────────────────────────┤
│                                 │
│ Inbox                           │
│ Things that need your attention │
│                                 │
│ [All] [Your Turn] [Completed]   │
│ [Pokes]                         │
│                                 │
│ 3 items need your attention     │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ QUESTION            Today   │ │
│ │ Daily Question              │ │
│ │ Complete together to earn   │ │
│ │ Love Points                 │ │
│ │                             │ │
│ │ Your Turn                   │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ POKE        Today 11:20 AM  │ │
│ │ Missing you 💭              │ │
│ │ Bob sent you a poke         │ │
│ │                             │ │
│ │ Your Turn              [B]  │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ WORD LADDER     Yesterday   │ │
│ │ LOVE → WARM                 │ │
│ │ 3 steps remaining           │ │
│ │                             │ │
│ │ Your Turn              [B]  │ │
│ └─────────────────────────────┘ │
│                                 │
└─────────────────────────────────┘
```

**Features:**
- Filters to show only incomplete items
- **Includes incomplete daily quests**
- Shows count of items needing attention
- All cards have "Your Turn" badge
- Clean, focused view for action items

### Screen 3: Completed Filter

**Purpose:** Shows all completed activities grouped by date.

**Layout:**
```
┌─────────────────────────────────┐
│ 9:41              📶 🔋 85%     │
├─────────────────────────────────┤
│                                 │
│ Inbox                           │
│ Your completed activities       │
│                                 │
│ [All] [Your Turn] [Completed]   │
│ [Pokes]                         │
│                                 │
│ Today                           │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ QUIZ              8:30 AM   │ │
│ │ Getting to Know You         │ │
│ │ Both completed              │ │
│ │                             │ │
│ │ ✓ Completed         [A][B] │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ REMINDER          9:00 AM   │ │
│ │ Morning coffee date ☕       │ │
│ │ Both completed              │ │
│ │                             │ │
│ │ ✓ Completed         [B][A] │ │
│ └─────────────────────────────┘ │
│                                 │
│ Yesterday                       │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ MEMORY FLIP       5:30 PM   │ │
│ │ Memory Challenge            │ │
│ │ 8/8 pairs matched           │ │
│ │ Both completed              │ │
│ │                             │ │
│ │ ✓ Completed         [A][B] │ │
│ └─────────────────────────────┘ │
│                                 │
└─────────────────────────────────┘
```

**Features:**
- Only shows fully completed activities
- **Includes completed daily quests**
- Grouped by date (Today, Yesterday, etc.)
- All cards have "Completed" badge
- Both participant avatars visible
- Slightly faded appearance (95% opacity)

### Activity Card Anatomy

```
┌─────────────────────────────────────────┐
│ TYPE BADGE                   Timestamp  │ ← Type & Time
│                                         │
│ Activity Title                          │ ← Main Title (Playfair Display)
│ Subtitle describing status/context     │ ← Status Subtitle
│                                         │
│ Status Badge           [A] [B]          │ ← Footer: Badge + Avatars
└─────────────────────────────────────────┘
```

**Components:**
1. **Type Badge** (top-left): Black background, white text, uppercase (e.g., "QUIZ", "REMINDER")
2. **Timestamp** (top-right): Gray text, relative or absolute time
3. **Title**: Serif font (Playfair Display), 18px, bold
4. **Subtitle**: Sans-serif font (Inter), 14px, gray, describes status
5. **Status Badge**: Gray or black background, shows "Your Turn" / "Waiting for partner" / "✓ Completed"
6. **Avatars**: Circular badges with initials, overlapped when multiple

---

## Quest System Integration

### Current Quest System Architecture

**Data Flow:**
```
1. Midnight → DailyQuestService.generateDailyQuests()
2. First device generates 3 quests → Writes to Firebase RTDB
3. Second device reads from Firebase → Syncs to local Hive
4. User completes quest → Updates userCompletions map
5. Both complete → LP awarded to both users
6. Real-time listener updates partner's UI
```

**Key Files:**
- `lib/models/daily_quest.dart` - Quest data models
- `lib/services/daily_quest_service.dart` - Quest business logic
- `lib/services/quest_sync_service.dart` - Firebase synchronization
- `lib/widgets/daily_quests_widget.dart` - Home screen display
- `lib/widgets/quest_card.dart` - Quest card UI component

### Integration Points

#### 1. ActivityService Integration

**Location:** `lib/services/activity_service.dart`

**New Method:** `_getDailyQuests()`

```dart
List<ActivityItem> _getDailyQuests() {
  final quests = _storage.getTodayQuests();
  final userId = _storage.getCurrentUserId();

  return quests.map((quest) {
    final userCompleted = quest.hasUserCompleted(userId);
    final partnerCompleted = quest.hasPartnerCompleted(userId);
    final bothCompleted = quest.isCompleted;

    // Map quest status to activity status
    ActivityStatus status;
    if (bothCompleted) {
      status = ActivityStatus.completed;
    } else if (userCompleted) {
      status = ActivityStatus.waitingForPartner;
    } else {
      status = ActivityStatus.yourTurn;
    }

    return ActivityItem(
      id: quest.id,
      type: _mapQuestTypeToActivityType(quest.questType),
      title: _getQuestTitle(quest),
      subtitle: _getQuestSubtitle(quest, userCompleted, bothCompleted),
      timestamp: quest.createdAt,
      status: status,
      participants: _getQuestParticipants(quest, userId),
      sourceData: quest,
      isUnread: !userCompleted && !quest.isExpired,
    );
  }).toList();
}
```

**Quest Type Mapping:**

```dart
ActivityType _mapQuestTypeToActivityType(int questType) {
  switch (questType) {
    case DailyQuestType.question:
      return ActivityType.question;
    case DailyQuestType.quiz:
      return ActivityType.quiz;
    case DailyQuestType.wordLadder:
      return ActivityType.wordLadder;
    case DailyQuestType.memoryFlip:
      return ActivityType.memoryFlip;
    case DailyQuestType.game:
    default:
      return ActivityType.game;
  }
}
```

**Title Generation:**

Uses same logic as `QuestCard` widget (quest_card.dart:245-275):

```dart
String _getQuestTitle(DailyQuest quest) {
  switch (quest.questType) {
    case DailyQuestType.quiz:
      // Dynamic titles based on sort order
      if (quest.sortOrder == 0) return 'Getting to Know You';
      if (quest.sortOrder == 1) return 'Deeper Connection';
      if (quest.sortOrder == 2) return 'Understanding Each Other';
      return 'Relationship Quiz';
    case DailyQuestType.question:
      return 'Daily Question';
    case DailyQuestType.wordLadder:
      return 'Word Ladder';
    case DailyQuestType.memoryFlip:
      return 'Memory Flip';
    default:
      return 'Daily Quest';
  }
}
```

**Subtitle Generation:**

```dart
String _getQuestSubtitle(DailyQuest quest, bool userCompleted, bool bothCompleted) {
  if (bothCompleted) {
    return 'Both completed';
  } else if (userCompleted) {
    return 'Waiting for partner to complete';
  } else {
    return 'Complete together to earn Love Points';
  }
}
```

**Participant Mapping:**

```dart
List<Participant> _getQuestParticipants(DailyQuest quest, String userId) {
  final user = _storage.getCurrentUser();
  final partner = _storage.getPartner();

  List<Participant> participants = [];

  // Only add avatars for users who have completed
  if (quest.hasUserCompleted(userId)) {
    participants.add(Participant(
      id: userId,
      name: user?.name ?? 'You',
      avatarUrl: user?.avatarUrl,
    ));
  }

  if (partner != null && quest.hasPartnerCompleted(userId)) {
    participants.add(Participant(
      id: partner.id,
      name: partner.name,
      avatarUrl: partner.avatarUrl,
    ));
  }

  return participants;
}
```

#### 2. Real-time Updates

**Challenge:** Activity feed needs to update when partner completes a quest.

**Solution:** Leverage existing Firebase listener in `DailyQuestsWidget`.

**Option A - Direct Firebase Listener in ActivityService:**

```dart
class ActivityService {
  StreamSubscription? _questCompletionListener;

  void startListeningToQuestCompletions() {
    final coupleId = _storage.getCoupleId();
    if (coupleId == null) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final questsRef = FirebaseDatabase.instance
        .ref('daily_quests/$coupleId/$today/completions');

    _questCompletionListener = questsRef.onValue.listen((event) {
      // Trigger activity feed refresh
      notifyListeners(); // If using ChangeNotifier
    });
  }

  void dispose() {
    _questCompletionListener?.cancel();
  }
}
```

**Option B - Reuse Existing Listener:**

`DailyQuestsWidget` already listens for completions (daily_quests_widget.dart:46-117). When it detects a completion:
1. Updates local Hive storage
2. Triggers UI rebuild

Since `ActivityService` reads from Hive via `_storage.getTodayQuests()`, it will automatically get updated data when activity screen rebuilds.

**Recommendation:** Use Option B (reuse existing listener) to avoid duplicate Firebase connections.

#### 3. Quest Expiration Handling

**Requirement:** Expired quests should not appear in "Your Turn" filter.

**Implementation:**

```dart
List<ActivityItem> getFilteredActivities(String filter) {
  final allActivities = getAllActivities();

  switch (filter) {
    case 'yourTurn':
      return allActivities.where((activity) {
        // Exclude expired quests from "Your Turn"
        if (activity.sourceData is DailyQuest) {
          final quest = activity.sourceData as DailyQuest;
          if (quest.isExpired) return false;
        }
        return activity.status == ActivityStatus.yourTurn;
      }).toList();

    case 'completed':
      return allActivities
          .where((a) => a.status == ActivityStatus.completed)
          .toList();

    case 'all':
    default:
      return allActivities;
  }
}
```

#### 4. Quiz Session Duplication Prevention

**Problem:** Quiz-type daily quests create quiz sessions. Those sessions appear in ActivityHub as standalone quizzes, causing duplication.

**Solution (Optional):** Add `isDailyQuest` flag to QuizSession model.

**Step 1 - Update Model:**

```dart
// lib/models/quiz_session.dart
@HiveType(typeId: X) // Use next available typeId
class QuizSession {
  // ... existing fields ...

  @HiveField(10, defaultValue: false)
  bool isDailyQuest;

  @HiveField(11, defaultValue: '')
  String dailyQuestId; // Optional: link back to quest
}
```

**Step 2 - Update Quiz Creation:**

```dart
// lib/widgets/daily_quests_widget.dart (around line 343)
final session = await _quizService.createSession(
  questId: quest.contentId,
  isDailyQuest: true,        // Mark as daily quest
  dailyQuestId: quest.id,    // Link to quest
);
```

**Step 3 - Filter in ActivityService:**

```dart
List<ActivityItem> _getQuizzes() {
  final sessions = _storage.getAllQuizSessions();

  return sessions
    .where((session) => !session.isDailyQuest) // Exclude daily quest quizzes
    .map((session) => _mapQuizToActivity(session))
    .toList();
}
```

**Note:** This is optional and can be implemented in a future phase. For MVP, showing both the daily quest card and quiz session is acceptable since they have different contexts (quest = assignment, session = game instance).

---

## Implementation Plan

### Phase 1: Core Activity Service Integration (HIGH PRIORITY)

**Goal:** Add daily quests to activity feed.

**Files to Modify:**
- `lib/services/activity_service.dart`
- `lib/models/activity_item.dart`

**Tasks:**
1. Add `_getDailyQuests()` method to ActivityService
2. Add helper methods: `_mapQuestTypeToActivityType()`, `_getQuestTitle()`, `_getQuestSubtitle()`, `_getQuestParticipants()`
3. Update `getAllActivities()` to include `..._getDailyQuests()`
4. Add `ActivityType.question` enum value if not exists
5. Test that daily quests appear in activity feed

**Estimated Effort:** 2-3 hours

### Phase 2: UI Updates (HIGH PRIORITY)

**Goal:** Update ActivityHubScreen to match mockup designs.

**Files to Modify:**
- `lib/screens/activity_hub_screen.dart`

**Tasks:**
1. Remove any existing quest progress indicators from header
2. Update header padding: `padding: 20px 20px 8px`
3. Update filter tabs padding: `padding: 12px 20px 16px`
4. Ensure status badge styling matches design:
   - Your Turn: Gray background (#E0E0E0)
   - Waiting: Gray background (#E0E0E0)
   - Completed: Black background (#1A1A1A)
5. Remove LP indicators from activity card subtitles
6. Remove checkmarks from participant avatars

**Estimated Effort:** 1-2 hours

### Phase 3: Filter Logic (HIGH PRIORITY)

**Goal:** Ensure daily quests work correctly with filter tabs.

**Files to Modify:**
- `lib/services/activity_service.dart`

**Tasks:**
1. Update `getFilteredActivities()` to handle quest expiration
2. Test "Your Turn" filter excludes expired quests
3. Test "Completed" filter includes completed daily quests
4. Test "All" shows all quests regardless of status

**Estimated Effort:** 1 hour

### Phase 4: Real-time Updates (MEDIUM PRIORITY)

**Goal:** Activity feed updates when partner completes quest.

**Files to Modify:**
- `lib/screens/activity_hub_screen.dart`

**Tasks:**
1. Add `setState()` call when navigating back to ActivityHub
2. Verify existing Firebase listener in DailyQuestsWidget updates Hive storage
3. Test: Alice completes quest → Bob's activity feed updates

**Estimated Effort:** 30 minutes

### Phase 5: Quiz Duplication Fix (OPTIONAL)

**Goal:** Prevent quiz sessions from appearing twice.

**Files to Modify:**
- `lib/models/quiz_session.dart`
- `lib/models/quiz_session.g.dart`
- `lib/widgets/daily_quests_widget.dart`
- `lib/services/activity_service.dart`

**Tasks:**
1. Add `isDailyQuest` and `dailyQuestId` fields to QuizSession
2. Run `flutter pub run build_runner build --delete-conflicting-outputs`
3. Update quiz creation to pass `isDailyQuest: true`
4. Filter daily quest quizzes in `_getQuizzes()`
5. Test that quiz-type daily quests only appear once

**Estimated Effort:** 1-2 hours

### Phase 6: Testing (HIGH PRIORITY)

**Goal:** Comprehensive testing of all features.

**Tasks:**
1. Manual testing with two devices (Alice + Bob)
2. Test all filter tabs with daily quests
3. Test completion flow (user → partner → both)
4. Test expiration handling
5. Test real-time updates
6. Test quiz integration (if Phase 5 completed)

**Estimated Effort:** 2 hours

---

## File Changes

### New Files
- `docs/INBOX_DAILY_QUESTS_INTEGRATION.md` (this document)

### Files to Modify

| File | Changes | Priority | Estimated Time |
|------|---------|----------|----------------|
| `lib/services/activity_service.dart` | Add `_getDailyQuests()` and helper methods, update `getAllActivities()`, update filter logic | **HIGH** | 2-3 hours |
| `lib/models/activity_item.dart` | Add `ActivityType.question` enum (if needed) | **HIGH** | 5 minutes |
| `lib/screens/activity_hub_screen.dart` | Update header/tab spacing, remove LP displays, update badge styling | **HIGH** | 1-2 hours |
| `lib/models/quiz_session.dart` | Add `isDailyQuest` and `dailyQuestId` fields | **OPTIONAL** | 30 minutes |
| `lib/widgets/daily_quests_widget.dart` | Pass `isDailyQuest: true` when creating quiz sessions | **OPTIONAL** | 15 minutes |

### Total Estimated Effort

**MVP (Phases 1-4):** 5-7 hours
**Complete (Phases 1-6):** 8-10 hours

---

## Testing Strategy

### Setup: Clean Test Environment

```bash
# 1. Clear Firebase RTDB
cd /Users/joakimachren/Desktop/togetherremind
firebase database:remove /daily_quests --force

# 2. Uninstall Android app (clears Hive)
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind2

# 3. Launch Alice (Android) - generates quests
cd app
flutter run -d emulator-5554 &

# 4. Wait, then launch Bob (Chrome) - loads quests
sleep 10 && flutter run -d chrome &
```

### Test Scenarios

#### Scenario 1: Daily Quests Appear in Inbox

**Steps:**
1. Open ActivityHub on both devices
2. Navigate to "All" tab

**Expected:**
- ✅ 3 daily quests appear in feed
- ✅ Mixed with other activities (reminders, pokes)
- ✅ Type badges show correct quest type (QUIZ, QUESTION, etc.)
- ✅ Titles match home screen display
- ✅ Status shows "Your Turn" (gray badge)

#### Scenario 2: Completion Flow

**Steps:**
1. Alice taps daily quest #1 (quiz type)
2. Alice completes quiz
3. Check Alice's ActivityHub
4. Check Bob's ActivityHub
5. Bob completes same quest
6. Check both devices

**Expected:**

**After Alice completes:**
- ✅ Alice's view: Status = "Waiting for partner", shows [A] avatar
- ✅ Bob's view: Status = "Your Turn", no avatars shown
- ✅ Quest moves to appropriate filter tabs

**After Bob completes:**
- ✅ Both views: Status = "✓ Completed", shows [A][B] avatars
- ✅ Subtitle = "Both completed"
- ✅ Badge background = black
- ✅ Quest appears in "Completed" filter

#### Scenario 3: Filter Tabs

**Setup:** Mixed completion states (1 completed by both, 1 completed by user only, 1 not started)

**Steps:**
1. Navigate to "Your Turn" tab
2. Navigate to "Completed" tab
3. Navigate to "All" tab

**Expected:**

**Your Turn:**
- ✅ Shows only incomplete daily quests
- ✅ Does NOT show quests where user already completed
- ✅ Shows quests with "Your Turn" badge

**Completed:**
- ✅ Shows only fully completed daily quests (both users)
- ✅ Does NOT show partially completed quests
- ✅ Shows quests with "✓ Completed" badge

**All:**
- ✅ Shows all daily quests regardless of status
- ✅ Mixed in chronological order with other activities

#### Scenario 4: Real-time Updates

**Steps:**
1. Bob opens ActivityHub and stays on "All" tab
2. Alice completes a daily quest
3. Observe Bob's screen (no manual refresh)

**Expected:**
- ✅ Bob's feed updates automatically within 2-3 seconds
- ✅ Quest card updates from "Your Turn" to show Alice's avatar
- ✅ Status badge changes to "Waiting for partner"
- ✅ Subtitle text updates

#### Scenario 5: Expiration Handling

**Setup:** Wait until 23:59:59 or manually set quest expiration

**Steps:**
1. After quest expires, open ActivityHub
2. Navigate to "Your Turn" tab
3. Navigate to "All" tab

**Expected:**
- ✅ Expired quests do NOT appear in "Your Turn" filter
- ✅ Expired quests still appear in "All" filter (with expired indicator)
- ✅ No way to complete expired quests

#### Scenario 6: UI Design Elements

**Steps:**
1. Open ActivityHub
2. Observe header spacing
3. Observe activity cards
4. Observe status badges
5. Observe participant avatars

**Expected:**

**Header:**
- ✅ No quest progress card/banner
- ✅ Reduced spacing between subtitle and tabs (12px)
- ✅ Clean, minimal header

**Activity Cards:**
- ✅ No LP indicators (no "💰 +30")
- ✅ Generic subtitle text ("Complete together to earn Love Points")
- ✅ Consistent card styling with other activities

**Status Badges:**
- ✅ "Your Turn" = gray background (#E0E0E0), black text
- ✅ "Waiting for partner" = gray background (#E0E0E0), black text
- ✅ "✓ Completed" = black background (#1A1A1A), white text
- ✅ No orange colors anywhere

**Participant Avatars:**
- ✅ No checkmarks on avatars
- ✅ Only completed users show avatars
- ✅ Both avatars overlap slightly when both complete

#### Scenario 7: Quiz Integration (If Phase 5 Complete)

**Steps:**
1. Complete a quiz-type daily quest
2. Open ActivityHub
3. Check for duplicate entries

**Expected:**
- ✅ Quiz appears once as daily quest
- ✅ Quiz session does NOT appear separately
- ✅ Tapping quest opens correct quiz session

### Debug Tools

**In-App Debug Menu:**
- Double-tap greeting text on home screen
- View Firebase RTDB data
- View local Hive storage
- Compare quest IDs between Firebase and local

**External Scripts:**
```bash
/tmp/debug_firebase.sh       # Inspect Firebase data
/tmp/verify_quiz_sync.sh     # Check quest/session ID matching
```

---

## Success Criteria

### User Experience
- [x] Daily quests visible in Activity Hub/Inbox ✅
- [x] Completion status accurately reflects both users ✅
- [x] "Your Turn" filter shows incomplete daily quests ✅
- [x] Partner completion updates in real-time ✅
- [x] UI matches mockup designs (no LP, no checkmarks, gray badges) ✅
- [x] Header spacing matches mockups ✅
- [x] Affirmation quizzes display with custom names ✅ (BONUS)
- [x] Both users see identical quest titles and types ✅ (BONUS)

### Technical
- [x] Firebase sync maintains "first creates, second loads" pattern ✅
- [x] All existing tests pass ✅
- [x] Activity feed loads quickly ✅
- [x] Real-time updates appear within seconds ✅
- [ ] No duplicate quiz sessions in activity feed (Phase 5 skipped - optional)

### Design
- [x] No quest progress indicator in inbox header ✅
- [x] All status badges use gray or black backgrounds (no orange) ✅
- [x] No LP amounts displayed on activity cards ✅
- [x] No checkmarks on participant avatars ✅
- [x] Header to tabs spacing = 12px ✅
- [x] Consistent black & white design system ✅
- [x] Title changed to "Inbox" ✅
- [x] Large Playfair Display font for titles ✅
- [x] Border-based cards (no shadows) ✅
- [x] Black uppercase type badges ✅
- [x] Footer layout reversed (badge LEFT, avatars RIGHT) ✅
- [x] Timestamp format: "Today 8:30 AM" style ✅

---

## Detailed Task List

This section provides a comprehensive, step-by-step checklist for implementing the inbox and daily quests integration.

### Pre-Implementation Setup

- [ ] Review all mockup HTML files in `mockups/` folder
- [ ] Read through this entire document
- [ ] Review related docs: `QUEST_SYSTEM.md`, `DAILY_QUESTS_PLAN.md`
- [ ] Set up clean test environment (Android + Chrome)
- [ ] Backup current codebase or create feature branch

### Phase 1: Core Activity Service Integration (2-3 hours)

#### Task 1.1: Add Quest Type Mapping Method
**File:** `lib/services/activity_service.dart`

- [ ] Open `activity_service.dart`
- [ ] Add `_mapQuestTypeToActivityType()` method
- [ ] Map `DailyQuestType.question` → `ActivityType.question`
- [ ] Map `DailyQuestType.quiz` → `ActivityType.quiz`
- [ ] Map `DailyQuestType.wordLadder` → `ActivityType.wordLadder`
- [ ] Map `DailyQuestType.memoryFlip` → `ActivityType.memoryFlip`
- [ ] Map `DailyQuestType.game` → `ActivityType.game`

**Code to add:**
```dart
ActivityType _mapQuestTypeToActivityType(int questType) {
  switch (questType) {
    case DailyQuestType.question:
      return ActivityType.question;
    case DailyQuestType.quiz:
      return ActivityType.quiz;
    case DailyQuestType.wordLadder:
      return ActivityType.wordLadder;
    case DailyQuestType.memoryFlip:
      return ActivityType.memoryFlip;
    case DailyQuestType.game:
    default:
      return ActivityType.game;
  }
}
```

#### Task 1.2: Add Quest Title Generation Method
**File:** `lib/services/activity_service.dart`

- [ ] Add `_getQuestTitle()` method
- [ ] Use same logic as `QuestCard` widget (quest_card.dart:245-275)
- [ ] Handle quiz sort order (0="Getting to Know You", 1="Deeper Connection", 2="Understanding Each Other")
- [ ] Handle question type → "Daily Question"
- [ ] Handle word ladder → "Word Ladder"
- [ ] Handle memory flip → "Memory Flip"
- [ ] Handle default → "Daily Quest"

**Code to add:**
```dart
String _getQuestTitle(DailyQuest quest) {
  switch (quest.questType) {
    case DailyQuestType.quiz:
      if (quest.sortOrder == 0) return 'Getting to Know You';
      if (quest.sortOrder == 1) return 'Deeper Connection';
      if (quest.sortOrder == 2) return 'Understanding Each Other';
      return 'Relationship Quiz';
    case DailyQuestType.question:
      return 'Daily Question';
    case DailyQuestType.wordLadder:
      return 'Word Ladder';
    case DailyQuestType.memoryFlip:
      return 'Memory Flip';
    default:
      return 'Daily Quest';
  }
}
```

#### Task 1.3: Add Quest Subtitle Generation Method
**File:** `lib/services/activity_service.dart`

- [ ] Add `_getQuestSubtitle()` method
- [ ] If both completed → "Both completed"
- [ ] If user completed → "Waiting for partner to complete"
- [ ] If neither completed → "Complete together to earn Love Points"
- [ ] **Do NOT include LP amounts** (e.g., no "30 LP")

**Code to add:**
```dart
String _getQuestSubtitle(DailyQuest quest, bool userCompleted, bool bothCompleted) {
  if (bothCompleted) {
    return 'Both completed';
  } else if (userCompleted) {
    return 'Waiting for partner to complete';
  } else {
    return 'Complete together to earn Love Points';
  }
}
```

#### Task 1.4: Add Quest Participants Method
**File:** `lib/services/activity_service.dart`

- [ ] Add `_getQuestParticipants()` method
- [ ] Only add avatars for users who have completed
- [ ] Check `quest.hasUserCompleted(userId)` for current user
- [ ] Check `quest.hasPartnerCompleted(userId)` for partner
- [ ] Return list of `Participant` objects
- [ ] **No checkmarks on avatars** (handled by UI)

**Code to add:**
```dart
List<Participant> _getQuestParticipants(DailyQuest quest, String userId) {
  final user = _storage.getCurrentUser();
  final partner = _storage.getPartner();

  List<Participant> participants = [];

  if (quest.hasUserCompleted(userId)) {
    participants.add(Participant(
      id: userId,
      name: user?.name ?? 'You',
      avatarUrl: user?.avatarUrl,
    ));
  }

  if (partner != null && quest.hasPartnerCompleted(userId)) {
    participants.add(Participant(
      id: partner.id,
      name: partner.name,
      avatarUrl: partner.avatarUrl,
    ));
  }

  return participants;
}
```

#### Task 1.5: Add Main _getDailyQuests Method
**File:** `lib/services/activity_service.dart`

- [ ] Add `_getDailyQuests()` method
- [ ] Get today's quests via `_storage.getTodayQuests()`
- [ ] Get current user ID via `_storage.getCurrentUserId()`
- [ ] For each quest, determine completion status
- [ ] Map to `ActivityStatus` (yourTurn, waitingForPartner, completed)
- [ ] Create `ActivityItem` with all required fields
- [ ] Set `isUnread` based on user completion and expiration
- [ ] Return list of `ActivityItem`

**Code to add:**
```dart
List<ActivityItem> _getDailyQuests() {
  final quests = _storage.getTodayQuests();
  final userId = _storage.getCurrentUserId();

  return quests.map((quest) {
    final userCompleted = quest.hasUserCompleted(userId);
    final partnerCompleted = quest.hasPartnerCompleted(userId);
    final bothCompleted = quest.isCompleted;

    ActivityStatus status;
    if (bothCompleted) {
      status = ActivityStatus.completed;
    } else if (userCompleted) {
      status = ActivityStatus.waitingForPartner;
    } else {
      status = ActivityStatus.yourTurn;
    }

    return ActivityItem(
      id: quest.id,
      type: _mapQuestTypeToActivityType(quest.questType),
      title: _getQuestTitle(quest),
      subtitle: _getQuestSubtitle(quest, userCompleted, bothCompleted),
      timestamp: quest.createdAt,
      status: status,
      participants: _getQuestParticipants(quest, userId),
      sourceData: quest,
      isUnread: !userCompleted && !quest.isExpired,
    );
  }).toList();
}
```

#### Task 1.6: Update getAllActivities Method
**File:** `lib/services/activity_service.dart`

- [ ] Find `getAllActivities()` method
- [ ] Add `..._getDailyQuests()` to the list
- [ ] Ensure activities are sorted by timestamp descending
- [ ] Test that method compiles

**Code to add:**
```dart
List<ActivityItem> getAllActivities() {
  final activities = [
    ..._getReminders(),
    ..._getPokes(),
    ..._getDailyQuests(),  // ← ADD THIS LINE
    ..._getQuizzes(),
    ..._getWordLadders(),
    ..._getMemoryFlips(),
  ];

  activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

  return activities;
}
```

#### Task 1.7: Add ActivityType Enum Value (If Needed)
**File:** `lib/models/activity_item.dart`

- [ ] Open `activity_item.dart`
- [ ] Check if `ActivityType` enum exists
- [ ] Add `question` value if not present
- [ ] Verify other quest types exist (quiz, wordLadder, memoryFlip, game)

**Code to check/add:**
```dart
enum ActivityType {
  reminder,
  poke,
  question,    // ← ADD IF MISSING
  quiz,
  wordLadder,
  memoryFlip,
  game,
}
```

#### Task 1.8: Test Phase 1
- [ ] Run `flutter run` to check for compilation errors
- [ ] Fix any import errors (add `import 'package:togetherremind/models/daily_quest.dart';` if needed)
- [ ] Navigate to ActivityHub screen
- [ ] Verify daily quests appear in the feed (even if styling is wrong)
- [ ] Check console for errors

### Phase 2: UI Updates (1-2 hours)

#### Task 2.1: Update Header Padding
**File:** `lib/screens/activity_hub_screen.dart`

- [ ] Find the header widget/container
- [ ] Change bottom padding from `16px` to `8px`
- [ ] Verify subtitle still displays correctly

**Expected CSS (for reference):**
```css
.header {
    padding: 20px 20px 8px;  /* Changed last value from 16px */
}
```

#### Task 2.2: Update Filter Tabs Padding
**File:** `lib/screens/activity_hub_screen.dart`

- [ ] Find the filter tabs widget/container
- [ ] Change top padding from `20px` to `12px`
- [ ] Verify tabs display correctly below subtitle

**Expected CSS (for reference):**
```css
.filter-tabs {
    padding: 12px 20px 16px;  /* Changed first value from 20px */
}
```

#### Task 2.3: Remove Quest Progress Indicator
**File:** `lib/screens/activity_hub_screen.dart`

- [ ] Search for any "Daily Quests" progress widgets
- [ ] Search for "2/3 Complete" or percentage displays
- [ ] Remove any quest progress banners/cards from header
- [ ] Verify header only shows title and subtitle

#### Task 2.4: Update Status Badge Styling - Your Turn
**File:** `lib/screens/activity_hub_screen.dart` or theme file

- [ ] Find "Your Turn" badge styling
- [ ] Change background color to gray (#E0E0E0 or equivalent)
- [ ] Change text color to black (#1A1A1A or equivalent)
- [ ] Remove any orange color references (#f59e0b or similar)

**Expected Flutter code:**
```dart
Container(
  decoration: BoxDecoration(
    color: Color(0xFFE0E0E0),  // Gray background
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    'Your Turn',
    style: TextStyle(color: Color(0xFF1A1A1A)),  // Black text
  ),
)
```

#### Task 2.5: Update Status Badge Styling - Waiting
**File:** `lib/screens/activity_hub_screen.dart` or theme file

- [ ] Find "Waiting for partner" badge styling
- [ ] Verify background color is gray (#E0E0E0)
- [ ] Verify text color is black (#1A1A1A)
- [ ] Should match "Your Turn" styling

#### Task 2.6: Update Status Badge Styling - Completed
**File:** `lib/screens/activity_hub_screen.dart` or theme file

- [ ] Find "Completed" badge styling
- [ ] Verify background color is black (#1A1A1A)
- [ ] Verify text color is white (#FFFEFD)
- [ ] Add checkmark icon "✓" if not present

#### Task 2.7: Remove LP Indicators from Activity Cards
**File:** `lib/screens/activity_hub_screen.dart`

- [ ] Search for "💰" emoji in activity cards
- [ ] Search for "+30", "+10", "LP" text displays
- [ ] Remove all LP reward displays from cards
- [ ] Verify subtitles still display correctly

#### Task 2.8: Remove Checkmarks from Avatars
**File:** `lib/screens/activity_hub_screen.dart` or avatar widget

- [ ] Find participant avatar rendering code
- [ ] Remove any checkmark overlays (✓ icons)
- [ ] Remove `.completed-check` class or equivalent
- [ ] Verify avatars display cleanly with just initials

#### Task 2.9: Test Phase 2
- [ ] Run `flutter run`
- [ ] Navigate to ActivityHub
- [ ] Verify header spacing is correct (tabs closer to subtitle)
- [ ] Verify no quest progress card in header
- [ ] Verify status badges are gray for "Your Turn" and "Waiting"
- [ ] Verify status badges are black for "Completed"
- [ ] Verify no LP indicators on cards
- [ ] Verify no checkmarks on avatars
- [ ] Compare visually to HTML mockups

### Phase 3: Filter Logic (1 hour)

#### Task 3.1: Update getFilteredActivities Method
**File:** `lib/services/activity_service.dart`

- [ ] Find `getFilteredActivities()` method (or create if doesn't exist)
- [ ] Add logic for "yourTurn" filter
- [ ] Add logic for "completed" filter
- [ ] Add logic for "all" filter
- [ ] Handle quest expiration in "yourTurn" filter

**Code to add/update:**
```dart
List<ActivityItem> getFilteredActivities(String filter) {
  final allActivities = getAllActivities();

  switch (filter) {
    case 'yourTurn':
      return allActivities.where((activity) {
        // Exclude expired quests from "Your Turn"
        if (activity.sourceData is DailyQuest) {
          final quest = activity.sourceData as DailyQuest;
          if (quest.isExpired) return false;
        }
        return activity.status == ActivityStatus.yourTurn;
      }).toList();

    case 'completed':
      return allActivities
          .where((a) => a.status == ActivityStatus.completed)
          .toList();

    case 'pokes':
      return allActivities
          .where((a) => a.type == ActivityType.poke)
          .toList();

    case 'all':
    default:
      return allActivities;
  }
}
```

#### Task 3.2: Test "Your Turn" Filter
- [ ] Run app
- [ ] Complete 1 daily quest as current user (not partner)
- [ ] Navigate to "Your Turn" filter tab
- [ ] Verify incomplete quests appear
- [ ] Verify quests user completed do NOT appear
- [ ] Verify expired quests do NOT appear

#### Task 3.3: Test "Completed" Filter
- [ ] Run app with both users completing some quests
- [ ] Navigate to "Completed" filter tab
- [ ] Verify only fully completed quests appear
- [ ] Verify partially completed quests do NOT appear

#### Task 3.4: Test "All" Filter
- [ ] Navigate to "All" filter tab
- [ ] Verify all daily quests appear (completed, incomplete, expired)
- [ ] Verify mixed with other activities
- [ ] Verify sorted chronologically

### Phase 4: Real-time Updates (30 minutes)

#### Task 4.1: Add State Refresh on Screen Resume
**File:** `lib/screens/activity_hub_screen.dart`

- [ ] Add `initState()` override if not present
- [ ] Add refresh logic when screen becomes visible
- [ ] Or ensure screen rebuilds when returning from quest completion

**Code pattern:**
```dart
@override
void initState() {
  super.initState();
  _refreshActivities();
}

void _refreshActivities() {
  setState(() {
    // Triggers rebuild, which fetches fresh data from Hive
  });
}
```

#### Task 4.2: Verify Firebase Listener Integration
**File:** `lib/widgets/daily_quests_widget.dart`

- [ ] Verify Firebase listener exists (lines 46-117)
- [ ] Verify it updates local Hive storage when partner completes
- [ ] Verify it calls `setState()` to trigger rebuild
- [ ] No changes needed if existing listener works

#### Task 4.3: Test Real-time Updates
- [ ] Launch two devices (Alice + Bob)
- [ ] Alice completes a daily quest
- [ ] Watch Bob's ActivityHub (don't refresh manually)
- [ ] Verify Bob's feed updates within 2-3 seconds
- [ ] Verify quest status changes from "Your Turn" to "Waiting"
- [ ] Verify Alice's avatar appears on Bob's device

### Phase 5: Quiz Duplication Fix (OPTIONAL - 1-2 hours)

#### Task 5.1: Add Fields to QuizSession Model
**File:** `lib/models/quiz_session.dart`

- [ ] Find next available `HiveField` typeId
- [ ] Add `isDailyQuest` field with `@HiveField` annotation
- [ ] Add `dailyQuestId` field with `@HiveField` annotation
- [ ] Use `defaultValue` for backward compatibility

**Code to add:**
```dart
@HiveField(10, defaultValue: false)
bool isDailyQuest;

@HiveField(11, defaultValue: '')
String dailyQuestId;
```

#### Task 5.2: Run Build Runner
**Terminal:**

- [ ] Run: `flutter pub run build_runner build --delete-conflicting-outputs`
- [ ] Wait for code generation to complete
- [ ] Verify `quiz_session.g.dart` is updated
- [ ] Fix any compilation errors

#### Task 5.3: Update Quiz Creation in DailyQuestsWidget
**File:** `lib/widgets/daily_quests_widget.dart`

- [ ] Find quiz session creation (around line 343)
- [ ] Add `isDailyQuest: true` parameter
- [ ] Add `dailyQuestId: quest.id` parameter

**Code to update:**
```dart
final session = await _quizService.createSession(
  questId: quest.contentId,
  isDailyQuest: true,        // ← ADD THIS
  dailyQuestId: quest.id,    // ← ADD THIS
);
```

#### Task 5.4: Update QuizService.createSession Method
**File:** `lib/services/quiz_service.dart`

- [ ] Find `createSession()` method
- [ ] Add `isDailyQuest` parameter (default: false)
- [ ] Add `dailyQuestId` parameter (default: '')
- [ ] Pass parameters to `QuizSession` constructor

#### Task 5.5: Filter Daily Quest Quizzes in ActivityService
**File:** `lib/services/activity_service.dart`

- [ ] Find `_getQuizzes()` method
- [ ] Add filter: `.where((session) => !session.isDailyQuest)`
- [ ] Verify quiz sessions created from daily quests don't appear

**Code to update:**
```dart
List<ActivityItem> _getQuizzes() {
  final sessions = _storage.getAllQuizSessions();

  return sessions
    .where((session) => !session.isDailyQuest)  // ← ADD THIS
    .map((session) => _mapQuizToActivity(session))
    .toList();
}
```

#### Task 5.6: Test Quiz Duplication Fix
- [ ] Run app
- [ ] Complete a quiz-type daily quest
- [ ] Navigate to ActivityHub
- [ ] Verify quiz appears only once (as daily quest)
- [ ] Verify no separate quiz session card
- [ ] Verify tapping quest opens correct quiz session

### Phase 6: Comprehensive Testing (2 hours)

#### Test Suite 1: Daily Quests Appear in Inbox
- [ ] Setup: Clean test environment (clear Firebase + Hive)
- [ ] Launch Alice (Android) - generates 3 daily quests
- [ ] Launch Bob (Chrome) - loads quests from Firebase
- [ ] Open ActivityHub on both devices
- [ ] **Expected:** 3 daily quests appear in "All" tab
- [ ] **Expected:** Type badges show correct types (QUIZ, QUESTION)
- [ ] **Expected:** Titles match home screen display
- [ ] **Expected:** All show "Your Turn" badge (gray)

#### Test Suite 2: Completion Flow
- [ ] Alice completes daily quest #1 (quiz)
- [ ] **Expected (Alice):** Status = "Waiting for partner", [A] avatar shows
- [ ] **Expected (Bob):** Status = "Your Turn", no avatars
- [ ] Bob completes same quest
- [ ] **Expected (Both):** Status = "✓ Completed" (black badge)
- [ ] **Expected (Both):** [A][B] avatars show
- [ ] **Expected (Both):** Subtitle = "Both completed"

#### Test Suite 3: Filter Tabs
- [ ] Setup: Mixed states (1 completed, 1 user-only, 1 incomplete)
- [ ] Navigate to "Your Turn" tab
- [ ] **Expected:** Only incomplete quests show
- [ ] **Expected:** User-completed quests do NOT show
- [ ] Navigate to "Completed" tab
- [ ] **Expected:** Only fully completed quests show
- [ ] **Expected:** Partially completed do NOT show
- [ ] Navigate to "All" tab
- [ ] **Expected:** All quests show, mixed with other activities

#### Test Suite 4: Real-time Updates
- [ ] Bob stays on ActivityHub "All" tab
- [ ] Alice completes a daily quest (don't tell Bob)
- [ ] Wait 2-3 seconds, watch Bob's screen
- [ ] **Expected:** Bob's feed updates automatically
- [ ] **Expected:** Quest shows [A] avatar
- [ ] **Expected:** Status changes to "Waiting for partner"
- [ ] **Expected:** No manual refresh needed

#### Test Suite 5: Expiration Handling
- [ ] Setup: Wait until 23:59:59 or manually expire quest
- [ ] Navigate to "Your Turn" tab
- [ ] **Expected:** Expired quests do NOT appear
- [ ] Navigate to "All" tab
- [ ] **Expected:** Expired quests still appear
- [ ] **Expected:** Cannot tap to complete expired quests

#### Test Suite 6: UI Design Validation
- [ ] Open ActivityHub
- [ ] **Expected:** No quest progress card in header
- [ ] **Expected:** Header to tabs spacing ~12px (visually close)
- [ ] **Expected:** "Your Turn" badge = gray background
- [ ] **Expected:** "Waiting" badge = gray background
- [ ] **Expected:** "Completed" badge = black background
- [ ] **Expected:** No "💰 +30" or LP indicators
- [ ] **Expected:** No checkmarks on avatars
- [ ] **Expected:** Subtitles say "Complete together to earn Love Points" (generic)
- [ ] Compare to HTML mockups - should match closely

#### Test Suite 7: Quiz Integration (If Phase 5 Complete)
- [ ] Complete a quiz-type daily quest
- [ ] Navigate to ActivityHub
- [ ] **Expected:** Quiz appears once (as daily quest)
- [ ] **Expected:** No separate quiz session card
- [ ] Tap quest card
- [ ] **Expected:** Opens correct quiz session
- [ ] Complete quiz
- [ ] **Expected:** Quest marked complete in ActivityHub

### Post-Implementation Tasks

#### Code Quality
- [ ] Run `flutter analyze` - fix all warnings/errors
- [ ] Run `flutter test` - ensure all tests pass
- [ ] Add comments to new methods
- [ ] Remove any debug print statements
- [ ] Check for TODO comments - resolve or track

#### Documentation
- [ ] Update this document with any implementation changes
- [ ] Mark tasks as complete in this checklist
- [ ] Note any deviations from plan
- [ ] Document any new issues discovered

#### Performance Testing
- [ ] Test with 50+ activities in feed - verify performance
- [ ] Check memory usage - no leaks
- [ ] Verify Firebase listener is properly disposed
- [ ] Test on slow network - loading states work

#### Deployment Preparation
- [ ] Create feature branch: `feature/inbox-daily-quests-integration`
- [ ] Commit changes with descriptive messages
- [ ] Create pull request with link to this document
- [ ] Request code review
- [ ] Test on physical iOS device (if available)
- [ ] Test on different screen sizes

---

## Implementation Notes

### Files Modified

**Models:**
- `lib/models/activity_item.dart`
  - Added `ActivityType.affirmation` enum value
  - Added corresponding label ("Affirmation") and emoji (💗)

**Services:**
- `lib/services/activity_service.dart`
  - Added `_getDailyQuests()` method (~45 lines)
  - Added `_mapQuestTypeToActivityType()` with affirmation detection
  - Added `_getQuestTitle()` with quiz session lookup for affirmation names
  - Added `_getQuestSubtitle()` for clean status messages
  - Added `_getQuestParticipants()` for avatar display
  - Added `_hasPartnerCompleted()` helper method
  - Updated `getAllActivities()` to include daily quests
  - Updated `getFilteredActivities()` to handle quest expiration and pokes filter

**UI Screens:**
- `lib/screens/activity_hub_screen.dart`
  - Complete redesign of header (title, subtitle, spacing)
  - Complete redesign of filter tabs (border-based, added Pokes)
  - Complete redesign of `_ActivityCard` widget:
    - Removed emoji icon boxes
    - Added black type badges at top
    - Large Playfair Display titles
    - Reversed footer layout
    - Border-based card styling
    - New timestamp formatting
  - Added `_getHeaderSubtitle()` method
  - Updated navigation handling for affirmation quizzes
  - Added navigation for question activities

### Key Implementation Details

1. **Affirmation Quiz Detection:**
   - Service queries quiz session by `contentId` to check `formatType`
   - If `formatType == 'affirmation'`, uses custom `quizName` from session
   - Maps to `ActivityType.affirmation` instead of `ActivityType.quiz`

2. **Title Generation:**
   - Checks quiz session first for affirmation quiz custom name
   - Falls back to sortOrder-based titles for classic quizzes:
     - sortOrder 0: "Getting to Know You"
     - sortOrder 1: "Deeper Connection"
     - sortOrder 2: "Understanding Each Other"

3. **Card Design:**
   - Matches mockups exactly (border-based, no shadows)
   - Black uppercase type badges with white text
   - Playfair Display serif font for titles (18px, bold)
   - Status badge on left, avatars on right (reversed from original)
   - Timestamp: "Today 8:30 AM" / "Yesterday" / "3 days ago" / "MMM d"

4. **Filter Behavior:**
   - "Your Turn": Excludes expired quests (quest.isExpired check)
   - "Completed": Shows only fully completed activities
   - "Pokes": Shows only poke activities
   - "All": Shows everything

### Testing Performed

- ✅ Clean environment testing (Android + Chrome)
- ✅ Quest sync verification (Alice generates, Bob loads)
- ✅ Affirmation quiz display on both devices
- ✅ Filter tab functionality
- ✅ Real-time updates when partner completes quest
- ✅ UI matches mockups exactly

### Known Issues

None identified during implementation and testing.

---

## Future Enhancements

### Phase 7: Enhanced Completion Summary (Post-MVP)

Add summary banner at top of "Completed" tab:
- "Completed Today: 4 Activities"
- Visual progress indicator
- Optional: Total LP earned today

### Phase 8: Quest History (Post-MVP)

Archive completed daily quests beyond 30 days:
- "Past Quests" tab in activity hub
- View completion history by week/month
- See which quests were completed together

### Phase 9: Push Notifications (Post-MVP)

Notify when partner completes quest:
- "Bob completed Getting to Know You"
- Deep link to activity hub
- Encourages completion before expiration

### Phase 10: Quest Suggestions (Post-MVP)

Intelligent quest recommendations:
- Based on incomplete quests
- Time of day reminders
- Partner online status

---

## Appendix

### Related Documentation

- [QUEST_SYSTEM.md](./QUEST_SYSTEM.md) - Quest system architecture and 30-day data retention
- [DAILY_QUESTS_PLAN.md](./DAILY_QUESTS_PLAN.md) - Original daily quests design and specifications
- [ARCHITECTURE.md](./ARCHITECTURE.md) - Overall app architecture and data models
- [QUIZ_SYNC_SYSTEM.md](./QUIZ_SYNC_SYSTEM.md) - Quiz synchronization architecture

**Note:** `INBOX_ACTIVITY_FEED_INTEGRATION.md` contains outdated designs (shows LP indicators, orange badges, checkmarks) and should not be referenced. This document supersedes it.

### Key Code References

**Quest System:**
- `lib/models/daily_quest.dart:14-107` - DailyQuest model
- `lib/services/daily_quest_service.dart:75-152` - Completion logic
- `lib/services/quest_sync_service.dart:32-107` - Firebase sync
- `lib/widgets/daily_quests_widget.dart:46-117` - Real-time listener
- `lib/widgets/quest_card.dart:245-275` - Dynamic titles

**Activity System:**
- `lib/services/activity_service.dart` - Activity aggregation
- `lib/models/activity_item.dart` - Activity data model
- `lib/screens/activity_hub_screen.dart` - Inbox UI

---

**Document Version:** 1.0
**Last Updated:** 2025-11-14
**Status:** Ready for Implementation

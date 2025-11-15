# Inbox & Activity Feed Integration Plan

**Date:** 2025-11-14
**Status:** Analysis Complete - Ready for Implementation

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current State Analysis](#current-state-analysis)
3. [Architecture Issues](#architecture-issues)
4. [Design Intent](#design-intent)
5. [Implementation Plan](#implementation-plan)
6. [Testing Strategy](#testing-strategy)

---

## Executive Summary

### Problem
Daily quests are currently isolated to the home screen and do not appear in the Activity Hub/Inbox, preventing users from monitoring completion status in a unified activity feed.

### Solution
Integrate daily quests into the `ActivityService` and display them in the Activity Hub alongside other activities (reminders, pokes, games), while maintaining the home screen widget as the primary dashboard view.

### Impact
- **User Experience**: Single location to monitor all activities and completion status
- **Consistency**: All activities use the same status tracking and filtering
- **Visibility**: Users can see partner progress on daily quests in real-time

---

## Current State Analysis

### Inbox Screen (`lib/screens/inbox_screen.dart`)

**Current Functionality:**
- Shows only Reminders and Pokes
- 4-tab filter system: All, Received, Sent, Pokes
- User interactions: Snooze, Mark Done (awards 10 LP)
- Status indicators: Color-coded cards, mutual poke detection
- **NOT in main navigation** - appears to be legacy code

**File Location:** `lib/screens/inbox_screen.dart`

### Activity Hub Screen (`lib/screens/activity_hub_screen.dart`)

**Current Functionality:**
- Main "Inbox" tab in bottom navigation (index 1)
- Aggregates: Reminders, Pokes, Quizzes, Word Ladders, Memory Flip
- Filter system: Your Turn, Unread, Completed, All
- **Does NOT include Daily Quests** ⚠️

**File Location:** `lib/screens/activity_hub_screen.dart`

### Daily Quests System

**Architecture:**
```
Model:         lib/models/daily_quest.dart
Service:       lib/services/daily_quest_service.dart
Sync:          lib/services/quest_sync_service.dart
Widget:        lib/widgets/daily_quests_widget.dart
Card:          lib/widgets/quest_card.dart
```

**How It Works:**
1. **Generation**: First device creates 3 daily quests at midnight
2. **Firebase Sync**: Second device loads from `/daily_quests/{coupleId}/{dateKey}`
3. **Completion Tracking**:
   - Each user completes independently
   - Tracked per user in `userCompletions` map
   - When BOTH complete: 30 LP awarded to each user
4. **Real-time Updates**: Firebase listener updates UI when partner completes
5. **Expiration**: All quests expire at 23:59:59

**Quest Types:**
- `question` - Daily discussion prompts
- `quiz` - Relationship quiz (3 rounds)
- `wordLadder` - Word transformation puzzle
- `memoryFlip` - Card matching game
- `game` - Generic game type

**Current Display Location:**
- **Primary**: Home screen via `DailyQuestsWidget` (lines 489-490 in `new_home_screen.dart`)
- **Not in Activity Hub** ⚠️

---

## Architecture Issues

### Issue 1: Daily Quests Missing from Activity Feed

**Current State:**
```
Home Screen (index 0)
├── DailyQuestsWidget ← Only place to see daily quests
└── Other content

"Inbox" Tab (index 1) → ActivityHubScreen
├── Reminders ✅
├── Pokes ✅
├── Quizzes ✅ (ALL quizzes, including ones from daily quests)
├── Word Ladders ✅ (standalone only)
├── Memory Flip ✅ (standalone only)
└── Daily Quests ❌ MISSING
```

**Impact:**
- Users cannot monitor daily quest completion status in unified feed
- "Your Turn" filter doesn't include daily quests awaiting user action
- No single source of truth for "what needs my attention today"

**Code Evidence:**
```dart
// activity_service.dart - getAllActivities()
// Missing: _getDailyQuests() method
final activities = [
  ..._getReminders(),
  ..._getPokes(),
  ..._getQuizzes(),      // Gets ALL quiz sessions
  ..._getWordLadders(),
  ..._getMemoryFlips(),
  // MISSING: ..._getDailyQuests(),
];
```

### Issue 2: Quiz Duplication Risk

**Problem:**
When a daily quest is a quiz:
1. User sees quest card on home screen: "Getting to Know You"
2. User taps → Creates quiz session stored in Hive
3. Quiz session ALSO appears in ActivityHub as standalone quiz
4. No visual indication that the quiz session belongs to a daily quest

**Code Evidence:**
```dart
// activity_service.dart:202
final sessions = _storage.getAllQuizSessions();
// ^^ Includes quiz sessions created by daily quests
```

**Current Behavior:**
- Daily quest quiz appears twice (home screen + activity hub)
- No way to distinguish daily quest quizzes from standalone quizzes

### Issue 3: Inconsistent Completion Models

| Feature | Status Model | LP Reward | Completion Tracking |
|---------|-------------|-----------|---------------------|
| **Reminders** | pending → done/snoozed | 10 LP to completer | Single user |
| **Daily Quests** | pending → in_progress → completed | 30 LP to BOTH users | Both users in `userCompletions` map |
| **Quizzes** | Based on answer presence | Via QuizService | Per-question answers |

**Impact:**
- Three different mental models for "completion"
- Inconsistent status tracking patterns
- Difficult to create unified activity feed

---

## Design Intent

Based on user clarification:

### Home Screen = Quick Dashboard
- Daily quests widget (stays in current location)
- Side quests
- Love Points & Streak counter
- At-a-glance view of "what's available today"

### Inbox/Activity Hub = Detailed Monitoring
- Everything completed (by you or partner)
- Everything in progress
- Everything waiting for partner
- **Should include**: Daily quests, Side quests, Reminders, Pokes, Games
- Filtering: "Your Turn", "Completed", "All", etc.

### Key Principle
> "The inbox is meant to monitor everything that you've completed with your partner or that your partner has only completed or that you have completed what you're waiting for your partner to complete. It's the same for all the side quests and for the daily quests. They should all be listed in the inbox."

---

## Implementation Plan

### Phase 1: Add Daily Quests to Activity Service

**File:** `lib/services/activity_service.dart`

#### Step 1.1: Add `_getDailyQuests()` Method

```dart
List<ActivityItem> _getDailyQuests() {
  final quests = _storage.getTodayQuests(); // Get today's daily quests
  final userId = _storage.getCurrentUserId();

  return quests.map((quest) {
    final userCompleted = quest.hasUserCompleted(userId);
    final partnerCompleted = quest.hasPartnerCompleted(userId);
    final bothCompleted = quest.isCompleted;

    // Determine status
    ActivityStatus status;
    if (bothCompleted) {
      status = ActivityStatus.completed;
    } else if (userCompleted && !partnerCompleted) {
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
      lpReward: bothCompleted ? null : 30, // Show LP if not yet earned
    );
  }).toList();
}

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

String _getQuestTitle(DailyQuest quest) {
  // Use same logic as QuestCard widget (quest_card.dart:245-275)
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

String _getQuestSubtitle(DailyQuest quest, bool userCompleted, bool bothCompleted) {
  if (bothCompleted) {
    return 'Both completed • 30 LP earned';
  } else if (userCompleted) {
    return 'Waiting for partner • 30 LP when complete';
  } else {
    return 'Complete to earn 30 LP';
  }
}

List<Participant> _getQuestParticipants(DailyQuest quest, String userId) {
  final user = _storage.getCurrentUser();
  final partner = _storage.getPartner();

  return [
    Participant(
      id: userId,
      name: user?.name ?? 'You',
      avatarUrl: user?.avatarUrl,
      hasCompleted: quest.hasUserCompleted(userId),
    ),
    if (partner != null)
      Participant(
        id: partner.id,
        name: partner.name,
        avatarUrl: partner.avatarUrl,
        hasCompleted: quest.hasPartnerCompleted(userId),
      ),
  ];
}
```

#### Step 1.2: Update `getAllActivities()` Method

```dart
List<ActivityItem> getAllActivities() {
  final activities = [
    ..._getReminders(),
    ..._getPokes(),
    ..._getDailyQuests(),  // ← ADD THIS
    ..._getQuizzes(),
    ..._getWordLadders(),
    ..._getMemoryFlips(),
  ];

  // Sort by timestamp descending (newest first)
  activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

  return activities;
}
```

#### Step 1.3: Add Daily Quest Type (if needed)

**File:** `lib/models/activity_item.dart`

```dart
enum ActivityType {
  reminder,
  poke,
  dailyQuest,  // ← ADD IF NOT EXISTS
  question,    // ← ADD IF NOT EXISTS
  quiz,
  wordLadder,
  memoryFlip,
  game,
}
```

### Phase 2: Handle Quiz Duplication (Optional Enhancement)

**File:** `lib/models/quiz_session.dart`

#### Add `isDailyQuest` Flag

```dart
@HiveType(typeId: X)  // Use next available typeId
class QuizSession {
  // ... existing fields ...

  @HiveField(10, defaultValue: false)
  bool isDailyQuest;  // ← ADD THIS

  @HiveField(11, defaultValue: '')
  String dailyQuestId;  // ← ADD THIS (optional, for linking)
}
```

#### Update Quiz Creation in DailyQuestsWidget

**File:** `lib/widgets/daily_quests_widget.dart`

```dart
// Around line 343
final session = await _quizService.createSession(
  questId: quest.contentId,
  isDailyQuest: true,        // ← ADD THIS
  dailyQuestId: quest.id,    // ← ADD THIS
);
```

#### Filter Daily Quest Quizzes from Activity Feed

**File:** `lib/services/activity_service.dart`

```dart
List<ActivityItem> _getQuizzes() {
  final sessions = _storage.getAllQuizSessions();

  return sessions
    .where((session) => !session.isDailyQuest)  // ← ADD THIS FILTER
    .map((session) {
      // ... existing mapping logic ...
    })
    .toList();
}
```

### Phase 3: Update ActivityHub UI (Optional Enhancements)

**File:** `lib/screens/activity_hub_screen.dart`

#### Add Daily Quest Progress Indicator

```dart
Widget _buildHeader() {
  return Column(
    children: [
      _buildDailyQuestProgress(),  // ← ADD THIS
      _buildFilterTabs(),
    ],
  );
}

Widget _buildDailyQuestProgress() {
  final completionPercentage = _dailyQuestService.getTodayCompletionPercentage();
  final completed = _dailyQuestService.getCompletedQuestsCount();
  final total = _dailyQuestService.getTotalQuestsCount();

  if (total == 0) return SizedBox.shrink();

  return Container(
    padding: EdgeInsets.all(16),
    child: Row(
      children: [
        Text('Daily Quests: $completed/$total Complete'),
        Spacer(),
        CircularProgressIndicator(
          value: completionPercentage / 100,
          backgroundColor: Colors.grey[300],
        ),
      ],
    ),
  );
}
```

### Phase 4: Real-time Updates

**File:** `lib/services/activity_service.dart`

#### Add Firebase Listener for Daily Quest Updates

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
      // OR: _activityStreamController.add(getAllActivities());
    });
  }

  void dispose() {
    _questCompletionListener?.cancel();
  }
}
```

### Phase 5: Testing Requirements

**File Location:** Create `test/integration/inbox_daily_quests_test.dart`

#### Test Cases

1. **Daily Quests Appear in Activity Feed**
   - Generate 3 daily quests
   - Check `getAllActivities()` includes all 3 quests
   - Verify quest type, title, subtitle are correct

2. **Completion Status Tracking**
   - User completes quest → Status = "Waiting for Partner"
   - Partner completes quest → Status = "Completed"
   - Both completed → Shows "30 LP earned"

3. **Filter Tabs Work Correctly**
   - "Your Turn" shows incomplete daily quests
   - "Completed" shows only fully completed quests
   - "All" shows all daily quests regardless of status

4. **Real-time Partner Updates**
   - Launch two devices (Alice + Bob)
   - Alice completes quest
   - Bob's activity feed updates automatically
   - Verify status changes from "Your Turn" to "Waiting for Partner"

5. **Quiz Duplication Prevention** (if Phase 2 implemented)
   - Complete quiz-type daily quest
   - Check activity feed only shows quest once
   - Verify quiz session has `isDailyQuest = true`

6. **Expiration Handling**
   - Daily quests expire at 23:59:59
   - Expired quests show "Expired" status
   - Do not appear in "Your Turn" filter

---

## Testing Strategy

### Manual Testing Procedure

#### Setup
```bash
# 1. Clear Firebase RTDB
firebase database:remove /daily_quests --force

# 2. Uninstall Android app (clears Hive)
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind2

# 3. Launch Alice (Android)
flutter run -d emulator-5554 &

# 4. Wait 10 seconds, then launch Bob (Chrome)
sleep 10 && flutter run -d chrome &
```

#### Test Scenarios

**Scenario 1: Daily Quests Appear in Inbox**
1. Open ActivityHub on both devices
2. ✅ Verify 3 daily quests appear in "All" tab
3. ✅ Verify quests show in "Your Turn" tab (since incomplete)
4. ✅ Verify quest titles, types, and LP indicators are correct

**Scenario 2: Completion Flow**
1. Alice taps daily quest #1 (question type)
2. Alice completes question
3. On Alice's device: ✅ Quest status = "Waiting for Partner"
4. On Bob's device: ✅ Quest still shows "Your Turn"
5. Bob completes same quest
6. On both devices: ✅ Quest status = "Completed • 30 LP earned"
7. ✅ Both users receive 30 LP

**Scenario 3: Filter Tabs**
1. With mixed completion states (1 done, 1 waiting, 1 pending):
2. ✅ "Your Turn" shows only incomplete quests
3. ✅ "Completed" shows only fully completed quests
4. ✅ "All" shows all quests

**Scenario 4: Real-time Updates**
1. Bob leaves ActivityHub open
2. Alice completes a quest
3. ✅ Bob's screen updates automatically (no refresh needed)
4. ✅ Quest moves from "Your Turn" to "Completed"

**Scenario 5: Quiz Integration**
1. Complete quiz-type daily quest
2. ✅ Quiz appears in activity feed
3. ✅ Shows completion status
4. If Phase 2 implemented: ✅ Quiz not duplicated

### Debug Tools

**In-App Debug Menu:**
- Double-tap greeting text to access
- View Firebase RTDB data
- View local Hive storage
- Compare quest IDs for sync issues

**External Scripts:**
```bash
/tmp/debug_firebase.sh       # Inspect Firebase data
/tmp/verify_quiz_sync.sh     # Check quest/session matching
```

---

## File Change Summary

### New Files
- `docs/INBOX_ACTIVITY_FEED_INTEGRATION.md` (this document)
- `test/integration/inbox_daily_quests_test.dart` (testing)

### Files to Modify

| File | Changes | Priority |
|------|---------|----------|
| `lib/services/activity_service.dart` | Add `_getDailyQuests()` method, update `getAllActivities()` | **HIGH** |
| `lib/models/activity_item.dart` | Add `ActivityType.dailyQuest` enum (if needed) | **HIGH** |
| `lib/models/quiz_session.dart` | Add `isDailyQuest` and `dailyQuestId` fields | **MEDIUM** |
| `lib/widgets/daily_quests_widget.dart` | Pass `isDailyQuest: true` to quiz creation | **MEDIUM** |
| `lib/screens/activity_hub_screen.dart` | Add daily quest progress indicator (optional) | **LOW** |

### Estimated Effort

| Phase | Effort | Priority |
|-------|--------|----------|
| Phase 1: Add to Activity Service | 2-3 hours | **HIGH** |
| Phase 2: Quiz Duplication Fix | 1-2 hours | **MEDIUM** |
| Phase 3: UI Enhancements | 1 hour | **LOW** |
| Phase 4: Real-time Updates | 30 min | **MEDIUM** |
| Phase 5: Testing | 2 hours | **HIGH** |

**Total Estimated Time:** 6-8 hours

---

## Risks & Mitigations

### Risk 1: Performance Impact
**Concern:** Adding daily quests to activity feed increases query complexity

**Mitigation:**
- Daily quests are cached in Hive (fast local access)
- Only 3 main quests per day (minimal data)
- Already have Firebase listener for real-time updates

### Risk 2: Status Tracking Complexity
**Concern:** Daily quests have different completion model (both users required)

**Mitigation:**
- ActivityItem model already supports `participants` with completion status
- Use existing `ActivityStatus.waitingForPartner` state
- Leverage existing `quest.userCompletions` map

### Risk 3: Quiz Session Duplication
**Concern:** Quiz-type daily quests may appear twice in feed

**Mitigation:**
- Phase 2 addresses this with `isDailyQuest` flag
- Filter out daily quest quizzes from `_getQuizzes()`
- Graceful degradation: Even without fix, quizzes work correctly

---

## Success Criteria

### User Experience
- [ ] Daily quests visible in Activity Hub/Inbox
- [ ] Completion status accurately reflects both users
- [ ] "Your Turn" filter shows incomplete daily quests
- [ ] Partner completion updates in real-time
- [ ] LP indicators show before and after completion

### Technical
- [ ] No duplicate quiz sessions in activity feed
- [ ] Firebase sync maintains "first creates, second loads" pattern
- [ ] Hive migrations handle new fields gracefully
- [ ] All existing tests pass
- [ ] New integration tests pass

### Performance
- [ ] Activity feed loads in <500ms
- [ ] Real-time updates appear within 2 seconds
- [ ] No memory leaks from Firebase listeners

---

## Future Enhancements

### Phase 6: Activity Hub as Primary View (Post-MVP)
- Move daily quests widget from home screen to activity hub header
- Keep home screen focused on LP, streak, and partner connection
- Make activity hub the "to-do list" central location

### Phase 7: Quest History
- Archive completed daily quests beyond 30 days
- "Past Quests" tab in activity hub
- View completion history and earned LP

### Phase 8: Notifications
- Push notification when partner completes daily quest
- "Bob completed Getting to Know You • 30 LP awarded"
- Deep link to activity hub to see details

---

## References

### Related Documentation
- [docs/QUEST_SYSTEM.md](./QUEST_SYSTEM.md) - Quest architecture overview
- [docs/DAILY_QUESTS_PLAN.md](./DAILY_QUESTS_PLAN.md) - Original daily quests design
- [docs/ARCHITECTURE.md](./ARCHITECTURE.md) - Overall app architecture

### Key Code Files
- `lib/services/activity_service.dart` - Activity aggregation logic
- `lib/services/daily_quest_service.dart` - Daily quest business logic
- `lib/services/quest_sync_service.dart` - Firebase synchronization
- `lib/models/daily_quest.dart` - Data models
- `lib/widgets/daily_quests_widget.dart` - Home screen display
- `lib/screens/activity_hub_screen.dart` - Activity feed UI

---

**Document Version:** 1.0
**Last Updated:** 2025-11-14
**Author:** Claude Code Analysis
**Status:** Ready for Review & Implementation

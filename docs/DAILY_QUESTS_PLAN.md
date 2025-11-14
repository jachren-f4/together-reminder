# Daily Quests System - Implementation Plan

**Version:** 1.0
**Last Updated:** 2025-11-13

---

## Overview

A gamified daily engagement system that encourages users to complete 3 interactive activities per day with their partner. Each quest rewards 30 Love Points and creates opportunities for partner interaction.

---

## Goals

1. **Daily Engagement**: Encourage users to interact with the app daily
2. **Partner Interaction**: All quests must create opportunities for partner responses
3. **Completion Tracking**: Visual progress toward daily goal (3/3 quests)
4. **Reward System**: Higher LP rewards (30 LP) for meaningful engagement vs. quick interactions (5 LP for pokes/reminders)
5. **Optional Content**: Side quests available for users who want to do more

---

## User Experience Flow

### 1. Daily Quest Structure

**Home Screen Layout:**
```
┌─────────────────────────────────────┐
│ Home                        🔥 2    │
│                                     │
│ [Quick Actions: Poke, Reminder]     │
│                                     │
│ Daily Quests                        │
│ ✓ Question: Who's funnier?    [J✓] │
│ ✓ Quiz: Embracing Commitment  [J✓] │
│ ✓ Game: Cute or Corny?        [J✓] │
│                                     │
│ ✅ Way to go! Completed Daily Quests│
│                                     │
│ Side Quests (Optional)              │
│ □ Word Ladder Challenge             │
│ □ Memory Flip Puzzle                │
│ □ Speed Round Quiz                  │
└─────────────────────────────────────┘
```

### 2. Quest States

- **Not Started**: Empty card with "Your Turn" indicator
- **In Progress**: Partial completion (user answered, waiting for partner)
- **Completed**: Both users completed, shows checkmark + avatars
- **All Done**: Completion banner appears when 3/3 quests finished

---

## Data Models

### DailyQuest Model

```dart
@HiveType(typeId: 17)
class DailyQuest extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String dateKey; // YYYY-MM-DD format

  @HiveField(2)
  late QuestType type; // question, quiz, game

  @HiveField(3)
  late String contentId; // Reference to actual content (quiz session, question, etc.)

  @HiveField(4)
  late DateTime createdAt;

  @HiveField(5)
  late DateTime expiresAt; // End of day (23:59:59)

  @HiveField(6)
  late String status; // 'pending', 'in_progress', 'completed'

  @HiveField(7)
  Map<String, bool>? userCompletions; // userId -> completed bool

  @HiveField(8)
  int? lpAwarded; // 30 LP when both complete

  @HiveField(9)
  DateTime? completedAt;

  @HiveField(10, defaultValue: false)
  bool isSideQuest; // true for optional quests beyond the 3 daily

  @HiveField(11, defaultValue: 0)
  int sortOrder; // 0-2 for daily quests, 3+ for side quests
}

enum QuestType {
  question,      // Daily question prompts
  quiz,          // Relationship quizzes
  game,          // Interactive games (Would You Rather, etc.)
  wordLadder,    // Word ladder challenges
  memoryFlip,    // Memory card game
}
```

### DailyQuestCompletion Model

```dart
@HiveType(typeId: 18)
class DailyQuestCompletion extends HiveObject {
  @HiveField(0)
  late String dateKey; // YYYY-MM-DD

  @HiveField(1)
  late int questsCompleted; // 0-3 for daily quests

  @HiveField(2)
  late bool allQuestsCompleted; // true when 3/3 done

  @HiveField(3)
  late DateTime completedAt;

  @HiveField(4)
  late int totalLpEarned; // 90 LP for 3 quests

  @HiveField(5, defaultValue: 0)
  int sideQuestsCompleted; // Bonus quests beyond the 3

  @HiveField(6)
  DateTime? lastUpdatedAt;
}
```

---

## Service Layer

### DailyQuestService

**Key Methods:**

```dart
class DailyQuestService {
  // Quest Generation
  Future<void> generateDailyQuests(String dateKey);

  // Quest Selection
  List<DailyQuest> getTodaysQuests();
  List<DailyQuest> getSideQuests();

  // Completion Tracking
  Future<void> markQuestCompleted(String questId, String userId);
  bool hasUserCompleted(DailyQuest quest, String userId);
  bool areBothUsersCompleted(DailyQuest quest);

  // Progress
  int getCompletedQuestCount(String dateKey);
  bool areAllQuestsCompleted(String dateKey);

  // Rewards
  Future<void> awardQuestReward(String questId); // 30 LP when both complete

  // Side Quests
  Future<void> addSideQuest(QuestType type, String contentId);
}
```

### Quest Generation Logic

**Daily Quest Selection (runs at midnight local time):**

**Version 1.0 - Quizzes Only (No Games)**

All 3 daily quests use **quiz-based content** with intelligent branching:

1. **Quest Slot 1** - Classic Quiz
2. **Quest Slot 2** - Speed Round or Would You Rather
3. **Quest Slot 3** - Deep Dive or Daily Pulse

**Key Principles:**
- ✅ **No games** in daily quests (v1)
- ✅ **Branching progression** through quiz content
- ✅ **Flexible architecture** for future quest types
- ✅ **Reuse existing quiz system**

**Side Quest Population:**
- Word Ladder (always available)
- Memory Flip (always available)
- Bonus quizzes (optional)
- Future: Additional game modes

---

## Branching Quiz System

### Overview

Users progress through quizzes in a **sequential, branching path** rather than random selection. This creates a sense of progression and story.

**IMPORTANT:** This system **reuses the existing QuizService and question bank** (`assets/data/quiz_questions.json`). We do NOT create new quiz questions. Instead, we use the existing infrastructure with category/tier filtering to create progression.

### Quiz Progression Tracks

**Track Structure (uses existing quiz categories/tiers):**
```
Track 0: Relationship Foundation (tier 1, category filters)
├─ Quiz 0: Getting to Know You (category: "favorites", tier: 1)
├─ Quiz 1: Love Languages (category: "values", tier: 1-2)
├─ Quiz 2: Daily Rhythms (category: "personality", tier: 1)
└─ Quiz 3: Values & Priorities (category: "values", tier: 2)

Track 1: Communication & Conflict (tier 2-3, category filters)
├─ Quiz 0: Communication Styles (category: "communication", tier: 2)
├─ Quiz 1: Conflict Resolution (category: "conflict", tier: 2-3)
├─ Quiz 2: Emotional Expression (category: "emotions", tier: 2)
└─ Quiz 3: Support & Encouragement (category: "support", tier: 2-3)

Track 2: Future & Growth (tier 3-4, category filters)
├─ Quiz 0: Relationship Goals (category: "future", tier: 3)
├─ Quiz 1: Life Planning (category: "goals", tier: 3)
├─ Quiz 2: Growth & Change (category: "growth", tier: 3-4)
└─ Quiz 3: Embracing Commitment (category: "commitment", tier: 4)
```

**Implementation Note:** Each "quiz" in the track is actually a call to `QuizService.startQuizSession()` with specific category/tier filters to pull relevant questions from the existing question bank.

### Progression Logic

**User Progression State:**
```dart
@HiveType(typeId: 19)
class QuizProgressionState extends HiveObject {
  @HiveField(0)
  late String userId;

  @HiveField(1)
  late Map<String, int> trackProgress; // trackId -> quiz index (0-3)

  @HiveField(2)
  late String currentTrackId;

  @HiveField(3)
  late DateTime lastUpdated;

  @HiveField(4, defaultValue: 0)
  late int totalQuizzesCompleted;
}
```

**Progression Rules:**
1. User starts at Track 1, Quiz 0
2. Completing a quiz unlocks next quiz in track
3. Completing a track unlocks next track
4. Partner progression tracked separately
5. Daily quests pull from user's current position

**Example Flow:**
```
Day 1: User at Track 1, Quiz 0 → Assigned "Getting to Know You"
Day 2: User completed Quiz 0 → Assigned "Love Languages" (Quiz 1)
Day 3: User completed Quiz 1 → Assigned "Communication Styles" (Quiz 2)
...
Day 5: User completed Track 1 → Move to Track 2, Quiz 0
```

### Daily Quest Assignment

**Algorithm:**
```dart
Future<List<String>> assignDailyQuizzes(String userId) async {
  final progression = await getProgressionState(userId);
  final quizzes = <String>[];

  // Slot 1: Current quiz in current track
  quizzes.add(getCurrentQuiz(progression));

  // Slot 2: Random quiz from completed quizzes (review/variety)
  quizzes.add(getReviewQuiz(progression));

  // Slot 3: Preview quiz from next track or special format
  quizzes.add(getPreviewOrSpecialQuiz(progression));

  return quizzes;
}
```

**Benefits:**
- ✅ Guided progression through content
- ✅ No random/repeated quizzes
- ✅ Sense of accomplishment
- ✅ Can track couple's journey
- ✅ Easy to add new tracks/quizzes

### Integration with Existing QuizService

**Critical Architecture Decision:** We REUSE the existing quiz infrastructure instead of creating duplicate systems.

**How It Works:**
1. **QuizQuestProvider** calls existing `QuizService.startQuizSession()`
2. Passes category/tier filters based on current track position
3. QuizService creates session using existing question bank
4. Returns `QuizSession.id` as the quest's `contentId`
5. Users complete the quiz through existing quiz screens
6. On completion, DailyQuestService awards 30 LP and advances progression

**Code Example:**
```dart
class QuizQuestProvider implements QuestProvider {
  @override
  Future<String?> generateQuest({
    required QuizProgressionState? progressionState,
    ...
  }) async {
    // Get category/tier for current position
    final trackConfig = _getTrackConfig(
      progressionState.currentTrack,
      progressionState.currentPosition,
    );

    // Use existing QuizService to create session
    final session = await QuizService().startQuizSession(
      formatType: 'classic',
      categoryFilter: trackConfig.category,
      difficulty: trackConfig.tier,
    );

    // Return session ID as contentId
    return session.id;
  }
}
```

**What We DON'T Create:**
- ❌ New quiz question JSON files
- ❌ New quiz session models
- ❌ New quiz UI screens
- ❌ Duplicate quiz logic

**What We DO Create:**
- ✅ QuizProgressionState model (tracks which quiz in progression)
- ✅ Track configuration mapping (track/position → category/tier)
- ✅ Integration layer (QuizQuestProvider)
- ✅ Daily quest wrapper (DailyQuest model references quiz sessions)

---

## Quest Sync Architecture

### Problem

Both partners must see the **same daily quests** to enable collaboration and completion tracking.

### Solution: Firebase RTDB Sync

**Database Structure:**
```
/daily_quest_assignments/
  /{dateKey}/              // "2025-11-13"
    /{coupleId}/           // Hash of both user IDs
      /quest1: "quiz_session_abc123"
      /quest2: "quiz_session_def456"
      /quest3: "quiz_session_ghi789"
      /assignedBy: "user_123"
      /assignedAt: 1699876543000
```

### Sync Flow

**First User Opens App:**
```
1. Check Firebase for today's quest assignments
2. If not exist:
   - Generate 3 quizzes based on user's progression
   - Create quiz sessions in Firebase
   - Write quest assignments to Firebase
3. If exists:
   - Load quest assignments from Firebase
   - Sync to local Hive storage
```

**Second User Opens App:**
```
1. Check Firebase for today's quest assignments
2. Assignment exists (created by partner)
3. Load same quest sessions
4. Sync to local Hive storage
5. Both users now have identical quests
```

### Implementation

**QuestSyncService:**
```dart
class QuestSyncService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  Future<List<String>> getDailyQuestAssignments(String dateKey) async {
    final coupleId = await _getCoupleId();
    final ref = _db.ref('daily_quest_assignments/$dateKey/$coupleId');

    final snapshot = await ref.get();
    if (snapshot.exists) {
      // Load existing assignments
      return _parseAssignments(snapshot);
    } else {
      // Generate new assignments
      return await _generateAndSyncQuests(dateKey, coupleId);
    }
  }

  Future<List<String>> _generateAndSyncQuests(
    String dateKey,
    String coupleId,
  ) async {
    final quizIds = await _quizService.assignDailyQuizzes(currentUserId);

    // Write to Firebase
    final ref = _db.ref('daily_quest_assignments/$dateKey/$coupleId');
    await ref.set({
      'quest1': quizIds[0],
      'quest2': quizIds[1],
      'quest3': quizIds[2],
      'assignedBy': currentUserId,
      'assignedAt': ServerValue.timestamp,
    });

    return quizIds;
  }

  String _getCoupleId() {
    // Generate deterministic couple ID from both user IDs
    final userId = _storage.getUser()?.id ?? '';
    final partnerId = _storage.getPartner()?.pushToken ?? '';
    final combined = [userId, partnerId]..sort();
    return combined.join('_');
  }
}
```

**Benefits:**
- ✅ Guaranteed same quests for both partners
- ✅ Only one user generates quests (prevents conflicts)
- ✅ Offline support (local Hive cache)
- ✅ Quest history preserved in Firebase

### Edge Cases

**Time Zone Differences:**
- Use UTC for `dateKey` calculation
- Each user's local midnight triggers quest refresh
- If partners in different time zones, first to cross midnight generates quests

**Offline Mode:**
- Cache previous day's quests
- On reconnect, sync with Firebase
- Show warning if can't sync

**Partner Not Paired:**
- Generate quests locally only
- When partner pairs, sync to Firebase

---

## Flexible Quest Type System

### Architecture for Extensibility

**Quest Type Registry:**
```dart
abstract class QuestProvider {
  QuestType get type;
  Future<String> generateQuest(String userId);
  Future<bool> isCompleted(String questId, String userId);
  Future<void> awardCompletion(String questId);
}

class QuizQuestProvider implements QuestProvider {
  @override
  QuestType get type => QuestType.quiz;

  @override
  Future<String> generateQuest(String userId) async {
    // Generate quiz session
    final session = await _quizService.createSession(...);
    return session.id;
  }

  @override
  Future<bool> isCompleted(String questId, String userId) async {
    final session = _storage.getQuizSession(questId);
    return session?.hasUserAnswered(userId) ?? false;
  }

  @override
  Future<void> awardCompletion(String questId) async {
    await _lovePointService.awardQuestReward(questId, 30);
  }
}

class QuestionQuestProvider implements QuestProvider {
  // Future implementation
}

class GameQuestProvider implements QuestProvider {
  // Future implementation for games in daily quests
}
```

**Quest Type Manager:**
```dart
class QuestTypeManager {
  final Map<QuestType, QuestProvider> _providers = {};

  void registerProvider(QuestProvider provider) {
    _providers[provider.type] = provider;
  }

  Future<String> generateQuest(QuestType type, String userId) {
    return _providers[type]!.generateQuest(userId);
  }

  Future<bool> isCompleted(QuestType type, String questId, String userId) {
    return _providers[type]!.isCompleted(questId, userId);
  }
}
```

**Usage:**
```dart
// Initialize
final manager = QuestTypeManager();
manager.registerProvider(QuizQuestProvider());
// Future: manager.registerProvider(GameQuestProvider());

// Generate quest
final questId = await manager.generateQuest(QuestType.quiz, userId);
```

**Benefits:**
- ✅ Easy to add new quest types
- ✅ Decoupled quest logic
- ✅ Each type handles its own completion/rewards
- ✅ No if/else chains
- ✅ Testable in isolation

---

## 7 AM Notification System

### Overview

Send push notification at 7 AM local time to remind users about new daily quests.

### Implementation Strategy

**Option 1: Flutter Local Notifications (Recommended)**

Use `flutter_local_notifications` to schedule daily notifications based on local time:

```dart
class DailyQuestNotificationService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> scheduleDailyQuestNotification() async {
    // Cancel previous schedule
    await _notifications.cancelAll();

    // Schedule for 7 AM every day
    await _notifications.zonedSchedule(
      0, // Notification ID
      '🌅 Good morning!',
      'Your daily quests are ready. Complete them together!',
      _next7AM(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_quests',
          'Daily Quests',
          channelDescription: 'Daily quest reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
    );
  }

  tz.TZDateTime _next7AM() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      7, // 7 AM
      0, // 0 minutes
    );

    // If 7 AM already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  Future<void> init() async {
    // Initialize plugin
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _notifications.initialize(initializationSettings);

    // Request permissions (iOS)
    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Schedule notification
    await scheduleDailyQuestNotification();
  }
}
```

**Option 2: Cloud Functions (Backup)**

If local notifications unreliable, use Firebase Cloud Functions with timezone support:

```javascript
// functions/index.js
exports.scheduleDailyQuestNotifications = functions.pubsub
  .schedule('0 7 * * *') // Every day at 7 AM UTC
  .timeZone('America/Los_Angeles') // User's timezone
  .onRun(async (context) => {
    // Send FCM to all users in this timezone
  });
```

**Hybrid Approach (Recommended):**
1. Use local notifications as primary
2. Cloud Functions as fallback
3. Re-schedule local notification on app open

### Notification Content Variations

```dart
final messages = [
  'Good morning! Your daily quests await ☀️',
  'Ready to connect today? 3 new quests available!',
  'Start your day together! Daily quests are live 💕',
  'New daily quests unlocked! Time to play 🎯',
];

final randomMessage = messages[Random().nextInt(messages.length)];
```

---

## Integration Points

### 1. Update Love Point Rewards

**Current System:**
```dart
// lib/services/love_point_service.dart
static const int REMINDER_DONE_REWARD = 10;
static const int POKE_REWARD = 5;
static const int MUTUAL_POKE_REWARD = 10;
```

**New System:**
```dart
// Updated rewards
static const int REMINDER_DONE_REWARD = 5;  // Reduced
static const int POKE_REWARD = 5;            // Keep same
static const int MUTUAL_POKE_REWARD = 10;   // Keep same
static const int DAILY_QUEST_REWARD = 30;   // New
static const int SIDE_QUEST_REWARD = 20;    // New (optional)
```

### 2. Quiz Service Integration

- When quiz session completes, check if it's part of a daily quest
- If yes, call `DailyQuestService.markQuestCompleted()`
- Award 30 LP instead of current quiz rewards

### 3. Question System (New)

**Create new question prompts:**
- Daily rotating questions
- Both users submit text answers
- Partner can see and react to answers
- Examples in `lib/services/question_bank.dart`

### 4. Game Integration

- "Cute or Corny?" game
- "Would You Rather" (already exists)
- Other quick interactive games

---

## UI Components

### 1. DailyQuestsWidget

**Location:** `lib/widgets/daily_quests_widget.dart`

**Features:**
- Displays 3 daily quest cards
- Shows completion status (checkmarks, avatars)
- Vertical progress tracker
- Completion banner when 3/3 done

### 2. SideQuestsWidget

**Location:** `lib/widgets/side_quests_widget.dart`

**Features:**
- Optional activities beyond daily quests
- Scrollable horizontal cards
- Shows available side quests
- Lower visual priority than daily quests

### 3. QuestCard Component

**Location:** `lib/widgets/quest_card.dart`

**Features:**
- Type badge (Question, Quiz, Game)
- Title and description
- Completion status
- Participant avatars
- Tap to navigate to activity

### 4. Home Screen Redesign

**Location:** `lib/screens/new_home_screen.dart`

**New Layout:**
```
- Header (Title + Streak)
- Quick Actions (Poke + Reminder notes)
- Daily Quests (3 cards with progress)
- Completion Banner (conditional)
- Side Quests (horizontal scroll)
```

---

## Database Schema

### Hive Boxes

**New Boxes:**
- `daily_quests` - Stores DailyQuest objects
- `quest_completions` - Stores DailyQuestCompletion objects

**Updated Boxes:**
- `love_point_transactions` - Add quest-related transactions

**Storage Methods:**
```dart
// StorageService additions
Box<DailyQuest> get dailyQuestsBox;
Box<DailyQuestCompletion> get questCompletionsBox;

Future<void> saveDailyQuest(DailyQuest quest);
List<DailyQuest> getDailyQuests(String dateKey);
DailyQuestCompletion? getQuestCompletion(String dateKey);
```

---

## Content Types & Examples

### 1. Question Quests

**Examples:**
- "Who's funnier? Why?"
- "What's your partner's love language?"
- "Describe your perfect date night"
- "What's one thing you appreciate today?"
- "What's your favorite memory together?"

**Implementation:**
- Text input for both users
- Character limit: 500
- Both must answer to complete quest
- Answers visible to partner

### 2. Quiz Quests

**Formats:**
- Classic Quiz (5 questions about partner)
- Speed Round (10 quick questions, 60s timer)
- Would You Rather (5 scenarios + predict partner)

**Implementation:**
- Reuse existing quiz systems
- Track as quest completion
- Award 30 LP on both completion

### 3. Game Quests

**Types:**
- **Cute or Corny?** - Rate romantic gestures
- **High or Low?** - Guess partner's rating
- **This or That?** - Quick preference choices
- **Photo Challenge** - Daily photo sharing

**Implementation:**
- Quick interactions (2-5 minutes)
- Both must participate
- Fun, lighthearted content

---

## Reward Distribution

### Love Point Flow

**Daily Quest Completion (Both Users):**
```
User A completes quest → No LP yet
User B completes quest → Both get 30 LP
Total: 60 LP per quest (30 each)
3 quests = 180 LP total per day
```

**Side Quest Completion:**
```
Optional: 20 LP per side quest
Unlimited side quests available
```

**Pokes & Reminders (Reduced):**
```
Send poke: 5 LP
Complete reminder: 5 LP
Mutual poke: 10 LP (5 each)
```

### Achievement Thresholds

With new reward system:
- **Daily quests**: 180 LP/day (if all 3 completed)
- **Consistency**: Higher value on completing all 3 vs. random activities
- **Partner engagement**: Both must participate for rewards

---

## Implementation Phases

### Phase 1: Core Infrastructure (Week 1)

**Data Models:**
- [ ] Create `DailyQuest` model (typeId: 17)
- [ ] Create `DailyQuestCompletion` model (typeId: 18)
- [ ] Create `QuizProgressionState` model (typeId: 19)
- [ ] Generate Hive adapters for all models
- [ ] Update `StorageService` with new boxes

**Services:**
- [ ] Create `DailyQuestService` with quest tracking
- [ ] Create `QuestSyncService` for Firebase RTDB sync
- [ ] Create `QuestTypeManager` (provider pattern)
- [ ] Implement `QuizQuestProvider`
- [ ] Update `LovePointService` reward constants (5 LP pokes, 30 LP quests)

### Phase 2: Branching System & Sync (Week 1-2)

**Quiz Progression:**
- [ ] Design 3 quiz tracks with 4 quizzes each
- [ ] Implement progression state tracking
- [ ] Create quiz assignment algorithm (current, review, preview)
- [ ] Test progression flow locally

**Firebase Sync:**
- [ ] Implement couple ID generation
- [ ] Create Firebase RTDB structure for quest assignments
- [ ] Implement quest sync logic (first user generates, second loads)
- [ ] Handle time zone differences (UTC dateKey)
- [ ] Add offline caching
- [ ] Test sync between two devices

### Phase 3: UI Components (Week 2)

**Home Screen Redesign:**
- [ ] Build `DailyQuestsWidget` (3 quest cards + progress tracker)
- [ ] Build `QuestCard` component (type badge, title, completion status)
- [ ] Update `SideQuestsWidget` (existing carousel for games)
- [ ] Create completion banner ("Way to go!")
- [ ] Integrate into `new_home_screen.dart`

**Quest Card Features:**
- [ ] Vertical progress tracker with checkmarks
- [ ] Participant avatars (show who completed)
- [ ] Type badges (Quiz, Question, Game - future)
- [ ] Tap navigation to quiz screens

### Phase 4: Notifications (Week 2)

**7 AM Daily Notification:**
- [ ] Add `flutter_local_notifications` dependency
- [ ] Create `DailyQuestNotificationService`
- [ ] Implement 7 AM local time scheduling
- [ ] Add notification permission requests
- [ ] Test on Android and iOS
- [ ] Add notification content variations

**Notification Triggers:**
- [ ] Schedule on app install
- [ ] Re-schedule on app open (refresh)
- [ ] Handle timezone changes
- [ ] Test notification reliability

### Phase 5: Integration & Rewards (Week 2-3)

**Quiz Integration:**
- [ ] Connect quiz completion to quest system
- [ ] Award 30 LP when both users complete quest
- [ ] Update Activity Hub to show quest status
- [ ] Test LP distribution

**Side Quests:**
- [ ] Keep Word Ladder in carousel
- [ ] Keep Memory Flip in carousel
- [ ] Ensure they don't appear in daily quests
- [ ] Keep existing LP rewards for side quests

**Midnight Reset:**
- [ ] Implement midnight rollover logic (local time)
- [ ] Generate new quests at midnight
- [ ] Archive previous day's quests
- [ ] Sync with partner's midnight (different time zones)

### Phase 6: Testing & Edge Cases (Week 3)

**Core Functionality:**
- [ ] Test quest generation (3 quizzes per day)
- [ ] Test branching progression (tracks advance correctly)
- [ ] Test sync between partners
- [ ] Test completion tracking (both users)
- [ ] Test LP rewards (30 LP per quest)

**Edge Cases:**
- [ ] Midnight rollover in different time zones
- [ ] Offline mode (cached quests)
- [ ] Partner not paired yet
- [ ] Quest completed while offline
- [ ] Re-pairing after unpair
- [ ] App not opened for multiple days

**Polish:**
- [ ] Animations for quest completion
- [ ] Loading states during sync
- [ ] Error handling (sync failures)
- [ ] Empty states
- [ ] Tutorial/onboarding for new users

---

## Decisions (Answered)

1. ✅ **Quest Reset Time**: Midnight local time
2. ✅ **Quest Selection**: Intelligent branching system (see below)
3. ✅ **Missed Days**: Start fresh next day, no carry-over
4. ✅ **Side Quest Limits**: Use existing carousel, show all available games
5. ✅ **Notifications**: Push notification at 7 AM local time daily
6. ✅ **Partner Sync**: Firebase RTDB sync (see architecture below)
7. ✅ **Question Answers**: Handled by existing quiz system (no changes needed)

---

## Success Metrics

**KPIs to Track:**
- Daily quest completion rate (target: 60%+ complete all 3)
- Daily active users (DAU)
- Average LP earned per day
- Streak retention (7-day, 30-day)
- Partner engagement (both users completing quests)
- Side quest participation rate

---

## Future Enhancements

1. **Streak Bonuses**: Extra LP for consecutive days (e.g., 7-day streak = +50 LP bonus)
2. **Quest Variety**: More quest types (photo sharing, voice notes, etc.)
3. **Personalization**: AI-suggested quests based on relationship stage
4. **Themed Weeks**: Special quest collections (Anniversary Week, Adventure Week)
5. **Couple Challenges**: Weekly challenges requiring collaboration
6. **Quest History**: View past completed quests and answers

---

## Technical Considerations

### Performance
- Cache today's quests in memory
- Index quests by dateKey for fast lookup
- Lazy load side quests

### Data Sync
- Daily quests must sync between devices
- Use Firebase RTDB for quest assignments
- Local Hive for quest progress

### Edge Cases
- Time zone differences between partners
- App not opened for multiple days
- Quest completion while offline
- Partner unpaired mid-quest

---

## Migration Strategy

**Existing Users:**
1. First app open after update: Generate quests for current day
2. Preserve existing quiz/game sessions
3. Reduce LP rewards for old reminders/pokes going forward
4. Show onboarding explaining new Daily Quests system

**New Users:**
1. Daily quests available from day 1
2. Tutorial highlighting quest system
3. Encourage completing first quest together

---

## Summary - Updated Plan

### Version 1.0 Scope

**Daily Quests (Required):**
- 🎯 3 quiz-based quests per day
- 🎯 30 LP reward per quest (when both complete)
- 🎯 Branching progression through quiz tracks
- 🎯 Firebase RTDB sync between partners
- 🎯 7 AM daily notification (local time)
- 🎯 Midnight reset (local time)

**Side Quests (Optional):**
- 🎮 Word Ladder (existing)
- 🎮 Memory Flip (existing)
- 🎮 Displayed in horizontal carousel
- 🎮 No changes to existing functionality

**Excluded from v1:**
- ❌ Games in daily quests (Word Ladder, Memory Flip)
- ❌ Question-based quests (future)
- ❌ Photo sharing quests (future)
- ❌ Custom quest types (future - but architecture supports them)

### Key Design Decisions

1. **Branching System**: Users progress sequentially through quiz tracks instead of random selection
2. **Quest Sync**: Firebase RTDB ensures both partners get same daily quests
3. **Flexible Architecture**: Provider pattern allows easy addition of new quest types
4. **Local Notifications**: 7 AM daily reminder using `flutter_local_notifications`
5. **Reduced Rewards**: Pokes/reminders drop to 5 LP, quests worth 30 LP (6x value)

### Technical Architecture

```
┌─────────────────────────────────────────┐
│         Daily Quests System             │
├─────────────────────────────────────────┤
│                                         │
│  ┌──────────────┐   ┌────────────────┐ │
│  │ Quest Sync   │───│ Firebase RTDB  │ │
│  │ Service      │   │ /daily_quest_  │ │
│  │              │   │  assignments/  │ │
│  └──────────────┘   └────────────────┘ │
│         │                               │
│         ▼                               │
│  ┌──────────────────────────────────┐  │
│  │   Daily Quest Service            │  │
│  │  - Generate quests (midnight)    │  │
│  │  - Track completion              │  │
│  │  - Award rewards (30 LP)         │  │
│  └──────────────────────────────────┘  │
│         │                               │
│         ▼                               │
│  ┌─────────────┐   ┌─────────────────┐ │
│  │ Quest Type  │───│ Quiz Quest      │ │
│  │ Manager     │   │ Provider        │ │
│  │ (Registry)  │   │ (Progression)   │ │
│  └─────────────┘   └─────────────────┘ │
│         │                               │
│         ▼                               │
│  ┌──────────────────────────────────┐  │
│  │   Hive Storage                   │  │
│  │  - DailyQuest                    │  │
│  │  - DailyQuestCompletion          │  │
│  │  - QuizProgressionState          │  │
│  └──────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

### User Journey

**Day 1 (New User):**
1. Opens app at 8 AM
2. Sees 3 daily quests (from Track 1, Quiz 0)
3. Completes first quiz → Earns 30 LP (when partner completes too)
4. Next day: Unlocks Track 1, Quiz 1

**Day 7 (Engaged User):**
1. 7 AM notification: "Good morning! Daily quests await ☀️"
2. Opens app, sees new quests (mid-Track 1)
3. Completes all 3 quests → Earns 90 LP
4. Sees "Way to go!" completion banner
5. Optionally plays Word Ladder (side quest)

**Partner Sync:**
1. User A opens app first (7:30 AM)
2. System generates quizzes based on User A's progression
3. Syncs to Firebase RTDB
4. User B opens app (9:00 AM)
5. Loads same quizzes from Firebase
6. Both users work on identical quests

### Success Criteria

**User Engagement:**
- 60%+ daily quest completion rate (all 3 quests)
- 80%+ users complete at least 1 quest per day
- 7-day streak retention: 40%+

**Technical:**
- < 2s quest sync latency
- 99%+ quest sync success rate
- No duplicate quest generation

**Business:**
- 2x daily active users (DAU)
- 3x average daily LP earned
- 50%+ reduction in "quick tap" engagement (pokes)

### Next Steps

1. ✅ Review and approve this plan
2. ⏭️ Begin Phase 1: Core Infrastructure
3. ⏭️ Set up Firebase RTDB structure
4. ⏭️ Design 12 quizzes across 3 tracks
5. ⏭️ Prototype branching system locally

---

**Ready to implement?** This plan provides a complete roadmap for Daily Quests v1.0 with quiz-based content, branching progression, and partner synchronization.

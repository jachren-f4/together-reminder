# Daily Quest System - Technical Documentation

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Core Components](#core-components)
4. [Data Models](#data-models)
5. [Quest Generation Flow](#quest-generation-flow)
6. [Synchronization & Real-Time Updates](#synchronization--real-time-updates)
7. [Completion Flow](#completion-flow)
8. [Love Points Integration](#love-points-integration)
9. [Technical Implementation Details](#technical-implementation-details)
10. [Known Issues & Workarounds](#known-issues--workarounds)
11. [Testing & Debugging](#testing--debugging)
12. [Improvement Suggestions](#improvement-suggestions)

---

## Overview

The Daily Quest System provides couples with 3 shared daily activities that both partners must complete to earn rewards. The system is designed around a "first user creates, second user loads" pattern to ensure both partners receive identical quests.

### Key Features

- **3 Daily Quests**: Generated once per day, shared between both partners
- **Dual Completion Required**: Both partners must complete each quest
- **Real-Time Sync**: Partner completions sync via Firebase RTDB
- **Love Points Rewards**: 30 LP awarded per quest when both complete
- **Quest Types**: Quiz, Question, Game, Word Ladder, Memory Flip (currently only Quiz implemented)
- **Progression System**: Quiz questions follow a track-based progression
- **Expiration**: Quests expire at midnight (23:59:59)

---

## Architecture

### High-Level Design

```
┌─────────────────────────────────────────────────────────────┐
│                      User Launches App                       │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Initialization (main.dart)                 │
│                                                               │
│  1. Firebase Init                                             │
│  2. Hive Init (Local Storage)                                 │
│  3. NotificationService Init                                  │
│  4. Quest Sync Check                                          │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
           ┌────────────────┴────────────────┐
           │                                  │
           ▼                                  ▼
  ┌────────────────┐              ┌──────────────────┐
  │  Firebase Has  │              │   No Firebase     │
  │     Quests?    │              │      Quests       │
  └────────┬───────┘              └────────┬─────────┘
           │                               │
           ▼                               ▼
  ┌────────────────┐              ┌──────────────────┐
  │  Load Quests   │              │  Generate New    │
  │  from Firebase │              │     Quests       │
  │  (Preserve IDs)│              │  (Save to FB)    │
  └────────┬───────┘              └────────┬─────────┘
           │                               │
           └────────────┬──────────────────┘
                        │
                        ▼
           ┌────────────────────────┐
           │   Save Quests Locally   │
           │       (Hive Box)        │
           └────────────┬────────────┘
                        │
                        ▼
           ┌────────────────────────┐
           │  Display Daily Quests   │
           │        Widget           │
           └─────────────────────────┘
```

### Service Layer Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Application Layer                          │
│  (Widgets: DailyQuestsWidget, QuestCard)                     │
└────────────────┬─────────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────────┐
│                      Service Layer                            │
│                                                               │
│  ┌──────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │QuestTypeMan- │  │ DailyQuestSvc   │  │ QuestSyncSvc    │ │
│  │ager          │──▶│                 │◀─│                 │ │
│  │              │  │ - Generation    │  │ - Firebase Sync │ │
│  │ - Providers  │  │ - Completion    │  │ - Real-time     │ │
│  │ - Orches-    │  │ - Expiration    │  │ - Partner Watch │ │
│  │   tration    │  │ - Statistics    │  │                 │ │
│  └──────────────┘  └─────────────────┘  └─────────────────┘ │
│                                                               │
│  ┌──────────────┐  ┌─────────────────┐                      │
│  │QuizQuest     │  │ LovePointSvc    │                      │
│  │Provider      │  │                 │                      │
│  │              │  │ - Award LP      │                      │
│  │ - Generate   │  │ - Firebase Sync │                      │
│  │ - Track Prog │  │ - Deduplication │                      │
│  └──────────────┘  └─────────────────┘                      │
└────────────────┬─────────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────────┐
│                      Storage Layer                            │
│                                                               │
│  ┌──────────────┐  ┌─────────────────┐                      │
│  │ Hive (Local) │  │ Firebase RTDB    │                      │
│  │              │  │                  │                      │
│  │ - Quests     │  │ - /daily_quests/ │                      │
│  │ - Sessions   │  │ - /quiz_progres- │                      │
│  │ - Completion │  │    sion/         │                      │
│  │ - Progression│  │ - /lp_awards/    │                      │
│  └──────────────┘  └─────────────────┘                      │
└──────────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. QuestTypeManager
**Location**: `lib/services/quest_type_manager.dart`

**Purpose**: Orchestrates quest generation using provider pattern

**Key Methods**:
- `registerProvider(QuestProvider)` - Register quest type handlers
- `generateDailyQuests()` - Generate all 3 daily quests
- Uses provider pattern for extensibility

**Provider Pattern**:
```dart
abstract class QuestProvider {
  QuestType get questType;
  Future<DailyQuest?> generateQuest({
    required String dateKey,
    required int sortOrder,
    String? currentUserId,
    String? partnerUserId,
  });
}
```

### 2. DailyQuestService
**Location**: `lib/services/daily_quest_service.dart`

**Responsibilities**:
- Quest completion tracking
- User completion status (dual-user model)
- Love Point award coordination (non-quiz types)
- Statistics (streak, total completed, etc.)
- Quest expiration management

**Key Methods**:
- `getTodayQuests()` - Retrieve today's quests
- `completeQuestForUser()` - Mark quest complete for one user
- `areAllMainQuestsCompleted()` - Check if all 3 quests done
- `getCurrentStreak()` - Get consecutive days streak

### 3. QuestSyncService
**Location**: `lib/services/quest_sync_service.dart`

**Responsibilities**:
- Firebase RTDB synchronization
- "First creates, second loads" pattern
- Real-time partner completion listening
- Quest ID consistency validation
- Progression state sync

**Key Methods**:
- `syncTodayQuests()` - Check Firebase vs local quests
- `saveQuestsToFirebase()` - Upload generated quests
- `listenForPartnerCompletions()` - Real-time stream
- `markQuestCompleted()` - Sync completion to Firebase

**Firebase Structure**:
```
/daily_quests/
  {coupleId}/
    {dateKey}/                    // e.g., "2025-11-14"
      quests: [
        {
          id: "quest_1763093637734_quiz"
          questType: 1            // QuestType.quiz.index
          contentId: "session_id"
          sortOrder: 0
          isSideQuest: false
        },
        ...
      ]
      completions: {
        quest_1763093637734_quiz: {
          alice-dev-user-...: true
          bob-dev-user-...: true
        }
      }
      generatedBy: "user_id"
      generatedAt: {timestamp}
      progression: {
        currentTrack: 0
        currentPosition: 2
        totalCompleted: 5
      }
```

### 4. QuizQuestProvider
**Location**: `lib/services/quest_type_manager.dart`

**Responsibilities**:
- Generate quiz-based quests
- Track quiz progression (track + position)
- Create quiz sessions via QuizService
- Save sessions to Firebase for partner access

**Quiz Progression**:
- 5 Tracks: Tier 1 (Easy) → Tier 5 (Expert)
- Each track has ~36 questions (1 per day for ~1 month)
- Advances position within track daily
- Advances to next track when track completes

### 5. DailyQuestsWidget
**Location**: `lib/widgets/daily_quests_widget.dart`

**Responsibilities**:
- Display quest list with progress tracker
- Listen for partner completions (real-time)
- Handle quest tap navigation
- Show completion banner when all done

**Real-Time Updates**:
```dart
_partnerCompletionSubscription = _questSyncService
  .listenForPartnerCompletions(
    currentUserId: user.id,
    partnerUserId: partner.pushToken,
  )
  .listen((partnerCompletions) {
    // Update local storage with partner's completions
    // Trigger UI rebuild
  });
```

---

## Data Models

### DailyQuest
**Location**: `lib/models/daily_quest.dart`
**Hive TypeId**: 17

```dart
class DailyQuest extends HiveObject {
  String id;                    // "quest_{timestamp}_{type}"
  String dateKey;               // "YYYY-MM-DD"
  int questType;                // QuestType enum index
  String contentId;             // Quiz session ID, etc.
  DateTime createdAt;
  DateTime expiresAt;           // End of day (23:59:59)
  String status;                // 'pending', 'in_progress', 'completed'
  Map<String, bool>? userCompletions;  // {userId: true}
  int? lpAwarded;               // 30 LP
  DateTime? completedAt;
  bool isSideQuest;             // false for main 3 quests
  int sortOrder;                // 0, 1, 2 for daily quests
}
```

**Key Methods**:
- `hasUserCompleted(userId)` - Check if specific user completed
- `areBothUsersCompleted()` - Check if both completed
- `isExpired` - Check if past 23:59:59
- `isCompleted` - Check if status == 'completed'

### DailyQuestCompletion
**Hive TypeId**: 18

Tracks daily completion stats for achievements/streaks:

```dart
class DailyQuestCompletion extends HiveObject {
  String dateKey;               // "YYYY-MM-DD"
  int questsCompleted;          // 0-3
  bool allQuestsCompleted;      // true when 3/3
  DateTime completedAt;
  int totalLpEarned;            // 90 LP for 3 quests
  int sideQuestsCompleted;      // Bonus quests
  DateTime? lastUpdatedAt;
}
```

---

## Quest Generation Flow

### Detailed Sequence

```
App Launch (main.dart)
│
├─▶ Initialize Services
│   ├─ Firebase
│   ├─ Hive
│   ├─ DailyQuestService
│   ├─ QuestSyncService
│   └─ QuestTypeManager (registers providers)
│
├─▶ Sync Check: syncTodayQuests()
│   │
│   ├─▶ Check Firebase: /daily_quests/{coupleId}/{dateKey}
│   │
│   ├─ [EXISTS]
│   │   ├─▶ Compare Quest IDs
│   │   │   ├─ [MATCH] → Sync completion only
│   │   │   └─ [MISMATCH] → Delete local, load from Firebase
│   │   │
│   │   └─▶ Load Quests from Firebase
│   │       ├─ Preserve original IDs
│   │       ├─ Load completion status
│   │       └─ Save locally to Hive
│   │
│   └─ [DOES NOT EXIST]
│       ├─▶ Generate New Quests
│       │   │
│       │   ├─▶ Load/Create Progression State
│       │   │   ├─ Check Firebase: /quiz_progression/{coupleId}
│       │   │   ├─ Load if exists
│       │   │   └─ Create new if first time
│       │   │
│       │   ├─▶ Generate 3 Quests (sortOrder 0, 1, 2)
│       │   │   │
│       │   │   └─▶ For each quest:
│       │   │       ├─ Select question from progression track
│       │   │       ├─ Create quiz session (QuizService)
│       │   │       ├─ Save session to Firebase
│       │   │       ├─ Create DailyQuest with session ID
│       │   │       └─ Advance progression position
│       │   │
│       │   ├─▶ Save Quests to Hive (local)
│       │   │
│       │   └─▶ Save Quests to Firebase
│       │       ├─ Quest metadata (id, type, contentId, sortOrder)
│       │       ├─ Generation metadata (generatedBy, timestamp)
│       │       └─ Progression state
│       │
│       └─▶ Return Generated Quests
│
└─▶ Display Quests in UI
    ├─ DailyQuestsWidget
    ├─ Listen for partner completions
    └─ Enable user interaction
```

### Quest ID Generation

**Critical**: Quest IDs must be deterministic and identical across both devices when loaded from Firebase.

```dart
// Generation
id: 'quest_${DateTime.now().millisecondsSinceEpoch}_${type.name}'

// Example: "quest_1763093637734_quiz"
```

**Problem**: If second device generates instead of loading, IDs will differ!

**Solution**: Firebase sync ensures second device loads with preserved IDs.

---

## Synchronization & Real-Time Updates

### First User Creates, Second User Loads

```
┌──────────────────┐                    ┌──────────────────┐
│   Alice (First)  │                    │   Bob (Second)   │
└────────┬─────────┘                    └────────┬─────────┘
         │                                       │
         ├─▶ Check Firebase                      ├─▶ Check Firebase
         │   (No quests exist)                   │   (Quests exist!)
         │                                       │
         ├─▶ Generate quests                     ├─▶ Load quests
         │   quest_1763093637734_quiz           │   quest_1763093637734_quiz ✓
         │   quest_1763093637735_quiz           │   quest_1763093637735_quiz ✓
         │   quest_1763093637736_quiz           │   quest_1763093637736_quiz ✓
         │                                       │
         ├─▶ Save to Firebase                    ├─▶ Save to Local Hive
         │   /daily_quests/{coupleId}/...       │   (Same IDs!)
         │                                       │
         ├─▶ Save to Local Hive                  │
         │                                       │
         ▼                                       ▼
    [Both have identical quest IDs]
```

### Real-Time Partner Completion

**Widget Subscription**:
```dart
_partnerCompletionSubscription = _questSyncService
  .listenForPartnerCompletions(
    currentUserId: user.id,
    partnerUserId: partner.pushToken,
  )
  .listen((partnerCompletions) {
    // partnerCompletions = {questId: true}

    for (final questId in partnerCompletions.keys) {
      final quest = _storage.getDailyQuest(questId);
      if (quest != null && !quest.hasUserCompleted(partner.pushToken)) {
        quest.userCompletions ??= {};
        quest.userCompletions![partner.pushToken] = true;

        if (quest.areBothUsersCompleted()) {
          quest.status = 'completed';
          quest.completedAt = DateTime.now();
        }

        _storage.updateDailyQuest(quest);
      }
    }

    setState(() {}); // Rebuild UI
  });
```

**Firebase Path**:
```
/daily_quests/{coupleId}/{dateKey}/completions/{questId}/{userId} = true
```

---

## Completion Flow

### User Completes Quest

```
User taps quest (e.g., Quiz)
│
├─▶ Navigate to Quiz Screen
│
├─▶ User completes quiz
│
├─▶ QuizService.submitAnswers()
│   ├─ Save answers to session
│   ├─ Calculate score
│   └─ Mark session complete
│
├─▶ Quest Complete Handler
│   │
│   ├─▶ DailyQuestService.completeQuestForUser()
│   │   ├─ Check if user already completed
│   │   ├─ Mark userCompletions[userId] = true
│   │   ├─ Check if both users completed
│   │   │   ├─ [YES] → Mark quest as 'completed'
│   │   │   │          Award LP (if non-quiz)
│   │   │   └─ [NO]  → Mark quest as 'in_progress'
│   │   └─ Save to local Hive
│   │
│   └─▶ QuestSyncService.markQuestCompleted()
│       └─ Save to Firebase completion path
│           /completions/{questId}/{userId} = true
│
└─▶ UI Updates
    ├─ Quest card shows completion avatar
    ├─ Progress tracker updates
    └─ Partner's device receives real-time update
```

### Both Users Complete

```
Second User Completes
│
├─▶ DailyQuestService.completeQuestForUser()
│   ├─ userCompletions now has both users
│   ├─ areBothUsersCompleted() → true
│   ├─ status = 'completed'
│   ├─ completedAt = now
│   │
│   └─▶ Award Love Points (for non-quiz types)
│       │
│       └─▶ LovePointService.awardPointsToBothUsers()
│           ├─ Award 30 LP to user 1
│           ├─ Award 30 LP to user 2
│           └─ Save to Firebase /lp_awards/
│               (deduplication handled)
│
├─▶ Sync completion to Firebase
│
└─▶ Both devices update UI
    ├─ Quest card shows both avatars
    ├─ Progress tracker shows checkmark
    └─ Completion banner if all 3 done
```

**Note**: Quiz quests award LP via QuizService, not DailyQuestService, to avoid double-awarding.

---

## Love Points Integration

### Award Flow

**Quiz Quests**:
```
QuizService.submitAnswers()
│
└─▶ LovePointService.awardPointsToBothUsers()
    ├─ Award 30 LP to both users
    ├─ Save to Firebase /lp_awards/{coupleId}/{awardId}
    └─ Deduplicated via award ID
```

**Non-Quiz Quests**:
```
DailyQuestService.completeQuestForUser()
│
└─ [When both complete]
   └─▶ LovePointService.awardPointsToBothUsers()
       └─ Award 30 LP to both users
```

### Firebase LP Award Structure
```
/lp_awards/{coupleId}/
  {awardId}/                    // Unique ID per award
    user1:
      userId: "alice-..."
      amount: 30
      reason: "quiz_completed"
      timestamp: {time}
    user2:
      userId: "bob-..."
      amount: 30
      reason: "quiz_completed"
      timestamp: {time}
```

### Deduplication

**Location**: `lib/services/storage_service.dart`

Uses `app_metadata` box to track applied awards:

```dart
Set<String> getAppliedLPAwards() {
  final box = Hive.box('app_metadata');
  final List<dynamic>? awards = box.get('_appliedLPAwards');
  return Set<String>.from(awards ?? []);
}

Future<void> markLPAwardAsApplied(String awardId) async {
  final box = Hive.box('app_metadata');
  final awards = getAppliedLPAwards();
  awards.add(awardId);
  await box.put('_appliedLPAwards', awards.toList());
}
```

**Why Separate Box?**
- `user` box is typed `Box<User>`
- Cannot use as untyped `Box` for metadata
- `app_metadata` is untyped `Box` for flexible storage

---

## Technical Implementation Details

### Quest Expiration

Quests expire at end of day (23:59:59):

```dart
final now = DateTime.now();
final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

DailyQuest(
  ...
  expiresAt: endOfDay,
);

// Check expiration
bool get isExpired => DateTime.now().isAfter(expiresAt);
```

**Cleanup**: Old quests (>7 days) are cleaned up via:
- `DailyQuestService.cleanupExpiredQuests()` (local)
- `QuestSyncService.cleanupOldQuests()` (Firebase)

### Date Key Format

All quests use consistent date keys:

```dart
String getTodayDateKey() {
  final today = DateTime.now();
  return '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
}

// Example: "2025-11-14"
```

### Couple ID Generation

Deterministic couple ID ensures both partners reference same data:

```dart
String generateCoupleId(String userId1, String userId2) {
  final sortedIds = [userId1, userId2]..sort();
  return '${sortedIds[0]}_${sortedIds[1]}';
}

// Example: "alice-dev-user-..._bob-dev-user-..."
```

### Quest Status States

- **`pending`**: Quest created, neither user started
- **`in_progress`**: One user completed, waiting for partner
- **`completed`**: Both users completed

### Hive Box Management

**Quest Boxes**:
- `dailyQuestsBox` - Box<DailyQuest>
- `dailyQuestCompletionsBox` - Box<DailyQuestCompletion>
- `quizSessionsBox` - Box<QuizSession>
- `quizProgressionStatesBox` - Box<QuizProgressionState>
- `app_metadata` - Box (untyped, for LP awards tracking)

---

## 10. Data Retention & Storage Management (MVP)

### Overview

To balance user experience with storage costs during the MVP phase, TogetherRemind implements a 30-day data retention policy for quest activity data while preserving essential completion records and Love Points.

**Retention Policy:**

| Data Type | Retention Period | Rationale |
|-----------|------------------|-----------|
| Quiz Sessions | 30 days | Detailed question/answer data for review |
| Word Ladder Sessions | 30 days | Game history and word paths |
| Memory Flip Puzzles | 30 days | Puzzle configurations and attempts |
| Daily Quest Metadata (RTDB) | 7 days | Short-lived sync data |
| Quest Completion Records | Forever | Achievement tracking, small data |
| Love Point Transactions | Forever | Core progression mechanic, small data |

### Storage Impact

**Per Couple (30-day steady state):**
- Quiz Sessions: ~12 KB (30 quizzes × ~400 bytes)
- Word Ladders: ~6.6 KB (30 sessions × ~220 bytes)
- Memory Flip: ~10.5 KB (30 puzzles × ~350 bytes)
- Quest Completions: ~1.5 KB (365 records × ~40 bytes)
- LP Transactions: ~29 KB (365 transactions × ~80 bytes)
- **Total per couple: ~63 KB**

**At Scale (100,000 couples):**
- Local Storage (Hive): 6.3 GB total (distributed across devices)
- Firebase RTDB: ~6.3 MB (quest metadata only)
- Firebase Bandwidth: ~50 MB/month (well within 10 GB free tier)

### Implementation

#### 1. Quiz Service Cleanup

Add to `lib/services/quiz_service.dart`:

```dart
/// Clean up quiz sessions older than 30 days
Future<void> cleanupOldQuizSessions() async {
  try {
    final now = DateTime.now();
    final allSessions = _storage.quizSessionsBox.values.toList();
    int deletedCount = 0;

    for (final session in allSessions) {
      final age = now.difference(session.createdAt).inDays;
      if (age > 30) {
        await _storage.quizSessionsBox.delete(session.id);
        deletedCount++;
      }
    }

    print('🧹 Cleaned up $deletedCount old quiz sessions (>30 days)');
  } catch (e) {
    print('❌ Error cleaning quiz sessions: $e');
  }
}
```

#### 2. Word Ladder Service Cleanup

Add to `lib/services/word_ladder_service.dart`:

```dart
/// Clean up word ladder sessions older than 30 days
Future<void> cleanupOldLadderSessions() async {
  try {
    final now = DateTime.now();
    final allSessions = _storage.ladderSessionsBox.values.toList();
    int deletedCount = 0;

    for (final session in allSessions) {
      final age = now.difference(session.createdAt).inDays;
      if (age > 30) {
        await _storage.ladderSessionsBox.delete(session.id);
        deletedCount++;
      }
    }

    print('🧹 Cleaned up $deletedCount old ladder sessions (>30 days)');
  } catch (e) {
    print('❌ Error cleaning ladder sessions: $e');
  }
}
```

#### 3. Memory Flip Service Cleanup

Add to `lib/services/memory_flip_service.dart`:

```dart
/// Clean up memory flip puzzles older than 30 days
Future<void> cleanupOldMemoryPuzzles() async {
  try {
    final now = DateTime.now();
    final allPuzzles = _storage.memoryPuzzlesBox.values.toList();
    int deletedCount = 0;

    for (final puzzle in allPuzzles) {
      final age = now.difference(puzzle.createdAt).inDays;
      if (age > 30) {
        await _storage.memoryPuzzlesBox.delete(puzzle.id);
        deletedCount++;
      }
    }

    print('🧹 Cleaned up $deletedCount old memory puzzles (>30 days)');
  } catch (e) {
    print('❌ Error cleaning memory puzzles: $e');
  }
}
```

#### 4. Firebase RTDB Cleanup (Existing)

Already implemented in `lib/services/quest_sync_service.dart`:

```dart
/// Clean up quest metadata older than 7 days from Firebase RTDB
Future<void> cleanupOldQuests() async {
  // Removes /daily_quests/{coupleId}/{dateKey} older than 7 days
  // See quest_sync_service.dart:290-320 for implementation
}
```

#### 5. Periodic Cleanup Invocation

Add to `lib/main.dart` after mock data initialization:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await StorageService.init();
  await NotificationService.initialize();
  await MockDataService.injectMockDataIfNeeded();

  // Run periodic data cleanup
  await _runPeriodicCleanup();

  runApp(const TogetherRemindApp());
}

/// Run cleanup operations on app startup
Future<void> _runPeriodicCleanup() async {
  try {
    print('🧹 Running periodic data cleanup...');

    final storage = StorageService();
    final quizService = QuizService();
    final ladderService = WordLadderService(storage: storage);
    final memoryService = MemoryFlipService(storage: storage);
    final questSyncService = QuestSyncService(
      storage: storage,
      questService: DailyQuestService(storage: storage),
    );

    // Run all cleanup tasks in parallel
    await Future.wait([
      quizService.cleanupOldQuizSessions(),
      ladderService.cleanupOldLadderSessions(),
      memoryService.cleanupOldMemoryPuzzles(),
      questSyncService.cleanupOldQuests(), // Firebase RTDB cleanup
    ]);

    print('✅ Periodic cleanup completed');
  } catch (e) {
    print('⚠️  Cleanup failed: $e');
  }
}
```

### Abandoned Sessions

**Grace Period:** Abandoned or incomplete sessions (where only one partner started) are kept for the full 30-day period before deletion.

**Rationale:**
- Partners may complete quests days later
- Removes pressure for immediate completion
- Simplifies cleanup logic (age-based only, not status-based)

**Example:** Alice starts a quiz on Day 1 but Bob is busy. On Day 15, Bob completes it. The session remains until Day 31.

### Testing Procedures

#### Manual Verification

```dart
// Add to debug dialog or test file
void printStorageStats() {
  final storage = StorageService();

  final quizCount = storage.quizSessionsBox.length;
  final ladderCount = storage.ladderSessionsBox.length;
  final memoryCount = storage.memoryPuzzlesBox.length;
  final lpCount = storage.transactionsBox.length;

  print('📊 Storage Stats:');
  print('  Quiz Sessions: $quizCount');
  print('  Ladder Sessions: $ladderCount');
  print('  Memory Puzzles: $memoryCount');
  print('  LP Transactions: $lpCount');

  // Calculate age distribution
  final now = DateTime.now();
  final oldQuizzes = storage.quizSessionsBox.values
      .where((s) => now.difference(s.createdAt).inDays > 30)
      .length;

  print('  Quizzes >30 days: $oldQuizzes (should be 0 after cleanup)');
}
```

#### Automated Testing

1. **Inject old data:**
```dart
// In test environment
final oldDate = DateTime.now().subtract(Duration(days: 35));
final oldSession = QuizSession(
  id: 'test-old',
  createdAt: oldDate,
  // ... other fields
);
storage.quizSessionsBox.put(oldSession.id, oldSession);
```

2. **Run cleanup:**
```dart
await quizService.cleanupOldQuizSessions();
```

3. **Verify deletion:**
```dart
expect(storage.quizSessionsBox.get('test-old'), isNull);
```

### Monitoring & Debugging

**Debug Quest Dialog** (existing feature):
- Double-tap greeting text on home screen
- Shows Firebase RTDB data and local storage
- Copy to clipboard for sharing
- Useful for verifying cleanup ran correctly

**Log Messages:**
- `🧹 Cleaned up X old quiz sessions (>30 days)`
- `🧹 Cleaned up X old ladder sessions (>30 days)`
- `🧹 Cleaned up X old memory puzzles (>30 days)`
- `✅ Periodic cleanup completed`

### Future Enhancements (Post-MVP)

Once user feedback is collected, consider:

1. **Memory Vault Feature:**
   - Export quiz history to PDF/CSV
   - "Highlights" view of favorite moments
   - Compressed archives for long-term storage

2. **Smart Tiering:**
   - Keep 90 days locally
   - Archive 90-365 days to Firebase Storage (cheaper)
   - Summary-only data beyond 1 year

3. **Selective History:**
   - "Save this quiz" bookmark feature
   - Keep only quizzes with perfect scores
   - Relationship milestones preservation

4. **User-Controlled Retention:**
   - Settings toggle: 30/60/90 days
   - Premium tier for unlimited history
   - Export before auto-deletion notifications

### Cross-References

- See [Section 11: Known Issues & Workarounds](#11-known-issues--workarounds) for cleanup testing caveats
- See [Section 7: Quest Lifecycle](#7-quest-lifecycle) for quest creation and completion flow
- See [ARCHITECTURE.md](ARCHITECTURE.md) for storage service details

---

## 11. Known Issues & Workarounds

### Issue 1: Hot Reload Not Supported

**Problem**: Quest state changes don't reflect with hot reload due to:
- Hive storage initialization
- Firebase listeners not re-subscribing
- Service singleton instances retaining old state

**Workaround**: Full app restart required for quest changes

**Status**: Documented limitation, no current fix

### Issue 2: Quest ID Mismatch on Second Device

**Problem**: If second device generates quests instead of loading from Firebase, quest IDs differ between partners.

**Symptoms**:
- Partner completions don't sync
- Quests appear different on each device
- Firebase and local quests out of sync

**Root Cause**: Race condition where both devices generate simultaneously

**Solution**: Implement on Quest Sync Check
1. ALWAYS check Firebase first
2. Compare quest IDs if local quests exist
3. Replace local quests if IDs don't match
4. Log warnings when mismatch detected

**Implemented Fix** (`lib/services/quest_sync_service.dart:71-94`):
```dart
if (localQuests.isNotEmpty) {
  final localQuestIds = localQuests.map((q) => q.id).toSet();

  if (firebaseQuestIds.difference(localQuestIds).isEmpty &&
      localQuestIds.difference(firebaseQuestIds).isEmpty) {
    // IDs match - just sync completion
  } else {
    // IDs don't match - replace local with Firebase
    for (final quest in localQuests) {
      await quest.delete();
    }
    // Load from Firebase
  }
}
```

### Issue 3: LP Awards Not Applied

**Problem**: Hive box type error when tracking applied LP awards

**Error**: `The box "user" is already open and of type Box<User>`

**Root Cause**: Attempted to use typed `Box<User>` as untyped `Box`

**Solution**: Created dedicated `app_metadata` box (untyped) for metadata storage

**Implementation** (`lib/services/storage_service.dart:34,78`):
```dart
static const String _appMetadataBox = 'app_metadata';

await Hive.openBox(_appMetadataBox);  // Untyped box

// Usage
Set<String> getAppliedLPAwards() {
  final box = Hive.box(_appMetadataBox);  // Untyped access
  ...
}
```

### Issue 4: "Quiz Session Not Found"

**Problem**: When tapping quest, quiz session not found in local storage

**Root Cause**: Quiz session exists in Firebase but not loaded to local Hive

**Solution**: Implement Firebase fallback in quest tap handler

**Implementation** (`lib/widgets/daily_quests_widget.dart:323-330`):
```dart
Future<void> _handleQuizQuestTap(DailyQuest quest) async {
  // Try local storage first, then fetch from Firebase
  final session = await _quizService.getSession(quest.contentId);

  if (session == null) {
    _showError('Quiz session not found');
    return;
  }
  ...
}
```

---

## Testing & Debugging

### Debug Menu

**Access**: Double-tap greeting text ("Good morning" / "Good afternoon") on home screen

**Features**:
- View Firebase RTDB quest data
- View local Hive storage
- Copy debug data to clipboard
- Clear local storage (requires manual app restart)

**Location**: `lib/widgets/debug_quest_dialog.dart`

### Clean Testing Protocol

**Always perform clean restart when testing quest sync:**

```bash
# 1. Clear Firebase RTDB data
bash /tmp/clean_firebase.sh

# 2. Kill all Flutter processes
pkill -9 -f flutter

# 3. Optional: Clean build artifacts
cd app && flutter clean

# 4. Launch apps fresh
flutter run -d emulator-5554 &  # Alice
sleep 10 && flutter run -d chrome &  # Bob
```

**Why This Matters**:
- Prevents stale data interference
- Ensures clean Firebase state
- Validates proper initialization
- Reproduces real user experience

### Helper Scripts

**`/tmp/clean_firebase.sh`**:
- Clears `/daily_quests`
- Clears `/quiz_sessions`
- Clears `/lp_awards`
- Clears `/quiz_progression`

**`/tmp/debug_firebase.sh`**:
- Inspects current Firebase RTDB data
- Shows quest structure
- Displays completion status

### Common Debug Checks

1. **Quest IDs Match?**
   ```
   Firebase IDs: [quest_A, quest_B, quest_C]
   Local IDs:    [quest_A, quest_B, quest_C]
   ✓ Match
   ```

2. **Completion Sync Working?**
   ```
   Alice completes → Firebase updated → Bob receives event → Bob UI updates
   ```

3. **LP Awards Applied?**
   ```
   Check app_metadata box for _appliedLPAwards key
   Check user.lp value increased
   ```

4. **Progression Advancing?**
   ```
   /quiz_progression/{coupleId}
   currentTrack: 0
   currentPosition: 2 → 3 (next day)
   ```

---

## Improvement Suggestions

### 1. Streamline Quest Generation

**Current Issue**: Complex logic spread across multiple services

**Suggestion**: Consolidate quest generation into dedicated `QuestGenerationService`

**Benefits**:
- Single source of truth for generation logic
- Easier testing and debugging
- Clear separation of concerns
- Reduced coupling between services

**Proposed Structure**:
```dart
class QuestGenerationService {
  // Dependencies
  final StorageService _storage;
  final QuizService _quizService;
  final Map<QuestType, QuestProvider> _providers;

  /// Generate all daily quests for a couple
  Future<QuestGenerationResult> generateDailyQuests({
    required String coupleId,
    required String dateKey,
    int questCount = 3,
  }) async {
    // 1. Load progression state
    // 2. Generate quests via providers
    // 3. Save sessions to Firebase
    // 4. Return result with quests + progression
  }

  /// Validate quest consistency
  Future<ValidationResult> validateQuests(List<DailyQuest> quests) async {
    // Check IDs are unique
    // Verify sessions exist in Firebase
    // Validate progression state
  }
}
```

### 2. Introduce Quest State Machine

**Current Issue**: Quest status managed via string literals

**Suggestion**: Use formal state machine pattern

**Benefits**:
- Type-safe state transitions
- Clear validation rules
- Prevents invalid states
- Self-documenting code

**Proposed Implementation**:
```dart
enum QuestState {
  pending,
  userCompleted,      // One user done
  partnerCompleted,   // Other user done
  bothCompleted,      // Both done
  expired,

  // State transitions
  const QuestState();

  bool canTransitionTo(QuestState newState) {
    switch (this) {
      case QuestState.pending:
        return newState == QuestState.userCompleted ||
               newState == QuestState.partnerCompleted ||
               newState == QuestState.expired;

      case QuestState.userCompleted:
        return newState == QuestState.bothCompleted ||
               newState == QuestState.expired;

      // ...
    }
  }
}

class QuestStateMachine {
  QuestState _currentState;

  void transitionTo(QuestState newState) {
    if (!_currentState.canTransitionTo(newState)) {
      throw InvalidStateTransitionException(
        from: _currentState,
        to: newState,
      );
    }
    _currentState = newState;
  }
}
```

### 3. Add Quest Event Sourcing

**Current Issue**: Hard to debug quest history and state changes

**Suggestion**: Implement event sourcing for quest lifecycle

**Benefits**:
- Complete audit trail
- Easy debugging "what happened when?"
- Replay capability for testing
- Analytics on quest flow

**Proposed Events**:
```dart
abstract class QuestEvent {
  final String questId;
  final DateTime timestamp;
  final String userId;
}

class QuestCreatedEvent extends QuestEvent { ... }
class QuestStartedEvent extends QuestEvent { ... }
class QuestCompletedEvent extends QuestEvent { ... }
class QuestExpiredEvent extends QuestEvent { ... }
class QuestSyncedEvent extends QuestEvent { ... }

// Storage
/daily_quests/{coupleId}/{dateKey}/events/
  {eventId}/
    type: "QuestCompletedEvent"
    questId: "quest_123"
    userId: "alice-..."
    timestamp: 1234567890
    data: { ... }
```

### 4. Implement Optimistic Updates

**Current Issue**: UI waits for Firebase confirmation

**Suggestion**: Update UI immediately, rollback on error

**Benefits**:
- Snappier user experience
- Better perceived performance
- Handle offline scenarios

**Proposed Implementation**:
```dart
class OptimisticQuestCompletion {
  Future<void> completeQuest(String questId, String userId) async {
    // 1. Update local state immediately
    final originalQuest = _storage.getDailyQuest(questId);
    final updatedQuest = originalQuest.copyWith(
      userCompletions: {...originalQuest.userCompletions, userId: true},
    );
    await _storage.updateDailyQuest(updatedQuest);
    setState(() {}); // UI updates instantly

    try {
      // 2. Sync to Firebase
      await _syncService.markQuestCompleted(questId, userId);
    } catch (e) {
      // 3. Rollback on error
      await _storage.updateDailyQuest(originalQuest);
      setState(() {}); // Revert UI
      _showError('Failed to sync completion');
    }
  }
}
```

### 5. Separate Concerns: Generation vs Synchronization

**Current Issue**: QuestSyncService handles both sync AND loading logic

**Suggestion**: Split into distinct services

**Benefits**:
- Clear responsibilities
- Easier testing
- Reduced complexity

**Proposed Structure**:
```
QuestGenerationService
  - Generate new quests
  - Coordinate providers
  - Manage progression

QuestStorageService
  - Local Hive operations
  - CRUD for quests
  - Consistency checks

QuestSyncService
  - Firebase upload/download
  - Real-time listeners
  - Conflict resolution

QuestOrchestratorService
  - Coordinates all services
  - "First creates, second loads" logic
  - Initialization flow
```

### 6. Add Retry Logic with Exponential Backoff

**Current Issue**: Firebase operations fail silently or crash

**Suggestion**: Implement robust retry mechanism

**Benefits**:
- Handle transient network issues
- Better offline support
- More reliable sync

**Proposed Implementation**:
```dart
class RetryableOperation {
  static Future<T> execute<T>({
    required Future<T> Function() operation,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (attempt < maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        if (attempt >= maxAttempts) rethrow;

        await Future.delayed(delay);
        delay *= backoffMultiplier;
      }
    }

    throw Exception('Max retry attempts exceeded');
  }
}

// Usage
await RetryableOperation.execute(
  operation: () => _syncService.saveQuestsToFirebase(quests),
  maxAttempts: 3,
);
```

### 7. Hot Reload Support Strategy

**Challenge**: Enable hot reload while maintaining quest state

**Proposed Approach 1: State Preservation**:
```dart
class QuestManager {
  static QuestManager? _instance;

  // Preserve across hot reloads
  static QuestManager get instance {
    _instance ??= QuestManager._internal();
    return _instance!;
  }

  // State that survives hot reload
  List<DailyQuest>? _cachedQuests;
  StreamSubscription? _partnerSubscription;

  void dispose() {
    // Clean up but preserve _cachedQuests
    _partnerSubscription?.cancel();
  }

  @override
  void reassemble() {
    super.reassemble();
    // Re-attach listeners without regenerating quests
    if (_cachedQuests != null) {
      _reattachListeners();
    }
  }
}
```

**Proposed Approach 2: Dev Mode Flag**:
```dart
class QuestConfig {
  static const bool enableHotReload = bool.fromEnvironment(
    'ENABLE_HOT_RELOAD',
    defaultValue: false,
  );
}

// In quest sync
if (QuestConfig.enableHotReload) {
  // Skip Firebase validation
  // Use local quests only
  // Disable real-time listeners
}
```

**Proposed Approach 3: Hydration from Storage**:
```dart
@override
void reassemble() {
  super.reassemble();

  // Hot reload detected - hydrate from Hive
  final quests = _storage.getTodayQuests();
  if (quests.isNotEmpty) {
    setState(() {
      _quests = quests;
    });

    // Re-subscribe to partner completions
    _subscribeToPartnerCompletions();
  }
}
```

### 8. Add Quest Validation Layer

**Suggestion**: Validate quest consistency before displaying

**Benefits**:
- Catch data corruption early
- Prevent UI crashes
- Better error messages

**Proposed Validator**:
```dart
class QuestValidator {
  static ValidationResult validate(List<DailyQuest> quests) {
    final errors = <String>[];

    // Check count
    if (quests.length != 3) {
      errors.add('Expected 3 quests, got ${quests.length}');
    }

    // Check IDs are unique
    final ids = quests.map((q) => q.id).toSet();
    if (ids.length != quests.length) {
      errors.add('Duplicate quest IDs detected');
    }

    // Check expiration
    final now = DateTime.now();
    for (final quest in quests) {
      if (quest.expiresAt.isBefore(now.subtract(Duration(days: 1)))) {
        errors.add('Quest ${quest.id} has old expiration date');
      }
    }

    // Check sessions exist
    for (final quest in quests.where((q) => q.type == QuestType.quiz)) {
      if (!_storage.hasQuizSession(quest.contentId)) {
        errors.add('Quiz session ${quest.contentId} not found');
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}
```

### 9. Introduce Quest Repository Pattern

**Suggestion**: Abstract storage operations behind repository interface

**Benefits**:
- Swap storage implementations (Hive → SQL, etc.)
- Easier testing with mock repositories
- Clean architecture principles

**Proposed Interface**:
```dart
abstract class QuestRepository {
  Future<List<DailyQuest>> getQuestsForDate(String dateKey);
  Future<void> saveQuest(DailyQuest quest);
  Future<void> updateQuest(DailyQuest quest);
  Future<void> deleteQuest(String questId);
  Stream<QuestUpdate> watchQuest(String questId);
}

class HiveQuestRepository implements QuestRepository { ... }
class FirebaseQuestRepository implements QuestRepository { ... }
class CompositeQuestRepository implements QuestRepository {
  final HiveQuestRepository _local;
  final FirebaseQuestRepository _remote;

  @override
  Future<List<DailyQuest>> getQuestsForDate(String dateKey) async {
    // Try local first
    final local = await _local.getQuestsForDate(dateKey);
    if (local.isNotEmpty) return local;

    // Fallback to remote
    final remote = await _remote.getQuestsForDate(dateKey);
    // Cache locally
    for (final quest in remote) {
      await _local.saveQuest(quest);
    }
    return remote;
  }
}
```

### 10. Add Telemetry and Monitoring

**Suggestion**: Track quest system health and usage

**Benefits**:
- Identify common issues
- Monitor sync success rate
- Understand user behavior

**Proposed Metrics**:
```dart
class QuestTelemetry {
  static void trackQuestGeneration({
    required String coupleId,
    required int questCount,
    required Duration duration,
  }) { ... }

  static void trackQuestCompletion({
    required String questId,
    required String userId,
    required bool isBothCompleted,
  }) { ... }

  static void trackSyncFailure({
    required String operation,
    required String error,
  }) { ... }

  static void trackValidationError({
    required List<String> errors,
  }) { ... }
}

// Usage
final start = DateTime.now();
final quests = await generateDailyQuests(...);
QuestTelemetry.trackQuestGeneration(
  coupleId: coupleId,
  questCount: quests.length,
  duration: DateTime.now().difference(start),
);
```

---

## Conclusion

The Daily Quest System is a complex, multi-layered feature that coordinates:
- Local storage (Hive)
- Remote synchronization (Firebase RTDB)
- Real-time updates (Firebase listeners)
- Dual-user completion tracking
- Progression systems
- Love Points integration

### Key Takeaways

1. **"First Creates, Second Loads"** is critical for quest ID consistency
2. **Quest IDs must be preserved** when loading from Firebase
3. **Full app restart required** for testing (hot reload not supported)
4. **Always check Firebase first** to avoid generation races
5. **Separate typed and untyped Hive boxes** for metadata storage
6. **Use Firebase fallback** for session loading

### Recommended Next Steps

1. **Implement Quest Validation Layer** (Quick win, high impact)
2. **Add Retry Logic** (Improves reliability)
3. **Consolidate Generation Logic** (Reduces complexity)
4. **Explore Hot Reload Support** (Developer experience)
5. **Add Telemetry** (Visibility into issues)

---

**Last Updated**: 2025-11-14
**Author**: Technical Documentation
**Version**: 1.0.0

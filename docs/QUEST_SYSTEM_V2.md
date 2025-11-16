# Daily Quest & Quiz System - Complete Technical Documentation (V2)

**Last Updated:** 2025-11-16
**Version:** 2.0.1
**Status:** Production-Ready

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Architecture](#2-architecture)
3. [Quest Types & Formats](#3-quest-types--formats)
4. [Data Models](#4-data-models)
5. [Core Services](#5-core-services)
6. [Quest Generation Flow](#6-quest-generation-flow)
7. [Quiz System](#7-quiz-system)
8. [Synchronization & Real-Time Updates](#8-synchronization--real-time-updates)
9. [Completion & LP Awards](#9-completion--lp-awards)
10. [Critical Design Patterns](#10-critical-design-patterns)
11. [Firebase RTDB Structure](#11-firebase-rtdb-structure)
12. [Testing & Debugging](#12-testing--debugging)
13. [Known Issues & Solutions](#13-known-issues--solutions)
14. [Migration & Compatibility](#14-migration--compatibility)

---

## 1. System Overview

### Purpose

The Daily Quest System provides couples with 3 shared daily activities designed to strengthen their relationship through:
- **Knowledge quizzes** (classic multiple-choice)
- **Self-assessment quizzes** (affirmation with 5-point scales)
- **Future: Games** (word ladder, memory flip, etc.)

### Key Features

- **3 Daily Quests**: Generated once per day, shared between both partners
- **Multiple Quiz Formats**: Classic quizzes, affirmation quizzes, speed rounds
- **Dual Completion Required**: Both partners must complete each quest
- **Real-Time Sync**: Partner completions sync via Firebase RTDB
- **Love Points Rewards**: 30 LP awarded per quest when both complete
- **Progression System**: Quiz questions follow track-based progression
- **Quest Expiration**: Quests expire at midnight (23:59:59)
- **30-Day Data Retention**: Quiz sessions stored for 30 days

### Architecture Principles

1. **"First Creates, Second Loads"** - First user generates quests, second loads from Firebase
2. **Local-First Storage** - All data cached in Hive for offline access
3. **Firebase as Sync Layer** - RTDB used only for lightweight metadata sync
4. **Denormalized Display Data** - Quest titles/metadata stored directly in quest model
5. **Provider Pattern** - Extensible quest type system via providers
6. **Format Variants** - Multiple quiz types under single `QuestType.quiz`

---

## 2. Architecture

### High-Level System Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                         │
│  (Widgets: DailyQuestsWidget, QuestCard, Quiz Screens)      │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│                      Service Layer                           │
│                                                              │
│  ┌──────────────┐  ┌─────────────────┐  ┌─────────────────┐│
│  │QuestType     │  │ DailyQuestSvc   │  │ QuestSyncSvc    ││
│  │Manager       │──▶│                 │◀─│                 ││
│  │              │  │ - Generation    │  │ - Firebase Sync ││
│  │ - Providers  │  │ - Completion    │  │ - Real-time     ││
│  │ - Orchestra- │  │ - Expiration    │  │ - Partner Watch ││
│  │   tion       │  │ - Statistics    │  │                 ││
│  └──────────────┘  └─────────────────┘  └─────────────────┘│
│                                                              │
│  ┌──────────────┐  ┌─────────────────┐  ┌─────────────────┐│
│  │QuizQuest     │  │ QuizService     │  │ LovePointSvc    ││
│  │Provider      │  │                 │  │                 ││
│  │              │  │ - Classic Quiz  │  │ - Award LP      ││
│  │ - Generate   │  │ - Affirmation   │  │ - Firebase Sync ││
│  │ - Track Prog │  │ - Speed Round   │  │ - Deduplication ││
│  └──────────────┘  └─────────────────┘  └─────────────────┘│
│                                                              │
│  ┌──────────────┐  ┌─────────────────┐                     │
│  │Quest         │  │ Activity        │                     │
│  │Utilities     │  │ Service         │                     │
│  │              │  │                 │                     │
│  │ - DateKeys   │  │ - Inbox Feed    │                     │
│  │ - CoupleID   │  │ - Quest Titles  │                     │
│  └──────────────┘  └─────────────────┘                     │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│                      Storage Layer                           │
│                                                              │
│  ┌──────────────┐  ┌─────────────────┐                     │
│  │ Hive (Local) │  │ Firebase RTDB    │                     │
│  │              │  │                  │                     │
│  │ - Quests     │  │ - /daily_quests/ │                     │
│  │ - Sessions   │  │ - /quiz_progres- │                     │
│  │ - Completion │  │    sion/         │                     │
│  │ - Progression│  │ - /lp_awards/    │                     │
│  │ - LP Trans   │  │ - /quiz_sessions/│                     │
│  └──────────────┘  └─────────────────┘                     │
└─────────────────────────────────────────────────────────────┘
```

### Service Dependencies

```
┌──────────────────────────────────────────────────────────┐
│                   Dependency Graph                        │
│                                                           │
│  QuestTypeManager                                         │
│       │                                                   │
│       ├─▶ QuizQuestProvider                              │
│       │       └─▶ QuizService                            │
│       │               └─▶ AffirmationQuizBank            │
│       │                                                   │
│       └─▶ DailyQuestService ──▶ QuestSyncService         │
│                   │                    │                  │
│                   └────────────────────┴─▶ StorageService│
│                                                           │
│  LovePointService ◀─── QuizService                       │
│       │                                                   │
│       └─▶ ForegroundNotificationBanner                   │
│                                                           │
│  QuestUtilities (static utility class)                   │
│       └─▶ Used by all services for date/couple ID        │
└──────────────────────────────────────────────────────────┘
```

**Key Improvement (2025-11-14):** Removed circular dependency between `DailyQuestService` and `QuestSyncService`. Now `QuestSyncService` uses `StorageService` directly.

---

## 3. Quest Types & Formats

### Quest Type Hierarchy

```
QuestType (Enum)
├─ quiz          // Knowledge-based quizzes
│  ├─ Format: 'classic'        // Multiple choice, match answers
│  ├─ Format: 'affirmation'    // 5-point scale, self-assessment
│  └─ Format: 'speed_round'    // Timed quiz with streak bonuses
│
├─ word_ladder   // Collaborative word transformation
├─ memory_flip   // Daily memory card matching
└─ (future types...)
```

### Quiz Formats Comparison

| Aspect | Classic Quiz | Affirmation Quiz | Speed Round |
|--------|-------------|------------------|-------------|
| **Format Type** | `'classic'` | `'affirmation'` | `'speed_round'` |
| **Answer Type** | Multiple choice (4 options) | 5-point Likert scale | Multiple choice (4 options) |
| **Answer Storage** | `[0, 2, 1, 3]` (option indices) | `[3, 4, 2, 5, 1]` (scale values 1-5) | `[0, 2, 1, 3]` (option indices) |
| **Question Count** | 5 questions | 5 questions | 10 questions |
| **Scoring** | Match percentage (compare partners) | Individual score (self-assessment) | Match % + time bonus |
| **UI Widget** | Option buttons | Heart-based scale widget | Option buttons + timer |
| **LP Reward** | 30 LP (both complete) | 30 LP (both complete) | 30 LP base + streak bonus |
| **Unlock Requirement** | Always available | Always available (50% daily distribution) | After 5 classic quizzes |
| **Question Bank** | 180 questions, 5 categories | 30 questions, 6 themed quizzes | Same as classic |

### Daily Quest Distribution

**Standard Pattern (3 quests per day):**
- Position 0 (sortOrder=0): 50% Affirmation, 50% Classic
- Position 1 (sortOrder=1): 50% Affirmation, 50% Classic
- Position 2 (sortOrder=2): Always Classic

**Result:** Users see 1-2 affirmation quizzes per day, ensuring daily self-reflection opportunities.

---

## 4. Data Models

### DailyQuest Model

**File:** `lib/models/daily_quest.dart`
**Hive TypeId:** 17

```dart
@HiveType(typeId: 17)
class DailyQuest extends HiveObject {
  @HiveField(0)
  String id;                    // "quest_{timestamp}_{type}"

  @HiveField(1)
  String dateKey;               // "YYYY-MM-DD"

  @HiveField(2)
  int questType;                // QuestType enum index

  @HiveField(3)
  String contentId;             // Quiz session ID, game ID, etc.

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime expiresAt;           // End of day (23:59:59)

  @HiveField(6)
  String status;                // 'pending', 'in_progress', 'completed'

  @HiveField(7)
  Map<String, bool>? userCompletions;  // {userId: true}

  @HiveField(8)
  int? lpAwarded;               // 30 LP

  @HiveField(9)
  DateTime? completedAt;

  @HiveField(10)
  bool isSideQuest;             // false for main 3 quests

  @HiveField(11)
  int sortOrder;                // 0, 1, 2 for daily quests

  @HiveField(12, defaultValue: 'classic')
  String formatType;            // 'classic', 'affirmation', 'speed_round'

  @HiveField(13)
  String? quizName;             // ✨ NEW: Quiz title for display (e.g., "Warm Vibes")

  // Key methods
  bool hasUserCompleted(String userId);
  bool areBothUsersCompleted();
  bool get isExpired;
  bool get isCompleted;
}
```

**Critical Field (Added 2025-11-15):** `quizName` enables cross-device title sync without session lookups. See [Section 10](#10-critical-design-patterns) for details.

### QuizSession Model

**File:** `lib/models/quiz.dart`
**Hive TypeId:** 13

```dart
@HiveType(typeId: 13)
class QuizSession extends HiveObject {
  @HiveField(0)
  String id;                    // Session identifier

  @HiveField(1)
  String userId;                // Creator's user ID

  @HiveField(2)
  String partnerId;             // Partner's user ID

  @HiveField(3)
  String? questId;              // Associated daily quest

  @HiveField(4)
  List<QuizQuestion> questions; // Session questions

  @HiveField(5)
  Map<String, List<int>>? answers;  // {userId: [answerIndices]}

  @HiveField(6)
  String status;                // 'in_progress', 'completed'

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  DateTime? completedAt;

  @HiveField(9)
  int? matchPercentage;         // For classic quizzes

  @HiveField(10)
  int? lpEarned;                // 30 LP

  @HiveField(11, defaultValue: 'classic')
  String? formatType;           // 'classic', 'affirmation', 'speed_round'

  @HiveField(12)
  String? quizName;             // Quiz title (e.g., "Gentle Beginnings")

  @HiveField(13)
  String? category;             // For affirmations: 'Trust', 'Emotional Support'

  // Key methods
  bool get isCompleted;
  int getAnswerCount();
}
```

### QuizQuestion Model

**File:** `lib/models/quiz_question.dart`
**Hive TypeId:** 11

```dart
@HiveType(typeId: 11)
class QuizQuestion {
  @HiveField(0)
  String id;                    // Question identifier

  @HiveField(1)
  String text;                  // Question text

  @HiveField(2)
  List<String>? options;        // For classic/speed: 4 options

  @HiveField(3)
  String? category;             // "Personal", "Preferences", etc.

  @HiveField(4)
  int? difficulty;              // 1-5

  @HiveField(5, defaultValue: 'classic')
  String questionType;          // 'classic', 'affirmation'
}
```

### QuizProgressionState Model

**File:** `lib/models/quiz.dart`
**Hive TypeId:** 19

```dart
@HiveType(typeId: 19)
class QuizProgressionState extends HiveObject {
  @HiveField(0)
  int currentTrack;             // 0-4 (Tier 1-5)

  @HiveField(1)
  int currentPosition;          // Position within track

  @HiveField(2)
  Map<String, bool> completedQuizzes;  // {questionId: true}

  @HiveField(3)
  int totalQuizzesCompleted;

  @HiveField(4)
  DateTime? lastCompletedAt;
}
```

### DailyQuestCompletion Model

**File:** `lib/models/daily_quest.dart`
**Hive TypeId:** 18

```dart
@HiveType(typeId: 18)
class DailyQuestCompletion extends HiveObject {
  @HiveField(0)
  String dateKey;               // "YYYY-MM-DD"

  @HiveField(1)
  int questsCompleted;          // 0-3

  @HiveField(2)
  bool allQuestsCompleted;      // true when 3/3

  @HiveField(3)
  DateTime completedAt;

  @HiveField(4)
  int totalLpEarned;            // 90 LP for 3 quests

  @HiveField(5)
  int sideQuestsCompleted;      // Bonus quests

  @HiveField(6)
  DateTime? lastUpdatedAt;
}
```

---

## 5. Core Services

### QuestTypeManager

**File:** `lib/services/quest_type_manager.dart`
**Purpose:** Orchestrates quest generation using provider pattern

**Key Methods:**
```dart
// Register quest type providers
void registerProvider(QuestProvider provider);

// Generate all daily quests
Future<List<DailyQuest>> generateDailyQuests({
  required String currentUserId,
  required String partnerUserId,
  required String dateKey,
});
```

**Provider Pattern:**
```dart
abstract class QuestProvider {
  QuestType get questType;

  Future<String?> generateQuest({
    required String dateKey,
    required int sortOrder,
    String? currentUserId,
    String? partnerUserId,
  });

  Future<bool> validateCompletion({
    required String contentId,
    required String userId,
  });
}
```

### QuizQuestProvider

**File:** `lib/services/quest_type_manager.dart`
**Purpose:** Generate quiz-based quests (all formats)

**Track Configuration:**
```dart
class TrackConfig {
  final String? categoryFilter;  // For classic quizzes
  final int? difficulty;         // 1-5
  final String formatType;       // 'classic', 'affirmation', 'speed_round'
  final int questionsPerQuiz;    // 5 for classic/affirmation, 10 for speed
}
```

**Daily Quest Generation Logic:**
```dart
Future<String?> generateQuest({...}) async {
  // Determine format type based on sortOrder
  String formatType = 'classic';  // default

  if (sortOrder == 0 || sortOrder == 1) {
    // 50% chance of affirmation for positions 0 and 1
    formatType = Random().nextBool() ? 'affirmation' : 'classic';
  }

  // Create quiz session via QuizService
  final session = await _quizService.startQuizSession(
    userId: currentUserId,
    partnerId: partnerUserId,
    formatType: formatType,
    difficulty: difficulty,
  );

  // Extract metadata for quest
  final quizName = session.quizName;  // ✨ Extract for denormalization
  final contentId = session.id;

  return contentId;  // Used as DailyQuest.contentId
}
```

### QuizService

**File:** `lib/services/quiz_service.dart`
**Purpose:** Quiz session management and Firebase sync

**Key Methods:**
```dart
// Start new quiz session
Future<QuizSession> startQuizSession({
  required String userId,
  required String partnerId,
  String formatType = 'classic',
  int difficulty = 1,
});

// Submit user answers
Future<void> submitAnswers(
  String sessionId,
  String userId,
  List<int> answers,
);

// Get session (checks Firebase fallback)
Future<QuizSession?> getSession(String sessionId);

// Background listener for partner sessions
Future<void> startListeningForPartnerSessions();

// Sync session to Firebase RTDB
Future<void> _syncSessionToRTDB(QuizSession session);

// Calculate completion when both answered
Future<void> _calculateAndCompleteSession(QuizSession session);
```

**Format-Specific Logic:**
```dart
Future<QuizSession> startQuizSession({...}) async {
  if (formatType == 'affirmation') {
    // Load from AffirmationQuizBank
    return await _createAffirmationSession(userId, partnerId);
  } else if (formatType == 'speed_round') {
    // Load 10 questions with timer
    return await _createSpeedRoundSession(userId, partnerId, difficulty);
  } else {
    // Classic quiz: 5 questions
    return await _createClassicSession(userId, partnerId, difficulty);
  }
}
```

### AffirmationQuizBank

**File:** `lib/services/affirmation_quiz_bank.dart`
**Purpose:** Load affirmation quiz questions from JSON

**Structure:**
```dart
class AffirmationQuizBank {
  // Load 6 themed quizzes from JSON
  static Future<void> loadQuizzes() async;

  // Get specific quiz by name
  static AffirmationQuiz? getQuizByName(String name);

  // Get next quiz in progression
  static AffirmationQuiz? getNextQuizInCategory(String category, int position);
}
```

**Quiz Bank Data (`assets/data/affirmation_quizzes.json`):**
- **Trust Category:** 3 quizzes (Gentle Beginnings, Warm Vibes, Deep Trust)
- **Emotional Support Category:** 3 quizzes (First Steps, Caring Moments, Strong Bond)
- **Total:** 30 questions across 6 themed quizzes

### DailyQuestService

**File:** `lib/services/daily_quest_service.dart`
**Purpose:** Quest completion tracking and LP award coordination

**Key Methods:**
```dart
// Get today's quests
List<DailyQuest> getTodayQuests();

// Complete quest for one user
Future<void> completeQuestForUser({
  required String questId,
  required String userId,
  required String partnerUserId,
});

// Check if all main quests completed
bool areAllMainQuestsCompleted(String userId, String partnerUserId);

// Get current completion streak
int getCurrentStreak();

// Clean up old quests (>7 days)
Future<void> cleanupExpiredQuests();
```

### QuestSyncService

**File:** `lib/services/quest_sync_service.dart`
**Purpose:** Firebase RTDB synchronization

**Key Methods:**
```dart
// Main sync check (first creates, second loads pattern)
Future<void> syncTodayQuests({
  required String currentUserId,
  required String partnerUserId,
});

// Upload quests to Firebase
Future<void> saveQuestsToFirebase({
  required List<DailyQuest> quests,
  required String currentUserId,
  required String partnerUserId,
});

// Real-time partner completion listener
Stream<Map<String, bool>> listenForPartnerCompletions({
  required String currentUserId,
  required String partnerUserId,
});

// Mark quest completed in Firebase
Future<void> markQuestCompleted({
  required String questId,
  required String userId,
  required String partnerUserId,
});

// Clean up old Firebase data (>7 days)
Future<void> cleanupOldQuests();
```

### QuestUtilities

**File:** `lib/services/quest_utilities.dart`
**Purpose:** Centralized utility methods (added 2025-11-14)

**Methods:**
```dart
class QuestUtilities {
  // Get today's date key (YYYY-MM-DD format)
  static String getTodayDateKey();

  // Get date key for specific date
  static String getDateKey(DateTime date);

  // Generate deterministic couple ID (sorted alphabetically)
  static String generateCoupleId(String userId1, String userId2);
}
```

**Why This Matters:** Eliminates duplicate utility code across services, ensures consistent couple ID generation (critical for sync).

### LovePointService

**File:** `lib/services/love_point_service.dart`
**Purpose:** Award and track Love Points

**Key Method:**
```dart
static Future<void> awardPointsToBothUsers({
  required String userId1,
  required String userId2,
  required int amount,
  required String reason,
  String? relatedId,
}) async {
  // Award to user 1 locally
  await awardPoints(userId1, amount, reason, relatedId);

  // Award to user 2 via Firebase
  await _awardToPartnerViaFirebase(userId2, amount, reason, relatedId);

  // Show foreground notification banner
  if (_appContext != null && _appContext!.mounted) {
    ForegroundNotificationBanner.show(
      _appContext!,
      title: 'Love Points Earned!',
      message: '+$amount LP',
      emoji: '💰',
    );
  }
}
```

**Deduplication:** Uses `app_metadata` Hive box to track applied awards by ID.

### ActivityService

**File:** `lib/services/activity_service.dart`
**Purpose:** Generate inbox activity feed

**Quest Title Logic (Fixed 2025-11-15):**
```dart
String _getQuestTitle(DailyQuest quest) {
  switch (quest.questType) {
    case 1: // QuestType.quiz
      // ✅ Use denormalized quizName from quest
      if (quest.formatType == 'affirmation') {
        return quest.quizName ?? 'Affirmation Quiz';
      }

      // Classic quiz titles based on sortOrder
      const titles = [
        'Getting to Know You',
        'Deeper Connection',
        'Understanding Each Other'
      ];
      return titles[quest.sortOrder];

    default:
      return 'Quest';
  }
}
```

---

## 6. Quest Generation Flow

### Complete Initialization Sequence

```
App Launch (main.dart)
│
├─▶ Initialize Services
│   ├─ Firebase.initializeApp()
│   ├─ StorageService.init()                    # Open Hive boxes
│   ├─ NotificationService.initialize()
│   ├─ QuizService().startListeningForPartnerSessions()  # Background listener
│   └─ MockDataService.injectMockDataIfNeeded()
│
├─▶ Home Screen Initialization
│   └─▶ DailyQuestsWidget.initState()
│       └─▶ QuestSyncService.syncTodayQuests()
│
└─▶ Quest Sync Check
    │
    ├─▶ Check Firebase: /daily_quests/{coupleId}/{dateKey}
    │
    ├─ [EXISTS] ✅ Second User (Bob)
    │   │
    │   ├─▶ Load Quests from Firebase
    │   │   ├─ Preserve original quest IDs
    │   │   ├─ Load formatType, quizName ✨
    │   │   └─ Load completion status
    │   │
    │   └─▶ Save to Local Hive
    │       └─ Bob now has quests with SAME IDs as Alice
    │
    └─ [DOES NOT EXIST] ✅ First User (Alice)
        │
        └─▶ Generate New Quests
            │
            ├─▶ Load/Create Progression State
            │   ├─ Check Firebase: /quiz_progression/{coupleId}
            │   └─ Create new if first time
            │
            ├─▶ Generate 3 Quests (via QuestTypeManager)
            │   │
            │   └─▶ For each quest (sortOrder 0, 1, 2):
            │       │
            │       ├─▶ QuizQuestProvider.generateQuest()
            │       │   │
            │       │   ├─ Determine format type
            │       │   │  ├─ sortOrder 0/1: 50% affirmation
            │       │   │  └─ sortOrder 2: always classic
            │       │   │
            │       │   ├─▶ QuizService.startQuizSession()
            │       │   │   ├─ Load questions
            │       │   │   ├─ Create QuizSession
            │       │   │   ├─ Sync session to Firebase
            │       │   │   └─ Return session ID
            │       │   │
            │       │   ├─ Extract metadata
            │       │   │  ├─ formatType: session.formatType
            │       │   │  └─ quizName: session.quizName ✨
            │       │   │
            │       │   └─▶ Create DailyQuest
            │       │       ├─ id: quest_{timestamp}_{type}
            │       │       ├─ contentId: session.id
            │       │       ├─ formatType: 'affirmation' or 'classic'
            │       │       ├─ quizName: "Gentle Beginnings" ✨
            │       │       └─ sortOrder: 0, 1, or 2
            │       │
            │       └─ Advance progression position
            │
            ├─▶ Save Quests to Local Hive
            │
            └─▶ Save to Firebase (QuestSyncService)
                ├─ Quest metadata (id, type, contentId, sortOrder)
                ├─ formatType, quizName ✨
                ├─ Generation metadata (generatedBy, timestamp)
                └─ Progression state
```

### Quest ID Generation

**Critical:** Quest IDs must be deterministic and preserved across devices.

```dart
// Generation pattern
final timestamp = DateTime.now().millisecondsSinceEpoch;
final questId = 'quest_${timestamp}_${questType.name}';

// Example: "quest_1763093637734_quiz"
```

**Importance:** Second device MUST load these IDs from Firebase, not generate new ones.

---

## 7. Quiz System

### Quiz Lifecycle

```
User Taps Quest Card
│
├─▶ Check format type (quest.formatType)
│
├─ [Classic] → QuizIntroScreen
│   │
│   └─▶ User Taps "Start Quiz"
│       │
│       └─▶ QuizScreen (5 questions)
│           ├─ Multiple choice options
│           ├─ User selects answers
│           └─▶ User Taps "Submit"
│               │
│               └─▶ QuizService.submitAnswers()
│                   ├─ Save answers to session
│                   ├─ Sync to Firebase
│                   ├─ Check if both answered
│                   │  ├─ [YES] → Calculate match %
│                   │  │          Award 30 LP
│                   │  │          Navigate to results
│                   │  └─ [NO]  → Navigate to waiting screen
│                   └─ Mark quest completed
│
└─ [Affirmation] → AffirmationIntroScreen
    │
    └─▶ User Taps "Start Self-Assessment"
        │
        └─▶ AffirmationQuestionScreen (5 questions)
            ├─ 5-point Likert scale (heart icons)
            ├─ User selects ratings (1-5)
            └─▶ User Taps "Submit"
                │
                └─▶ QuizService.submitAnswers()
                    ├─ Calculate individual score
                    ├─ Save answers to session
                    ├─ Sync to Firebase
                    ├─ Check if both answered
                    │  ├─ [YES] → Award 30 LP
                    │  │          Show partner scores
                    │  └─ [NO]  → Navigate to waiting screen
                    └─ Navigate to results
```

### Quiz Completion Detection

**Critical Pattern:** Waiting screen MUST poll Firebase, not just local storage.

```dart
// ❌ WRONG (old code)
final session = _storage.getQuizSession(sessionId);

// ✅ CORRECT (current code)
final session = await _quizService.getSession(sessionId);
// ^ This checks partner's Firebase path
```

**Why This Works:**
1. `getSession()` tries local storage first (fast)
2. Falls back to own Firebase path
3. Falls back to partner's Firebase path
4. Automatically caches to local storage

### Quiz Synchronization Mechanisms

**1. Background Listener (Push Updates)**

Setup in `main.dart`:
```dart
await QuizService().startListeningForPartnerSessions();
```

Implementation:
```dart
Future<void> startListeningForPartnerSessions() async {
  final partnerEmulatorId = await _getPartnerEmulatorId();

  final ref = _database
      .child('quiz_sessions')
      .child(partnerEmulatorId);

  // Listen for new sessions
  ref.onChildAdded.listen((event) {
    final session = QuizSession.fromMap(event.snapshot.value);
    _storage.saveQuizSession(session);
  });

  // Listen for updates
  ref.onChildChanged.listen((event) {
    final session = QuizSession.fromMap(event.snapshot.value);
    _storage.saveQuizSession(session);
  });
}
```

**2. Active Polling (Pull Updates)**

Waiting screen polls every 3 seconds:
```dart
void _startPolling() {
  _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
    _checkSessionStatus();
  });
}

Future<void> _checkSessionStatus() async {
  final updatedSession = await _quizService.getSession(_session.id);

  if (updatedSession == null) return;

  setState(() {
    _session = updatedSession;
  });

  if (_session.isCompleted) {
    _pollTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => QuizResultsScreen(session: _session),
      ),
    );
  }
}
```

**3. Firebase Sync on Write**

Every session modification syncs to Firebase:
```dart
Future<void> _syncSessionToRTDB(QuizSession session) async {
  final emulatorId = await DevConfig.emulatorId;
  final sessionRef = _database
      .child('quiz_sessions')
      .child(emulatorId)
      .child(session.id);

  await sessionRef.set({
    'id': session.id,
    'userId': session.userId,
    'partnerId': session.partnerId,
    'formatType': session.formatType,
    'quizName': session.quizName,
    'questions': session.questions.map((q) => q.toMap()).toList(),
    'answers': session.answers,
    'status': session.status,
    'isCompleted': session.isCompleted,
    'lpEarned': session.lpEarned,
    'matchPercentage': session.matchPercentage,
    'completedAt': session.completedAt?.millisecondsSinceEpoch,
    'createdAt': session.createdAt.millisecondsSinceEpoch,
  });
}
```

---

## 8. Synchronization & Real-Time Updates

### First Creates, Second Loads Pattern

```
┌──────────────────┐                    ┌──────────────────┐
│   Alice (First)  │                    │   Bob (Second)   │
└────────┬─────────┘                    └────────┬─────────┘
         │                                       │
         ├─▶ Check Firebase                      ├─▶ Check Firebase
         │   (No quests exist)                   │   (Quests exist!)
         │                                       │
         ├─▶ Generate quests                     ├─▶ Load quests
         │   ├─ quest_1763093637734_quiz        │   ├─ quest_1763093637734_quiz ✓
         │   ├─ quest_1763093637735_quiz        │   ├─ quest_1763093637735_quiz ✓
         │   └─ quest_1763093637736_quiz        │   └─ quest_1763093637736_quiz ✓
         │   ├─ formatType: 'affirmation' ✨     │   ├─ formatType: 'affirmation' ✓
         │   └─ quizName: 'Gentle Beginnings' ✨ │   └─ quizName: 'Gentle Beginnings' ✓
         │                                       │
         ├─▶ Save to Firebase                    ├─▶ Save to Local Hive
         │   /daily_quests/{coupleId}/...       │   (Same IDs + metadata!)
         │                                       │
         ├─▶ Save to Local Hive                  │
         │                                       │
         ▼                                       ▼
    [Both have identical quest data]
```

### Real-Time Partner Completion

**Widget Subscription:**
```dart
_partnerCompletionSubscription = _questSyncService
  .listenForPartnerCompletions(
    currentUserId: user.id,
    partnerUserId: partner.pushToken,
  )
  .listen((partnerCompletions) {
    // Update local storage
    for (final entry in partnerCompletions.entries) {
      final questId = entry.key;
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

**Firebase Path:**
```
/daily_quests/{coupleId}/{dateKey}/completions/{questId}/{userId} = true
```

---

## 9. Completion & LP Awards

### Quest Completion Flow

```
User Completes Quest (e.g., Quiz)
│
├─▶ QuizService.submitAnswers()
│   ├─ Save answers to session
│   ├─ Calculate score (if both answered)
│   └─ Sync to Firebase
│
├─▶ DailyQuestService.completeQuestForUser()
│   │
│   ├─ Update userCompletions[userId] = true
│   │
│   ├─ Check if both users completed
│   │  │
│   │  ├─ [BOTH COMPLETED]
│   │  │  ├─ Set status = 'completed'
│   │  │  ├─ Set completedAt = now
│   │  │  └─ (LP award handled by QuizService)
│   │  │
│   │  └─ [ONE COMPLETED]
│   │     └─ Set status = 'in_progress'
│   │
│   └─ Save to local Hive
│
└─▶ QuestSyncService.markQuestCompleted()
    └─ Save to Firebase completion path
```

### Love Points Award Flow

**For Quiz Quests:**
```dart
// In QuizService._calculateAndCompleteSession()
if (session.answers != null && session.answers!.length >= 2) {
  const int lpEarned = 30;

  // Award to BOTH users
  await LovePointService.awardPointsToBothUsers(
    userId1: session.userId,
    userId2: session.partnerId,
    amount: lpEarned,
    reason: 'quiz_completion',
    relatedId: session.id,
  );

  session.lpEarned = lpEarned;
  session.status = 'completed';
  await session.save();
}
```

**LP Award Deduplication:**

Uses `app_metadata` Hive box to track applied awards:
```dart
// Check if award already applied
final appliedAwards = _storage.getAppliedLPAwards();
if (appliedAwards.contains(awardId)) {
  return; // Skip duplicate
}

// Apply award
await _storage.markLPAwardAsApplied(awardId);
```

**Foreground Notification (Added 2025-11-14):**

When LP is awarded, a notification banner appears:
```dart
if (_appContext != null && _appContext!.mounted) {
  ForegroundNotificationBanner.show(
    _appContext!,
    title: 'Love Points Earned!',
    message: '+$amount LP',
    emoji: '💰',
  );
}
```

**Design Decision:** LP counter in header does NOT auto-update. The notification banner provides immediate feedback, and the counter updates on next screen rebuild.

---

## 10. Critical Design Patterns

### Pattern 1: Quest Title Denormalization (2025-11-15)

**Problem:** UI components looked up quiz sessions to get titles. Bob didn't have sessions → wrong titles.

**Solution:** Store `quizName` directly in `DailyQuest` model, sync via Firebase.

```dart
// ❌ WRONG: Session lookup fails on partner's device
final session = StorageService().getQuizSession(quest.contentId);
if (session != null && session.formatType == 'affirmation') {
  return session.quizName!; // Only works for Alice!
}

// ✅ CORRECT: Use denormalized metadata
if (quest.formatType == 'affirmation') {
  return quest.quizName ?? 'Affirmation Quiz';
}
```

**Affected Components:**
- `lib/widgets/quest_card.dart` - Main screen quest titles
- `lib/services/activity_service.dart` - Inbox quest titles
- `lib/widgets/daily_quests_widget.dart` - Format type detection

**Data Flow:**
1. Alice: QuizSession created → `formatType`, `quizName` extracted
2. Alice: DailyQuest created with metadata from session
3. Alice: Quest synced to Firebase with `formatType`, `quizName`
4. Bob: Quest loaded from Firebase with all metadata intact
5. Bob: UI uses `quest.formatType` and `quest.quizName` directly

**Lesson:** **Denormalize display metadata to avoid cross-device lookups.**

### Pattern 2: First Creates, Second Loads

**Rule:** First user to launch app generates quests. Second loads from Firebase.

**Implementation:**
```dart
Future<void> syncTodayQuests() async {
  final coupleId = QuestUtilities.generateCoupleId(userId1, userId2);
  final dateKey = QuestUtilities.getTodayDateKey();

  final snapshot = await _database
      .child('daily_quests')
      .child(coupleId)
      .child(dateKey)
      .once();

  if (snapshot.snapshot.value != null) {
    // Quests exist → Load from Firebase
    await _loadQuestsFromFirebase(snapshot.snapshot, dateKey);
  } else {
    // No quests → Generate new ones
    final quests = await _questTypeManager.generateDailyQuests(...);
    await saveQuestsToFirebase(quests, userId1, userId2);
  }
}
```

**Critical:** Preserve quest IDs when loading from Firebase!

### Pattern 3: Fallback to Firebase

**Rule:** When data not found locally, check Firebase before failing.

```dart
Future<QuizSession?> getSession(String sessionId) async {
  // 1. Try local storage first (fast)
  var session = _storage.getQuizSession(sessionId);
  if (session != null) return session;

  // 2. Try own Firebase path
  final myEmulatorId = await DevConfig.emulatorId;
  session = await _loadSessionFromFirebase(sessionId, myEmulatorId);
  if (session != null) {
    _storage.saveQuizSession(session); // Cache locally
    return session;
  }

  // 3. Try partner's Firebase path
  final partnerEmulatorId = await _getPartnerEmulatorId();
  session = await _loadSessionFromFirebase(sessionId, partnerEmulatorId);
  if (session != null) {
    _storage.saveQuizSession(session); // Cache locally
    return session;
  }

  return null;
}
```

### Pattern 4: Centralized Utilities (2025-11-14)

**Rule:** Use `QuestUtilities` for all date/couple ID operations.

```dart
// ✅ CORRECT
final dateKey = QuestUtilities.getTodayDateKey();
final coupleId = QuestUtilities.generateCoupleId(userId1, userId2);

// ❌ WRONG (old code - causes sync issues)
final dateKey = '${now.year}-${now.month}-${now.day}'; // Format inconsistency!
final coupleId = '${userId1}_${userId2}'; // Not sorted!
```

**Why This Matters:** Couple ID MUST be sorted alphabetically to ensure both partners generate the same ID.

### Pattern 5: Format Variants Over New Types

**Rule:** Add new quiz formats as `formatType` variants, not new `QuestType` values.

```dart
// ✅ CORRECT
DailyQuest(
  questType: QuestType.quiz.index,  // Reuse existing type
  formatType: 'affirmation',         // New format variant
);

// ❌ WRONG
enum QuestType {
  quiz,
  affirmation,  // Don't create new type!
  speedRound,   // Don't create new type!
}
```

**Benefits:**
- Reuse 90% of quest infrastructure
- No new providers needed
- Compatible with existing progression system
- Answer storage format compatible

---

## 11. Firebase RTDB Structure

### Complete Database Schema

```
firebase-realtime-database/
│
├── /daily_quests/
│   └── /{coupleId}/              # e.g., "alice123_bob456" (sorted!)
│       └── /{dateKey}/            # e.g., "2025-11-15"
│           ├── quests: [          # Quest definitions
│           │   {
│           │     id: "quest_1763093637734_quiz",
│           │     questType: 1,                    # QuestType.quiz.index
│           │     contentId: "session_abc123",
│           │     sortOrder: 0,
│           │     isSideQuest: false,
│           │     formatType: "affirmation",       # ✨ Format variant
│           │     quizName: "Gentle Beginnings"    # ✨ Denormalized title
│           │   }
│           │ ]
│           ├── generatedBy: "alice123"
│           ├── generatedAt: 1731657600000
│           ├── completions/       # User completion flags
│           │   └── /quest_1763093637734_quiz/
│           │       ├── alice123: true
│           │       └── bob456: true
│           └── progression/        # Quiz progression state
│               ├── currentTrack: 0
│               ├── currentPosition: 5
│               └── totalCompleted: 12
│
├── /quiz_sessions/
│   ├── /emulator-5554/           # Alice's device path
│   │   └── /{sessionId}/          # e.g., "session_abc123"
│   │       ├── id: "session_abc123"
│   │       ├── userId: "alice123"
│   │       ├── partnerId: "bob456"
│   │       ├── questId: "quest_1763093637734_quiz"
│   │       ├── formatType: "affirmation"         # ✨ Quiz format
│   │       ├── quizName: "Gentle Beginnings"     # ✨ Quiz title
│   │       ├── category: "Trust"                 # For affirmations
│   │       ├── questions: [...]
│   │       ├── answers: {
│   │       │   "alice123": [3, 4, 2, 5, 1],      # 5-point scale values
│   │       │   "bob456": [3, 5, 3, 4, 2]
│   │       │ }
│   │       ├── status: "completed"
│   │       ├── isCompleted: true
│   │       ├── lpEarned: 30
│   │       ├── matchPercentage: 60  # For classic quizzes
│   │       ├── completedAt: 1731658800000
│   │       └── createdAt: 1731657600000
│   │
│   └── /web-bob/                 # Bob's device path
│       └── /{sessionId}/          # Same structure as above
│
├── /quiz_progression/
│   └── /{coupleId}/
│       ├── currentTrack: 0
│       ├── currentPosition: 5
│       ├── completedQuizzes: {
│       │   "question_001": true,
│       │   "question_002": true
│       │ }
│       └── totalQuizzesCompleted: 12
│
└── /lp_awards/
    └── /{coupleId}/
        └── /{awardId}/            # Unique ID per award
            ├── user1:
            │   ├── userId: "alice123"
            │   ├── amount: 30
            │   ├── reason: "quiz_completed"
            │   └── timestamp: 1731658800000
            └── user2:
                ├── userId: "bob456"
                ├── amount: 30
                ├── reason: "quiz_completed"
                └── timestamp: 1731658800000
```

### Firebase Security Rules

**File:** `database.rules.json`

```json
{
  "rules": {
    "daily_quests": {
      "$coupleId": {
        ".read": true,
        ".write": true
      }
    },
    "quiz_sessions": {
      "$emulatorId": {
        ".read": true,
        ".write": true
      }
    },
    "quiz_progression": {
      "$coupleId": {
        ".read": true,
        ".write": true
      }
    },
    "lp_awards": {
      "$coupleId": {
        ".read": true,
        ".write": true
      }
    }
  }
}
```

**Deploy:** `firebase deploy --only database`

---

## 12. Testing & Debugging

### Complete Clean Testing Procedure

Use when testing quest sync, Firebase RTDB sync, Love Point awards, or cross-device synchronization.

#### Optimized Procedure (Parallel Builds)

```bash
# 1. Kill existing Flutter processes
pkill -9 -f "flutter"

# 2. Start builds in parallel (background)
cd /Users/joakimachren/Desktop/togetherremind/app
flutter build apk --debug &
ANDROID_BUILD_PID=$!
flutter build web --debug &
WEB_BUILD_PID=$!

# 3. While builds run, do cleanup
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind

cd /Users/joakimachren/Desktop/togetherremind
firebase database:remove /daily_quests --force
firebase database:remove /quiz_sessions --force
firebase database:remove /lp_awards --force
firebase database:remove /quiz_progression --force

# 4. Wait for builds to complete
echo "⏳ Waiting for builds to complete..."
wait $ANDROID_BUILD_PID && echo "✅ Android build complete"
wait $WEB_BUILD_PID && echo "✅ Web build complete"

# 5. Launch Alice (Android) - generates fresh quests
cd /Users/joakimachren/Desktop/togetherremind/app
flutter run -d emulator-5554 &

# 6. Launch Bob (Chrome) - loads from Firebase
flutter run -d chrome &
```

**Time Savings:** ~10-15 seconds (builds run during cleanup)

### Debug Menu

**Access:** Double-tap greeting text on home screen

**Features (5-Tab Interface):**
1. **Overview Tab**
   - Device info, system health checks
   - Storage statistics

2. **Quests Tab**
   - Daily quest comparison (Firebase vs Local)
   - Validation checks
   - Visual comparison

3. **Sessions Tab**
   - Quiz/game session inspector
   - Filters by status/format

4. **LP & Sync Tab**
   - Love Point transactions
   - Firebase sync monitoring

5. **Actions Tab**
   - Clear local storage
   - Copy debug data to clipboard
   - Pull-to-refresh

**Location:** `lib/widgets/debug/debug_menu.dart`

### Testing Checklist

**Quest Generation:**
- [ ] Alice launches first → generates quests
- [ ] Bob launches second → loads Alice's quests
- [ ] Quest IDs match on both devices
- [ ] formatType syncs correctly
- [ ] quizName syncs correctly ✨

**Quest Completion:**
- [ ] Bob completes quest → Alice sees update
- [ ] Alice completes quest → Bob sees update
- [ ] Both complete → LP awarded to both
- [ ] Foreground notification shows "+30 LP"

**Quiz Formats:**
- [ ] Classic quiz: Multiple choice, match percentage
- [ ] Affirmation quiz: 5-point scale, individual scores
- [ ] Speed round: Timer, streak bonuses (if unlocked)

**Cross-Device Sync:**
- [ ] Quest titles match on both devices ✨
- [ ] Inbox shows correct quest names ✨
- [ ] Partner completion detected within 3 seconds
- [ ] LP awards sync to both devices

---

## 13. Known Issues & Solutions

### Issue 1: Quest Title Mismatch (RESOLVED 2025-11-15)

**Symptoms:**
- Bob shows "Deeper Connection" for affirmation quiz
- Alice shows "Gentle Beginnings" (correct)

**Root Cause:** UI looked up quiz sessions from local storage. Bob didn't have sessions.

**Solution:** Added `quizName` field to `DailyQuest` model, synced via Firebase.

**Status:** ✅ Resolved

### Issue 2: Hot Reload Not Supported

**Problem:** Quest state changes don't reflect with hot reload

**Root Cause:**
- Hive storage initialization
- Firebase listeners not re-subscribing
- Service singleton instances retaining old state

**Workaround:** Full app restart required

**Status:** Documented limitation

### Issue 3: Quest ID Mismatch (RESOLVED 2025-11-14)

**Symptoms:**
- Partner completions don't sync
- Quests appear different on each device

**Root Cause:** Both devices generating quests independently

**Solution:** "First creates, second loads" pattern with ID preservation

**Status:** ✅ Resolved

### Issue 4: Waiting Screen Stuck (RESOLVED 2025-11-13)

**Symptoms:**
- Both users submitted answers
- One user sees results, other stuck on waiting screen

**Root Cause:** Waiting screen polled local storage only, not Firebase

**Solution:** Changed to use `getSession()` which checks Firebase

**Status:** ✅ Resolved

### Issue 5: Circular Dependency (RESOLVED 2025-11-14)

**Problem:** `DailyQuestService` ← → `QuestSyncService` circular dependency

**Solution:** Made `QuestSyncService` use `StorageService` directly

**Status:** ✅ Resolved

### Issue 6: You or Me Dual-Session Architecture Bugs (RESOLVED 2025-11-16)

**Context:** You or Me uses dual separate sessions (one per user) unlike quizzes which use a single shared session. This fundamental difference caused multiple related bugs.

#### Bug 6a: Waiting Screen Checking Wrong Session Architecture

**Symptoms:**
- Waiting screen stuck on "Waiting for partner to complete the game..."
- Both users had completed their respective sessions
- Love Points awarded correctly (quest completion logic was correct)
- A/B badges appeared on main screen

**Root Cause:** Waiting screen checked for both users' answers in SAME session (quiz pattern), but You or Me uses SEPARATE sessions.

```dart
// ❌ WRONG - checks single session for both users
final userAnswers = widget.session.answers?[user.id];
final partnerAnswers = widget.session.answers?[partner.pushToken];
if (userAnswers != null && partnerAnswers != null) {
  // Navigate to results
}
```

**Solution:** Fetch and check both separate sessions
```dart
// ✅ CORRECT - fetches both separate sessions
final partnerSessionId = 'youorme_${partner.pushToken}_$timestamp';
final partnerSession = await _service.getSession(partnerSessionId, forceRefresh: true);

final userCompleted = userAnswers != null && userAnswers.length >= widget.session.questions.length;
final partnerCompleted = partnerAnswers != null && partnerAnswers.length >= (partnerSession?.questions.length ?? 0);
```

**Files Fixed:** `lib/screens/you_or_me_waiting_screen.dart:56-88`

**Status:** ✅ Resolved

#### Bug 6b: Quest Matching by Exact Session ID

**Symptoms:**
- Quest matching failed for partner's session
- Couldn't find associated daily quest to mark complete
- Love Points not awarded or duplicated

**Root Cause:** Each user has different session ID (`youorme_alice_1234` vs `youorme_bob_1234`), exact match fails.

**Solution:** Match by timestamp extraction (sessions share same timestamp)
```dart
// ✅ CORRECT - match by timestamp
final sessionParts = widget.session.id.split('_');
final sessionTimestamp = sessionParts.length >= 3 ? sessionParts.last : '';

final matchingQuest = todayQuests.where((q) {
  if (q.type != QuestType.youOrMe) return false;
  final questIdParts = q.contentId.split('_');
  if (questIdParts.length < 3) return false;
  return questIdParts.last == sessionTimestamp;  // Match by timestamp
}).firstOrNull;
```

**Files Fixed:** `lib/screens/you_or_me_waiting_screen.dart:102-118`

**Status:** ✅ Resolved

#### Bug 6c: Results Screen Not Fetching Partner Session

**Symptoms:**
- Results screen couldn't calculate agreement percentage
- Couldn't display partner's answers
- Missing comparison data

**Root Cause:** Results screen only used current user's session, didn't fetch partner's separate session.

**Solution:** Created new service method accepting both sessions
```dart
// ✅ CORRECT - fetches partner session and compares both
final partnerSessionId = 'youorme_${partner.pushToken}_$timestamp';
final partnerSession = await _service.getSession(partnerSessionId, forceRefresh: true);

final results = _service.calculateResultsFromDualSessions(
  widget.session,    // Current user's session
  partnerSession,    // Partner's session
);
```

**Files Fixed:**
- `lib/screens/you_or_me_results_screen.dart:40-88`
- `lib/services/you_or_me_service.dart:180-245` (new method)

**Status:** ✅ Resolved

#### Bug 6d: Service Method Signature Mismatch

**Symptoms:**
- Compilation error: "Too many positional arguments: 1 allowed, but 2 found"
- Build failures on both web and Android

**Root Cause:** Original `calculateResults` method only accepted one session parameter.

**Solution:** Created new `calculateResultsFromDualSessions` method accepting both sessions
```dart
Map<String, dynamic> calculateResultsFromDualSessions(
  YouOrMeSession userSession,
  YouOrMeSession? partnerSession,
) {
  if (partnerSession == null || partnerSession.answers == null) {
    return { 'partnerCompleted': false, /* ... */ };
  }
  // Compare answers from both sessions...
}
```

**Files Fixed:**
- `lib/services/you_or_me_service.dart:180-245`
- All calls in `lib/screens/you_or_me_results_screen.dart`

**Status:** ✅ Resolved

**Key Lesson:** When implementing new quest types with different session architectures:
1. **Never assume single-session pattern** - Always check quest type before session operations
2. **Use timestamp correlation for dual sessions** - Don't rely on exact ID matching
3. **Always force refresh partner data** - Use `forceRefresh: true` when checking partner completion
4. **Create appropriate service methods** - Dual sessions need methods accepting both sessions

---

## 14. Migration & Compatibility

### Hive Field Migration

**Rule:** Always use `defaultValue` when adding fields to existing HiveTypes.

```dart
// ✅ CORRECT - prevents "type 'Null' is not a subtype" crashes
@HiveField(13, defaultValue: null)
String? quizName;

// ❌ WRONG - crashes on existing data
@HiveField(13)
late String quizName;
```

**After adding fields:**
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Version Compatibility

**Scenario:** One partner updates app, other doesn't.

**Considerations:**
- Old version doesn't send `quizName` → New version shows fallback title
- Old version ignores `quizName` field → Works normally
- New version sends `quizName` → Old version ignores it

**Result:** Graceful degradation, no crashes.

### Data Retention (30 Days)

**Implementation:** Cleanup on app startup

```dart
// main.dart
Future<void> _runPeriodicCleanup() async {
  await Future.wait([
    quizService.cleanupOldQuizSessions(),     // >30 days
    ladderService.cleanupOldLadderSessions(), // >30 days
    memoryService.cleanupOldMemoryPuzzles(),  // >30 days
    questSyncService.cleanupOldQuests(),      // >7 days (Firebase)
  ]);
}
```

---

## Conclusion

The Daily Quest & Quiz System is a sophisticated, multi-layered feature that coordinates:
- Local storage (Hive) for offline-first access
- Remote synchronization (Firebase RTDB) for cross-device sync
- Real-time updates (Firebase listeners + polling)
- Dual-user completion tracking
- Multiple quiz formats (classic, affirmation, speed round)
- Track-based progression systems
- Love Points integration with deduplication
- Denormalized display metadata for reliable UI rendering

### Key Takeaways

1. **"First Creates, Second Loads"** is critical for quest ID consistency
2. **Denormalize display metadata** to avoid cross-device lookups
3. **Quest IDs must be preserved** when loading from Firebase
4. **Use QuestUtilities** for all date/couple ID operations
5. **Full app restart required** for testing (hot reload not supported)
6. **Always check Firebase first** to avoid generation races
7. **Format variants over new types** for quiz extensibility
8. **Fallback to Firebase** when local data missing

### Architecture Improvements (2025-11-14/15)

1. ✅ **Centralized Utilities** - `QuestUtilities` for date/couple ID
2. ✅ **Removed Circular Dependencies** - `QuestSyncService` uses `StorageService`
3. ✅ **Quest Title Denormalization** - `quizName` field in `DailyQuest`
4. ✅ **Foreground LP Notifications** - Immediate user feedback
5. ✅ **Affirmation Quiz Integration** - Format variants pattern

### Related Documentation

- **[QUEST_TITLE_SYNC_ISSUE.md](./QUEST_TITLE_SYNC_ISSUE.md)** - Technical deep-dive on quest title bug
- **[AFFIRMATION_INTEGRATION_PLAN.md](./AFFIRMATION_INTEGRATION_PLAN.md)** - Affirmation quiz implementation plan
- **[QUIZ_SYNC_SYSTEM.md](./QUIZ_SYNC_SYSTEM.md)** - Quiz-specific sync mechanisms
- **[quest_system_refactoring.md](./quest_system/quest_system_refactoring.md)** - Refactoring history
- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Overall app architecture
- **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** - Common issues and debugging

---

**Version History:**

- **V2.0.0 (2025-11-15):** Unified comprehensive documentation, quest title sync fix
- **V1.0.0 (2025-11-14):** Initial consolidated documentation

**Maintainer:** Development Team
**Feedback:** Submit issues via project repository

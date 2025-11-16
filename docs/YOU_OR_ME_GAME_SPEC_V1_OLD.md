# You or Me? Game - Implementation Plan V2

**Version:** 2.0 (Quest System Integrated)
**Date:** 2025-11-15
**Status:** Implementation Ready

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture Summary](#architecture-summary)
3. [Reuse Analysis](#reuse-analysis)
4. [Phase 1: Data Models & Storage](#phase-1-data-models--storage)
5. [Phase 2: Question Bank](#phase-2-question-bank)
6. [Phase 3: Service Layer](#phase-3-service-layer)
7. [Phase 4: Quest Provider Integration](#phase-4-quest-provider-integration)
8. [Phase 5: UI Screens](#phase-5-ui-screens)
9. [Phase 6: UI Components](#phase-6-ui-components)
10. [Phase 7: Integration](#phase-7-integration)
11. [Phase 8: Testing & Polish](#phase-8-testing--polish)
12. [Complete Task Checklist](#complete-task-checklist)
13. [Timeline & Resources](#timeline--resources)

---

## Overview

### What Changed from V1

**V1 (Original Spec)**: Standalone implementation with custom infrastructure
**V2 (This Plan)**: Leverages 90% of existing quest system infrastructure

### Key Design Decisions

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| **Quest Type** | New `QuestType.youOrMe` enum value | Different game mechanic (not a quiz variant) |
| **Daily Distribution** | **FIXED**: 1 classic, 1 affirmation, 1 You or Me | Guaranteed variety, predictable daily experience |
| **LP Rewards** | 30 LP when both complete (V1 standard) | Consistency with existing quests |
| **Availability** | Both daily quest AND Activities screen | Daily engagement + on-demand play |
| **Display Data** | Denormalized in `DailyQuest.quizName` | No session lookups on partner device |
| **Provider Pattern** | `YouOrMeQuestProvider` implements `QuestProvider` | Plugs into existing generation system |
| **Storage** | Hive boxes + Firebase RTDB sync | Standard quest pattern |
| **Completion Tracking** | `userCompletions` map in `DailyQuest` | Standard dual completion pattern |
| **Intro Screen** | Always shown | Simple, consistent UX |
| **Waiting Screen** | Can leave, no notifications (V1) | Flexible, non-intrusive |
| **Question Tracking** | Per-couple progression | Shared experience, prevents repetition |
| **Mock Data** | No sessions pre-created | Follow affirmation pattern (load on demand) |
| **UI Design** | Follow `/mockups/you_or_me_game.html` | Consistent with design spec |
| **Debugging** | Use Logger service per CLAUDE.md | Consistent with affirmation pattern |

### Game Mechanics Summary

- **10 questions per session** (random selection from 50+ pool)
- **4 answer types**: Me, Partner, Neither, Both
- **4 question categories**: Personality, Actions, Scenarios, Comparative
- **Category variety**: 3-4 categories per session, max 4 questions per category
- **Question tracking**: Mark used questions, reset when pool exhausted
- **Card-based UI**: Stack of 3 cards with slide/rotation animation
- **Results**: Agreement %, answer distribution, comparison stats

---

## Architecture Summary

### Data Flow

```
User Taps Quest Card
    ↓
[Quest Type Check: youOrMe]
    ↓
YouOrMeService.getSession(contentId)
    ↓
Navigate to YouOrMeIntroScreen
    ↓
User Taps "Start Game"
    ↓
Navigate to YouOrMeGameScreen
    ↓
Display Question 1/10
    ↓
User Selects Answer → Card animates away
    ↓
Repeat for Questions 2-10
    ↓
User Submits All Answers
    ↓
YouOrMeService.submitAnswers()
    ├─ Save to local Hive
    ├─ Sync to Firebase RTDB
    └─ Check if both answered
        ├─ [BOTH] → Award 30 LP to both
        │           Mark quest completed
        │           Navigate to results
        └─ [ONE]  → Navigate to waiting screen
                    Poll for partner completion
```

### Service Dependencies

```
YouOrMeQuestProvider
    ↓
YouOrMeService
    ├─→ StorageService (Hive)
    ├─→ FirebaseDatabase (RTDB)
    ├─→ LovePointService (LP awards)
    └─→ QuestUtilities (dateKey, coupleId)
```

### Firebase RTDB Structure

```
/you_or_me_sessions/
    /{emulatorId}/
        /{sessionId}/
            - id: string
            - userId: string
            - partnerId: string
            - questId: string
            - questions: [...]
            - answers: {userId: [answers]}
            - status: 'in_progress' | 'completed'
            - isCompleted: boolean
            - lpEarned: 30
            - createdAt: timestamp
            - completedAt: timestamp
            - coupleId: string
```

---

## Reuse Analysis

### ✅ Fully Reusable (90% of code)

| Component | File | Usage |
|-----------|------|-------|
| Quest generation | `lib/services/quest_type_manager.dart` | Add YouOrMeQuestProvider |
| Daily distribution | `lib/services/daily_quest_service.dart` | No changes needed |
| Completion tracking | `lib/models/daily_quest.dart` | Use existing userCompletions |
| LP awards | `lib/services/love_point_service.dart` | Standard 30 LP pattern |
| Firebase sync | `lib/services/quest_sync_service.dart` | No changes needed |
| Storage | `lib/services/storage_service.dart` | Add new Hive boxes |
| Utilities | `lib/services/quest_utilities.dart` | Use as-is |
| Quest card | `lib/widgets/quest_card.dart` | Add navigation case |
| Debug menu | `lib/widgets/debug/debug_menu.dart` | Sessions tab will show data |
| Cleanup | `main.dart` | Add cleanup call |

### 🆕 New Code Required (10%)

1. **Models**: `YouOrMeQuestion`, `YouOrMeAnswer`, `YouOrMeSession` (3 classes)
2. **Service**: `YouOrMeService` (1 file, ~400 lines)
3. **Provider**: `YouOrMeQuestProvider` (1 class, ~50 lines)
4. **Question Bank**: JSON file (50+ questions)
5. **Screens**: Intro, game, results (3 files)
6. **Widgets**: Card stack, answer buttons, progress bar, bottom sheet (4 files)
7. **Animations**: Card slide/rotation controller (in game screen)

---

## Phase 1: Data Models & Storage

**Estimated Time**: 4-6 hours
**Dependencies**: None

### Task 1.1: Create Data Models

- [ ] Create `lib/models/you_or_me.dart`
- [ ] Define `YouOrMeQuestion` class
  ```dart
  @HiveType(typeId: 20)
  class YouOrMeQuestion {
    @HiveField(0) String id;
    @HiveField(1) String prompt;       // "Who's more...", "Who would..."
    @HiveField(2) String content;      // "Creative", "Plan the perfect date"
    @HiveField(3) String category;     // "personality", "actions", etc.
  }
  ```
- [ ] Define `YouOrMeAnswer` class
  ```dart
  @HiveType(typeId: 21)
  class YouOrMeAnswer {
    @HiveField(0) String questionId;
    @HiveField(1) String questionPrompt;
    @HiveField(2) String questionContent;
    @HiveField(3) String answerType;   // 'me', 'partner', 'neither', 'both'
    @HiveField(4) DateTime answeredAt;
  }
  ```
- [ ] Define `YouOrMeSession` class
  ```dart
  @HiveType(typeId: 22)
  class YouOrMeSession extends HiveObject {
    @HiveField(0) String id;
    @HiveField(1) String userId;
    @HiveField(2) String partnerId;
    @HiveField(3) String? questId;
    @HiveField(4) List<YouOrMeQuestion> questions;
    @HiveField(5) Map<String, List<YouOrMeAnswer>>? answers;
    @HiveField(6) String status;       // 'in_progress', 'completed'
    @HiveField(7) DateTime createdAt;
    @HiveField(8) DateTime? completedAt;
    @HiveField(9) int? lpEarned;
    @HiveField(10) String coupleId;
  }
  ```
- [ ] Add `toMap()` and `fromMap()` methods to all classes
- [ ] Add helper methods to `YouOrMeSession`:
  - [ ] `bool get isCompleted`
  - [ ] `int getAnswerCount()`
  - [ ] `bool hasUserAnswered(String userId)`

### Task 1.2: Generate Hive Adapters

- [ ] Run build_runner:
  ```bash
  cd /Users/joakimachren/Desktop/togetherremind/app
  flutter pub run build_runner build --delete-conflicting-outputs
  ```
- [ ] Verify `you_or_me.g.dart` generated successfully
- [ ] Check for compilation errors

### Task 1.3: Update StorageService

- [ ] Open `lib/services/storage_service.dart`
- [ ] Add adapter registration in `init()`:
  ```dart
  Hive.registerAdapter(YouOrMeQuestionAdapter());
  Hive.registerAdapter(YouOrMeAnswerAdapter());
  Hive.registerAdapter(YouOrMeSessionAdapter());
  ```
- [ ] Open Hive boxes:
  ```dart
  await Hive.openBox<YouOrMeSession>('you_or_me_sessions');
  await Hive.openBox('you_or_me_progression');  // Track used questions
  ```
- [ ] Add helper methods:
  - [ ] `YouOrMeSession? getYouOrMeSession(String sessionId)`
  - [ ] `Future<void> saveYouOrMeSession(YouOrMeSession session)`
  - [ ] `List<YouOrMeSession> getAllYouOrMeSessions()`
  - [ ] `Future<void> updateYouOrMeSession(YouOrMeSession session)`
  - [ ] `Future<void> deleteYouOrMeSession(String sessionId)`

### Task 1.4: Test Data Models

- [ ] Write basic unit test for model serialization
- [ ] Test Hive save/load with sample session
- [ ] Verify adapters work correctly

**Completion Criteria**:
- ✅ All models compile without errors
- ✅ Hive adapters generated
- ✅ StorageService methods work
- ✅ Can save and load sample session

---

## Phase 2: Question Bank

**Estimated Time**: 2-3 hours
**Dependencies**: None

### Task 2.1: Create Question Bank JSON

- [ ] Create `assets/data/you_or_me_questions.json`
- [ ] Structure:
  ```json
  {
    "questions": [
      {
        "id": "yom_q001",
        "prompt": "Who's more...",
        "content": "Creative",
        "category": "personality"
      }
    ]
  }
  ```
- [ ] Write questions for each category:
  - [ ] **Personality** (15+ questions): Creative, Organized, Spontaneous, Introverted, Ambitious, Patient, Playful, Romantic, Practical, Optimistic, etc.
  - [ ] **Actions** (15+ questions): Plan the perfect date, Cook dinner tonight, Wake up first, Apologize first, Win at trivia, etc.
  - [ ] **Scenarios** (15+ questions): Start a spontaneous adventure, Forget an anniversary, Fall asleep during a movie, Try a new hobby, etc.
  - [ ] **Comparative** (10+ questions): Better dancer, Better cook, Funnier, More adventurous, Better listener, etc.
- [ ] Ensure variety in prompts:
  - [ ] "Who's more..." (personality)
  - [ ] "Who would..." (actions)
  - [ ] "Who's more likely to..." (scenarios)
  - [ ] "Which of you..." (comparative)
- [ ] Total: **50+ unique questions**

### Task 2.2: Update Asset Configuration

- [ ] Open `pubspec.yaml`
- [ ] Add asset path:
  ```yaml
  flutter:
    assets:
      - assets/data/you_or_me_questions.json
  ```
- [ ] Run `flutter pub get`

### Task 2.3: Test Question Loading

- [ ] Write simple script to load and parse JSON
- [ ] Verify all questions have required fields
- [ ] Check for duplicates (by ID)
- [ ] Validate category distribution

**Completion Criteria**:
- ✅ 50+ questions in JSON file
- ✅ All 4 categories represented
- ✅ JSON parses without errors
- ✅ Asset path configured correctly

---

## Phase 3: Service Layer

**Estimated Time**: 4-6 hours
**Dependencies**: Phase 1, Phase 2

### Task 3.1: Create YouOrMeService

- [ ] Create `lib/services/you_or_me_service.dart`
- [ ] Set up singleton pattern:
  ```dart
  class YouOrMeService {
    static final YouOrMeService _instance = YouOrMeService._internal();
    factory YouOrMeService() => _instance;
    YouOrMeService._internal();
  }
  ```
- [ ] Add dependencies:
  ```dart
  final _storage = StorageService();
  final _database = FirebaseDatabase.instance.ref();
  List<YouOrMeQuestion>? _questionBank;
  ```

### Task 3.2: Implement Question Loading

- [ ] Method: `Future<void> loadQuestions()`
  - [ ] Load from `assets/data/you_or_me_questions.json`
  - [ ] Parse JSON into `List<YouOrMeQuestion>`
  - [ ] Cache in `_questionBank` field
  - [ ] Log success/failure
- [ ] Test: Verify questions load on app startup

### Task 3.3: Implement Question Selection

- [ ] Method: `Future<List<YouOrMeQuestion>> getRandomQuestions(int count, String coupleId)`
- [ ] Get used question IDs from progression:
  ```dart
  Set<String> _getUsedQuestionIds(String coupleId) {
    final box = Hive.box('you_or_me_progression');
    final data = box.get(coupleId) as Map?;
    return (data?['usedQuestionIds'] as List? ?? []).cast<String>().toSet();
  }
  ```
- [ ] Filter available questions:
  ```dart
  final available = _questionBank!
      .where((q) => !usedIds.contains(q.id))
      .toList();
  ```
- [ ] If insufficient questions, reset progression
- [ ] Select with category variety:
  - [ ] Max 4 questions per category
  - [ ] Ensure 3-4 different categories
  - [ ] Shuffle within constraints
- [ ] Mark questions as used:
  ```dart
  void _markQuestionsAsUsed(String coupleId, List<YouOrMeQuestion> questions) {
    final box = Hive.box('you_or_me_progression');
    final data = box.get(coupleId, defaultValue: {}) as Map;
    final usedIds = Set<String>.from(data['usedQuestionIds'] ?? []);
    usedIds.addAll(questions.map((q) => q.id));
    box.put(coupleId, {
      'usedQuestionIds': usedIds.toList(),
      'totalPlayed': (data['totalPlayed'] ?? 0) + 1,
    });
  }
  ```

### Task 3.4: Implement Session Management

- [ ] Method: `Future<YouOrMeSession> startSession({required String userId, required String partnerId, String? questId})`
  - [ ] Generate couple ID: `QuestUtilities.generateCoupleId(userId, partnerId)`
  - [ ] Get 10 random questions
  - [ ] Create session with unique ID
  - [ ] Save to local Hive
  - [ ] Sync to Firebase RTDB
  - [ ] Log session creation
  - [ ] Return session

- [ ] Method: `Future<void> submitAnswers(String sessionId, String userId, List<YouOrMeAnswer> answers)`
  - [ ] Load session
  - [ ] Store answers in `session.answers[userId]`
  - [ ] Save to local Hive
  - [ ] Sync to Firebase
  - [ ] Check if both answered
  - [ ] If both: call `_completeSession()`
  - [ ] Log submission

- [ ] Method: `Future<void> _completeSession(YouOrMeSession session)` (private)
  - [ ] Award 30 LP to both users:
    ```dart
    await LovePointService.awardPointsToBothUsers(
      userId1: session.userId,
      userId2: session.partnerId,
      amount: 30,
      reason: 'you_or_me_completion',
      relatedId: session.id,
    );
    ```
  - [ ] Set `session.lpEarned = 30`
  - [ ] Set `session.status = 'completed'`
  - [ ] Set `session.completedAt = DateTime.now()`
  - [ ] Save and sync
  - [ ] Log completion

### Task 3.5: Implement Firebase Sync

- [ ] Method: `Future<void> _syncSessionToRTDB(YouOrMeSession session)` (private)
  - [ ] Get emulator ID: `await DevConfig.emulatorId`
  - [ ] Reference: `/you_or_me_sessions/{emulatorId}/{sessionId}`
  - [ ] Set session data: `await sessionRef.set(session.toMap())`
  - [ ] Handle errors gracefully

- [ ] Method: `Future<YouOrMeSession?> _loadSessionFromFirebase(String sessionId, String emulatorId)` (private)
  - [ ] Reference: `/you_or_me_sessions/{emulatorId}/{sessionId}`
  - [ ] Get snapshot
  - [ ] Parse to `YouOrMeSession`
  - [ ] Return null if not found

- [ ] Method: `Future<YouOrMeSession?> getSession(String sessionId)` (public)
  - [ ] Try local storage first
  - [ ] If not found, try own Firebase path
  - [ ] If not found, try partner's Firebase path
  - [ ] Cache to local storage when found
  - [ ] Return null if nowhere

- [ ] Helper: `Future<String> _getPartnerEmulatorId()` (private)
  - [ ] Get partner from storage
  - [ ] Return partner.pushToken

### Task 3.6: Implement Background Listener

- [ ] Method: `Future<void> startListeningForPartnerSessions()`
  - [ ] Get partner emulator ID
  - [ ] Reference: `/you_or_me_sessions/{partnerEmulatorId}`
  - [ ] Listen to `onChildAdded` → save to local storage
  - [ ] Listen to `onChildChanged` → update local storage
  - [ ] Log incoming sessions

### Task 3.7: Implement Results Calculation

- [ ] Method: `Map<String, dynamic> calculateResults(YouOrMeSession session)`
  - [ ] Count answer types for current user (me, partner, neither, both)
  - [ ] Find agreements (same answer as partner)
  - [ ] Calculate agreement percentage
  - [ ] Determine most selected answer type
  - [ ] Return stats map:
    ```dart
    {
      'userCounts': {me: 3, partner: 5, neither: 1, both: 1},
      'mostSelected': 'partner',
      'mostSelectedCount': 5,
      'agreements': 6,
      'agreementPercentage': 60,
    }
    ```

### Task 3.8: Implement Cleanup

- [ ] Method: `Future<void> cleanupOldSessions()`
  - [ ] Get all sessions from Hive
  - [ ] Find sessions older than 30 days
  - [ ] Delete from Hive
  - [ ] Log cleanup count

**Completion Criteria**:
- ✅ All service methods implemented
- ✅ Question selection with category variety works
- ✅ Session creation saves to Hive + Firebase
- ✅ Answer submission syncs correctly
- ✅ Both-answered detection triggers LP award
- ✅ Background listener receives partner sessions
- ✅ Results calculation returns correct stats

---

## Phase 4: Quest Provider Integration

**Estimated Time**: 1-2 hours
**Dependencies**: Phase 3

### Task 4.1: Add QuestType Enum Value

- [ ] Open `lib/services/quest_type_manager.dart`
- [ ] Add to `QuestType` enum:
  ```dart
  enum QuestType {
    quiz,
    wordLadder,
    memoryFlip,
    youOrMe,  // 🆕 Add this
  }
  ```

### Task 4.2: Update Daily Quest Generation Logic

**CRITICAL**: Daily quests now have **FIXED distribution** (not random):
- **Position 0 (sortOrder=0)**: Always Classic Quiz
- **Position 1 (sortOrder=1)**: Always Affirmation Quiz
- **Position 2 (sortOrder=2)**: Always You or Me

- [ ] Open `lib/services/quest_type_manager.dart`
- [ ] Update `generateDailyQuests()` method:
  ```dart
  Future<List<DailyQuest>> generateDailyQuests({
    required String currentUserId,
    required String partnerUserId,
    required String dateKey,
  }) async {
    final quests = <DailyQuest>[];

    // Position 0: Classic Quiz (formatType: 'classic')
    final classicResult = await _quizProvider.generateQuest(
      dateKey: dateKey,
      sortOrder: 0,
      currentUserId: currentUserId,
      partnerUserId: partnerUserId,
      formatType: 'classic',  // 🆕 Force classic
    );

    if (classicResult != null) {
      quests.add(_createQuest(
        questType: QuestType.quiz,
        contentId: classicResult['contentId']!,
        formatType: classicResult['formatType']!,
        quizName: classicResult['quizName'],
        dateKey: dateKey,
        sortOrder: 0,
      ));
    }

    // Position 1: Affirmation Quiz (formatType: 'affirmation')
    final affirmationResult = await _quizProvider.generateQuest(
      dateKey: dateKey,
      sortOrder: 1,
      currentUserId: currentUserId,
      partnerUserId: partnerUserId,
      formatType: 'affirmation',  // 🆕 Force affirmation
    );

    if (affirmationResult != null) {
      quests.add(_createQuest(
        questType: QuestType.quiz,
        contentId: affirmationResult['contentId']!,
        formatType: affirmationResult['formatType']!,
        quizName: affirmationResult['quizName'],
        dateKey: dateKey,
        sortOrder: 1,
      ));
    }

    // Position 2: You or Me (NEW)
    final youOrMeResult = await _youOrMeProvider.generateQuest(
      dateKey: dateKey,
      sortOrder: 2,
      currentUserId: currentUserId,
      partnerUserId: partnerUserId,
    );

    if (youOrMeResult != null) {
      quests.add(_createQuest(
        questType: QuestType.youOrMe,
        contentId: youOrMeResult['contentId']!,
        formatType: youOrMeResult['formatType']!,
        quizName: youOrMeResult['quizName'],
        dateKey: dateKey,
        sortOrder: 2,
      ));
    }

    return quests;
  }
  ```

**Note**: This removes the random distribution logic. Every day now has 1 classic, 1 affirmation, 1 You or Me.

### Task 4.3: Create YouOrMeQuestProvider

- [ ] In same file, add provider class:
  ```dart
  class YouOrMeQuestProvider extends QuestProvider {
    final YouOrMeService _youOrMeService = YouOrMeService();

    @override
    QuestType get questType => QuestType.youOrMe;

    @override
    Future<Map<String, String?>?> generateQuest({
      required String dateKey,
      required int sortOrder,
      String? currentUserId,
      String? partnerUserId,
    }) async {
      if (currentUserId == null || partnerUserId == null) {
        Logger.error('User IDs required for You or Me quest', service: 'quest');
        return null;
      }

      try {
        final session = await _youOrMeService.startSession(
          userId: currentUserId,
          partnerId: partnerUserId,
        );

        return {
          'contentId': session.id,
          'formatType': 'you_or_me',
          'quizName': 'You or Me?',
        };
      } catch (e) {
        Logger.error('Failed to generate You or Me quest', error: e, service: 'quest');
        return null;
      }
    }

    @override
    Future<bool> validateCompletion({
      required String contentId,
      required String userId,
    }) async {
      final session = await _youOrMeService.getSession(contentId);
      return session?.hasUserAnswered(userId) ?? false;
    }
  }
  ```

### Task 4.4: Register Provider

- [ ] In `QuestTypeManager` constructor, add:
  ```dart
  QuestTypeManager() {
    registerProvider(QuizQuestProvider());
    registerProvider(YouOrMeQuestProvider());  // 🆕 Add this
  }
  ```

### Task 4.5: Test Quest Generation

- [ ] Trigger daily quest generation
- [ ] Verify You or Me quest appears in daily quests
- [ ] Check Firebase: `/daily_quests/{coupleId}/{dateKey}`
- [ ] Verify quest has:
  - [ ] `questType = 3` (youOrMe index)
  - [ ] `formatType = 'you_or_me'`
  - [ ] `quizName = 'You or Me?'`
  - [ ] `contentId = 'youorme_{timestamp}'`

**Completion Criteria**:
- ✅ Provider registered successfully
- ✅ Quest generation creates You or Me session
- ✅ Quest syncs to Firebase with correct metadata
- ✅ Second device loads quest correctly

---

## Phase 5: UI Screens

**Estimated Time**: 8-10 hours
**Dependencies**: Phase 3

### Task 5.1: Create Intro Screen

- [ ] Create `lib/screens/you_or_me_intro_screen.dart`
- [ ] Accept `YouOrMeSession session` parameter
- [ ] Build UI:
  - [ ] AppBar with "You or Me?" title
  - [ ] Icon (people/comparison themed)
  - [ ] Game title (large, bold)
  - [ ] Description text (2-3 sentences)
  - [ ] Info rows:
    - [ ] 10 Questions icon + text
    - [ ] ~3 minutes icon + text
    - [ ] 30 Love Points icon + text
  - [ ] "Start Game" button (full width, black background)
- [ ] Navigation:
  - [ ] On button tap → `Navigator.pushReplacement()` to `YouOrMeGameScreen`
- [ ] Test:
  - [ ] Screen displays correctly
  - [ ] Navigation works

### Task 5.2: Create Game Screen Structure

- [ ] Create `lib/screens/you_or_me_game_screen.dart`
- [ ] Set up StatefulWidget
- [ ] Accept `YouOrMeSession session` parameter
- [ ] State variables:
  ```dart
  int _currentQuestionIndex = 0;
  List<YouOrMeAnswer> _answers = [];
  late AnimationController _cardController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotationAnimation;
  bool _isSubmitting = false;
  ```
- [ ] Initialize animation controller in `initState()`:
  ```dart
  _cardController = AnimationController(
    duration: const Duration(milliseconds: 300),
    vsync: this,
  );

  _slideAnimation = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(1.5, 0),
  ).animate(CurvedAnimation(
    parent: _cardController,
    curve: Curves.easeInOut,
  ));

  _rotationAnimation = Tween<double>(
    begin: 0,
    end: 0.35,  // ~20 degrees
  ).animate(CurvedAnimation(
    parent: _cardController,
    curve: Curves.easeInOut,
  ));
  ```
- [ ] Dispose controller in `dispose()`

### Task 5.3: Build Game Screen Layout

- [ ] AppBar:
  - [ ] Back button (circular with border)
  - [ ] No title (minimal design)
- [ ] Progress bar:
  - [ ] `LinearProgressIndicator`
  - [ ] Value: `(_currentQuestionIndex + 1) / 10`
  - [ ] Black fill, light gray background
- [ ] Card stack area:
  - [ ] Use `Stack` widget
  - [ ] Display 3 cards with depth effect
  - [ ] Front card: Full opacity, current question
  - [ ] Middle card: 96% width, 60% opacity
  - [ ] Back card: 92% width, 30% opacity
- [ ] Answer section:
  - [ ] White card container
  - [ ] Primary answers: Me / or / Partner (circular buttons)
  - [ ] "More options" link (gray, underlined)
- [ ] Wire up to widget components (Phase 6)

### Task 5.4: Implement Answer Logic

- [ ] Method: `void _handleAnswer(String answerType)`
  - [ ] Create `YouOrMeAnswer` object
  - [ ] Add to `_answers` list
  - [ ] Trigger card exit animation
  - [ ] After animation, advance to next question
  - [ ] If last question (index 9), show submit button

- [ ] Method: `void _animateToNextQuestion()`
  - [ ] Start card controller forward
  - [ ] On complete:
    - [ ] Increment `_currentQuestionIndex`
    - [ ] Reset card controller
    - [ ] Update UI (`setState`)

- [ ] Method: `void _showMoreOptions()`
  - [ ] Show bottom sheet modal (Phase 6)
  - [ ] On selection → call `_handleAnswer()`

### Task 5.5: Implement Submit Logic

- [ ] Method: `Future<void> _submitAnswers()`
  - [ ] Set `_isSubmitting = true`
  - [ ] Get current user ID from storage
  - [ ] Call `YouOrMeService().submitAnswers(session.id, userId, _answers)`
  - [ ] Check if both answered:
    - [ ] Load updated session
    - [ ] If both: navigate to results screen
    - [ ] If one: navigate to waiting screen
  - [ ] Handle errors gracefully

### Task 5.6: Create Results Screen

- [ ] Create `lib/screens/you_or_me_results_screen.dart`
- [ ] Accept `YouOrMeSession session` parameter
- [ ] Get results from service:
  ```dart
  final results = YouOrMeService().calculateResults(session);
  ```
- [ ] Build UI:
  - [ ] AppBar with "Results" title
  - [ ] LP earned badge (30 LP, prominent)
  - [ ] Most selected section:
    - [ ] Icon for answer type (person, people, etc.)
    - [ ] Text: "You mostly picked [answer type]!"
    - [ ] Percentage: "50% of answers"
  - [ ] Agreement section:
    - [ ] Heart icon
    - [ ] Agreement percentage with partner
    - [ ] Text: "You agreed on X out of 10 questions"
  - [ ] Answer distribution:
    - [ ] Bar chart or list:
      - [ ] Me: X answers
      - [ ] Partner: X answers
      - [ ] Both: X answers
      - [ ] Neither: X answers
  - [ ] Action buttons:
    - [ ] "View Details" (optional, show all Q&A)
    - [ ] "Done" → Back to home
- [ ] Test results display with sample data

### Task 5.7: Create Waiting Screen

- [ ] Create `lib/screens/you_or_me_waiting_screen.dart`
- [ ] Accept `YouOrMeSession session` parameter
- [ ] Set up polling timer:
  ```dart
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkSessionStatus();
    });
  }

  Future<void> _checkSessionStatus() async {
    final updatedSession = await YouOrMeService().getSession(widget.session.id);
    if (updatedSession == null) return;

    setState(() {
      _session = updatedSession;
    });

    if (_session.isCompleted) {
      _pollTimer?.cancel();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => YouOrMeResultsScreen(session: _session),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
  ```
- [ ] Build UI:
  - [ ] Loading indicator
  - [ ] "Waiting for partner..." text
  - [ ] Partner avatar (if available)
  - [ ] Optional: "Cancel" button → back to home

**Completion Criteria**:
- ✅ Intro screen displays and navigates correctly
- ✅ Game screen shows questions with card stack
- ✅ Progress bar updates 1-10
- ✅ Answer selection works for all 4 types
- ✅ Card animations smooth
- ✅ Submit logic saves answers and checks completion
- ✅ Results screen shows correct stats
- ✅ Waiting screen polls Firebase every 3s

---

## Phase 6: UI Components

**Estimated Time**: 4-6 hours
**Dependencies**: Phase 5

### Task 6.1: Create Question Card Widget

- [ ] Create `lib/widgets/you_or_me_card.dart`
- [ ] Accept parameters:
  - [ ] `YouOrMeQuestion question`
  - [ ] `int questionNumber` (1-10)
  - [ ] `double opacity` (for stacked cards)
  - [ ] `double scale` (for depth effect)
- [ ] Build card UI:
  - [ ] White background, rounded corners
  - [ ] Border (light gray)
  - [ ] Padding: 24px
  - [ ] Top: "Question X of 10" (small, gray)
  - [ ] Center: Question prompt + content
    - [ ] Prompt: 36px, Playfair Display, weight 700
    - [ ] Content: 42px, Playfair Display, weight 700
  - [ ] Bottom: Decorative element (optional)
- [ ] Apply transform:
  ```dart
  Transform.scale(
    scale: scale,
    child: Opacity(
      opacity: opacity,
      child: Card(...),
    ),
  )
  ```

### Task 6.2: Create Answer Buttons Widget

- [ ] Create `lib/widgets/you_or_me_answer_buttons.dart`
- [ ] Accept parameters:
  - [ ] `String currentUserInitial` (e.g., "J")
  - [ ] `Function(String) onAnswerSelected`
  - [ ] `VoidCallback onMoreOptions`
- [ ] Build UI:
  - [ ] White card container
  - [ ] Padding: 20px
  - [ ] Primary answers row:
    - [ ] Left button: Circular, user initial, 60px diameter
    - [ ] Center: "or" text (gray)
    - [ ] Right button: Circular, "Your partner" text, 60px diameter
  - [ ] Divider (horizontal line)
  - [ ] "More options" link button:
    - [ ] Underlined, gray
    - [ ] On tap → call `onMoreOptions()`
- [ ] Button styling:
  - [ ] Default: White background, black border
  - [ ] Hover: Black background, white text
  - [ ] Active: Scale down slightly
- [ ] Wire up callbacks:
  - [ ] Left button → `onAnswerSelected('me')`
  - [ ] Right button → `onAnswerSelected('partner')`

### Task 6.3: Create Bottom Sheet Widget

- [ ] Create `lib/widgets/you_or_me_bottom_sheet.dart`
- [ ] Accept parameters:
  - [ ] `BuildContext context`
  - [ ] `Function(String) onOptionSelected`
- [ ] Method: `static void show(BuildContext context, Function(String) callback)`
  ```dart
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => YouOrMeBottomSheet(onOptionSelected: callback),
  );
  ```
- [ ] Build UI:
  - [ ] Drag handle (40px × 4px gray bar, centered)
  - [ ] Title: "Select an option" (18px, bold)
  - [ ] Option buttons (full width):
    - [ ] "Neither" button
    - [ ] "Both" button
  - [ ] Spacing: 12px between buttons
  - [ ] Padding: 20-32px
- [ ] Button interactions:
  - [ ] On tap → call `onOptionSelected()` and close sheet

### Task 6.4: Create Progress Bar Widget

- [ ] Create `lib/widgets/you_or_me_progress_bar.dart`
- [ ] Accept parameters:
  - [ ] `int currentQuestion` (1-10)
  - [ ] `int totalQuestions` (always 10)
- [ ] Build UI:
  - [ ] Container with fixed height (6px)
  - [ ] Background: Light gray (`#F0F0F0`)
  - [ ] Fill: Black (`#1A1A1A`)
  - [ ] Rounded ends (3px radius)
  - [ ] Animated progress:
    ```dart
    LinearProgressIndicator(
      value: currentQuestion / totalQuestions,
      backgroundColor: const Color(0xFFF0F0F0),
      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1A1A1A)),
      minHeight: 6,
    )
    ```

### Task 6.5: Wire Up Components to Game Screen

- [ ] In `you_or_me_game_screen.dart`:
  - [ ] Replace placeholder card stack with `YouOrMeCard` widgets
  - [ ] Use `SlideTransition` and `RotationTransition` on front card:
    ```dart
    SlideTransition(
      position: _slideAnimation,
      child: RotationTransition(
        turns: _rotationAnimation,
        child: YouOrMeCard(
          question: widget.session.questions[_currentQuestionIndex],
          questionNumber: _currentQuestionIndex + 1,
          opacity: 1.0,
          scale: 1.0,
        ),
      ),
    )
    ```
  - [ ] Add middle and back cards (static, scaled)
  - [ ] Replace answer section with `YouOrMeAnswerButtons`:
    ```dart
    YouOrMeAnswerButtons(
      currentUserInitial: _getUserInitial(),
      onAnswerSelected: _handleAnswer,
      onMoreOptions: _showMoreOptions,
    )
    ```
  - [ ] Replace progress placeholder with `YouOrMeProgressBar`:
    ```dart
    YouOrMeProgressBar(
      currentQuestion: _currentQuestionIndex + 1,
      totalQuestions: 10,
    )
    ```
  - [ ] Implement `_showMoreOptions()`:
    ```dart
    void _showMoreOptions() {
      YouOrMeBottomSheet.show(context, _handleAnswer);
    }
    ```

**Completion Criteria**:
- ✅ Card widget displays question correctly
- ✅ Card stack shows 3 layers with depth
- ✅ Answer buttons respond to taps
- ✅ Bottom sheet appears and closes correctly
- ✅ Progress bar animates smoothly
- ✅ All components integrated into game screen

---

## Phase 7: Integration

**Estimated Time**: 3-4 hours
**Dependencies**: Phase 4, Phase 5, Phase 6

### Task 7.1: Update Main Initialization

- [ ] Open `main.dart`
- [ ] In `main()` function, after existing services:
  ```dart
  // Load You or Me questions
  await YouOrMeService().loadQuestions();

  // Start listening for partner sessions
  await YouOrMeService().startListeningForPartnerSessions();
  ```
- [ ] In `_runPeriodicCleanup()`, add:
  ```dart
  await YouOrMeService().cleanupOldSessions();
  ```
- [ ] Test: Verify questions load on app startup

### Task 7.2: Add to Activities Screen

- [ ] Open `lib/screens/activities_screen.dart`
- [ ] Add game card:
  ```dart
  _buildGameCard(
    context,
    icon: '🎭',
    title: 'You or Me?',
    description: 'Playful comparison game',
    onTap: () async {
      final user = _storage.getUser();
      final partner = user?.partnerId != null
          ? _storage.getPartner(user!.partnerId!)
          : null;

      if (partner == null) {
        _showNeedPartnerDialog(context);
        return;
      }

      // Create standalone session (not tied to daily quest)
      final session = await YouOrMeService().startSession(
        userId: user!.id,
        partnerId: partner.id,
        questId: null,  // ⚠️ No quest ID = still awards 30 LP on completion
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => YouOrMeIntroScreen(session: session),
        ),
      );
    },
  ),
  ```
- [ ] Test: Tap game card → navigates to intro screen

**Note**: Sessions created from Activities screen (without `questId`) still award 30 LP when both users complete. This encourages play beyond daily quests.

### Task 7.3: Update QuestCard Navigation

- [ ] Open `lib/widgets/quest_card.dart`
- [ ] In `_handleQuestTap()`, add case for You or Me:
  ```dart
  void _handleQuestTap(BuildContext context, DailyQuest quest) async {
    // ... existing quiz/game logic ...

    // 🆕 You or Me handling
    if (quest.questType == QuestType.youOrMe.index) {
      final session = await YouOrMeService().getSession(quest.contentId);
      if (session == null) {
        _showError(context, 'Session not found');
        return;
      }

      // Check if user already answered
      final user = _storage.getUser();
      if (user != null && session.hasUserAnswered(user.id)) {
        // Navigate to results or waiting screen
        if (session.isCompleted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => YouOrMeResultsScreen(session: session),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => YouOrMeWaitingScreen(session: session),
            ),
          );
        }
      } else {
        // Navigate to intro screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => YouOrMeIntroScreen(session: session),
          ),
        );
      }
      return;
    }
  }
  ```
- [ ] Test: Tap quest card → navigates correctly based on state

### Task 7.4: Update ActivityService (Inbox Titles)

- [ ] Open `lib/services/activity_service.dart`
- [ ] In `_getQuestTitle()`, add case:
  ```dart
  String _getQuestTitle(DailyQuest quest) {
    switch (quest.questType) {
      case 1: // QuestType.quiz
        // ... existing quiz logic ...

      case 3: // QuestType.youOrMe (index 3)
        return quest.quizName ?? 'You or Me?';

      default:
        return 'Quest';
    }
  }
  ```
- [ ] Test: Inbox shows "You or Me?" for completed quests

### Task 7.5: Update Firebase Security Rules

- [ ] Open `database.rules.json`
- [ ] Add rules for You or Me sessions:
  ```json
  {
    "rules": {
      "you_or_me_sessions": {
        "$emulatorId": {
          ".read": true,
          ".write": true
        }
      }
    }
  }
  ```
- [ ] Deploy rules:
  ```bash
  cd /Users/joakimachren/Desktop/togetherremind
  firebase deploy --only database
  ```
- [ ] Verify: Rules deployed successfully

### Task 7.6: Update Debug Menu (Optional)

- [ ] Open `lib/widgets/debug/tabs/sessions_tab.dart`
- [ ] Add filter option for "You or Me" sessions
- [ ] Display You or Me sessions in list
- [ ] Show session details (questions, answers, status)

**Completion Criteria**:
- ✅ Service initializes on app startup
- ✅ Activities screen shows You or Me card
- ✅ Tapping activities card creates session and navigates
- ✅ Quest card navigation works (intro/waiting/results)
- ✅ Inbox shows correct quest titles
- ✅ Firebase rules deployed
- ✅ Debug menu shows sessions (optional)

---

## Phase 8: Testing & Polish

**Estimated Time**: 4-6 hours
**Dependencies**: All previous phases

### Task 8.1: Clean Testing Procedure

- [ ] Run complete clean test (see CLAUDE.md):
  ```bash
  # Kill processes
  pkill -9 -f "flutter"

  # Uninstall Android app
  ~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind

  # Clear Firebase
  cd /Users/joakimachren/Desktop/togetherremind
  firebase database:remove /daily_quests --force
  firebase database:remove /you_or_me_sessions --force
  firebase database:remove /lp_awards --force

  # Launch Alice (Android)
  cd app
  flutter run -d emulator-5554 &

  # Launch Bob (Chrome)
  flutter run -d chrome &
  ```

### Task 8.2: Quest Generation Testing

- [ ] **Test 8.2.1**: First device (Alice) generates daily quests
  - [ ] Verify quest appears in daily quests list
  - [ ] Check quest has `questType = 3` (youOrMe)
  - [ ] Check quest has `formatType = 'you_or_me'`
  - [ ] Check quest has `quizName = 'You or Me?'`
  - [ ] Verify session created with 10 questions

- [ ] **Test 8.2.2**: Second device (Bob) loads from Firebase
  - [ ] Wait for sync (3-5 seconds)
  - [ ] Verify same quest appears
  - [ ] Check quest ID matches Alice's quest
  - [ ] Verify quest title shows "You or Me?"
  - [ ] Check session accessible

### Task 8.3: Gameplay Testing

- [ ] **Test 8.3.1**: Question display
  - [ ] Launch game from quest card
  - [ ] Verify intro screen displays
  - [ ] Tap "Start Game" → game screen loads
  - [ ] Verify first question displays correctly
  - [ ] Check card stack shows 3 layers
  - [ ] Verify progress bar shows "1/10"

- [ ] **Test 8.3.2**: Answer interactions
  - [ ] Tap "Me" button → card animates away
  - [ ] Verify next question appears
  - [ ] Progress bar updates to "2/10"
  - [ ] Tap "Partner" button → card animates
  - [ ] Tap "More options" → bottom sheet appears
  - [ ] Tap "Neither" → bottom sheet closes, card animates
  - [ ] Tap "Both" → card animates
  - [ ] Repeat until question 10

- [ ] **Test 8.3.3**: Submission
  - [ ] Answer all 10 questions
  - [ ] Verify "Submit" button appears
  - [ ] Tap submit → answers saved
  - [ ] Check Firebase: `/you_or_me_sessions/{emulatorId}/{sessionId}`
  - [ ] Verify answers array present

### Task 8.4: Completion & Sync Testing

- [ ] **Test 8.4.1**: Single user completion
  - [ ] Alice submits answers
  - [ ] Verify navigates to waiting screen
  - [ ] Check "Waiting for partner..." message
  - [ ] Verify polling timer active (every 3s)

- [ ] **Test 8.4.2**: Partner completion detection
  - [ ] Bob submits answers
  - [ ] Alice's waiting screen detects completion (within 3-5s)
  - [ ] Alice navigates to results screen
  - [ ] Bob navigates to results screen

- [ ] **Test 8.4.3**: Love Points award
  - [ ] Verify both users awarded 30 LP
  - [ ] Check foreground notification appears: "+30 LP 💰"
  - [ ] Verify Firebase: `/lp_awards/{coupleId}/{awardId}`
  - [ ] Check LP deduplication works (no double award)

- [ ] **Test 8.4.4**: Quest completion
  - [ ] Quest status changes to "completed"
  - [ ] Quest shows checkmark on both devices
  - [ ] Quest appears in inbox feed
  - [ ] Daily progress updates (1/3 quests complete)

### Task 8.5: Results Screen Testing

- [ ] **Test 8.5.1**: Stats accuracy
  - [ ] Verify "Most selected" is correct
  - [ ] Check answer distribution counts
  - [ ] Verify agreement percentage
  - [ ] Test with various answer patterns:
    - [ ] All "Me" → 100% me, 0% agreement
    - [ ] All matching partner → 100% agreement
    - [ ] Mixed answers → correct percentages

- [ ] **Test 8.5.2**: UI display
  - [ ] LP earned badge shows "30 LP"
  - [ ] All sections render correctly
  - [ ] "Done" button returns to home

### Task 8.6: Question Pool Testing

- [ ] **Test 8.6.1**: Category variety
  - [ ] Play 5 sessions
  - [ ] Verify 3-4 different categories per session
  - [ ] Check no category exceeds 4 questions

- [ ] **Test 8.6.2**: Question tracking
  - [ ] Play until 50+ questions used
  - [ ] Verify no duplicate questions within sessions
  - [ ] Verify progression resets when pool exhausted
  - [ ] Check new session has fresh questions

### Task 8.7: Edge Cases & Error Handling

- [ ] **Test 8.7.1**: Network interruption
  - [ ] Disable WiFi during gameplay
  - [ ] Submit answers → should save locally
  - [ ] Re-enable WiFi → should sync to Firebase
  - [ ] Verify partner receives update

- [ ] **Test 8.7.2**: App backgrounding
  - [ ] Start game, answer 5 questions
  - [ ] Background app (home button)
  - [ ] Wait 1 minute
  - [ ] Return to app → should resume at question 6

- [ ] **Test 8.7.3**: Missing session
  - [ ] Delete session from Hive
  - [ ] Tap quest card → should load from Firebase
  - [ ] Verify fallback logic works

- [ ] **Test 8.7.4**: No partner
  - [ ] Unpair devices
  - [ ] Tap "You or Me?" in activities
  - [ ] Verify "Need partner" message appears

### Task 8.8: UI/UX Polish

- [ ] **Test 8.8.1**: Animations
  - [ ] Card slide animation smooth (300ms)
  - [ ] Card rotation smooth (~20 degrees)
  - [ ] Progress bar transitions smoothly
  - [ ] Bottom sheet slides up/down smoothly
  - [ ] No jank or stuttering

- [ ] **Test 8.8.2**: Responsive design
  - [ ] Test on Android (Pixel 5)
  - [ ] Test on Chrome (web)
  - [ ] Test on iOS (if available)
  - [ ] Verify layout adapts to screen size
  - [ ] Max width 430px maintained

- [ ] **Test 8.8.3**: Accessibility
  - [ ] Button tap targets ≥48px
  - [ ] Text contrast ratios pass WCAG AA
  - [ ] Font sizes readable (≥14px)

- [ ] **Test 8.8.4**: Loading states
  - [ ] Intro screen loads instantly
  - [ ] Game screen shows questions immediately
  - [ ] Submit button shows loading indicator
  - [ ] Waiting screen shows spinner

### Task 8.9: Debug Menu Verification

- [ ] Open debug menu (double-tap greeting)
- [ ] Navigate to Sessions tab
- [ ] Verify You or Me sessions appear
- [ ] Check session details display correctly:
  - [ ] Questions list
  - [ ] Answers (if submitted)
  - [ ] Status (in_progress/completed)
  - [ ] LP earned (30)
- [ ] Copy session data to clipboard
- [ ] Verify JSON is valid

### Task 8.10: Data Cleanup Testing

- [ ] Create sessions with old dates (manually set `createdAt`)
- [ ] Run cleanup: `YouOrMeService().cleanupOldSessions()`
- [ ] Verify sessions older than 30 days deleted
- [ ] Verify recent sessions preserved

**Completion Criteria**:
- ✅ All quest generation tests pass
- ✅ Gameplay is smooth and bug-free
- ✅ Completion detection works within 3-5s
- ✅ LP awards correctly to both users
- ✅ Results screen shows accurate stats
- ✅ Question pool variety works
- ✅ Edge cases handled gracefully
- ✅ UI/UX polish complete
- ✅ Debug menu shows data correctly
- ✅ Cleanup works as expected

---

## Complete Task Checklist

### Phase 1: Data Models & Storage ✅
- [ ] 1.1: Create data models (YouOrMeQuestion, YouOrMeAnswer, YouOrMeSession)
- [ ] 1.2: Generate Hive adapters
- [ ] 1.3: Update StorageService
- [ ] 1.4: Test data models

### Phase 2: Question Bank ✅
- [ ] 2.1: Create question bank JSON (50+ questions)
- [ ] 2.2: Update asset configuration
- [ ] 2.3: Test question loading

### Phase 3: Service Layer ✅
- [ ] 3.1: Create YouOrMeService
- [ ] 3.2: Implement question loading
- [ ] 3.3: Implement question selection
- [ ] 3.4: Implement session management
- [ ] 3.5: Implement Firebase sync
- [ ] 3.6: Implement background listener
- [ ] 3.7: Implement results calculation
- [ ] 3.8: Implement cleanup

### Phase 4: Quest Provider Integration ✅
- [ ] 4.1: Add QuestType enum value
- [ ] 4.2: Create YouOrMeQuestProvider
- [ ] 4.3: Register provider
- [ ] 4.4: Test quest generation

### Phase 5: UI Screens ✅
- [ ] 5.1: Create intro screen
- [ ] 5.2: Create game screen structure
- [ ] 5.3: Build game screen layout
- [ ] 5.4: Implement answer logic
- [ ] 5.5: Implement submit logic
- [ ] 5.6: Create results screen
- [ ] 5.7: Create waiting screen

### Phase 6: UI Components ✅
- [ ] 6.1: Create question card widget
- [ ] 6.2: Create answer buttons widget
- [ ] 6.3: Create bottom sheet widget
- [ ] 6.4: Create progress bar widget
- [ ] 6.5: Wire up components to game screen

### Phase 7: Integration ✅
- [ ] 7.1: Update main initialization
- [ ] 7.2: Add to activities screen
- [ ] 7.3: Update quest card navigation
- [ ] 7.4: Update activity service (inbox titles)
- [ ] 7.5: Update Firebase security rules
- [ ] 7.6: Update debug menu (optional)

### Phase 8: Testing & Polish ✅
- [ ] 8.1: Clean testing procedure
- [ ] 8.2: Quest generation testing
- [ ] 8.3: Gameplay testing
- [ ] 8.4: Completion & sync testing
- [ ] 8.5: Results screen testing
- [ ] 8.6: Question pool testing
- [ ] 8.7: Edge cases & error handling
- [ ] 8.8: UI/UX polish
- [ ] 8.9: Debug menu verification
- [ ] 8.10: Data cleanup testing

---

## Timeline & Resources

### Time Estimates (Developer Hours)

| Phase | Tasks | Estimated Time | Dependencies |
|-------|-------|----------------|--------------|
| Phase 1 | Data models & storage | 4-6 hours | None |
| Phase 2 | Question bank | 2-3 hours | None |
| Phase 3 | Service layer | 4-6 hours | Phase 1, 2 |
| Phase 4 | Quest provider | 1-2 hours | Phase 3 |
| Phase 5 | UI screens | 8-10 hours | Phase 3 |
| Phase 6 | UI components | 4-6 hours | Phase 5 |
| Phase 7 | Integration | 3-4 hours | Phase 4, 5, 6 |
| Phase 8 | Testing & polish | 4-6 hours | All phases |
| **TOTAL** | **8 phases** | **30-43 hours** | **~5-7 days** |

### Critical Path

```
Day 1: Phase 1 + Phase 2 (6-9 hours)
    ↓
Day 2: Phase 3 (4-6 hours)
    ↓
Day 3: Phase 4 + Phase 5 (start) (9-12 hours)
    ↓
Day 4: Phase 5 (finish) + Phase 6 (8-10 hours)
    ↓
Day 5: Phase 7 + Phase 8 (7-10 hours)
```

### Recommended Approach

**Sprint 1 (Days 1-2)**: Foundation
- Complete Phase 1 & 2 (data models + question bank)
- Complete Phase 3 (service layer)
- **Milestone**: Questions load, sessions can be created

**Sprint 2 (Days 3-4)**: UI Development
- Complete Phase 4 (quest provider integration)
- Complete Phase 5 (UI screens)
- Complete Phase 6 (UI components)
- **Milestone**: Full gameplay flow works

**Sprint 3 (Day 5)**: Integration & Polish
- Complete Phase 7 (integration)
- Complete Phase 8 (testing & polish)
- **Milestone**: Production-ready feature

### Key Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Question pool too small | Medium | Start with 30 questions, expand to 50+ in iterations |
| Card animations janky | Medium | Use pre-built animation curves, test on real devices |
| Firebase sync delays | Low | Polling fallback already in place (3s interval) |
| Quest title sync issues | Low | Denormalized data pattern already proven |
| LP award duplication | Low | Deduplication logic already exists |

### Success Criteria

**Minimum Viable Product (MVP)**:
- ✅ 30+ questions in question bank
- ✅ 10 questions per session with category variety
- ✅ All 4 answer types functional
- ✅ Card animations smooth
- ✅ Both-user completion detection works
- ✅ 30 LP awarded correctly
- ✅ Results screen shows basic stats

**V1 Launch**:
- ✅ 50+ questions in question bank
- ✅ Question tracking prevents immediate repetition
- ✅ Full results screen with agreement %
- ✅ Waiting screen with polling
- ✅ Firebase sync robust
- ✅ Debug menu integration
- ✅ Data cleanup (30 days)

**V2 Enhancements** (Future):
- Custom questions from couples
- Themed question packs
- LP bonuses ("Both" answer, 24h completion)
- Comparison mode (real-time play)
- Streak system

---

## Appendix: Code References

### Key Files to Modify

1. **New Files** (~10 files):
   - `lib/models/you_or_me.dart`
   - `lib/services/you_or_me_service.dart`
   - `lib/screens/you_or_me_intro_screen.dart`
   - `lib/screens/you_or_me_game_screen.dart`
   - `lib/screens/you_or_me_results_screen.dart`
   - `lib/screens/you_or_me_waiting_screen.dart`
   - `lib/widgets/you_or_me_card.dart`
   - `lib/widgets/you_or_me_answer_buttons.dart`
   - `lib/widgets/you_or_me_bottom_sheet.dart`
   - `lib/widgets/you_or_me_progress_bar.dart`
   - `assets/data/you_or_me_questions.json`

2. **Modified Files** (~6 files):
   - `lib/services/storage_service.dart` (add Hive boxes)
   - `lib/services/quest_type_manager.dart` (add provider)
   - `lib/widgets/quest_card.dart` (add navigation case)
   - `lib/services/activity_service.dart` (add inbox title)
   - `lib/screens/activities_screen.dart` (add game card)
   - `main.dart` (add initialization)
   - `database.rules.json` (add Firebase rules)
   - `pubspec.yaml` (add asset path)

### Design System References

**Colors** (from spec):
```dart
const Color primaryBlack = Color(0xFF1A1A1A);
const Color primaryWhite = Color(0xFFFFFEFD);
const Color backgroundGray = Color(0xFFFAFAFA);
const Color borderLight = Color(0xFFF0F0F0);
const Color borderMedium = Color(0xFFE0E0E0);
const Color textSecondary = Color(0xFF6E6E6E);
const Color textTertiary = Color(0xFFAAAAAA);
```

**Typography** (from spec):
- Question prompts: Playfair Display, 36px, weight 700
- Trait/content: Playfair Display, 42px, weight 700
- Body text: Inter, 15-16px, weight 400-500
- Buttons: Inter, 16-18px, weight 600
- Labels: Inter, 13-15px, weight 500

**Layout**:
- Max width: 430px (mobile-first)
- Card padding: 24px
- Button padding: 16-20px
- Spacing: 12-24px increments

---

**Version History**:
- V2.0 (2025-11-15): Quest system integrated implementation plan
- V1.0 (2025-11-13): Original specification

**Maintainer**: Development Team
**Estimated Completion**: 5-7 days (30-43 developer hours)

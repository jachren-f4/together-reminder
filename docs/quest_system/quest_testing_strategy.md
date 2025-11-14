# Quest System Testing Strategy

> **📝 Update (2025-11-14):** Phase 2 refactoring has been completed! The circular dependency between `DailyQuestService` and `QuestSyncService` has been resolved. See [quest_system_refactoring.md](./quest_system_refactoring.md) for details. This makes the testing approach described below even easier to implement.

## Executive Summary

**Problem:** Testing the quest system currently requires launching Android emulator + Chrome, manually clearing Firebase RTDB, and performing full app restarts. This makes testing slow (5+ minutes per iteration), error-prone, and difficult to reproduce edge cases.

**Solution:** Implement a layered testing strategy starting with quick wins (unit tests without architectural changes) and progressively adding more sophisticated testing infrastructure.

**Impact:** Reduce testing iteration time from 5+ minutes to 1-2 seconds for most scenarios, achieve 70%+ test coverage for quest logic, and enable testing of edge cases (race conditions, offline, etc.) that are currently impractical.

---

## Table of Contents

1. [Current State Assessment](#current-state-assessment)
2. [Architecture Analysis](#architecture-analysis)
3. [Quick Win Strategy (Phase 1)](#quick-win-strategy-phase-1)
4. [Future Enhancements (Phase 2+)](#future-enhancements-phase-2)
5. [Implementation Roadmap](#implementation-roadmap)
6. [Code Examples](#code-examples)
7. [Testing Commands](#testing-commands)
8. [Success Metrics](#success-metrics)

---

## Current State Assessment

### Test Coverage

**Existing Tests:**
- `test/memory_flip_service_test.dart` - 431 lines, comprehensive unit tests (excellent coverage)
- `test/widget_test.dart` - Default Flutter template (not useful)

**Missing Tests (Quest System):**
- ❌ NO unit tests for `DailyQuestService`
- ❌ NO unit tests for `QuestSyncService`
- ❌ NO unit tests for `QuestTypeManager`
- ❌ NO unit tests for `QuizQuestProvider`
- ❌ NO widget tests for `DailyQuestsWidget`
- ❌ NO widget tests for `QuestCard`
- ❌ NO integration tests for quest sync flow

**Test Coverage: 0% for quest system**

### Current Testing Pain Points

1. **Manual Device Setup**
   ```bash
   # Required for EVERY test iteration
   flutter run -d emulator-5554 &  # Alice
   sleep 10 && flutter run -d chrome &  # Bob
   # Wait 2-3 minutes for builds + initialization
   ```

2. **Manual Data Clearing**
   ```bash
   bash /tmp/clear_firebase.sh  # Clear Firebase RTDB
   pkill -9 -f flutter  # Kill all processes
   # Must remember to do this or get stale data bugs
   ```

3. **No Hot Reload Support**
   - Quest system changes require full app restarts
   - Firebase listeners don't re-subscribe
   - Hive storage state doesn't reset

4. **Hard to Test Edge Cases**
   - Race conditions (both devices generating simultaneously)
   - Offline completion scenarios
   - Network errors during sync
   - Partner completion events
   - Quest ID mismatches

5. **Slow Feedback Loop**
   - 5+ minutes per test iteration
   - Hard to verify fixes quickly
   - Discourages thorough testing

### Existing Mock Infrastructure

**What We Have:**

1. **`MockDataService`** (`lib/services/mock_data_service.dart`)
   - Creates mock users, partners, reminders
   - Injects LP transactions, quiz data
   - Used for UI development

2. **`MockDailyQuestsService`** (`lib/services/mock_daily_quests_service.dart`)
   - Creates 3 static test quests
   - Limited scenarios (completed, waiting, pending)
   - Useful for UI state testing

3. **`DevConfig`** (`lib/config/dev_config.dart`)
   - Flags for enabling mock mode
   - Simulator detection
   - Dual-emulator configuration

**What's Missing:**
- Test fixtures for common scenarios
- Hive test helpers
- Mock Firebase RTDB implementation
- Mock `QuestSyncService`
- Edge case simulators

### Firebase Testing Setup

**Current State:**
```json
// firebase.json - NO emulator configuration
{
  "functions": [...],
  "database": {
    "rules": "database.rules.json"
  }
  // Missing: "emulators": { ... }
}
```

**Issues:**
- All tests hit production Firebase RTDB
- No local emulator configured
- Cannot test offline scenarios safely
- Cannot test race conditions without risk
- Must manually clear data between tests

---

## Architecture Analysis

### Testability Strengths

✅ **`DailyQuestService` Already Testable!**

```dart
// lib/services/daily_quest_service.dart
class DailyQuestService {
  final StorageService _storage;
  final QuestSyncService? _questSyncService;  // Optional!

  DailyQuestService({
    required StorageService storage,
    QuestSyncService? questSyncService,  // Can pass null!
  })  : _storage = storage,
        _questSyncService = questSyncService;
}
```

**Key Insight:** By passing `null` for `questSyncService`, we can test quest logic without hitting Firebase!

✅ **Hive Testing Pattern Proven**

`memory_flip_service_test.dart` demonstrates excellent Hive testing:
- Temp directory for test data
- Proper setup/teardown
- Adapter registration
- Box clearing between tests

### Testability Blockers

~~❌ **Problem 1: `QuestSyncService` - Circular Dependency with `DailyQuestService`**~~ ✅ **RESOLVED (2025-11-14)**

**Previous Problem:** `QuestSyncService` had a circular dependency with `DailyQuestService`, making both services harder to test.

**Resolution:** Phase 2 refactoring removed the circular dependency. `QuestSyncService` now only depends on `StorageService`:

```dart
// lib/services/quest_sync_service.dart - AFTER Phase 2 Refactoring
class QuestSyncService {
  final StorageService _storage;
  final DatabaseReference _database;  // ⚠️ Still hard-coded (Phase 2+ testing)

  QuestSyncService({
    required StorageService storage,
  })  : _storage = storage,
        _database = FirebaseDatabase.instance.ref();
}
```

**Remaining Issue:** The `DatabaseReference` is still hard-coded, which means:
- Cannot mock database for testing
- Every method call hits real Firebase
- Cannot test offline behavior without emulator
- Cannot simulate network errors
- Cannot test race conditions safely

**Future Fix (Testing Phase 2):** Add optional `databaseRef` parameter for dependency injection

---

❌ **Problem 2: `DailyQuestsWidget` - Service Instantiation in `initState`**

```dart
// lib/widgets/daily_quests_widget.dart (lines 23-39)
class _DailyQuestsWidgetState extends State<DailyQuestsWidget> {
  final StorageService _storage = StorageService();  // Hard-coded
  late DailyQuestService _questService;
  late QuestSyncService _questSyncService;
  final QuizService _quizService = QuizService();  // Hard-coded

  @override
  void initState() {
    super.initState();
    _questService = DailyQuestService(storage: _storage);
    _questSyncService = QuestSyncService(
      storage: _storage,
      questService: _questService,
    );
    _listenForPartnerCompletions();  // Starts Firebase immediately
  }
}
```

**Impact:**
- Cannot inject mock services for widget testing
- Widget always uses real Firebase streams
- Hard to test different quest states
- Cannot simulate partner completion events

**Future Fix:** Add optional service parameters to widget constructor

---

❌ **Problem 3: `LovePointService` - Static Method Calls**

```dart
// lib/services/daily_quest_service.dart (lines 114-122)
await LovePointService.awardPointsToBothUsers(  // Static call!
  userId1: user.id,
  userId2: partner.pushToken,
  amount: lpReward,
  reason: 'daily_quest',
  relatedId: questId,
);
```

**Impact:**
- Cannot verify LP award logic in isolation
- Cannot test without hitting Firebase (LP awards sync to RTDB)

**Future Fix:** Inject `ILovePointService` interface

---

### Missing Abstractions

**No interfaces for key services:**
- No `IQuestSyncService` interface
- No `IDatabaseReference` abstraction
- No `IStorageService` interface
- All dependencies are concrete classes

**Example of what's needed (future):**
```dart
abstract class IQuestSyncService {
  Future<bool> syncTodayQuests({...});
  Future<void> saveQuestsToFirebase({...});
  Stream<Map<String, dynamic>> listenForPartnerCompletions({...});
}

class QuestSyncService implements IQuestSyncService { ... }
class MockQuestSyncService implements IQuestSyncService { ... }
```

---

## Quick Win Strategy (Phase 1)

### Goal
Test ~70% of quest logic **without architectural refactoring**, leveraging existing design.

### Time Estimate
**4-5 hours** focused work

### What We're Testing
- Quest completion logic (single user, both users)
- Quest status calculation (your_turn, waiting, completed, expired)
- Streak calculation (consecutive days, breaks)
- Quest retrieval (today, by date, filtering)
- Statistics (LP totals, completion counts)
- Quest generation (IDs, sortOrder, progression)

### What We're NOT Testing (Future)
- Firebase sync behavior (requires emulator or mocks)
- Widget UI states (requires DI refactor)
- End-to-end flows (requires integration tests)
- Real-time partner updates (requires Firebase emulator)

### Implementation Steps

#### Step 1: Create Test Fixtures (30 minutes)

**File:** `app/test/fixtures/quest_fixtures.dart`

**Purpose:** Reusable test data builders

**Contents:**
- Pre-defined user IDs (Alice, Bob)
- Quest factories (pending, in_progress, completed)
- Quiz session factories
- Date utilities (consistent date keys)

**Benefits:**
- Write tests 3x faster
- Consistent test data
- Reduce boilerplate
- Easy to extend

---

#### Step 2: Create Hive Test Helpers (30 minutes)

**File:** `app/test/helpers/hive_test_helper.dart`

**Purpose:** Reusable Hive setup/teardown

**Contents:**
- Setup temp directory
- Register all adapters
- Open boxes
- Clear boxes between tests
- Cleanup on teardown

**Benefits:**
- Follow same pattern as `memory_flip_service_test.dart`
- Reusable across all future tests
- Consistent test isolation

---

#### Step 3: Unit Tests for `DailyQuestService` (2-3 hours)

**File:** `app/test/daily_quest_service_test.dart`

**Test Groups:**

1. **Quest Completion Logic (5 tests)**
   - First user completion → status `in_progress`
   - Second user completion → status `completed` + LP awarded
   - Cannot complete same quest twice for same user
   - Both users completion detection
   - Daily completion record updates when all 3 done

2. **Quest Status Queries (4 tests)**
   - `getQuestStatus()` returns `your_turn` when pending
   - Returns `waiting` when user done, partner not
   - Returns `completed` when both done
   - Returns `expired` when past `expiresAt`

3. **Streak Calculation (4 tests)**
   - `getCurrentStreak()` returns 0 when no completions
   - Calculates consecutive days correctly (3 day streak)
   - Streak breaks on missing day
   - Today-only completion = streak of 1

4. **Quest Retrieval (4 tests)**
   - `getTodayQuests()` returns today's quests
   - Returns empty list when none exist
   - Filters main vs side quests correctly
   - `getQuestsByDate()` retrieves specific date

5. **Statistics (3 tests)**
   - `getTotalLPEarned()` sums LP correctly
   - `areAllMainQuestsCompleted()` checks all 3
   - Quest counts (total, completed, pending)

**Total: 20+ tests covering 70% of quest logic**

---

#### Step 4: Basic Tests for `QuestTypeManager` (1 hour)

**File:** `app/test/quest_type_manager_test.dart`

**Test Cases:**
- Quiz quest provider generates valid quests
- Quest IDs are unique
- SortOrder assigned correctly (0, 1, 2)
- ContentId references quiz session
- Date key matches today
- ExpiresAt is end of day (23:59:59)

**Limitation:** Cannot test Firebase save behavior without emulator (future phase)

---

#### Step 5: Test Documentation (30 minutes)

**File:** `app/test/README.md`

**Contents:**
- How to run tests
- Test patterns and conventions
- How to add new tests
- Coverage report generation
- Troubleshooting common issues

---

### What This Achieves

✅ **Test ~70% of quest logic** without launching apps
✅ **Tests run in 1-2 seconds** (no Firebase, no emulators)
✅ **Prove the testing approach works** before bigger refactors
✅ **No architecture changes required** (uses existing design)
✅ **Foundation for future test expansion**
✅ **Catch quest bugs in CI/CD** before manual testing

### What We're NOT Doing (Out of Scope)

❌ Firebase emulator setup (Phase 2)
❌ Widget tests (requires DI refactor - Phase 2)
❌ Integration tests (needs emulator - Phase 2)
❌ Service interface abstractions (Phase 3)
❌ MockQuestSyncService (not needed for Phase 1)

---

## Future Enhancements (Phase 2+)

### Phase 2: Testing Infrastructure (Week 2, 10-12 hours)

#### 2.1 Firebase Emulator Setup (2-3 hours)

**Goal:** Test Firebase sync logic locally without hitting production

**Tasks:**
1. Configure `firebase.json` with emulator settings
2. Create `FirebaseTestHelper` for setup/teardown
3. Add npm scripts to start emulator
4. Write tests for `QuestSyncService` using emulator

**Benefits:**
- Test against real Firebase behavior (transactions, offline, etc.)
- No risk of corrupting production data
- Test race conditions safely
- Faster than production Firebase (local network)

---

#### 2.2 Service Abstractions (4-5 hours)

**Goal:** Enable mocking of Firebase services

**Tasks:**
1. Create `IQuestSyncService` interface
2. Implement `MockQuestSyncService`
3. Update service constructors to accept interfaces
4. Migrate tests to use mocks

**Benefits:**
- Test without Firebase entirely (even faster than emulator)
- Simulate network errors, delays, timeouts
- Test edge cases (corrupted data, missing fields)
- Complete control over test scenarios

---

#### 2.3 Widget Tests (3-4 hours)

**Goal:** Test UI states without launching app

**Tasks:**
1. Add DI to `DailyQuestsWidget` (optional service params)
2. Add DI to `QuestCard`
3. Write widget tests with mock services
4. Test partner completion events

**Benefits:**
- Test all UI states instantly
- Verify UI updates on partner completion
- Test loading, error, empty states
- Catch UI regressions before manual testing

---

### Phase 3: Integration & Advanced Testing (Week 3+, 8-10 hours)

#### 3.1 Integration Tests (4-5 hours)

**Goal:** Test full quest sync flow end-to-end

**Tests:**
- Alice generates quests, Bob loads them (verify same IDs)
- Quest completion syncs between devices
- Race condition handling (both generate simultaneously)
- Offline completion queuing

---

#### 3.2 Repository Pattern (Optional, 4-5 hours)

**Goal:** Abstract storage layer for easier testing

**Tasks:**
1. Create `IQuestRepository` interface
2. Implement `HiveQuestRepository` (current behavior)
3. Implement `MockQuestRepository` for tests
4. Migrate services to use repository

**Benefits:**
- Swap storage implementations (Hive → SQL, etc.)
- Test without Hive overhead
- Clean architecture principles

---

## Implementation Roadmap

### Phase 1: Foundation (This Week)
**Time:** 4-5 hours
**Priority:** HIGH
**Risk:** LOW

| Task | Time | Impact | Status |
|------|------|--------|--------|
| Create test fixtures | 30 min | High | Not Started |
| Create Hive test helpers | 30 min | High | Not Started |
| Unit tests for DailyQuestService | 2-3 hours | Very High | Not Started |
| Unit tests for QuestTypeManager | 1 hour | Medium | Not Started |
| Test documentation | 30 min | Medium | Not Started |

**Deliverable:** Can test 70% of quest logic without launching dual devices

---

### Phase 2: Infrastructure (Next 1-2 Weeks)
**Time:** 10-12 hours
**Priority:** MEDIUM
**Risk:** MEDIUM

| Task | Time | Impact | Dependencies |
|------|------|--------|--------------|
| Firebase emulator setup | 2-3 hours | High | None |
| Service interface abstractions | 4-5 hours | Very High | None |
| Widget tests with DI | 3-4 hours | High | Service abstractions |

**Deliverable:** Can test all UI states + Firebase sync logic locally

---

### Phase 3: Advanced (Future)
**Time:** 8-10 hours
**Priority:** LOW
**Risk:** HIGH

| Task | Time | Impact | Dependencies |
|------|------|--------|--------------|
| Integration tests | 4-5 hours | Medium | Firebase emulator |
| Repository pattern refactor | 4-5 hours | Low | Service abstractions |

**Deliverable:** Full test coverage including end-to-end flows

---

## Code Examples

### Example 1: Test Fixtures

```dart
// test/fixtures/quest_fixtures.dart
import 'package:togetherremind/models/daily_quest.dart';
import 'package:togetherremind/models/quiz.dart';

class QuestFixtures {
  // Pre-defined user IDs
  static const String aliceUserId = 'alice-test-user-id';
  static const String bobUserId = 'bob-test-user-id';
  static const String coupleId = 'alice-bob-couple-id';

  // Date utilities
  static String get todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static DateTime get endOfDay {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  // Quest factories
  static DailyQuest createPendingQuest({
    int sortOrder = 0,
    QuestType type = QuestType.quiz,
    String? contentId,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch + sortOrder;
    return DailyQuest(
      id: 'quest_${timestamp}_${type.name}',
      dateKey: todayKey,
      questType: type.index,
      contentId: contentId ?? 'quiz_session_$sortOrder',
      createdAt: DateTime.now(),
      expiresAt: endOfDay,
      status: 'pending',
      userCompletions: {},
      isSideQuest: false,
      sortOrder: sortOrder,
    );
  }

  static DailyQuest createInProgressQuest({
    required String userId,
    int sortOrder = 0,
  }) {
    final quest = createPendingQuest(sortOrder: sortOrder);
    quest.userCompletions = {userId: true};
    quest.status = 'in_progress';
    return quest;
  }

  static DailyQuest createCompletedQuest({
    required String userId1,
    required String userId2,
    int sortOrder = 0,
  }) {
    final quest = createPendingQuest(sortOrder: sortOrder);
    quest.userCompletions = {userId1: true, userId2: true};
    quest.status = 'completed';
    quest.completedAt = DateTime.now();
    quest.lpAwarded = 30;
    return quest;
  }

  // Quiz session factories
  static QuizSession createMockQuizSession({
    required String id,
    List<String>? questionIds,
    String? initiatedBy,
  }) {
    return QuizSession(
      id: id,
      questionIds: questionIds ?? ['q1', 'q2', 'q3', 'q4', 'q5'],
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(Duration(hours: 3)),
      status: 'active',
      initiatedBy: initiatedBy ?? aliceUserId,
      answers: [],
    );
  }
}
```

---

### Example 2: Hive Test Helper

```dart
// test/helpers/hive_test_helper.dart
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:togetherremind/models/daily_quest.dart';
import 'package:togetherremind/models/quiz.dart';

class HiveTestHelper {
  static Directory? _tempDir;

  /// Setup Hive with temp directory for testing
  static Future<void> setup() async {
    _tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(_tempDir!.path);

    // Register adapters (only register once)
    if (!Hive.isAdapterRegistered(17)) {
      Hive.registerAdapter(DailyQuestAdapter());
    }
    if (!Hive.isAdapterRegistered(18)) {
      Hive.registerAdapter(DailyQuestCompletionAdapter());
    }
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(QuizSessionAdapter());
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(QuizProgressionStateAdapter());
    }

    // Open boxes
    await Hive.openBox<DailyQuest>('daily_quests');
    await Hive.openBox<DailyQuestCompletion>('daily_quest_completions');
    await Hive.openBox<QuizSession>('quiz_sessions');
    await Hive.openBox('app_metadata');
  }

  /// Clear all boxes (call in tearDown)
  static Future<void> clear() async {
    await Hive.box<DailyQuest>('daily_quests').clear();
    await Hive.box<DailyQuestCompletion>('daily_quest_completions').clear();
    await Hive.box<QuizSession>('quiz_sessions').clear();
    await Hive.box('app_metadata').clear();
  }

  /// Cleanup (call in tearDownAll)
  static Future<void> cleanup() async {
    await Hive.close();
    if (_tempDir != null && await _tempDir!.exists()) {
      await _tempDir!.delete(recursive: true);
      _tempDir = null;
    }
  }
}
```

---

### Example 3: DailyQuestService Unit Test

```dart
// test/daily_quest_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherremind/services/daily_quest_service.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'helpers/hive_test_helper.dart';
import 'fixtures/quest_fixtures.dart';

void main() {
  late DailyQuestService service;
  late StorageService storage;

  setUpAll(() async {
    await HiveTestHelper.setup();
  });

  tearDownAll(() async {
    await HiveTestHelper.cleanup();
  });

  setUp(() {
    storage = StorageService();
    service = DailyQuestService(
      storage: storage,
      questSyncService: null,  // Skip Firebase for unit tests!
    );
  });

  tearDown() async {
    await HiveTestHelper.clear();
  });

  group('Quest Completion Logic', () {
    test('First user completion marks quest as in_progress', () async {
      // Arrange
      final quest = QuestFixtures.createPendingQuest(sortOrder: 0);
      await storage.saveDailyQuest(quest);

      // Act
      final bothCompleted = await service.completeQuestForUser(
        questId: quest.id,
        userId: QuestFixtures.aliceUserId,
      );

      // Assert
      expect(bothCompleted, isFalse);

      final updated = storage.getDailyQuest(quest.id)!;
      expect(updated.status, 'in_progress');
      expect(updated.hasUserCompleted(QuestFixtures.aliceUserId), isTrue);
      expect(updated.lpAwarded, isNull);
      expect(updated.completedAt, isNull);
    });

    test('Second user completion marks quest as completed', () async {
      // Arrange
      final quest = QuestFixtures.createInProgressQuest(
        userId: QuestFixtures.aliceUserId,
        sortOrder: 0,
      );
      await storage.saveDailyQuest(quest);

      // Act
      final bothCompleted = await service.completeQuestForUser(
        questId: quest.id,
        userId: QuestFixtures.bobUserId,
      );

      // Assert
      expect(bothCompleted, isTrue);

      final updated = storage.getDailyQuest(quest.id)!;
      expect(updated.status, 'completed');
      expect(updated.hasUserCompleted(QuestFixtures.bobUserId), isTrue);
      expect(updated.lpAwarded, 30);
      expect(updated.completedAt, isNotNull);
    });

    test('Cannot complete same quest twice for same user', () async {
      // Arrange
      final quest = QuestFixtures.createInProgressQuest(
        userId: QuestFixtures.aliceUserId,
        sortOrder: 0,
      );
      await storage.saveDailyQuest(quest);

      // Act - Try to complete again
      final result = await service.completeQuestForUser(
        questId: quest.id,
        userId: QuestFixtures.aliceUserId,
      );

      // Assert
      expect(result, isFalse);  // Should return false
    });
  });

  group('Quest Status Queries', () {
    test('getQuestStatus returns your_turn when user has not completed', () {
      // Arrange
      final quest = QuestFixtures.createPendingQuest();

      // Act
      final status = service.getQuestStatus(quest, QuestFixtures.aliceUserId);

      // Assert
      expect(status, 'your_turn');
    });

    test('getQuestStatus returns waiting when user completed but partner has not', () {
      // Arrange
      final quest = QuestFixtures.createInProgressQuest(
        userId: QuestFixtures.aliceUserId,
      );

      // Act
      final status = service.getQuestStatus(quest, QuestFixtures.aliceUserId);

      // Assert
      expect(status, 'waiting');
    });

    test('getQuestStatus returns completed when both users completed', () {
      // Arrange
      final quest = QuestFixtures.createCompletedQuest(
        userId1: QuestFixtures.aliceUserId,
        userId2: QuestFixtures.bobUserId,
      );

      // Act
      final status = service.getQuestStatus(quest, QuestFixtures.aliceUserId);

      // Assert
      expect(status, 'completed');
    });

    test('getQuestStatus returns expired when past expiresAt', () {
      // Arrange
      final quest = QuestFixtures.createPendingQuest();
      quest.expiresAt = DateTime.now().subtract(Duration(hours: 1));

      // Act
      final status = service.getQuestStatus(quest, QuestFixtures.aliceUserId);

      // Assert
      expect(status, 'expired');
    });
  });

  group('Quest Retrieval', () {
    test('getTodayQuests returns empty list when no quests exist', () {
      // Act
      final quests = service.getTodayQuests();

      // Assert
      expect(quests, isEmpty);
    });

    test('getTodayQuests returns only today\'s quests', () async {
      // Arrange
      final todayQuest = QuestFixtures.createPendingQuest(sortOrder: 0);
      await storage.saveDailyQuest(todayQuest);

      final yesterday = DateTime.now().subtract(Duration(days: 1));
      final yesterdayQuest = QuestFixtures.createPendingQuest(sortOrder: 0);
      yesterdayQuest.dateKey = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      await storage.saveDailyQuest(yesterdayQuest);

      // Act
      final quests = service.getTodayQuests();

      // Assert
      expect(quests.length, 1);
      expect(quests[0].id, todayQuest.id);
    });

    test('getTodayQuests filters out side quests', () async {
      // Arrange
      final mainQuest = QuestFixtures.createPendingQuest(sortOrder: 0);
      mainQuest.isSideQuest = false;
      await storage.saveDailyQuest(mainQuest);

      final sideQuest = QuestFixtures.createPendingQuest(sortOrder: 3);
      sideQuest.isSideQuest = true;
      await storage.saveDailyQuest(sideQuest);

      // Act
      final quests = service.getTodayQuests();

      // Assert
      expect(quests.length, 1);
      expect(quests[0].isSideQuest, isFalse);
    });
  });

  group('Streak Calculation', () {
    test('getCurrentStreak returns 0 when no completions exist', () {
      // Act
      final streak = service.getCurrentStreak();

      // Assert
      expect(streak, 0);
    });

    test('getCurrentStreak calculates consecutive days correctly', () async {
      // Arrange - Create completions for last 3 days
      final today = DateTime.now();
      for (int i = 0; i < 3; i++) {
        final date = today.subtract(Duration(days: i));
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        final completion = DailyQuestCompletion(
          dateKey: dateKey,
          questsCompleted: 3,
          allQuestsCompleted: true,
          completedAt: date,
          totalLpEarned: 90,
          sideQuestsCompleted: 0,
        );
        await storage.saveDailyQuestCompletion(completion);
      }

      // Act
      final streak = service.getCurrentStreak();

      // Assert
      expect(streak, 3);
    });

    test('getCurrentStreak breaks on missing day', () async {
      // Arrange
      final today = DateTime.now();

      // Today completed
      final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final todayCompletion = DailyQuestCompletion(
        dateKey: todayKey,
        questsCompleted: 3,
        allQuestsCompleted: true,
        completedAt: today,
        totalLpEarned: 90,
        sideQuestsCompleted: 0,
      );
      await storage.saveDailyQuestCompletion(todayCompletion);

      // Skip yesterday

      // Day before yesterday completed
      final twoDaysAgo = today.subtract(Duration(days: 2));
      final oldKey = '${twoDaysAgo.year}-${twoDaysAgo.month.toString().padLeft(2, '0')}-${twoDaysAgo.day.toString().padLeft(2, '0')}';
      final oldCompletion = DailyQuestCompletion(
        dateKey: oldKey,
        questsCompleted: 3,
        allQuestsCompleted: true,
        completedAt: twoDaysAgo,
        totalLpEarned: 90,
        sideQuestsCompleted: 0,
      );
      await storage.saveDailyQuestCompletion(oldCompletion);

      // Act
      final streak = service.getCurrentStreak();

      // Assert - Streak should be 1 (only today)
      expect(streak, 1);
    });
  });
}
```

---

### Example 4: Test Documentation

```markdown
// test/README.md
# TogetherRemind Test Suite

## Running Tests

### Run all tests
```bash
cd app
flutter test
```

### Run specific test file
```bash
flutter test test/daily_quest_service_test.dart
```

### Run tests with coverage
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Run tests matching pattern
```bash
flutter test --name "Quest Completion"
```

## Test Organization

```
test/
├── fixtures/
│   └── quest_fixtures.dart        # Reusable test data builders
├── helpers/
│   └── hive_test_helper.dart      # Hive setup/teardown utilities
├── daily_quest_service_test.dart  # Quest logic unit tests
├── quest_type_manager_test.dart   # Quest generation tests
└── README.md                      # This file
```

## Testing Patterns

### Pattern 1: Hive Setup/Teardown

```dart
void main() {
  setUpAll(() async {
    await HiveTestHelper.setup();  // One-time setup
  });

  tearDownAll(() async {
    await HiveTestHelper.cleanup();  // Final cleanup
  });

  setUp() {
    // Test-specific setup
  });

  tearDown() async {
    await HiveTestHelper.clear();  // Clear boxes between tests
  });
}
```

### Pattern 2: Using Test Fixtures

```dart
test('example test', () async {
  // Use fixtures instead of manual construction
  final quest = QuestFixtures.createPendingQuest(sortOrder: 0);
  final session = QuestFixtures.createMockQuizSession(id: 'quiz_1');

  // ... test logic
});
```

### Pattern 3: Testing Without Firebase

```dart
// Skip Firebase by passing null to questSyncService
final service = DailyQuestService(
  storage: storage,
  questSyncService: null,  // No Firebase calls!
);
```

## Troubleshooting

### "Box is already open" Error
- Make sure to call `await HiveTestHelper.clear()` in `tearDown`
- Ensure `await HiveTestHelper.cleanup()` is called in `tearDownAll`

### "Adapter not registered" Error
- Check that all adapters are registered in `HiveTestHelper.setup()`
- Verify adapter TypeIds match model definitions

### "Quest not found" Error
- Verify quest was saved to storage before retrieving
- Check date key matches today's date

## Adding New Tests

1. Create test file: `test/my_service_test.dart`
2. Import helpers: `helpers/hive_test_helper.dart`
3. Import fixtures: `fixtures/quest_fixtures.dart`
4. Follow setup/teardown pattern above
5. Write test groups and test cases
6. Run tests: `flutter test test/my_service_test.dart`
```

---

## Testing Commands

### Basic Commands

```bash
# Navigate to app directory
cd /Users/joakimachren/Desktop/togetherremind/app

# Run all tests
flutter test

# Run with verbose output
flutter test --reporter expanded

# Run specific test file
flutter test test/daily_quest_service_test.dart

# Run tests matching name pattern
flutter test --name "Quest Completion"

# Run tests matching file pattern
flutter test test/services/

# Run widget tests only
flutter test test/widgets/
```

### Coverage Commands

```bash
# Generate coverage report
flutter test --coverage

# View coverage in HTML (macOS)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# View coverage in HTML (Linux)
genhtml coverage/lcov.info -o coverage/html
xdg-open coverage/html/index.html
```

### Watch Mode (Continuous Testing)

```bash
# Install entr (macOS)
brew install entr

# Watch test files and re-run on changes
find test -name "*.dart" | entr -c flutter test
```

### Debugging Tests

```bash
# Run tests with debug output
flutter test --verbose

# Run single test with debug
flutter test --name "First user completion" --verbose

# Run tests in IDE (VS Code)
# 1. Open test file
# 2. Click "Run" above test() or group()
# 3. Set breakpoints as needed
```

---

## Success Metrics

### Phase 1 Success Criteria

✅ **Coverage:** 70%+ test coverage for quest system
✅ **Speed:** Tests run in <5 seconds total
✅ **Reliability:** All tests pass consistently
✅ **Maintainability:** Tests follow consistent patterns
✅ **Documentation:** README explains how to add tests

### Quantitative Metrics

| Metric | Before | After Phase 1 | Target |
|--------|--------|---------------|--------|
| Test Coverage | 0% | 70% | 80%+ |
| Test Iteration Time | 5+ min | 2 sec | <5 sec |
| Manual Test Steps | 10+ | 0 | 0 |
| Edge Cases Tested | 0 | 10+ | 20+ |
| CI/CD Integration | ❌ | ✅ | ✅ |

### Qualitative Improvements

**Before:**
- Must launch Android + Chrome for every test
- Must manually clear Firebase data
- Cannot reproduce edge cases reliably
- Slow feedback loop discourages testing
- Hard to verify fixes quickly

**After Phase 1:**
- Run tests with single command: `flutter test`
- No manual setup required
- Edge cases tested automatically
- Instant feedback on changes
- Confident refactoring with test safety net

---

## Next Steps

### Immediate Action (This Week)

1. **Create fixtures:** `test/fixtures/quest_fixtures.dart`
2. **Create helpers:** `test/helpers/hive_test_helper.dart`
3. **Write first test:** Verify DailyQuestService completion logic works
4. **Iterate:** Add more tests until 70% coverage

### Command to Start

```bash
cd /Users/joakimachren/Desktop/togetherremind/app
mkdir -p test/fixtures test/helpers
touch test/fixtures/quest_fixtures.dart
touch test/helpers/hive_test_helper.dart
touch test/daily_quest_service_test.dart
```

### Validation

After implementing Phase 1, run:

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

Verify coverage report shows 70%+ for quest-related files.

---

## References

- [QUEST_SYSTEM.md](./QUEST_SYSTEM.md) - Comprehensive quest system documentation
- [Flutter Testing Docs](https://docs.flutter.dev/testing)
- [Hive Testing Guide](https://docs.hivedb.dev/#/advanced/testing)
- [memory_flip_service_test.dart](../../app/test/memory_flip_service_test.dart) - Example of excellent test patterns

---

**Last Updated:** 2025-11-14
**Author:** Quest System Testing Strategy
**Version:** 1.0.0

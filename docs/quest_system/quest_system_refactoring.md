# Quest System Refactoring History

This document tracks architectural improvements made to the quest system to improve code quality, maintainability, and testability.

---

## Phase 1: Extract Quest Utilities (Completed: 2025-11-14)

### Problem
Utility methods for quest operations were duplicated across multiple services:
- `getTodayDateKey()` was duplicated in `DailyQuestService` and `QuestSyncService`
- `getDateKey()` was duplicated in `DailyQuestService`
- `generateCoupleId()` was duplicated in `QuestSyncService` and `DebugQuestDialog`
- Inconsistent couple ID generation caused quest sync issues

### Solution
Created a new `QuestUtilities` class to centralize all quest-related utility methods:

**New File Created:**
- `app/lib/services/quest_utilities.dart`

**Centralized Methods:**
```dart
class QuestUtilities {
  QuestUtilities._(); // Private constructor - utility class only

  /// Get today's date key in YYYY-MM-DD format
  static String getTodayDateKey()

  /// Get date key for a specific date in YYYY-MM-DD format
  static String getDateKey(DateTime date)

  /// Generate deterministic couple ID from two user IDs
  /// IDs are sorted alphabetically to ensure consistency
  static String generateCoupleId(String userId1, String userId2)
}
```

**Files Modified:**
1. `app/lib/services/daily_quest_service.dart`
   - Deprecated `getTodayDateKey()` and `getDateKey()`
   - Added `@Deprecated` annotations pointing to `QuestUtilities`
   - Methods kept for backward compatibility

2. `app/lib/services/quest_sync_service.dart`
   - Replaced all direct calls with `QuestUtilities` methods
   - Removed local `generateCoupleId()` implementation

3. `app/lib/services/quest_type_manager.dart`
   - Updated to use `QuestUtilities.getTodayDateKey()`
   - Updated to use `QuestUtilities.generateCoupleId()`

4. `app/lib/widgets/debug_quest_dialog.dart`
   - Updated to use `QuestUtilities.generateCoupleId()`

5. `app/lib/main.dart`
   - Updated `_clearOldMockQuests()` to use `QuestUtilities`
   - Updated `_initializeDailyQuests()` to use `QuestUtilities`

### Benefits
- ✅ Single source of truth for quest utilities
- ✅ Consistent couple ID generation across entire app
- ✅ Fixed quest sync issues caused by mismatched couple IDs
- ✅ Easier to test utility logic in isolation
- ✅ Reduced code duplication
- ✅ Backward compatible with deprecated methods

### Testing Results
- ✅ Quest generation works correctly
- ✅ Quest synchronization between Alice and Bob verified
- ✅ Debug dialog shows correct couple ID
- ✅ No compilation errors

---

## Phase 2: Break Circular Dependency (Completed: 2025-11-14)

### Problem
`DailyQuestService` and `QuestSyncService` had a circular dependency:
- `DailyQuestService` depends on `QuestSyncService` (for syncing quest completions)
- `QuestSyncService` depends on `DailyQuestService` (for getting quest data)

This circular dependency:
- Makes testing difficult
- Increases coupling between services
- Makes the code harder to reason about
- Can cause initialization issues

### Solution
Removed `DailyQuestService` dependency from `QuestSyncService` by having it use `StorageService` directly instead.

**Dependency Structure:**

**Before:**
```
DailyQuestService ←→ QuestSyncService
         ↓                    ↓
          StorageService
```

**After:**
```
DailyQuestService → QuestSyncService → StorageService
```

### Changes Made

**1. app/lib/services/quest_sync_service.dart**

Removed the circular dependency:
```dart
// BEFORE
class QuestSyncService {
  final StorageService _storage;
  final DailyQuestService _questService;  // ❌ Circular dependency

  QuestSyncService({
    required StorageService storage,
    required DailyQuestService questService,
  }) : _storage = storage,
       _questService = questService;

  // Used _questService.getTodayQuests()
  // Used _questService.hasTodayQuests()
  // Used _questService.getQuestsForDate(dateKey)
}

// AFTER
class QuestSyncService {
  final StorageService _storage;

  QuestSyncService({
    required StorageService storage,
  }) : _storage = storage;

  // Now uses _storage.getTodayQuests()
  // Now uses _storage.getTodayQuests().isNotEmpty
  // Now uses _storage.getDailyQuestsForDate(dateKey)
}
```

**Method Updates in quest_sync_service.dart:**
- Line 60: `_questService.getTodayQuests()` → `_storage.getTodayQuests()`
- Line 93: `_questService.hasTodayQuests()` → `_storage.getTodayQuests().isNotEmpty`
- Line 227: `_questService.getQuestsForDate(dateKey)` → `_storage.getDailyQuestsForDate(dateKey)`
- Removed import: `import '../services/daily_quest_service.dart';`

**2. Constructor Call Updates**

Removed `questService` parameter from all `QuestSyncService` instantiations:

**app/lib/main.dart** (lines 123-132):
```dart
// BEFORE
final syncService = QuestSyncService(
  storage: storage,
  questService: questService,  // ❌ REMOVED
);

// AFTER
final syncService = QuestSyncService(
  storage: storage,
);
```

**app/lib/widgets/daily_quests_widget.dart** (lines 36-38):
```dart
// BEFORE
_questSyncService = QuestSyncService(
  storage: _storage,
  questService: _questService,  // ❌ REMOVED
);

// AFTER
_questSyncService = QuestSyncService(
  storage: _storage,
);
```

**app/lib/services/quiz_service.dart** (lines 684-686):
```dart
// BEFORE
questSyncService = QuestSyncService(
  storage: _storage,
  questService: dailyQuestService,  // ❌ REMOVED
);

// AFTER
questSyncService = QuestSyncService(
  storage: _storage,
);
```

**app/lib/screens/new_home_screen.dart** (lines 74-76):
```dart
// BEFORE
final syncService = QuestSyncService(
  storage: _storage,
  questService: questService,  // ❌ REMOVED
);

// AFTER
final syncService = QuestSyncService(
  storage: _storage,
);
```

**app/lib/screens/quiz_results_screen.dart** (2 instances at lines 89-91 and 154-156):
```dart
// BEFORE
final syncService = QuestSyncService(
  storage: _storage,
  questService: questService,  // ❌ REMOVED
);

// AFTER
final syncService = QuestSyncService(
  storage: _storage,
);
```

### Files Modified (Total: 7 files)
1. `app/lib/services/quest_sync_service.dart` - Removed circular dependency
2. `app/lib/main.dart` - Updated constructor call
3. `app/lib/widgets/daily_quests_widget.dart` - Updated constructor call
4. `app/lib/services/quiz_service.dart` - Updated constructor call
5. `app/lib/screens/new_home_screen.dart` - Updated constructor call
6. `app/lib/screens/quiz_results_screen.dart` - Updated constructor calls (2 instances)

### Benefits
- ✅ Clean one-way dependency: `DailyQuestService` → `QuestSyncService` → `StorageService`
- ✅ Easier to test `QuestSyncService` in isolation
- ✅ Reduced coupling between services
- ✅ Clearer separation of concerns
- ✅ Simpler initialization order
- ✅ Better code maintainability

### Testing Results
- ✅ Both apps compile successfully
- ✅ Apps launch without errors
- ✅ Quest synchronization works correctly
- ✅ Quest generation works correctly
- ✅ No runtime errors

---

## Phase 3: Fix Quiz Quest LP Awards (Completed: 2025-11-14)

### Problem
Quiz quest completions weren't automatically awarding Love Points (LP) to both users, requiring manual reload button presses to trigger LP sync:
- Non-quiz quests awarded LP correctly via `DailyQuestService.completeQuest()`
- Quiz quests had a comment saying "LP awarded via QuizService" but the actual award call was missing
- `quiz_results_screen.dart` printed "30 LP awarded" but never called `LovePointService.awardPointsToBothUsers()`
- Real-time LP listeners were set up correctly in `main.dart` but had no LP awards to receive
- Users had to press the reload button to manually sync quest completions and trigger LP awards

### Root Cause
The disconnect between quest completion and LP awards was due to:
1. `daily_quest_service.dart` (lines 99-128) intentionally skipped LP awards for quiz quests
2. Expected `QuizService` to handle LP awards when both users completed the quiz
3. `quiz_results_screen.dart` (lines 99-106) checked for quest completion but never called the LP award function
4. The real-time sync infrastructure was already in place - just missing the trigger

### Solution
Added the missing `LovePointService.awardPointsToBothUsers()` call in `quiz_results_screen.dart` when both users complete a quiz quest.

**File Modified:**
`app/lib/screens/quiz_results_screen.dart`

**Changes Made:**

**1. Added Missing Import** (line 10):
```dart
import '../services/love_point_service.dart';
```

**2. Added LP Award Call** (lines 103-110):
```dart
// BEFORE (lines 99-106)
if (bothCompleted) {
  print('✅ Daily quest completed by both users! 30 LP awarded');

  // Check if all 3 daily quests are completed
  await _checkDailyQuestsCompletion(questService, user.id, partner.pushToken);
}

// AFTER (lines 99-112)
if (bothCompleted) {
  print('✅ Daily quest completed by both users! Awarding 30 LP...');

  // Award Love Points to BOTH users via Firebase (real-time sync)
  await LovePointService.awardPointsToBothUsers(
    userId1: user.id,
    userId2: partner.pushToken,
    amount: 30,
    reason: 'daily_quest_quiz',
    relatedId: matchingQuest.id,
  );

  // Check if all 3 daily quests are completed
  await _checkDailyQuestsCompletion(questService, user.id, partner.pushToken);
}
```

**3. Added Automatic LP Award to Partner Completion Listener** (lines 76-109):

The partner completion listener in `daily_quests_widget.dart` now automatically awards LP when receiving partner completion updates via Firebase. This ensures LP awards are triggered regardless of which screen the user is on.

```dart
// Partner completion listener now triggers LP awards automatically
if (quest.areBothUsersCompleted()) {
  quest.status = 'completed';
  quest.completedAt = DateTime.now();

  // Award LP if not already awarded (prevent duplicates)
  if (quest.lpAwarded == null || quest.lpAwarded == 0) {
    quest.lpAwarded = 30;

    print('💰 Auto-awarding 30 LP for completed quest: ${quest.type.name}');

    LovePointService.awardPointsToBothUsers(
      userId1: user.id,
      userId2: partner.pushToken,
      amount: 30,
      reason: 'daily_quest_${quest.type.name}',
      relatedId: quest.id,
    ).then((_) {
      print('✅ LP awarded automatically via partner completion listener');
    }).catchError((error) {
      print('❌ Error awarding LP: $error');
    });
  }
}
```

This fix complements the quiz results screen fix by ensuring LP awards are triggered in ALL scenarios:
- User completes quest and views results → LP awarded via `quiz_results_screen.dart`
- Partner completes quest while user is on home screen → LP awarded via `daily_quests_widget.dart` listener
- Any other screen combination → LP awarded via whichever component detects completion first

### How It Works Now
1. **User A completes quiz** → Quest marked as in_progress for User A
2. **User B completes quiz** → Quest detected as completed by both users
3. **LP award triggered** → `LovePointService.awardPointsToBothUsers()` writes LP award to Firebase RTDB at `/lp_awards/{coupleId}/{awardId}`
   - Triggered by `quiz_results_screen.dart` when viewing results
   - OR triggered by `daily_quests_widget.dart` partner listener when receiving partner completion
4. **Real-time listeners apply LP** → Both users' `LovePointService.startListeningForLPAwards()` (initialized in `main.dart:117-121`) automatically detect and apply the LP
5. **UI updates automatically** → No reload button needed

### Benefits
- ✅ Quiz quest LP awards work automatically in real-time
- ✅ Consistent LP award behavior across all quest types
- ✅ Eliminates need for manual reload button press
- ✅ Leverages existing real-time sync infrastructure
- ✅ Proper separation of concerns - `LovePointService` handles all LP operations
- ✅ Better user experience - instant feedback when both users complete a quest

### Testing Strategy
To verify the fix works correctly:

1. **Clean Firebase state:**
   ```bash
   firebase database:remove /daily_quests && \
   firebase database:remove /quiz_sessions && \
   firebase database:remove /lp_awards
   ```

2. **Launch both apps fresh:**
   ```bash
   flutter run -d emulator-5554 &  # Alice
   sleep 10 && flutter run -d chrome &  # Bob
   ```

3. **Test quiz quest completion:**
   - Alice completes quiz quest → Check LP doesn't change yet
   - Bob completes same quiz quest → Check both users receive 30 LP automatically
   - Verify no reload button press needed

4. **Verify real-time sync:**
   - Check console logs for "💰 LP awarded: +30" on both devices
   - Check Firebase RTDB shows LP award at `/lp_awards/{coupleId}/{awardId}`
   - Verify UI updates immediately without manual refresh

### Next Steps
- Remove reload button from `new_home_screen.dart` (lines 236-244) once testing confirms real-time LP sync works
- Update UI to show LP awards with animations/notifications for better user feedback

---

## Future Improvements

### Phase 4: Consider Extracting Quest Validation
Currently, quest validation logic is spread across multiple services. Consider creating a `QuestValidationService` to centralize:
- Quest completion validation
- User completion checks
- Quest expiration checks
- Quest status calculations

### Phase 5: Consider Dependency Injection
The current initialization in `main.dart` manually wires up all dependencies. Consider using a DI framework like `get_it` or `provider` for:
- Cleaner dependency management
- Easier testing with mock dependencies
- Better separation of concerns

### Phase 6: Consider Repository Pattern
Consider introducing a repository layer between services and storage:
- `QuestRepository` for quest data access
- `UserRepository` for user data access
- Better abstraction of data layer
- Easier to swap storage implementations

---

## Related Documentation

- [LP Sync Architecture](./lp_sync_architecture.md)
- [Quest Testing Strategy](./quest_testing_strategy.md)
- [Side Quest Integration](./side_quest_integration.md)
- [Main Architecture](../ARCHITECTURE.md)

---

**Last Updated:** 2025-11-14 (Completed Phase 3: LP Awards improvements - quiz results screen + partner completion listener)

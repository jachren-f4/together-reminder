# Quest Title Display Synchronization Issue

**Date:** 2025-11-15
**Issue Type:** Cross-device data synchronization bug
**Severity:** High (user-facing inconsistency)
**Status:** ✅ Resolved

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Problem Description](#problem-description)
3. [Root Cause Analysis](#root-cause-analysis)
4. [Technical Deep Dive](#technical-deep-dive)
5. [Solution Implementation](#solution-implementation)
6. [Affected Components](#affected-components)
7. [Lessons Learned](#lessons-learned)
8. [Related Documentation](#related-documentation)

---

## Executive Summary

### The Problem
When displaying daily quest titles in the UI, Bob (the second device) showed incorrect titles for affirmation quizzes, while Alice (the first device) displayed them correctly. This created a confusing user experience where partners saw different quest names for the same shared content.

**Example:**
- **Alice saw:** AFFIRMATION - "Gentle Beginnings"
- **Bob saw:** QUIZ - "Deeper Connection" (wrong quest title)

### The Root Cause
UI components were looking up quiz sessions from local storage to determine quest titles. Since Bob never created the quiz sessions (Alice did), Bob's local storage didn't contain the session data, causing the title lookup to fail and fall through to incorrect default titles.

### The Solution
Added a `quizName` field directly to the `DailyQuest` model that syncs via Firebase RTDB, eliminating the need for session lookups. This ensures both devices have immediate access to quest metadata without requiring the full quiz session data.

---

## Problem Description

### Symptom 1: Main Screen (Daily Quests Widget)
**Location:** `lib/widgets/daily_quests_widget.dart`
**Observed Behavior:**
- Alice: Shows correct quest types and titles (Quiz → Affirmation → Quiz)
- Bob: Shows all three quests as regular quizzes with wrong titles

**User Impact:** Bob couldn't distinguish affirmation quizzes from classic quizzes on the main screen.

### Symptom 2: Inbox Screen (Activity Feed)
**Location:** `lib/services/activity_service.dart`
**Observed Behavior:**
- Alice: Activity items show "Gentle Beginnings" for completed affirmation quiz
- Bob: Activity items show "Deeper Connection" (wrong classic quiz title)

**User Impact:** Bob's activity feed showed incorrect quest completion notifications.

### Why This Happened Asymmetrically

The issue only affected Bob because of the **"first user creates, second user loads"** architecture pattern used in the quest system:

1. **Alice (Android)** launches first
   - Generates 3 daily quests via `QuestTypeManager.generateDailyQuests()`
   - Creates quiz sessions via `QuizService.startQuizSession()`
   - Stores sessions locally in Hive: `_storage.saveQuizSession(session)`
   - Syncs quest metadata to Firebase RTDB
   - **Alice has both quests AND sessions in local storage** ✅

2. **Bob (Chrome)** launches second
   - Loads quest metadata from Firebase via `QuestSyncService.syncTodayQuests()`
   - Stores quests locally in Hive
   - **Does NOT load quiz sessions from Firebase**
   - **Bob has quests but NO sessions in local storage** ❌

---

## Root Cause Analysis

### The Flawed Logic Pattern

Multiple UI components used this pattern to determine quest titles:

```dart
// ❌ BROKEN: Looks up session from local storage
String _getQuestTitle(DailyQuest quest) {
  if (quest.type == QuestType.quiz) {
    // Try to get quiz name from session
    final session = StorageService().getQuizSession(quest.contentId);

    if (session != null && session.formatType == 'affirmation') {
      return session.quizName!;  // Only works for Alice!
    }

    // Fallback to classic quiz titles
    const titles = ['Getting to Know You', 'Deeper Connection', 'Understanding Each Other'];
    return titles[quest.sortOrder];  // Bob falls through here!
  }
}
```

### Why Bob Got "Deeper Connection"

1. Bob's affirmation quest has `sortOrder = 1` (second quest in the daily lineup)
2. Session lookup returns `null` (Bob doesn't have the session)
3. Code falls through to classic quiz title array
4. Returns `titles[1]` = **"Deeper Connection"** (wrong title for position 2)

### The Architectural Problem

**Issue:** Quest metadata (title, format type) was split across two data structures:
- `DailyQuest` model: Basic quest info (contentId, sortOrder, status)
- `QuizSession` model: Detailed quiz info (questions, answers, quizName, formatType)

**Problem:** Only `DailyQuest` synced via Firebase. `QuizSession` was only stored locally by the creating device.

**Result:** Partner device couldn't access quiz metadata without the full session.

---

## Technical Deep Dive

### Data Flow Before Fix

```
┌─────────────────────────────────────────────────────────────┐
│ ALICE (Android - Quest Generator)                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Generate Quest                                           │
│     ├─ Create QuizSession                                    │
│     │  └─ quizName: "Gentle Beginnings"                     │
│     │  └─ formatType: "affirmation"                         │
│     └─ Save to Hive: _storage.saveQuizSession(session)      │
│                                                              │
│  2. Create DailyQuest                                        │
│     ├─ contentId: [session.id]                              │
│     ├─ sortOrder: 1                                          │
│     └─ formatType: "affirmation" ✅                          │
│                                                              │
│  3. Sync to Firebase                                         │
│     └─ /daily_quests/{coupleId}/{dateKey}/quests            │
│        └─ { contentId, formatType, sortOrder, ... }         │
│        └─ ❌ NO quizName field!                             │
│                                                              │
│  4. Display UI                                               │
│     ├─ Look up session in local Hive storage                │
│     └─ ✅ SUCCESS: session found → "Gentle Beginnings"      │
│                                                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ BOB (Chrome - Quest Loader)                                 │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Load from Firebase                                       │
│     └─ /daily_quests/{coupleId}/{dateKey}/quests            │
│        └─ { contentId, formatType, sortOrder, ... }         │
│        └─ ❌ NO quizName field!                             │
│                                                              │
│  2. Store DailyQuest locally                                 │
│     ├─ contentId: [session.id from Alice]                   │
│     ├─ sortOrder: 1                                          │
│     └─ formatType: "affirmation" ✅                          │
│                                                              │
│  3. Display UI                                               │
│     ├─ Look up session in local Hive storage                │
│     ├─ ❌ FAILURE: session NOT found (Alice created it)     │
│     └─ Falls back to titles[sortOrder] → "Deeper Connection"│
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Why Sessions Weren't Synced

Quiz sessions are stored in Firebase at `/quiz_sessions/{emulatorId}/{sessionId}` but:
1. `QuestSyncService` only syncs quest metadata, not full sessions
2. Loading full quiz sessions for all daily quests would be inefficient
3. Sessions contain answer data, question IDs, and scoring logic (not needed for title display)

**Design Decision:** Keep quest sync lightweight - only sync metadata needed for display.

---

## Solution Implementation

### Step 1: Add `quizName` Field to DailyQuest Model

**File:** `lib/models/daily_quest.dart`

```dart
@HiveType(typeId: 17)
class DailyQuest extends HiveObject {
  // ... existing fields ...

  @HiveField(12, defaultValue: 'classic')
  String formatType; // 'classic', 'affirmation', 'speed_round', etc.

  @HiveField(13)  // ✅ NEW FIELD
  String? quizName; // Quiz name for display (e.g., "Warm Vibes")

  DailyQuest({
    // ... existing params ...
    this.formatType = 'classic',
    this.quizName,  // ✅ Added to constructor
  });
}
```

**Key Points:**
- Used `HiveField(13)` to add field to existing model
- Made field nullable (`String?`) for backward compatibility
- No `defaultValue` needed (null is acceptable for classic quizzes)

### Step 2: Extract quizName During Quest Generation

**File:** `lib/services/quest_type_manager.dart`

```dart
if (contentId != null) {
  debugPrint('✅ Quest ${i + 1} content created: $contentId');

  // Get format type and quiz name from quiz session
  String formatType = 'classic';
  String? quizName;  // ✅ NEW

  final session = _storage.getQuizSession(contentId);
  if (session != null) {
    if (session.formatType != null) {
      formatType = session.formatType!;
    }
    quizName = session.quizName; // ✅ Extract quiz name for display
  }

  final quest = DailyQuest.create(
    dateKey: dateKey,
    type: QuestType.quiz,
    contentId: contentId,
    sortOrder: i,
    isSideQuest: false,
    formatType: formatType,
    quizName: quizName,  // ✅ Pass to quest
  );
}
```

**Why This Works:**
- Alice (quest generator) has access to the session she just created
- Extracts `quizName` from session during quest creation
- Stores it directly in the `DailyQuest` object

### Step 3: Sync quizName to Firebase

**File:** `lib/services/quest_sync_service.dart`

**Serialization (Alice → Firebase):**
```dart
// Convert quests to JSON
final questsData = quests.map((q) => {
  'id': q.id,
  'questType': q.questType,
  'contentId': q.contentId,
  'sortOrder': q.sortOrder,
  'isSideQuest': q.isSideQuest,
  'formatType': q.formatType,
  'quizName': q.quizName,  // ✅ Sync to Firebase
}).toList();
```

**Deserialization (Firebase → Bob):**
```dart
final quest = DailyQuest(
  id: questId,
  dateKey: dateKey,
  questType: questMap['questType'] as int,
  contentId: questMap['contentId'] as String,
  // ... other fields ...
  formatType: questMap['formatType'] as String? ?? 'classic',
  quizName: questMap['quizName'] as String?,  // ✅ Load from Firebase
  userCompletions: userCompletions,
);
```

**Firebase Data Structure After Fix:**
```json
{
  "daily_quests": {
    "alice-bob-couple-id": {
      "2025-11-15": {
        "quests": [
          {
            "id": "quest_1763187645855_quiz",
            "contentId": "05355fa1-ec7d-432b-9d14-cf0bba2d95bc",
            "formatType": "classic",
            "sortOrder": 0
          },
          {
            "id": "quest_1763187646238_quiz",
            "contentId": "25088dc3-1289-448c-909b-57ae9844fa73",
            "formatType": "affirmation",
            "quizName": "Gentle Beginnings",  // ✅ NOW SYNCED
            "sortOrder": 1
          },
          {
            "id": "quest_1763187646638_quiz",
            "contentId": "de746b94-d4ea-4230-b141-e7bc858cdbc7",
            "formatType": "classic",
            "sortOrder": 2
          }
        ]
      }
    }
  }
}
```

### Step 4: Update UI Components to Use quest.quizName

**File:** `lib/widgets/quest_card.dart`

**Before (Broken):**
```dart
String _getQuestTitle() {
  switch (quest.type) {
    case QuestType.quiz:
      if (quest.formatType == 'affirmation') {
        // ❌ Session lookup fails for Bob
        final session = StorageService().getQuizSession(quest.contentId);
        if (session != null && session.quizName != null) {
          return session.quizName!;
        }
        return 'Affirmation Quiz';  // Bob always gets this fallback
      }
      return _getQuizTitle(quest.sortOrder);
  }
}
```

**After (Fixed):**
```dart
String _getQuestTitle() {
  switch (quest.type) {
    case QuestType.quiz:
      if (quest.formatType == 'affirmation') {
        // ✅ Use quest.quizName (always available from Firebase)
        return quest.quizName ?? 'Affirmation Quiz';
      }
      return _getQuizTitle(quest.sortOrder);
  }
}
```

**File:** `lib/services/activity_service.dart`

**Before (Broken):**
```dart
String _getQuestTitle(DailyQuest quest) {
  switch (quest.questType) {
    case 1: // QuestType.quiz
      // ❌ Session lookup fails for Bob
      final session = _storage.getQuizSession(quest.contentId);
      if (session != null && session.formatType == 'affirmation' && session.quizName != null) {
        return session.quizName!;
      }
      // Bob falls through to here
      const titles = ['Getting to Know You', 'Deeper Connection', 'Understanding Each Other'];
      return titles[quest.sortOrder];  // Wrong title!
  }
}
```

**After (Fixed):**
```dart
String _getQuestTitle(DailyQuest quest) {
  switch (quest.questType) {
    case 1: // QuestType.quiz
      // ✅ Check formatType first (always available from Firebase)
      if (quest.formatType == 'affirmation') {
        // ✅ Use quest.quizName (synced from Firebase)
        return quest.quizName ?? 'Affirmation Quiz';
      }
      // Only classic quizzes reach here
      const titles = ['Getting to Know You', 'Deeper Connection', 'Understanding Each Other'];
      return titles[quest.sortOrder];
  }
}
```

### Step 5: Regenerate Hive Adapters

**Command:**
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

**Why Needed:**
Adding `@HiveField(13)` requires regenerating the `DailyQuestAdapter` to handle serialization/deserialization of the new field.

---

## Affected Components

### Files Modified

| File | Change | Reason |
|------|--------|--------|
| `lib/models/daily_quest.dart` | Added `quizName` field (HiveField 13) | Store quiz name directly in quest model |
| `lib/services/quest_type_manager.dart` | Extract `quizName` from session | Pass quiz name to DailyQuest.create() |
| `lib/services/quest_sync_service.dart` | Sync `quizName` to/from Firebase | Ensure both devices have access to quiz name |
| `lib/widgets/quest_card.dart` | Use `quest.quizName` instead of session lookup | Fix main screen display |
| `lib/services/activity_service.dart` | Use `quest.quizName` instead of session lookup | Fix inbox activity feed |
| `lib/widgets/daily_quests_widget.dart` | Use `quest.formatType` for affirmation detection | Fix quest type detection |

### Testing Locations

1. **Main Screen - Daily Quests Widget**
   - Quest type badges (QUIZ vs AFFIRMATION)
   - Quest titles (classic titles vs affirmation names)
   - Quest progress tracker

2. **Inbox Screen - Activity Feed**
   - Completed quest notifications
   - Quest title display in activity items

3. **Firebase RTDB - Data Verification**
   - Check `/daily_quests/{coupleId}/{dateKey}/quests`
   - Verify `quizName` field exists for affirmation quests

---

## Data Flow After Fix

```
┌─────────────────────────────────────────────────────────────┐
│ ALICE (Android - Quest Generator)                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Generate Quest                                           │
│     ├─ Create QuizSession                                    │
│     │  └─ quizName: "Gentle Beginnings"                     │
│     │  └─ formatType: "affirmation"                         │
│     └─ Save to Hive: _storage.saveQuizSession(session)      │
│                                                              │
│  2. Create DailyQuest                                        │
│     ├─ contentId: [session.id]                              │
│     ├─ sortOrder: 1                                          │
│     ├─ formatType: "affirmation" ✅                          │
│     └─ quizName: "Gentle Beginnings" ✅ NEW!                │
│                                                              │
│  3. Sync to Firebase                                         │
│     └─ /daily_quests/{coupleId}/{dateKey}/quests            │
│        └─ { contentId, formatType, quizName, sortOrder }    │
│        └─ ✅ quizName field now synced!                     │
│                                                              │
│  4. Display UI                                               │
│     ├─ Use quest.quizName directly                           │
│     └─ ✅ "Gentle Beginnings"                               │
│                                                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ BOB (Chrome - Quest Loader)                                 │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Load from Firebase                                       │
│     └─ /daily_quests/{coupleId}/{dateKey}/quests            │
│        └─ { contentId, formatType, quizName, sortOrder }    │
│        └─ ✅ quizName field loaded!                         │
│                                                              │
│  2. Store DailyQuest locally                                 │
│     ├─ contentId: [session.id from Alice]                   │
│     ├─ sortOrder: 1                                          │
│     ├─ formatType: "affirmation" ✅                          │
│     └─ quizName: "Gentle Beginnings" ✅ NEW!                │
│                                                              │
│  3. Display UI                                               │
│     ├─ Use quest.quizName directly                           │
│     └─ ✅ "Gentle Beginnings"                               │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Lessons Learned

### 1. **Avoid Cross-Storage Lookups in Multi-Device Sync**

**Problem:** UI components looked up related data from local storage, assuming all devices have the same local data.

**Lesson:** In a multi-device app with Firebase sync, always ensure all data needed for display is synced via Firebase. Don't rely on local-only data.

**Pattern to Avoid:**
```dart
// ❌ BAD: Assumes local storage has related data
final session = _storage.getQuizSession(quest.contentId);
return session.quizName;
```

**Better Pattern:**
```dart
// ✅ GOOD: Uses data synced via Firebase
return quest.quizName;
```

### 2. **Denormalize Display Metadata**

**Problem:** Quest titles required looking up full quiz sessions (which contain questions, answers, etc.).

**Lesson:** For display purposes, denormalize frequently-accessed metadata into the primary model. Avoid joins/lookups in UI code.

**Before:** DailyQuest → (lookup) → QuizSession → quizName
**After:** DailyQuest.quizName ✅

### 3. **Test Multi-Device Scenarios Early**

**Problem:** Issue only appeared when testing Bob (second device), not during Alice-only testing.

**Lesson:** Always test with two devices in different states:
- Device A creates content
- Device B loads content from sync
- Verify both see identical UI

### 4. **Use Field-Level Nullability Wisely**

**Problem:** Adding a required field would break backward compatibility.

**Lesson:** When adding fields to existing Hive models, use nullable types (`String?`) with sensible fallbacks:

```dart
@HiveField(13)
String? quizName; // ✅ Nullable - backward compatible

// Usage with fallback
return quest.quizName ?? 'Affirmation Quiz';
```

### 5. **Consolidate Duplicate Logic**

**Problem:** Both `quest_card.dart` and `activity_service.dart` had the same flawed quest title logic.

**Lesson:** Extract shared logic into a single helper function to prevent inconsistencies:

**Future Improvement:**
```dart
// lib/utils/quest_helpers.dart
class QuestHelpers {
  static String getQuestTitle(DailyQuest quest) {
    // Single source of truth for quest title logic
  }
}
```

### 6. **Document Sync Boundaries**

**Problem:** It wasn't clear which data syncs via Firebase and which stays local.

**Lesson:** Maintain clear documentation of sync boundaries:

| Model | Syncs via Firebase? | Local Only? |
|-------|---------------------|-------------|
| DailyQuest | ✅ Yes | No |
| QuizSession | ❌ No | ✅ Yes (created by first device) |
| QuizQuestion | N/A | JSON asset file |

---

## Related Documentation

- [Daily Quest System Architecture](./QUEST_SYSTEM_ARCHITECTURE.md)
- [Firebase RTDB Sync Patterns](./FIREBASE_SYNC_PATTERNS.md)
- [Affirmation Integration Plan](./AFFIRMATION_INTEGRATION_PLAN.md)
- [Hive Data Migration Guide](./HIVE_MIGRATION_GUIDE.md)

---

## Appendix: Complete Code Comparison

### DailyQuest Model - Before vs After

```diff
@HiveType(typeId: 17)
class DailyQuest extends HiveObject {
  @HiveField(11, defaultValue: 0)
  int sortOrder;

  @HiveField(12, defaultValue: 'classic')
  String formatType;

+ @HiveField(13)
+ String? quizName; // Quiz name for display

  DailyQuest({
    required this.id,
    required this.dateKey,
    required this.questType,
    required this.contentId,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    this.userCompletions,
    this.lpAwarded,
    this.completedAt,
    this.isSideQuest = false,
    this.sortOrder = 0,
    this.formatType = 'classic',
+   this.quizName,
  });
}
```

### Quest Card Widget - Before vs After

```diff
String _getQuestTitle() {
  switch (quest.type) {
    case QuestType.quiz:
-     // Check quest formatType first (always available from Firebase)
-     if (quest.formatType == 'affirmation') {
-       // Try to get affirmation quiz name from session
-       final session = StorageService().getQuizSession(quest.contentId);
-       if (session != null && session.quizName != null) {
-         return session.quizName!;
-       }
-       // Fallback to generic title if session not loaded yet
-       return 'Affirmation Quiz';
-     }
+     if (quest.formatType == 'affirmation') {
+       // Use quest.quizName (synced from Firebase) or fallback
+       return quest.quizName ?? 'Affirmation Quiz';
+     }
      return _getQuizTitle(quest.sortOrder);
  }
}
```

---

**Document Version:** 1.0
**Last Updated:** 2025-11-15
**Authors:** Development Team
**Reviewers:** QA Team, Product Team

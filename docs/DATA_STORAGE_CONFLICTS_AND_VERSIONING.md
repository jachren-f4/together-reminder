# Data Storage Conflicts & Versioning Strategy

**Critical Pre-Production Analysis**
**Date:** 2025-11-16
**Status:** 🔴 CRITICAL ISSUES IDENTIFIED
**Recommended Action:** DO NOT DEPLOY TO PRODUCTION without Phase 1 fixes

---

## Executive Summary

TogetherRemind uses a hybrid storage architecture with **Hive (local NoSQL)** for offline-first operation and **Firebase RTDB (remote)** for cross-device synchronization. While functional for MVP, the current implementation has **10 critical vulnerabilities** that will cause data corruption, sync conflicts, and user experience degradation in production.

**Most Critical Finding:** The app has **NO versioning system** for either Hive schemas or Firebase data structures, creating substantial risk when deploying updates to production.

### Risk Assessment

| Issue | Severity | Impact | Fix Priority |
|-------|----------|--------|--------------|
| No schema versioning | 🔴 CRITICAL | App crashes on schema changes | **P0** |
| LP balance divergence | 🔴 CRITICAL | Users see different balances | **P0** |
| No data validation | 🔴 CRITICAL | Crashes on bad Firebase data | **P0** |
| Quest ID mismatch | 🟠 HIGH | Lost quest progress | **P1** |
| Quiz progression conflicts | 🟠 HIGH | Lost completions | **P1** |
| LP dedup volatile | 🟡 MEDIUM | Duplicate awards on reinstall | **P1** |
| Cleanup never runs | 🟡 MEDIUM | Growing database size | **P2** |
| Retention mismatch | 🟡 MEDIUM | Orphaned data | **P2** |
| Concurrent completion | 🟡 MEDIUM | Missed LP awards (rare) | **P2** |
| No health checks | 🟢 LOW | Silent corruption | **P3** |

---

## Data Architecture Overview

### Current Storage Model

#### Hive (Local Storage)
- **23 HiveTypes** (typeId 0-22, typeId 7 missing/deprecated)
- **20 Storage Boxes** for different data categories
- **NO version tracking** - relies on `defaultValue` for new fields
- **Volatile on reinstall** - all data lost if app uninstalled

#### Firebase RTDB (Remote Sync)
- **8 primary paths** (`pairing_codes`, `daily_quests`, `quiz_sessions`, etc.)
- **NO schema versioning** - no validation beyond `pairing_codes`
- **Last-write-wins** - no conflict resolution or merge logic
- **No retention enforcement** - cleanup functions exist but never called

### Data Flow Patterns

| Data Type | Hive (Local) | Firebase (Remote) | Sync Pattern | Conflict Risk |
|-----------|--------------|-------------------|--------------|---------------|
| User Identity | ✅ Primary | One-time (pairing) | Single sync | 🟢 Low |
| Love Points | ✅ Primary | Dedup only | **NO SYNC** | 🔴 Critical |
| Daily Quests | ✅ Cache | ✅ Primary | "First creates, second loads" | 🟠 High |
| Quiz Sessions | ✅ Cache | ✅ Primary | Dual-session | 🟢 Low |
| Quiz Progression | ✅ Cache | ✅ Primary | Synced | 🟠 High |
| Game Sessions | ✅ Primary | ❌ None | Local-only | 🟢 Low |

---

## Critical Vulnerabilities (P0)

### 🔴 VULNERABILITY 1: No Schema Versioning

**Problem:** Zero version tracking in Hive or Firebase, no app version checks when reading data.

**Production Failure Scenario:**
```
Timeline: App Update v1.0 → v1.1

Day 1: Release v1.1 with new field in DailyQuest
  @HiveField(14, defaultValue: 'new_default')
  String newFeature;

Hour 1: 30% of users update to v1.1
  - Alice (v1.1) generates quests with newFeature='value'
  - Syncs to Firebase with new field
  - Bob (v1.0) loads quests → Hive ignores unknown field
  - Bob's local quests missing newFeature

Hour 2: 50% adoption, mixed versions
  - Bob (v1.0) becomes "first device" (alphabetically)
  - Generates quests WITHOUT newFeature
  - Syncs to Firebase → overwrites with old schema
  - Alice (v1.1) loads incomplete data
  - App logic expecting newFeature fails → CRASH

Result: Production crashes for v1.1 users during rollout window
```

**Code Evidence:**
```dart
// storage_service.dart:45-68 - NO version checking
if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ReminderAdapter());
if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(PartnerAdapter());
// ... no migration logic, no version validation

// quest_sync_service.dart:154-171 - NO schema version in Firebase writes
await questsRef.set({
  'quests': questsData,
  'generatedBy': currentUserId,
  'generatedAt': ServerValue.timestamp,
  // ⚠️ Missing: 'schemaVersion', 'appVersion'
});
```

**Fix Required:** Phase 1 (Week 1-2)

---

### 🔴 VULNERABILITY 2: Love Points Balance Divergence

**Problem:** Each device stores LP locally with no single source of truth. Firebase only used for deduplication, not balance storage.

**Production Failure Scenario:**
```
Timeline: Alice reinstalls app

Before reinstall:
  - Alice: 500 LP (local Hive)
  - Bob: 500 LP (local Hive)
  - Firebase: Only LP award dedup tracking

After reinstall:
  - Alice: Hive data cleared → User.lovePoints = 0
  - Bob: Still 500 LP
  - Firebase: No balance to restore from

New quest completed:
  - Both get 30 LP award
  - Alice: 0 + 30 = 30 LP
  - Bob: 500 + 30 = 530 LP

PERMANENT DIVERGENCE - No reconciliation mechanism exists
```

**Code Evidence:**
```dart
// love_point_service.dart:188-218
// Only writes award to Firebase for dedup, NOT balance
await _database.child('lp_awards/$coupleId/$awardId').set({
  'users': [userId1, userId2],
  'amount': actualAmount,
  'reason': reason,
  // ⚠️ Balance NOT stored in Firebase
});

// Each device updates its OWN local balance independently
await awardPoints(amount: amount, reason: reason);
user.lovePoints += amount;  // ⚠️ LOCAL Hive only
await _storage.saveUser(user);
```

**Documentation Exists:**
`docs/quest_system/lp_sync_architecture.md` identifies this exact issue with 3 proposed solutions, but **NONE IMPLEMENTED**.

**Fix Required:** Phase 1 (Week 1-2) - Move LP to Firebase as single source of truth

---

### 🔴 VULNERABILITY 3: No Data Validation on Firebase Reads

**Problem:** Firebase data loaded with zero validation, no type/range checking.

**Production Failure Scenario:**
```
Timeline: Bug writes invalid data to Firebase

Scenario 1: Invalid questType
  Firebase contains: { "questType": 99, ... }
  App loads: QuestType.values[99] → Index out of range → CRASH

Scenario 2: Missing required field
  Firebase contains: { "id": null, ... }
  App loads: final id = questMap['id'] as String → Null cast error → CRASH

Scenario 3: Type mismatch
  Firebase contains: { "contentId": 123, ... } (int instead of String)
  App loads: final id = questMap['contentId'] as String → Type error → CRASH

Result: App crashes for BOTH users (bad data synced to Firebase)
```

**Code Evidence:**
```dart
// quest_sync_service.dart:178-239 - NO validation before deserialization
for (final questData in questsData) {
  final questMap = questData as Map<dynamic, dynamic>;
  final questId = questMap['id'] as String;  // ⚠️ No null check
  final questType = questMap['questType'] as int;  // ⚠️ No range check

  // ⚠️ No validation that questType is valid enum value
  final quest = DailyQuest(
    type: QuestType.values[questType],  // Can crash here
    // ... no error handling
  );
}
```

**Fix Required:** Phase 1 (Week 1-2) - Add validation before all Firebase deserializations

---

## High Priority Issues (P1)

### 🟠 VULNERABILITY 4: Quest ID Mismatch When Offline

**Problem:** "First creates, second loads" pattern assumes perfect timing with 5-second window (3s + 2s retry).

**Production Failure Scenario:**
```
Timeline: Both devices delayed startup

8:00 AM: Alice comes online
  - Checks Firebase → empty (Bob not online yet)
  - Waits 3 seconds
  - Checks Firebase → still empty
  - Waits 2 more seconds
  - Checks Firebase → still empty
  - Generates own quests: quest_alice_001, quest_alice_002, quest_alice_003
  - Syncs to Firebase

8:00:10: Bob comes online (10 seconds late)
  - Checks Firebase → finds Alice's quests
  - Loads quests with Alice's IDs ✅

BUT if BOTH delayed:
8:00 AM: Alice online → waits 5s → generates quest_alice_001
8:00:01: Bob online → waits 5s → generates quest_bob_001

Result:
  - Alice syncs first → Firebase has quest_alice_001
  - Bob finds Alice's quests → deletes own → reloads
  - BUT if Bob already completed quest_bob_001 → progress lost
```

**Code Evidence:**
```dart
// quest_sync_service.dart:48-68
if (isSecondDevice) {
  await Future.delayed(const Duration(seconds: 3));
}

final snapshot = await questsRef.get();
if (!snapshot.exists || snapshot.value == null) {
  await Future.delayed(const Duration(seconds: 2));  // Only 2s retry
  snapshot = await questsRef.get();

  if (!snapshot.exists || snapshot.value == null) {
    // ⚠️ Generate own quests with different IDs
    return false;
  }
}

// quest_sync_service.dart:82-103 - Detects mismatch and DELETES local quests
if (firebaseQuestIds.difference(localQuestIds).isEmpty) {
  // IDs match ✅
} else {
  // IDs don't match → DELETE local quests
  for (final quest in localQuests) {
    await quest.delete();  // ⚠️ Lost if already completed
  }
}
```

**Fix Required:** Phase 2 (Week 3-4) - Longer retry window + offline queue

---

### 🟠 VULNERABILITY 5: Quiz Progression Conflicts (Last Write Wins)

**Problem:** Shared progression state with no merge logic - simultaneous updates overwrite each other.

**Production Failure Scenario:**
```
Timeline: Both complete different quizzes simultaneously

Device A (Alice):                    Device B (Bob):
- Current: track=0, pos=2           - Current: track=0, pos=2
- Completes quiz "0_2"              - Completes quiz "0_3"
- Updates local:                    - Updates local:
  track=0, pos=3                      track=0, pos=4
  completedQuizzes["0_2"]=true        completedQuizzes["0_3"]=true

- Writes to Firebase (9:00:00):    - Writes to Firebase (9:00:01):
  {                                   {
    currentPosition: 3,                 currentPosition: 4,
    completedQuizzes: {                 completedQuizzes: {
      "0_2": true                         "0_3": true
    }                                   }
  }                                   }

Result: Bob's write (9:00:01) overwrites Alice's
  - Firebase now has: position=4, completedQuizzes={"0_3": true}
  - Alice's completion of "0_2" is LOST
```

**Code Evidence:**
```dart
// quest_sync_service.dart:311-350 - Simple set() call, no merge
await progressionRef.set({
  'currentTrack': state.currentTrack,
  'currentPosition': state.currentPosition,
  'completedQuizzes': state.completedQuizzes,
  'totalQuizzesCompleted': state.totalQuizzesCompleted,
  // ⚠️ Overwrites entire object - no merge, no conflict detection
});
```

**Fix Required:** Phase 2 (Week 3-4) - Use Firebase transactions for atomic updates

---

### 🟡 VULNERABILITY 6: LP Deduplication Tracking Volatile

**Problem:** Applied LP awards tracked in untyped Hive box, lost on app reinstall.

**Production Failure Scenario:**
```
Timeline: User clears app data or reinstalls

Day 1:
  - Quest completed → LP award created in Firebase
  - Alice applies award → lovePoints += 30
  - Award ID saved: _appMetadataBox['applied_lp_awards'] = ['award_123']

Day 2:
  - Alice clears app data (or reinstalls)
  - _appMetadataBox cleared → applied_lp_awards = []
  - Firebase listener re-fires for existing awards
  - Award 'award_123' not in applied list → applies again
  - lovePoints += 30 (DUPLICATE)
```

**Code Evidence:**
```dart
// storage_service.dart:520-535
Future<void> markLPAwardAsApplied(String awardId) async {
  final box = Hive.box(_appMetadataBox);  // ⚠️ Untyped, volatile
  final awards = getAppliedLPAwards();
  awards.add(awardId);
  await box.put(_appliedLPAwardsKey, awards.toList());
  // ⚠️ Lost on app data clear
}
```

**Fix Required:** Phase 2 (Week 3-4) - Move dedup tracking to Firebase

---

## Medium Priority Issues (P2)

### 🟡 VULNERABILITY 7: Cleanup Functions Never Called

**Problem:** Cleanup functions exist but never scheduled or called in production code.

**Production Impact:**
- Firebase database grows indefinitely
- Hive storage bloats over time
- Old quests/sessions never removed
- Increased memory usage and slower queries

**Code Evidence:**
```dart
// Functions exist:
// daily_quest_service.dart:220-231
Future<void> cleanupExpiredQuests() async {
  final allQuests = _storage.dailyQuestsBox.values.toList();
  final now = DateTime.now();
  for (final quest in allQuests) {
    if (now.difference(quest.expiresAt).inDays > 7) {
      await quest.delete();
    }
  }
}

// quest_sync_service.dart:377-411
Future<void> cleanupOldQuests(...) async { ... }

// you_or_me_service.dart:819-839
Future<void> cleanupOldSessions() async { ... }

// ⚠️ NEVER CALLED in main.dart or any background service
```

**Fix Required:** Phase 2 (Week 3-4) - Schedule cleanup on startup + daily timer

---

### 🟡 VULNERABILITY 8: Retention Policy Mismatch

**Problem:** Documentation says 30 days, code implements 7 days for quests, 30 days for sessions.

**Production Impact:**
- Quests deleted after 7 days
- Quiz sessions kept for 30 days
- Quests reference sessions via `contentId`
- Days 8-30: Orphaned session references in old quests

**Code Evidence:**
```dart
// daily_quest_service.dart:226
if (now.difference(quest.expiresAt).inDays > 7) { ... }  // 7 days

// you_or_me_service.dart:821
final cutoff = DateTime.now().subtract(const Duration(days: 30));  // 30 days

// docs/QUEST_SYSTEM_V2.md:46
"30-Day Data Retention: Quiz sessions stored for 30 days"
```

**Fix Required:** Phase 2 (Week 3-4) - Align retention policies to 30 days for all

---

### 🟡 VULNERABILITY 9: Concurrent Quest Completion Race Condition

**Problem:** Each device writes its own completion separately, LP award depends on seeing both.

**Production Failure Scenario:**
```
Timeline: Both complete same quest simultaneously

9:00:00 Alice:
  - Completes quest_123
  - Writes to Firebase: completions/quest_123/alice = true
  - Checks for partner completion → bob = undefined → No LP award yet

9:00:00 Bob:
  - Completes quest_123
  - Writes to Firebase: completions/quest_123/bob = true
  - Checks for partner completion → alice = undefined (write not visible yet)
  - No LP award yet

9:00:01 Both:
  - Listener fires → sees partner completion
  - LP awarded ✅

BUT if listener inactive (app backgrounded):
  - Completion not detected until next app open
  - Delayed LP award (user confusion)
```

**Code Evidence:**
```dart
// quest_sync_service.dart:252-256
for (final quest in quests) {
  if (quest.hasUserCompleted(userId)) {
    await completionsRef.child('${quest.id}/$userId').set(true);
    // ⚠️ Each device writes separately
  }
}

// Listener must be active to detect partner completion
Stream<Map<String, dynamic>> listenForPartnerCompletions(...) {
  return completionsRef.onValue.map((event) { ... });
  // ⚠️ If listener not active → missed
}
```

**Fix Required:** Phase 2 (Week 3-4) - Add completion check on app resume

---

## Low Priority Issues (P3)

### 🟢 VULNERABILITY 10: No Health Checks or Data Integrity Validation

**Problem:** No system to detect or repair data corruption, orphaned references, or balance discrepancies.

**Production Impact:**
- Silent data corruption goes undetected
- Orphaned quests referencing deleted sessions
- LP balance not matching transaction sum
- Quiz progression state inconsistent with completed quizzes

**Fix Required:** Phase 3 (Month 2+) - Build health check dashboard in debug menu

---

## Implementation Phases

### Phase 1: Pre-Production Critical (Week 1-2)

**Blockers for Production Launch - MUST FIX**

#### 1. Schema Versioning System (2 days)

**Implementation:**
```dart
// constants/schema_versions.dart - NEW FILE
class SchemaVersions {
  static const int currentHiveVersion = 1;
  static const int currentFirebaseVersion = 1;
  static const String appVersion = '1.0.0';
}

// quest_sync_service.dart - Add to ALL Firebase writes
await questsRef.set({
  'schemaVersion': SchemaVersions.currentFirebaseVersion,
  'appVersion': SchemaVersions.appVersion,
  'quests': questsData,
  'generatedAt': ServerValue.timestamp,
});

// quest_sync_service.dart - Validate on read
final data = snapshot.value as Map<dynamic, dynamic>;
final schemaVersion = data['schemaVersion'] as int? ?? 0;

if (schemaVersion > SchemaVersions.currentFirebaseVersion) {
  throw IncompatibleVersionException(
    'Data created by newer app version. Please update app.',
  );
}

if (schemaVersion < SchemaVersions.currentFirebaseVersion) {
  // Migrate old data
  data = _migrateQuestsFromV${schemaVersion}(data);
}
```

**Testing:**
- Deploy v1.0 → generate quests
- Deploy v1.1 → verify migration runs
- Test v1.0 reading v1.1 data → error message shown

---

#### 2. Love Points Firebase Sync (3 days)

**Implementation:**
```dart
// Firebase structure - NEW
/couples/
  {coupleId}/
    lp_balance: 500          // Single source of truth
    lp_floor: 0
    lp_tier: 2
    last_updated: timestamp

// love_point_service.dart - NEW METHODS

/// Get couple's LP balance from Firebase (source of truth)
static Future<int> getLPBalance({
  required String userId,
  required String partnerId,
}) async {
  final sortedIds = [userId, partnerId]..sort();
  final coupleId = '${sortedIds[0]}_${sortedIds[1]}';

  final snapshot = await _database.child('couples/$coupleId/lp_balance').get();
  return snapshot.value as int? ?? 0;
}

/// Award LP via Firebase transaction (atomic, no race conditions)
static Future<void> awardPointsToCouple({
  required String userId,
  required String partnerId,
  required int amount,
  required String reason,
}) async {
  final sortedIds = [userId, partnerId]..sort();
  final coupleId = '${sortedIds[0]}_${sortedIds[1]}';

  // Atomic increment via Firebase transaction
  final balanceRef = _database.child('couples/$coupleId/lp_balance');
  await balanceRef.runTransaction((currentValue) {
    final current = (currentValue ?? 0) as int;
    return current + amount;
  });

  // Record transaction for history
  final txnRef = _database.child('couples/$coupleId/lp_transactions').push();
  await txnRef.set({
    'amount': amount,
    'reason': reason,
    'awardedBy': userId,
    'timestamp': ServerValue.timestamp,
  });
}

/// Listen for LP balance changes (real-time sync)
static void listenForLPBalance({
  required String userId,
  required String partnerId,
}) {
  final sortedIds = [userId, partnerId]..sort();
  final coupleId = '${sortedIds[0]}_${sortedIds[1]}';

  _database.child('couples/$coupleId/lp_balance').onValue.listen((event) {
    final newBalance = event.snapshot.value as int? ?? 0;

    // Update local cache
    final user = _storage.getUser();
    if (user != null) {
      user.lovePoints = newBalance;
      _storage.saveUser(user);
    }
  });
}
```

**Migration Strategy:**
1. Deploy new code with Firebase LP sync
2. On first launch: Read local LP → write to Firebase if higher
3. Switch to Firebase as source of truth
4. Remove local LP storage in v1.1

**Testing:**
- Complete quest → verify LP written to Firebase
- Reinstall app → verify LP restored from Firebase
- Offline LP award → verify syncs when back online

---

#### 3. Data Validation Layer (2 days)

**Implementation:**
```dart
// services/firebase_validator.dart - NEW FILE

class FirebaseValidator {
  static bool isValidQuestData(Map<dynamic, dynamic> data) {
    try {
      // Required fields
      if (!data.containsKey('id') || data['id'] is! String) return false;
      if (!data.containsKey('questType') || data['questType'] is! int) return false;
      if (!data.containsKey('contentId') || data['contentId'] is! String) return false;

      // Range checks
      final questType = data['questType'] as int;
      if (questType < 0 || questType >= QuestType.values.length) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  static bool isValidQuizSessionData(Map<dynamic, dynamic> data) {
    // ... similar validation
  }
}

// quest_sync_service.dart - Apply validation
for (final questData in questsData) {
  final questMap = questData as Map<dynamic, dynamic>;

  // NEW: Validate before deserializing
  if (!FirebaseValidator.isValidQuestData(questMap)) {
    Logger.error('Invalid quest data from Firebase, skipping', data: questMap);
    continue; // Skip invalid quest
  }

  // Safe to deserialize
  final quest = DailyQuest.fromMap(questMap);
}
```

**Testing:**
- Manually write invalid data to Firebase
- Verify app skips invalid data instead of crashing
- Test all data types: quests, sessions, progression

---

#### 4. Scheduled Cleanup Jobs (1 day)

**Implementation:**
```dart
// main.dart - Add after initialization

void main() async {
  // ... existing initialization

  // NEW: Schedule cleanup jobs
  _scheduleDataCleanup();

  runApp(const TogetherRemindApp());
}

Future<void> _scheduleDataCleanup() async {
  // Run cleanup on startup
  await _runCleanupJobs();

  // Schedule daily cleanup
  Timer.periodic(const Duration(hours: 24), (_) async {
    await _runCleanupJobs();
  });
}

Future<void> _runCleanupJobs() async {
  try {
    Logger.info('Running scheduled cleanup jobs', service: 'storage');

    // Clean local Hive storage
    await DailyQuestService().cleanupExpiredQuests();
    await YouOrMeService().cleanupOldSessions();

    // Clean Firebase (if paired)
    final user = StorageService.instance.getUser();
    final partner = StorageService.instance.getPartner();
    if (user != null && partner != null) {
      final syncService = QuestSyncService();
      await syncService.cleanupOldQuests(
        currentUserId: user.id,
        partnerUserId: partner.pushToken,
      );
    }

    Logger.success('Cleanup jobs completed', service: 'storage');
  } catch (e) {
    Logger.error('Cleanup jobs failed', error: e, service: 'storage');
  }
}
```

**Testing:**
- Create quests older than 7 days
- Restart app → verify old quests deleted
- Verify Firebase cleanup runs when paired

---

### Phase 2: Production Hardening (Week 3-4)

**Deploy After Launch, Monitor Closely**

#### 5. Quiz Progression Atomic Updates (2 days)

**Implementation:**
```dart
// quest_sync_service.dart - Replace set() with transaction

Future<void> updateProgressionState(QuizProgressionState state) async {
  final progressionRef = _database.child('quiz_progression/${state.coupleId}');

  // Use Firebase transaction for atomic update
  await progressionRef.runTransaction((currentData) {
    final current = currentData as Map<dynamic, dynamic>? ?? {};

    // Merge completed quizzes (don't overwrite)
    final currentCompleted = Map<String, bool>.from(
      current['completedQuizzes'] ?? {}
    );
    final newCompleted = Map<String, bool>.from(state.completedQuizzes);

    // Merge both maps
    currentCompleted.addAll(newCompleted);

    // Use max values for position (prevent going backwards)
    final maxTrack = max(
      current['currentTrack'] as int? ?? 0,
      state.currentTrack,
    );
    final maxPosition = max(
      current['currentPosition'] as int? ?? 0,
      state.currentPosition,
    );

    return {
      'currentTrack': maxTrack,
      'currentPosition': maxPosition,
      'completedQuizzes': currentCompleted,
      'totalQuizzesCompleted': currentCompleted.length,
      'lastUpdated': ServerValue.timestamp,
    };
  });
}
```

**Testing:**
- Both devices complete different quizzes simultaneously
- Verify both completions recorded in Firebase
- Verify position uses max value, not last write

---

#### 6. Improved Quest ID Sync (1 day)

**Implementation:**
```dart
// quest_sync_service.dart - Extend retry window

if (isSecondDevice) {
  await Future.delayed(const Duration(seconds: 3));
}

// NEW: Retry up to 5 times with exponential backoff
int retries = 0;
const maxRetries = 5;
DataSnapshot? snapshot;

while (retries < maxRetries) {
  snapshot = await questsRef.get();
  if (snapshot.exists && snapshot.value != null) {
    break; // Found quests
  }

  retries++;
  final backoffSeconds = min(2 * retries, 10); // Max 10 seconds
  await Future.delayed(Duration(seconds: backoffSeconds));
}

if (snapshot == null || !snapshot.exists) {
  // After 5 retries (~30 seconds total), generate own quests
  Logger.warn('No quests found after $maxRetries retries, generating locally');
  return false;
}
```

**Testing:**
- Simulate slow network (Firebase emulator)
- Verify retries work up to 30 seconds
- Verify eventual fallback to local generation

---

#### 7. Move LP Dedup to Firebase (1 day)

**Implementation:**
```dart
// Firebase structure - CHANGE
/couples/
  {coupleId}/
    lp_balance: 500
    applied_awards: {
      award_123: true,
      award_456: true,
    }

// love_point_service.dart - Check Firebase instead of Hive

static Future<bool> hasAppliedAward(String coupleId, String awardId) async {
  final snapshot = await _database
    .child('couples/$coupleId/applied_awards/$awardId')
    .get();
  return snapshot.exists && snapshot.value == true;
}

static Future<void> markAwardAsApplied(String coupleId, String awardId) async {
  await _database
    .child('couples/$coupleId/applied_awards/$awardId')
    .set(true);
}
```

**Testing:**
- Complete quest → verify award marked in Firebase
- Reinstall app → verify duplicate awards prevented
- Clear app data → verify dedup still works

---

#### 8. Align Retention Policies (1 day)

**Implementation:**
```dart
// daily_quest_service.dart - Change from 7 to 30 days
Future<void> cleanupExpiredQuests() async {
  final allQuests = _storage.dailyQuestsBox.values.toList();
  final now = DateTime.now();

  for (final quest in allQuests) {
    // CHANGE: 7 days → 30 days
    if (now.difference(quest.expiresAt).inDays > 30) {
      await quest.delete();
    }
  }
}

// quest_sync_service.dart - Change from 7 to 30 days
Future<void> cleanupOldQuests(...) async {
  // ... parse dateKey
  // CHANGE: 7 days → 30 days
  if (now.difference(questDate).inDays > 30) {
    await questsRef.child(dateKey).remove();
  }
}

// Update documentation
// docs/QUEST_SYSTEM_V2.md - Verify 30-day retention documented
```

**Testing:**
- Create quests 29 days old → verify NOT deleted
- Create quests 31 days old → verify deleted
- Check Firebase cleanup matches local cleanup

---

### Phase 3: Long-term Architecture (Month 2+)

**Strategic Improvements for Scale**

#### 9. Event Sourcing for Love Points (1 week)

**Why:** Complete audit trail, no divergence possible, easy debugging.

**Implementation:**
```dart
// Firebase structure - REPLACE lp_balance with events
/couples/
  {coupleId}/
    lp_events: {
      event_001: {
        type: 'quest_completed',
        amount: 30,
        timestamp: 1699876543000,
        questId: 'quest_123',
      },
      event_002: {
        type: 'quiz_completed',
        amount: 30,
        timestamp: 1699876600000,
      },
    }

// Balance computed from events
Future<int> computeLPBalance(String coupleId) async {
  final eventsSnapshot = await _database
    .child('couples/$coupleId/lp_events')
    .get();

  if (!eventsSnapshot.exists) return 0;

  final events = eventsSnapshot.value as Map<dynamic, dynamic>;
  return events.values.fold(0, (sum, event) {
    final eventMap = event as Map<dynamic, dynamic>;
    return sum + (eventMap['amount'] as int);
  });
}
```

**Benefits:**
- Append-only (no overwrites)
- Complete history for debugging
- Can rebuild balance from scratch
- Easy to detect duplicate events

---

#### 10. Health Check System (1 week)

**Implementation:**
```dart
// services/data_health_checker.dart - NEW FILE

class HealthReport {
  final List<String> errors = [];
  final List<String> warnings = [];
  final Map<String, dynamic> stats = {};

  bool get isHealthy => errors.isEmpty;
}

class DataHealthChecker {
  static Future<HealthReport> runFullCheck() async {
    final report = HealthReport();

    // Check 1: Orphaned quest references
    await _checkOrphanedQuests(report);

    // Check 2: LP balance consistency
    await _checkLPConsistency(report);

    // Check 3: Quiz progression consistency
    await _checkQuizProgression(report);

    // Check 4: Retention policy violations
    await _checkRetentionPolicies(report);

    return report;
  }

  static Future<void> _checkOrphanedQuests(HealthReport report) async {
    final quests = StorageService.instance.getTodayQuests();
    int orphaned = 0;

    for (final quest in quests) {
      if (quest.type == QuestType.quiz) {
        final session = StorageService.instance.getQuizSession(quest.contentId);
        if (session == null) {
          orphaned++;
          report.errors.add(
            'Quest ${quest.id} references missing session ${quest.contentId}'
          );
        }
      }
    }

    report.stats['orphaned_quests'] = orphaned;
  }

  // ... more checks
}

// Add to debug menu
ElevatedButton(
  child: Text('Run Health Check'),
  onPressed: () async {
    final report = await DataHealthChecker.runFullCheck();
    // Show report in dialog
  },
)
```

---

## Testing Strategy

### Unit Tests

```dart
// test/services/quest_sync_service_test.dart

test('Schema version validation rejects future versions', () async {
  // Simulate Firebase data from future version
  final futureData = {
    'schemaVersion': 99,
    'quests': [],
  };

  expect(
    () => QuestSyncService()._loadQuestsFromFirebase(futureData),
    throwsA(isA<IncompatibleVersionException>()),
  );
});

test('Data validation skips invalid quests', () async {
  final mixedData = [
    {'id': 'quest_1', 'questType': 0, 'contentId': 'c1'}, // Valid
    {'id': 'quest_2', 'questType': 99, 'contentId': 'c2'}, // Invalid type
    {'id': null, 'questType': 0, 'contentId': 'c3'}, // Invalid id
  ];

  final loaded = await QuestSyncService()._loadQuests(mixedData);
  expect(loaded.length, equals(1)); // Only valid quest loaded
});

test('LP balance syncs from Firebase on reinstall', () async {
  // Simulate reinstall (clear local storage)
  await StorageService.instance.clearAll();

  // Mock Firebase balance
  when(mockDatabase.child('couples/alice_bob/lp_balance').get())
    .thenAnswer((_) => Future.value(MockSnapshot(500)));

  // Initialize LP service
  await LovePointService.initialize('alice', 'bob');

  // Verify local balance restored
  final user = StorageService.instance.getUser();
  expect(user.lovePoints, equals(500));
});
```

### Integration Tests

```dart
// integration_test/versioning_test.dart

testWidgets('Version upgrade scenario', (tester) async {
  // 1. Launch app v1.0
  await tester.pumpWidget(MyApp(version: '1.0.0'));

  // 2. Generate quests
  await tester.tap(find.byIcon(Icons.refresh));
  await tester.pumpAndSettle();

  // 3. Verify schema version in Firebase
  final snapshot = await FirebaseDatabase.instance
    .ref('daily_quests/alice_bob/2025-11-16')
    .get();
  expect(snapshot.value['schemaVersion'], equals(1));

  // 4. Simulate app update to v1.1
  await tester.pumpWidget(MyApp(version: '1.1.0'));

  // 5. Verify migration runs
  // ... test migration logic
});
```

### Manual Testing Checklist

**Pre-Production (Phase 1):**
- [ ] Deploy v1.0 → generate quests → verify schemaVersion in Firebase
- [ ] Complete quest → verify LP written to Firebase couples/ path
- [ ] Reinstall app → verify LP restored from Firebase
- [ ] Write invalid data to Firebase → verify app skips gracefully
- [ ] Create 31-day-old quests → verify cleanup deletes them
- [ ] Run health check → verify no errors on clean install

**Production (Phase 2):**
- [ ] Both devices complete different quizzes → verify both recorded
- [ ] Slow network test → verify quest sync retries work
- [ ] Reinstall app → verify LP dedup still prevents duplicates
- [ ] Monitor Firebase storage size → verify cleanup running

**Long-term (Phase 3):**
- [ ] Review LP event log for audit trail completeness
- [ ] Run weekly health checks → track error trends
- [ ] Test offline queue → verify operations sync on reconnect

---

## Deployment Checklist

### Pre-Production (Before First Release)

**Week 1:**
- [ ] Implement schema versioning
- [ ] Add data validation layer
- [ ] Test version upgrade scenarios (v1.0 → v1.1)
- [ ] Deploy to internal test environment

**Week 2:**
- [ ] Implement LP Firebase sync
- [ ] Test LP sync with reinstalls
- [ ] Schedule cleanup jobs
- [ ] Deploy to beta testers (10 couples)

**Week 3:**
- [ ] Monitor beta for schema version issues
- [ ] Monitor beta for LP divergence
- [ ] Review crash reports for validation failures
- [ ] Fix any critical bugs

**Week 4:**
- [ ] Final production deployment
- [ ] Monitor for 48 hours closely
- [ ] Have rollback plan ready

### Post-Production (Ongoing)

**Weekly:**
- [ ] Review error logs for data validation failures
- [ ] Check Firebase database size growth
- [ ] Monitor LP divergence reports (user support)

**Monthly:**
- [ ] Run health checks on sample users
- [ ] Review retention policy effectiveness
- [ ] Plan next phase improvements

---

## Risk Mitigation

### Rollback Plan

If critical issues arise post-deployment:

1. **Immediate Actions (< 1 hour):**
   - Revert to previous app version in App Store / Play Store
   - Disable Firebase writes via remote config flag
   - Announce issue to users via in-app banner

2. **Short-term (< 24 hours):**
   - Analyze crash reports and error logs
   - Identify root cause
   - Deploy hotfix if possible

3. **Long-term (< 1 week):**
   - Implement comprehensive fix
   - Test thoroughly in staging
   - Gradual rollout (10% → 50% → 100%)

### Data Export Tool

Before major changes, provide users with data export:

```dart
// services/data_export_service.dart - NEW FILE

class DataExportService {
  static Future<Map<String, dynamic>> exportAllData() async {
    return {
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'user': StorageService.instance.getUser()?.toMap(),
      'partner': StorageService.instance.getPartner()?.toMap(),
      'quests': StorageService.instance.getAllQuests().map((q) => q.toMap()).toList(),
      'sessions': StorageService.instance.getAllSessions().map((s) => s.toMap()).toList(),
      'lpTransactions': StorageService.instance.getAllTransactions().map((t) => t.toMap()).toList(),
    };
  }

  static Future<void> importData(Map<String, dynamic> data) async {
    // ... restore from export
  }
}
```

---

## Success Metrics

### Phase 1 Metrics (Production Launch)

- **Zero crashes** related to schema version mismatches in first 30 days
- **< 1% LP divergence** reports from users
- **Zero data corruption** incidents from validation failures
- **Cleanup jobs** running successfully on 100% of devices

### Phase 2 Metrics (Production Hardening)

- **< 0.1% quest ID mismatch** incidents
- **Zero quiz progression loss** reports
- **Zero duplicate LP awards** after reinstalls
- **Firebase database size** growing linearly (cleanup effective)

### Phase 3 Metrics (Long-term)

- **100% LP balance accuracy** (event sourcing eliminates divergence)
- **Health check pass rate** > 95% across user base
- **Offline queue** handling 100% of offline operations

---

## Conclusion

The current data storage architecture is **NOT production-ready** due to critical vulnerabilities around schema versioning, LP synchronization, and data validation. **Phase 1 fixes are mandatory** before any production launch.

Implement Phase 1 (Week 1-2), deploy to beta, monitor closely, then proceed to production launch. Phase 2 and 3 can be deployed post-launch but should be prioritized to prevent long-term scaling issues.

**Estimated Total Implementation Time:**
- Phase 1: 8 days (2 weeks with testing)
- Phase 2: 5 days (1 week with testing)
- Phase 3: 10 days (2 weeks with testing)

**Total: 5 weeks for complete implementation**

---

**Document Status:** ✅ COMPLETE
**Last Updated:** 2025-11-16
**Next Review:** After Phase 1 implementation

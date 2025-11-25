# Phase 4: Daily Quests Migration Plan

**Date:** 2025-11-25
**Complexity:** ⭐⭐ MEDIUM (simpler than Love Points)
**Estimated Time:** 2-3 hours (analysis + implementation + testing)
**Feature Flag:** `DevConfig.useSuperbaseForDailyQuests`

---

## 📊 Current Architecture Analysis

### Firebase RTDB Usage

**Current Flow:**
```
App Start (Both Devices)
  ↓
QuestSyncService.syncTodayQuests()
  ↓
Check Firebase: /daily_quests/{coupleId}/{dateKey}
  ↓
EXISTS?
├─ YES → Load from Firebase, save to Hive
└─ NO → Generate locally, save to Firebase + Hive
```

**Key Firebase Operations:**
1. **Read:** `_database.child('daily_quests/$coupleId/$dateKey').get()`
2. **Write:** `questsRef.set({ quests, generatedBy, generatedAt, progression })`
3. **Completion Sync:** Via Firebase RTDB (currently)

**Race Condition Handling:**
- First device (alphabetically first user ID) generates immediately
- Second device waits 3 seconds, then retries if empty (total: 5 seconds)
- Ensures only one device generates quests

---

## 🎯 Supabase-Only Design

### New Flow (Flag TRUE)

```
App Start (Both Devices)
  ↓
QuestSyncService.syncTodayQuests() [flag check]
  ↓
GET /api/sync/daily-quests?date=YYYY-MM-DD
  ↓
EXISTS?
├─ YES → Load from Supabase, save to Hive
└─ NO → Generate locally, POST to Supabase + Hive
```

**Advantages over Love Points:**
- ✅ No polling needed (quests checked once per day)
- ✅ Simpler than Love Points (one-time read, not continuous)
- ✅ API already has all endpoints (GET, POST, completion)
- ✅ Database already has `daily_quests` table

---

## 🔧 Implementation Plan

### 1. Add Feature Flag

**File:** `lib/config/dev_config.dart`
```dart
// Already added in previous commit ✅
static const bool useSuperbaseForDailyQuests = false;
```

### 2. Modify Quest Sync Service

**File:** `lib/services/quest_sync_service.dart`

**Changes needed:**

#### A. Modify `syncTodayQuests()` method
```dart
Future<bool> syncTodayQuests({
  required String currentUserId,
  required String partnerUserId,
}) async {
  // NEW: Check feature flag
  if (DevConfig.useSuperbaseForDailyQuests) {
    return _syncTodayQuestsSupabase(currentUserId, partnerUserId);
  }

  // OLD: Firebase path (unchanged)
  // ... existing code ...
}
```

#### B. Add new method: `_syncTodayQuestsSupabase()`
```dart
Future<bool> _syncTodayQuestsSupabase(
  String currentUserId,
  String partnerUserId
) async {
  final dateKey = QuestUtilities.getTodayDateKey();

  // 1. Try to fetch from Supabase
  final response = await _apiClient.get('/api/sync/daily-quests?date=$dateKey');

  if (response.success && response.data != null) {
    final quests = response.data['quests'] as List;

    if (quests.isNotEmpty) {
      // Quests exist - load them
      await _loadQuestsFromSupabase(quests, dateKey);
      return true;
    }
  }

  // 2. No quests exist - check if we should generate
  if (_storage.getTodayQuests().isNotEmpty) {
    // Local quests exist - already synced
    return true;
  }

  // 3. Implement race condition handling (like Firebase)
  final sortedIds = [currentUserId, partnerUserId]..sort();
  final isSecondDevice = currentUserId == sortedIds[1];

  if (isSecondDevice) {
    // Wait 3 seconds, then retry
    await Future.delayed(const Duration(seconds: 3));
    final retryResponse = await _apiClient.get('/api/sync/daily-quests?date=$dateKey');

    if (retryResponse.success && retryResponse.data != null) {
      final quests = retryResponse.data['quests'] as List;
      if (quests.isNotEmpty) {
        await _loadQuestsFromSupabase(quests, dateKey);
        return true;
      }
    }
  }

  // 4. No quests anywhere - need to generate
  return false;
}
```

#### C. Add helper method: `_loadQuestsFromSupabase()`
```dart
Future<void> _loadQuestsFromSupabase(List<dynamic> questsData, String dateKey) async {
  final quests = questsData.map((data) {
    return DailyQuest(
      id: data['id'],
      type: QuestType.values.firstWhere(
        (e) => e.name == data['quest_type'],
        orElse: () => QuestType.quiz,
      ),
      contentId: data['content_id'],
      sortOrder: data['sort_order'],
      isSideQuest: data['is_side_quest'] ?? false,
      dateKey: dateKey,
      completedAt: null,
    )..formatType = (data['metadata'] as Map?)?['formatType']
      ..quizName = (data['metadata'] as Map?)?['quizName'];
  }).toList();

  await _storage.saveTodayQuests(quests);
  Logger.success('Loaded ${quests.length} quests from Supabase', service: 'quest');
}
```

#### D. Modify `saveQuestsToFirebase()` method
```dart
Future<void> saveQuestsToFirebase({
  required List<DailyQuest> quests,
  required String currentUserId,
  required String partnerUserId,
  QuizProgressionState? progressionState,
}) async {
  // NEW: Check feature flag
  if (DevConfig.useSuperbaseForDailyQuests) {
    return _saveQuestsToSupabaseOnly(quests, currentUserId, partnerUserId);
  }

  // OLD: Firebase + dual-write path (unchanged)
  // ... existing code ...
}
```

#### E. Add method: `_saveQuestsToSupabaseOnly()`
```dart
Future<void> _saveQuestsToSupabaseOnly(
  List<DailyQuest> quests,
  String currentUserId,
  String partnerUserId,
) async {
  final dateKey = QuestUtilities.getTodayDateKey();

  final response = await _apiClient.post('/api/sync/daily-quests', body: {
    'dateKey': dateKey,
    'quests': quests.map((q) => {
      'id': q.id,
      'questType': q.type.name,
      'contentId': q.contentId,
      'sortOrder': q.sortOrder,
      'isSideQuest': q.isSideQuest,
      'formatType': q.formatType,
      'quizName': q.quizName,
    }).toList(),
  });

  if (response.success) {
    Logger.success('Saved ${quests.length} quests to Supabase', service: 'quest');
  } else {
    Logger.error('Failed to save quests to Supabase: ${response.error}', service: 'quest');
    throw Exception('Failed to save quests to Supabase');
  }
}
```

### 3. Modify Completion Sync

**File:** `lib/services/quest_sync_service.dart`

**Method:** `_syncCompletionStatus()`

**Change:** Already dual-writes to Supabase (Phase 3), just make it Supabase-only when flag is TRUE.

```dart
Future<void> _syncCompletionStatus(
  String coupleId,
  String dateKey,
  String currentUserId
) async {
  if (DevConfig.useSuperbaseForDailyQuests) {
    // Supabase-only path
    return _syncCompletionStatusSupabase(dateKey, currentUserId);
  }

  // Firebase path (unchanged)
  // ... existing code ...
}
```

---

## 📋 API Endpoints (Already Complete)

### 1. GET /api/sync/daily-quests?date=YYYY-MM-DD

**Purpose:** Fetch quests for a specific date
**Response:**
```json
{
  "quests": [
    {
      "id": "uuid",
      "couple_id": "uuid",
      "date": "2025-11-25",
      "quest_type": "quiz",
      "content_id": "uuid",
      "sort_order": 0,
      "is_side_quest": false,
      "metadata": {
        "formatType": "classic",
        "quizName": "Daily Couples Quiz"
      }
    }
  ]
}
```

### 2. POST /api/sync/daily-quests

**Purpose:** Save generated quests
**Body:**
```json
{
  "dateKey": "2025-11-25",
  "quests": [
    {
      "id": "uuid",
      "questType": "quiz",
      "contentId": "uuid",
      "sortOrder": 0,
      "isSideQuest": false,
      "formatType": "classic",
      "quizName": "Daily Couples Quiz"
    }
  ]
}
```

### 3. POST /api/sync/daily-quests/completion

**Purpose:** Record quest completion
**Body:**
```json
{
  "quest_id": "uuid",
  "timestamp": "2025-11-25T10:00:00Z"
}
```

---

## 🧪 Testing Strategy

### Pre-Simulator Tests (Same as Love Points)

**1. API Testing (curl commands)**
```bash
# Test GET (empty - no quests yet)
curl -X GET "http://localhost:3000/api/sync/daily-quests?date=2025-11-25" \
  -H "X-Dev-User-Id: c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28"

# Test POST (create quests)
curl -X POST http://localhost:3000/api/sync/daily-quests \
  -H "Content-Type: application/json" \
  -H "X-Dev-User-Id: c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28" \
  -d '{
    "dateKey": "2025-11-25",
    "quests": [{
      "id": "550e8400-e29b-41d4-a716-446655440010",
      "questType": "quiz",
      "contentId": "650e8400-e29b-41d4-a716-446655440011",
      "sortOrder": 0,
      "isSideQuest": false,
      "formatType": "classic",
      "quizName": "Test Quiz"
    }]
  }'

# Test GET (should return quest)
curl -X GET "http://localhost:3000/api/sync/daily-quests?date=2025-11-25" \
  -H "X-Dev-User-Id: c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28"

# Test completion
curl -X POST http://localhost:3000/api/sync/daily-quests/completion \
  -H "Content-Type: application/json" \
  -H "X-Dev-User-Id: c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28" \
  -d '{
    "quest_id": "550e8400-e29b-41d4-a716-446655440010",
    "timestamp": "2025-11-25T10:00:00Z"
  }'
```

**2. Flutter Code Analysis**
```bash
flutter analyze lib/services/quest_sync_service.dart
```

**3. Logic Verification**
- Trace through sync flow (GET → empty → generate → POST)
- Trace through sync flow (GET → exists → load)
- Verify race condition handling (first vs second device)

### Simulator Tests (After API verified)

**Test Case 1: First Device Generates**
1. Clear Supabase quests for today
2. Launch Alice (Android) - should generate quests
3. Verify quests saved to Supabase
4. Check Alice's local storage has 3 quests

**Test Case 2: Second Device Loads**
1. Quests already exist in Supabase (from Test 1)
2. Launch Bob (Chrome) - should load from Supabase
3. Verify Bob has same 3 quests as Alice
4. Verify quest IDs match

**Test Case 3: Completion Sync**
1. Alice completes a quest
2. Check Supabase completion recorded
3. Verify completion shows on Alice's device

**Test Case 4: Race Condition**
1. Clear Supabase quests
2. Launch BOTH devices simultaneously
3. Verify only one set of quests generated
4. Verify both devices have same quests

---

## 📊 Complexity Comparison

| Aspect | Love Points | Daily Quests |
|--------|-------------|--------------|
| **Frequency** | Continuous (10s polling) | Once per day |
| **Listener** | Timer-based polling | One-time check |
| **Complexity** | HIGH (real-time) | MEDIUM (batch) |
| **API Calls** | Many (every 10s) | Few (once at startup) |
| **Testing** | Harder (timing-sensitive) | Easier (deterministic) |
| **Code Changes** | +171 lines | ~100 lines (estimated) |

**Daily Quests is SIMPLER because:**
- ✅ No continuous polling needed
- ✅ One-time read on app start (like Firebase)
- ✅ Race condition already handled (3-second wait pattern)
- ✅ API endpoints already complete
- ✅ No real-time sync requirements

---

## 🚨 Potential Issues & Solutions

### Issue 1: Race Condition (Two Devices Generate)

**Problem:** Both devices might generate quests if requests happen simultaneously

**Solution:**
- Use database constraint: `UNIQUE(couple_id, date, quest_type, sort_order)`
- API uses `ON CONFLICT` to handle duplicates (keep first)
- Second device's POST will update (not duplicate)

### Issue 2: Quest ID Mismatch

**Problem:** Local quest IDs don't match Supabase (like current Firebase issue)

**Solution:**
- Always use Supabase as source of truth
- Clear local quests if IDs don't match
- Load from Supabase (same logic as current Firebase path)

### Issue 3: Network Failure on Generation

**Problem:** First device generates but fails to POST to Supabase

**Solution:**
- Retry POST with exponential backoff
- If still fails, fall back to local quests
- Second device will generate if first device failed

---

## ✅ Definition of Done

**Code Complete:**
- [ ] Feature flag checked in all quest sync methods
- [ ] `_syncTodayQuestsSupabase()` implemented
- [ ] `_loadQuestsFromSupabase()` implemented
- [ ] `_saveQuestsToSupabaseOnly()` implemented
- [ ] Completion sync uses Supabase when flag TRUE
- [ ] Zero compile errors

**Testing Complete:**
- [ ] API endpoints tested with curl (GET, POST, completion)
- [ ] Flutter code compiles cleanly
- [ ] Logic traced and verified
- [ ] First device generates (simulator test)
- [ ] Second device loads (simulator test)
- [ ] Completion sync works (simulator test)
- [ ] Race condition handled (dual launch test)

**Documentation Complete:**
- [ ] This migration plan created ✅
- [ ] Test report created (after implementation)
- [ ] CLAUDE.md updated with new patterns

**Safety Verified:**
- [ ] Feature flag OFF by default
- [ ] No breaking changes
- [ ] No Linked files touched
- [ ] Backward compatible (Firebase path unchanged)

---

## 🎯 Estimated Timeline

**Phase 1: Implementation** (1 hour)
- Add new Supabase-only methods
- Modify existing methods to check flag
- Add error handling and logging

**Phase 2: Pre-Simulator Testing** (30 min)
- API testing with curl
- Flutter analysis
- Logic verification

**Phase 3: Simulator Testing** (30 min)
- First device generates
- Second device loads
- Completion sync
- Race condition test

**Phase 4: Documentation** (30 min)
- Test report
- Update CLAUDE.md
- Commit with flag OFF

**Total: 2-3 hours**

---

## 🚀 Next Steps

**Option A: Implement Now**
- Start implementation based on this plan
- Test with curl before simulators
- Commit with flag OFF

**Option B: Review & Approve Plan First**
- User reviews this plan
- Clarify any questions
- Then proceed with implementation

**Option C: Wait Until Later**
- Focus on Linked game completion
- Come back to Daily Quests later

---

**Migration Plan Status:** ✅ COMPLETE
**Ready for Implementation:** YES
**Waiting for:** User approval to proceed

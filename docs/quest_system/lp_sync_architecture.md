# Love Points Synchronization Architecture

**Status:** Architecture Analysis & Proposal
**Date:** 2025-11-14
**Context:** Addressing potential LP balance divergence between coupled users

---

## 1. Problem Statement

### Current Architecture Issues

**Current Implementation:**
- Each user stores their LP balance locally in Hive (`userBox`)
- Both users independently award themselves LP when completing quests
- Firebase RTDB `/lp_awards/{coupleId}/{questId}` prevents duplicate awards
- No single source of truth for couple's LP balance

**Identified Risks:**

1. **Offline Divergence:**
   - Alice completes quest offline → awards herself 100 LP
   - Bob completes same quest offline → awards himself 100 LP
   - Both sync to Firebase → both awards recorded
   - Result: Alice shows 100 LP, Bob shows 100 LP (correct individually but not synchronized)

2. **Race Conditions:**
   - Quest marked complete at same millisecond
   - Both devices check Firebase simultaneously
   - Both see "no award exists yet"
   - Both write award records
   - Both increment local LP

3. **No Reconciliation:**
   - If LP balances diverge, there's no mechanism to detect or fix
   - Users may see different totals
   - No audit trail to identify discrepancies

4. **Data Loss Scenarios:**
   - User clears app data → loses local LP balance
   - User switches devices → no LP migration
   - Database corruption → LP history lost

---

## 2. Fundamental Question

**Why do both users store the same LP value locally?**

### Current Model (Duplicated Storage)
```
Alice's Device:          Bob's Device:           Firebase RTDB:
┌──────────────┐        ┌──────────────┐        ┌──────────────────────┐
│ User:        │        │ User:        │        │ /lp_awards/          │
│   lp: 500    │        │   lp: 500    │        │   alice_bob/         │
│              │        │              │        │     quest_123: true  │
│ LP Txns:     │        │ LP Txns:     │        │     quest_124: true  │
│   - quest_123│        │   - quest_123│        └──────────────────────┘
│   - quest_124│        │   - quest_124│
└──────────────┘        └──────────────┘
```

**Issues:**
- Redundant storage
- Potential for drift
- Complex synchronization logic
- No authoritative source

### Alternative Model (Shared Source of Truth)
```
Alice's Device:          Bob's Device:           Firebase RTDB:
┌──────────────┐        ┌──────────────┐        ┌──────────────────────┐
│ User:        │        │ User:        │        │ /couples/            │
│   (no LP)    │        │   (no LP)    │        │   alice_bob/         │
│              │        │              │        │     lp: 500          │
│ LP Txns:     │        │ LP Txns:     │        │     transactions:    │
│   (cache)    │        │   (cache)    │        │       - quest_123    │
└──────────────┘        └──────────────┘        │       - quest_124    │
                                                 └──────────────────────┘
```

**Benefits:**
- Single source of truth
- Automatic synchronization
- Consistent view for both users
- Real-time updates via listeners

---

## 3. Proposed Solutions

### Option A: Keep Local Storage + Add Reconciliation (Minimal Change)

**Implementation:**
1. Keep current local LP storage
2. Add periodic Firebase sync check
3. Implement reconciliation on mismatch
4. Add conflict resolution strategy

**Code Changes:**
```dart
class LovePointService {
  // New: Periodic reconciliation
  Future<void> reconcileLPWithFirebase() async {
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    final coupleId = _generateCoupleId(user.id, partner.pushToken);

    // Fetch all LP awards from Firebase
    final snapshot = await _database.ref('lp_awards/$coupleId').get();
    final firebaseAwards = snapshot.value as Map?;

    // Fetch all local transactions
    final localTxns = _storage.getAllLPTransactions();

    // Compare and reconcile
    final localTotal = localTxns.fold(0, (sum, txn) => sum + txn.amount);
    final firebaseTotal = _calculateTotalFromAwards(firebaseAwards);

    if (localTotal != firebaseTotal) {
      print('⚠️ LP mismatch detected: local=$localTotal, firebase=$firebaseTotal');
      // Strategy: Trust Firebase as source of truth
      _storage.setUserLP(firebaseTotal);
      _rebuildLocalTransactionsFromFirebase(firebaseAwards);
    }
  }
}
```

**Pros:**
- Minimal code changes
- Maintains offline capability
- Backward compatible

**Cons:**
- Still risk of temporary divergence
- Complex reconciliation logic
- Race conditions still possible
- Periodic sync adds overhead

---

### Option B: Move LP to Firebase RTDB (Single Source of Truth)

**Implementation:**
1. Create `/couples/{coupleId}/lp_balance` in Firebase
2. Store LP transactions in Firebase
3. Cache locally for offline viewing (read-only)
4. Use Firebase transactions for atomic updates

**Code Changes:**
```dart
class LovePointService {
  // New: Award LP via Firebase transaction (atomic)
  Future<void> awardLPForQuest(DailyQuest quest) async {
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    final coupleId = _generateCoupleId(user.id, partner.pushToken);

    // Use Firebase transaction for atomic increment
    final lpRef = _database.ref('couples/$coupleId/lp_balance');

    await lpRef.runTransaction((currentValue) {
      final currentLP = (currentValue ?? 0) as int;
      return currentLP + quest.lpReward;
    });

    // Record transaction for history
    final txnRef = _database.ref('couples/$coupleId/lp_transactions').push();
    await txnRef.set({
      'questId': quest.id,
      'amount': quest.lpReward,
      'timestamp': ServerValue.timestamp,
      'awardedBy': user.id,
    });

    // Update local cache
    _storage.cacheLP(currentLP + quest.lpReward);
  }

  // New: Listen for LP changes
  void listenForLPUpdates() {
    final coupleId = _generateCoupleId(user.id, partner.pushToken);

    _database.ref('couples/$coupleId/lp_balance').onValue.listen((event) {
      final newLP = event.snapshot.value as int? ?? 0;
      _storage.cacheLP(newLP);

      // Notify UI
      if (mounted) setState(() {});
    });
  }
}
```

**Database Structure:**
```
/couples/
  {coupleId}/
    lp_balance: 500
    lp_transactions/
      {txnId1}/
        questId: "quest_123"
        amount: 100
        timestamp: 1699876543000
        awardedBy: "alice_id"
      {txnId2}/
        questId: "quest_124"
        amount: 100
        timestamp: 1699876789000
        awardedBy: "bob_id"
```

**Pros:**
- True single source of truth
- Atomic updates via Firebase transactions
- Real-time sync via listeners
- No reconciliation needed
- Consistent view for both users
- Survives app reinstalls

**Cons:**
- Requires Firebase connection to award LP
- Offline quest completion needs queuing
- More Firebase reads/writes (cost)
- Migration path for existing users

---

### Option C: Hybrid Approach (Best of Both)

**Implementation:**
1. Store LP balance in Firebase (source of truth)
2. Cache locally for offline reading
3. Queue LP awards when offline
4. Sync queue when online

**Code Changes:**
```dart
class LovePointService {
  final List<LPAwardRequest> _offlineQueue = [];

  // Award LP (online or offline)
  Future<void> awardLPForQuest(DailyQuest quest) async {
    if (await _isOnline()) {
      await _awardLPToFirebase(quest);
    } else {
      // Queue for later
      _offlineQueue.add(LPAwardRequest(
        questId: quest.id,
        amount: quest.lpReward,
        timestamp: DateTime.now(),
      ));

      // Optimistically update local cache
      final currentLP = _storage.getCachedLP();
      _storage.cacheLP(currentLP + quest.lpReward);
    }
  }

  // Sync queue when coming online
  Future<void> syncOfflineAwards() async {
    if (_offlineQueue.isEmpty) return;

    for (final award in _offlineQueue) {
      await _awardLPToFirebase(award);
    }

    _offlineQueue.clear();

    // Fetch authoritative balance from Firebase
    await _refreshLPFromFirebase();
  }
}
```

**Pros:**
- Works offline
- Single source of truth when online
- Optimistic UI updates
- Eventual consistency

**Cons:**
- More complex implementation
- Offline queue management
- Potential for temporary divergence

---

## 4. Recommendation

**Recommended Approach: Option B (Firebase as Source of Truth)**

### Rationale:

1. **Quest System Context:**
   - Quests already require Firebase for partner sync
   - LP awards happen when completing quests (already online)
   - Rare to complete quest while offline

2. **Consistency Priority:**
   - LP is a couple-shared resource
   - Both users should always see same balance
   - Divergence creates confusion and trust issues

3. **Simplicity:**
   - Eliminates complex reconciliation logic
   - Firebase transactions handle race conditions
   - Real-time listeners keep UI in sync

4. **User Experience:**
   - Partner sees LP update immediately
   - No "your LP is different than mine" scenarios
   - Survives app reinstalls

### Migration Strategy:

**Phase 1: Add Firebase LP Storage (Parallel)**
1. Create `/couples/{coupleId}/lp_balance` path
2. Keep writing to local storage
3. Also write to Firebase
4. Compare for inconsistencies

**Phase 2: Switch Reads to Firebase**
1. Start reading from Firebase
2. Fall back to local if offline
3. Monitor for issues

**Phase 3: Deprecate Local LP Balance**
1. Stop writing to local `user.lp`
2. Keep `lp_transactions` for history
3. Remove reconciliation code

---

## 5. Implementation Plan

### Step 1: Database Rules
```json
{
  "couples": {
    "$coupleId": {
      "lp_balance": {
        ".read": "true",
        ".write": "true"
      },
      "lp_transactions": {
        ".read": "true",
        "$txnId": {
          ".write": "newData.exists()"
        }
      }
    }
  }
}
```

### Step 2: Update LovePointService
- Add `_awardLPToFirebase()` method
- Add `listenForLPUpdates()` method
- Add `_refreshLPFromFirebase()` method
- Update `getLovePoints()` to read from cache

### Step 3: Update UI
- HomeScreen LP display listens to cache updates
- Add loading state while fetching initial LP
- Handle offline gracefully

### Step 4: Testing
- Test concurrent quest completions
- Test offline quest completion + sync
- Test app reinstall scenario
- Verify both users see same LP in real-time

---

## 6. Open Questions

1. **Offline Quest Completion:**
   - Should we allow LP awards offline with queuing (Option C)?
   - Or require connection for LP award (Option B)?

2. **Migration:**
   - How to migrate existing users' LP balances?
   - Trust local storage? Trust Firebase awards history?
   - One-time reconciliation script?

3. **LP Transactions:**
   - Keep local transactions for history/offline viewing?
   - Or move entirely to Firebase?

4. **Cost:**
   - Firebase reads/writes for LP queries?
   - Acceptable for 100 couples? 1,000? 10,000?

---

## 7. Next Steps

1. **Decision:** Choose between Option A, B, or C
2. **Prototype:** Implement chosen approach in dev branch
3. **Test:** Verify synchronization with Alice/Bob setup
4. **Document:** Update ARCHITECTURE.md with LP sync design
5. **Deploy:** Roll out with migration strategy

---

**Questions for Discussion:**
- Is offline LP awarding required for MVP?
- What's the acceptable cost for Firebase LP storage?
- Should we implement Option B (simple) or Option C (robust)?

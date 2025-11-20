# Memory Flip: Cross-Device Sync + Performance Fix

**Status:** Implementation Spec
**Created:** 2025-11-17
**Author:** AI Assistant
**Priority:** High (P0 - User-facing bugs)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Issue 1: Missing Cross-Device Synchronization](#issue-1-missing-cross-device-synchronization)
3. [Issue 2: Performance Bottleneck (5-Second Delay)](#issue-2-performance-bottleneck-5-second-delay)
4. [Implementation Plan](#implementation-plan)
5. [Detailed Task Breakdown](#detailed-task-breakdown)
6. [Testing Procedures](#testing-procedures)
7. [Rollout Strategy](#rollout-strategy)

---

## Executive Summary

### Problems Identified

**Issue 1: No Cross-Device Synchronization**
- Alice plays Memory Flip and matches cards
- Bob opens Memory Flip and sees a completely fresh game
- Root cause: Game state stored in local Hive only, no Firebase RTDB sync

**Issue 2: 5-Second Performance Delay**
- When Alice finds a match, it takes 5 seconds to show the success popup
- Root cause: Blocking network calls (syncMatch + sendMatchNotification) before UI update
- User experience: Feels laggy and unresponsive

### Impact

| Metric | Current State | Target State |
|--------|--------------|--------------|
| **Cross-device sync** | 0% (no sync) | 100% (real-time sync) |
| **Match popup delay** | ~5 seconds | <1 second |
| **User experience** | Broken collaboration | Smooth co-op gameplay |
| **Network resilience** | Blocks on failure | Graceful degradation |

### Solution Approach

1. **Performance Fix FIRST** (Phase 1): Quick win, immediate UX improvement
2. **Sync Implementation** (Phase 2): Add Firebase RTDB synchronization

---

## Issue 1: Missing Cross-Device Synchronization

### Current Architecture

**Storage Layer:**
- Memory Flip uses **local-only Hive storage**
- No Firebase RTDB sync (unlike Daily Quests)
- Each device has independent game state

**Data Flow (Current - Broken):**

```
Alice's Device:
1. getCurrentPuzzle() → Checks local Hive only
2. Generates new puzzle if none exists
3. Matches cards → Saves to local Hive
4. syncMatch() → Writes to Firestore (backup only)
5. sendMatchNotification() → Sends push notification

Bob's Device:
1. getCurrentPuzzle() → Checks local Hive only (empty)
2. Generates NEW puzzle (different from Alice's)
3. Result: Sees fresh game, NOT Alice's matches
```

### Why Daily Quests Work (Reference Pattern)

Daily Quests use a **"first device creates, second device loads"** pattern:

**Files:** `app/lib/services/quest_sync_service.dart`, `app/lib/services/daily_quest_service.dart`

```dart
// 1. Check Firebase FIRST (quest_sync_service.dart:41-75)
Future<bool> syncTodayQuests() async {
  final snapshot = await _database
    .child('daily_quests/$coupleId/$dateKey')
    .get();

  if (snapshot.exists) {
    // Load from Firebase (second device)
    _loadQuestsFromFirebase(snapshot, dateKey);
    return true;
  }

  // Generate locally (first device)
  return false; // Signal to generate
}

// 2. Upload after generation (quest_sync_service.dart:77-114)
Future<void> saveQuestsToFirebase(List<DailyQuest> quests) async {
  await _database.child('daily_quests/$coupleId/$dateKey').set({
    'quests': questsData,
    'generatedBy': currentUserId,
    'generatedAt': ServerValue.timestamp,
  });
}

// 3. Sync completions bidirectionally (quest_sync_service.dart:116-172)
Future<void> _syncCompletionStatus() async {
  // Read Firebase completions, update local state
  // Write local completions back to Firebase
}
```

### What Memory Flip Needs

**Firebase RTDB Path:**
```
/memory_puzzles/
  {coupleId}/
    {puzzleId}/
      - createdAt: timestamp
      - createdBy: userId
      - expiresAt: timestamp
      - totalPairs: 8
      - cards: [
          {
            id: string,
            position: int,
            emoji: string,
            pairId: string,
            status: 'hidden' | 'matched',
            matchedBy: userId | null,
            matchedAt: timestamp | null
          }
        ]
      - matches: {
          [userId]: {
            cardIds: [string, string],
            timestamp: timestamp
          }
        }
```

**Security Rules (database.rules.json):**
```json
"memory_puzzles": {
  "$coupleId": {
    "$puzzleId": {
      ".read": true,
      ".write": true
    }
  }
}
```

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `database.rules.json` | Modify | Add `/memory_puzzles/` security rules |
| `app/lib/services/memory_flip_sync_service.dart` | Create | New sync service (pattern from quest_sync_service.dart) |
| `app/lib/services/memory_flip_service.dart` | Modify | Add Firebase checks in getCurrentPuzzle() |
| `app/lib/screens/memory_flip_game_screen.dart` | Modify | Load from Firebase in _loadGameState() |

---

## Issue 2: Performance Bottleneck (5-Second Delay)

### Current Match Flow with Timing

**File:** `app/lib/screens/memory_flip_game_screen.dart`

**Method:** `_checkForMatch()` (lines 127-227)

```
Step 1: setState → isProcessing = true           [~1ms]
Step 2: await Future.delayed(600ms)               [600ms] ← Shows both cards
Step 3: Check for match (local)                   [~50ms]
Step 4: Decrement flip allowance (Hive write)     [~10ms]
Step 5: Reload allowance (Hive read)              [~5ms]

IF MATCH FOUND:
Step 6: await _service.syncMatch(...)             [2-4s] 🔴 BLOCKING NETWORK CALL
Step 7: await _service.sendMatchNotification(...) [1-2s] 🔴 BLOCKING NETWORK CALL
Step 8: await LovePointService.awardPoints(...)   [~20ms]
Step 9: await ActivityStreakService.record(...)   [~20ms]
Step 10: setState + clear flippedCards            [~5ms]
Step 11: await showDialog(...)                    [~10ms] ← FINALLY shows popup!

Total time: 600ms + 50ms + 25ms + 4-6s = ~5 seconds
```

### Root Cause: Blocking Network Calls

**Lines 160-173 in memory_flip_game_screen.dart:**

```dart
// Sync match to Firestore
await _service.syncMatch(           // ❌ BLOCKING 2-4 seconds
  _puzzle!.id,
  [card1.id, card2.id],
  _userId!,
);

// Send push notification to partner
await _service.sendMatchNotification(  // ❌ BLOCKING 1-2 seconds
  partnerToken: partner.pushToken,
  senderName: user.name ?? 'Your Partner',
  emoji: matchResult.card1.emoji,
  quote: matchResult.quote,
  lovePoints: matchResult.lovePoints,
);
```

### Why These Calls Don't Need to Block

**What the dialog needs:**
- Matched cards (already in memory ✅)
- Quote (already in MatchResult ✅)
- Love points (already calculated ✅)

**What the dialog DOESN'T need:**
- Network confirmation from Firestore ❌
- Push notification delivery status ❌

**Service already designed for offline play:**

From `memory_flip_service.dart`:
- Line 333: `// Don't throw - allow offline play` (syncFlip)
- Line 353: `// Don't throw - allow offline play` (syncMatch)
- Line 376: `// Don't throw - notification is not critical` (sendMatchNotification)

### Solution: Fire-and-Forget Pattern

**Move network calls to background, show UI immediately:**

```dart
// Start background operations WITHOUT blocking
if (partner != null && user != null) {
  // Fire-and-forget: No await
  _service.syncMatch(
    _puzzle!.id,
    [card1.id, card2.id],
    _userId!,
  ).catchError((e) {
    Logger.error('Error syncing match', error: e, service: 'memory_flip');
  });

  _service.sendMatchNotification(
    partnerToken: partner.pushToken,
    senderName: user.name ?? 'Your Partner',
    emoji: matchResult.card1.emoji,
    quote: matchResult.quote,
    lovePoints: matchResult.lovePoints,
  ).catchError((e) {
    Logger.error('Error sending notification', error: e, service: 'memory_flip');
  });

  // KEEP await on critical local operations
  await LovePointService.awardPoints(...);
  await GeneralActivityStreakService().recordActivity();
}

// Show dialog IMMEDIATELY (no wait for network)
setState(() {
  _allowance = updatedAllowance;
  _flippedCards.clear();
  _isProcessing = false;
});

if (mounted) {
  await showDialog(...);  // Shows in ~800ms total!
}
```

**New timing:**
```
Step 1-5: Same as before                          [~665ms]
Step 6-7: Network calls (background, NO await)    [0ms blocking]
Step 8: await LovePointService.awardPoints(...)   [~20ms]
Step 9: await ActivityStreakService.record(...)   [~20ms]
Step 10: setState + clear flippedCards            [~5ms]
Step 11: await showDialog(...)                    [~10ms]

Total time: ~720ms (down from 5 seconds!) ✅
```

---

## Implementation Plan

### Phase 1: Performance Fix (Quick Win)

**Goal:** Reduce match popup delay from 5s → <1s

**Files to modify:**
- `app/lib/screens/memory_flip_game_screen.dart`

**Tasks:**
1. Remove `await` from `syncMatch()` call (line 160)
2. Remove `await` from `sendMatchNotification()` call (line 167)
3. Add `.catchError()` handlers to both calls
4. Keep `await` on `LovePointService.awardPoints()` (critical)
5. Keep `await` on `GeneralActivityStreakService.recordActivity()` (critical)

**Estimated time:** 15 minutes
**Risk:** Low (service already designed for offline play)

---

### Phase 2: Cross-Device Synchronization

**Goal:** Enable Alice and Bob to collaborate on the same puzzle

#### Step 1: Add Firebase RTDB Security Rules

**File:** `database.rules.json`

**Add:**
```json
"memory_puzzles": {
  "$coupleId": {
    "$puzzleId": {
      ".read": true,
      ".write": true
    }
  }
}
```

**Deploy:**
```bash
firebase deploy --only database
```

**Estimated time:** 5 minutes
**Risk:** Low (standard security rules pattern)

---

#### Step 2: Create MemoryFlipSyncService

**File:** `app/lib/services/memory_flip_sync_service.dart` (NEW)

**Pattern from:** `quest_sync_service.dart`

**Methods to implement:**

```dart
class MemoryFlipSyncService {
  final FirebaseDatabase _database;
  final StorageService _storage;

  // Check Firebase first, load if exists, return false if need to generate
  Future<MemoryPuzzle?> syncPuzzle(String coupleId, String puzzleId);

  // Upload new puzzle to Firebase (first device generates)
  Future<void> savePuzzleToFirebase(MemoryPuzzle puzzle, String coupleId);

  // Sync match state to Firebase (card status updates)
  Future<void> syncMatchToFirebase(
    String coupleId,
    String puzzleId,
    String cardId1,
    String cardId2,
    String userId
  );

  // Load partner's puzzle from Firebase (second device)
  Future<MemoryPuzzle?> loadPuzzleFromFirebase(String coupleId, String puzzleId);

  // Listen for partner's matches in real-time
  Stream<Map<String, dynamic>> watchPuzzleUpdates(String coupleId, String puzzleId);
}
```

**Estimated time:** 2-3 hours
**Risk:** Medium (new service, needs testing)

---

#### Step 3: Update MemoryFlipService

**File:** `app/lib/services/memory_flip_service.dart`

**Changes:**

**3a. Add couple ID generation (like QuestUtilities)**

```dart
String _getCoupleId() {
  final user = _storage.getUser();
  final partner = _storage.getPartner();

  if (user == null || partner == null) {
    throw Exception('User or partner not found');
  }

  // Sort FCM tokens to ensure consistent couple ID
  final tokens = [user.pushToken, partner.pushToken]..sort();
  return tokens.join('_');
}
```

**3b. Update getCurrentPuzzle() - Check Firebase first**

```dart
Future<MemoryPuzzle?> getCurrentPuzzle() async {
  // Check local first (fast path)
  var puzzle = _storage.getActivePuzzle();

  if (puzzle != null && !_isPuzzleExpired(puzzle)) {
    return puzzle;
  }

  // Check Firebase (second device loads partner's puzzle)
  try {
    final coupleId = _getCoupleId();
    final puzzleId = _generatePuzzleId(DateTime.now());

    final syncService = MemoryFlipSyncService();
    final firebasePuzzle = await syncService.loadPuzzleFromFirebase(
      coupleId,
      puzzleId
    );

    if (firebasePuzzle != null) {
      // Partner already generated puzzle, use theirs
      _storage.saveMemoryPuzzle(firebasePuzzle);
      return firebasePuzzle;
    }
  } catch (e) {
    Logger.error('Error loading puzzle from Firebase',
                 error: e,
                 service: 'memory_flip');
  }

  // No puzzle in Firebase, generate new one (first device)
  puzzle = await generateDailyPuzzle();

  // Upload to Firebase for partner
  try {
    final coupleId = _getCoupleId();
    final syncService = MemoryFlipSyncService();
    await syncService.savePuzzleToFirebase(puzzle, coupleId);
  } catch (e) {
    Logger.error('Error saving puzzle to Firebase',
                 error: e,
                 service: 'memory_flip');
  }

  return puzzle;
}
```

**3c. Update matchCards() - Sync to Firebase RTDB**

```dart
Future<MatchResult> matchCards(String cardId1, String cardId2) async {
  // Existing local logic...
  final result = _performLocalMatch(cardId1, cardId2);

  // Sync to Firebase RTDB (in addition to Firestore)
  try {
    final coupleId = _getCoupleId();
    final userId = _storage.getUser()?.id;

    if (userId != null) {
      final syncService = MemoryFlipSyncService();
      await syncService.syncMatchToFirebase(
        coupleId,
        puzzle.id,
        cardId1,
        cardId2,
        userId,
      );
    }
  } catch (e) {
    Logger.error('Error syncing match to Firebase RTDB',
                 error: e,
                 service: 'memory_flip');
  }

  return result;
}
```

**Estimated time:** 1-2 hours
**Risk:** Medium (core logic changes)

---

#### Step 4: Update Game Screen

**File:** `app/lib/screens/memory_flip_game_screen.dart`

**Changes:**

**4a. Update _loadGameState() - Load from Firebase**

```dart
Future<void> _loadGameState() async {
  setState(() => _isLoading = true);

  try {
    // getCurrentPuzzle now checks Firebase first
    final puzzle = await _service.getCurrentPuzzle();

    if (puzzle == null) {
      // Show error state
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    // Load puzzle state (now includes partner's matches)
    setState(() {
      _puzzle = puzzle;
      _isLoading = false;
    });

    // Load allowance
    await _loadFlipAllowance();
  } catch (e) {
    Logger.error('Error loading game state',
                 error: e,
                 service: 'memory_flip');
    setState(() {
      _isLoading = false;
      _hasError = true;
    });
  }
}
```

**4b. Optional: Listen for partner's matches in real-time**

```dart
void _listenForPartnerMatches() {
  final coupleId = _getCoupleId();
  final puzzleId = _puzzle?.id;

  if (coupleId == null || puzzleId == null) return;

  final syncService = MemoryFlipSyncService();
  _matchSubscription = syncService
    .watchPuzzleUpdates(coupleId, puzzleId)
    .listen((update) {
      // Update local state when partner makes a match
      setState(() {
        _updatePuzzleFromFirebase(update);
      });
    });
}

@override
void dispose() {
  _matchSubscription?.cancel();
  super.dispose();
}
```

**Estimated time:** 1 hour
**Risk:** Low (mostly UI updates)

---

## Detailed Task Breakdown

### Phase 1: Performance Fix

| # | Task | File | Lines | Time | Risk |
|---|------|------|-------|------|------|
| 1 | Remove `await` from `syncMatch()` | memory_flip_game_screen.dart | 160 | 2 min | Low |
| 2 | Remove `await` from `sendMatchNotification()` | memory_flip_game_screen.dart | 167 | 2 min | Low |
| 3 | Add `.catchError()` to `syncMatch()` | memory_flip_game_screen.dart | 160-164 | 5 min | Low |
| 4 | Add `.catchError()` to `sendMatchNotification()` | memory_flip_game_screen.dart | 167-173 | 5 min | Low |
| 5 | Test: Measure match popup timing | Manual testing | - | 10 min | - |

**Total Phase 1: ~25 minutes**

---

### Phase 2: Cross-Device Sync

| # | Task | File | Lines | Time | Risk |
|---|------|------|-------|------|------|
| 6 | Add `/memory_puzzles` security rules | database.rules.json | - | 5 min | Low |
| 7 | Deploy Firebase rules | CLI | - | 2 min | Low |
| 8 | Create MemoryFlipSyncService skeleton | memory_flip_sync_service.dart | - | 30 min | Low |
| 9 | Implement `syncPuzzle()` method | memory_flip_sync_service.dart | - | 45 min | Med |
| 10 | Implement `savePuzzleToFirebase()` | memory_flip_sync_service.dart | - | 30 min | Med |
| 11 | Implement `syncMatchToFirebase()` | memory_flip_sync_service.dart | - | 30 min | Med |
| 12 | Implement `loadPuzzleFromFirebase()` | memory_flip_sync_service.dart | - | 30 min | Med |
| 13 | Add `_getCoupleId()` to MemoryFlipService | memory_flip_service.dart | - | 15 min | Low |
| 14 | Update `getCurrentPuzzle()` with Firebase check | memory_flip_service.dart | 94-108 | 45 min | Med |
| 15 | Update `matchCards()` to sync Firebase RTDB | memory_flip_service.dart | 182-209 | 30 min | Med |
| 16 | Update `_loadGameState()` in screen | memory_flip_game_screen.dart | 45-94 | 30 min | Low |
| 17 | Optional: Add real-time listener | memory_flip_game_screen.dart | - | 45 min | Med |

**Total Phase 2: ~5-6 hours**

---

## Testing Procedures

### Performance Fix Testing

**Goal:** Verify match popup appears in <1 second

**Procedure:**
1. Launch app on any device
2. Play Memory Flip
3. Find a matching pair
4. **Measure time:** From 2nd card flip → popup appears
5. **Expected:** <1 second (down from 5 seconds)
6. **Verify:** Push notification still sends to partner
7. **Verify:** Firestore still syncs (check Firebase Console)

**Edge cases:**
- Test with network disabled (should still work)
- Test with slow 3G connection (should not block UI)
- Test with partner offline (should not crash)

---

### Cross-Device Sync Testing

**Use the Complete Clean Testing Procedure:**

```bash
# 1. Kill existing Flutter processes
pkill -9 -f "flutter"

# 2. Uninstall Android app (fresh Hive storage)
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind

# 3. Clear Firebase RTDB
cd /Users/joakimachren/Desktop/togetherremind
firebase database:remove /memory_puzzles --force

# 4. Launch Alice (Android) - generates fresh puzzle
cd /Users/joakimachren/Desktop/togetherremind/app
flutter run -d emulator-5554 &

# Wait for "Memory Flip puzzle generated" log

# 5. Launch Bob (Chrome) - loads Alice's puzzle
flutter run -d chrome &
```

**Test Cases:**

| Test | Alice Action | Bob's Expected State | Pass Criteria |
|------|--------------|---------------------|---------------|
| T1 | Generate puzzle | Sees same puzzle | Card positions match |
| T2 | Match 1 pair | Sees 1 matched pair | Same cards matched |
| T3 | Match 2 pairs | Sees 2 matched pairs | Same cards matched |
| T4 | Complete puzzle | Sees completed puzzle | All 8 pairs matched |
| T5 | Bob matches pair | Alice sees Bob's match | Real-time sync works |
| T6 | Clear local Hive | Bob reloads, sees synced state | Firebase is source of truth |

**Edge Cases:**
- T7: Alice offline, Bob opens game → Should load cached version or show error
- T8: Both devices generate simultaneously → Should resolve to one puzzle (first write wins)
- T9: Network fails mid-game → Should degrade gracefully, sync when reconnected
- T10: Partner unpaired → Should generate local-only puzzle

---

## Rollout Strategy

### Recommended Order

1. **Implement Performance Fix (Phase 1)**
   - Quick win, immediate UX improvement
   - Low risk, easy to test
   - Deploy independently

2. **Test Performance Fix Thoroughly**
   - Measure timing improvements
   - Verify no regressions
   - Confirm offline play works

3. **Implement Sync (Phase 2)**
   - Larger change, needs careful testing
   - Test with clean testing procedure
   - Verify both devices see same state

4. **Beta Testing**
   - Test with real devices (iOS + Android)
   - Monitor Firebase usage/costs
   - Gather user feedback

5. **Production Rollout**
   - Deploy Firebase security rules first
   - Deploy app update
   - Monitor error logs

---

## Success Metrics

| Metric | Before | After | Measurement Method |
|--------|--------|-------|-------------------|
| Match popup delay | ~5 seconds | <1 second | Stopwatch / logs |
| Cross-device sync | 0% (broken) | 100% (working) | Manual testing |
| Offline play | Works | Still works | Disable network test |
| User satisfaction | Low (laggy) | High (responsive) | User feedback |
| Firebase costs | Minimal | Minimal | Firebase Console |

---

## Migration Notes

### No Breaking Changes

- Existing local puzzles continue to work
- No Hive schema changes required
- No data migration needed

### Backwards Compatibility

- App works offline (no Firebase required)
- Graceful degradation if Firebase unavailable
- No changes to Cloud Functions

---

## Future Enhancements (Out of Scope)

- Show which partner matched which pairs (UI enhancement)
- Shared flip allowance pool (current: separate per user)
- Puzzle difficulty settings (4×4, 5×5, 6×6 grids)
- Custom emoji packs
- Leaderboard / statistics

---

## Related Documentation

- [CLAUDE.md](../CLAUDE.md) - General architecture patterns
- [QUEST_SYSTEM_V2.md](./QUEST_SYSTEM_V2.md) - Quest sync reference implementation
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Testing procedures

---

**Last Updated:** 2025-11-17
**Status:** Ready for Implementation
**Estimated Total Time:** 6-7 hours
**Priority:** High (P0 - User-facing bugs)

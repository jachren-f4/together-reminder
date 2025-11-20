# TogetherRemind - Backend Storage & Sync Architecture

**Version:** 1.0
**Date:** 2025-11-18
**Purpose:** Technical documentation of data synchronization patterns for external review

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Core Design Patterns](#core-design-patterns)
3. [Feature-Specific Sync Mechanisms](#feature-specific-sync-mechanisms)
4. [Security & Authentication Model](#security--authentication-model)
5. [Edge Cases & Design Decisions](#edge-cases--design-decisions)
6. [Known Limitations & Areas for Feedback](#known-limitations--areas-for-feedback)

---

## Architecture Overview

### Tech Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Frontend** | Flutter 3.16+ (Dart 3.2+) | Cross-platform mobile app (iOS/Android) |
| **Local Storage** | Hive (NoSQL key-value store) | On-device data persistence |
| **Sync Layer** | Firebase Realtime Database (RTDB) | Cross-device synchronization between partners |
| **Functions** | Firebase Cloud Functions (Node.js 20) | Push notifications only |
| **Authentication** | None (device pairing via FCM tokens) | Simplified couple pairing |

### Data Flow Philosophy

```
Device A (Alice)                    Firebase RTDB                    Device B (Bob)
┌─────────────┐                   ┌──────────────┐                 ┌─────────────┐
│             │                   │              │                 │             │
│  Hive       │ ──── write ────> │  Shared      │ <─── listen ─── │  Hive       │
│  (local)    │                   │  Data        │                 │  (local)    │
│             │ <─── listen ───── │  (synced)    │ ──── write ───> │             │
│             │                   │              │                 │             │
└─────────────┘                   └──────────────┘                 └─────────────┘
```

**Key principle:** Local-first with selective Firebase sync for couple-shared data only.

---

## Core Design Patterns

### Pattern 1: "First User Creates, Second User Loads"

**Used for:** Daily Quests, Memory Flip Puzzles, Quiz Sessions

**Problem:** Both partners need identical game content (same questions, same puzzle cards) to play together, but content is randomly generated.

**Solution:** Deterministic device priority based on alphabetically sorted user IDs.

```dart
// Determine device priority
final sortedIds = [currentUserId, partnerUserId]..sort();
final isSecondDevice = currentUserId == sortedIds[1];

if (isSecondDevice) {
  // Wait 3 seconds for first device to generate and sync
  await Future.delayed(const Duration(seconds: 3));
}

// Check Firebase first
final snapshot = await questsRef.get();

if (snapshot.exists) {
  // Load from Firebase (preserving IDs)
  loadFromFirebase(snapshot);
} else {
  // Generate new content (only first device reaches here)
  generateAndSyncToFirebase();
}
```

**Benefits:**
- Deterministic (same device always generates)
- No race conditions
- No duplicate generation
- Works offline (falls back to local generation)

**Tradeoffs:**
- 3-5 second delay for second device on first load
- Requires retry logic if first device is offline

### Pattern 2: "Atomic Deduplication via Firebase Child Keys"

**Used for:** Love Points Awards (shared activity rewards)

**Problem:** Both devices award points simultaneously for shared activities, causing duplicates.

**Solution:** Use content ID as Firebase child key + onChildAdded listener.

```dart
// Award LP to both users (either device can call this)
Future<void> awardPointsToBothUsers({
  required String relatedId,  // e.g., questId
  required int amount,
}) async {
  final awardKey = relatedId; // Use questId as Firebase key

  // Both devices write to same path
  await database.child('lp_awards/$coupleId/$awardKey').set({
    'users': [userId1, userId2],
    'amount': amount,
    'timestamp': ServerValue.timestamp,
  });
}

// Listener (set up once on app start)
database.child('lp_awards/$coupleId').onChildAdded.listen((event) {
  // Even if both devices write to same key,
  // onChildAdded only fires ONCE per unique child path
  awardPointsLocally(event.data);

  // Additional local tracking prevents re-processing
  markAwardAsApplied(event.key);
});
```

**Benefits:**
- Works even if both devices trigger award simultaneously
- No server-side logic needed
- Firebase atomic operations handle race conditions
- Local deduplication adds safety layer

**How it prevents duplicates:**
1. **Firebase level:** `onChildAdded` fires once per unique child key
2. **Local level:** `appliedLPAwards` set tracks processed awards

### Pattern 3: "Completion Status Sync with Partial Updates"

**Used for:** Daily Quest Completions, Quiz Session Answers

**Problem:** Track individual progress while syncing overall completion state.

**Firebase structure:**
```json
/daily_quests/{coupleId}/{dateKey}/
  quests: [...]
  completions: {
    "quest_123": {
      "user_alice": true,
      "user_bob": true
    }
  }
```

**Implementation:**
```dart
// Mark quest completed (individual)
await database
  .child('daily_quests/$coupleId/$dateKey/completions/$questId/$userId')
  .set(true);

// Listen for partner completions
database
  .child('daily_quests/$coupleId/$dateKey/completions')
  .onValue
  .listen((event) {
    // Update local quest status when partner completes
    updateLocalQuestStatus(event.data);
  });
```

**Benefits:**
- Fine-grained sync (only completion status updates)
- Both partners see real-time progress
- Minimal data transfer
- Supports offline completion (syncs when back online)

---

## Feature-Specific Sync Mechanisms

### Daily Quests (Hybrid Sync)

**Firebase paths:**
- `/daily_quests/{coupleId}/{dateKey}/quests` - Quest list (written once by first device)
- `/daily_quests/{coupleId}/{dateKey}/completions/{questId}/{userId}` - Completion tracking

**Sync flow:**

1. **App Launch (both devices):**
   ```
   Check Firebase for today's quests
   ├─ If exists: Load from Firebase (preserving IDs)
   ├─ If not exists:
   │  ├─ First device: Generate → Save to Hive → Sync to Firebase
   │  └─ Second device: Wait 3s → Retry load → Generate if still missing
   ```

2. **Quest Completion:**
   ```
   User completes quest locally
   ├─ Update Hive (instant UI update)
   ├─ Write completion to Firebase (/completions/{questId}/{userId} = true)
   └─ Partner's listener triggers → Update partner's UI
   ```

3. **Data denormalization:** Quest metadata (formatType, quizName) stored in quest object to avoid session lookups on partner's device.

**Key files:**
- `lib/services/quest_sync_service.dart` - Sync orchestration
- `lib/services/daily_quest_service.dart` - Quest generation
- `lib/services/quest_type_manager.dart` - Provider pattern for quest types

### Love Points (Bilateral Sync)

**Firebase paths:**
- `/lp_awards/{coupleId}/{awardId}` - LP award records

**Sync flow:**

```
Shared activity completed (e.g., both finish quiz)
├─ Either device writes to Firebase:
│  /lp_awards/{coupleId}/{questId}
│  { users: [alice, bob], amount: 30, reason: "quiz" }
│
├─ Both devices listening with onChildAdded
│  ├─ Listener fires ONCE per unique child key
│  ├─ Check: Award not already applied locally?
│  ├─ Apply points to local Hive storage
│  ├─ Mark award as applied (prevent re-processing)
│  └─ Show notification banner ("+30 LP 💰")
```

**Deduplication layers:**
1. Firebase: `onChildAdded` only fires once per child path
2. Local: `appliedLPAwards` set prevents re-processing
3. Atomic: Both writes to same key merge (last write wins, but data identical)

**Key files:**
- `lib/services/love_point_service.dart:201-240` - Award syncing
- `lib/services/love_point_service.dart:242-272` - Listener setup
- `lib/services/love_point_service.dart:274-324` - Award handling

### Memory Flip Puzzle (Full State Sync)

**Firebase paths:**
- `/memory_puzzles/{coupleId}/{puzzleId}` - Full puzzle state (cards, matches, status)

**Sync flow:**

1. **Puzzle Generation:**
   ```
   First device:
   ├─ Generate 4x4 grid with 8 pairs
   ├─ Assign reveal quotes to each card
   ├─ Save to Hive
   └─ Sync to Firebase (full puzzle state)

   Second device:
   ├─ Wait 2s
   ├─ Load from Firebase
   └─ Save to Hive (identical puzzle)
   ```

2. **Match Discovery:**
   ```
   User finds match locally
   ├─ Update cards in Hive (status = 'matched')
   ├─ Sync match to Firebase:
   │  └─ Update specific cards + matchedPairs count
   └─ Partner's next load sees updated state
   ```

**Design choice:** No real-time sync during gameplay (deliberate). Partner sees updates on next puzzle open.

**Key files:**
- `lib/services/memory_flip_sync_service.dart` - Sync logic
- `lib/services/memory_flip_service.dart` - Game logic

### You or Me Game (Session Sync)

**Firebase paths:**
- `/you_or_me_sessions/{sessionId}` - Shared session with questions/answers

**Sync flow:**

```
Single session shared by both users:
├─ First user creates session → Syncs to Firebase
├─ Second user loads session from Firebase
├─ Both answer questions locally → Update same Firebase session
├─ Results screen loads Firebase session → Calculates comparison
```

**Question progression tracking:**
- `/you_or_me_progression/{coupleId}` - Used question IDs (prevents repetition)
- Resets when pool exhausted

**Key files:**
- `lib/services/you_or_me_service.dart:178-235` - Session creation & sync
- `lib/models/you_or_me.dart` - Data models

---

## Security & Authentication Model

### No Traditional Auth

**Design:** App uses FCM (Firebase Cloud Messaging) tokens as user identifiers.

**Pairing flow:**
1. Alice generates QR code containing her FCM token
2. Bob scans QR code → Saves Alice as partner
3. Bob's device sends pairing confirmation with his FCM token
4. Both devices now have partner's FCM token → Couple paired

**Couple ID generation:**
```dart
final sortedIds = [userId1, userId2]..sort();
final coupleId = '${sortedIds[0]}_${sortedIds[1]}';
```

**Security posture:**

| Aspect | Implementation | Risk Level |
|--------|----------------|------------|
| **Data access** | Anyone with couple ID can read/write shared data | 🔴 High |
| **FCM tokens** | Not secret (sent in push notifications) | 🟡 Medium |
| **Firebase rules** | Basic path validation only | 🔴 High |
| **Pairing** | QR code or remote code (6-digit, 15min expiry) | 🟡 Medium |

**Current Firebase Security Rules:**

```json
{
  "rules": {
    "daily_quests": {
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

**Trade-offs:**
- ✅ **Pro:** Zero authentication friction, fast pairing
- ✅ **Pro:** Works offline after initial pairing
- ❌ **Con:** No user authentication (token = identity)
- ❌ **Con:** Couple data accessible if couple ID discovered
- ❌ **Con:** No multi-device support per user

---

## Edge Cases & Design Decisions

### Race Conditions

**Problem:** Both devices check Firebase simultaneously, both see "no data", both generate content.

**Solution:** Alphabetically sorted user IDs determine priority. Second device always waits.

**Failure mode:** If first device is offline, second device eventually generates (after 5s timeout).

### Offline Support

**Behavior:**
- ✅ Local gameplay works offline (Hive storage)
- ✅ Sync resumes when connection restored
- ❌ Partners might have different quests if both offline during generation
- ❌ No conflict resolution (last write wins)

### Clock Skew

**Problem:** Device clocks differ → Different "today" date keys.

**Mitigation:**
- Server timestamps used in Firebase (`ServerValue.timestamp`)
- Date keys generated from device local time (deliberate - respects user timezone)
- Quest expiry at 23:59:59 local time

**Known issue:** Partners in different timezones might see quests expire at different times.

### Duplicate LP Awards

**Original bug:** Calling `startListeningForLPAwards()` multiple times created duplicate listeners → 60 LP instead of 30 LP.

**Fix:**
- Listener started ONCE in `main.dart`
- Screens use `setLPChangeCallback()` for UI updates (not `startListeningForLPAwards()`)

**Documentation:** Heavily documented in `CLAUDE.md` critical rules.

### Quest Title Display

**Problem:** Alice creates quiz session locally → syncs quest to Bob → Bob has quest but no local session → title lookup fails.

**Solution:** Denormalize metadata (`formatType`, `quizName`) in quest object itself.

```dart
// ❌ Wrong - session lookup fails on partner device
final session = storage.getQuizSession(quest.contentId);
return session?.quizName ?? 'Quiz';

// ✅ Correct - metadata in quest object
return quest.quizName ?? 'Quiz';
```

### Data Retention

**Automatic cleanup:**
- Daily quests: 7 days (implemented)
- Quiz sessions: No auto-cleanup (stored indefinitely)
- LP awards: No auto-cleanup (stored indefinitely)
- Memory puzzles: No auto-cleanup (stored indefinitely)

**Storage growth:** No limits implemented. Firebase RTDB size could grow unbounded.

---

## Known Limitations & Areas for Feedback

### 1. Scalability Concerns

**Current model:** All couple data in single Firebase RTDB instance.

**Questions:**
- At what couple count does this become problematic?
- Should we shard by couple ID hash?
- Is RTDB the right choice vs. Firestore?

### 2. Security Model

**Current approach:** FCM tokens as identity, no real auth.

**Questions:**
- How vulnerable is this to token theft?
- Should we add proper authentication (Firebase Auth)?
- How to maintain "zero friction" pairing experience?

### 3. Conflict Resolution

**Current approach:** Last write wins, no conflict detection.

**Scenarios:**
- Both devices complete quest offline → Sync later
- Both devices match same cards in Memory Flip offline
- No merge strategy, no CRDTs

**Questions:**
- Do we need operational transformation for real-time sync?
- Should we implement vector clocks or CRDTs?
- Is eventual consistency sufficient for this use case?

### 4. Real-Time vs. Polling

**Current approach:** Firebase RTDB listeners for real-time updates.

**Questions:**
- Is onChildAdded the right pattern for LP awards?
- Should we use onValue with snapshots instead?
- How to handle listener cleanup on app lifecycle changes?

### 5. Data Denormalization

**Current approach:** Store metadata in multiple places (quest object, session object).

**Trade-offs:**
- ✅ Fast reads (no joins)
- ❌ Update complexity
- ❌ Data consistency risk

**Questions:**
- Is this the right trade-off for mobile apps?
- Should we normalize more and accept slower reads?

### 6. Offline-First Architecture

**Current approach:** Hive-first, Firebase for sync only.

**Questions:**
- Should we use Firebase Local Persistence?
- How to handle schema migrations in Hive?
- Better patterns for offline-first mobile apps?

### 7. Testing Strategy

**Current approach:** Manual two-device testing (Android emulator + Chrome).

**Questions:**
- How to automate sync testing?
- Best practices for testing race conditions?
- Mock Firebase vs. Firebase emulator?

---

## Technical Metrics

### Data Transfer Patterns

| Feature | Write Size | Read Size | Frequency |
|---------|-----------|-----------|-----------|
| Daily Quests | ~2 KB | ~2 KB | Once/day |
| Quest Completion | ~50 B | ~50 B | 3-4x/day |
| LP Award | ~200 B | ~200 B | 3-4x/day |
| Memory Flip Puzzle | ~3 KB | ~3 KB | Once/day |
| Memory Match | ~100 B | ~100 B | 8-16x/puzzle |
| You or Me Session | ~1.5 KB | ~1.5 KB | Once/session |

### Firebase RTDB Structure Size

**Per couple, per day:**
- Daily quests: ~2 KB
- Completions: ~150 B
- LP awards: ~600 B (assuming 3 awards)
- Total: ~3 KB/day

**Per couple, per month:** ~90 KB (with 7-day retention)

**For 10,000 couples:** ~900 MB/month (within Firebase free tier: 1 GB stored, 10 GB/month downloaded)

---

## File Reference

### Core Services
- `lib/services/storage_service.dart` - Hive box management (20 boxes)
- `lib/services/quest_sync_service.dart` - Daily quest sync
- `lib/services/love_point_service.dart` - LP awards & sync
- `lib/services/memory_flip_sync_service.dart` - Memory Flip sync
- `lib/services/you_or_me_service.dart` - You or Me session sync

### Models
- `lib/models/daily_quest.dart` - Quest data model
- `lib/models/love_point_transaction.dart` - LP transaction model
- `lib/models/memory_flip.dart` - Puzzle & card models
- `lib/models/you_or_me.dart` - Session & question models

### Configuration
- `database.rules.json` - Firebase RTDB security rules
- `lib/config/dev_config.dart` - Mock data control

---

## Questions for Expert Review

1. **Architecture choice:** Is Firebase RTDB appropriate for this use case, or should we migrate to Firestore?

2. **Security model:** Given the "couples only" use case, is FCM-token-based identity acceptable, or should we implement proper authentication?

3. **Sync patterns:** Are our "first user creates" and "atomic deduplication" patterns sound, or are there better approaches?

4. **Conflict resolution:** Do we need more sophisticated conflict resolution (CRDTs, OT), or is eventual consistency sufficient?

5. **Offline support:** Are we handling offline/online transitions correctly? Any edge cases we're missing?

6. **Scalability:** At what scale does this architecture break down? What would you change first?

7. **Data modeling:** Is our denormalization strategy (metadata in quest objects) appropriate, or should we normalize more?

8. **Real-time sync:** Should Memory Flip have real-time match sync, or is the current "sync on next load" acceptable?

---

**Contact:** For questions about implementation details, see `docs/ARCHITECTURE.md` or `CLAUDE.md` in the repository.

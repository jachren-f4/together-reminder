# Known Issues & Solutions

This document tracks known issues, bugs, and their solutions to prevent regression and aid future debugging.

---

## Quest Card Not Updating After Completion

**Date Discovered:** 2025-11-17
**Status:** ✅ FIXED
**Severity:** Medium (UX issue, no data loss)

### Symptom

After completing a quest (e.g., "You or Me"), the quest card on the home screen continues to show "YOUR TURN" instead of updating to "Waiting for partner". However, tapping the card correctly shows the waiting screen, indicating the data layer is working correctly.

### Root Cause

The issue was caused by incorrect navigation flow using `Navigator.pushReplacement()` instead of `Navigator.push()` when navigating from the quest intro screen to the game screen.

**Navigation Flow (BROKEN):**
```
Home → Quest Intro (push) → Quest Game (pushReplacement)
                ↑                          |
                |                          |
                ← ← ← ← ← ← ← ← ← ← ← ← ← ←
                     (back button bypasses intro screen)
```

When using `pushReplacement`, the intro screen is removed from the navigation stack. When the user presses back from the game screen, they return directly to the home screen, **bypassing** the return handler in `daily_quests_widget.dart` that calls `setState()` to refresh the UI.

**Navigation Flow (FIXED):**
```
Home → Quest Intro (push) → Quest Game (push)
                ↑                       |
                |← ← Intro ← ← ← ← ← ← ←
                |      ↑
                ← ← ← ←
      (setState triggered here)
```

With `push`, the intro screen remains in the stack, ensuring the return flow goes through: Game → Intro → Home, which properly triggers the `setState()` call.

### Why Classic/Affirmation Quizzes Worked But You or Me Didn't

Classic and Affirmation quizzes always used `Navigator.push()` throughout their navigation flow, so the return handler was always triggered. You or Me was the only quest type using `pushReplacement`, which broke the UI refresh mechanism.

### Solution

**File:** `app/lib/screens/you_or_me_intro_screen.dart`
**Line:** 96

**Change:**
```dart
// BEFORE (BROKEN)
Navigator.of(context).pushReplacement(
  MaterialPageRoute(
    builder: (context) => YouOrMeGameScreen(session: session),
  ),
);

// AFTER (FIXED)
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => YouOrMeGameScreen(session: session),
  ),
);
```

### Prevention

**Rule for Quest Screens:**
Always use `Navigator.push()` for quest navigation unless there is a specific, documented reason to use `pushReplacement`. The navigation stack must remain intact for the home screen's `setState()` callback to be triggered when returning from quest completion.

**Files to Check:**
- `daily_quests_widget.dart` - Contains the `setState()` callback at line ~360 that refreshes quest cards
- Quest intro screens (`*_intro_screen.dart`) - Should use `push`, not `pushReplacement`

### Testing Checklist

When adding new quest types:
- [ ] Complete the quest on one device
- [ ] Verify quest card updates to show "Waiting for partner" immediately upon returning to home screen
- [ ] Do NOT rely on app restart or manual refresh to see the update
- [ ] Check that navigation uses `push`, not `pushReplacement`

### Related Files

- `app/lib/screens/you_or_me_intro_screen.dart:96` - Fixed navigation call
- `app/lib/widgets/daily_quests_widget.dart:360` - setState() callback location
- `app/lib/widgets/quest_card.dart:328-368` - "Waiting for partner" badge logic

---

## Duplicate Love Points Award for You or Me Quest

**Date Discovered:** 2025-11-17
**Status:** ✅ FIXED
**Severity:** Medium (incorrect LP rewards, no data loss)

### Symptom

When both users complete "You or Me" quest, they each receive **60 LP** instead of the expected **30 LP**. This same bug previously affected Classic and Affirmation quizzes but was fixed for those quest types.

### Root Cause

The issue was caused by **duplicate LP awards** at two different layers:

1. **YouOrMeService._completeSession()** (line 424-430) awarded 30 LP when both users submitted answers
2. **DailyQuestService.completeQuestForUser()** (line 117-123) awarded another 30 LP when the quest was marked as completed by both users

**Why DailyQuestService awarded LP:**

DailyQuestService checks `if (quest.type != QuestType.quiz)` before awarding LP. Since "You or Me" uses `QuestType.youOrMe` (not `QuestType.quiz`), the condition was TRUE and LP was awarded.

**Result:** 30 LP + 30 LP = 60 LP (duplicate!)

### Why This Bug Kept Recurring

After unifying "You or Me" to use the same single-session architecture as Classic and Affirmation quizzes, the YouOrMeService still contained its own LP award logic from the old dual-session implementation. This created the duplicate award.

**Pattern:** Classic and Affirmation quizzes rely on DailyQuestService for LP awards. You or Me should follow the same pattern but didn't until now.

### Solution

**File:** `app/lib/services/you_or_me_service.dart`
**Line:** 416-440

**Change:** Removed LP award call from `_completeSession()` method

```dart
// BEFORE (BROKEN - awarded duplicate LP)
Future<void> _completeSession(YouOrMeSession session) async {
  Logger.info('Completing session: ${session.id}', service: 'you_or_me');

  const lpEarned = 30;

  // Award LP to both users (DUPLICATE!)
  await LovePointService.awardPointsToBothUsers(
    userId1: session.userId,
    userId2: session.partnerId,
    amount: lpEarned,
    reason: 'you_or_me_completion',
    relatedId: session.id,
  );

  session.lpEarned = lpEarned;
  session.status = 'completed';
  session.completedAt = DateTime.now();

  await session.save();
  await _syncSessionToRTDB(session);

  Logger.success('Session completed, 30 LP awarded to both users', service: 'you_or_me');
}

// AFTER (FIXED - LP awarded only by DailyQuestService)
/// Complete session when both users have submitted answers
///
/// NOTE: LP is awarded by DailyQuestService.completeQuestForUser(), not here.
/// This prevents duplicate LP awards (issue: You or Me was awarding 60 LP instead of 30).
Future<void> _completeSession(YouOrMeSession session) async {
  Logger.info('Completing session: ${session.id}', service: 'you_or_me');

  const lpEarned = 30; // Standard quest reward

  // DO NOT award LP here - DailyQuestService handles it
  // (This prevents duplicate LP awards: 30 + 30 = 60 bug)
  // LP is awarded via DailyQuestService.completeQuestForUser() when quest is marked completed

  session.lpEarned = lpEarned;
  session.status = 'completed';
  session.completedAt = DateTime.now();

  await session.save();
  await _syncSessionToRTDB(session);

  Logger.success('Session completed (LP awarded via DailyQuestService)', service: 'you_or_me');
}
```

### Prevention

**Rule for Quest Services:**

All quest types should follow the **centralized LP award pattern** implemented in `DailyQuestService.completeQuestForUser()`. Individual quest services (QuizService, YouOrMeService, etc.) should NOT award LP directly.

**LP Award Flow:**
1. User completes content (quiz, game, etc.)
2. Quest service marks quest as completed via `DailyQuestService.completeQuestForUser()`
3. **DailyQuestService** awards LP when both users have completed (line 117-123)
4. Quest service tracks `session.lpEarned` for display purposes only (not for actual awarding)

**Exception:** Quiz-type quests (`QuestType.quiz`) are excluded from DailyQuestService LP awards and handle LP in QuizService instead.

**Files to Check When Adding New Quest Types:**
- `app/lib/services/daily_quest_service.dart:111` - Check if quest type needs LP award exclusion
- New quest service file - Do NOT call `LovePointService.awardPointsToBothUsers()` directly
- `app/lib/models/daily_quest.dart` - Verify quest type enum value

### Testing Checklist

When adding new quest types or modifying quest completion:
- [ ] Complete quest with both users
- [ ] Check LP awarded = exactly 30 LP per user (not 60)
- [ ] Verify LP award appears in debug logs only ONCE
- [ ] Check both users' LP balances match expected total
- [ ] Ensure `LovePointService.awardPointsToBothUsers()` is called only from DailyQuestService
- [ ] Search quest service code for any direct LP award calls

### Related Files

- `app/lib/services/you_or_me_service.dart:416-440` - Fixed _completeSession() method
- `app/lib/services/daily_quest_service.dart:111-130` - Centralized LP award logic
- `app/lib/services/love_point_service.dart:224-275` - awardPointsToBothUsers() implementation
- `app/lib/models/daily_quest.dart` - QuestType enum definitions

---

## Duplicate Love Points from Multiple Firebase Listeners

**Date Discovered:** 2025-11-17
**Status:** ✅ FIXED
**Severity:** Medium (incorrect LP rewards, no data loss)

### Symptom

When implementing real-time LP counter updates, users received **60 LP** instead of **30 LP** when completing quests.

### Root Cause

The issue was caused by **duplicate Firebase listeners** in `LovePointService`:

1. **main.dart** (line 133) calls `startListeningForLPAwards()` → Creates Listener #1
2. **new_home_screen.dart** also called `startListeningForLPAwards()` → Creates Listener #2
3. When LP is awarded → **Both listeners fire**
4. Both call `_handleLPAward()` → Both call `awardPoints()`
5. Result: 30 LP + 30 LP = **60 LP (duplicate!)**

This is the same pattern as the "You or Me" duplicate LP bug, but at the Firebase listener layer instead of the service layer.

### Solution

**File:** `app/lib/services/love_point_service.dart`
**Lines:** 194-199

**Change:** Created separate `setLPChangeCallback()` method for registering UI callbacks without creating new listeners

```dart
// NEW METHOD (CORRECT)
/// Register callback for LP changes (for real-time UI updates)
/// Use this in screens that need to update when LP changes
/// DO NOT call startListeningForLPAwards() again - that creates duplicate listeners!
static void setLPChangeCallback(VoidCallback? callback) {
  _onLPChanged = callback;
}
```

**File:** `app/lib/screens/new_home_screen.dart`
**Lines:** 60-70

```dart
// BEFORE (BROKEN - created duplicate listener)
LovePointService.startListeningForLPAwards(
  currentUserId: user.id,
  partnerUserId: partner.pushToken,
  onLPChanged: () { setState(() {}); },
);

// AFTER (FIXED - just registers callback)
LovePointService.setLPChangeCallback(() {
  if (mounted) {
    setState(() {});
  }
});
```

### Prevention

**Rule for Firebase Listeners:**

Only call `startListeningForLPAwards()` **ONCE** in `main.dart`. Individual screens should use `setLPChangeCallback()` to register UI update callbacks.

**Pattern:**
1. `main.dart` creates the Firebase listener (singleton pattern)
2. Screens register callbacks via `setLPChangeCallback()`
3. Listener invokes callbacks when LP changes
4. No duplicate listeners = no duplicate LP awards

**Files to Check:**
- `app/lib/main.dart:133` - Single listener initialization
- Screen files - Should use `setLPChangeCallback()`, NOT `startListeningForLPAwards()`

### Testing Checklist

When implementing real-time updates for any Firebase listener:
- [ ] Listener is created only ONCE (in main.dart or service initialization)
- [ ] Screens use callback registration methods (not duplicate listeners)
- [ ] Complete quest with both users
- [ ] Check LP awarded = exactly 30 LP per user (not 60, not 90)
- [ ] Search codebase for multiple calls to listener initialization methods

### Related Files

- `app/lib/services/love_point_service.dart:194-199` - setLPChangeCallback() method
- `app/lib/services/love_point_service.dart:239-265` - startListeningForLPAwards() (singleton)
- `app/lib/main.dart:133-136` - Single listener initialization
- `app/lib/screens/new_home_screen.dart:60-70` - Correct callback registration pattern

---

## Memory Flip Cross-Device Sync Not Working

**Date Discovered:** 2025-11-17
**Date Fixed:** 2025-11-18
**Status:** ✅ FIXED
**Severity:** High (core feature broken, poor UX)

### Symptom

When Alice plays Memory Flip and matches cards, Bob opens Memory Flip but sees a completely different puzzle with different card layouts and no matched pairs visible. Each device generates and plays its own independent game instead of sharing the same puzzle.

### Context: Why Sync Issues Are Challenging in This Codebase

Cross-device synchronization has been a recurring challenge in this project. Multiple features have required extensive debugging before sync worked correctly:

- **Daily Quests:** Took multiple attempts to ensure both devices see the same quests with matching IDs
- **Quiz Progression:** Required careful Firebase RTDB path structure and security rules
- **Love Points:** Multiple bugs with duplicate awards and listener management
- **You or Me Results:** Sync timing issues between partners submitting answers

**Common patterns of failure:**
1. Missing or incorrect Firebase security rules (permission denied errors)
2. Race conditions (both devices generating instead of one generating, one loading)
3. Timing issues (second device loads before first device finishes saving)
4. ID mismatches (devices using different IDs for "same" content)
5. Silent failures (code doesn't crash but sync doesn't happen)

### What We've Tried (November 17, 2025)

#### Attempt 1: Created Comprehensive Spec Document
**What:** Created `docs/MEMORY_FLIP_SYNC_FIX.md` with 15-task breakdown, Firebase RTDB schema design, and comparison with working Daily Quests pattern
**Why:** To understand the problem thoroughly and plan implementation systematically
**Result:** ✅ Good documentation, helped plan the fix
**Why it didn't solve sync:** Documentation doesn't fix code, just guides implementation

#### Attempt 2: Fixed Performance Issue
**What:** Removed `await` from `syncMatch()` and `sendMatchNotification()` calls in memory_flip_game_screen.dart:159-177
**Why:** 5-second delay when finding matches suggested blocking network calls
**Result:** ✅ Match popup now appears in <1 second (down from 5 seconds)
**Why it didn't solve sync:** This fixed UI responsiveness, not cross-device synchronization

#### Attempt 3: Added Firebase RTDB Security Rules
**What:** Added `/memory_puzzles/{coupleId}` path rules to database.rules.json:57-66
**Why:** Permission denied errors indicated missing security rules
**Result:** ❌ Rules added but not deployed initially
**Why it didn't solve sync:** Rules existed in file but weren't active in Firebase until deployed

#### Attempt 4: Deployed Firebase Security Rules
**What:** Ran `firebase deploy --only database` to activate the new rules
**Why:** Rules in database.rules.json must be deployed to take effect
**Result:** ✅ Rules deployed successfully
**Why it didn't solve sync:** Fixed permission errors, but core sync logic still missing

#### Attempt 5: Created MemoryFlipSyncService
**What:** Created new service (320 lines) following QuestSyncService pattern with:
- `syncPuzzle()` - Load from Firebase or generate
- `savePuzzleToFirebase()` - Save generated puzzle
- `syncMatchToFirebase()` - Update when cards matched
- `loadPuzzleFromFirebase()` - Retrieve puzzle
- Device priority logic (2-second wait for second device)
- Full JSON serialization for MemoryPuzzle and MemoryCard

**Why:** Memory Flip was storing data only in local Hive, needed Firebase RTDB sync like Daily Quests
**Result:** ✅ Service created with complete implementation
**Why it didn't solve sync:** Service exists but integration may be incomplete or logic has bugs

#### Attempt 6: Integrated Sync Service into MemoryFlipService
**What:** Modified MemoryFlipService.getCurrentPuzzle() to:
- Check Firebase first for existing puzzle
- Generate only if Firebase is empty
- Save to Firebase for partner to load
- Use date-based puzzle IDs (`puzzle_YYYY-MM-DD`)

**Why:** Core service needed to call sync methods to enable cross-device sync
**Result:** ✅ Integration code added
**Why it didn't solve sync:** Unknown - may have logic bugs, timing issues, or silent failures

#### Attempt 7: Fixed Build Error
**What:** Changed `partner.userId` to `partner.pushToken` at memory_flip_service.dart:125
**Why:** Build failed because Partner model only has `pushToken`, not `userId`
**Result:** ✅ Build succeeded
**Why it didn't solve sync:** Fixed compilation, not synchronization logic

#### Attempt 8: Added Debug Mode Visual Indicators
**What:** Added `_debugShowAllCards = true` flag and visual indicators for matched cards:
- Light green background
- Green border
- White checkmark badge in top-right corner

**Why:** Needed to see all cards during testing to verify sync without finding matches
**Result:** ✅ Visual indicators working
**Why it didn't solve sync:** UI enhancement for testing, doesn't fix sync

#### Attempt 9: Complete Clean Testing Procedure
**What:**
1. Killed all Flutter processes
2. Uninstalled Android app (fresh Hive storage)
3. Cleared Firebase RTDB data
4. Built fresh APK and Web builds
5. Launched Alice (Android) then Bob (Chrome)

**Why:** Eliminate stale data that might interfere with testing
**Result:** ✅ Clean environment achieved
**Why it didn't solve sync:** Alice and Bob still see different puzzles (core sync logic still broken)

#### Attempt 10: Fix Couple ID Generation (Partial Success)
**What:** Changed Memory Flip to use `user.id` instead of `user.pushToken` for couple ID generation
- `memory_flip_service.dart:140` - `_getCoupleId(user.id, partner.pushToken)` (was `user.pushToken`)
- `memory_flip_service.dart:262` - `_getCoupleId(user.id, partner.pushToken)` (was `user.pushToken`)
- `memory_flip_sync_service.dart:43` - `final tokens = [user.id, partner.pushToken]` (was `user.pushToken`)

**Why:** Quest system uses `QuestUtilities.generateCoupleId(user.id, partner.pushToken)` and works correctly. Memory Flip was using `user.pushToken + partner.pushToken` which generates different couple IDs on each device:
- Alice's device: `user.pushToken` = `"web_token_1763398570609"` (Chrome FCM token)
- Bob's device: `user.pushToken` = `"cojE5uuTRuq1XD_XMFW9-Z:APA91b..."` (Android FCM token)
- These are DIFFERENT on each device, causing different couple IDs

**Result:** ⚠️ **Partially worked** - Both devices now generate the SAME couple ID:
- Before: Alice writes to `alice_fcm_token_bob_user_id`, Bob writes to `bob_fcm_token_alice_user_id` ❌
- After: Both write to `alice-dev-user-00000000-0000-0000-0000-000000000001_bob-dev-user-00000000-0000-0000-0000-000000000002` ✅

**Why it didn't fully solve sync:**
Checking Firebase revealed TWO different puzzles under the SAME couple ID:
```json
{
  "alice-dev-user-..._bob-dev-user-...": {
    "fab12448-098c-4f1c-a5cd-6dee210f7a69": { ... },  // Alice's puzzle (random UUID)
    "d287f99e-db98-400b-8151-8f7a19ef8d7d": { ... }   // Bob's puzzle (different random UUID)
  }
}
```

**Root cause discovered:** Alice generates puzzle with random UUID (`const Uuid().v4()`), but Bob looks for date-based puzzle ID (`puzzle_2025-11-18`). Even with matching couple IDs, they create different puzzles because puzzle IDs don't match.

#### Attempt 11: Fix Puzzle ID Generation (Final Solution) ✅
**What:** Changed `generateDailyPuzzle()` to use date-based puzzle ID consistently
- `memory_flip_service.dart:37-39` - Made `puzzleId` an optional parameter: `Future<MemoryPuzzle> generateDailyPuzzle({String? puzzleId})`
- `memory_flip_service.dart:138` - Pass date-based ID when generating: `puzzle = await generateDailyPuzzle(puzzleId: puzzleId);`

**Why:** The couple ID fix revealed the second bug - Alice was generating a puzzle with a random UUID but the sync service expected a date-based ID:
- Line 118: `final puzzleId = 'puzzle_$dateKey';` (creates `puzzle_2025-11-18`)
- Line 137: `puzzle = await generateDailyPuzzle();` (generates random UUID like `fab12448-...`)
- Line 141: `await _syncService.savePuzzleToFirebase(puzzle, ...)` (saves random UUID to Firebase)
- Result: Bob looks for `puzzle_2025-11-18` but finds nothing, generates his own with different random UUID

**Result:** ✅ **FULLY WORKING** - Both devices now:
1. Generate/look for the SAME couple ID: `alice-dev-user-..._bob-dev-user-...`
2. Generate/look for the SAME puzzle ID: `puzzle_2025-11-18`
3. Share the exact same puzzle state in Firebase

**Verification:**
- Alice opens Memory Flip → Generates `puzzle_2025-11-18` under correct couple ID
- Bob opens Memory Flip → Loads `puzzle_2025-11-18` from Firebase (same couple ID)
- Alice matches cards → Bob sees matched cards immediately
- Firebase shows ONE puzzle under ONE couple ID ✅

### Final Solution (Two-Part Fix)

#### Part 1: Couple ID Generation
**Problem:** Memory Flip used `user.pushToken` (FCM token, different on each device) instead of `user.id` (deterministic user ID)
**Solution:** Match the quest system pattern - use `user.id + partner.pushToken`

```dart
// BEFORE (BROKEN) - memory_flip_service.dart:140, 262
final coupleId = _getCoupleId(user.pushToken, partner.pushToken);
// Generates: "web_token_1763398570609_bob-dev-user-..." on Alice
//            "cojE5uuTRuq1XD_XMFW9-Z:APA91b..._alice-dev-user-..." on Bob
// Result: DIFFERENT couple IDs ❌

// AFTER (FIXED)
final coupleId = _getCoupleId(user.id, partner.pushToken);
// Generates: "alice-dev-user-00000000-0000-0000-0000-000000000001_bob-dev-user-00000000-0000-0000-0000-000000000002"
// Result: SAME couple ID on both devices ✅
```

#### Part 2: Puzzle ID Generation
**Problem:** Even with matching couple IDs, Alice generated puzzle with random UUID while Bob looked for date-based ID
**Solution:** Pass date-based puzzle ID to `generateDailyPuzzle()` method

```dart
// BEFORE (BROKEN) - memory_flip_service.dart:37-38
Future<MemoryPuzzle> generateDailyPuzzle() async {
  final puzzleId = const Uuid().v4(); // Random: "fab12448-098c-4f1c-a5cd-6dee210f7a69"
}

// AFTER (FIXED)
Future<MemoryPuzzle> generateDailyPuzzle({String? puzzleId}) async {
  puzzleId ??= const Uuid().v4(); // Use provided ID or generate if needed
}

// Caller passes date-based ID - memory_flip_service.dart:138
puzzle = await generateDailyPuzzle(puzzleId: puzzleId); // "puzzle_2025-11-18"
```

### Why This Pattern Failed Initially

This demonstrates a **cascade dependency bug** - fixing one bug revealed another:

1. **Initial symptom:** Different puzzles on each device
2. **First investigation:** Assumed sync service logic was broken
3. **9 attempts:** Added security rules, created sync service, fixed performance, cleaned test environment
4. **Couple ID fix:** Both devices now write to same Firebase path → progress!
5. **Surprise discovery:** Firebase had TWO puzzles under ONE couple ID → revealed second bug
6. **Puzzle ID fix:** Both devices now use same puzzle ID → fully working!

**Key lesson:** The puzzle ID bug was HIDDEN behind the couple ID bug. You can't see puzzle ID mismatches until couple IDs match. This is why direct Firebase inspection (`firebase database:get`) after each change is critical - it reveals data structure issues that logs don't show.

### Prevention Checklist for Future Sync Features

Use this checklist when implementing ANY cross-device sync feature:

**Before Writing Code:**
- [ ] Study existing working sync pattern (Daily Quests, Quest system)
- [ ] Design Firebase RTDB path structure on paper first
- [ ] Identify all places where couple ID / content ID is generated
- [ ] Verify ID generation is **deterministic** (same on both devices)

**Couple ID Generation:**
- [ ] Use `user.id` (NOT `user.pushToken`) for current user
- [ ] Use `partner.pushToken` (which stores partner's user ID) for partner
- [ ] Sort IDs alphabetically: `[userId1, userId2]..sort()`
- [ ] Generate: `'${sorted[0]}_${sorted[1]}'`
- [ ] **Test:** Print couple ID on both devices - must be identical

**Content ID Generation (Puzzles, Sessions, etc):**
- [ ] Use date-based IDs for daily content: `'content_YYYY-MM-DD'`
- [ ] Never use random UUIDs for shared content (different on each device)
- [ ] If using UUID, first device generates and second device loads (not both generate)
- [ ] **Test:** Print content ID on both devices - must be identical

**During Development:**
- [ ] Enable logging for the service: `lib/utils/logger.dart`
- [ ] Add debug logs at every Firebase operation (save/load/update)
- [ ] Test with clean environment: `/runtogether` command

**Testing Procedure:**
- [ ] Run `/runtogether` to clear all storage and Firebase
- [ ] Launch Alice (first device) - should generate content
- [ ] Launch Bob (second device) - should load Alice's content
- [ ] Check Firebase directly: `firebase database:get /path`
  - Should see ONE entry
  - Under ONE couple ID
  - With ONE content ID
- [ ] Alice makes change → Bob should see change immediately
- [ ] Bob makes change → Alice should see change immediately

**Common Pitfalls:**
- ❌ Using `user.pushToken` instead of `user.id` for couple ID
- ❌ Both devices generating content instead of one generating, one loading
- ❌ Random UUIDs for shared content (different on each device)
- ❌ Forgetting to sort user IDs (generates different couple IDs on each device)
- ❌ Not checking Firebase directly (assumptions hide bugs)

### Related Files

- `docs/MEMORY_FLIP_SYNC_FIX.md` - Comprehensive implementation spec
- `app/lib/services/memory_flip_service.dart:37-39, 138, 140, 262` - Couple ID and puzzle ID fixes
- `app/lib/services/memory_flip_sync_service.dart:43` - Couple ID generation
- `app/lib/services/quest_utilities.dart:28-39` - Reference pattern for couple ID generation
- `app/lib/screens/memory_flip_game_screen.dart` - UI with performance fixes
- `database.rules.json:57-66` - Firebase security rules for /memory_puzzles
- `app/lib/utils/logger.dart:59` - Logging configuration (memory_flip enabled for debugging)

### Pattern Recognition: Similar Issues

This follows the same pattern as previous sync bugs:
- Daily Quests sync (fixed after multiple iterations)
- Quiz progression sync (required careful RTDB path design)
- Love Points duplicate awards (duplicate listeners issue)

**Common solution pattern:** Extensive logging → Inspect Firebase directly → Find ID mismatch → Fix generation logic → Test thoroughly

**New insight from this bug:** Sometimes fixing one bug reveals another (cascade dependency bugs). Always check Firebase directly after each fix to see the actual data structure, not just logs.

---

## Prevention Guide: HealthKit Step Sync Feature

**Date Added:** 2025-11-18
**Status:** 📋 PLANNING (Not yet implemented)
**Feature Type:** Cross-Device Sync (High Risk)

### Feature Overview

**Planned functionality:**
- Alice walks 5,000 steps (tracked via Apple HealthKit)
- Bob walks 7,000 steps (tracked via Apple HealthKit)
- Combined: 12,000 steps toward shared daily goal
- Shared goal: 20,000 steps/day → Award 30 LP to both users
- Real-time updates: Each partner sees other's step count and progress toward goal

**Why this document exists:**

This project has repeatedly struggled with cross-device sync features. Memory Flip required 11 attempts to work correctly. Daily Quests, Love Points, and Quiz Progression all had similar multi-attempt debugging cycles. This chapter documents the common pitfalls and patterns to follow BEFORE implementing HealthKit step sync to avoid the same mistakes.

### Common Sync Pitfalls (Lessons from Memory Flip & Other Features)

Based on our experience with Memory Flip, Daily Quests, Love Points, and Quiz Progression, these are the recurring issues:

#### 1. ID Determinism Issues

**The Problem:**
- Using `user.pushToken` (FCM token) instead of `user.id` for couple IDs
- Using random UUIDs for daily content instead of date-based IDs
- IDs generated differently on each device → devices write to different Firebase paths

**Memory Flip Example:**
```
Alice's couple ID: "web_token_1763398570609_bob-dev-user-..."
Bob's couple ID:   "cojE5uuTRuq1XD_XMFW9-Z:APA91b..._alice-dev-user-..."
Result: TWO different puzzles in Firebase ❌
```

**How This Affects Step Sync:**
- Couple ID must be deterministic: `user.id + partner.pushToken`, sorted
- Daily step goal ID must be date-based: `step_goal_YYYY-MM-DD`
- Never use random UUIDs for daily goals

#### 2. Duplicate Data vs. Aggregated Data

**The Problem:**
- Multiple devices writing the same data creates duplicates
- No clear "single source of truth" for who writes what
- Race conditions when both devices try to update simultaneously

**Love Points Example:**
- Multiple Firebase listeners created duplicate LP awards
- Result: 60 LP instead of 30 LP

**How This Affects Step Sync:**
- Alice's steps: Only Alice's device should write to `/steps/{coupleId}/{date}/alice`
- Bob's steps: Only Bob's device should write to `/steps/{coupleId}/{date}/bob`
- Combined total: DERIVED from individual counts (not stored separately)
- Goal completion: ONE device detects and awards LP (prevent duplicate 30 LP awards)

#### 3. Cascade Dependency Bugs

**The Problem:**
- Fixing one bug reveals another hidden bug
- Can't see second bug until first bug is fixed
- Leads to frustration: "We fixed couple ID but it still doesn't work!"

**Memory Flip Example:**
1. Fixed couple ID bug → Both devices now write to same path ✅
2. Firebase inspection revealed TWO puzzles under ONE couple ID ❌
3. Discovered puzzle ID bug was hidden behind couple ID bug
4. Fixed puzzle ID bug → Finally working ✅

**How This Affects Step Sync:**
- Fix issues one at a time
- Check Firebase directly after each fix: `firebase database:get /steps`
- Expect multiple rounds of debugging
- Don't assume first fix will be the only fix

#### 4. Silent Failures

**The Problem:**
- Code doesn't crash but sync doesn't happen
- Missing Firebase security rules → permission denied (silently caught)
- Network errors swallowed by try/catch blocks
- Logs say "success" but data isn't in Firebase

**Quest System Example:**
- Quiz progression sync failed silently for weeks
- Firebase security rules missing → permission denied
- Error caught and logged but sync appeared to work

**How This Affects Step Sync:**
- Add Firebase security rules FIRST: `/steps/{coupleId}/`
- Deploy rules BEFORE testing: `firebase deploy --only database`
- Enable verbose logging: `lib/utils/logger.dart` → `'step_sync': true`
- Check Firebase directly, don't trust logs alone

#### 5. Timing and Race Conditions

**The Problem:**
- First device generates content, second device loads too early
- Second device doesn't find content, generates its own
- Result: Duplicate content under same couple ID

**Memory Flip Example:**
- Second device waited 2 seconds, but sometimes not enough
- If first device is slow, second device generates duplicate puzzle

**How This Affects Step Sync:**
- Individual step counts don't have this issue (each device writes its own)
- Goal completion detection IS vulnerable:
  - Alice hits 20k combined → Awards 30 LP
  - Bob's device delayed, doesn't see Alice's award yet
  - Bob hits 20k combined → Awards another 30 LP
  - Result: 60 LP instead of 30 LP ❌

### Architectural Patterns to Follow

Based on working implementations (Daily Quests, Quest System, Love Points after fixes):

#### Pattern 1: Deterministic ID Generation

```
Couple ID:
1. Use user.id (NOT user.pushToken)
2. Use partner.pushToken (which stores partner's user ID)
3. Sort alphabetically: [user.id, partner.pushToken].sort()
4. Generate: '${sorted[0]}_${sorted[1]}'

Daily Content ID:
1. Use date-based IDs: 'step_goal_YYYY-MM-DD'
2. NEVER use random UUIDs for shared content
```

#### Pattern 2: Partitioned Writes (No Conflicts)

```
Firebase RTDB Structure:
/steps/{coupleId}/{dateKey}/
  alice_steps: 5000          ← Only Alice's device writes
  bob_steps: 7000            ← Only Bob's device writes
  goal_target: 20000
  goal_completed: false
  goal_completed_by: null
  lp_awarded: false
```

Each device writes to its own partition → No write conflicts

#### Pattern 3: Idempotent Goal Completion

```
Goal Completion Logic:
1. Both devices watch /steps/{coupleId}/{dateKey}
2. When combined steps >= 20000:
   - Check if lp_awarded == false
   - Use Firebase transaction (atomic check-and-set)
   - Set lp_awarded = true
   - Award LP only if transaction succeeds
3. Transaction prevents duplicate awards
```

#### Pattern 4: Firebase-First Testing

```
Testing Procedure:
1. Run /runtogether (clean environment)
2. Alice walks 5k steps → Check Firebase: Should see alice_steps = 5000
3. Bob walks 7k steps → Check Firebase: Should see bob_steps = 7000
4. Verify combined total shown on both devices
5. Alice walks to 13k (total 20k) → Check Firebase: lp_awarded = true
6. Verify LP awarded exactly once
7. Bob's device should NOT award LP again
```

#### Pattern 5: Single Listener Per Service

```
Initialization:
1. main.dart creates ONE Firebase listener for /steps/{coupleId}/{dateKey}
2. Listener updates local Hive storage when steps change
3. Screens use setStepChangeCallback() to register UI updates
4. NEVER create duplicate listeners (causes duplicate LP awards)
```

### Specific Concerns for Step Sync

#### Concern 1: HealthKit Data Freshness

**Issue:** HealthKit step counts may update with delay
- Steps added retroactively (e.g., manual entry, delayed sync)
- Steps removed (e.g., corrections)

**Pattern:**
- Poll HealthKit periodically (e.g., every 15 minutes when app is active)
- Update Firebase with latest count
- Handle step count DECREASING (corrections)
- Don't award LP if goal was already completed

#### Concern 2: Goal Completion Detection

**Issue:** Both devices independently detect goal completion
- Risk of duplicate LP awards
- Risk of duplicate notifications

**Pattern:**
- Use Firebase transaction for atomic check-and-set
- Only award LP if transaction succeeds (lp_awarded: false → true)
- If transaction fails, another device already awarded → Don't award again

#### Concern 3: Daily Reset Timing

**Issue:** Devices may have different timezones or reset times
- Alice at 23:59 → 20k steps
- Bob at 00:01 (next day) → New goal started
- Do they get credit for Alice's steps?

**Pattern:**
- Use UTC date for daily goal IDs: `step_goal_2025-11-18`
- Both devices convert to UTC before generating ID
- Reset happens at same absolute time worldwide
- Document timezone behavior clearly

#### Concern 4: Offline Sync

**Issue:** User walks steps while offline, syncs later
- Alice walks 15k steps offline
- Comes online, syncs → Combined total suddenly jumps to 20k
- Goal completed retroactively

**Pattern:**
- Firebase transaction handles this correctly
- First device to see 20k+ triggers LP award
- Second device sees lp_awarded = true, doesn't award again
- Show notification: "You reached your goal while you were away!"

#### Concern 5: Data Visibility and Privacy

**Issue:** Each partner can see other's step count
- What if one partner walks very little?
- What if one partner wants privacy?

**Pattern (Not Technical):**
- Design UI to emphasize COMBINED progress, not individual comparison
- Show "12k / 20k steps together" not "Alice: 5k, Bob: 7k"
- Consider privacy settings (show combined only vs. individual)

### Prevention Checklist for HealthKit Step Sync

Use this checklist during implementation:

**Before Writing Code:**
- [ ] Design Firebase RTDB path structure: `/steps/{coupleId}/{dateKey}/`
- [ ] Identify couple ID generation: `user.id + partner.pushToken`, sorted
- [ ] Identify daily goal ID generation: `step_goal_YYYY-MM-DD` (UTC)
- [ ] Confirm each device writes to its own partition (no conflicts)
- [ ] Plan goal completion detection with Firebase transaction

**Couple ID Generation:**
- [ ] Use `user.id` (NOT `user.pushToken`)
- [ ] Use `partner.pushToken` (stores partner's user ID)
- [ ] Sort IDs: `[user.id, partner.pushToken].sort()`
- [ ] Test: Print couple ID on both devices → Must be identical

**Daily Goal ID Generation:**
- [ ] Use UTC date: `DateTime.now().toUtc().toIso8601String().substring(0, 10)`
- [ ] Format: `step_goal_YYYY-MM-DD`
- [ ] Test: Print goal ID on both devices → Must be identical
- [ ] Test across timezone boundaries (Alice in PST, Bob in EST)

**Firebase Security Rules:**
- [ ] Add `/steps/{coupleId}` path to `database.rules.json`
- [ ] Deploy rules: `firebase deploy --only database`
- [ ] Test: Verify writes succeed (no permission denied errors)

**Goal Completion Logic:**
- [ ] Use Firebase transaction for `lp_awarded` flag
- [ ] Award LP only if transaction succeeds (false → true)
- [ ] Handle transaction failure gracefully (another device awarded)
- [ ] Test: Complete goal on both devices simultaneously → Exactly 30 LP awarded (not 60)

**Testing Procedure:**
- [ ] Run `/runtogether` to clean environment
- [ ] Launch Alice and Bob with clean storage
- [ ] Alice logs steps → Check Firebase: `alice_steps` present
- [ ] Bob logs steps → Check Firebase: `bob_steps` present
- [ ] Verify combined total calculated correctly on both devices
- [ ] Alice reaches goal → Check Firebase: `lp_awarded = true`
- [ ] Bob's device should NOT award LP again
- [ ] Check LP balance: Exactly 30 LP per user (not 60)

**Logging and Debugging:**
- [ ] Enable logging: `lib/utils/logger.dart` → `'step_sync': true`
- [ ] Add debug logs for every Firebase operation
- [ ] Add debug logs for goal completion detection
- [ ] Add debug logs for LP award transaction
- [ ] Test with logs enabled first, disable after verification

**Common Pitfalls to Avoid:**
- ❌ Using `user.pushToken` for couple ID
- ❌ Using random UUIDs for daily goals
- ❌ Both devices writing combined total (race condition)
- ❌ Not using Firebase transaction for goal completion
- ❌ Creating duplicate Firebase listeners
- ❌ Awarding LP without checking `lp_awarded` flag
- ❌ Not testing with clean environment (`/runtogether`)
- ❌ Not checking Firebase directly after each operation

### Key Takeaway

**The pattern that works:**
1. Deterministic IDs (same on both devices)
2. Partitioned writes (each device owns its data)
3. Atomic operations (Firebase transactions)
4. Single listener (no duplicates)
5. Test with Firebase inspection (don't trust logs alone)

**The pattern that fails:**
1. Variable IDs (different on each device)
2. Shared writes (race conditions)
3. Non-atomic operations (duplicate awards)
4. Multiple listeners (duplicate processing)
5. Test with logs only (silent failures hidden)

Follow the working pattern. Avoid the failing pattern. Check Firebase directly after every change.

### Related Documentation

- This document (Known Issues) - All previous sync bugs and lessons learned
- `docs/QUEST_SYSTEM_V2.md` - Reference implementation of working sync (Daily Quests)
- `docs/ARCHITECTURE.md` - Firebase RTDB patterns and couple ID generation
- `app/lib/services/quest_utilities.dart:28-39` - Correct couple ID generation code
- `app/lib/services/love_point_service.dart` - Firebase listener patterns (after fixes)

---

## Template for New Issues

```markdown
## [Issue Title]

**Date Discovered:** YYYY-MM-DD
**Status:** 🐛 OPEN / 🔍 INVESTIGATING / ✅ FIXED
**Severity:** Low / Medium / High / Critical

### Symptom
[What the user experiences]

### Root Cause
[Technical explanation of why it happens]

### Solution
[How it was fixed, with code examples]

### Prevention
[Rules or practices to avoid this in the future]

### Testing Checklist
- [ ] Step 1
- [ ] Step 2

### Related Files
- `path/to/file.dart:line` - Description
```

---

**Last Updated:** 2025-11-17 (Added Memory Flip cross-device sync investigation)

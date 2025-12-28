# Polling System Implementation Plan

**Status:** Phase 1 Complete, Phase 2 Partially Complete
**Started:** 2025-12-19
**Last Updated:** 2025-12-19
**Completed:** Phase 1 (all 4 tasks), Task 2.1 (partial - removed handleCompletion duplicates only)

---

## Phase 1: Critical Bug Fixes

### Task 1.1: Fix LP Callback Memory Leak
**Priority:** Critical
**Effort:** 5 minutes
**File:** `lib/screens/home_screen.dart`

**Problem:**
LP callback is set in line 210 but never cleared in dispose(). This causes a memory leak that accumulates every time the user switches tabs.

**Implementation:**
1. Add `LovePointService.clearLPChangeCallback()` to dispose()
2. Verify LovePointService has a clear method (add if missing)

**Tests:**
- [ ] Switch between tabs 10 times, verify memory doesn't grow
- [ ] LP updates still show after returning to home
- [ ] No callback errors in logs after leaving home screen

---

### Task 1.2: Protect UnifiedGameService Callback
**Priority:** Critical
**Effort:** 1 hour
**File:** `lib/services/unified_game_service.dart`

**Problem:**
Single `_onStateUpdate` callback can be cleared by any `stopPolling()` call, breaking waiting screen updates.

**Implementation:**
1. Change `Function? _onStateUpdate` to `Map<String, Function> _matchCallbacks`
2. Update `startPolling()` to store callback by matchId
3. Update `stopPolling()` to remove only the specific matchId's callback
4. Update `_pollOnce()` to use callback from map

**Tests:**
- [ ] Start quiz, go to waiting screen, verify polling works
- [ ] While on waiting screen, simulate game screen dispose - updates continue
- [ ] Multiple matches can have separate callbacks
- [ ] stopPolling with wrong matchId doesn't affect other callbacks

---

### Task 1.3: Replace print() with Logger
**Priority:** Medium
**Effort:** 30 minutes
**Files:**
- `lib/services/unified_game_service.dart` (10 statements)
- `lib/screens/quiz_match_waiting_screen.dart` (5 statements)
- `lib/screens/you_or_me_match_waiting_screen.dart` (4 statements)

**Implementation:**
1. Replace all `print()` calls with `Logger.debug()` or `Logger.info()`
2. Use appropriate service tags: 'quiz', 'you_or_me', 'polling'
3. Remove debug print statements added for investigation

**Tests:**
- [ ] No print() output in release build
- [ ] Debug logs visible when service verbosity enabled
- [ ] All game flows still work correctly

---

### Task 1.4: Unify Polling Intervals
**Priority:** Low
**Effort:** 15 minutes
**Files:**
- `lib/services/you_or_me_match_service.dart` (change 10s → 5s)
- `lib/mixins/game_polling_mixin.dart` (change 10s → 5s default)

**Implementation:**
1. Change default intervals to 5 seconds
2. Document interval choices in code comments

**Tests:**
- [ ] You or Me waiting screen polls every 5s
- [ ] Linked/Word Search game screens poll every 5s
- [ ] Partner completion detected within 10 seconds

---

## Phase 2: Consolidate Pending Results Flag

### Task 2.1: Remove Duplicate Flag Setting from Waiting Screens
**Priority:** High
**Effort:** 30 minutes
**Status:** PARTIAL - handleCompletion removed, initState KEPT as safety net
**Files:**
- `lib/screens/quiz_match_waiting_screen.dart`
- `lib/screens/you_or_me_match_waiting_screen.dart`

**Implementation:**
1. ✅ Remove `setPendingResultsMatchId` calls from handleCompletion (redundant - about to navigate to results)
2. ⚠️ KEEP `setPendingResultsMatchId` in initState UNTIL Task 2.2 is complete
3. HomePollingService auto-detection serves as backup (already implemented)

**IMPORTANT:** Do NOT remove initState flag setting until Task 2.2 (set flag in game screen) is implemented. Otherwise there's a race condition where user leaves waiting screen before HomePollingService detects partner completion.

**Tests:**
- [x] Complete quiz as second player, "RESULTS ARE READY!" shows for first player
- [x] Complete You or Me as second player, badge shows correctly
- [ ] Kill app on waiting screen, reopen - badge still correct
- [x] Removed handleCompletion duplicate (verified)

---

### Task 2.2: Set Flag in Game Screen on First Answer
**Priority:** High
**Effort:** 45 minutes
**Files:**
- `lib/screens/quiz_match_game_screen.dart`
- `lib/screens/you_or_me_match_game_screen.dart`

**Implementation:**
1. Add `_pendingFlagSet` boolean field
2. After first answer submitted successfully, set pending flag
3. Use matchId from game state

**Tests:**
- [ ] Answer first question, verify flag is set in Hive
- [ ] Complete game without waiting screen, flag still set
- [ ] Partner completes, "RESULTS ARE READY!" shows
- [ ] Flag not set multiple times (check logs)

---

### Task 2.3: Ensure Single Clear Location
**Priority:** Medium
**Effort:** 15 minutes
**Files:**
- `lib/screens/quiz_match_results_screen.dart`
- `lib/screens/you_or_me_match_results_screen.dart`

**Implementation:**
1. Verify flag cleared in initState (already exists)
2. Add logging to confirm clear happens
3. Ensure no other code paths clear the flag unexpectedly

**Tests:**
- [ ] View results, return to home - shows "COMPLETED" not "RESULTS ARE READY!"
- [ ] Clear only happens once per results view
- [ ] No errors if flag already cleared

---

## Phase 3: Unify Game Screen Polling

### Task 3.1: Add Game Topics to HomePollingService
**Priority:** Medium
**Effort:** 1 hour
**File:** `lib/services/home_polling_service.dart`

**Implementation:**
1. Add new topics: 'quizGame', 'youOrMeGame', 'linkedGame', 'wordSearchGame'
2. Add methods to poll active game matches
3. Notify game topics when turn changes detected

**Tests:**
- [ ] Game topics exist and can have subscribers
- [ ] Poll includes active game state when on game screen
- [ ] Turn changes trigger game topic notifications

---

### Task 3.2: Migrate LinkedGameScreen to Topic Subscription
**Priority:** Medium
**Effort:** 1.5 hours
**File:** `lib/screens/linked_game_screen.dart`

**Implementation:**
1. Remove `with GamePollingMixin`
2. Add HomePollingService subscription in initState
3. Subscribe to 'linkedGame' topic
4. Rebuild state from Hive on topic notification
5. Unsubscribe in dispose

**Tests:**
- [ ] Turn changes detected within 5 seconds
- [ ] Screen updates correctly on partner's move
- [ ] No memory leaks after leaving screen
- [ ] Works alongside home screen polling

---

### Task 3.3: Migrate WordSearchGameScreen to Topic Subscription
**Priority:** Medium
**Effort:** 1.5 hours
**File:** `lib/screens/word_search_game_screen.dart`

**Implementation:**
1. Same pattern as LinkedGameScreen
2. Subscribe to 'wordSearchGame' topic

**Tests:**
- [ ] Word submissions by partner detected
- [ ] Turn changes update UI correctly
- [ ] Completion transitions smoothly

---

### Task 3.4: Migrate Quiz Waiting Screens
**Priority:** Medium
**Effort:** 2 hours
**Files:**
- `lib/screens/quiz_match_waiting_screen.dart`
- `lib/screens/you_or_me_match_waiting_screen.dart`

**Implementation:**
1. Replace UnifiedGameService polling with HomePollingService subscription
2. Subscribe to 'quizGame' or 'youOrMeGame' topics
3. Handle completion detection via topic notification

**Tests:**
- [ ] Partner completion detected within 5 seconds
- [ ] Navigation to results works correctly
- [ ] No duplicate callbacks after migration

---

### Task 3.5: Remove GamePollingMixin
**Priority:** Low
**Effort:** 15 minutes
**File:** `lib/mixins/game_polling_mixin.dart`

**Implementation:**
1. Verify no files import the mixin
2. Delete the file
3. Update CLAUDE.md to remove mixin documentation

**Tests:**
- [ ] App compiles without mixin
- [ ] All game screens work correctly

---

## Phase 4: Batch API Requests

### Task 4.1: Create Unified Poll Endpoint
**Priority:** Medium
**Effort:** 3 hours
**File:** `api/app/api/sync/poll/route.ts` (new)

**Implementation:**
1. Create new endpoint that combines:
   - Daily quest status
   - Active Linked match state
   - Active Word Search match state
   - Total LP
2. Return all data in single response
3. Add caching headers for efficiency

**Tests:**
- [ ] Endpoint returns all expected data
- [ ] Response time < 200ms
- [ ] Handles missing data gracefully
- [ ] Auth works correctly

---

### Task 4.2: Update HomePollingService to Use Batch Endpoint
**Priority:** Medium
**Effort:** 2 hours
**File:** `lib/services/home_polling_service.dart`

**Implementation:**
1. Replace 3 sequential API calls with single batch call
2. Parse combined response
3. Notify appropriate topics based on changes
4. Fallback to individual calls if batch fails

**Tests:**
- [ ] Single network request per poll cycle
- [ ] All data updates correctly
- [ ] Fallback works when batch endpoint unavailable
- [ ] Performance improvement measurable

---

## Phase 5: Polish and Optimization

### Task 5.1: Add Request Timeout
**Priority:** Medium
**Effort:** 30 minutes
**File:** `lib/services/api_client.dart`

**Implementation:**
1. Add 10 second timeout to all HTTP requests
2. Handle timeout gracefully
3. Log timeout occurrences

**Tests:**
- [ ] Slow requests timeout after 10s
- [ ] UI doesn't freeze on timeout
- [ ] Retry on next poll cycle

---

### Task 5.2: Add Exponential Backoff
**Priority:** Low
**Effort:** 1 hour
**File:** `lib/services/home_polling_service.dart`

**Implementation:**
1. Track consecutive failures
2. Increase interval after failures: 5s → 10s → 20s → 30s
3. Reset to 5s on success
4. Cap at 30s maximum

**Tests:**
- [ ] Interval increases after failures
- [ ] Interval resets on success
- [ ] Cap at 30s works

---

### Task 5.3: Polling State Machine
**Priority:** Low
**Effort:** 2 hours
**File:** `lib/services/home_polling_service.dart`

**Implementation:**
1. Add PollingState enum
2. Track state transitions
3. Expose state for debugging
4. Handle pause/resume for app lifecycle

**Tests:**
- [ ] State transitions correctly
- [ ] Polling pauses when app backgrounded
- [ ] Resumes when app foregrounded

---

## Progress Tracking

### Phase 1: Critical Bug Fixes ✅ COMPLETED
- [x] Task 1.1: Fix LP Callback Memory Leak (home_screen.dart dispose now clears callback)
- [x] Task 1.2: Protect UnifiedGameService Callback (refactored to Map-based callbacks per matchId)
- [x] Task 1.3: Replace print() with Logger (4 files cleaned up)
- [x] Task 1.4: Unify Polling Intervals (all now 5s)

### Phase 2: Consolidate Pending Results Flag (PARTIALLY COMPLETE)
- [x] Task 2.1: Remove Duplicate Flag Setting (removed handleCompletion duplicates only; kept initState as safety net)
- [x] Bugfix: Fixed HomePollingService setting pending flag on initial sync after login
  - Problem: On fresh login with already-completed quests, polling mistakenly set pending flag
  - Fix: Added `wasUserAlreadyLocallyCompleted` check before setting pending flag
  - Only sets flag if user was already tracked locally (not on first sync)
- [ ] Task 2.2: Set Flag in Game Screen (required before removing initState flag)
- [ ] Task 2.3: Ensure Single Clear Location

### Phase 3: Unify Game Screen Polling
- [ ] Task 3.1: Add Game Topics
- [ ] Task 3.2: Migrate LinkedGameScreen
- [ ] Task 3.3: Migrate WordSearchGameScreen
- [ ] Task 3.4: Migrate Quiz Waiting Screens
- [ ] Task 3.5: Remove GamePollingMixin

### Phase 4: Batch API Requests
- [ ] Task 4.1: Create Unified Poll Endpoint
- [ ] Task 4.2: Update HomePollingService

### Phase 5: Polish and Optimization
- [ ] Task 5.1: Add Request Timeout
- [ ] Task 5.2: Add Exponential Backoff
- [ ] Task 5.3: Polling State Machine

---

## Rollback Procedures

### Phase 1 Rollback
```bash
git revert <phase1-commit>
```
Individual tasks can be reverted independently.

### Phase 2 Rollback
Re-add flag setting to waiting screens:
- Restore initState setPendingResultsMatchId calls
- Restore handleCompletion setPendingResultsMatchId calls

### Phase 3 Rollback
- Re-add GamePollingMixin to game screens
- Remove topic subscriptions
- Restore UnifiedGameService polling for waiting screens

### Phase 4 Rollback
- Keep old individual endpoints
- Revert HomePollingService to sequential calls
- Delete batch endpoint

---

**Next Action:** Start Task 1.1 - Fix LP Callback Memory Leak

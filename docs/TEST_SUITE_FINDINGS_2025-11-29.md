# Test Suite Findings - 2025-11-29

## Overview

The curl-based daily quest test suite (`api/scripts/test_daily_quest_flow.sh`) was created to test API endpoints without requiring device builds. Initial run uncovered several issues.

**Initial Results:** 18 passed, 21 failed
**After Fixes (Round 1):** 39 passed, 2 failed
**After Fixes (Round 2):** 41 passed, 0 failed

---

## Issues Discovered

### 1. Duplicate Variable Declaration in You-or-Me Submit Route

**Status:** Fixed

**File:** `api/app/api/sync/you-or-me-match/submit/route.ts`

**Problem:** The variable `partnerAnswerCount` was defined twice (lines 169 and 199), causing a TypeScript compilation error that crashed the entire API server.

**Error Message:**
```
the name `partnerAnswerCount` is defined multiple times
```

**Fix Applied:**
- Removed duplicate declaration on line 199
- Changed `myAnswerCount` reference to `userAnswerCount` (the existing variable from line 168)

---

### 2. LP Mismatch Between Partners (Critical)

**Status:** FIXED (2025-11-29)

**Original Evidence:**
```
Jokke total LP: 240
TestiY total LP: 1160
```

**After Fix:**
```
Jokke total LP: 1160
TestiY total LP: 1160
[PASS] LP totals MATCH!
```

**Root Cause:** LP was being stored per-user in `user_love_points.total_points` instead of at the couple level. When LP was awarded, both users' records needed to be updated atomically, but bugs caused divergence over time.

**Solution Applied:**
1. Created new column `couples.total_lp` as single source of truth
2. Migrated existing LP using `GREATEST()` of both users (took higher value)
3. Created shared `awardLP()` utility that updates `couples.total_lp`
4. Updated all LP-awarding routes to use the shared utility
5. Added trigger to update leaderboard when `couples.total_lp` changes

**Files Changed:**
- `api/supabase/migrations/025_lp_single_source.sql` - Database migration
- `api/lib/lp/award.ts` - Shared awardLP utility (NEW)
- `api/app/api/sync/love-points/route.ts` - Updated to use couples.total_lp
- `api/app/api/sync/quiz-match/submit/route.ts` - Uses shared awardLP
- `api/app/api/sync/you-or-me-match/submit/route.ts` - Uses shared awardLP
- `api/app/api/sync/linked/submit/route.ts` - Added LP award on completion
- `api/app/api/sync/word-search/submit/route.ts` - Added LP award on completion
- `api/app/api/sync/steps/route.ts` - Added LP award on steps claim

---

### 3. Quiz Submit Returns 400 on Already-Completed Matches

**Status:** FIXED (2025-11-29) - Reset endpoint created

**Symptom:** All quiz submit calls return HTTP 400.

**Cause:** The test matches from previous runs are already completed (`"status":"completed"`). The submit endpoint correctly rejects submissions to completed matches.

**Solution Applied:** Created `/api/dev/reset-games` endpoint to clear test data between runs.

---

### 4. Reset Endpoint

**Status:** FIXED (2025-11-29)

**Endpoint:** `POST /api/dev/reset-games`

**File:** `api/app/api/dev/reset-games/route.ts`

**Behavior:**
- Accepts `{ coupleId: string }` in request body
- Deletes all `quiz_matches` for that couple
- Deletes all `you_or_me_sessions` for that couple
- Returns count of deleted records
- Only available when `AUTH_DEV_BYPASS_ENABLED=true`

**Usage:**
```bash
curl -X POST "http://localhost:3000/api/dev/reset-games" \
  -H "Content-Type: application/json" \
  -H "X-Dev-User-Id: <user-id>" \
  -d '{"coupleId": "11111111-1111-1111-1111-111111111111"}'
```

---

### 5. You-or-Me Test Script Turn Order Issue

**Status:** FIXED (2025-11-29)

**Original Symptom:** Jokke fails to answer 10 questions in You-or-Me test, but TestiY succeeds.

**Root Cause:** The test script assumed Jokke (Chrome) always goes first, but the API defaults first turn to `first_player_id || user2_id`. Since TestiY is `user2_id`, TestiY gets first turn, making Jokke's submissions fail with "Not your turn".

**Solution Applied:** Updated test script to dynamically determine who plays first by checking `gameState.isMyTurn` from the API response.

**File Changed:** `api/scripts/tests/04_you_or_me.sh`

**Verified Result:**
```
[INFO] Jokke goes first: false
[INFO] Turn order: TestiY goes FIRST, Jokke goes SECOND
[PASS] TestiY completed all 10 questions
[PASS] Jokke completed all 10 questions
```

---

### 6. You-or-Me isCompleted Flag

**Status:** FIXED (2025-11-29) - Was not actually a bug

**Original Symptom:** After TestiY submits final answer, `isCompleted` is false but LP is still awarded.

**Root Cause:** The test was checking `isCompleted` on Jokke's failed submission response (because Jokke was incorrectly going first when it wasn't his turn). Once the turn order was fixed, the `isCompleted` flag works correctly.

**Verified Result:**
```
[PASS] Match should be completed (.isCompleted = true)
[PASS] LP awarded on completion (.lpEarned exists)
```

---

## Test Suite Files

| File | Purpose |
|------|---------|
| `api/scripts/test_daily_quest_flow.sh` | Main orchestrator |
| `api/scripts/lib/test_helpers.sh` | Assertions, colors, API wrapper |
| `api/scripts/lib/user_config.sh` | User IDs, API URL, couple ID |
| `api/scripts/tests/01_reset_data.sh` | Reset test data (needs endpoint) |
| `api/scripts/tests/02_classic_quiz.sh` | Classic quiz flow test |
| `api/scripts/tests/03_affirmation_quiz.sh` | Affirmation quiz flow test |
| `api/scripts/tests/04_you_or_me.sh` | You-or-Me turn-based test |
| `api/scripts/tests/05_verify_lp.sh` | LP verification test |

## Running the Tests

```bash
cd /Users/joakimachren/Desktop/togetherremind/api/scripts

# Run all tests
./test_daily_quest_flow.sh

# Run with verbose output
./test_daily_quest_flow.sh --verbose

# Run specific test
./test_daily_quest_flow.sh --test=classic
./test_daily_quest_flow.sh --test=affirmation
./test_daily_quest_flow.sh --test=you_or_me
./test_daily_quest_flow.sh --test=verify_lp

# Test against different API
API_URL=https://api.example.com ./test_daily_quest_flow.sh
```

## Test Users

| User | ID | Device | Role |
|------|-----|--------|------|
| Jokke | `d71425a3-a92f-404e-bfbe-a54c4cb58b6a` | Chrome | Goes FIRST |
| TestiY | `c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28` | Android | Goes SECOND |

**Couple ID:** `11111111-1111-1111-1111-111111111111`

---

## Next Steps

1. ~~**Investigate LP Mismatch** - Query database to understand discrepancy~~ **DONE**
2. ~~**Create Reset Endpoint** - `/api/dev/reset-games` for test data cleanup~~ **DONE** (2025-11-29)
3. ~~**Re-run Tests** - After reset endpoint is available, run full test suite~~ **DONE** (39 passed, 2 failed)
4. ~~**Fix LP Bug** - If investigation reveals a bug, fix and sync LP totals~~ **DONE** (2025-11-29)
5. ~~**Fix You-or-Me test script turn order** - Test now dynamically determines first player~~ **DONE** (2025-11-29)
6. ~~**Verify isCompleted flag** - Was not a bug, just affected by turn order issue~~ **DONE** (2025-11-29)

**All issues resolved! Test suite now passes: 41 passed, 0 failed**

---

## Summary of Fixes Applied

### LP Single Source of Truth (2025-11-29)

The LP mismatch issue has been permanently resolved by moving LP storage from per-user to couple-level:

**Architecture Change:**
- **Before:** `user_love_points.total_points` per user (could diverge)
- **After:** `couples.total_lp` single column (always identical for both partners)

**Verified Result:**
```
Jokke LP: 1160
TestiY LP: 1160
[PASS] LP totals MATCH!
```

See `CLAUDE.md` section 18 for full documentation.

### You-or-Me Test Script Turn Order Fix (2025-11-29)

The You-or-Me test was failing because it assumed Jokke (Chrome) always plays first. In reality, the API defaults first turn to `first_player_id || user2_id`.

**Root Cause:**
- Test assumed creator goes first
- API gives turn to `first_player_id` (from couples table) or `user2_id` (default)
- TestiY is `user2_id`, so TestiY gets first turn by default
- Jokke's submissions failed with "Not your turn" (HTTP 400)

**Solution:**
- Test now reads `gameState.isMyTurn` from the API response
- Dynamically determines who plays first vs second
- Both players complete all questions correctly

**Verified Result:**
```
Results: 41 passed, 0 failed
```

---

## Appendix: Full Test Output

```
========================================
  Daily Quest Test Suite
========================================

Date:      2025-11-28
API:       http://localhost:3000
Jokke ID:  d71425a3-a92f-404e-bfbe-a54c4cb58b6a (Chrome - goes FIRST)
TestiY ID: c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28 (Android - goes SECOND)
Couple:    11111111-1111-1111-1111-111111111111

----------------------------------------

[TEST] Reset Test Data
---
[INFO] Recording initial LP totals...
[INFO] Initial LP total: 240
[INFO] Calling reset endpoint...
[INFO] Reset endpoint returned HTTP 404 (may not exist yet)
[INFO] Continuing with tests - new sessions will be created

[TEST] Classic Quiz - Full Flow
---
[INFO] Jokke (Chrome) creates/gets classic quiz match...
[PASS] Jokke creates classic quiz match (HTTP 200)
[PASS] Response indicates success (.success = true)
[INFO] Match ID: 93dd4dc4-5f3f-41ff-b727-45e8a3086763
[INFO] Questions loaded: 5
[PASS] Quiz has 5 questions
[INFO] Jokke (Chrome) submits his answers...
[FAIL] Jokke submits answers (Expected HTTP 200, got 400)
[FAIL] Submit successful (Expected .success = true, got null)
...

[TEST] Love Points - Verification
---
[INFO] Fetching Jokke's LP total...
[PASS] Fetch Jokke LP (HTTP 200)
[INFO] Jokke total LP: 240
[INFO] Fetching TestiY's LP total...
[PASS] Fetch TestiY LP (HTTP 200)
[INFO] TestiY total LP: 1160
[FAIL] LP mismatch: Jokke=240, TestiY=1160

========================================
Results: 18 passed, 21 failed
========================================
```

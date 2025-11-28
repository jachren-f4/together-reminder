# Quiz API Migration Plan

**Date:** 2025-11-28
**Status:** Phase 2 Complete - API Endpoints Created
**Goal:** Migrate Classic Quiz, Affirmation Quiz, and You or Me from Firebase RTDB to Vercel API + Supabase (matching Linked/Word Search architecture)

---

## Problem Statement

Currently, Classic Quiz, Affirmation Quiz, and You or Me use Firebase RTDB for sync with a `isSimulatorSync` guard that **blocks physical devices** from syncing. This causes "Session not found" errors when launching quests on physical iPhones/Android devices.

The newer features (Linked, Word Search, Steps) use a Vercel API + Supabase architecture that works on all devices.

---

## Architecture Comparison

| Aspect | Current (Quiz) | Target (Linked-style) |
|--------|---------------|----------------------|
| Sync mechanism | Firebase RTDB (client writes) | Vercel API (server writes) |
| Device support | Simulators only (`isSimulatorSync`) | All devices |
| State storage | Firebase RTDB + Hive | Supabase + Hive |
| Session creation | Client-side | Server-side |
| Answer submission | Client writes to RTDB | POST to `/api/sync/quiz/submit` |
| Polling | Firebase listeners | 10-30s HTTP polling |

---

## Scope

### In Scope
- Classic Quiz (`formatType: 'classic'`)
- Affirmation Quiz (`formatType: 'affirmation'`)
- You or Me (`formatType: 'youorme'`)

### Out of Scope
- Linked (already migrated)
- Word Search (already migrated)
- Steps Together (already migrated)

---

## Phase 1: Database Schema (Day 1) ✅ COMPLETE

### Tasks

- [x] **1.1** Review existing Supabase schema for quiz tables
  - Check if `quiz_sessions`, `quiz_answers`, `quiz_progression` tables exist
  - Check if `you_or_me_sessions`, `you_or_me_answers`, `you_or_me_progression` tables exist

- [x] **1.2** Create/update migration file `api/supabase/migrations/021_quiz_api_migration.sql`
  - Added columns: `subject_user_id`, `initiated_by`, `daily_quest_id`, `answers`, `predictions`, `match_percentage`, `lp_earned`, `alignment_matches`, `prediction_scores`, `branch`, `date`
  - Added indexes for `(couple_id, date)` and `(couple_id, format_type, date)`
  - Added RLS policies for you_or_me tables

- [x] **1.3** Apply migration to Supabase
  - Migration executed successfully via Supabase SQL Editor

### Testing - Phase 1 ✅

- [x] **T1.1** Verify tables exist: `SELECT * FROM quiz_sessions LIMIT 1;`
- [x] **T1.2** Verified new columns exist (date, answers, subject_user_id, initiated_by)
- [x] **T1.3** Verified you_or_me_sessions columns exist (date, answers, status, user_id, partner_id)

---

## Phase 2: API Endpoints (Days 2-4) ✅ COMPLETE

### 2A: Classic/Affirmation Quiz Endpoints

- [x] **2.1** Create `api/app/api/sync/quiz/route.ts`
  - `POST` - Create or get quiz session for today
  - `GET` - Get current session state (for polling)

- [x] **2.2** Create `api/app/api/sync/quiz/[sessionId]/route.ts`
  - `GET` - Poll specific session state

- [x] **2.3** Create `api/app/api/sync/quiz/submit/route.ts`
  - `POST` - Submit answers for a session
  - Handle both classic (predictor answers) and affirmation (5-point scale)
  - Calculate results when both users have answered
  - Award LP on completion

### 2B: You or Me Endpoints

- [x] **2.4** Expand `api/app/api/sync/you-or-me/route.ts`
  - `POST` - Create or get You or Me session for today
  - `GET` - Get current session state

- [x] **2.5** Create `api/app/api/sync/you-or-me/[sessionId]/route.ts`
  - `GET` - Poll specific session state

- [x] **2.6** Create `api/app/api/sync/you-or-me/submit/route.ts`
  - `POST` - Submit answer for a single question
  - Support partial progress (answer one question at a time)
  - Calculate results when both users complete all questions

### API Design Reference (matching Linked pattern)

```typescript
// POST /api/sync/quiz
// Request: { date: "2025-11-28", formatType: "classic" | "affirmation" }
// Response: { session: QuizSession, isNew: boolean }

// GET /api/sync/quiz?date=2025-11-28&formatType=classic
// Response: { session: QuizSession | null }

// POST /api/sync/quiz/submit
// Request: { sessionId: string, answers: number[], predictions?: number[] }
// Response: { success: boolean, session: QuizSession, lpAwarded?: number }

// GET /api/sync/quiz/[sessionId]
// Response: { session: QuizSession }
```

### Testing - Phase 2

- [ ] **T2.1** API health check: `curl -X GET http://localhost:3000/api/sync/quiz`
- [ ] **T2.2** Create session test: POST with Alice's user ID
- [ ] **T2.3** Get session test: GET with Bob's user ID (should return same session)
- [ ] **T2.4** Submit answers test: POST submit with Alice
- [ ] **T2.5** Submit answers test: POST submit with Bob
- [ ] **T2.6** Verify completion: Session status = 'completed', LP awarded
- [x] **T2.7** Create shell script: `api/scripts/test_quiz_api.sh`
- [x] **T2.8** Create shell script: `api/scripts/test_you_or_me_api.sh`

**To run tests:**
```bash
cd api && npm run dev  # In one terminal
cd api && ./scripts/test_quiz_api.sh  # In another terminal
cd api && ./scripts/test_you_or_me_api.sh
```

---

## Phase 3: Flutter Service Refactor (Days 5-7)

### 3A: Create API-based Quiz Service

- [ ] **3.1** Create `lib/services/quiz_api_service.dart`
  - Mirror structure of `linked_service.dart`
  - Methods: `createOrGetSession()`, `getSession()`, `submitAnswers()`, `startPolling()`, `stopPolling()`
  - Use `AuthService.getAccessToken()` for auth headers
  - Handle dev bypass with `X-Dev-User-Id` header

- [ ] **3.2** Update `lib/services/quiz_service.dart`
  - Replace `_syncSessionToRTDB()` with API calls
  - Remove `isSimulatorSync` guard
  - Keep Hive caching for offline support

- [ ] **3.3** Create `lib/services/you_or_me_api_service.dart`
  - Mirror structure of `quiz_api_service.dart`
  - Handle partial answer submission (one question at a time)

- [ ] **3.4** Update `lib/services/you_or_me_service.dart`
  - Replace Firebase writes with API calls
  - Remove `isSimulatorSync` guard (if present)

### 3B: Update Navigation Service

- [ ] **3.5** Update `lib/services/quest_navigation_service.dart`
  - `_getSession()` should try API first, then local cache
  - Handle API errors gracefully with fallback to local

### Testing - Phase 3

- [ ] **T3.1** Unit test: `quiz_api_service_test.dart`
- [ ] **T3.2** Unit test: `you_or_me_api_service_test.dart`
- [ ] **T3.3** Integration test: Create session on Android, verify on Chrome
- [ ] **T3.4** Integration test: Submit answers on Chrome, verify on Android
- [ ] **T3.5** Offline test: Submit while offline, verify sync when online

---

## Phase 4: Screen Updates (Days 8-9)

### Tasks

- [ ] **4.1** Update `lib/screens/quiz_intro_screen.dart`
  - Use `QuizApiService` instead of direct `QuizService` for session creation

- [ ] **4.2** Update `lib/screens/quiz_screen.dart`
  - Submit answers via API
  - Poll for partner's answers

- [ ] **4.3** Update `lib/screens/affirmation_question_screen.dart`
  - Submit answers via API

- [ ] **4.4** Update `lib/screens/you_or_me_game_screen.dart`
  - Submit each answer via API
  - Poll for partner's progress

- [ ] **4.5** Update waiting screens
  - `quiz_waiting_screen.dart` - Poll API instead of Firebase listener
  - `you_or_me_waiting_screen.dart` - Poll API instead of Firebase listener

### Testing - Phase 4

- [ ] **T4.1** Manual test: Classic quiz full flow on iPhone
- [ ] **T4.2** Manual test: Affirmation quiz full flow on iPhone
- [ ] **T4.3** Manual test: You or Me full flow on iPhone
- [ ] **T4.4** Manual test: Cross-device (iPhone + Android) for all three
- [ ] **T4.5** Manual test: Partner waiting screen updates when other submits

---

## Phase 5: Remove Legacy Code (Day 10)

### Tasks

- [ ] **5.1** Remove Firebase RTDB sync code from `quiz_service.dart`
  - Delete `_syncSessionToRTDB()`
  - Delete `_generateCoupleId()` (use Supabase couple_id instead)
  - Remove Firebase RTDB imports

- [ ] **5.2** Remove Firebase RTDB sync code from `you_or_me_service.dart`
  - Delete any `_rtdb` references

- [ ] **5.3** Remove `isSimulatorSync` checks throughout codebase
  - Search: `grep -r "isSimulatorSync" app/lib/`

- [ ] **5.4** Clean up unused Firebase RTDB paths
  - Document paths to delete: `/quiz_sessions/`, `/you_or_me_sessions/`
  - DO NOT delete yet (keep for rollback)

- [ ] **5.5** Update CLAUDE.md
  - Remove references to `isSimulatorSync` for quizzes
  - Document new API endpoints

### Testing - Phase 5

- [ ] **T5.1** Verify no Firebase writes: Check RTDB console during quiz flow
- [ ] **T5.2** Full regression: All daily quest types work on physical devices
- [ ] **T5.3** Cross-device sync: Both partners see correct state

---

## Phase 6: Production Validation (Days 11-14)

### Tasks

- [ ] **6.1** Deploy API to Vercel production
  ```bash
  cd api && vercel --prod
  ```

- [ ] **6.2** Update Flutter to use production API URL
  - Set `useProductionApi = true` in `dev_config.dart`

- [ ] **6.3** Build and deploy Flutter app
  - iOS TestFlight
  - Android internal testing

- [ ] **6.4** Monitor for 3 days
  - Check Supabase logs for errors
  - Check Vercel function logs
  - Monitor user feedback

### Testing - Phase 6

- [ ] **T6.1** Production smoke test: Create quiz on production
- [ ] **T6.2** Production smoke test: Complete quiz on two physical devices
- [ ] **T6.3** Load test: 100 concurrent quiz sessions
- [ ] **T6.4** Verify LP awards are correct (no duplicates)
- [ ] **T6.5** Verify quiz progression advances correctly

---

## Rollback Plan

If issues are discovered:

1. **Immediate (< 1 hour):** Revert Flutter code to use Firebase RTDB
2. **Short-term (< 1 day):** Re-enable `isSimulatorSync` guard
3. **Data recovery:** Firebase RTDB data preserved for 30 days

---

## Success Criteria

- [ ] All three quest types (Classic, Affirmation, You or Me) work on physical iPhones
- [ ] All three quest types work on physical Android devices
- [ ] Cross-device sync works within 30 seconds
- [ ] No "Session not found" errors
- [ ] LP awards are correct (no duplicates)
- [ ] Offline support: Can start quiz offline, syncs when online

---

## Files to Modify

### API (New)
- `api/app/api/sync/quiz/route.ts`
- `api/app/api/sync/quiz/[sessionId]/route.ts`
- `api/app/api/sync/quiz/submit/route.ts`
- `api/app/api/sync/you-or-me/[sessionId]/route.ts`
- `api/app/api/sync/you-or-me/submit/route.ts`
- `api/supabase/migrations/020_quiz_api_migration.sql`
- `api/scripts/test_quiz_api.sh`
- `api/scripts/test_you_or_me_api.sh`

### Flutter (Modify)
- `lib/services/quiz_service.dart`
- `lib/services/you_or_me_service.dart`
- `lib/services/quest_navigation_service.dart`
- `lib/screens/quiz_intro_screen.dart`
- `lib/screens/quiz_screen.dart`
- `lib/screens/affirmation_question_screen.dart`
- `lib/screens/you_or_me_game_screen.dart`
- `lib/screens/quiz_waiting_screen.dart`
- `lib/screens/you_or_me_waiting_screen.dart`

### Flutter (New)
- `lib/services/quiz_api_service.dart`
- `lib/services/you_or_me_api_service.dart`

### Documentation
- `CLAUDE.md` - Update architecture notes
- `docs/MIGRATION_HANDOVER.md` - Mark quiz migration complete

---

## Reference Implementation

Use these files as reference for the API pattern:
- `api/app/api/sync/linked/route.ts` - Session creation
- `api/app/api/sync/linked/submit/route.ts` - Answer submission
- `app/lib/services/linked_service.dart` - Flutter service pattern

---

## Timeline Estimate

| Phase | Duration | Cumulative |
|-------|----------|------------|
| Phase 1: Database | 1 day | Day 1 |
| Phase 2: API Endpoints | 3 days | Day 4 |
| Phase 3: Flutter Services | 3 days | Day 7 |
| Phase 4: Screen Updates | 2 days | Day 9 |
| Phase 5: Legacy Removal | 1 day | Day 10 |
| Phase 6: Production | 4 days | Day 14 |

**Total: ~2 weeks**

---

**Last Updated:** 2025-11-28

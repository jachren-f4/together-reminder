# Remove Firebase RTDB - Full Architecture Simplification

## Goal

Remove Firebase Realtime Database entirely and use only:
- **Supabase** - Server source of truth (all synced data)
- **Hive** - Local cache for fast UI display

## Current Firebase RTDB Usage (9 Files)

| Service | Firebase Path | Current Use | Supabase Replacement |
|---------|---------------|-------------|---------------------|
| QuestSyncService | `/daily_quests/` | Quest generation & sync | Already migrated |
| DailyQuestsWidget | `/daily_quests/.../completions` | Partner completion listener | Polling |
| LovePointService | `/lp_awards/` | LP award syncing | Already has fallback |
| CouplePreferencesService | `/couple_preferences/` | First player pref | Polling |
| StepsSyncService | `/steps_data/` | Steps connection & data | Polling |
| DailyPulseService | `/daily_pulse/` | Pulse responses | Polling |
| QuestsTab (debug) | `/daily_quests/` | Debug inspection | Keep for now |
| LpSyncTab (debug) | Various | Debug inspection | Keep for now |
| DevPairingService | Dev paths | Dev pairing | Keep for now |

---

## New Architecture: Supabase + Hive Only

### Data Flow (Simplified)

```
[Client A] → POST /api/... → [Supabase] ← GET /api/... ← [Client B]
     ↓                                              ↓
   [Hive A]                                     [Hive B]
```

### Polling Strategy

| Feature | Polling Location | Interval | Trigger |
|---------|-----------------|----------|---------|
| Quiz completion | Waiting screen | 5s | Already exists |
| Partner quest status | Home screen | 30s | New polling |
| LP updates | Home screen | 30s | New polling |
| Steps sync | Steps screen | 60s | Already exists |
| Couple preferences | Settings | On open | One-time fetch |

---

## Phase 1: Quiz Flow (Priority - Fix Current Bugs)

### Status: IMPLEMENTED (2025-11-29)

### Goal
Fix the quiz completion flow so both partners see correct status and LP.

### Implementation Summary

1. **Created `api/app/api/sync/quest-status/route.ts`** (NEW)
   - Returns quest completion status from `quiz_matches` table (all game types use this table)
   - Response: `{ quests: [{ questId, questType, status, userCompleted, partnerCompleted, matchId, lpAwarded, player1Score, player2Score, matchPercentage }], totalLp }`
   - Fixed column name issues during implementation (you_or_me uses quiz_matches, not separate table)

2. **Modified `app/lib/widgets/daily_quests_widget.dart`**
   - Removed Firebase `_partnerCompletionSubscription` and `StreamSubscription` import
   - Added `Timer? _pollingTimer` for 30-second interval polling
   - Polls `/api/sync/quest-status` endpoint
   - Updates local quest status when partner completion detected

3. **`app/lib/services/quest_sync_service.dart`**
   - Already uses Supabase-only paths via `DevConfig.useSuperbaseForDailyQuests = true`
   - Firebase writes are bypassed by the flag

### Testing Checklist - Phase 1

**API Tests (via curl script `api/scripts/test_phase1_quest_status.sh`) - ALL PASSED (2025-11-29):**

- [x] Quest status endpoint returns empty after reset
- [x] User 1 can create quiz match via POST
- [x] User 1 can submit answers
- [x] User 2 polls and sees partner completed = true (polling works!)
- [x] User 2 submits → match completes, 30 LP awarded, match % calculated
- [x] Both users see completed status and 30 LP
- [x] Total LP is returned in response

**End-to-End Tests (with Flutter apps):**

- [ ] Chrome completes quiz → Android sees "Jokke completed" on quest card (within 30s)
- [ ] Android completes quiz → Both see "COMPLETED" status
- [ ] Both devices show 30 LP after both complete
- [ ] No Firebase RTDB errors in console
- [ ] Quest card updates correctly on home screen refresh

---

## Phase 2: LP Sync

### Goal
Remove Firebase listeners for LP and use Supabase polling.

### Files to Modify

1. **`app/lib/services/love_point_service.dart`**
   - Remove `startListeningForLPAwards()` Firebase listener
   - Remove Firebase RTDB writes
   - Add Supabase polling method for LP updates
   - Keep existing Supabase fallback as primary

2. **`app/lib/screens/new_home_screen.dart`**
   - Add LP polling on app resume
   - Poll Supabase for current LP value

3. **`app/lib/main.dart`**
   - Remove Firebase listener initialization for LP

### Existing API
- `GET /api/sync/love-points` - Already returns LP from Supabase

### Testing Checklist - Phase 2

After completing Phase 2, verify:

- [ ] LP counter shows correct value on app launch
- [ ] LP updates after completing quiz (via Supabase polling)
- [ ] LP counter updates when returning to home screen
- [ ] No Firebase RTDB errors related to LP
- [ ] LP is consistent between both devices

---

## Phase 3: Couple Preferences

### Goal
Remove Firebase listener for first player preference.

### Files to Modify

1. **`app/lib/services/couple_preferences_service.dart`**
   - Remove Firebase RTDB listener
   - Fetch from Supabase on settings screen open
   - Cache in Hive for local reads

### Testing Checklist - Phase 3

After completing Phase 3, verify:

- [ ] "Who goes first" preference loads correctly in Settings
- [ ] Changing preference saves to Supabase
- [ ] Partner sees updated preference after refreshing settings
- [ ] No Firebase errors for couple preferences

---

## Phase 4: Steps Together

### Goal
Remove Firebase listeners for steps sync.

### Files to Modify

1. **`app/lib/services/steps_sync_service.dart`**
   - Remove Firebase RTDB listeners
   - Use existing Supabase API at `/api/sync/steps`
   - Poll on Steps screen (already has 60s polling)

### Testing Checklist - Phase 4

After completing Phase 4, verify:

- [ ] Steps counter shows correct values
- [ ] Both partners see each other's steps
- [ ] Goal progress updates correctly
- [ ] No Firebase errors for steps

---

## Phase 5: Daily Pulse

### Goal
Remove Firebase sync for daily pulse responses.

### Files to Modify

1. **`app/lib/services/daily_pulse_service.dart`**
   - Migrate sync to Supabase if not already
   - Remove any Firebase RTDB usage

### Testing Checklist - Phase 5

After completing Phase 5, verify:

- [ ] Daily pulse responses save correctly
- [ ] Partner can see responses
- [ ] No Firebase errors for daily pulse

---

## Phase 6: Cleanup & Verification

### Goal
Remove unused Firebase RTDB imports and verify no regressions.

### Files to Modify

1. **Remove Firebase RTDB imports from:**
   - All services that no longer use it
   - Keep debug tabs for now (they read-only)

2. **Verify Firebase dependencies:**
   - Keep `firebase_database` in pubspec.yaml for debug tabs
   - Can remove entirely in future phase

### Final Testing Checklist

- [ ] Complete quiz flow works end-to-end
- [ ] LP awards and displays correctly
- [ ] Quest cards update on both devices
- [ ] No Firebase RTDB errors in any console
- [ ] All features work offline (Hive cache)
- [ ] App performance is good (no excessive polling)

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Polling increases API load | 30s intervals are reasonable for 2-person app |
| Slower updates (not real-time) | 5s polling on waiting screen is fast enough |
| Breaking existing features | Test each feature after migration |
| Debug tabs stop working | Keep Firebase imports for debug only |

---

## Rollback Plan

If issues arise:
1. Each phase is independent - can stop at any phase
2. Git commit after each phase allows easy rollback
3. Firebase RTDB data remains available (we're only removing writes)

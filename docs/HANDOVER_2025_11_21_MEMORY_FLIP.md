# Handover Document - Memory Flip Migration
**Date:** 2025-11-21
**Session Focus:** Memory Flip Game - Real-time to Turn-based Migration

---

## Session Summary

### What Was Completed

1. **Fixed Memory Flip Real-Time Sync Issue** ✅
   - Added Firebase RTDB real-time listener to `memory_flip_game_screen.dart`
   - Fixed import error in `/api/sync/memory-flip/route.ts` (withAuth → withAuthOrDevBypass)
   - Added Supabase dual-write to match updates in `MemoryFlipSyncService`
   - Updated cleanup script to include `memory_puzzles` table

2. **Created Turn-Based Specification** ✅
   - Complete specification document at: `/docs/MEMORY_FLIP_TURN_BASED_SPEC.md`
   - Defined game rules based on user requirements:
     - Individual flip allowances (6 flips every 5 hours)
     - No bonus turns for matches
     - 5-hour turn timeout
     - Score tracking per player
     - Polling updates (like Daily Quests)

### Current State

#### Working Features
- Memory Flip game works with Firebase RTDB real-time sync
- Supabase dual-write is functional (Android only, Chrome has localhost:4000 connection issue)
- Both devices can see matches in real-time

#### Known Issues
1. **Chrome Cannot Connect to API Server**
   - Error: `ClientException: Failed to fetch, uri=http://localhost:4000/api/sync/memory-flip`
   - Impact: Supabase dual-write fails on web platform
   - Workaround: Firebase RTDB still works for real-time sync

2. **Firebase RTDB Still Required**
   - Currently using Firebase for real-time sync
   - Need to migrate to Supabase-only solution

---

## Next Steps - Memory Flip Turn-Based Implementation

### Phase 1: Database Setup (Priority: HIGH)

Create file: `/api/supabase/migrations/009_memory_flip_turn_based.sql`

```sql
-- Add turn-based columns to memory_puzzles
ALTER TABLE memory_puzzles ADD COLUMN
  current_player_id UUID REFERENCES auth.users(id),
  turn_number INT DEFAULT 0,
  turn_started_at TIMESTAMPTZ,
  turn_expires_at TIMESTAMPTZ,
  player1_pairs INT DEFAULT 0,
  player2_pairs INT DEFAULT 0,
  game_phase TEXT DEFAULT 'waiting',
  player1_flips_remaining INT DEFAULT 6,
  player1_flips_reset_at TIMESTAMPTZ,
  player2_flips_remaining INT DEFAULT 6,
  player2_flips_reset_at TIMESTAMPTZ;

-- Create memory_moves audit table
CREATE TABLE memory_moves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  puzzle_id UUID REFERENCES memory_puzzles(id) ON DELETE CASCADE,
  player_id UUID REFERENCES auth.users(id),
  card1_id VARCHAR NOT NULL,
  card2_id VARCHAR NOT NULL,
  card1_position INT NOT NULL,
  card2_position INT NOT NULL,
  match_found BOOLEAN NOT NULL,
  pair_id VARCHAR,
  turn_number INT NOT NULL,
  flips_remaining_after INT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(puzzle_id, turn_number)
);

-- Add RLS policies (see spec for details)
```

### Phase 2: API Endpoints (Priority: HIGH)

Create file: `/api/app/api/sync/memory-flip/move/route.ts`

Key functionality:
- Validate it's player's turn
- Check turn timeout (5 hours)
- Validate player has flips remaining
- Process move and check for match
- Update scores and advance turn
- Record move in audit table

### Phase 3: Flutter Service Updates (Priority: HIGH)

Update: `/app/lib/services/memory_flip_service.dart`
- Remove Firebase RTDB dependencies
- Add `submitMove()` method
- Add `isMyTurn()` method
- Update flip allowance to 5-hour recharge

Delete: `/app/lib/services/memory_flip_sync_service.dart`
- No longer needed (Firebase RTDB sync)

### Phase 4: UI Updates (Priority: MEDIUM)

Update: `/app/lib/screens/memory_flip_game_screen.dart`
- Add turn indicator ("Your Turn" / "Waiting for Partner")
- Show score tracking (Alice: 3 pairs, Bob: 2 pairs)
- Disable cards when not player's turn
- Add pull-to-refresh for updates
- Remove Firebase RTDB listener

---

## Important Context for Next Session

### User Preferences (from this session)
1. **Flip Recharge:** Every 5 hours (not daily)
2. **No Bonus Turns:** Matches don't give extra turns
3. **Score Tracking:** Track who found each pair
4. **Turn Timeout:** 5 hours before auto-advance
5. **Updates:** Same pattern as Daily Quests (polling on screen load)

### Architecture Decisions
1. **Remove Firebase RTDB completely** - Use only Supabase
2. **Turn-based instead of real-time** - Simplifies sync logic
3. **Server-side validation** - All moves validated in API
4. **Audit trail** - memory_moves table tracks all actions

### Testing Requirements
- Test turn transitions
- Test 5-hour flip recharge
- Test 5-hour turn timeout
- Test score tracking accuracy
- Test offline handling

---

## Files Modified Today

### Fixed for Real-Time Sync
1. `/app/lib/screens/memory_flip_game_screen.dart` - Added Firebase listener
2. `/app/lib/services/memory_flip_sync_service.dart` - Added Supabase sync to matches
3. `/api/app/api/sync/memory-flip/route.ts` - Fixed import error
4. `/api/scripts/clear_quest_tables.ts` - Added memory_puzzles cleanup

### Documentation Created
1. `/docs/MEMORY_FLIP_TURN_BASED_SPEC.md` - Complete specification
2. `/docs/HANDOVER_2025_11_21_MEMORY_FLIP.md` - This handover document

---

## Current Todo List

1. ✅ Write detailed Memory Flip turn-based specification
2. ⏳ Create Supabase migration for turn-based schema
3. ⏳ Create move validation API endpoint
4. ⏳ Update Flutter service to use Supabase-only
5. ⏳ Update UI for turn-based gameplay
6. ⏳ Remove Firebase RTDB dependencies
7. ⏳ Test turn-based Memory Flip gameplay

---

## Commands for Testing

### Quick Test Setup
```bash
# Clean Firebase
firebase database:remove /memory_puzzles --force

# Clean Supabase (if local)
cd /Users/joakimachren/Desktop/togetherremind/api
npx tsx scripts/clear_quest_tables.ts

# Launch both devices
cd /Users/joakimachren/Desktop/togetherremind/app
flutter run -d emulator-5554 &  # Android
sleep 8
flutter run -d chrome &          # Chrome
```

### API Server (if needed)
```bash
cd /Users/joakimachren/Desktop/togetherremind/api
PORT=4000 npm run dev
```

---

## Critical Notes

1. **Do NOT remove Firebase RTDB** until turn-based implementation is complete and tested
2. **Chrome API connection issue** needs investigation (CORS or localhost resolution)
3. **Specification is approved** - Follow `/docs/MEMORY_FLIP_TURN_BASED_SPEC.md` exactly
4. **5-hour timers** are critical - Both flip recharge AND turn timeout

---

## Questions Resolved

All design questions were answered:
- ✅ Flip allowances: Individual, 5-hour recharge
- ✅ Match behavior: No bonus turns, track scorer
- ✅ Turn timeout: 5 hours
- ✅ Updates: Polling like Daily Quests

---

## Next Session Should Start With

1. Create the Supabase migration file
2. Run migration in Supabase
3. Create the move validation API endpoint
4. Test with Postman/curl
5. Begin Flutter service updates

---

**Handover Complete**
All context preserved for continuation.
Last action: Created turn-based specification document.
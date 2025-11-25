# Phase 3 Dual-Write Testing Plan

## Overview
Test dual-write implementations for Pokes, Reminders, You or Me, and Memory Flip features.

## Prerequisites
1. **Logging enabled** in `app/lib/utils/logger.dart`:
   - `poke: true` ✓
   - `you_or_me: true` ✓
   - `memory_flip: true` ✓

2. **Backend running**:
   ```bash
   cd /Users/joakimachren/Desktop/togetherremind/api
   npm run dev  # Should be running on http://localhost:4000
   ```

3. **Clean test environment**:
   ```bash
   # Uninstall Android app
   ~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind

   # Clear Firebase RTDB
   cd /Users/joakimachren/Desktop/togetherremind
   firebase database:remove /pokes --force
   firebase database:remove /you_or_me_sessions --force
   firebase database:remove /memory_puzzles --force
   ```

## Test 1: Poke Dual-Write

### Actions
1. Launch Alice (Android) and Bob (Chrome)
2. Alice sends a poke to Bob
3. Bob receives the poke

### Expected Logs
**Alice's console:**
```
[poke] 🚀 Attempting dual-write to Supabase (poke)...
[poke] ✅ Supabase dual-write successful!
```

**Bob's console:**
```
[poke] 🚀 Attempting dual-write to Supabase (poke)...
[poke] ✅ Supabase dual-write successful!
```

### Verification
```bash
# Check Firebase RTDB
firebase database:get /pokes

# Check Supabase PostgreSQL
cd /Users/joakimachren/Desktop/togetherremind/api
npx tsx scripts/verify_poke_sync.ts
```

### Success Criteria
- ✓ Firebase RTDB contains poke with correct data
- ✓ Supabase `reminders` table contains:
  - 2 rows (one "sent", one "received")
  - Correct category='poke'
  - Correct from/to user IDs
  - Correct couple_id

---

## Test 2: You or Me Dual-Write

### Actions
1. Launch Alice (Android) and Bob (Chrome)
2. Alice navigates to Activities screen
3. Alice starts a "You or Me" game
4. New session is created

### Expected Logs
**Alice's console:**
```
[you_or_me] 🚀 Attempting dual-write to Supabase (youOrMe)...
[you_or_me] ✅ Supabase dual-write successful!
```

### Verification
```bash
# Check Firebase RTDB
firebase database:get /you_or_me_sessions

# Check Supabase PostgreSQL
cd /Users/joakimachren/Desktop/togetherremind/api
npx tsx scripts/verify_you_or_me_sync.ts
```

### Success Criteria
- ✓ Firebase RTDB contains session with questions array
- ✓ Supabase `you_or_me_sessions` table contains:
  - 1 row with matching session ID
  - Questions stored as JSONB array
  - Correct couple_id
  - Correct created_at timestamp

---

## Test 3: Memory Flip Dual-Write

### Actions
1. Launch Alice (Android) and Bob (Chrome)
2. Alice navigates to Activities screen
3. Alice starts a "Memory Flip" game
4. New puzzle is created and synced

### Expected Logs
**Alice's console:**
```
[memory_flip] 💾 Saving puzzle to Firebase...
[memory_flip] 🚀 Attempting dual-write to Supabase (memoryFlip)...
[memory_flip] ✅ Supabase dual-write successful!
[memory_flip]    ✅ Puzzle saved to Firebase
```

**Bob's console:**
```
[memory_flip] 📡 Loading puzzle from Firebase...
[memory_flip]    ✅ Puzzle loaded from Firebase
```

### Verification
```bash
# Check Firebase RTDB
firebase database:get /memory_puzzles

# Check Supabase PostgreSQL
cd /Users/joakimachren/Desktop/togetherremind/api
npx tsx scripts/verify_memory_flip_sync.ts
```

### Success Criteria
- ✓ Firebase RTDB contains puzzle with cards array
- ✓ Supabase `memory_puzzles` table contains:
  - 1 row with matching puzzle ID
  - Cards stored as JSONB array
  - Correct couple_id
  - Correct date (YYYY-MM-DD format)
  - status='active'

---

## Common Issues

### Issue: "No authorization token provided"
**Cause:** JWT token not being sent with dual-write request
**Fix:** Check that `ApiClient` is properly configured with auth token

### Issue: "No couple found for user"
**Cause:** User not linked to a couple in Supabase
**Fix:** Run pairing flow or manually insert couple record

### Issue: Dual-write logs not appearing
**Cause:** Logger service not enabled
**Fix:** Verify `logger.dart` has correct services enabled

### Issue: "Connection refused" on dual-write
**Cause:** Backend not running
**Fix:** Start backend with `npm run dev` on port 4000

---

## Quick Launch Script

```bash
# 1. Kill existing Flutter processes
pkill -9 -f "flutter"

# 2. Start Alice (Android) in background
cd /Users/joakimachren/Desktop/togetherremind/app
flutter run -d emulator-5554 2>&1 | grep -E "poke|you_or_me|memory_flip" &

# 3. Wait 5 seconds, then start Bob (Chrome)
sleep 5
flutter run -d chrome 2>&1 | grep -E "poke|you_or_me|memory_flip" &
```

This filters console output to only show dual-write logs from the three services.

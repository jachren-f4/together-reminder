---
description: Launch TestiY (Android) and Jokke (Chrome) for local couple testing
---

Quick launch of both test devices. Minimal by default - only does what's necessary.

**What this does:**
1. Kill existing Flutter processes (prevents port conflicts)
2. Launch Android emulator (TestiY)
3. Wait 3 seconds for quest generation
4. Launch Chrome (Jokke)

**Commands to run:**
```bash
# Kill existing processes
pkill -9 -f "flutter" 2>/dev/null || true

# Launch Android (TestiY)
cd /Users/joakimachren/Desktop/togetherremind/app
flutter run -d emulator-5554 --flavor togetherremind --dart-define=BRAND=togetherRemind &

# Wait for Android to generate quests, then launch Chrome (Jokke)
sleep 3
flutter run -d chrome --dart-define=BRAND=togetherRemind &
```

---

## Need more cleanup?

**Reset games only** (Linked, Word Search, Memory Flip):
```bash
cd /Users/joakimachren/Desktop/togetherremind/api && npx tsx scripts/reset_all_games.ts
```

**Full clean start** (for debugging sync issues - rarely needed):
```bash
# Uninstall Android app
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind

# Clear Firebase RTDB
cd /Users/joakimachren/Desktop/togetherremind
firebase database:remove /daily_quests --force
firebase database:remove /quiz_sessions --force
firebase database:remove /lp_awards --force
firebase database:remove /quiz_progression --force

# Clear Supabase quest tables
cd /Users/joakimachren/Desktop/togetherremind/api && npx tsx scripts/clear_quest_tables.ts

# Reset all games
npx tsx scripts/reset_all_games.ts
```

---

## Prerequisites
- Android emulator (Pixel_5) running: `~/Library/Android/sdk/emulator/emulator -avd Pixel_5 &`
- API server running: `cd /Users/joakimachren/Desktop/togetherremind/api && npm run dev`

## Test Users
- **Android:** TestiY (`e2ecabb7-43ee-422c-b49c-f0636d57e6d2`)
- **Chrome:** Jokke (`634e2af3-1625-4532-89c0-2d0900a2690a`)
- **Couple ID:** `11111111-1111-1111-1111-111111111111`

## Tips
- **Hot reload works** if apps are already running - press `r` in terminal
- **Only reset games** when testing game completion flows
- **Only full clean** when debugging quest sync or seeing stale data

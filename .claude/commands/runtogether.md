---
description: Launch Alice (Android) and Bob (Chrome) for local couple testing
---

Complete clean testing procedure with dev auth bypass and real Supabase data. Optimized parallel builds, clean storage, then launch both devices with actual database content.

**🔧 Dev Auth Bypass Active:**
- ✅ Skips email/OTP authentication
- ✅ Loads real user data from Supabase
- ✅ Uses actual couple relationship from database
- ✅ Firebase RTDB only for quest/session sync (not user data)

**Optimized steps:**
1. Kill existing Flutter processes: `pkill -9 -f "flutter"`
2. Start builds in parallel (background):
   - `cd /Users/joakimachren/Desktop/togetherremind/app`
   - `flutter build apk --debug > /tmp/android_build.log 2>&1 &` (capture PID)
   - `flutter build web --debug > /tmp/web_build.log 2>&1 &` (capture PID)
3. While builds run, do cleanup in parallel:
   - Uninstall Android app: `~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind`
   - Clear Chrome storage: Close Chrome completely (or clear via DevTools)
   - Clean Firebase RTDB (sync data only): `cd /Users/joakimachren/Desktop/togetherremind`
     - `firebase database:remove /daily_quests --force`
     - `firebase database:remove /quiz_sessions --force`
     - `firebase database:remove /lp_awards --force`
     - `firebase database:remove /quiz_progression --force`
   - Clean Supabase tables (quest sync data): `cd /Users/joakimachren/Desktop/togetherremind/api && npx tsx scripts/clear_quest_tables.ts`
4. Wait for both builds to complete (check PIDs or tail logs)
5. Launch Android (User 1 - `c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28`):
   - `cd /Users/joakimachren/Desktop/togetherremind/app`
   - `flutter run -d emulator-5554 > /tmp/android_run.log 2>&1 &`
   - Loads real user data from Supabase via `/api/dev/user-data`
   - Generates fresh daily quests
6. Launch Chrome (User 2 - `d71425a3-a92f-404e-bfbe-a54c4cb58b6a`):
   - Wait 3 seconds for Android to generate quests
   - `sleep 3 && flutter run -d chrome > /tmp/chrome_run.log 2>&1 &`
   - Loads real user data from Supabase via `/api/dev/user-data`
   - Loads quests from Firebase RTDB

**Prerequisites:**
- Android emulator (Pixel_5) must be running
- API server must be running (`npm run dev` in `/api` directory)
- Supabase configured with `couples` table and user records

**Data Flow:**
1. **User/Couple Data:** Loaded from Supabase Postgres (via `/api/dev/user-data`)
2. **Quest Sync:** Dual-write to both Firebase RTDB and Supabase Postgres (first device generates, second loads)
3. **Local Storage:** Hive (cached after initial load)

**Why this procedure:**
- Parallel builds save ~10-15 seconds
- Uninstalling app removes old local data
- Cleaning Firebase & Supabase ensures fresh quest generation (no foreign key conflicts)
- Real database content for realistic testing
- No email auth interruption during development

**Monitoring:**
- Android logs: `tail -f /tmp/android_run.log`
- Chrome logs: `tail -f /tmp/chrome_run.log`
- Look for: "🔧 [DEV] Loading real user data from Supabase..."

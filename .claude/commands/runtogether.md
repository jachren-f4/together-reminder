---
description: Launch Alice (Android) and Bob (Chrome) for local couple testing
---

Complete clean testing procedure with optimized parallel builds: Kill existing processes, build Android and Web in parallel, clean up storage and Firebase while builds run, wait for builds to complete, then launch both devices.

**Optimized steps:**
1. Kill existing Flutter processes: `pkill -9 -f "flutter"`
2. Start builds in parallel (background):
   - `cd /Users/joakimachren/Desktop/togetherremind/app`
   - `flutter build apk --debug &` (capture PID)
   - `flutter build web --debug &` (capture PID)
3. While builds run, do cleanup in parallel:
   - Uninstall Android app: `~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind`
   - Clean Firebase RTDB: `cd /Users/joakimachren/Desktop/togetherremind`
     - `firebase database:remove /daily_quests --force`
     - `firebase database:remove /quiz_sessions --force`
     - `firebase database:remove /lp_awards --force`
     - `firebase database:remove /quiz_progression --force`
4. Wait for both builds to complete (check PIDs)
5. Launch Alice (Android) - generates fresh quests:
   - `cd /Users/joakimachren/Desktop/togetherremind/app`
   - `flutter run -d emulator-5554 &`
6. Launch Bob (Chrome) - loads from Firebase:
   - `flutter run -d chrome &`

Both devices will have deterministic user IDs and will share the same couple ID for testing.

**Prerequisites:**
- Android emulator (Pixel_5) must be running before executing this command
- For cleanest testing, manually clear Chrome storage: F12 → Application tab → Storage → Clear site data

**Why this procedure:**
- Parallel builds save ~10-15 seconds (builds run while cleanup happens)
- Killing Flutter processes first prevents interference with new builds
- Uninstalling app removes all local Hive storage for fresh initialization
- Cleaning Firebase ensures first device (Alice) generates fresh quests that second device (Bob) can load
- Waiting for builds ensures clean, fresh artifacts before launching

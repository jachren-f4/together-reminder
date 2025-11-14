# TogetherRemind - Technical Development Guide

**AI Assistant Reference for Development**

---

## Table of Contents

1. [Stack Overview](#stack-overview)
2. [Critical Architecture Rules](#critical-architecture-rules)
3. [Testing & Debugging](#testing--debugging)
4. [File Locations Reference](#file-locations-reference)
5. [Additional Documentation](#additional-documentation)

---

## Stack Overview

| Layer | Technology |
|-------|------------|
| **Frontend** | Flutter 3.16+, Dart 3.2+, Material Design 3 |
| **Backend** | Firebase Cloud Functions (Node.js 20) |
| **Storage** | Hive (local NoSQL) |
| **Notifications** | FCM (Android), APNs (iOS) |
| **Auth** | None (device pairing only) |

### Bundle IDs
- **iOS:** `com.togetherremind.togetherremind2` (changed 2025-11-13 after security remediation)
- **Android:** `com.togetherremind.togetherremind` (original, not yet migrated)

---

## Critical Architecture Rules

### 1. Initialization Order (MUST FOLLOW)

```dart
// main.dart - STRICT ORDER REQUIRED
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);  // 1. Firebase FIRST
  await StorageService.init();                                                     // 2. Hive Storage
  await NotificationService.initialize();                                          // 3. NotificationService
  await MockDataService.injectMockDataIfNeeded();                                 // 4. Mock data (optional)

  runApp(const TogetherRemindApp());                                              // 5. Run app
}
```

### 2. Hive Data Migration

**CRITICAL:** Always use `defaultValue` when adding fields to existing HiveTypes:

```dart
// ✅ CORRECT - prevents "type 'Null' is not a subtype" crashes
@HiveField(10, defaultValue: 'reminder')
String category;

// ❌ WRONG - crashes on existing data
@HiveField(10)
late String category;
```

After adding fields:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Web Platform Safety

| Rule | Description |
|------|-------------|
| ✅ DO | Use `NotificationService.getToken()` for FCM tokens |
| ❌ DON'T | Call `FirebaseMessaging.instance.getToken()` directly |
| ⚠️ NOTE | Web platform doesn't support FCM service workers in Flutter debug → blank screen crash |
| ⚠️ NOTE | `NotificationService.initialize()` skips FCM setup on web (by design) |
| ⚠️ NOTE | `DevConfig.emulatorId` returns `'web-bob'` for web platform |

### 4. Cloud Function Signature (v2 API)

Firebase Functions v6+ requires `(request)` signature:

```javascript
// ✅ CORRECT (v2)
exports.myFunction = functions.https.onCall(async (request) => {
  const { param1, param2 } = request.data;
});

// ❌ WRONG (v1 - causes "parameter is required" errors)
exports.myFunction = functions.https.onCall(async (data, context) => {
  const { param1, param2 } = data;
});
```

### 5. Device Detection

Detection is async with caching - MUST await:

```dart
// Async with proper detection
final isSimulator = await DevConfig.isSimulator;

// Sync cached check (returns false if not yet determined)
final isSim = DevConfig.isSimulatorSync;
```

### 6. Firebase Credentials (SECURITY CRITICAL)

**NEVER COMMIT:**
```
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
.env
functions/.env
functions/serviceAccountKey.json
```

**Why:**
- Contains API keys and project identifiers
- Enables unauthorized Firebase access
- Can lead to billing fraud, data breaches, service abuse
- Firebase security rules don't protect against valid credentials

**If accidentally committed:**
1. Remove from history (use BFG Repo-Cleaner or git-filter-repo)
2. Rotate ALL Firebase credentials in Console
3. Regenerate and download new config files
4. Update .gitignore and recommit

**Before every commit:**
```bash
git status  # Verify no sensitive files staged
git diff    # Review all changes
```

### 7. Firebase RTDB Paths & Permissions

All paths require security rules in `database.rules.json`:

| Path | Purpose |
|------|---------|
| `/pairing_codes/{code}` | Remote pairing (write-once) |
| `/dev_emulators/{emulatorId}` | Dev FCM tokens (dev mode only) |
| `/daily_quests/{coupleId}/{dateKey}` | Quest sync between partners |
| `/quiz_progression/{coupleId}` | Quiz progression state |
| `/quiz_sessions/{emulatorId}/{sessionId}` | Quiz data for partner access |

**Deploy rules:** `firebase deploy --only database`

**Common error:** "Quiz session not found" → Missing `/quiz_sessions/` rules

### 8. Love Points UI Updates

**CRITICAL:** LP counter does NOT auto-update when LP is awarded.

**Design rationale:**
- Avoids ValueListenableBuilder complexity across screens
- Notification banner provides immediate feedback (3-sec overlay: "+30 LP 💰")
- Counter updates on next screen rebuild (navigation, app restart)

**Implementation requirements:**
- `LovePointService.setAppContext()` must be called in `main.dart` via `addPostFrameCallback`
- See `love_point_service.dart:280-288` for notification trigger

**Related files:**
- `lib/services/love_point_service.dart`
- `lib/widgets/foreground_notification_banner.dart`
- `lib/widgets/daily_quests_widget.dart:86-102`

---

## Testing & Debugging

### Complete Clean Testing Procedure

Use when testing quest sync, Firebase RTDB sync, Love Point awards, or cross-device synchronization.

#### Quick Reference

```bash
# 1. Uninstall Android app (clears Hive local storage)
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind2

# 2. Kill Flutter processes
pkill -9 -f "flutter"

# 3. Clean Firebase RTDB
cd /Users/joakimachren/Desktop/togetherremind
firebase database:remove /daily_quests --force
firebase database:remove /quiz_sessions --force
firebase database:remove /lp_awards --force
firebase database:remove /quiz_progression --force

# 4. Launch Alice (Android) - generates fresh quests
cd /Users/joakimachren/Desktop/togetherremind/app
flutter run -d emulator-5554 &

# 5. Wait 10 seconds, then launch Bob (Chrome) - loads from Firebase
sleep 10 && flutter run -d chrome &
```

#### Detailed Steps

**Step 1: Uninstall Android App**
```bash
# Try new Bundle ID first
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind2

# If DELETE_FAILED_INTERNAL_ERROR, check what's installed
~/Library/Android/sdk/platform-tools/adb shell pm list packages | grep togetherremind
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind
```
- **Why:** Removes app and local Hive storage, ensuring fresh initialization
- **Note:** MUST use full path `~/Library/Android/sdk/platform-tools/adb` (not in PATH)

**Step 2: Kill Flutter Processes & Clear Chrome Storage**
```bash
pkill -9 -f "flutter"

# Clear Chrome manually in DevTools:
# F12 → Application tab → Storage → Clear site data
# OR: Close Chrome entirely and restart
```
- **Why:** Ensures no old processes interfere; Chrome starts with clean storage

**Step 3: Clean Build Artifacts** (Optional)
```bash
cd /Users/joakimachren/Desktop/togetherremind/app
flutter clean
```
- **Why:** Rebuilds from scratch for major code changes
- **When:** Skip for quick tests

**Step 4: Clean Firebase RTDB**
```bash
cd /Users/joakimachren/Desktop/togetherremind
firebase database:remove /daily_quests --force
firebase database:remove /quiz_sessions --force
firebase database:remove /lp_awards --force
firebase database:remove /quiz_progression --force
```
- **Why:** First device generates fresh quests, preventing ID mismatches
- **Note:** `--force` bypasses confirmation prompts

**Step 5: Launch Alice (Android Emulator)**
```bash
cd /Users/joakimachren/Desktop/togetherremind/app
flutter run -d emulator-5554 &
```
- **Why:** First device generates fresh daily quests and writes to Firebase
- **Wait:** Look for "✅ Daily quests generated: 3 quests" in console

**Step 6: Launch Bob (Chrome)**
```bash
sleep 10  # Wait for Alice initialization
cd /Users/joakimachren/Desktop/togetherremind/app
flutter run -d chrome &
```
- **Why:** Second device loads quests from Firebase with matching IDs

### Why Complete Clean Testing Matters

- Prevents stale data from interfering with results
- Eliminates Hive storage issues (fresh install)
- Ensures clean Firebase state (first device generates, second loads)
- Validates proper initialization sequence
- Reproduces real user experience of clean launches and first-time pairing

### Debugging Tools

#### In-App Debug Menu

**Access:** Double-tap greeting text ("Good morning" / "Good afternoon")

**Features:**
- View Firebase RTDB data for current couple's daily quests
- View local Hive storage quest data
- Copy to clipboard for sharing
- **"Clear Local Storage & Reload"** button - Clears ONLY Hive boxes (local data), NOT Firebase

⚠️ **IMPORTANT:** Debug button does NOT clear Firebase - use external script

#### Helper Scripts (in `/tmp/`)

| Script | Purpose |
|--------|---------|
| `clear_firebase.sh` | **DELETE ALL** Firebase RTDB data (use BEFORE launching fresh apps) |
| `debug_firebase.sh` | Inspect current Firebase RTDB data |
| `verify_quiz_sync.sh` | Verify quest contentIds match sessions in Firebase |

### Data Clearing Separation

**Why this matters:** One device clearing Firebase deletes shared data, causing quest ID mismatches.

| Tool | Clears | Purpose | Safe for Partner? |
|------|--------|---------|-------------------|
| **In-App Debug Menu** | Hive boxes (local) | Reset individual device state | ✅ Yes |
| **External Script** | Firebase RTDB paths | Clean slate for both devices | ❌ No (run BEFORE both apps) |

**Usage Pattern:**
1. Run external script to clear Firebase
2. Launch both apps fresh
3. Use in-app debug menu to reset individual device state as needed

---

## File Locations Reference

### Core Services

| File | Purpose |
|------|---------|
| `lib/services/storage_service.dart` | Hive box management |
| `lib/services/notification_service.dart` | FCM + local notifications |
| `lib/services/reminder_service.dart` | Send/receive reminders |
| `lib/services/remote_pairing_service.dart` | Remote code pairing logic |
| `lib/services/poke_service.dart` | Poke logic, rate limiting (30s), mutual detection (2min) |
| `lib/services/poke_animation_service.dart` | Lottie animations + haptic |
| `lib/services/quiz_service.dart` | Quiz logic, question rotation, scoring |
| `lib/services/word_ladder_service.dart` | Word ladder game logic |
| `lib/services/memory_flip_service.dart` | Memory Flip game logic |
| `lib/services/love_point_service.dart` | Love Points tracking and rewards |

### Configuration

| File | Purpose |
|------|---------|
| `lib/config/dev_config.dart` | Mock data control, simulator detection |
| `lib/firebase_options.dart` | Auto-generated Firebase config |
| `functions/index.js` | Cloud Functions (sendReminder, sendPoke, etc.) |
| `database.rules.json` | RTDB security rules |

### UI Screens

| File | Purpose |
|------|---------|
| `lib/screens/home_screen.dart` | Main screen with FAB |
| `lib/screens/pairing_screen.dart` | Tabbed pairing (QR + Remote code) |
| `lib/screens/inbox_screen.dart` | Poke filter tab + card display |
| `lib/screens/activities_screen.dart` | Activities hub with game cards |
| `lib/screens/quiz_intro_screen.dart` | Classic quiz intro |
| `lib/screens/quiz_screen.dart` | Classic quiz gameplay |
| `lib/screens/speed_round_intro_screen.dart` | Speed round intro |
| `lib/screens/speed_round_screen.dart` | Speed round gameplay |
| `lib/screens/word_ladder_game_screen.dart` | Word ladder gameplay |
| `lib/screens/memory_flip_game_screen.dart` | Memory Flip 4×4 card grid |

### UI Components

| File | Purpose |
|------|---------|
| `lib/widgets/poke_bottom_sheet.dart` | Send poke modal |
| `lib/widgets/poke_response_dialog.dart` | Receive poke dialog |
| `lib/widgets/match_reveal_dialog.dart` | Memory Flip match celebration |
| `lib/widgets/foreground_notification_banner.dart` | In-app notification banner |

### Models

| File | Purpose |
|------|---------|
| `lib/models/reminder.dart` | Hive models (Reminder, Partner, User) |
| `lib/models/pairing_code.dart` | PairingCode model with expiration tracking |
| `lib/models/quiz.dart` | Quiz models (QuizSession, QuizAnswer, QuizQuestion) |
| `lib/models/word_ladder.dart` | Word ladder models (WordLadderSession, WordGuess) |
| `lib/models/memory_flip.dart` | Memory Flip models (MemoryPuzzle, MemoryCard) |
| `lib/models/love_point.dart` | Love Points models (LovePointTransaction) |

---

## Additional Documentation

| Document | Contents |
|----------|----------|
| **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** | Data models, push notification flow, device pairing architecture, feature specifications |
| **[docs/SETUP.md](docs/SETUP.md)** | Firebase configuration, development setup, two-device testing, deployment |
| **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** | Common issues, debugging strategies, error handling patterns, Chrome testing best practices |

---

## Resources

- [Flutter Docs](https://docs.flutter.dev/)
- [Firebase Flutter](https://firebase.flutter.dev/)
- [Hive Docs](https://docs.hivedb.dev/)
- [pub.dev](https://pub.dev/)

---

**Last Updated:** 2025-11-14 (Refactored for improved organization and readability)

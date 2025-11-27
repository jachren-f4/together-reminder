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

### White-Label Architecture

The app supports multiple branded versions via Flutter flavors:

| Brand | Android Bundle ID | iOS Bundle ID | Dart Define |
|-------|-------------------|---------------|-------------|
| TogetherRemind | `com.togetherremind.togetherremind` | `com.togetherremind.togetherremind2` | `BRAND=togetherRemind` |
| HolyCouples | `com.togetherremind.holycouples` | `com.togetherremind.holycouples` | `BRAND=holyCouples` |

**Key files:**
- `lib/config/brand/brand_config.dart` - Brand enum and config class
- `lib/config/brand/brand_registry.dart` - All brand configurations
- `lib/config/brand/brand_loader.dart` - Runtime brand loading
- `assets/brands/{brandId}/` - Brand-specific content

**Build commands:**
```bash
# TogetherRemind
flutter run --flavor togetherremind --dart-define=BRAND=togetherRemind

# HolyCouples
flutter run --flavor holycouples --dart-define=BRAND=holyCouples

# Web (any brand)
flutter run -d chrome --dart-define=BRAND=holyCouples
```

**Validation:**
```bash
./scripts/validate_brand_assets.sh  # Validate all brands
```

**Database Strategy:**
- **Development:** Single shared Supabase with `brand_id` column filtering
- **Production:** Separate Supabase project per brand (when launched)
- **Migration:** `api/supabase/migrations/014_white_label_brand_id.sql`
- **Apply:** `cd api && supabase db push`
- API queries must filter: `WHERE brand_id = 'holycouples'`

See `docs/WHITE_LABEL_GUIDE.md` for complete brand creation guide.

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

**Flutter Web Asset Rebuilds:**
- Adding new files to `assets/` subdirectories requires `flutter clean && flutter run` - hot restart does NOT rebuild the asset bundle
- If image shows 404 with path like `assets/assets/brands/.../image.png`, the file exists in source but isn't in the build output
- Always run full rebuild after adding new images to `assets/brands/{brand}/images/`

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

**CRITICAL:** LP counter auto-updates in real-time when LP is awarded (matches quest card behavior).

**Design rationale:**
- Uses callback pattern for real-time UI updates (consistent with quest cards)
- Notification banner provides immediate feedback (3-sec overlay: "+30 LP 💰")
- LP counter updates immediately via `setState()` callback

**Implementation pattern:**
```dart
// In NewHomeScreen.initState() or similar screens
// IMPORTANT: Do NOT call startListeningForLPAwards() again - that creates duplicate listeners!
// The listener is already started in main.dart, just register the callback:
LovePointService.setLPChangeCallback(() {
  if (mounted) {
    setState(() {
      // Trigger rebuild to update LP counter
    });
  }
});
```

**Flow:**
1. Partner awards LP → Firebase RTDB update
2. `LovePointService._handleLPAward()` receives update
3. Updates local Hive storage
4. Shows notification banner ("+30 LP 💰")
5. Calls `_onLPChanged` callback
6. Screen's `setState()` triggers rebuild
7. LP counter displays new value immediately

**Implementation requirements:**
- `LovePointService.setAppContext()` must be called in `main.dart` via `addPostFrameCallback`
- Firebase listener is started ONCE in `main.dart` via `startListeningForLPAwards()`
- Individual screens register callbacks via `setLPChangeCallback()` (do NOT call startListeningForLPAwards again!)
- Callback is optional (backward compatible for screens that don't need real-time updates)

**CRITICAL WARNING:**
- Do NOT call `startListeningForLPAwards()` multiple times - it creates duplicate Firebase listeners
- Each duplicate listener awards LP again, causing the 60 LP bug (30 LP × 2 listeners = 60 LP)
- Always use `setLPChangeCallback()` in screens to register UI update callbacks

**Related files:**
- `lib/services/love_point_service.dart:19-20` - Callback variable declaration
- `lib/services/love_point_service.dart:194-199` - setLPChangeCallback() method (use this in screens!)
- `lib/services/love_point_service.dart:239-265` - startListeningForLPAwards() (called once in main.dart)
- `lib/services/love_point_service.dart:313` - Callback invocation after LP award
- `lib/main.dart:133-136` - Listener initialization (called once on app start)
- `lib/screens/new_home_screen.dart:60-70` - Reference implementation using setLPChangeCallback()
- `lib/widgets/foreground_notification_banner.dart` - Notification overlay
- `lib/widgets/daily_quests_widget.dart:86-102` - Quest card pattern (similar architecture)

### 9. Quest Title Display Rules

**CRITICAL:** Quest title display must use denormalized metadata, NOT session lookups.

**Why this matters:**
- Alice creates daily quests → writes to Firebase → has local sessions
- Bob loads quests from Firebase → has quests but NO local sessions
- Session lookup fails on Bob's device → displays wrong titles

**Design pattern:**
```dart
// ❌ WRONG - session lookup fails on partner's device
final session = StorageService().getQuizSession(quest.contentId);
if (session != null && session.formatType == 'affirmation') {
  return session.quizName!;
}

// ✅ CORRECT - uses Firebase-synced metadata
if (quest.formatType == 'affirmation') {
  return quest.quizName ?? 'Affirmation Quiz';
}
```

**Affected components:**
- `lib/widgets/quest_card.dart` - Main screen quest titles
- `lib/services/activity_service.dart` - Inbox quest titles
- `lib/widgets/daily_quests_widget.dart` - Format type detection

**Data flow:**
1. Alice: QuizSession created → `formatType`, `quizName` extracted
2. Alice: DailyQuest created with metadata from session
3. Alice: Quest synced to Firebase with `formatType`, `quizName`
4. Bob: Quest loaded from Firebase with all metadata intact
5. Bob: UI uses `quest.formatType` and `quest.quizName` directly

See `docs/QUEST_TITLE_SYNC_ISSUE.md` for full technical analysis.

### 10. Logger Service Verbosity Control

**CRITICAL:** All Logger services are **disabled by default** to prevent log flooding.

**Philosophy:**
- Clean logs by default (only errors shown)
- Enable specific services only when debugging that feature
- Prevents AI coding agent context window pollution

**Usage:**
```dart
import '../utils/logger.dart';

Logger.debug('Processing data', service: 'quiz');      // Only in debug mode
Logger.info('User logged in', service: 'auth');        // Only in debug mode
Logger.warn('Slow network', service: 'network');       // Only in debug mode
Logger.error('Failed to load', error: e, service: 'quiz');  // Always logs
Logger.success('Quest completed', service: 'quest');   // Only in debug mode
```

**How to enable logging for a service:**
1. Edit `lib/utils/logger.dart`
2. Find service in `_serviceVerbosity` map (organized by category)
3. Change `false` → `true`
4. Run debug build - only that service's logs appear

**Service Categories:**
```dart
// CRITICAL CORE (3): storage, notification, lovepoint
// MAJOR FEATURES (3): quiz, you_or_me, pairing
// MINOR FEATURES (8): reminder, poke, daily_pulse, affirmation,
//                      memory_flip, word_ladder, ladder, quest
// INFRASTRUCTURE (5): debug, mock, word_validation, home, arena
```

**GOTCHA:** Logger calls **without** `service:` parameter bypass verbosity control and always log.
```dart
Logger.debug('message');  // ❌ Always logs
Logger.debug('message', service: 'quiz');  // ✅ Respects config
```

**Benefits:**
- Debug builds: ~4 log lines instead of hundreds
- Production: Only errors log
- Easy to debug specific features without noise

**Related files:**
- `lib/utils/logger.dart` - Logger implementation and service config

### 11. Development Auth Bypass

**CRITICAL:** Dev auth bypass allows development without email/OTP authentication while using real Supabase data.

**When to use:**
- Two-device testing (Android + Chrome)
- Rapid iteration without authentication interruption
- Testing with actual database content

**Architecture:**
- **Two-layer bypass:** API-side (`AUTH_DEV_BYPASS_ENABLED=true`) + Flutter-side (`skipAuthInDev=true`)
- **Real data loading:** Fetches user/couple data from Supabase Postgres via `/api/dev/user-data`
- **Per-device user IDs:** Each device (Android/Chrome) gets its own user ID from `DevConfig`
- **Quest sync:** Firebase RTDB for real-time synchronization between devices

**Configuration:**

1. **API Environment** (`/api/.env.local`):
```bash
AUTH_DEV_BYPASS_ENABLED=true
NODE_ENV=development
```

2. **Flutter Config** (`lib/config/dev_config.dart`):
```dart
static const bool skipAuthInDev = true;  // Bypass email auth
static const String devUserIdAndroid = 'c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28';
static const String devUserIdWeb = 'd71425a3-a92f-404e-bfbe-a54c4cb58b6a';
```

3. **Supabase Database:**
- Must have existing `couples` table with user1_id and user2_id matching dev config
- Users must exist in Supabase Auth with metadata (full_name, avatar_emoji)

**Data Flow:**
1. **User/Couple Data:** Loaded from Supabase Postgres via `/api/dev/user-data?userId=<uuid>`
2. **Quest Sync:** Firebase RTDB (first device generates, second device loads)
3. **Local Storage:** Hive (cached after initial load)
4. **FCM Tokens:** Real tokens per device for notifications

**How it works:**
1. App startup detects `kDebugMode && skipAuthInDev`
2. `DevDataService.loadRealDataIfNeeded()` calls API with dev user ID
3. API returns user + partner + couple data from Supabase
4. App stores data in Hive and proceeds to home screen
5. No email/OTP prompt - seamless development experience

**Quick Start:**
```bash
/runtogether  # Launches both devices with clean state
```

**Related files:**
- `lib/services/dev_data_service.dart` - Fetches real user data from Supabase
- `api/app/api/dev/user-data/route.ts` - Development endpoint (secured by env vars)
- `lib/config/dev_config.dart` - Dev user ID configuration
- `lib/services/auth_service.dart` - Injects X-Dev-User-Id header
- `.claude/commands/runtogether.md` - Complete testing workflow

**Security:**
- Only active when `NODE_ENV=development` AND `AUTH_DEV_BYPASS_ENABLED=true`
- API endpoint returns 403 in production
- Never commit `.env.local` files

### 12. Turn-Based Game "Who Goes First" Preference

**CRITICAL:** For FUTURE features only. Do NOT retrofit to existing games (Memory Flip, etc.).

**Implementation pattern:**
```dart
// In new turn-based game initialization
final firstPlayerId = await CouplePreferencesService().getFirstPlayerId();
puzzle.currentPlayerId = firstPlayerId;  // Start with preferred player
```

**Storage layers:**
- Supabase: `couples.first_player_id` (authoritative, nullable)
- Firebase RTDB: `/couple_preferences/{coupleId}` (real-time sync)
- Hive: `app_metadata` box (keys: `first_player_id`, `couple_id`)

**Listener initialization:**
- Called ONCE in `main.dart:165` after user/partner check
- Do NOT call `startListening()` multiple times
- Pattern: Same as `LovePointService.startListeningForLPAwards()`

**Default behavior:**
- NULL in database → returns `user2_id` at runtime (latest joiner)
- No DB write until user explicitly changes preference

**Files:**
- Service: `lib/services/couple_preferences_service.dart`
- API: `api/app/api/sync/couple-preferences/route.ts`
- UI: `lib/screens/settings_screen.dart:286-337` (GAME PREFERENCES section)
- Migration: `api/supabase/migrations/010_first_player_preference.sql`

### 13. Linked Game Clue Cell Rendering

**CRITICAL:** Clue cells are rendered inline in `linked_game_screen.dart:468`, NOT in `clue_cell.dart`.

**Font sizing logic (in `_buildClueCell`):**
- Emoji: `fontSize: 28`
- Text ≤4 chars: `fontSize: 16`
- Text ≤8 chars: `fontSize: 12`
- Text ≤12 chars or has space: `fontSize: 9`
- Longer text: `fontSize: 7`

**Files:**
- Actual renderer: `lib/screens/linked_game_screen.dart:468-526`
- Unused widget: `lib/widgets/linked/clue_cell.dart` (kept for potential future use)

### 14. Linked Game Answer Cell Colors

**CRITICAL:** Answer cell colors are defined INLINE in `linked_game_screen.dart:749-775`, NOT in `answer_cell.dart`.

**The Problem:** The grid container uses a dark background (`textPrimary`) for grid lines. If cell colors use `withOpacity()`, the dark background bleeds through the transparency.

**The Fix:** Use `Color.alphaBlend()` to create **solid, opaque** colors:

```dart
// lib/screens/linked_game_screen.dart - _buildAnswerCell()
// ❌ WRONG - transparent, dark background shows through
bgColor = BrandLoader().colors.warning.withOpacity(0.2);

// ✅ CORRECT - solid color, no bleed-through
final surface = BrandLoader().colors.surface;
bgColor = Color.alphaBlend(BrandLoader().colors.warning.withOpacity(0.2), surface);
```

**Current color definitions (lines 749-775):**
```dart
final surface = BrandLoader().colors.surface;
switch (state) {
  case AnswerCellState.empty:
    bgColor = surface;  // Pure white
  case AnswerCellState.draft:
    bgColor = Color.alphaBlend(BrandLoader().colors.warning.withOpacity(0.2), surface);  // Light yellow
  case AnswerCellState.locked:
    bgColor = Color.alphaBlend(BrandLoader().colors.success.withOpacity(0.15), surface); // Light green
  case AnswerCellState.incorrect:
    bgColor = Color.alphaBlend(BrandLoader().colors.error.withOpacity(0.7), surface);    // Red
}
```

**Files:**
- Actual colors: `lib/screens/linked_game_screen.dart:749-775` (`_buildAnswerCell()` method)
- Unused widget: `lib/widgets/linked/answer_cell.dart` (imported but NOT used by the screen)

**Why the grid needs dark background:**
- Line 319: `Container(color: BrandLoader().colors.textPrimary)` creates grid lines
- GridView has 2px spacing between cells, dark container shows through gaps
- This is intentional for grid lines, but cells must be OPAQUE to cover it

### 15. Daily Quest Generation Structure

**CRITICAL:** Daily quests generate exactly 3 quests per day (not 4).

**Quest mix:**
- Slot 0: Classic quiz (uses even track positions: 0, 2)
- Slot 1: Affirmation quiz (uses odd track positions: 1, 3)
- Slot 2: You or Me (separate branch progression)

**Position advancement:** Advances once per day (after classic quiz), not per-quiz.

**File:** `lib/services/quest_type_manager.dart:403-507`

### 16. Branch Manifest System

**Purpose:** Each content branch can have custom video (intro screen) and image (quest card).

**Key Files:**
- Service: `lib/services/branch_manifest_service.dart`
- Model: `lib/models/branch_manifest.dart`
- Manifests: `assets/brands/{brandId}/data/{activity}/{branch}/manifest.json`

**Fallback Chain (video):**
1. Manifest `videoPath` → 2. Activity default video → 3. Grayscale emoji

**Fallback Chain (image):**
1. Manifest `imagePath` → 2. Quest `imagePath` → 3. Type-based default

**Adding branch media:**
1. Add video/image to `assets/brands/{brandId}/videos/` or `images/quests/`
2. Update branch's `manifest.json` with paths
3. Register folder in `pubspec.yaml`
4. Run `flutter clean && flutter run`

See `docs/BRANCH_MANIFEST_GUIDE.md` for complete guide.

### 17. Auth Service State vs Token Checks

**CRITICAL:** Never use synchronous `_authService.isAuthenticated` for auth gating in async flows.

**Why:** `isAuthenticated` reads from `_authState` which updates asynchronously after OTP verification. This causes race conditions when navigating between screens.

```dart
// ❌ WRONG - race condition after account creation
if (!_authService.isAuthenticated) {
  throw Exception('Not authenticated');
}

// ✅ CORRECT - reads from persisted storage
final token = await _authService.getAccessToken();
if (token == null) {
  throw Exception('Not authenticated');
}
```

**Affected file:** `lib/services/couple_pairing_service.dart` (fixed 2025-11-27)

### 18. Leaderboard System

**Key constraint:** Both users in a couple have **identical LP** (shared pool). The trigger uses `NEW.total_points` directly - never sum both users' LP.

**Trigger debugging:** If leaderboard doesn't update when LP changes:
1. Verify user is in `couples` table (most common issue)
2. Check trigger exists: `SELECT tgname FROM pg_trigger WHERE tgrelid = 'user_love_points'::regclass;`
3. Test with hardcoded couple_id to isolate issue

**Files:**
- Migration: `api/supabase/migrations/016_leaderboard.sql`
- API: `api/app/api/leaderboard/route.ts`, `api/app/api/user/country/route.ts`
- Full guide: `docs/LEADERBOARD_SYSTEM.md`

### 19. Animation & Sound System

**Services:**
- `lib/animations/animation_config.dart` - Timing constants, curves, scale factors
- `lib/services/haptic_service.dart` - `HapticService().trigger(HapticType.xxx)`
- `lib/services/sound_service.dart` - `SoundService().play(SoundId.xxx)`
- `lib/services/celebration_service.dart` - `CelebrationService.triggerConfetti(controller)`

**Available HapticTypes:** `light`, `medium`, `heavy`, `success`, `warning`, `selection`

**Available SoundIds:** `buttonTap`, `cardFlip`, `matchFound`, `wordFound`, `confettiBurst`, `toggleOn`, `toggleOff`

**Accessibility Pattern:**
```dart
// In StatefulWidget with animations:
bool _reduceMotion = false;

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  _reduceMotion = AnimationConfig.shouldReduceMotion(context);
}
// Then check _reduceMotion before running animations
```

**Settings Toggles:** Sound Effects and Haptic Feedback in Settings screen, stored via `StorageService`

---

## Testing & Debugging

### Complete Clean Testing Procedure

Use when testing quest sync, Firebase RTDB sync, Love Point awards, or cross-device synchronization.

#### Quick Reference (Optimized with Parallel Builds)

```bash
# 1. Kill existing Flutter processes
pkill -9 -f "flutter"

# 2. Start builds in parallel (background)
cd /Users/joakimachren/Desktop/togetherremind/app
flutter build apk --debug &
ANDROID_BUILD_PID=$!
flutter build web --debug &
WEB_BUILD_PID=$!

# 3. While builds run, do cleanup
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind

cd /Users/joakimachren/Desktop/togetherremind
firebase database:remove /daily_quests --force
firebase database:remove /quiz_sessions --force
firebase database:remove /lp_awards --force
firebase database:remove /quiz_progression --force

# 4. Wait for builds to complete
echo "⏳ Waiting for builds to complete..."
wait $ANDROID_BUILD_PID && echo "✅ Android build complete"
wait $WEB_BUILD_PID && echo "✅ Web build complete"

# 5. Launch Alice (Android) - generates fresh quests
cd /Users/joakimachren/Desktop/togetherremind/app
flutter run -d emulator-5554 &

# 6. Launch Bob (Chrome) - loads from Firebase
flutter run -d chrome &
```

#### Detailed Steps

**Step 1: Uninstall Android App**
```bash
# Try current Android Bundle ID first
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind

# If DELETE_FAILED_INTERNAL_ERROR, check what's installed
~/Library/Android/sdk/platform-tools/adb shell pm list packages | grep togetherremind
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind2
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

### Parallel Build Optimization

The optimized procedure runs builds in parallel with cleanup tasks:
- **Time savings:** ~10-15 seconds (builds run during cleanup)
- **Android build:** ~12-15 seconds (runs in background)
- **Web build:** ~15-18 seconds (runs in background)
- **Cleanup tasks:** ~5-8 seconds (uninstall + Firebase clear)
- **Result:** Builds complete by the time cleanup finishes, ready to launch immediately

### Debugging Tools

#### Version Number for Hot Reload Verification

**Purpose:** Visual confirmation that hot reload/rebuild is working correctly

**Location:** `lib/screens/new_home_screen.dart` - Bottom of screen (above bottom padding)

**Current Version:** `v1.0.3`

**Requirement:** Increment version number with each UI change to verify that changes are being reflected in the running app.

**Why this matters:**
- Hot reload doesn't work with background Flutter processes (started with `&`)
- Version number provides immediate visual feedback that rebuild succeeded
- Helps distinguish between "bug still exists" vs "rebuild didn't apply"

#### Enhanced Debug Menu

**Access:** Double-tap greeting text ("Good morning" / "Good afternoon")

**Features:**
- 5-tab interface (Overview, Quests, Sessions, LP & Sync, Actions)
- Firebase vs Local comparison with validation
- Copy to clipboard at page/section/card level
- Pull-to-refresh on Overview, Quests, Sessions, LP tabs
- Selective storage clearing (requires app restart)

⚠️ **IMPORTANT:**
- Old `debug_quest_dialog.dart` still exists but not used (can be removed)
- Clear storage does NOT clear Firebase - use external script

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

### Android Emulator Troubleshooting

**Problem:** Android emulator becomes unresponsive, Flutter run hangs
- **Symptoms:**
  - `flutter run -d emulator-5554` starts but never produces output
  - All `adb` commands hang indefinitely
  - Emulator appears running but doesn't respond to commands

**Root Causes:**
1. Frozen emulator process (adb can't communicate)
2. Multiple emulator instances with same AVD
3. Flutter startup lock conflicts

**Solution:**
```bash
# 1. Kill all emulator processes
pkill -9 -f "qemu-system-aarch64"

# 2. Start fresh emulator
~/Library/Android/sdk/emulator/emulator -avd Pixel_5 &

# 3. Wait for boot (10-15 seconds), verify connection
~/Library/Android/sdk/platform-tools/adb devices

# 4. If Flutter run still hangs, build and install APK manually:
flutter build apk --debug
~/Library/Android/sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-debug.apk
~/Library/Android/sdk/platform-tools/adb shell am start -n com.togetherremind.togetherremind/com.togetherremind.togetherremind.MainActivity
```

**Prevention:**
- Always kill old emulator processes before starting new ones
- Use `flutter run` without `&` for better error visibility
- Monitor emulator health with `adb devices` periodically

### API Testing Without Simulators

**Philosophy:** Test API endpoints directly with shell scripts instead of running full Flutter apps on simulators.

**Benefits:**
- Fast iteration (no simulator startup)
- Automated verification (CI-compatible)
- Clear pass/fail output
- Tests both users (Alice/Android, Bob/Chrome) in one run

**Available Scripts:**
```bash
# Test Memory Flip turn-based API
cd api && ./scripts/test_memory_flip_api.sh
```

**Script Location:** `api/scripts/test_memory_flip_api.sh`

**What it tests:**
1. API health check
2. Reset Memory Flip data
3. Create puzzle
4. Get puzzle state
5. Alice makes move
6. Bob makes move
7. Turn alternation
8. Game completion

**When to use:**
- After modifying API endpoints
- Before asking user to test on simulators
- During code review

**Prerequisites:**
- API server running (`cd api && npm run dev`)
- `AUTH_DEV_BYPASS_ENABLED=true` in `.env.local`

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
| `lib/services/affirmation_quiz_bank.dart` | Affirmation quiz loader (6 quizzes, 30 questions) |
| `lib/services/word_ladder_service.dart` | Word ladder game logic |
| `lib/services/memory_flip_service.dart` | Memory Flip game logic |
| `lib/services/love_point_service.dart` | Love Points tracking and rewards |
| `lib/services/leaderboard_service.dart` | Leaderboard API client (30s cache) |
| `lib/services/country_service.dart` | Country detection & flag emojis |

### Configuration

| File | Purpose |
|------|---------|
| `lib/config/dev_config.dart` | Mock data control, simulator detection |
| `lib/firebase_options.dart` | Auto-generated Firebase config |
| `lib/utils/logger.dart` | Centralized logging service (replaces print) |
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
| `lib/screens/affirmation_intro_screen.dart` | Affirmation quiz intro |
| `lib/screens/affirmation_question_screen.dart` | Affirmation quiz 5-point scale questions |
| `lib/screens/affirmation_results_screen.dart` | Affirmation quiz results with progress visualization |
| `lib/screens/speed_round_intro_screen.dart` | Speed round intro |
| `lib/screens/speed_round_screen.dart` | Speed round gameplay |
| `lib/screens/word_ladder_game_screen.dart` | Word ladder gameplay |
| `lib/screens/memory_flip_game_screen.dart` | Memory Flip 4×4 card grid |
| `lib/screens/linked_game_screen.dart` | Linked (arroword) puzzle gameplay |
| `lib/widgets/linked/answer_cell.dart` | **ACTUAL** answer cell colors (draft/locked/incorrect states) |
| `lib/widgets/linked/clue_cell.dart` | **UNUSED** - clues rendered inline in linked_game_screen.dart |

### UI Components

| File | Purpose |
|------|---------|
| `lib/widgets/poke_bottom_sheet.dart` | Send poke modal |
| `lib/widgets/poke_response_dialog.dart` | Receive poke dialog |
| `lib/widgets/match_reveal_dialog.dart` | Memory Flip match celebration |
| `lib/widgets/foreground_notification_banner.dart` | In-app notification banner |
| `lib/widgets/five_point_scale.dart` | 5-point Likert scale for affirmation quizzes |
| `lib/widgets/quest_card.dart` | Daily quest card (uses quest.quizName for display) |
| `lib/widgets/daily_quests_widget.dart` | Daily quests container (formatType detection) |
| `lib/widgets/leaderboard_bottom_sheet.dart` | Leaderboard ranking UI |

### Debug Menu

| File | Purpose |
|------|---------|
| `lib/widgets/debug/debug_menu.dart` | Main tab-based debug interface (5 tabs) |
| `lib/widgets/debug/tabs/overview_tab.dart` | System health, device info, storage stats |
| `lib/widgets/debug/tabs/quests_tab.dart` | Quest comparison, validation, detailed cards |
| `lib/widgets/debug/tabs/sessions_tab.dart` | Quiz session inspector with filters |
| `lib/widgets/debug/tabs/lp_sync_tab.dart` | LP transactions, Firebase sync monitoring |
| `lib/widgets/debug/tabs/actions_tab.dart` | Data cleanup, clipboard operations |
| `lib/widgets/debug/components/` | Shared components (copy button, section card, status indicator) |
| `lib/services/clipboard_service.dart` | Clipboard operations with user feedback |

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
| **[docs/QUEST_SYSTEM_V2.md](docs/QUEST_SYSTEM_V2.md)** | Quest system architecture, dual vs single session patterns, common pitfalls when adding new quest types, denormalization rules |
| **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** | Data models, push notification flow, device pairing architecture, feature specifications |
| **[docs/SETUP.md](docs/SETUP.md)** | Firebase configuration, development setup, two-device testing, deployment |
| **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** | Common issues, debugging strategies, error handling patterns, Chrome testing best practices |
| **[docs/FLUTTER_TESTING_GUIDE.md](docs/FLUTTER_TESTING_GUIDE.md)** | Headless testing without simulators, API integration tests, shell script tests, templates |
| **[docs/WHITE_LABEL_GUIDE.md](docs/WHITE_LABEL_GUIDE.md)** | Step-by-step brand creation, asset requirements, build commands, App Store submission |
| **[docs/BRANCH_MANIFEST_GUIDE.md](docs/BRANCH_MANIFEST_GUIDE.md)** | Branch-dependent videos/images, manifest.json format, fallback chains, adding new branches |
| **[docs/LEADERBOARD_SYSTEM.md](docs/LEADERBOARD_SYSTEM.md)** | Leaderboard triggers, debugging, test user setup |

---

## Resources

- [Flutter Docs](https://docs.flutter.dev/)
- [Firebase Flutter](https://firebase.flutter.dev/)
- [Hive Docs](https://docs.hivedb.dev/)
- [pub.dev](https://pub.dev/)

---

**Last Updated:** 2025-11-27 (Added Auth Service race condition fix - use getAccessToken() not isAuthenticated)

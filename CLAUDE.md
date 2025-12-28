# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Table of Contents

1. [Common Commands](#common-commands)
2. [Stack Overview](#stack-overview)
3. [Architecture Rules](#architecture-rules)
   - [Initialization & Storage](#initialization--storage)
   - [Sync & Data Flow](#sync--data-flow)
   - [Love Points System](#love-points-system)
   - [Game-Specific Rules](#game-specific-rules)
   - [UI Patterns](#ui-patterns)
   - [Security & Platform](#security--platform)
4. [Development Setup](#development-setup)
5. [Testing & Debugging](#testing--debugging)
6. [Documentation Practices](#documentation-practices)
7. [File Reference](#file-reference)

---

## Common Commands

### Flutter App (run from `app/` directory)

```bash
# Run on Android emulator (requires --flavor for Android)
flutter run -d emulator-5554 --flavor togetherremind --dart-define=BRAND=togetherRemind

# Run on iOS physical device (no --flavor, use --release)
flutter run -d 00008110-00011D4A340A401E --dart-define=BRAND=togetherRemind --release

# Run on Chrome (web)
flutter run -d chrome --dart-define=BRAND=togetherRemind

# Analyze code for errors
flutter analyze

# Run all unit tests
flutter test

# Run a single test file
flutter test test/unit/word_search_model_test.dart

# Run integration tests (requires running device)
flutter test integration_test/linked/normal_flow_test.dart

# Regenerate Hive adapters after model changes
flutter pub run build_runner build --delete-conflicting-outputs
```

### Next.js API (run from `api/` directory)

```bash
# Start development server
npm run dev

# Build for production
npm run build

# Lint code
npm run lint

# Run database scripts
npx tsx scripts/reset_couple_progress.ts
npx tsx scripts/wipe_all_accounts.ts

# Push database migrations
npm run db:push
```

### Quick Development Start

```bash
# Launch Android emulator + Chrome for couple testing
/runtogether
```

### Running iOS Simulator from Xcode

When `flutter run` fails for iOS simulator (common with Xcode beta versions), run directly from Xcode:

1. **Open workspace:** `open app/ios/Runner.xcworkspace`
2. **Select simulator** from device dropdown (e.g., iPhone 17 Pro)
3. **Click Play** (▶) to build and run

**IMPORTANT:** After `flutter clean`, you must run `pod install` before Xcode can build:
```bash
cd app/ios && pod install
```

If you get "Module 'xxx' not found" errors in Xcode, this is because:
- `flutter clean` deletes build folders and breaks pod linkage
- Xcode doesn't auto-run `pod install` like `flutter run` does

Full reset if pods are corrupted:
```bash
cd app/ios && rm -rf Pods Podfile.lock && pod install
```

### TestFlight Deployment (iOS)

```bash
cd /Users/joakimachren/Desktop/togetherremind/app

# 1. Build the IPA
flutter build ipa --release --dart-define=BRAND=togetherRemind

# 2. Ensure API key is in place
mkdir -p ~/.private_keys
cp keys/connect/AuthKey_54R6QHKMB4.p8 ~/.private_keys/

# 3. Upload to App Store Connect
xcrun altool --upload-app --type ios \
  -f build/ios/ipa/togetherremind.ipa \
  --apiKey 54R6QHKMB4 \
  --apiIssuer e43a1b2a-f0d3-4d40-af64-a987db2c850a
```

**After upload:**
1. Go to [App Store Connect](https://appstoreconnect.apple.com) → TogetherRemind → TestFlight
2. Wait 5-15 min for processing
3. Complete "Export Compliance" (select "None of the algorithms mentioned above")
4. Build becomes available to testers automatically

**Version bumping:** Edit `app/pubspec.yaml` line `version: 1.0.0+1`
- Format: `major.minor.patch+buildNumber`
- Increment build number for each TestFlight upload

**API Key Credentials:**
- API Key ID: `54R6QHKMB4`
- Issuer ID: `e43a1b2a-f0d3-4d40-af64-a987db2c850a`
- Key file: `keys/connect/AuthKey_54R6QHKMB4.p8` (also `~/.private_keys/AuthKey_54R6QHKMB4.p8`)

---

## Stack Overview

| Layer | Technology |
|-------|------------|
| **Frontend** | Flutter 3.16+, Dart 3.2+, Material Design 3 |
| **Backend** | Next.js API (Vercel) + Firebase Cloud Functions (Node.js 20) |
| **Database** | Supabase (Postgres) |
| **Storage** | Hive (local NoSQL) |
| **Notifications** | FCM (Android), APNs (iOS) |
| **Auth** | Supabase Auth (OTP) |

### URLs & Config
- **Production API:** `https://api-joakim-achrens-projects.vercel.app`
- **Supabase:** `https://naqzdqdncdzxpxbdysgq.supabase.co`
- **Config:** `lib/config/supabase_config.dart`

### Bundle IDs
- **iOS:** `com.togetherremind.togetherremind2`
- **Android:** `com.togetherremind.togetherremind`

### White-Label Architecture

| Brand | Android | iOS | Dart Define |
|-------|---------|-----|-------------|
| TogetherRemind | `com.togetherremind.togetherremind` | `com.togetherremind.togetherremind2` | `BRAND=togetherRemind` |
| HolyCouples | `com.togetherremind.holycouples` | `com.togetherremind.holycouples` | `BRAND=holyCouples` |

**Build:**
```bash
flutter run --flavor togetherremind --dart-define=BRAND=togetherRemind  # Android
flutter run -d chrome --dart-define=BRAND=holyCouples                    # Web
```

**Key files:** `lib/config/brand/brand_config.dart`, `brand_registry.dart`, `brand_loader.dart`

See `docs/WHITE_LABEL_GUIDE.md` for complete guide.

---

## Architecture Rules

### Initialization & Storage

#### Startup Order (MUST FOLLOW)
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);  // 1. Firebase
  await StorageService.init();                                                     // 2. Hive
  await NotificationService.initialize();                                          // 3. Notifications
  await MockDataService.injectMockDataIfNeeded();                                 // 4. Mock data
  runApp(const TogetherRemindApp());
}
```

#### Hive Field Migration
Always use `defaultValue` for new fields on existing HiveTypes:
```dart
// ✅ CORRECT
@HiveField(10, defaultValue: 'reminder')
String category;

// ❌ WRONG - crashes on existing data
@HiveField(10)
late String category;
```
After adding: `flutter pub run build_runner build --delete-conflicting-outputs`

#### Device Detection
```dart
final isSimulator = await DevConfig.isSimulator;  // Async, cached
final isSim = DevConfig.isSimulatorSync;          // Sync, may be stale
```

---

### Sync & Data Flow

All sync uses Supabase API with polling (Firebase RTDB removed 2024-12-01).

| Sync Type | Endpoint | Notes |
|-----------|----------|-------|
| Daily Quests | `GET/POST /api/sync/daily-quests` | First device creates, second loads |
| Quest Completion | `POST /api/sync/daily-quests/completion` | Mark complete |
| Love Points | `GET/POST /api/sync/love-points` | From `couples.total_lp` |
| Steps | `GET/POST /api/sync/steps` | HealthKit data |

**Polling:** Partner updates fetched every 30-60 seconds.

#### Quest Title Display
Use denormalized metadata, NOT session lookups (partner has no local sessions):
```dart
// ❌ Session lookup fails on partner's device
final session = StorageService().getQuizSession(quest.contentId);

// ✅ Use synced metadata
return quest.quizName ?? 'Affirmation Quiz';
```

#### Quest Completion Flow
1. User finishes quiz → API call → Hive updated → Navigate to waiting screen
2. Partner polling every 30s → Detects completion → Updates UI
3. RouteAware `didPopNext()` refreshes quest cards when returning home

**Files:** `lib/widgets/daily_quests_widget.dart` (RouteAware, polling)

#### Quest Initialization (CRITICAL)
Use `QuestInitializationService.ensureQuestsInitialized()` for all quest setup:

```dart
// ✅ CORRECT - Use centralized service
final initService = QuestInitializationService();
final result = await initService.ensureQuestsInitialized();
if (result.isSuccess) { /* navigate to home */ }

// ❌ WRONG - Direct sync service calls
await questSyncService.syncTodayQuests(...);  // Scattered, hard to track
```

**Called from exactly 2 places:**
| Location | Trigger | Purpose |
|----------|---------|---------|
| `PairingScreen._completeOnboarding()` | After successful pairing | Generate/sync quests for new couples |
| `HomeScreen._syncDailyQuestsIfNeeded()` | HomeScreen mount | Restore quests for returning users (app reinstall) |

**NOT called from:** `main.dart` (too early - User/Partner not restored yet)

**Server-side idempotency:** API uses `ON CONFLICT DO NOTHING` to handle race conditions when both devices try to upload quests simultaneously. No arbitrary delays needed.

**File:** `lib/services/quest_initialization_service.dart`

---

### Love Points System

**Single Source of Truth:** `couples.total_lp` (couple-level, not per-user)

#### One-Time LP Awards

| Content Type | LP | Notes |
|--------------|-----|-------|
| `welcome_quiz` | 30 | One-time onboarding award via `welcome-quiz/submit/route.ts` |

#### Daily LP Grant System

LP is awarded **once per content type per UTC day per couple**. Users can play unlimited content but only receive LP once per day per content type.

| Content Type | LP per Day | Notes |
|--------------|------------|-------|
| `classic_quiz` | 30 | Via `api/lib/lp/grant-service.ts` |
| `affirmation_quiz` | 30 | Via `api/lib/lp/grant-service.ts` |
| `you_or_me` | 30 | Via `api/lib/lp/grant-service.ts` |
| `linked` | 30 | Via `api/lib/lp/grant-service.ts` |
| `word_search` | 30 | Via `api/lib/lp/grant-service.ts` |
| Steps Together | 15-30 | **Unchanged** - keeps existing claim pattern |

**Max daily:** 150 LP (games) + 15-30 LP (steps) = 165-180 LP

#### Configuration (api/.env)

```env
# Hour (0-23 UTC) when LP grants reset. Default: 0 (midnight UTC)
LP_RESET_HOUR_UTC=0

# Whether users can play more content after earning LP for the day
# true = unlimited play, just no more LP (default)
# false = block new content until reset
LP_ALLOW_UNLIMITED_CONTENT=true
```

#### Server Awards LP (DO NOT award locally)
```dart
// ❌ WRONG - causes double-counting
await _arenaService.awardLovePoints(30, 'quiz_complete');

// ✅ CORRECT - sync from server
await LovePointService.fetchAndSyncFromServer();
```

#### Key Files

| File | Purpose |
|------|---------|
| `api/lib/lp/grant-service.ts` | Daily LP grant tracking (tryAwardDailyLp) |
| `api/lib/lp/daily-reset.ts` | LP day calculation, reset time utilities |
| `api/lib/lp/award.ts` | Core LP award to couples.total_lp |
| `docs/LP_DAILY_RESET_SYSTEM.md` | Full implementation documentation |

#### API Response Fields

Game completion endpoints return LP status:
```json
{
  "lpEarned": 30,
  "alreadyGrantedToday": false,
  "resetInMs": 43200000,
  "canPlayMore": true
}
```

#### UI Updates via Callback
```dart
LovePointService.setLPChangeCallback(() {
  if (mounted) setState(() {});
});
```

---

### Game-Specific Rules

#### Onboarding Unlock System
Unlock chain: `Pairing → Welcome Quiz → Classic + Affirmation → You or Me → Linked → Word Search → Steps`

**Key files:**
- `lib/services/unlock_service.dart` - Server-only state (no Hive)
- `lib/screens/welcome_quiz_*.dart` - Intro, game, waiting, results
- `lib/widgets/unlock_celebration.dart` - Post-unlock celebration overlay
- `lib/widgets/lp_intro_overlay.dart` - First-time LP introduction (shown on home)

**Rules:**
- Navigate to `MainScreen(showLpIntro: true)` after quiz results (includes bottom nav)
- Welcome Quiz screens use `PopScope(canPop: false)` - users cannot go back
- LP is introduced on HOME screen after quiz, NOT on quiz intro screen
- Unlock triggers fire from result screens (check `_checkForUnlock()` pattern)

#### Daily Quest Generation
Exactly 3 quests per day:
- Slot 0: Classic quiz (even track positions: 0, 2)
- Slot 1: Affirmation quiz (odd track positions: 1, 3)
- Slot 2: You or Me (separate progression)

**File:** `lib/services/quest_type_manager.dart:403-507`

#### You-or-Me Answer Encoding
Uses RELATIVE encoding, not absolute:
- User taps "You" → sends 0 (partner)
- User taps "Me" → sends 1 (self)
- Server inverts for comparison: `api/lib/game/handler.ts:381-399`

**DO NOT** invert answers on Flutter side or compare raw values.

#### Linked Game
- Clue cells: Rendered inline at `linked_game_screen.dart:468` (not `clue_cell.dart`)
- Answer colors: Defined inline at `linked_game_screen.dart:749-775`
- Use `Color.alphaBlend()` for solid colors (prevents dark grid bleed-through)

#### Side Quest Polling (Linked, Word Search)

**Key distinction:**
- Daily quests: Each user plays once → tracked via `userCompletions`
- Side quests: Multiple turns per user → tracked via `currentTurnUserId`

**Polling:** `home_screen.dart:137-186`
- 5s interval, polls `linkedService.pollMatchState()` / `wordSearchService.pollMatchState()`
- Updates Hive → refreshes `_sideQuestsFuture` → rebuilds quest cards

**Quest card turn detection:** `quest_card.dart:77-117`
- Reads `currentTurnUserId` synchronously from Hive in `build()`
- Turn status checked FIRST in `_buildStatusBadge()`, before completion logic

**CRITICAL:** After Linked turn submission, save to Hive (Word Search does this via `refreshGameState()`):
```dart
// linked_game_screen.dart - after setState with _updateStateFromResult()
await StorageService().saveLinkedMatch(_gameState!.match);
```

#### Branch Rotation (Linked & Word Search)
Advances on completion:
- Linked: casual → romantic → adult → casual
- Word Search: everyday → passionate → naughty → everyday

**Cooldown:** `PUZZLE_COOLDOWN_ENABLED` env var (default: true)

#### Steps Together
Never use `hasPermission()` for sync gating (iOS unreliable):
```dart
// ❌ Unreliable
final hasPerms = await _health.hasPermissions([HealthDataType.STEPS]);

// ✅ Use stored status
final connection = _storage.getStepsConnection();
if (connection?.isConnected != true) return null;
```

---

### UI Patterns

#### LP Counter Auto-Updates
- `LovePointService.setAppContext()` in `main.dart`
- Screens register via `setLPChangeCallback()`
- Notification banner shows "+30 LP" for 3 seconds

#### Animation & Sound
- Haptics: `HapticService().trigger(HapticType.success)`
- Sound: `SoundService().play(SoundId.confettiBurst)`
- Accessibility: Check `AnimationConfig.shouldReduceMotion(context)`

#### Branch Manifests
Custom video/image per content branch:
- Manifests: `assets/brands/{brandId}/data/{activity}/{branch}/manifest.json`
- Fallback: Manifest → Activity default → Grayscale emoji

See `docs/BRANCH_MANIFEST_GUIDE.md`

#### Brand-Specific UI (Multi-Brand Architecture)

**Design Principle:** "Shared logic, separate UI"
- Services, models, and business logic are shared across all brands
- Only presentation/UI varies between brands
- Brand-specific widgets live in `lib/widgets/brand/{brandId}/` (e.g., `us2/`)

**DO NOT:** Write inline brand-specific code in screens
```dart
// ❌ WRONG - Bloats the file with 200+ lines of brand-specific widgets
Widget _buildUs2HeroImage() { ... }
Widget _buildUs2Badge() { ... }
Widget _buildUs2StatsCard() { ... }
```

**DO:** Use reusable brand components
```dart
// ✅ CORRECT - Reusable component with configuration
return Us2IntroScreen.withQuizCard(
  heroEmoji: '🤔',
  badges: ['YOU OR ME', 'DEEPER'],
  quizTitle: _quizTitle,
  stats: [('Questions', '5', false)],
);
```

**Key Files:**
| File | Purpose |
|------|---------|
| `lib/config/brand/brand_loader.dart` | Runtime brand selection |
| `lib/config/brand/us2_theme.dart` | Us 2.0 design tokens (colors, gradients) |
| `lib/widgets/brand/brand_widget_factory.dart` | Factory for brand-aware widgets |
| `lib/widgets/brand/us2/*.dart` | Reusable Us 2.0 components |

**Component Patterns:**
- **Simple factories:** `Us2IntroScreen.simple(title, description, emoji, ...)` for basic layouts
- **Complex factories:** `Us2IntroScreen.withQuizCard(badges, stats, ...)` for rich layouts
- **Shared private widgets:** `_Us2BackButton`, `_Us2Badge` in component files
- **Public building blocks:** `Us2StartButton`, `Us2RewardBadge` for cross-screen use

**When Adding Brand-Specific UI:**
1. Check if a reusable component exists in `lib/widgets/brand/us2/`
2. If not, create one with factory constructors for flexibility
3. Use `BrandWidgetFactory.isUs2` to branch at screen level
4. Never duplicate widget code across screens

---

### Security & Platform

#### Never Commit These Files
```
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
.env, functions/.env, functions/serviceAccountKey.json
```

If committed: Remove from history, rotate ALL Firebase credentials.

#### Web Platform Safety
- Use `NotificationService.getToken()` not `FirebaseMessaging.instance.getToken()`
- Web doesn't support FCM service workers in debug → blank screen crash
- New assets require `flutter clean && flutter run`

#### Push Notifications & Pokes

**Token sync triggers:**
- Bootstrap (awaited) - `app_bootstrap_service.dart:191`
- App resume from background - `main.dart:187`
- After permission granted in LP intro - `notification_service.dart:240`
- FCM token refresh callback - `notification_service.dart:154`

**After reset script:** Both devices must open app to register push tokens. Tokens are device-specific and cannot be created by server scripts.

**Common poke failures:**
- Partner hasn't opened app since pairing/reset
- User denied notification permission
- Network failure during sync (retries 3x automatically)

**File:** `lib/widgets/poke_bottom_sheet.dart` shows warning when partner token missing.

#### Cloud Functions v2
```javascript
// ✅ CORRECT (v2)
exports.fn = functions.https.onCall(async (request) => {
  const { param } = request.data;
});

// ❌ WRONG (v1)
exports.fn = functions.https.onCall(async (data, context) => {});
```

#### Auth Token Checks
Never use sync `isAuthenticated` in async flows:
```dart
// ❌ Race condition
if (!_authService.isAuthenticated) throw Exception('Not auth');

// ✅ Read from storage
final token = await _authService.getAccessToken();
if (token == null) throw Exception('Not auth');
```

#### Logout Behavior
- Clears: Hive local data + secure storage auth tokens
- Does NOT clear: Supabase `auth.users` or `couples` table
- User can log back in with same email → session restored, pairing intact
- To fully reset a user: Manually delete from `auth.users` in Supabase
- File: `lib/screens/profile_screen.dart:743-871`

#### FutureBuilder with Polling (Anti-Blink)
When using `FutureBuilder` in widgets that rebuild due to polling:
```dart
// ❌ WRONG - blinks on every setState
FutureBuilder(future: _fetchData(), ...)  // New Future every build

// ✅ CORRECT - cache the Future
Future<Data>? _cachedFuture;
void _refreshCache() => _cachedFuture = _fetchData();

// Only refresh when data changes:
if (hasChanges && mounted) { _refreshCache(); setState(() {}); }

// In build:
FutureBuilder(future: _cachedFuture ?? _fetchData(), ...)
```

**Ref:** `home_screen.dart:_sideQuestsFuture`, `docs/POLLING_ARCHITECTURE.md`

---

## Development Setup

### Dev Auth Bypass Toggles

All toggles in `lib/config/dev_config.dart`:

| Toggle | Purpose | Default | Works in Release? |
|--------|---------|---------|-------------------|
| `skipAuthInDev` | Skip entire auth flow (simulator/emulator only) | `true` | No |
| `skipOtpVerificationInDev` | Skip OTP code, use password auth | `true` | **Yes** |

#### `skipAuthInDev` - Full Auth Bypass (Simulators Only)
Skips the entire authentication flow on simulators/emulators/web. Never activates on physical devices.
```dart
static const bool skipAuthInDev = true;  // Toggle in dev_config.dart:17
```
- **Use case:** Fastest development on simulators
- **Effect:** Goes directly to MainScreen or OnboardingScreen without any login

#### `skipOtpVerificationInDev` - OTP Bypass (All Devices)
Collects email but skips OTP verification. Creates real Supabase users via password auth.
```dart
static const bool skipOtpVerificationInDev = true;  // Toggle in dev_config.dart:26
```
- **Use case:** Physical device bug hunting without email verification
- **Effect:** Button shows "Continue (Dev Mode)", creates user directly
- **Technical:** Uses deterministic password `DevPass_{sha256(email).substring(0,12)}_2024!`
- **Note:** SHA256 hash used instead of Dart's `hashCode` because hashCode is NOT stable across devices
- **WARNING:** Set to `false` before App Store release!

#### Apple Sign-In Toggle
Enable/disable "Continue with Apple" button on iOS. Requires Apple Developer Portal + Supabase configuration.
```dart
// In lib/screens/onboarding_screen.dart ~line 22
bool get _isAppleSignInAvailable {
  return false; // Set to: if (kIsWeb) return false; return Platform.isIOS;
}
```
- **Current state:** Disabled (`return false`)
- **To enable:** Change to `if (kIsWeb) return false; return Platform.isIOS;`
- **Full setup guide:** `docs/APPLE_SIGNIN_SETUP.md`

#### API-Side Bypass
Controls how the API authenticates requests:
```bash
# api/.env.local
AUTH_DEV_BYPASS_ENABLED=true   # Ignores JWT, uses hardcoded dev user IDs
AUTH_DEV_BYPASS_ENABLED=false  # Reads real JWT from Supabase auth
```

#### CRITICAL: Flutter + API Setting Compatibility

| Flutter Setting | API Setting | Result |
|-----------------|-------------|--------|
| `skipAuthInDev=true` | `AUTH_DEV_BYPASS_ENABLED=true` | ✅ Both use hardcoded dev user IDs |
| `skipOtpVerificationInDev=true` | `AUTH_DEV_BYPASS_ENABLED=false` | ✅ Both use real users with real JWTs |
| `skipOtpVerificationInDev=true` | `AUTH_DEV_BYPASS_ENABLED=true` | ❌ **BROKEN** - Flutter creates real users, API ignores their JWTs and uses wrong hardcoded IDs → "Couple not found" |

**Rule of thumb:**
- Testing with **hardcoded dev users** (fast, no signup): `skipAuthInDev=true` + `AUTH_DEV_BYPASS_ENABLED=true`
- Testing with **real signup flow** (new users each time): `skipOtpVerificationInDev=true` + `AUTH_DEV_BYPASS_ENABLED=false`

**Quick start:** `/runtogether` launches Android + Chrome with clean state

**Files:** `lib/config/dev_config.dart`, `lib/services/auth_service.dart`, `lib/screens/auth_screen.dart`, `lib/screens/onboarding_screen.dart`

### Logger Verbosity
All services disabled by default. Enable in `lib/utils/logger.dart`:
```dart
Logger.debug('msg', service: 'quiz');  // ✅ Respects config
Logger.debug('msg');                    // ❌ Always logs (bypasses config)
```

---

## Testing & Debugging

### Quick Reset
```bash
cd api && npx tsx scripts/reset_couple_progress.ts  # Clears Supabase couple data
/runtogether                                         # Launches Android + Chrome
```

### Manual Reset Steps
```bash
pkill -9 -f "flutter"
cd api && npx tsx scripts/reset_couple_progress.ts
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind
# Chrome: DevTools → Application → Clear site data
flutter run -d emulator-5554 --flavor togetherremind --dart-define=BRAND=togetherRemind &
flutter run -d chrome --dart-define=BRAND=togetherRemind &
```

### Wipe All Test Accounts
```bash
cd api && npx tsx scripts/wipe_all_accounts.ts  # Nuclear option - removes all test data
```

### Debug Menu
**Access:** Double-tap greeting text on home screen

**Tabs:** Overview, Quests, Sessions, LP & Sync, Actions

### Data Clearing

| Tool | Clears | Safe for Partner? |
|------|--------|-------------------|
| In-App Debug Menu | Local Hive | Yes |
| Reset Script | Supabase | No (run before both apps) |

### Version Verification
Check `lib/screens/home_screen.dart` bottom - increment on UI changes to verify hot reload worked.

### iOS Build Issues
- Firebase config symlink: `ios/Runner/GoogleService-Info.plist` → `../Firebase/TogetherRemind/GoogleService-Info.plist`
- If build fails with "GoogleService-Info.plist not found": `git checkout ios/Firebase/TogetherRemind/GoogleService-Info.plist`

### Android Emulator Hangs
```bash
pkill -9 -f "qemu-system-aarch64"
~/Library/Android/sdk/emulator/emulator -avd Pixel_5 &
~/Library/Android/sdk/platform-tools/adb devices
```

### iOS Multi-Device Deployment
Flutter builds the **same iOS binary** regardless of target device. When deploying to multiple iPhones:
```bash
# ✅ CORRECT - Build once, install sequentially
flutter run -d 00008110-00011D4A340A401E --release  # iPhone 14 first
flutter run -d 00008101-001120A02230001E --release  # iPhone 12 second

# ❌ WRONG - Parallel builds cause Xcode conflicts
flutter run -d device1 --release &
flutter run -d device2 --release &  # "Xcode build failed due to concurrent builds"
```

---

## Documentation Practices

When implementing new features or making significant changes, update the relevant documentation to help future Claude Code agents (and humans) understand the codebase.

### When to Update Documentation

| Change Type | Action |
|-------------|--------|
| New feature | Create `docs/features/FEATURE_NAME.md` |
| Significant architecture change | Update `docs/architecture/*.md` or create new |
| Bug fix with non-obvious cause | Add to relevant feature doc or TROUBLESHOOTING.md |
| New gotcha/edge case discovered | Add to CLAUDE.md Architecture Rules or feature doc |
| Task completion | Mark done in relevant MD files if tracking in docs |

### Feature Documentation Template

New feature docs in `docs/features/` should include:

```markdown
# Feature Name

## Overview
Brief description of what this feature does and why it exists.

## User Flow
1. Step-by-step user journey
2. Screen transitions
3. Expected outcomes

## Key Files
| File | Purpose |
|------|---------|
| `lib/screens/feature_screen.dart` | Main UI |
| `lib/services/feature_service.dart` | Business logic |
| `api/app/api/feature/route.ts` | API endpoint |

## API Endpoints
- `POST /api/feature/action` - Description of what it does

## State Management
- Where state lives (Hive box, service singleton, etc.)
- How state syncs between devices

## Edge Cases & Gotchas
- Known quirks
- Race conditions to watch for
- Platform differences (iOS vs Android vs Web)
```

### Quick Reference: Which Doc to Update

| Topic | File |
|-------|------|
| Auth flows, OTP, sessions | `docs/features/AUTHENTICATION.md` |
| Quest generation/sync | `docs/features/DAILY_QUESTS.md` |
| Quiz mechanics | `docs/features/QUIZ_MATCH.md` |
| You or Me game | `docs/features/YOU_OR_ME.md` |
| Linked puzzle | `docs/features/LINKED.md` |
| Word Search | `docs/features/WORD_SEARCH.md` |
| Feature unlocks | `docs/features/UNLOCK_SYSTEM.md` |
| LP rewards | `docs/features/LOVE_POINTS.md` |
| Steps/HealthKit | `docs/features/STEPS_TOGETHER.md` |
| Polling patterns | `docs/architecture/POLLING.md` |
| API client/auth | `docs/architecture/API_CLIENT.md` |
| Push notifications | `docs/architecture/NOTIFICATIONS.md` |
| Hive/storage | `docs/architecture/STATE_MANAGEMENT.md` |
| Screen routing | `docs/architecture/NAVIGATION.md` |
| Critical rules | `CLAUDE.md` Architecture Rules section |

### CLAUDE.md vs docs/ Files

- **CLAUDE.md**: Critical rules, gotchas, and patterns that MUST be followed. Keep concise.
- **docs/features/**: Detailed feature documentation with flows, files, and edge cases.
- **docs/architecture/**: Cross-cutting concerns that affect multiple features.

**Rule of thumb**: If a future agent would break something without knowing this info, it belongs in CLAUDE.md. If it's helpful context for understanding a feature, it goes in docs/.

---

## File Reference

### API Shared Utilities

| File | Purpose |
|------|---------|
| `api/lib/couple/utils.ts` | Couple fetching (`getCouple`, `getCoupleBasic`, `getCoupleId`) |
| `api/lib/puzzle/loader.ts` | Puzzle loading (`loadPuzzle`, `getNextPuzzle`, `isCooldownActive`) |
| `api/lib/db/transaction.ts` | Transaction wrapper (`withTransaction`, `withTransactionResult`) |
| `api/lib/game/handler.ts` | Game completion logic, LP awards |

**Usage:**
```typescript
// Couple utilities - use in API routes
import { getCouple, getCoupleBasic, getCoupleId } from '@/lib/couple/utils';
const couple = await getCouple(userId);           // Full couple data with firstPlayerId
const basic = await getCoupleBasic(userId);       // coupleId + isPlayer1 only
const coupleId = await getCoupleId(userId);       // Just the ID

// Puzzle utilities - for Linked and Word Search
import { loadPuzzle, getNextPuzzle, isCooldownActive } from '@/lib/puzzle/loader';
const puzzle = loadPuzzle('wordSearch', 'ws_001', 'everyday');
const { puzzleId, activeMatch, branch } = await getNextPuzzle(coupleId, 'linked');

// Transaction wrapper - prevents forgotten rollback/release
import { withTransaction } from '@/lib/db/transaction';
await withTransaction(async (client) => {
  await client.query('INSERT INTO ...', [...]);
  await client.query('UPDATE ...', [...]);
}); // Auto COMMIT on success, ROLLBACK on error
```

### Flutter Mixins

| File | Purpose |
|------|---------|
| `app/lib/mixins/game_polling_mixin.dart` | Standardized polling for turn-based games |

**Usage:**
```dart
class _GameScreenState extends State<GameScreen> with GamePollingMixin {
  @override
  Duration get pollInterval => const Duration(seconds: 10);

  @override
  bool get shouldPoll => !_isLoading && _gameState != null && !_gameState!.isMyTurn;

  @override
  Future<void> onPollUpdate() async {
    final newState = await _service.pollMatchState(_matchId);
    if (mounted) setState(() => _gameState = newState);
  }

  @override
  void initState() { super.initState(); startPolling(); }

  @override
  void dispose() { cancelPolling(); super.dispose(); }
}
```

### Core Services
| File | Purpose |
|------|---------|
| `lib/services/storage_service.dart` | Hive management |
| `lib/services/notification_service.dart` | FCM + local notifications |
| `lib/services/love_point_service.dart` | LP tracking |
| `lib/services/quiz_service.dart` | Quiz logic |
| `lib/services/couple_preferences_service.dart` | Who goes first |
| `lib/services/quest_initialization_service.dart` | Centralized quest init (sync + generate) |

### Config
| File | Purpose |
|------|---------|
| `lib/config/dev_config.dart` | Mock data, simulator detection |
| `lib/utils/logger.dart` | Logging with verbosity control |

### Us 2.0 Brand Widgets
| File | Purpose |
|------|---------|
| `lib/widgets/brand/us2/us2_home_content.dart` | Home screen with hero section (Stack-based layout) |
| `lib/widgets/brand/us2/us2_avatar_section.dart` | Avatars with positioned name badges + glow effects |
| `lib/widgets/brand/us2/us2_connection_bar.dart` | LP progress bar (gold fill, animated heart) |
| `lib/widgets/brand/us2/us2_section_header.dart` | Ribbon-style headers (CustomPaint) |
| `lib/widgets/brand/us2/us2_quest_card.dart` | Quest cards (image + content sections) |
| `lib/widgets/brand/us2/us2_bottom_nav.dart` | Bottom nav with gradient active states |

**Hero section layout:** Uses Stack with fixed heights. If avatar/logo sizes change, update `_buildHeroSection()` height constants.

### Screens
| File | Purpose |
|------|---------|
| `lib/screens/main_screen.dart` | App shell with bottom navigation |
| `lib/screens/home_screen.dart` | Home tab content (quests, stats) |
| `lib/screens/linked_game_screen.dart` | Linked puzzle |
| `lib/screens/quiz_match_game_screen.dart` | Quiz gameplay |

### Debug
| File | Purpose |
|------|---------|
| `lib/widgets/debug/debug_menu.dart` | 5-tab debug interface |
| `lib/widgets/debug/tabs/*.dart` | Individual debug tabs |

---

## Additional Documentation

### Feature Documentation

| Document | Contents |
|----------|----------|
| `docs/features/AUTHENTICATION.md` | Auth flows, OTP, dev bypass, session restoration |
| `docs/features/DAILY_QUESTS.md` | Quest generation, sync, completion tracking |
| `docs/features/QUIZ_MATCH.md` | Classic/Affirmation quiz, waiting screens, results |
| `docs/features/YOU_OR_ME.md` | You or Me game, answer encoding, bulk submission |
| `docs/features/LINKED.md` | Linked puzzle, turn-based, clue/answer mechanics |
| `docs/features/WORD_SEARCH.md` | Word Search, hints, word finding |
| `docs/features/UNLOCK_SYSTEM.md` | Feature unlock chain, celebration triggers |
| `docs/features/LOVE_POINTS.md` | LP rewards, tiers, server-authoritative sync |
| `docs/features/STEPS_TOGETHER.md` | HealthKit integration, step counting, claims |

### Architecture Documentation

| Document | Contents |
|----------|----------|
| `docs/architecture/POLLING.md` | GamePollingMixin, HomePollingService, anti-blink patterns |
| `docs/architecture/API_CLIENT.md` | HTTP client, JWT auth, 401 retry, dev bypass |
| `docs/architecture/NOTIFICATIONS.md` | FCM setup, foreground banners, push handling |
| `docs/architecture/STATE_MANAGEMENT.md` | Hive boxes, storage layers, model patterns |
| `docs/architecture/NAVIGATION.md` | Screen flows, routing, RouteAware pattern |

### Legacy Documentation

| Document | Contents |
|----------|----------|
| `docs/DEV_AUTH_TESTING.md` | Testing new user signup flow without OTP |
| `docs/QUEST_SYSTEM_V2.md` | Quest architecture, patterns |
| `docs/ARCHITECTURE.md` | Data models, push flow |
| `docs/SETUP.md` | Firebase setup, deployment |
| `docs/TROUBLESHOOTING.md` | Common issues |
| `docs/WHITE_LABEL_GUIDE.md` | Brand creation |
| `docs/LEADERBOARD_SYSTEM.md` | Leaderboard triggers |

---

**Last Updated:** 2025-12-17

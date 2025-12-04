# TogetherRemind - Technical Development Guide

**AI Assistant Reference for Development**

---

## Table of Contents

1. [Stack Overview](#stack-overview)
2. [Architecture Rules](#architecture-rules)
   - [Initialization & Storage](#initialization--storage)
   - [Sync & Data Flow](#sync--data-flow)
   - [Love Points System](#love-points-system)
   - [Game-Specific Rules](#game-specific-rules)
   - [UI Patterns](#ui-patterns)
   - [Security & Platform](#security--platform)
3. [Development Setup](#development-setup)
4. [Testing & Debugging](#testing--debugging)
5. [File Reference](#file-reference)

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

---

### Love Points System

**Single Source of Truth:** `couples.total_lp` (couple-level, not per-user)

| Activity | LP | File |
|----------|-----|------|
| Classic/Affirmation Quiz | 30 | `quiz-match/submit/route.ts` |
| You or Me | 30 | `you-or-me-match/submit/route.ts` |
| Linked | 30 | `linked/submit/route.ts` |
| Word Search | 30 | `word-search/submit/route.ts` |
| Steps Together | 15-30 | `steps/route.ts` |

**Max daily:** 165-180 LP

#### Server Awards LP (DO NOT award locally)
```dart
// ❌ WRONG - causes double-counting
await _arenaService.awardLovePoints(30, 'quiz_complete');

// ✅ CORRECT - sync from server
await LovePointService.fetchAndSyncFromServer();
```

**Shared utility:** `api/lib/lp/award.ts`

#### UI Updates via Callback
```dart
LovePointService.setLPChangeCallback(() {
  if (mounted) setState(() {});
});
```

---

### Game-Specific Rules

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

**Polling:** `new_home_screen.dart:137-186`
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

**Ref:** `new_home_screen.dart:_sideQuestsFuture`, `docs/POLLING_ARCHITECTURE.md`

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
- **Effect:** Goes directly to HomeScreen or OnboardingScreen without any login

#### `skipOtpVerificationInDev` - OTP Bypass (All Devices)
Collects email but skips OTP verification. Creates real Supabase users via password auth.
```dart
static const bool skipOtpVerificationInDev = true;  // Toggle in dev_config.dart:26
```
- **Use case:** Physical device bug hunting without email verification
- **Effect:** Button shows "Continue (Dev Mode)", creates user directly
- **Technical:** Uses deterministic password `DevPass_{email.hashCode}_2024!`
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
For API requests to bypass auth header checks:
```bash
# api/.env.local
AUTH_DEV_BYPASS_ENABLED=true
```

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
./scripts/reset_all_progress.sh  # Clears Supabase + instructions
/runtogether                      # Launches both devices
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

### Debug Menu
**Access:** Double-tap greeting text on home screen

**Tabs:** Overview, Quests, Sessions, LP & Sync, Actions

### Data Clearing

| Tool | Clears | Safe for Partner? |
|------|--------|-------------------|
| In-App Debug Menu | Local Hive | Yes |
| Reset Script | Supabase | No (run before both apps) |

### Version Verification
Check `lib/screens/new_home_screen.dart` bottom - increment on UI changes to verify hot reload worked.

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

### Config
| File | Purpose |
|------|---------|
| `lib/config/dev_config.dart` | Mock data, simulator detection |
| `lib/utils/logger.dart` | Logging with verbosity control |

### Screens
| File | Purpose |
|------|---------|
| `lib/screens/new_home_screen.dart` | Main screen |
| `lib/screens/linked_game_screen.dart` | Linked puzzle |
| `lib/screens/quiz_match_game_screen.dart` | Quiz gameplay |

### Debug
| File | Purpose |
|------|---------|
| `lib/widgets/debug/debug_menu.dart` | 5-tab debug interface |
| `lib/widgets/debug/tabs/*.dart` | Individual debug tabs |

---

## Additional Documentation

| Document | Contents |
|----------|----------|
| `docs/QUEST_SYSTEM_V2.md` | Quest architecture, patterns |
| `docs/ARCHITECTURE.md` | Data models, push flow |
| `docs/SETUP.md` | Firebase setup, deployment |
| `docs/TROUBLESHOOTING.md` | Common issues |
| `docs/WHITE_LABEL_GUIDE.md` | Brand creation |
| `docs/LEADERBOARD_SYSTEM.md` | Leaderboard triggers |

---

**Last Updated:** 2025-12-04

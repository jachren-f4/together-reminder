# TogetherRemind - Technical Development Guide

**AI Assistant Reference for Development**

---

## Stack Overview

**Frontend:** Flutter 3.16+, Dart 3.2+, Material Design 3
**Backend:** Firebase Cloud Functions (Node.js 20)
**Storage:** Hive (local NoSQL)
**Notifications:** FCM (Android), APNs (iOS)
**Auth:** None (device pairing only)

**Bundle ID:** `com.togetherremind.togetherremind2` (changed after security remediation)

---

## Critical Architecture Rules

### 1. Initialization Order (MUST FOLLOW)

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase FIRST
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Hive Storage
  await StorageService.init();

  // 3. NotificationService (requires Firebase)
  await NotificationService.initialize();

  // 4. Mock data (if needed)
  await MockDataService.injectMockDataIfNeeded();

  // 5. Run app
  runApp(const TogetherRemindApp());
}
```

### 2. Hive Data Migration Rules

**CRITICAL:** When adding fields to existing HiveTypes, MUST use `defaultValue`:

```dart
// ✅ CORRECT - prevents null errors on existing data
@HiveField(10, defaultValue: 'reminder')
String category;

// ❌ WRONG - will crash with "type 'Null' is not a subtype of type 'String'"
@HiveField(10)
late String category;
```

After adding fields, regenerate adapters:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Web Platform Safety

**CRITICAL Rules:**
- ✅ ALWAYS use `NotificationService.getToken()` to get FCM tokens
- ❌ NEVER call `FirebaseMessaging.instance.getToken()` directly (bypasses web safety)
- Web platform doesn't support FCM service workers in Flutter debug → causes blank screen crash
- `NotificationService.initialize()` skips FCM setup on web (by design)
- `DevConfig.emulatorId` returns `'web-bob'` for web platform

### 4. Cloud Function Signature (v2 API)

**Firebase Functions v6+ requires `(request)` signature, NOT `(data, context)`:**

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

All functions use this pattern (sendReminder, sendPoke, sendPairingConfirmation, etc.).

### 5. Device Detection

**Detection is async with caching - MUST await:**

```dart
// ALWAYS await device detection before using
final isSimulator = await DevConfig.isSimulator;
if (isSimulator) {
  // Simulator-specific logic
}

// Cached synchronous check (returns false if not yet determined)
final isSim = DevConfig.isSimulatorSync;
```

### 6. Firebase Credentials (SECURITY CRITICAL)

**NEVER COMMIT these files to version control:**

```bash
# Already in .gitignore - verify before committing
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
.env
functions/.env
functions/serviceAccountKey.json
```

**Why this matters:**
- These files contain API keys and project identifiers
- Compromised credentials allow unauthorized Firebase access
- Can lead to billing fraud, data breaches, service abuse
- Firebase security rules don't protect against valid credentials

**Required setup:**
- Download from Firebase Console for each environment
- Share via secure channels (1Password, encrypted email)
- Never include in screenshots, logs, or documentation
- Rotate keys immediately if exposed

**Verification:**
```bash
git status  # Check no sensitive files are staged
git diff    # Review changes before commit
```

**If accidentally committed:**
```bash
# 1. Remove from history (use BFG Repo-Cleaner or git-filter-repo)
# 2. Rotate ALL Firebase credentials in Console
# 3. Regenerate and download new config files
# 4. Update .gitignore and recommit
```

---

## Key File Locations

### Core Services
- `lib/services/storage_service.dart` - Hive box management
- `lib/services/notification_service.dart` - FCM + local notifications
- `lib/services/reminder_service.dart` - Send/receive reminders
- `lib/services/remote_pairing_service.dart` - Remote code pairing logic
- `lib/services/poke_service.dart` - Poke logic, rate limiting (30s), mutual detection (2min)
- `lib/services/poke_animation_service.dart` - Lottie animations + haptic
- `lib/services/quiz_service.dart` - Quiz logic, question rotation, scoring
- `lib/services/word_ladder_service.dart` - Word ladder game logic
- `lib/services/memory_flip_service.dart` - Memory Flip game logic
- `lib/services/love_point_service.dart` - Love Points tracking and rewards

### Configuration
- `lib/config/dev_config.dart` - Mock data control, simulator detection
- `lib/firebase_options.dart` - Auto-generated Firebase config
- `functions/index.js` - Cloud Functions (sendReminder, sendPoke, sendPairingConfirmation, etc.)
- `database.rules.json` - RTDB security rules for pairing_codes

### UI Screens
- `lib/screens/home_screen.dart` - Main screen with FAB
- `lib/screens/pairing_screen.dart` - Tabbed pairing (QR + Remote code)
- `lib/screens/inbox_screen.dart` - Poke filter tab + card display
- `lib/screens/activities_screen.dart` - Activities hub with game cards
- `lib/screens/quiz_intro_screen.dart` - Classic quiz intro
- `lib/screens/quiz_screen.dart` - Classic quiz gameplay
- `lib/screens/speed_round_intro_screen.dart` - Speed round intro
- `lib/screens/speed_round_screen.dart` - Speed round gameplay
- `lib/screens/word_ladder_game_screen.dart` - Word ladder gameplay
- `lib/screens/memory_flip_game_screen.dart` - Memory Flip 4×4 card grid

### UI Components
- `lib/widgets/poke_bottom_sheet.dart` - Send poke modal
- `lib/widgets/poke_response_dialog.dart` - Receive poke dialog
- `lib/widgets/match_reveal_dialog.dart` - Memory Flip match celebration
- `lib/widgets/foreground_notification_banner.dart` - In-app notification banner

### Models
- `lib/models/reminder.dart` - Hive models (Reminder, Partner, User)
- `lib/models/pairing_code.dart` - PairingCode model with expiration tracking
- `lib/models/quiz.dart` - Quiz models (QuizSession, QuizAnswer, QuizQuestion)
- `lib/models/word_ladder.dart` - Word ladder models (WordLadderSession, WordGuess)
- `lib/models/memory_flip.dart` - Memory Flip models (MemoryPuzzle, MemoryCard)
- `lib/models/love_point.dart` - Love Points models (LovePointTransaction)

---

## Additional Documentation

See detailed documentation for comprehensive information:

- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Data models, push notification flow, device pairing architecture, feature specifications
- **[docs/SETUP.md](docs/SETUP.md)** - Firebase configuration, development setup, two-device testing, deployment
- **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Common issues, debugging strategies, error handling patterns, Chrome testing best practices

---

## Resources

- [Flutter Docs](https://docs.flutter.dev/)
- [Firebase Flutter](https://firebase.flutter.dev/)
- [Hive Docs](https://docs.hivedb.dev/)
- [pub.dev](https://pub.dev/)

---

**Last Updated:** 2025-11-11 (Refactored documentation structure)

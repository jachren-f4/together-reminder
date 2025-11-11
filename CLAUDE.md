# TogetherRemind - Technical Development Guide

**AI Assistant Reference for Development**

---

## Stack Overview

**Frontend:** Flutter 3.16+, Dart 3.2+, Material Design 3
**Backend:** Firebase Cloud Functions (Node.js 20)
**Storage:** Hive (local NoSQL)
**Notifications:** FCM (Android), APNs (iOS)
**Auth:** None (device pairing only)

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

All functions (`sendReminder`, `sendPairingConfirmation`, `sendPoke`) use this pattern.

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

---

## Data Models

```dart
@HiveType(typeId: 0)
class Reminder extends HiveObject {
  @HiveField(0) late String id;
  @HiveField(1) late String type; // 'sent' | 'received'
  @HiveField(2) late String from;
  @HiveField(3) late String to;
  @HiveField(4) late String text;
  @HiveField(5) late DateTime timestamp;
  @HiveField(6) late DateTime scheduledFor;
  @HiveField(7) late String status; // 'pending' | 'done' | 'snoozed'
  @HiveField(8) DateTime? snoozedUntil;
  @HiveField(9) late DateTime createdAt;
  @HiveField(10, defaultValue: 'reminder') String category; // 'poke' | 'reminder'
}

@HiveType(typeId: 1)
class Partner extends HiveObject {
  @HiveField(0) late String name;
  @HiveField(1) late String pushToken;
  @HiveField(2) late DateTime pairedAt;
  @HiveField(3) String? avatarEmoji;
}

@HiveType(typeId: 2)
class User extends HiveObject {
  @HiveField(0) late String id;
  @HiveField(1) late String pushToken;
  @HiveField(2) late DateTime createdAt;
  @HiveField(3) String? name;
}

@HiveType(typeId: 3)
class MemoryPuzzle extends HiveObject {
  @HiveField(0) late String id;
  @HiveField(1) late DateTime createdAt;
  @HiveField(2) late DateTime expiresAt;
  @HiveField(3) late List<MemoryCard> cards;
  @HiveField(4) late String status; // 'active' | 'completed'
  @HiveField(5) late int totalPairs;
  @HiveField(6) late int matchedPairs;
  @HiveField(7) DateTime? completedAt;
  @HiveField(8) late String completionQuote;
}

@HiveType(typeId: 4)
class MemoryCard extends HiveObject {
  @HiveField(0) late String id;
  @HiveField(1) late String puzzleId;
  @HiveField(2) late int position;
  @HiveField(3) late String emoji;
  @HiveField(4) late String pairId;
  @HiveField(5) late String status; // 'hidden' | 'matched'
  @HiveField(6) String? matchedBy;
  @HiveField(7) DateTime? matchedAt;
  @HiveField(8) late String revealQuote;
}

@HiveType(typeId: 5)
class MemoryFlipAllowance extends HiveObject {
  @HiveField(0) late String userId;
  @HiveField(1) late int flipsRemaining;
  @HiveField(2) late DateTime resetsAt;
  @HiveField(3) late int totalFlipsToday;
  @HiveField(4) late DateTime lastFlipAt;
}
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
- `lib/services/memory_flip_service.dart` - Memory Flip game logic, flip allowance, match detection
- `lib/services/memory_content_bank.dart` - 53 emoji pairs with romantic quotes

### Configuration
- `lib/config/dev_config.dart` - Mock data control, simulator detection
- `lib/firebase_options.dart` - Auto-generated Firebase config
- `functions/index.js` - Cloud Functions (sendReminder, sendPoke, sendPairingConfirmation, createPairingCode, getPairingCode, syncMemoryFlip, sendMemoryFlipMatchNotification, sendMemoryFlipCompletionNotification)
- `database.rules.json` - RTDB security rules for pairing_codes

### UI Components
- `lib/screens/home_screen.dart` - Main screen with FAB
- `lib/screens/pairing_screen.dart` - Tabbed pairing (QR + Remote code)
- `lib/screens/inbox_screen.dart` - Poke filter tab + card display
- `lib/screens/memory_flip_game_screen.dart` - Memory Flip 4×4 card grid game
- `lib/screens/activities_screen.dart` - Activities hub with Memory Flip card
- `lib/widgets/poke_bottom_sheet.dart` - Send poke modal (opened by FAB)
- `lib/widgets/poke_response_dialog.dart` - Receive poke dialog
- `lib/widgets/match_reveal_dialog.dart` - Memory Flip match celebration
- `lib/widgets/foreground_notification_banner.dart` - In-app notification banner

### Models
- `lib/models/reminder.dart` - Hive models (Reminder, Partner, User)
- `lib/models/pairing_code.dart` - PairingCode model with expiration tracking
- `lib/models/memory_flip.dart` - Memory Flip models (MemoryPuzzle, MemoryCard, MemoryFlipAllowance)

---

## Push Notifications

### Foreground Notification Flow

**Context Setup (Required):**
- Context must be set in main.dart: `NotificationService.setAppContext(context)` after first frame
- Banner shows only if `_appContext` is mounted

**Behavior:**
- **Foreground:** Animated banner + haptic feedback
- **Background/Terminated:** System notification
- Auto-dismiss after 4 seconds (tap to dismiss early)

### Background Message Handler

**MUST be top-level function with pragma annotation:**

```dart
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📨 Background message: ${message.messageId}');
  await NotificationService._saveReceivedReminder(message);
}
```

Location: `lib/services/notification_service.dart:9`

### Notification Service (Key Methods)

```dart
class NotificationService {
  Future<void> initialize() async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);
    String? token = await _fcm.getToken();

    // Configure local notifications with action buttons
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'reminder_channel', 'Reminders',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('love_chime'),
      actions: [
        AndroidNotificationAction('done', 'Done'),
        AndroidNotificationAction('snooze', 'Snooze'),
      ],
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.actionId == 'done') {
      StorageService().updateReminderStatus(response.payload, 'done');
    } else if (response.actionId == 'snooze') {
      // Snooze logic
    }
  }
}
```

---

## Firebase Integration

### Dependency Requirements

**mobile_scanner MUST be v7.0.0+ (GoogleUtilities 8.x compatibility)**
- Versions <7.0 cause CocoaPods conflict with Firebase
- Root cause: mobile_scanner <7.0 uses GoogleMLKit which requires GoogleUtilities < 8.0

### Android Build Requirements

```kotlin
// android/app/build.gradle.kts
android {
  compileOptions {
    isCoreLibraryDesugaringEnabled = true
  }
}

dependencies {
  coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
```

### iOS Requirements (MANDATORY)

**Xcode Capabilities:**
- Push Notifications capability
- Background Modes → Remote notifications

**Firebase Console:**
- APNs .p8 key uploaded to Cloud Messaging settings

**Files:**
- `ios/Runner/Info.plist` - Must have `FirebaseAppDelegateProxyEnabled = false`
- `ios/Runner/AppDelegate.swift` - Notification categories (line 27-34)
- `ios/Runner/GoogleService-Info.plist` - Downloaded from Firebase Console

**Notification Categories:**
```swift
// ios/Runner/AppDelegate.swift
let doneAction = UNNotificationAction(identifier: "DONE_ACTION", title: "Done", options: [])
let snoozeAction = UNNotificationAction(identifier: "SNOOZE_ACTION", title: "Snooze", options: [])
let category = UNNotificationCategory(identifier: "REMINDER_CATEGORY", actions: [doneAction, snoozeAction], intentIdentifiers: [], options: [])
UNUserNotificationCenter.current().setNotificationCategories([category])
```

### Android Requirements

**Files:**
- `android/app/google-services.json` - Downloaded from Firebase Console
- `android/app/build.gradle.kts` - Google Services plugin

**Permissions:**
- `POST_NOTIFICATIONS` in AndroidManifest.xml
- Firebase notification channel metadata in AndroidManifest.xml

### Cloud Function Deployment

```bash
firebase deploy --only functions
```

**Deployed URL:** us-central1-togetherremind.cloudfunctions.net/sendReminder
**Runtime:** Node.js 20
**Requires:** Firebase Blaze plan

---

## Device Pairing

TogetherRemind supports two pairing methods: **In-Person QR Pairing** and **Remote Code Pairing**.

### Pairing UI Structure

The pairing screen uses a `TabController` with two tabs:
- **In Person**: QR code generation and scanning
- **Remote**: 6-character temporary code pairing

File: `lib/screens/pairing_screen.dart`

---

## In-Person QR Pairing

### Generate QR

```dart
final pairingData = {
  'userId': user.id,
  'pushToken': await NotificationService.getToken(), // Use service method
  'platform': Platform.isIOS ? 'ios' : 'android',
  'timestamp': DateTime.now().millisecondsSinceEpoch,
};

QrImageView(
  data: jsonEncode(pairingData),
  version: QrVersions.auto,
  size: 200.0,
)
```

**UI Notes:**
- QR code auto-generates in `initState()` - no button needed
- Scanner opened via "Scan Partner's Code" button

### Scan QR

```dart
MobileScanner(
  onDetect: (capture) {
    final qrData = capture.barcodes.first.rawValue;
    final data = jsonDecode(qrData);

    final partner = Partner(
      name: 'Partner',
      pushToken: data['pushToken'],
      pairedAt: DateTime.now(),
    );
    await StorageService().savePartner(partner);

    // Send pairing notification to partner
    await _sendPairingNotification(partner.pushToken);
  },
)
```

---

## Remote Code Pairing

**Purpose**: Enables long-distance couples to pair without physical proximity.

### Architecture

**Backend Storage**: Firebase Realtime Database (NOT Firestore)
- Path: `/pairing_codes/{CODE}`
- TTL: 10 minutes
- One-time use (deleted after retrieval)

**Cloud Functions**:
- `createPairingCode` - Generates and stores codes
- `getPairingCode` - Retrieves and validates codes

**Security Rules**: `database.rules.json`

### Code Format

- **Length**: 6 characters
- **Character Set**: A-Z, 2-9 (32 chars total)
- **Excluded**: 0/O, 1/I (prevents ambiguity)
- **Keyspace**: 32^6 = 1,073,741,824 combinations
- **TTL**: 10 minutes
- **One-Time Use**: Code deleted after first retrieval

### Service Layer

File: `lib/services/remote_pairing_service.dart`

```dart
class RemotePairingService {
  /// Generate a new pairing code
  Future<PairingCode> generatePairingCode() async {
    final user = _storage.getUser();
    final pushToken = await NotificationService.getToken();

    final callable = _functions.httpsCallable('createPairingCode');
    final result = await callable.call({
      'userId': user.id,
      'pushToken': pushToken,
      'name': user.name ?? 'Your Partner',
      'avatarEmoji': user.avatarEmoji ?? '💕',
    });

    return PairingCode(
      code: result.data['code'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(result.data['expiresAt'] as int),
    );
  }

  /// Pair with a partner using their code
  Future<Partner> pairWithCode(String code) async {
    final callable = _functions.httpsCallable('getPairingCode');
    final result = await callable.call({'code': code.toUpperCase().trim()});

    final partner = Partner(
      name: result.data['name'] ?? 'Partner',
      pushToken: result.data['pushToken'] ?? '',
      pairedAt: DateTime.now(),
      avatarEmoji: result.data['avatarEmoji'] ?? '💕',
    );

    await _storage.savePartner(partner);

    // Send pairing confirmation notification to partner
    await NotificationService.sendPairingConfirmation(
      partnerToken: partner.pushToken,
      myName: user.name ?? 'Your Partner',
      myPushToken: await NotificationService.getToken(),
    );

    return partner;
  }
}
```

### Cloud Functions Implementation

File: `functions/index.js`

**createPairingCode** (Lines 1177-1241):
```javascript
exports.createPairingCode = functions.https.onCall(async (request) => {
  const { userId, pushToken, name, avatarEmoji } = request.data;

  // Generate random 6-char code (excludes 0/O, 1/I)
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }

  const createdAt = Date.now();
  const expiresAt = createdAt + (10 * 60 * 1000); // 10 minutes

  // Store in RTDB
  const db = admin.database();
  await db.ref(`pairing_codes/${code}`).set({
    userId, pushToken,
    name: name || 'Your Partner',
    avatarEmoji: avatarEmoji || '💕',
    createdAt, expiresAt,
  });

  return { code, expiresAt };
});
```

**getPairingCode** (Lines 1243-1310):
```javascript
exports.getPairingCode = functions.https.onCall(async (request) => {
  const { code } = request.data;

  if (!code || code.length !== 6) {
    throw new functions.https.HttpsError('invalid-argument', 'Code must be 6 characters');
  }

  const db = admin.database();
  const codeRef = db.ref(`pairing_codes/${code.toUpperCase()}`);
  const snapshot = await codeRef.once('value');

  if (!snapshot.exists()) {
    throw new functions.https.HttpsError('not-found', 'Code not found or expired');
  }

  const data = snapshot.val();

  // Check expiration
  if (Date.now() > data.expiresAt) {
    await codeRef.remove();
    throw new functions.https.HttpsError('deadline-exceeded', 'Code expired');
  }

  // Delete code after successful retrieval (one-time use)
  await codeRef.remove();

  return {
    userId: data.userId,
    pushToken: data.pushToken,
    name: data.name,
    avatarEmoji: data.avatarEmoji,
  };
});
```

### RTDB Security Rules

File: `database.rules.json`

```json
{
  "rules": {
    "pairing_codes": {
      "$code": {
        ".read": true,
        ".write": "!data.exists()",
        ".validate": "newData.hasChildren(['userId', 'pushToken', 'name', 'createdAt', 'expiresAt'])"
      }
    }
  }
}
```

**Rules Explanation**:
- `.read: true` - Anyone can read codes (required for code lookup)
- `.write: "!data.exists()"` - Prevents code overwrites (write only if doesn't exist)
- `.validate` - Ensures required fields are present

### UI Implementation

File: `lib/screens/pairing_screen.dart` (1,323 lines)

**Key UI States**:
1. **Initial Choice Screen** - Generate or Enter code buttons
2. **Code Display Screen** - Shows code with live countdown timer
3. **Waiting Screen** - Circular progress while waiting for partner
4. **Code Entry Dialog** - 6-character input with validation
5. **Confirmation Dialog** - Shows partner info before pairing

**Countdown Timer** (Lines 184-206):
```dart
void _startCountdownTimer() {
  _countdownTimer?.cancel();
  _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (!mounted || _generatedCode == null) {
      timer.cancel();
      return;
    }

    if (_generatedCode!.isExpired) {
      timer.cancel();
      setState(() {
        _generatedCode = null;
        _isWaitingForPartner = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code expired. Please generate a new one.')),
      );
    } else {
      setState(() {}); // Trigger rebuild to update timer display
    }
  });
}
```

**Code Display with Warning Color** (Lines 643-687):
```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
  decoration: BoxDecoration(
    color: AppTheme.borderLight,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: AppTheme.textTertiary.withAlpha((0.3 * 255).round()),
      width: 2,
    ),
  ),
  child: Text(
    _generatedCode!.code,
    style: const TextStyle(
      fontFamily: 'Courier',
      fontSize: 48,
      fontWeight: FontWeight.w700,
      letterSpacing: 8,
      color: AppTheme.textPrimary,
    ),
  ),
),
const SizedBox(height: 16),
Text(
  'Expires in ${_generatedCode!.formattedTimeRemaining}',
  style: AppTheme.bodyFont.copyWith(
    fontSize: 14,
    color: _generatedCode!.timeRemaining.inMinutes < 3
        ? Colors.red  // Warning color when < 3 minutes
        : AppTheme.textTertiary,
    fontWeight: _generatedCode!.timeRemaining.inMinutes < 3
        ? FontWeight.w600
        : FontWeight.normal,
  ),
),
```

### Error Handling

**Comprehensive error scenarios**:
- `not-found` → "Invalid or expired code"
- `deadline-exceeded` → "Code expired. Ask your partner for a new code."
- `invalid-argument` → "Invalid code format"
- Network errors → Generic error with retry suggestion

File: `lib/services/remote_pairing_service.dart:99-114`

### Model

File: `lib/models/pairing_code.dart`

```dart
class PairingCode {
  final String code;
  final DateTime expiresAt;

  PairingCode({required this.code, required this.expiresAt});

  Duration get timeRemaining => expiresAt.difference(DateTime.now());
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  String get formattedTimeRemaining {
    final remaining = timeRemaining;
    if (remaining.isNegative) return '0:00';
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
```

### Deployment

```bash
# Deploy functions and database rules
firebase deploy --only functions:createPairingCode,functions:getPairingCode,database

# Install dependencies
cd app && flutter pub get
```

**Deployed URLs**:
- `https://us-central1-togetherremind.cloudfunctions.net/createPairingCode`
- `https://us-central1-togetherremind.cloudfunctions.net/getPairingCode`

**RTDB URL**: `https://togetherremind-default-rtdb.firebaseio.com`

### Testing

See `REMOTE_PAIRING_TEST_RESULTS.md` for:
- Deployment verification
- Test scenarios (happy path, expiration, invalid codes, network errors)
- Security validation
- Manual testing checklist

### Security Features

1. **Large Keyspace**: 32^6 = 1,073,741,824 combinations
2. **Short TTL**: 10-minute expiration
3. **One-Time Use**: Code deleted after retrieval
4. **No Ambiguous Chars**: Excludes 0/O, 1/I
5. **RTDB Rules**: Prevents code overwrites
6. **Client Validation**: 6-character format check
7. **Server Validation**: Expiration check before returning data

**Attack Resistance**:
- Brute force: 1B+ combinations + 10-min window = extremely difficult
- Code interception: 10-min window limits exposure
- Code reuse: Prevented by one-time deletion
- Timing attacks: Server-side expiration check

---

## Poke Feature

### Rate Limiting
- Client-side: 30-second cooldown stored in SharedPreferences
- `PokeService.canSendPoke()` checks before sending
- `sendPokeBack()` bypasses rate limit
- Mutual detection: 2-minute window for poke + poke back

### Files
**Services:**
- `lib/services/poke_service.dart` - Core logic
- `lib/services/poke_animation_service.dart` - Lottie + haptic

**UI:**
- `lib/widgets/poke_bottom_sheet.dart` - Send modal
- `lib/widgets/poke_response_dialog.dart` - Receive dialog
- `lib/screens/home_screen.dart:107-150` - FAB

**Cloud Function:**
- `functions/index.js:197-291` - `sendPoke` (v2 API signature)

**Animations:**
- `assets/animations/poke_send.json` - Expanding circle
- `assets/animations/poke_receive.json` - Heart scale/rotate
- `assets/animations/poke_mutual.json` - Confetti particles

---

## Word Ladder Feature

### Word Pair Constraints
- **Minimum difficulty:** All word pairs require `optimalSteps >= 2` (no 1-step ladders)
- **Language:** Finnish-only (English pairs exist but are not used in rotation)
- **Current inventory:** 6 easy, 4 medium, 2 hard Finnish pairs

### Critical Rules
- Finnish dictionary (`assets/words/finnish_words.json`) contains 135 words - expansion required if adding more word pairs
- Yield button appears ONLY in game screen AppBar, NOT on hub/card screens
- File: `lib/services/word_pair_bank.dart` - source of all curated word pairs

### Progress UI
- Uses `SingleChildScrollView` with `Axis.horizontal` for word chain display
- File: `lib/screens/word_ladder_game_screen.dart:290-438`

---

## Speed Round Quiz

### Files
- `lib/screens/speed_round_intro_screen.dart` - Unlock check, intro UI
- `lib/screens/speed_round_screen.dart` - 10-second timer, auto-advance
- `lib/screens/speed_round_results_screen.dart` - Streak bonus breakdown

### Key Rules
- **Unlock:** `QuizService.isSpeedRoundUnlocked()` requires 5 completed Classic Quizzes
- **Format type:** `formatType: 'speed_round'` (vs. `'classic'`)
- **Timer:** 10 seconds per question, auto-advances on timeout
- **Streak bonus:** +5 LP per 3 consecutive correct answers (resets on incorrect)
- **LP rewards:** 20-40 base (match %) + streak bonuses

### LovePointService Integration

**CRITICAL:** Use static method, not instance method:

```dart
// ✅ CORRECT - use static method
LovePointService.awardPoints(
  amount: totalLp,
  reason: 'speed_round',
  relatedId: sessionId,
);

// ❌ WRONG - no instance method exists
final service = LovePointService();
service.awardLovePoints(...); // Does not exist
```

---

## Development Mode & Testing

### Mock Data Control

**Auto-injects on simulators only (debug mode):**
```dart
// lib/config/dev_config.dart
static const bool enableMockPairing = false; // Set to disable
```

**Uninstall app to clear existing mock data.**

### Dual-Emulator Testing

**Hardcoded partner IDs:**
- Alice = `emulator-5554` (Android)
- Bob = `web-bob` (Web)

**If platform changes, update:**
- `lib/services/dev_pairing_service.dart:83`
- `lib/services/quiz_service.dart:335`
- Pattern: `myIndex == 0 ? 'web-bob' : 'emulator-5554'`

### Web Platform Testing

```bash
flutter run -d emulator-5554  # Alice (Android)
flutter run -d chrome          # Bob (Web)
```

**Web Constraints:**
- Treated as "simulator" in debug mode
- FCM service workers NOT supported → blank screen crash if called directly
- Uses fake push tokens: `web_token_${timestamp}`

**CRITICAL: Chrome Testing Best Practices**

When testing new code changes on Chrome, hot reload often fails to pick up changes properly. **ALWAYS** follow this process:

```bash
# 1. Kill BOTH Flutter processes AND Chrome instances
pkill -f "flutter run"
pkill -f "chrome"

# 2. Clean build (optional but recommended for major changes)
cd app && flutter clean
flutter pub get

# 3. Start fresh Flutter instance
flutter run -d chrome
```

**Why this is necessary:**
- Hot reload (`r`) often doesn't update UI changes on Chrome
- Hot restart (`R`) sometimes maintains stale state
- Chrome instances maintain Hive/IndexedDB state even after Flutter process dies
- Multiple Chrome tabs can interfere with each other
- Killing only Flutter leaves Chrome with stale connections and cached state

**Quick restart (without clean):**
```bash
# Kill BOTH Flutter and Chrome
pkill -f "flutter run" && pkill -f "chrome"

# Start fresh
cd app && flutter run -d chrome
```

**When to use full clean:**
- After updating dependencies
- After modifying data models (Hive types)
- After major UI restructuring
- When hot reload repeatedly fails
- When seeing inexplicable errors

**Testing Checklist:**
- [ ] Kill BOTH Flutter processes AND Chrome instances
- [ ] Start fresh `flutter run -d chrome`
- [ ] Verify 160 questions loaded (check console)
- [ ] Navigate to Activities screen
- [ ] Verify all cards visible (including Speed Round)
- [ ] Test feature functionality

---

## Common Patterns

### Error Handling
```dart
try {
  await sendReminder(reminder);
} catch (e) {
  // Save as "pending_send", retry later
}
```

### Check Connectivity
```dart
import 'package:connectivity_plus/connectivity_plus.dart';
final result = await Connectivity().checkConnectivity();
return result != ConnectivityResult.none;
```

### Request Permissions
```dart
final settings = await FirebaseMessaging.instance.requestPermission();
if (settings.authorizationStatus != AuthorizationStatus.authorized) {
  // Show dialog, offer settings
}
```

### Lazy Loading
```dart
ListView.builder(
  itemCount: StorageService().remindersBox.length,
  itemBuilder: (context, index) {
    final reminder = StorageService().remindersBox.getAt(index);
    return ReminderCard(reminder: reminder);
  },
)
```

### Secure Storage
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
final storage = FlutterSecureStorage();
await storage.write(key: 'push_token', value: token);
```

### Encrypt Hive
```dart
final key = Hive.generateSecureKey();
await Hive.openBox('secure', encryptionCipher: HiveAesCipher(key));
```

---

## Troubleshooting

### Hot Reload Not Working
```bash
ps aux | grep flutter       # Find process ID
kill <pid>                  # Kill process
flutter run -d <device-id>  # Restart
```

**Why:** Hot reload may not pick up all UI changes.

### Firebase Build Failures
```bash
flutter clean && rm -rf ios/Pods ios/Podfile.lock
pod repo update
flutter pub get
flutter run -d <device-id>
```

**Check:** `mobile_scanner` version is 7.0.0+ in pubspec.yaml

### CocoaPods GoogleUtilities Conflict
**Symptom:** "CocoaPods could not find compatible versions for pod GoogleUtilities"
**Solution:** Update mobile_scanner to ^7.0.0

### iOS Notifications Not Showing
1. Check APNs .p8 key uploaded in Firebase Console
2. Add `GoogleService-Info.plist` to ios/Runner/
3. Enable "Push Notifications" capability in Xcode
4. Enable "Background Modes → Remote notifications" in Xcode
5. Test on real device (simulator doesn't support push)

### Hive Box Already Open
```dart
if (!Hive.isBoxOpen('reminders')) await Hive.openBox('reminders');
```

### QR Scanner Not Working
1. Add camera permissions (Info.plist, AndroidManifest.xml)
2. Request runtime permission
3. Test on real device

### Mock Data on Real Devices
**Cause:** Old hardcoded `_forceSimulatorMode` flag (now removed)
**Solution:** Already fixed - uses `device_info_plus` detection
**Verify:** Check logs for `isPhysicalDevice: true` on real devices

### UI Overflow Errors
- Send reminder screen: Fixed GridView sizing (`lib/screens/send_reminder_screen.dart:27`)
- Poke screen: Fixed emoji button sizing (`lib/widgets/poke_bottom_sheet.dart:303`)

### Quiz Results Showing Wrong Answers
**Symptom:** "You" shows partner's answers and vice versa
**Cause:** Using `userIds[0]` and `userIds[1]` without checking current user
**Solution:** Look up answers by current user ID: `answers[user.id]`
**Location:** `lib/screens/quiz_results_screen.dart:290-382`

### Cloud Function Errors
- "runtime field is required" → Add `"runtime": "nodejs20"` to firebase.json
- "Your project must be on the Blaze plan" → Upgrade in Firebase Console
- "parameter is required" → Check function signature uses `(request)` not `(data, context)`

---

## Testing Configuration

### Testing Time Options
**First time option currently set to "In 1 sec" for testing.**

Change back to production:
```dart
// lib/screens/send_reminder_screen.dart:27
{'emoji': '⏰', 'label': '15 min', 'minutes': 15}
```

---

## Dependencies (Critical Versions)

```yaml
dependencies:
  # Local Storage
  hive: ^2.2.3
  hive_flutter: ^1.1.0

  # Firebase & Notifications
  firebase_core: ^3.6.0
  firebase_messaging: ^15.1.3
  firebase_database: ^11.1.4
  flutter_local_notifications: ^18.0.1
  cloud_functions: ^5.1.3

  # QR Code (CRITICAL: Must be v7.0.0+ for Firebase compatibility)
  qr_flutter: ^4.1.0
  mobile_scanner: ^7.0.0

  # Utilities
  uuid: ^4.3.3
  intl: ^0.19.0
  device_info_plus: ^11.1.0
  share_plus: ^10.1.3

  # Animations
  lottie: ^3.1.3

dev_dependencies:
  hive_generator: ^2.0.1
  build_runner: ^2.4.6
```

**CRITICAL:**
- mobile_scanner MUST be >= 7.0.0 for Firebase compatibility
- firebase_database required for remote pairing (RTDB)
- share_plus required for sharing pairing codes

---

## Custom Slash Commands

**CRITICAL:** Slash command files in `~/.claude/commands/` MUST have YAML frontmatter:

```markdown
---
description: Command description here
---

Your command prompt here...
```

Without the `---` delimiters and description field, commands are invisible to Claude Code.

---

## Resources

- [Flutter Docs](https://docs.flutter.dev/)
- [Firebase Flutter](https://firebase.flutter.dev/)
- [Hive Docs](https://docs.hivedb.dev/)
- [pub.dev](https://pub.dev/)

---

**Last Updated:** 2025-11-11 (Added Speed Round quiz mode and Chrome testing best practices)

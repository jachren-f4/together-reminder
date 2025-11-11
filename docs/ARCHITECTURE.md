# Architecture

Technical architecture and data flow documentation.

---

## Local-First Design

All data stored on-device with Hive (no cloud database). Privacy-focused, fast, offline-capable.

**Tradeoff:** No multi-device sync or backup in MVP.

---

## Device Pairing

The app supports two pairing methods to accommodate different scenarios.

### In-Person QR Pairing

**Flow:**
1. User A generates QR with push token + device ID
2. User B scans QR, saves User A's info locally
3. User B sends pairing notification to User A
4. Both devices paired (no server sync)

**Best for:** Partners in the same location

**Implementation:**

Generate QR:
```dart
final pairingData = {
  'userId': user.id,
  'pushToken': await NotificationService.getToken(),
  'platform': Platform.isIOS ? 'ios' : 'android',
  'timestamp': DateTime.now().millisecondsSinceEpoch,
};

QrImageView(
  data: jsonEncode(pairingData),
  version: QrVersions.auto,
  size: 200.0,
)
```

Scan QR:
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
    await _sendPairingNotification(partner.pushToken);
  },
)
```

**File:** `lib/screens/pairing_screen.dart`

### Remote Code Pairing

**Flow:**
1. User A generates 6-character code (e.g., "7X9K2M")
2. Code stored in Firebase Realtime Database with 10-minute expiration
3. User A shares code via text/messaging apps
4. User B enters code in app
5. App retrieves User A's info from RTDB
6. Both devices paired, code deleted (one-time use)

**Best for:** Long-distance couples who can't meet in person

**Security Features:**
- 1+ billion possible code combinations (32^6)
- 10-minute expiration window
- One-time use (deleted after retrieval)
- No ambiguous characters (0/O, 1/I excluded)

**Code Format:**
- **Length**: 6 characters
- **Character Set**: A-Z, 2-9 (32 chars total)
- **Keyspace**: 32^6 = 1,073,741,824 combinations

**Backend Storage:** Firebase Realtime Database
- Path: `/pairing_codes/{CODE}`
- TTL: 10 minutes
- One-time use (deleted after retrieval)

**Cloud Functions:**
- `createPairingCode` - Generates and stores codes
- `getPairingCode` - Retrieves and validates codes

**RTDB Security Rules** (`database.rules.json`):
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

**Files:**
- `lib/services/remote_pairing_service.dart` - Service layer
- `lib/models/pairing_code.dart` - PairingCode model with expiration tracking
- `functions/index.js` - Cloud Functions (createPairingCode, getPairingCode)
- `database.rules.json` - RTDB security rules

---

## Push Notification Flow

### Standard Reminder Flow

1. User creates reminder → saved to local Hive DB
2. App calls Cloud Function with partner token + reminder data
3. Cloud Function sends FCM/APNs notification (stateless relay only)
4. Partner receives notification → saved to their local DB

### Foreground Handling

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

## Device Detection

Uses `device_info_plus` for iOS/Android simulator detection:
- **Simulators:** Auto-inject mock data (debug mode only)
- **Physical Devices:** Require QR pairing
- **Detection:** `iosInfo.isPhysicalDevice` (false = simulator)

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

**File:** `lib/config/dev_config.dart`

---

## Word Ladder Duet

Turn-based collaborative word puzzle game where partners transform a start word into a target word by changing one letter at a time.

### Progress Visualization
- Visual word chain shows completed steps (blue chips), current position (darker blue), remaining steps (dashed placeholders), and target word
- Horizontal scrolling for long chains
- Dynamic step counter: "Progress (X of Y steps)" or "Progress (X steps)" if exceeded optimal

### Difficulty System
- Easy (4 letters): 2-3 steps minimum
- Medium (5 letters): 2-4 steps
- Hard (6 letters): 3-5 steps
- All ladders require at least 2 guesses to complete

### Language Support
- Finnish word validation with 135-word dictionary
- Expanded word list supports common Finnish nouns, verbs, and nature words

### Key Rules
- **Minimum difficulty:** All word pairs require `optimalSteps >= 2` (no 1-step ladders)
- **Language:** Finnish-only (English pairs exist but are not used in rotation)
- **Current inventory:** 6 easy, 4 medium, 2 hard Finnish pairs
- Finnish dictionary (`assets/words/finnish_words.json`) contains 135 words - expansion required if adding more word pairs
- Yield button appears ONLY in game screen AppBar, NOT on hub/card screens

**Files:**
- `lib/services/word_pair_bank.dart` - Source of all curated word pairs
- `lib/screens/word_ladder_game_screen.dart:290-438` - Progress UI

---

## Speed Round Quiz

Fast-paced quiz mode with time pressure and streak bonuses.

### Features
- 10 rapid-fire questions with 10-second timer per question
- Auto-advance on timeout
- Streak bonus: +5 LP per 3 consecutive correct answers
- Base reward: 20-40 LP (based on match percentage) + streak bonuses
- **Unlock requirement:** Complete 5 Classic Quizzes

### Scoring
- 90-100% match: 38-40 LP base
- 70-89% match: 30-37 LP base
- 50-69% match: 26-29 LP base
- 0-49% match: 20-25 LP base
- Streak bonus: +5 LP per 3 consecutive correct answers

### Files
- `lib/screens/speed_round_intro_screen.dart` - Unlock status and intro
- `lib/screens/speed_round_screen.dart` - Timer and question flow
- `lib/screens/speed_round_results_screen.dart` - Streak breakdown

### Key Rules
- **Unlock:** `QuizService.isSpeedRoundUnlocked()` requires 5 completed Classic Quizzes
- **Format type:** `formatType: 'speed_round'` (vs. `'classic'`)
- **Timer:** 10 seconds per question, auto-advances on timeout
- **Streak bonus:** +5 LP per 3 consecutive correct answers (resets on incorrect)

---

## Data Models

### Reminder
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
```

### Partner
```dart
@HiveType(typeId: 1)
class Partner extends HiveObject {
  @HiveField(0) late String name;
  @HiveField(1) late String pushToken;
  @HiveField(2) late DateTime pairedAt;
  @HiveField(3) String? avatarEmoji;
}
```

### User
```dart
@HiveType(typeId: 2)
class User extends HiveObject {
  @HiveField(0) late String id;
  @HiveField(1) late String pushToken;
  @HiveField(2) late DateTime createdAt;
  @HiveField(3) String? name;
}
```

### Memory Flip Models
```dart
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

**Last Updated:** 2025-11-11

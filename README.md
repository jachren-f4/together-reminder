# TogetherRemind 💕

**Privacy-first couples app for quick, caring reminders — no email, no calendar, no accounts.**

Send instant reminders and pokes to your partner's phone. Built with Flutter, Firebase, and local-first storage.

---

## Quick Start

### Prerequisites
- Flutter 3.16+ | Dart 3.2+
- Xcode (iOS) or Android Studio
- Firebase account (Blaze plan for Cloud Functions)

### Run in 3 Steps

```bash
# 1. Install dependencies
cd togetherremind
flutter pub get

# 2. List devices
flutter devices

# 3. Run app (mock data auto-enabled on simulators)
flutter run -d <device-id>
```

**Development Mode:** Mock data automatically injects on simulators for rapid testing. For real device pairing, see [Two-Device Testing](#two-device-testing).

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter 3.16+, Dart 3.2+, Material Design 3 |
| **Storage** | Hive (local NoSQL, type-safe) |
| **Temporary Storage** | Firebase Realtime Database (pairing codes only) |
| **Notifications** | Firebase Cloud Messaging + APNs |
| **Backend** | Firebase Cloud Functions (Node.js 20) |
| **Animations** | Lottie v3.1.3 |
| **Auth** | None (device pairing only) |

**Architecture:** Local-first, privacy-focused, offline-capable. RTDB used only for temporary pairing codes (10-min TTL).

---

## Features

### Core (MVP Complete)
- 🔗 **Device Pairing** - Two methods: In-person QR code or Remote 6-character code
- 📲 **Push Notifications** - FCM/APNs with action buttons (Done/Snooze)
- 💬 **Quick Reminders** - Pre-set chips + custom text + time selection
- 💫 **Pokes** - Instant "thinking of you" with mutual detection
- 🧩 **Classic Quiz** - Knowledge-based questions about your partner (160 questions, 5 categories)
- ⚡ **Speed Round** - Fast-paced quiz with 10-second timer and streak bonuses (unlocks after 5 Classic Quizzes)
- 🪜 **Word Ladder Duet** - Collaborative word puzzle with turn-based gameplay
- 📥 **Inbox** - Filterable history (All/Received/Sent/Pokes)
- ⚙️ **Settings** - Notification prefs, partner info, unpair

### Technical Status
- ✅ iOS + Android tested on physical devices
- ✅ Cloud Functions deployed (us-central1)
- ✅ APNs configured, notification categories
- ✅ FCM integrated, core library desugaring

### Roadmap
- **Phase 2:** Voice input, custom sounds, smart time defaults
- **Phase 3:** Home screen widgets, family mode (>2 people), cloud sync

---

## Architecture Highlights

### Local-First Design
All data stored on-device with Hive (no cloud database). Privacy-focused, fast, offline-capable.

**Tradeoff:** No multi-device sync or backup in MVP.

### Device Pairing

The app supports two pairing methods to accommodate different scenarios:

#### In-Person QR Pairing
1. User A generates QR with push token + device ID
2. User B scans QR, saves User A's info locally
3. User B sends pairing notification to User A
4. Both devices paired (no server sync)

**Best for:** Partners in the same location

#### Remote Code Pairing
1. User A generates 6-character code (e.g., "7X9K2M")
2. Code stored in Firebase Realtime Database with 10-minute expiration
3. User A shares code via text/messaging apps
4. User B enters code in app
5. App retrieves User A's info from RTDB
6. Both devices paired, code deleted (one-time use)

**Best for:** Long-distance couples who can't meet in person

**Security Features:**
- 1+ billion possible code combinations
- 10-minute expiration window
- One-time use (deleted after retrieval)
- No ambiguous characters (0/O, 1/I excluded)

### Push Notification Flow
1. User creates reminder → saved to local Hive DB
2. App calls Cloud Function with partner token + reminder data
3. Cloud Function sends FCM/APNs notification (stateless relay only)
4. Partner receives notification → saved to their local DB

**Foreground Handling:**
- In-app animated banner with haptic feedback
- Auto-dismiss after 4 seconds
- System notifications when backgrounded/closed

### Device Detection
Uses `device_info_plus` for iOS/Android simulator detection:
- **Simulators:** Auto-inject mock data (debug mode only)
- **Physical Devices:** Require QR pairing
- **Detection:** `iosInfo.isPhysicalDevice` (false = simulator)

### Word Ladder Duet

Turn-based collaborative word puzzle game where partners transform a start word into a target word by changing one letter at a time.

**Progress Visualization:**
- Visual word chain shows completed steps (blue chips), current position (darker blue), remaining steps (dashed placeholders), and target word
- Horizontal scrolling for long chains
- Dynamic step counter: "Progress (X of Y steps)" or "Progress (X steps)" if exceeded optimal

**Difficulty System:**
- Easy (4 letters): 2-3 steps minimum
- Medium (5 letters): 2-4 steps
- Hard (6 letters): 3-5 steps
- All ladders require at least 2 guesses to complete

**Language Support:**
- Finnish word validation with 135-word dictionary
- Expanded word list supports common Finnish nouns, verbs, and nature words

### Speed Round Quiz

Fast-paced quiz mode with time pressure and streak bonuses.

**Features:**
- 10 rapid-fire questions with 10-second timer per question
- Auto-advance on timeout
- Streak bonus: +5 LP per 3 consecutive correct answers
- Base reward: 20-40 LP (based on match percentage) + streak bonuses
- **Unlock requirement:** Complete 5 Classic Quizzes

**Scoring:**
- 90-100% match: 38-40 LP base
- 70-89% match: 30-37 LP base
- 50-69% match: 26-29 LP base
- 0-49% match: 20-25 LP base
- Streak bonus: +5 LP per 3 consecutive correct answers

**Files:**
- `app/lib/screens/speed_round_intro_screen.dart` - Unlock status and intro
- `app/lib/screens/speed_round_screen.dart` - Timer and question flow
- `app/lib/screens/speed_round_results_screen.dart` - Streak breakdown

---

## Development Setup

### Firebase Configuration

**Required for push notifications:**

1. **Create Firebase Project**
   - Visit [Firebase Console](https://console.firebase.google.com/)
   - Upgrade to **Blaze plan** (required for Cloud Functions)

2. **Add iOS App**
   - Bundle ID: `com.togetherremind.togetherremind`
   - Download `GoogleService-Info.plist` → `ios/Runner/`
   - Upload APNs .p8 key in Firebase Console → Cloud Messaging

3. **Add Android App**
   - Package name: `com.togetherremind.togetherremind`
   - Download `google-services.json` → `android/app/`

4. **Enable Realtime Database**
   - In Firebase Console → Realtime Database → Create Database
   - Choose region (preferably same as Cloud Functions)
   - Start in **locked mode** (rules deployed via `database.rules.json`)

5. **Deploy Cloud Functions & Database Rules**
   ```bash
   firebase deploy --only functions,database
   ```

6. **Xcode Capabilities** (iOS only)
   - Open `ios/Runner.xcworkspace`
   - Enable: Push Notifications
   - Enable: Background Modes → Remote notifications

### Two-Device Testing

1. **Disable Mock Data**
   ```dart
   // lib/config/dev_config.dart
   static const bool enableMockPairing = false;
   ```

2. **Install on Both Devices**
   ```bash
   flutter run -d <device-a-id>  # Terminal 1
   flutter run -d <device-b-id>  # Terminal 2
   ```

3. **Pair Devices**

   **Option 1: In-Person (QR Code)**
   - Device A: Pairing screen → "In Person" tab → QR code auto-displays
   - Device B: Pairing screen → "In Person" tab → "Scan Partner's Code" → scan QR
   - Both devices save partner info locally

   **Option 2: Remote (6-Character Code)**
   - Device A: Pairing screen → "Remote" tab → "Generate Pairing Code"
   - Device A: Share code via text/messaging apps
   - Device B: Pairing screen → "Remote" tab → "Enter Partner's Code" → type code
   - Both devices save partner info (code expires after 10 minutes or first use)

4. **Send Test Reminder**
   - Device A: Send tab → type message → pick time → send
   - Device B: Receives push notification with action buttons
   - Test in: foreground, background, and terminated states

---

## Commands

### Development
```bash
flutter pub get                    # Install dependencies
flutter devices                    # List devices
flutter run -d <device-id>         # Run app
```

### Building
```bash
flutter build apk --release        # Android APK
flutter build ios --release        # iOS (via Xcode)
```

### Maintenance
```bash
flutter clean                      # Clean build cache
flutter pub run build_runner build --delete-conflicting-outputs  # Regenerate Hive adapters
```

---

## Troubleshooting

### Hot Reload Not Working
```bash
ps aux | grep flutter       # Find process ID
kill <pid>                  # Kill process
flutter run -d <device-id>  # Restart
```

### CocoaPods GoogleUtilities Conflict
**Symptom:** Build fails with "CocoaPods could not find compatible versions"

**Solution:** Ensure `mobile_scanner: ^7.0.0` in pubspec.yaml (v7.0+ required for Firebase compatibility)

```bash
flutter clean && rm -rf ios/Pods ios/Podfile.lock
pod repo update
flutter pub get
flutter run -d <device-id>
```

### iOS Notifications Not Showing
1. Upload APNs .p8 key to Firebase Console
2. Enable capabilities in Xcode (Push Notifications + Background Modes)
3. Add `GoogleService-Info.plist` to `ios/Runner/`
4. Test on **real device** (simulator doesn't support push)

### Hive Box Already Open
```dart
if (!Hive.isBoxOpen('reminders')) await Hive.openBox('reminders');
```

---

## Project Structure

```
togetherremind/
├── app/                    # Flutter application
│   ├── lib/
│   │   ├── models/         # Hive data models (Reminder, Partner, User)
│   │   ├── screens/        # UI screens (Home, Inbox, Settings, Pairing)
│   │   ├── services/       # Core services (Notification, Reminder, Poke, Storage)
│   │   ├── widgets/        # Reusable UI components
│   │   └── main.dart       # App entry point
│   ├── ios/                # iOS native configuration
│   ├── android/            # Android native configuration
│   └── pubspec.yaml        # Dependencies
├── functions/              # Firebase Cloud Functions
│   └── index.js            # sendReminder, sendPoke, sendPairingConfirmation, createPairingCode, getPairingCode
├── database.rules.json     # RTDB security rules (pairing codes)
├── mockups/                # UI/UX design mockups (HTML)
├── README.md               # This file (user-facing documentation)
├── CLAUDE.md               # Technical development guide (AI assistant reference)
└── PRD.md                  # Product Requirements Document
```

---

## Firebase Costs

**Free Tier Coverage:** Up to ~6,000 daily active users at 10 reminders/day

| Daily Users | Reminders/Day | Monthly Cost |
|-------------|---------------|--------------|
| 1,000       | 10,000        | **$0**       |
| 5,000       | 50,000        | **$0**       |
| 10,000      | 100,000       | **$2-3**     |
| 50,000      | 500,000       | **$10-15**   |

**Note:** Cost drivers are Cloud Functions only (FCM is free and unlimited).

---

## Privacy & Security

- 🔒 All reminder data stored **locally** on device
- 🔒 No cloud database or server-side storage
- 🔒 Push tokens transmitted via encrypted QR + FCM
- 🔒 Hive supports optional AES encryption
- 🔒 No analytics or tracking (MVP)

**User Controls:** Export data, clear history, unpair partner

---

## Documentation

- **[CLAUDE.md](./CLAUDE.md)** - Technical development guide (data models, services, Firebase setup, troubleshooting)
- **[PRD.md](./PRD.md)** - Product requirements, user stories, success metrics
- **[Mockups](./mockups/)** - Interactive HTML design previews

---

## Current Status

**Stage:** MVP Complete, Pre-Launch Testing
**Last Updated:** 2025-11-11 (Added Speed Round quiz mode)

### Production Ready
- ✅ Core features implemented and tested
- ✅ Push notifications working on iOS + Android
- ✅ Cloud Functions deployed and verified
- ✅ Real device testing (iPhone + Android)

### Next Steps
- Two-device end-to-end testing (cross-platform)
- App Store submission prep (screenshots, privacy policy)

---

## Contributing

This is a personal/concept project. Ideas and feedback welcome!

**Contact:** Joakim Achrén
**Stage:** Concept / Pre-seed

---

## Resources

- [Flutter Docs](https://docs.flutter.dev/)
- [Firebase Flutter](https://firebase.flutter.dev/)
- [Hive Docs](https://docs.hivedb.dev/)
- [pub.dev](https://pub.dev/)

---

**Built with ❤️ for meaningful relationships**

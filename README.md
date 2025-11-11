# TogetherRemind 💕

**Privacy-first couples app for quick, caring reminders — no email, no calendar, no accounts.**

Send instant reminders and pokes to your partner's phone. Built with Flutter, Firebase, and local-first storage.

---

## Quick Start

```bash
# 1. Install dependencies
flutter pub get

# 2. Run app (mock data auto-enabled on simulators)
flutter run -d <device-id>

# 3. For real device pairing, see Setup documentation
```

**Development Mode:** Mock data automatically injects on simulators for rapid testing.

📚 **Detailed Documentation:** [Setup](docs/SETUP.md) | [Architecture](docs/ARCHITECTURE.md) | [Troubleshooting](docs/TROUBLESHOOTING.md)

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

## Core Features

### Communication
- 🔗 **Device Pairing** - Two methods: In-person QR code or Remote 6-character code
- 📲 **Push Notifications** - FCM/APNs with action buttons (Done/Snooze)
- 💬 **Quick Reminders** - Pre-set chips + custom text + time selection
- 💫 **Pokes** - Instant "thinking of you" with mutual detection
- 📥 **Inbox** - Filterable history (All/Received/Sent/Pokes)

### Games & Activities
- 🧩 **Classic Quiz** - Knowledge-based questions about your partner (160 questions, 5 categories)
- ⚡ **Speed Round** - Fast-paced quiz with 10-second timer and streak bonuses (unlocks after 5 Classic Quizzes)
- 🪜 **Word Ladder Duet** - Collaborative word puzzle with turn-based gameplay
- 🎴 **Memory Flip** - Daily memory card matching game (4x4 grid, shared progress)

### Settings
- ⚙️ **Settings** - Notification preferences, partner info, unpair option

---

## Project Structure

```
togetherremind/
├── app/                    # Flutter application
│   ├── lib/
│   │   ├── models/         # Hive data models (Reminder, Partner, User, Quiz, etc.)
│   │   ├── screens/        # UI screens (Home, Inbox, Settings, Pairing, Games)
│   │   ├── services/       # Core services (Notification, Reminder, Poke, Storage)
│   │   ├── widgets/        # Reusable UI components
│   │   └── main.dart       # App entry point
│   ├── ios/                # iOS native configuration
│   ├── android/            # Android native configuration
│   └── pubspec.yaml        # Dependencies
├── functions/              # Firebase Cloud Functions
│   └── index.js            # Cloud function implementations
├── database.rules.json     # RTDB security rules (pairing codes)
├── docs/                   # Detailed documentation
│   ├── SETUP.md           # Development setup, Firebase configuration, testing
│   ├── ARCHITECTURE.md    # Data models, architecture details, feature specs
│   └── TROUBLESHOOTING.md # Common issues, debugging, best practices
├── mockups/                # UI/UX design mockups (HTML)
├── README.md               # This file (user-facing documentation)
├── CLAUDE.md               # Technical development guide (AI assistant reference)
└── PRD.md                  # Product Requirements Document
```

---

## Privacy & Security

- 🔒 All reminder data stored **locally** on device
- 🔒 No cloud database or server-side storage
- 🔒 Push tokens transmitted via encrypted QR + FCM
- 🔒 Pairing codes expire after 10 minutes (1B+ combinations)
- 🔒 Hive supports optional AES encryption
- 🔒 No analytics or tracking (MVP)

**Bundle ID:** `com.togetherremind.togetherremind2` (changed after security remediation)

**User Controls:** Export data, clear history, unpair partner

---

## Current Status

**Stage:** MVP Complete, Pre-Launch Testing
**Last Updated:** 2025-11-11

### Production Ready
- ✅ Core features implemented and tested
- ✅ Push notifications working on iOS + Android
- ✅ Cloud Functions deployed and verified
- ✅ Real device testing (iPhone + Android)

### Technical Status
- ✅ iOS + Android tested on physical devices
- ✅ Cloud Functions deployed (us-central1)
- ✅ APNs configured, notification categories
- ✅ FCM integrated, core library desugaring

### Roadmap
- **Phase 2:** Voice input, custom sounds, smart time defaults
- **Phase 3:** Home screen widgets, family mode (>2 people), cloud sync

---

## Documentation

- **[docs/SETUP.md](./docs/SETUP.md)** - Development setup, Firebase configuration, two-device testing, commands
- **[docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md)** - Data models, push notification flow, device pairing, feature specifications
- **[docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md)** - Common issues, debugging strategies, error handling patterns
- **[CLAUDE.md](./CLAUDE.md)** - Technical development guide (AI assistant reference)
- **[PRD.md](./PRD.md)** - Product requirements, user stories, success metrics
- **[Mockups](./mockups/)** - Interactive HTML design previews

---

## Resources

- [Flutter Docs](https://docs.flutter.dev/)
- [Firebase Flutter](https://firebase.flutter.dev/)
- [Hive Docs](https://docs.hivedb.dev/)
- [pub.dev](https://pub.dev/)

---

## Contributing

This is a personal/concept project. Ideas and feedback welcome!

**Contact:** Joakim Achrén
**Stage:** Concept / Pre-seed

---

**Built with ❤️ for meaningful relationships**

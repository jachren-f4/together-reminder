# Setup Guide

Complete setup instructions for TogetherRemind development.

---

## Firebase Configuration

**Required for push notifications:**

### 1. Create Firebase Project
- Visit [Firebase Console](https://console.firebase.google.com/)
- Upgrade to **Blaze plan** (required for Cloud Functions)

### 2. Add iOS App
- Bundle ID: `com.togetherremind.togetherremind`
- Download `GoogleService-Info.plist` → `ios/Runner/`
- Upload APNs .p8 key in Firebase Console → Cloud Messaging

### 3. Add Android App
- Package name: `com.togetherremind.togetherremind`
- Download `google-services.json` → `android/app/`

### 4. Enable Realtime Database
- In Firebase Console → Realtime Database → Create Database
- Choose region (preferably same as Cloud Functions)
- Start in **locked mode** (rules deployed via `database.rules.json`)

### 5. Deploy Cloud Functions & Database Rules
```bash
firebase deploy --only functions,database
```

### 6. Xcode Capabilities (iOS only)
- Open `ios/Runner.xcworkspace`
- Enable: Push Notifications
- Enable: Background Modes → Remote notifications

---

## Credential Management

### Security Warnings

**NEVER COMMIT THESE FILES:**
- `ios/Runner/GoogleService-Info.plist`
- `android/app/google-services.json`

**These files contain sensitive API keys and project identifiers.**

### Gitignore Configuration

Ensure your `.gitignore` includes:
```
# Firebase config files (NEVER COMMIT)
ios/Runner/GoogleService-Info.plist
android/app/google-services.json

# Firebase debug files
ios/Runner/google-services-info.plist
android/app/src/debug/google-services.json
android/app/src/release/google-services.json
```

### Initial Setup
1. Download credential files from Firebase Console
2. Place in correct directories (see Firebase Configuration above)
3. Verify files are gitignored: `git status` should NOT show them

### Team Collaboration
- Share credentials via secure channel (1Password, LastPass, etc.)
- **Never** share via email, Slack, or commit to git
- Each team member downloads their own copy from Firebase Console

### CI/CD Setup
- Store credentials as encrypted secrets in CI environment
- Use environment-specific Firebase projects (dev/staging/prod)
- Rotate keys regularly if exposed

---

## Two-Device Testing

### 1. Disable Mock Data
```dart
// lib/config/dev_config.dart
static const bool enableMockPairing = false;
```

### 2. Install on Both Devices
```bash
flutter run -d <device-a-id>  # Terminal 1
flutter run -d <device-b-id>  # Terminal 2
```

### 3. Pair Devices

**Option 1: In-Person (QR Code)**
- Device A: Pairing screen → "In Person" tab → QR code auto-displays
- Device B: Pairing screen → "In Person" tab → "Scan Partner's Code" → scan QR
- Both devices save partner info locally

**Option 2: Remote (6-Character Code)**
- Device A: Pairing screen → "Remote" tab → "Generate Pairing Code"
- Device A: Share code via text/messaging apps
- Device B: Pairing screen → "Remote" tab → "Enter Partner's Code" → type code
- Both devices save partner info (code expires after 10 minutes or first use)

### 4. Send Test Reminder
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

**Last Updated:** 2025-11-11

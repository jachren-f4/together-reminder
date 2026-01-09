# Notifications

## Quick Reference

| Item | Location |
|------|----------|
| Notification Service | `lib/services/notification_service.dart` |
| Foreground Banner | `lib/widgets/foreground_notification_banner.dart` |
| Poke Service | `lib/services/poke_service.dart` |
| User Profile Service | `lib/services/user_profile_service.dart` |
| Cloud Functions | `functions/src/index.ts` |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Push Notification Flow                       │
│                                                                  │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│   │    FCM       │    │ Cloud Funcs  │    │  APNs (iOS)      │  │
│   │  (Android)   │    │  (Triggers)  │    │  via FCM         │  │
│   └──────────────┘    └──────────────┘    └──────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    NotificationService                           │
│   ┌─────────────┐  ┌─────────────┐  ┌────────────────────────┐  │
│   │ Foreground  │  │ Background  │  │ Local Notifications    │  │
│   │ Handler     │  │ Handler     │  │ (flutter_local_notif)  │  │
│   └─────────────┘  └─────────────┘  └────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Notification Types

| Type | Channel | Purpose |
|------|---------|---------|
| `pairing` | - | Partner pairing confirmation |
| `poke` | `poke_channel` | Instant pokes from partner |
| `reminder` | `reminder_channel` | Scheduled reminders |

---

## Initialization

### Startup Sequence
```dart
// In main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(...);
  await NotificationService.initialize();  // Sets up handlers, NOT permissions
  runApp(MyApp());
}
```

### Deferred Permission Request
Permissions are NOT requested at initialization. They're deferred until contextually relevant moments:

1. **After completing a classic quiz** - Shows `NotificationPermissionPopup` explaining value, then system prompt
2. **When sending a poke/reminder** - User understands they need notifications to remind partner

```dart
// In quiz_match_game_screen.dart - after quiz completion
final isAuthorized = await NotificationService.isAuthorized();
if (!isAuthorized && mounted) {
  final shouldEnable = await showDialog<bool>(
    context: context,
    builder: (context) => const NotificationPermissionPopup(),
  );
  if (shouldEnable == true) {
    await NotificationService.requestPermission();
  }
}
```

**Rationale:** Request permission when user understands the value (waiting for partner's quiz results).

---

## Key Rules

### 1. Set App Context for Foreground Banners
```dart
// In main.dart after MaterialApp builds
@override
void initState() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    NotificationService.setAppContext(context);
  });
}
```

### 2. Web Platform Skip
FCM doesn't work in browser debug mode:

```dart
static Future<void> initialize() async {
  if (kIsWeb) {
    // Skip FCM initialization (service workers not supported)
    return;
  }
  // ... normal initialization
}
```

### 3. Token Sync on Auth
Sync push token to server after authentication:

```dart
// After successful login/signup
await NotificationService.syncTokenToServer();
```

### 4. Background Handler is Top-Level
The background handler must be a top-level function:

```dart
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle message types
  if (message.data['type'] == 'pairing') {
    await StorageService.init();  // Hive may not be initialized
    // ... handle pairing
  }
}
```

### 5. Pairing Callback Pattern
Register callback for pairing completion:

```dart
// In pairing_screen.dart
NotificationService.onPairingComplete = (name, token) {
  // Handle partner connection
  _completePairing(name, token);
};
```

---

## Foreground Notification Banner

In-app notification when app is open:

```dart
ForegroundNotificationBanner.show(
  context,
  title: 'Poke',
  message: 'Your partner is thinking of you!',
  emoji: '💫',
  onTap: () => _navigateToResponse(),
);
```

**Features:**
- Slides down from top with animation
- Auto-dismisses after 4 seconds
- Haptic feedback on show
- Tappable for navigation

---

## Android Notification Channels

```dart
// Created in initialize()
const AndroidNotificationChannel reminderChannel = AndroidNotificationChannel(
  'reminder_channel',
  'Reminders',
  description: 'Reminders from your partner',
  importance: Importance.max,
);

const AndroidNotificationChannel pokeChannel = AndroidNotificationChannel(
  'poke_channel',
  'Pokes',
  description: 'Instant pokes from your partner',
  importance: Importance.max,
);
```

---

## Message Handling

### Foreground Message
```dart
FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

static Future<void> _handleForegroundMessage(RemoteMessage message) async {
  // Check type and handle
  if (message.data['type'] == 'pairing') {
    onPairingComplete?.call(partnerName, partnerToken);
    return;
  }

  if (message.data['type'] == 'poke') {
    await PokeService.handleReceivedPoke(...);
    // Show in-app banner
    if (_appContext != null && _appContext!.mounted) {
      ForegroundNotificationBanner.show(...);
    }
    return;
  }

  // Regular reminder
  await _saveReceivedReminder(message);
  ForegroundNotificationBanner.show(...);
}
```

### Background Message
```dart
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Must initialize Hive since app may not be running
  await StorageService.init();

  if (message.data['type'] == 'pairing') {
    // Save partner immediately
    await storage.savePartner(partner);
    return;
  }

  if (message.data['type'] == 'poke') {
    await PokeService.handleReceivedPoke(...);
    return;
  }

  await NotificationService._saveReceivedReminder(message);
}
```

---

## Token Management

### Get Token
```dart
static Future<String?> getToken() async {
  if (kIsWeb) {
    // Return fake token for web testing
    return 'web_token_${DateTime.now().millisecondsSinceEpoch}';
  }
  return await _fcm.getToken();
}
```

### Token Refresh
```dart
// Registered in initialize()
_fcm.onTokenRefresh.listen(_onTokenRefresh);

static Future<void> _onTokenRefresh(String token) async {
  await userProfileService.syncPushToken(token, platform);
}
```

---

## Common Bugs & Fixes

### 1. Foreground Banner Not Showing
**Symptom:** Push received but no in-app banner.

**Cause:** App context not set.

**Fix:** Set context in main:
```dart
NotificationService.setAppContext(context);
```

### 2. Permission Never Requested
**Symptom:** Notifications not working on fresh install.

**Cause:** `requestPermission()` not called.

**Fix:** Call from LP intro overlay:
```dart
await NotificationService.requestPermission();
```

### 3. Background Handler Crashes
**Symptom:** App crashes when receiving background notification.

**Cause:** Hive not initialized in background.

**Fix:** Initialize in background handler:
```dart
await StorageService.init();  // First line in handler
```

### 4. Web Blank Screen
**Symptom:** Web app shows blank screen after FCM call.

**Cause:** FCM service workers not supported in debug.

**Fix:** Check platform before FCM calls:
```dart
if (kIsWeb) return;
```

### 5. Partner Pairing Not Detected
**Symptom:** Partner pairs but waiting screen doesn't update.

**Cause:** Callback not registered.

**Fix:** Register callback:
```dart
NotificationService.onPairingComplete = _handlePairing;
```

---

## Cloud Functions Integration

### Send Pairing Confirmation
```dart
static Future<void> sendPairingConfirmation({
  required String partnerToken,
  required String myName,
  required String myPushToken,
}) async {
  final functions = FirebaseFunctions.instance;
  final callable = functions.httpsCallable('sendPairingConfirmation');

  await callable.call({
    'partnerToken': partnerToken,
    'myName': myName,
    'myPushToken': myPushToken,
  });
}
```

---

## Notification Actions

### Android
```dart
actions: isPoke
    ? [
        AndroidNotificationAction('poke_back', '❤️ Send Back'),
        AndroidNotificationAction('acknowledge', '🙂 Smile'),
      ]
    : [
        AndroidNotificationAction('done', 'Done'),
        AndroidNotificationAction('snooze', 'Snooze'),
      ],
```

### iOS
```dart
categoryIdentifier: isPoke ? 'POKE_CATEGORY' : 'REMINDER_CATEGORY',
```

### Action Handler
```dart
static void _onNotificationTapped(NotificationResponse response) {
  switch (response.actionId) {
    case 'done':
      _storage.updateReminderStatus(response.payload ?? '', 'done');
      break;
    case 'snooze':
      _storage.updateReminderStatus(
        response.payload ?? '',
        'snoozed',
        snoozedUntil: DateTime.now().add(const Duration(hours: 1)),
      );
      break;
    case 'poke_back':
      PokeService.sendPokeBack(response.payload ?? '');
      break;
    case 'acknowledge':
      _storage.updateReminderStatus(response.payload ?? '', 'acknowledged');
      break;
  }
}
```

---

## File Reference

| File | Purpose |
|------|---------|
| `notification_service.dart` | FCM setup, message handling |
| `foreground_notification_banner.dart` | In-app notification overlay |
| `poke_service.dart` | Poke sending/receiving |
| `user_profile_service.dart` | Token sync to server |
| `storage_service.dart` | Reminder persistence |

# Notification Permission Popup Implementation Plan

## Overview
Show a contextual notification permission popup after users complete their first (and subsequent) classic quizzes, until they grant notification permission.

## Design Decision
Use **V2: Minimal** design from mockup - clean, single focused message.

## Logic Flow

```
User completes classic quiz
    ↓
Check NotificationService.getNotificationSettings()
    ↓
authorized? ─── YES ──→ Navigate to waiting screen
    │
    NO
    ↓
Show NotificationPermissionPopup
    ↓
User taps "Turn On" ──→ Call requestPermission() ──→ Shows native iOS dialog
    │
    ↓
User taps "Not Now" ──→ Skip (will ask again next quiz)
    ↓
Navigate to waiting screen
```

## Files to Create/Modify

### 1. NEW: `lib/widgets/notification_permission_popup.dart`
- Modal popup widget matching Us 2.0 style (V2 minimal design)
- Bell icon with coral gradient
- Title: "Don't Miss a Moment"
- Body: "We'll let you know when your partner finishes their quiz so you can see your results together."
- Primary button: "Turn On Notifications"
- Secondary button: "Not Now"
- Returns `bool` - true if user tapped primary button

### 2. MODIFY: `lib/services/notification_service.dart`
Add new static method to check permission status:

```dart
/// Check if notifications are authorized (without requesting)
static Future<bool> isAuthorized() async {
  if (kIsWeb) return true; // Web doesn't need permission

  final settings = await _fcm.getNotificationSettings();
  return settings.authorizationStatus == AuthorizationStatus.authorized;
}
```

### 3. MODIFY: `lib/screens/quiz_match_game_screen.dart`
In `_submitAnswers()` method, before navigating to waiting screen (~line 298-312):

```dart
// Before: Direct navigation
Navigator.of(context).pushReplacement(
  MaterialPageRoute(
    builder: (context) => QuizMatchWaitingScreen(...),
  ),
);

// After: Check permission, possibly show popup, then navigate
if (widget.quizType == 'classic') {
  final isAuthorized = await NotificationService.isAuthorized();
  if (!isAuthorized && mounted) {
    final shouldEnable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const NotificationPermissionPopup(),
    );

    if (shouldEnable == true) {
      await NotificationService.requestPermission();
    }
  }
}

// Then navigate to waiting screen
if (mounted) {
  Navigator.of(context).pushReplacement(...);
}
```

## Implementation Order

1. **NotificationService.isAuthorized()** - Add the permission check method
2. **NotificationPermissionPopup** - Create the popup widget
3. **quiz_match_game_screen.dart** - Integrate the popup into quiz completion flow

## Edge Cases

| Case | Behavior |
|------|----------|
| Web platform | Skip popup (web doesn't need permission the same way) |
| Affirmation quiz | Skip popup (only show for classic) |
| Already authorized | Skip popup |
| User taps "Not Now" | Navigate to waiting, ask again next classic quiz |
| User denies native dialog | Navigate to waiting, ask again next classic quiz |
| User grants permission | Navigate to waiting, never show popup again |
| User grants via Settings app | Detected automatically, never show popup |

## Testing Checklist

- [ ] Popup appears after first classic quiz completion (if not authorized)
- [ ] Popup does NOT appear after affirmation quiz
- [ ] Popup does NOT appear if already authorized
- [ ] "Turn On" triggers native iOS permission dialog
- [ ] "Not Now" dismisses and navigates to waiting screen
- [ ] Popup appears again next classic quiz if still not authorized
- [ ] Popup stops appearing once authorized (via dialog or Settings)
- [ ] Android 13+ shows popup (needs runtime permission)
- [ ] Android 12 and below skips popup (auto-granted)
- [ ] Web skips popup entirely

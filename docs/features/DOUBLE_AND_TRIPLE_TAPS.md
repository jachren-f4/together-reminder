# Hidden Debug Triggers (Double/Triple Taps)

This document lists all hidden debug features activated by tap gestures throughout the app.

## Summary

| Screen | Trigger | Action | Release Risk |
|--------|---------|--------|--------------|
| Home Screen | Double-tap greeting | Opens DebugMenu | Medium |
| Home Screen (Us2) | Double-tap logo | Opens DebugMenu | Medium |
| Value Carousel | Double-tap | Opens DebugMenu | Medium |
| Paywall Screen | Triple-tap title | Grants free subscription | **HIGH** |
| Paywall Screen | Tap bug icon | Toggle debug overlay | Low |

---

## Detailed Breakdown

### 1. Home Screen - Debug Menu

**File:** `app/lib/screens/home_screen.dart`

**Trigger:** Double-tap on greeting text ("Good morning, [Name]")

**Lines:** 960, 2125 (two separate build paths for different brands)

**Action:** Opens the full DebugMenu dialog with 5 tabs:
- Overview (app state, user info)
- Quests (daily quest state)
- Sessions (quiz sessions)
- LP & Sync (love points, sync status)
- Actions (reset data, inject test data, force unlocks)

**Code:**
```dart
onDoubleTap: () async {
  final result = await showDialog<String>(
    context: context,
    builder: (context) => const DebugMenu(),
  );
  // ...
}
```

**Risk:** Medium - Exposes internal state and allows data manipulation

---

### 2. Home Screen (Us2 Brand) - Debug Menu via Logo

**File:** `app/lib/widgets/brand/us2/us2_home_content.dart`

**Trigger:** Double-tap on the Us2 logo at top of home screen

**Line:** 108

**Action:** Calls `onDebugTap` callback which opens DebugMenu

**Code:**
```dart
Us2Logo(onDoubleTap: onDebugTap),
```

**Implementation in Us2Logo:** `app/lib/widgets/brand/us2/us2_logo.dart:52`

**Risk:** Medium - Same as above

---

### 3. Value Carousel Screen (Onboarding) - Debug Menu

**File:** `app/lib/screens/onboarding/value_carousel_screen.dart`

**Trigger:** Double-tap anywhere on the screen

**Line:** 234

**Action:** Opens DebugMenu

**Code:**
```dart
onDoubleTap: () {
  showDialog(
    context: context,
    builder: (context) => const DebugMenu(),
  );
},
```

**Risk:** Medium - Available during onboarding flow

---

### 4. Paywall Screen - Triple-Tap Subscription Bypass

**File:** `app/lib/screens/paywall_screen.dart`

**Trigger:** Triple-tap on the paywall title text

**Lines:** 146-160 (handler), 835 (GestureDetector)

**Action:**
1. Shows confirmation dialog
2. Calls API to grant real subscription to couple
3. Marks couple as premium in database
4. Navigates past paywall

**Code:**
```dart
void _handleTitleTap() {
  _tapCount++;
  _tapTimer?.cancel();
  _tapTimer = Timer(const Duration(milliseconds: 500), () {
    _tapCount = 0;
  });

  if (_tapCount >= 3) {
    _tapCount = 0;
    _activateDevBypass();
  }
}
```

**API Call:** `POST /api/subscription/activate` with `productId: 'dev_bypass_test'`

**Risk:** **HIGH** - This works in release builds and grants real subscriptions. A user who discovers this can bypass payment entirely.

---

### 5. Paywall Screen - Debug Overlay Toggle

**File:** `app/lib/screens/paywall_screen.dart`

**Trigger:** Tap on small bug icon in bottom-left corner

**Line:** 1222

**Action:** Toggles debug information overlay showing:
- RevenueCat configuration status
- SDK initialization state
- Offerings loaded status
- Current package info
- Error messages

**Code:**
```dart
onTap: () => setState(() => _showDebugOverlay = !_showDebugOverlay),
```

**Risk:** Low - Only shows diagnostic info, no actions available

---

## Compile-Time Dev Bypasses

These are not tap-triggered but are related debug mechanisms in `app/lib/config/dev_config.dart`:

| Flag | Default | Effect |
|------|---------|--------|
| `skipAuthInDev` | `false` | Bypasses entire auth flow (simulators only) |
| `skipOtpVerificationInDev` | `true` | Skips OTP, uses password auth |
| `skipSubscriptionCheckInDev` | `true` | Returns `isPremium = true` in debug builds |

**Safety:** These flags have guards:
- `skipAuthInDev` only works on simulators/emulators/web, never physical devices
- `skipSubscriptionCheckInDev` only works in `kDebugMode`
- `validateProductionBuild()` crashes the app if bypass flags are enabled in release

---

## Recommendations

### Critical (Do Before Release)

1. **Paywall Triple-Tap:** Gate behind `kDebugMode` or remove entirely
   ```dart
   if (kDebugMode && _tapCount >= 3) {
     _activateDevBypass();
   }
   ```

2. **Paywall Bug Icon:** Hide in release builds
   ```dart
   if (kDebugMode) _buildDebugButton(),
   ```

### Medium Priority

3. **DebugMenu triggers:** Consider gating all double-tap debug menu access behind `kDebugMode`:
   ```dart
   onDoubleTap: kDebugMode ? () => showDialog(...) : null,
   ```

4. **Alternative approach:** Require a secret sequence (e.g., 5 taps within 2 seconds, or tap pattern) instead of simple double/triple tap

### Low Priority

5. Add analytics event when debug features are accessed in release builds (to detect if users find them)

---

## Files to Modify

| File | Change Needed |
|------|---------------|
| `app/lib/screens/paywall_screen.dart` | Gate triple-tap and bug icon behind `kDebugMode` |
| `app/lib/screens/home_screen.dart` | Gate double-tap behind `kDebugMode` |
| `app/lib/widgets/brand/us2/us2_home_content.dart` | Gate double-tap behind `kDebugMode` |
| `app/lib/screens/onboarding/value_carousel_screen.dart` | Gate double-tap behind `kDebugMode` |

---

## Testing Checklist

Before release, verify:

- [ ] Triple-tap on paywall does NOT grant subscription in release build
- [ ] Bug icon on paywall is NOT visible in release build
- [ ] Double-tap on home screen does NOT open debug menu in release build
- [ ] Double-tap on Us2 logo does NOT open debug menu in release build
- [ ] Double-tap during onboarding does NOT open debug menu in release build
- [ ] `validateProductionBuild()` passes without crashing

---

*Last Updated: 2025-01-27*

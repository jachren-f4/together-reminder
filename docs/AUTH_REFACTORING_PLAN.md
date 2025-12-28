# Auth Flow Refactoring Plan

This document outlines the comprehensive refactoring plan for sign-up and sign-in flows in the Liia app.

---

## Implementation Status

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Add Production Safety Guards | ✅ Complete |
| 2 | Separate Begin vs Sign-In from OnboardingScreen | ✅ Complete |
| 3 | Update NameEntryScreen | ✅ Complete |
| 4 | Fix AuthScreen Navigation | ✅ Complete |
| 5 | Update OtpVerificationScreen | ✅ Complete |
| 6 | Environment Variables for Dev IDs | ✅ Complete |
| 7 | Final Build and Verification | ✅ Complete |

**All phases implemented on 2024-12-16.**

---

## Table of Contents

1. [Current Problems](#current-problems)
2. [Target Architecture](#target-architecture)
3. [Implementation Phases](#implementation-phases)
   - [Phase 1: Add Production Safety Guards](#phase-1-add-production-safety-guards)
   - [Phase 2: Separate Begin vs Sign-In from OnboardingScreen](#phase-2-separate-begin-vs-sign-in-from-onboardingscreen)
   - [Phase 3: Update NameEntryScreen](#phase-3-update-nameentryscreen)
   - [Phase 4: Fix AuthScreen Navigation](#phase-4-fix-authscreen-navigation)
   - [Phase 5: Update OtpVerificationScreen](#phase-5-update-otpverificationscreen)
   - [Phase 6: Environment Variables for Dev IDs](#phase-6-environment-variables-for-dev-ids)
   - [Phase 7: Final Build and Verification](#phase-7-final-build-and-verification)
4. [Files to Modify](#files-to-modify)
5. [Full Testing Matrix](#full-testing-matrix)

---

## Current Problems

| Issue | Severity | Impact |
|-------|----------|--------|
| Dev mode could ship to production | CRITICAL | Security vulnerability - dev bypass flags work on physical devices |
| Name asked twice in dev mode | HIGH | Poor UX, confusing flow |
| Sign-in asks for name (shouldn't) | HIGH | Wrong flow for returning users |
| `pending_user_name` orphaned | MEDIUM | Dead code, maintenance debt |
| Silent signup failures | MEDIUM | Users stuck in broken state |
| Hardcoded dev user IDs | LOW | Security hygiene |

### Current Broken Flows

**Dev Mode Flow (broken):**
```
NameEntryScreen (1st) → AuthScreen → NameEntryScreen (2nd!) → Home
```

**Sign-In Flow (broken):**
```
OnboardingScreen → NameEntryScreen → AuthScreen → OtpVerificationScreen → Home
                   ↑ WHY? Returning users already have a name!
```

---

## Target Architecture

### Flow Diagrams

**Production - New User (Begin):**
```
OnboardingScreen → NameEntryScreen → AuthScreen (email) → OtpVerificationScreen → PairingScreen → Home
                   [stores name]     [sends OTP]         [verifies + completeSignup]
```

**Production - Returning User (Sign In):**
```
OnboardingScreen → AuthScreen (email) → OtpVerificationScreen → Home
                   [sends OTP]         [verifies, checks existing user]
                   [NO name entry - user already has one]
```

**Dev Mode - New User:**
```
OnboardingScreen → NameEntryScreen → AuthScreen (auto-email) → [skip OTP] → PairingScreen → Home
                   [stores name]     [devSignInWithEmail()]
```

**Dev Mode - Returning User:**
```
OnboardingScreen → AuthScreen (auto-email) → [skip OTP] → Home
                   [devSignInWithEmail()]
                   [NO name entry]
```

---

## Implementation Phases

---

### Phase 1: Add Production Safety Guards

**Goal:** Prevent dev mode flags from ever shipping to production.

**File: `lib/config/dev_config.dart`**

Add validation method that crashes the app if dev flags are enabled in release mode:

```dart
import 'package:flutter/foundation.dart';

class DevConfig {
  /// CRITICAL: Call this on app startup to prevent dev flags in production
  /// Throws StateError in release builds if dev flags are enabled
  static void validateProductionSafety() {
    if (kReleaseMode) {
      if (skipAuthInDev || skipOtpVerificationInDev) {
        throw StateError(
          'CRITICAL: Dev auth bypass flags are enabled in release build! '
          'Set skipAuthInDev and skipOtpVerificationInDev to false in dev_config.dart'
        );
      }
    }
  }

  // Existing flags - document the danger
  /// WARNING: Only works on simulators/emulators. Safe for production.
  static const bool skipAuthInDev = true;

  /// DANGER: Works on ALL devices including physical.
  /// MUST be false before App Store release!
  static const bool skipOtpVerificationInDev = true;
}
```

**File: `lib/main.dart`**

Add validation call at startup:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CRITICAL: Crash early if dev flags are enabled in release
  DevConfig.validateProductionSafety();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // ... rest of initialization
}
```

#### Phase 1 Testing Tasks

- [ ] **Test 1.1:** Run app in debug mode with `skipOtpVerificationInDev = true` → App should launch normally
- [ ] **Test 1.2:** Run app in debug mode with `skipOtpVerificationInDev = false` → App should launch normally
- [ ] **Test 1.3:** Build release with `skipOtpVerificationInDev = true` → App should crash on launch with StateError
- [ ] **Test 1.4:** Build release with `skipOtpVerificationInDev = false` → App should launch normally

```bash
# Test 1.3 command (should fail):
flutter run --release --dart-define=BRAND=togetherRemind

# Test 1.4 command (after setting flags to false):
flutter run --release --dart-define=BRAND=togetherRemind
```

---

### Phase 2: Separate Begin vs Sign-In from OnboardingScreen

**Goal:** Route new users through name entry, returning users directly to email.

**File: `lib/screens/onboarding_screen.dart`**

Update navigation handlers:

```dart
void _handleBegin() {
  // New user flow - needs name entry first
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => const NameEntryScreen(isNewUser: true),
    ),
  );
}

void _handleSignIn() {
  // Returning user flow - skip name, go straight to email
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => const AuthScreen(isNewUser: false),
    ),
  );
}
```

#### Phase 2 Testing Tasks

- [ ] **Test 2.1:** Tap "BEGIN" → Should navigate to NameEntryScreen
- [ ] **Test 2.2:** Tap "Sign in" → Should navigate to AuthScreen (NOT NameEntryScreen)
- [ ] **Test 2.3:** Verify NameEntryScreen receives `isNewUser: true`
- [ ] **Test 2.4:** Verify AuthScreen receives `isNewUser: false` from Sign in path

---

### Phase 3: Update NameEntryScreen

**Goal:** Clean up name entry to only store name and pass `isNewUser` forward.

**File: `lib/screens/name_entry_screen.dart`**

Add `isNewUser` parameter:

```dart
class NameEntryScreen extends StatefulWidget {
  final bool isNewUser;

  const NameEntryScreen({
    super.key,
    this.isNewUser = true,  // Default to new user for backwards compat
  });

  @override
  State<NameEntryScreen> createState() => _NameEntryScreenState();
}
```

Update `_submitName()` to remove auth check and pass `isNewUser`:

```dart
Future<void> _submitName() async {
  if (!_validateName()) return;

  final name = _nameController.text.trim();

  // Store name for later use by completeSignup()
  await _secureStorage.write(key: 'pending_user_name', value: name);

  if (!mounted) return;

  // Always go to AuthScreen after name entry
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => AuthScreen(isNewUser: widget.isNewUser),
    ),
  );
}
```

**Remove:** The `isAuthenticated` check (lines ~54-60) - name entry should never check auth state.

#### Phase 3 Testing Tasks

- [ ] **Test 3.1:** Enter name and submit → Should store name in secure storage
- [ ] **Test 3.2:** Enter name and submit → Should navigate to AuthScreen with `isNewUser: true`
- [ ] **Test 3.3:** Verify `pending_user_name` is stored correctly (check via debug menu)
- [ ] **Test 3.4:** Verify no auth check happens on this screen (no redirect to home)

---

### Phase 4: Fix AuthScreen Navigation

**Goal:** Fix dev mode to not navigate back to NameEntryScreen, handle `isNewUser` properly.

**File: `lib/screens/auth_screen.dart`**

Add `isNewUser` parameter:

```dart
class AuthScreen extends StatefulWidget {
  final bool isNewUser;

  const AuthScreen({
    super.key,
    this.isNewUser = true,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}
```

Fix dev mode sign-in handler:

```dart
Future<void> _handleDevModeSignIn() async {
  setState(() => _isLoading = true);

  try {
    final result = await _authService.devSignInWithEmail(_emailController.text);

    if (!result.success) {
      _showError(result.error ?? 'Dev sign-in failed');
      return;
    }

    if (!mounted) return;

    if (widget.isNewUser) {
      // New user in dev mode - complete signup with stored name
      final pendingName = await _secureStorage.read(key: 'pending_user_name');
      if (pendingName != null && pendingName.isNotEmpty) {
        await _authService.completeSignup(pendingName);
        await _secureStorage.delete(key: 'pending_user_name');
      }

      // Go to pairing
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const PairingScreen()),
        (route) => false,
      );
    } else {
      // Returning user in dev mode - go straight to home
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const NewHomeScreen()),
        (route) => false,
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

Fix production sign-in to pass `isNewUser`:

```dart
Future<void> _handleProductionSignIn() async {
  final result = await _authService.signInWithEmail(_emailController.text);

  if (result.success) {
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OtpVerificationScreen(
          email: _emailController.text,
          isNewUser: widget.isNewUser,
        ),
      ),
    );
  } else {
    _showError(result.error ?? 'Failed to send verification code');
  }
}
```

**Remove:** Navigation back to `NameEntryScreen` after dev sign-in (the problematic lines ~72-84).

#### Phase 4 Testing Tasks

- [ ] **Test 4.1:** Dev mode + new user → Should go to PairingScreen (not NameEntryScreen again)
- [ ] **Test 4.2:** Dev mode + returning user → Should go to NewHomeScreen directly
- [ ] **Test 4.3:** Dev mode + new user → Should call completeSignup with stored name
- [ ] **Test 4.4:** Production mode + new user → Should go to OtpVerificationScreen with `isNewUser: true`
- [ ] **Test 4.5:** Production mode + returning user → Should go to OtpVerificationScreen with `isNewUser: false`
- [ ] **Test 4.6:** Dev sign-in failure → Should show error, stay on screen

---

### Phase 5: Update OtpVerificationScreen

**Goal:** Handle `isNewUser` properly, make failures block navigation.

**File: `lib/screens/otp_verification_screen.dart`**

Add `isNewUser` parameter:

```dart
class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final bool isNewUser;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.isNewUser = true,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}
```

Update verification to handle both flows and block on failures:

```dart
Future<void> _verifyOtp() async {
  setState(() => _isLoading = true);

  try {
    final result = await _authService.verifyOtp(widget.email, _otpController.text);

    if (!result.success) {
      _showError(result.error ?? 'Invalid verification code');
      return;  // BLOCK - don't continue
    }

    if (!mounted) return;

    if (widget.isNewUser) {
      // Complete signup with stored name
      final pendingName = await _secureStorage.read(key: 'pending_user_name');

      if (pendingName == null || pendingName.isEmpty) {
        _showError('Name not found. Please restart signup.');
        return;  // BLOCK - don't continue without name
      }

      final signupResult = await _authService.completeSignup(pendingName);

      if (!signupResult.success) {
        _showError(signupResult.error ?? 'Failed to complete signup');
        return;  // BLOCK - don't continue if signup fails
      }

      // Clean up stored name
      await _secureStorage.delete(key: 'pending_user_name');

      if (!mounted) return;

      // New user - go to pairing
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const PairingScreen()),
        (route) => false,
      );
    } else {
      // Returning user - go to home
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const NewHomeScreen()),
        (route) => false,
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

#### Phase 5 Testing Tasks

- [ ] **Test 5.1:** Wrong OTP code → Should show error, stay on screen
- [ ] **Test 5.2:** Correct OTP + new user → Should call completeSignup, go to PairingScreen
- [ ] **Test 5.3:** Correct OTP + returning user → Should go to NewHomeScreen (no completeSignup)
- [ ] **Test 5.4:** Correct OTP + new user + missing name → Should show error, stay on screen
- [ ] **Test 5.5:** Correct OTP + new user + completeSignup fails → Should show error, stay on screen
- [ ] **Test 5.6:** Verify `pending_user_name` is deleted after successful new user signup

---

### Phase 6: Environment Variables for Dev IDs

**Goal:** Remove hardcoded dev user IDs from source code.

**File: `lib/config/dev_config.dart`**

Replace hardcoded IDs with environment variables:

```dart
/// Dev user IDs - passed via --dart-define, never hardcoded
/// Usage: flutter run --dart-define=DEV_USER_ID_1=abc123 --dart-define=DEV_USER_ID_2=def456
static String get devUserId1 => const String.fromEnvironment(
  'DEV_USER_ID_1',
  defaultValue: '',  // Empty = disabled
);

static String get devUserId2 => const String.fromEnvironment(
  'DEV_USER_ID_2',
  defaultValue: '',
);

/// Check if dev user IDs are configured
static bool get hasDevUserIds => devUserId1.isNotEmpty && devUserId2.isNotEmpty;
```

Update any code that references hardcoded IDs to use these getters.

#### Phase 6 Testing Tasks

- [ ] **Test 6.1:** Run without `--dart-define` → `hasDevUserIds` should be false
- [ ] **Test 6.2:** Run with `--dart-define=DEV_USER_ID_1=test1 --dart-define=DEV_USER_ID_2=test2` → IDs should be accessible
- [ ] **Test 6.3:** Verify no hardcoded user IDs remain in codebase (grep search)

```bash
# Search for hardcoded UUIDs that might be user IDs
grep -r "test-user\|dev-user\|[0-9a-f]\{8\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{12\}" app/lib/
```

---

### Phase 7: Final Build and Verification

**Goal:** Verify all changes work together, app builds successfully.

#### Phase 7 Testing Tasks

**Build Verification:**

- [ ] **Test 7.1:** Flutter analyze passes with no errors
  ```bash
  cd app && flutter analyze
  ```

- [ ] **Test 7.2:** Debug build succeeds (Android)
  ```bash
  flutter build apk --debug --flavor togetherremind --dart-define=BRAND=togetherRemind
  ```

- [ ] **Test 7.3:** Debug build succeeds (iOS)
  ```bash
  flutter build ios --debug --dart-define=BRAND=togetherRemind --no-codesign
  ```

- [ ] **Test 7.4:** Release build succeeds with dev flags OFF
  ```bash
  # First set skipOtpVerificationInDev = false in dev_config.dart
  flutter build apk --release --flavor togetherremind --dart-define=BRAND=togetherRemind
  ```

**End-to-End Flow Verification:**

- [ ] **Test 7.5:** Complete new user signup flow (dev mode)
  1. Launch app fresh
  2. Tap "BEGIN"
  3. Enter name
  4. See auto-generated email
  5. Tap continue
  6. Arrive at PairingScreen
  7. Verify name is set correctly in user profile

- [ ] **Test 7.6:** Complete returning user sign-in flow (dev mode)
  1. Launch app fresh (with existing user in DB)
  2. Tap "Sign in"
  3. Enter email of existing user
  4. Tap continue
  5. Arrive at NewHomeScreen
  6. Verify NOT asked for name

- [ ] **Test 7.7:** Complete new user signup flow (production mode)
  1. Set `skipOtpVerificationInDev = false`
  2. Launch app fresh
  3. Tap "BEGIN"
  4. Enter name
  5. Enter real email
  6. Receive OTP
  7. Enter OTP
  8. Arrive at PairingScreen

- [ ] **Test 7.8:** Complete returning user sign-in flow (production mode)
  1. Set `skipOtpVerificationInDev = false`
  2. Launch app fresh
  3. Tap "Sign in"
  4. Enter email of existing user
  5. Receive OTP
  6. Enter OTP
  7. Arrive at NewHomeScreen

---

## Files to Modify

| File | Phase | Changes |
|------|-------|---------|
| `lib/config/dev_config.dart` | 1, 6 | Add `validateProductionSafety()`, env var getters |
| `lib/main.dart` | 1 | Call `validateProductionSafety()` on startup |
| `lib/screens/onboarding_screen.dart` | 2 | Separate Begin vs Sign-In navigation |
| `lib/screens/name_entry_screen.dart` | 3 | Add `isNewUser` param, remove auth check |
| `lib/screens/auth_screen.dart` | 4 | Add `isNewUser` param, fix dev mode navigation |
| `lib/screens/otp_verification_screen.dart` | 5 | Add `isNewUser` param, block on failures |

---

## Full Testing Matrix

| Scenario | Mode | Expected Flow | Expected Result |
|----------|------|---------------|-----------------|
| New user | Dev | Begin → Name → Email → Pairing | Account created, at pairing |
| New user | Prod | Begin → Name → Email → OTP → Pairing | Account created, at pairing |
| Returning user | Dev | Sign in → Email → Home | Session restored |
| Returning user | Prod | Sign in → Email → OTP → Home | Session restored |
| Wrong OTP | Prod | Sign in → Email → OTP (wrong) | Error shown, stays on OTP screen |
| Signup failure | Prod | Begin → Name → Email → OTP → (backend error) | Error shown, stays on OTP screen |
| Missing name | Prod | (somehow skip name) → OTP | Error shown, stays on OTP screen |
| Release + dev flags | Prod | Launch app | App crashes with StateError |
| Release + flags off | Prod | Launch app | App launches normally |

---

## Rollback Plan

If issues are discovered after deployment:

1. **Quick fix:** Set `skipOtpVerificationInDev = false` and rebuild
2. **Full rollback:** Revert commits for each phase in reverse order
3. **Database:** No database migrations required - changes are client-side only

---

## Notes

- **Dev mode is retained** - auto-email generation and OTP skip still work
- **Safety guards prevent production accidents** - app crashes if dev flags ship
- **Name entry only for new users** - returning users skip directly to email
- **Failures block navigation** - no more silent errors leaving users stuck

---

*Last Updated: 2024-12-16*
*Implementation Completed: 2024-12-16*

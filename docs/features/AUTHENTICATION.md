# Authentication System

## Quick Reference

| Item | Location |
|------|----------|
| Auth Service | `lib/services/auth_service.dart` |
| Onboarding Screen | `lib/screens/onboarding_screen.dart` |
| Name Entry | `lib/screens/name_entry_screen.dart` |
| Email Entry | `lib/screens/auth_screen.dart` |
| OTP Verification | `lib/screens/otp_verification_screen.dart` |
| Settings (Verify Email) | `lib/screens/settings_screen.dart` |
| Dev Config | `lib/config/dev_config.dart` |
| API Profile Route | `api/app/api/users/profile/route.ts` |
| API Signup Route | `api/app/api/users/signup/route.ts` |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Supabase Auth                                │
│                                                                  │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│   │  Password    │    │  Magic Link  │    │  Apple Sign-In   │  │
│   │  (New Users) │    │  (Returning) │    │  (Disabled)      │  │
│   └──────────────┘    └──────────────┘    └──────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    AuthService (Singleton)                       │
│                                                                  │
│   • Session management (auto-persist via Supabase)              │
│   • Token refresh (automatic)                                    │
│   • Auth state stream for UI updates                            │
│   • Test account bypass (emails matching @dev.test or +test)    │
│   • Email verification status (isEmailVerified getter)          │
└─────────────────────────────────────────────────────────────────┘
```

### Key Design Decision: Optional Email Verification

**New users** sign up without email verification (password-based auth) for frictionless onboarding.
**Returning users** must verify via magic link to prove email ownership (security).
**Email verification** is available optionally in Settings for users who want to verify their account.

---

## User Flows

### New User Flow (No OTP Required)
```
OnboardingScreen ──[BEGIN]──> NameEntryScreen ──> AuthScreen ──> PairingScreen
                                                       │
                                                       ▼
                                              [Instant Signup]
                                         (No email verification)
```
New users go directly to pairing without needing to verify their email. This reduces friction during onboarding.

**Technical note:** Behind the scenes, a deterministic password is generated from the email hash (`DevPass_{sha256(email).substring(0,12)}_2024!`) to create a real Supabase account. The user never sees or enters this password.

### Returning User Flow (Magic Link Required)
```
OnboardingScreen ──[Sign in]──> AuthScreen ──> OtpVerificationScreen ──> MainScreen
                                    │                   │
                                    │                   ▼
                                    │            [Magic Link]
                                    │         (Proves email ownership)
                                    │
                                    └──[Test Account @dev.test]──> MainScreen
                                              (Password Auth)
```
Returning users must verify via magic link for security - they have existing data worth protecting.
Test accounts (`@dev.test` or `+test` emails) bypass magic link for easier development.

### Settings Email Verification Flow
```
SettingsScreen ──> [Verify Email] ──> OtpVerificationScreen ──> [Success] ──> SettingsScreen
                                              │
                                              ▼
                                        [Magic Link]
                                    (Optional verification)
```
Users can optionally verify their email from Settings at any time.

### Automatic Session Restore
```
App Launch ──> main.dart ──> AuthService.initialize() ──> Check Supabase session
                                    │
              ┌─────────────────────┼─────────────────────┐
              ▼                     ▼                     ▼
        Session Valid         Session Expired        No Session
              │                     │                     │
              ▼                     ▼                     ▼
         MainScreen         Auto-Refresh Token    OnboardingScreen
                                    │
                              ┌─────┴─────┐
                              ▼           ▼
                          Success      Failure
                              │           │
                              ▼           ▼
                         MainScreen  OnboardingScreen
```

---

## Data Flow

### New User Sign Up (Instant - No OTP)
```dart
// 1. Create account instantly (user just enters email, no password prompt)
final success = await _authService.signInWithPassword(email);
// Behind the scenes: deterministic password from email hash
// Password formula: DevPass_{sha256(email).substring(0,12)}_2024!
// Session automatically persisted by Supabase

// 2. Complete signup (create user profile)
await userProfileService.completeSignup(
  pushToken: pushToken,
  name: pendingName,
);
```

### Returning User Sign In (Magic Link)
```dart
// 1. Send magic link to email
await _authService.signInWithMagicLink(email);
// Supabase sends 8-digit code to email

// 2. Verify OTP
final success = await _authService.verifyOTP(email, otp);
// Session automatically persisted by Supabase

// 3. Sync profile (restore user data)
await userProfileService.completeSignup(pushToken: pushToken);
```

### Test Account Bypass
```dart
// Test accounts skip magic link entirely
if (_authService.shouldBypassMagicLink(email)) {
  // Matches: @dev.test, +test in email
  await _authService.signInWithPassword(email);
} else {
  await _authService.signInWithMagicLink(email);
}
```

### Email Verification from Settings
```dart
// 1. Check verification status
final isVerified = _authService.isEmailVerified;

// 2. If not verified, user can trigger verification
if (!isVerified) {
  await _authService.sendVerificationEmail();
  // Navigate to OtpVerificationScreen(isFromSettings: true)
}

// 3. After successful OTP verification, email is marked verified
// Supabase sets emailConfirmedAt on the user record
```

---

## Key Rules

### 1. isNewUser Flag Must Be Passed Through Flow
The `isNewUser` flag determines navigation after auth:
- `true` → Navigate to `PairingScreen` (new user needs to pair)
- `false` → Navigate to `MainScreen` (returning user has existing couple)

```dart
// ✅ CORRECT - Pass flag through screens
NameEntryScreen(isNewUser: true)
AuthScreen(isNewUser: widget.isNewUser)
OtpVerificationScreen(email: email, isNewUser: widget.isNewUser)

// ❌ WRONG - Hardcoding or ignoring
AuthScreen()  // Defaults to isNewUser: true
```

### 2. Pending Name Storage Pattern
Name is stored in secure storage BEFORE auth, then used AFTER auth succeeds:

```dart
// In NameEntryScreen (before auth)
await _secureStorage.write(key: 'pending_user_name', value: name);

// In OtpVerificationScreen (after auth success)
final pendingName = await secureStorage.read(key: 'pending_user_name');
await userProfileService.completeSignup(name: pendingName, ...);
await secureStorage.delete(key: 'pending_user_name');
```

### 3. Pre-load Data for Returning Users
Before navigating to home, pre-load LP and quests to prevent UI flashing:

```dart
// After successful auth for returning user
if (result.isPaired && result.coupleId != null) {
  await _secureStorage.write(key: 'couple_id', value: result.coupleId!);
  await LovePointService.fetchAndSyncFromServer();  // Prevent LP counter flash
  await questService.ensureQuestsInitialized();     // Prevent empty quests
}
```

### 4. Never Block Returning Users
For returning users, profile sync failures should log but not block navigation:

```dart
// ✅ CORRECT - Log but don't block
try {
  await userProfileService.completeSignup(pushToken: pushToken);
} catch (e) {
  Logger.error('Failed to sync profile', error: e);
  // Continue to MainScreen anyway
}

// ❌ WRONG - Blocking on failure
if (!success) {
  setState(() => _errorMessage = 'Failed to sync');
  return;  // User stuck!
}
```

### 5. Use Secure Storage for Auth Persistence
Auth tokens are managed by Supabase automatically. Use secure storage only for app-level flags:

```dart
// App-level flags in secure storage
'has_completed_onboarding'  // Boolean string
'pending_user_name'         // Temporary during signup
'couple_id'                 // Cached for quick access

// Auth tokens - NEVER manually store
// Supabase handles: access_token, refresh_token, user_id
```

---

## Test Account Bypass

### Test Email Patterns

The app recognizes test email patterns that bypass magic link verification:

| Pattern | Example | Behavior |
|---------|---------|----------|
| `@dev.test` | `test7001@dev.test` | Password auth, no magic link |
| `+test` | `john+test@gmail.com` | Password auth, no magic link |

```dart
// In auth_service.dart
bool shouldBypassMagicLink(String email) {
  if (email.endsWith('@dev.test')) return true;
  if (email.contains('+test')) return true;
  return false;
}
```

### Why Test Email Patterns (Not Flags)

**Production-safe:** Real users won't accidentally use `@dev.test` emails.
**No flags to forget:** Works in all environments without configuration.
**Easy to use:** Just add `+test` to any email during testing.

### Dev Config Toggles (Legacy)

| Toggle | Purpose | Works on Physical Devices? |
|--------|---------|---------------------------|
| `skipAuthInDev` | Skip entire auth flow | NO (simulators only) |
| `skipOtpVerificationInDev` | Pre-fills test email | YES (convenience) |

```dart
// skipOtpVerificationInDev now just pre-fills test email for convenience
// The actual bypass is based on email pattern, not this flag
if (DevConfig.skipOtpVerificationInDev) {
  final random = DateTime.now().millisecondsSinceEpoch % 10000;
  _emailController.text = 'test$random@dev.test';
}
```

### Production Safety

The test email pattern approach is production-safe because:
- Real users won't use `@dev.test` domain (doesn't exist)
- Real users won't add `+test` to their emails accidentally
- No configuration flags that could be left enabled

---

## Common Bugs & Fixes

### 1. White Screen on TestFlight
**Symptom:** App shows white screen immediately after launch on physical device.

**Cause:** `validateProductionSafety()` throws because dev flags are enabled.

**Fix:**
```dart
// In dev_config.dart
static const bool skipOtpVerificationInDev = false;  // Must be false
static const bool allowAuthBypassInRelease = false;  // Must be false
```

### 2. Returning User Goes to Pairing
**Symptom:** User with existing couple is shown PairingScreen instead of MainScreen.

**Cause:** `isNewUser` flag not passed through the flow.

**Fix:** Ensure `isNewUser: false` is passed from OnboardingScreen → AuthScreen → OtpVerificationScreen.

### 3. LP Counter Flashes Zero
**Symptom:** Home screen briefly shows "0 LP" before updating.

**Cause:** LP not pre-loaded before navigation.

**Fix:**
```dart
// In auth completion (auth_screen.dart or otp_verification_screen.dart)
await LovePointService.fetchAndSyncFromServer();
```

### 4. Quests Empty on Return
**Symptom:** Returning user sees no quests on home screen.

**Cause:** Quests not initialized before navigation.

**Fix:**
```dart
// In auth completion
final questService = QuestInitializationService();
await questService.ensureQuestsInitialized();
```

### 5. Password Auth Fails Across Devices
**Symptom:** Dev sign-in works on Android but fails on iOS for same email.

**Cause:** Using Dart's `hashCode` which is NOT stable across platforms.

**Fix:** Use SHA256 hash (already implemented):
```dart
final emailBytes = utf8.encode(email);
final hash = sha256.convert(emailBytes);
final shortHash = hash.toString().substring(0, 12);
final devPassword = 'DevPass_${shortHash}_2024!';
```

### 6. Keyboard Pushes Button Over Input Field
**Symptom:** On name/email entry screens, keyboard opens and Continue button overlaps the text field.

**Cause:** Form content not scrollable, footer doesn't have background color.

**Fix:** Wrap form content in `SingleChildScrollView` and add background color to footer:
```dart
// Form content - scrollable when keyboard opens
Expanded(
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        NewspaperTextField(...),
        const SizedBox(height: 80),  // Spacing for button
      ],
    ),
  ),
),

// Footer with solid background
Container(
  decoration: const BoxDecoration(
    color: NewspaperColors.surface,  // Prevent overlap bleed-through
    border: Border(top: BorderSide(...)),
  ),
  child: NewspaperPrimaryButton(...),
),
```

---

## Debugging Tips

### Check Auth State
```dart
final authService = AuthService();
debugPrint('Auth state: ${authService.authState}');
debugPrint('User ID: ${authService.userId}');
debugPrint('Token: ${authService.accessToken?.substring(0, 20)}...');
```

### View Auth Headers
Auth headers are logged when dev bypass is active:
```
🔧 [DEV] Adding X-Dev-User-Id header: cd6373bd-77d2-43a8-9332-d4c9e777a570
```

### Supabase Dashboard
- View users: Supabase Dashboard → Authentication → Users
- View sessions: Supabase Dashboard → Authentication → Sessions
- Check email confirmation setting: Auth → Providers → Email → "Confirm email"

### Force Re-auth for Testing
```dart
await AuthService().signOut();
// User will be redirected to OnboardingScreen on next route check
```

---

## Apple Sign-In (Currently Disabled)

Apple Sign-In is implemented but disabled pending App Store compliance setup.

### Current State
```dart
// In onboarding_screen.dart
bool get _isAppleSignInAvailable {
  return false;  // Currently disabled
}
```

### To Enable
1. Configure Apple Developer Portal (App ID, Sign In with Apple capability)
2. Configure Supabase (Apple provider with service ID, key)
3. Update code:
```dart
bool get _isAppleSignInAvailable {
  if (kIsWeb) return false;
  return Platform.isIOS;
}
```

See `docs/APPLE_SIGNIN_SETUP.md` for full setup guide.

---

## File Reference

| File | Purpose |
|------|---------|
| `auth_service.dart` | Core auth logic, session management, verification status |
| `onboarding_screen.dart` | Initial splash with BEGIN/Sign in buttons |
| `name_entry_screen.dart` | Step 1: Collect user's name |
| `auth_screen.dart` | Step 2: Collect email, password or magic link auth |
| `otp_verification_screen.dart` | Verify OTP code (returning users + settings verification) |
| `settings_screen.dart` | Email verification UI in Account section |
| `pairing_screen.dart` | Post-auth screen for new users (pair with partner) |
| `main_screen.dart` | Post-auth screen for returning users (home with nav) |
| `dev_config.dart` | Dev bypass flags (test email pre-fill) |
| `user_profile_service.dart` | Server-side profile sync |

---

## Changelog

| Date | Change |
|------|--------|
| 2025-01-06 | **Major change:** Optional email verification - new users no longer require OTP, verification moved to Settings |
| 2025-01-06 | Added test email pattern bypass (`@dev.test`, `+test`) for development |
| 2025-01-06 | Added `isEmailVerified` getter and `sendVerificationEmail()` to AuthService |
| 2025-01-06 | Added `isFromSettings` param to OtpVerificationScreen |
| 2025-01-06 | Added email verification UI to Settings screen Account section |
| 2025-12-16 | Added fix for keyboard overlap on name/email entry screens (SingleChildScrollView + footer background) |
| 2025-12-16 | Initial documentation |

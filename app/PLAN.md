# Apple Sign-In Implementation Plan

## Status: Code Implementation Complete

The Flutter code for Apple Sign-In has been implemented. Two manual configuration steps remain:
1. **Apple Developer Portal**: Enable Sign In with Apple for App ID
2. **Supabase Dashboard**: Enable and configure Apple OAuth provider

## Overview

Replace email OTP verification with Apple Sign-In for a better user experience. Users will authenticate with a single tap using their Apple ID, and Supabase will handle the OAuth flow.

## Implementation Completed

- [x] Add `sign_in_with_apple` and `crypto` packages to pubspec.yaml
- [x] Add Sign In with Apple entitlement to iOS (`Runner.entitlements`)
- [x] Add `signInWithApple()` method to AuthService
- [x] Update OnboardingScreen with Apple Sign-In button (Variant 3: Apple Only - Minimal)
- [ ] Configure Supabase Apple provider (manual)
- [ ] Configure Apple Developer Portal (manual)

## Current State

- **Auth Flow**: Email OTP via `signInWithMagicLink()` → `verifyOTP()`
- **Files**:
  - `lib/services/auth_service.dart` - Handles Supabase auth
  - `lib/screens/auth_screen.dart` - Email input UI
  - `lib/screens/otp_verification_screen.dart` - OTP code entry
- **iOS Bundle ID**: `com.togetherremind.togetherremind2`
- **Supabase URL**: `jcibbrasffhwvjfojviv.supabase.co`
- **Current Entitlements**: Push notifications, HealthKit

## Implementation Steps

### 1. Apple Developer Portal Configuration

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers)
2. Select the App ID for `com.togetherremind.togetherremind2`
3. Enable "Sign In with Apple" capability
4. Create a Service ID for web/Android (if needed later):
   - Identifier: `com.togetherremind.togetherremind2.auth`
   - Configure domains and redirect URLs

### 2. Supabase Dashboard Configuration

1. Go to Supabase Dashboard → Authentication → Providers → Apple
2. Enable Apple provider
3. Configure:
   - **Enabled**: ON
   - **Client ID**: `com.togetherremind.togetherremind2` (Bundle ID for iOS native)
   - For web support (later): Add Service ID and configure callback URL

### 3. iOS Project Configuration

**File: `ios/Runner/Runner.entitlements`**

Add Sign In with Apple capability:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>development</string>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array/>
    <key>com.apple.developer.applesignin</key>
    <array>
        <string>Default</string>
    </array>
</dict>
</plist>
```

### 4. Flutter Dependencies

**File: `pubspec.yaml`**

Add the sign_in_with_apple package:

```yaml
dependencies:
  # Existing dependencies...
  sign_in_with_apple: ^6.1.3
  crypto: ^3.0.3  # For nonce generation
```

Run: `flutter pub get`

### 5. AuthService Updates

**File: `lib/services/auth_service.dart`**

Add Apple Sign-In method:

```dart
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Sign in with Apple ID
/// Returns true if sign-in was successful
Future<bool> signInWithApple() async {
  try {
    // Generate nonce for security
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    // Request Apple credentials
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    // Get the ID token
    final idToken = credential.identityToken;
    if (idToken == null) {
      debugPrint('❌ Apple Sign-In: No identity token');
      return false;
    }

    // Sign in to Supabase with the Apple ID token
    final response = await _supabase!.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    if (response.session != null) {
      await _saveSession(response.session!);

      // Save user's name if provided (Apple only provides name on first sign-in)
      if (credential.givenName != null || credential.familyName != null) {
        final fullName = [credential.givenName, credential.familyName]
            .where((s) => s != null && s.isNotEmpty)
            .join(' ');
        if (fullName.isNotEmpty) {
          await updateDisplayName(fullName);
        }
      }

      _updateAuthState(AuthState.authenticated);
      debugPrint('✅ Apple Sign-In successful');
      return true;
    }

    debugPrint('❌ Apple Sign-In: No session returned');
    return false;
  } on SignInWithAppleAuthorizationException catch (e) {
    if (e.code == AuthorizationErrorCode.canceled) {
      debugPrint('ℹ️ Apple Sign-In: User cancelled');
    } else {
      debugPrint('❌ Apple Sign-In error: ${e.code} - ${e.message}');
    }
    return false;
  } catch (e) {
    debugPrint('❌ Apple Sign-In error: $e');
    return false;
  }
}

/// Generate a random nonce for Apple Sign-In
String _generateNonce([int length = 32]) {
  const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
}
```

### 6. UI Updates

**Option A: Replace Email Flow (Recommended)**

Update `OnboardingScreen` to use Apple Sign-In button:

```dart
// In onboarding_screen.dart
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

// Replace "Begin Your Story" button with Apple Sign-In
SignInWithAppleButton(
  onPressed: _handleAppleSignIn,
  style: SignInWithAppleButtonStyle.black,
),

// Keep email fallback for users without Apple ID
TextButton(
  onPressed: () => Navigator.push(context, MaterialPageRoute(
    builder: (context) => const AuthScreen(),
  )),
  child: Text('Sign in with email instead'),
),
```

**Option B: Add as Additional Option**

Keep email flow but add Apple Sign-In as primary option on `AuthScreen`:

```dart
// In auth_screen.dart - add above the email form
Column(
  children: [
    SignInWithAppleButton(
      onPressed: _handleAppleSignIn,
      style: SignInWithAppleButtonStyle.black,
    ),

    const SizedBox(height: 20),

    // Divider
    Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('or', style: TextStyle(color: Colors.grey)),
        ),
        Expanded(child: Divider()),
      ],
    ),

    const SizedBox(height: 20),

    // Existing email form below...
  ],
)
```

### 7. Handle Post-Authentication Flow

The existing flow after authentication should work:
1. User signs in with Apple
2. Session is saved to secure storage
3. AuthState changes to `authenticated`
4. App navigates to pairing or home screen

Ensure `name_entry_screen.dart` still works - Apple may provide name on first sign-in, but not on subsequent ones.

### 8. Platform-Specific Considerations

**iOS**: Native Apple Sign-In works out of the box with the entitlement.

**Android**: Apple Sign-In on Android requires additional setup (Service ID, web redirect). Consider:
- Using Google Sign-In for Android users instead
- Or implementing Apple Sign-In via web view

**Web**: Requires Service ID configuration in Apple Developer Portal.

### 9. Testing Checklist

- [ ] First-time Apple Sign-In creates new Supabase user
- [ ] Returning Apple Sign-In finds existing user
- [ ] User name is captured on first sign-in
- [ ] User can sign out and sign back in
- [ ] Session persists across app restarts
- [ ] Token refresh works correctly
- [ ] Cancelled sign-in doesn't crash app
- [ ] Email fallback still works

## Files to Modify

1. `ios/Runner/Runner.entitlements` - Add Sign In with Apple capability
2. `pubspec.yaml` - Add sign_in_with_apple and crypto packages
3. `lib/services/auth_service.dart` - Add signInWithApple() method
4. `lib/screens/onboarding_screen.dart` - Add Apple Sign-In button
5. `lib/screens/auth_screen.dart` - Add Apple Sign-In as alternative

## External Configuration Required

1. **Apple Developer Portal**: Enable Sign In with Apple for App ID
2. **Supabase Dashboard**: Enable and configure Apple OAuth provider
3. Regenerate provisioning profiles after capability change

## Rollback Plan

If issues arise, the email OTP flow remains intact as a fallback. Simply hide the Apple Sign-In button to revert.

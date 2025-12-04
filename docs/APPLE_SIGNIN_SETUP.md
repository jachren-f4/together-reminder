# Apple Sign-In Configuration Guide

This guide walks you through configuring Apple Sign-In for TogetherRemind. The Flutter code is already implemented - you just need to complete the portal configurations below.

## Prerequisites

- Apple Developer Program membership ($99/year)
- Access to Supabase dashboard
- iOS Bundle ID: `com.togetherremind.togetherremind2`

---

## Step 1: Apple Developer Portal Configuration

### 1.1 Enable Sign In with Apple Capability

1. Go to [Apple Developer Portal - Identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. Find and click on your App ID: `com.togetherremind.togetherremind2`
3. Scroll down to **Capabilities**
4. Check the box next to **Sign In with Apple**
5. Click **Save**

### 1.2 Regenerate Provisioning Profile

After enabling the capability, you need to regenerate your provisioning profile:

1. Go to [Profiles](https://developer.apple.com/account/resources/profiles/list)
2. Find your development/distribution profile for TogetherRemind
3. Click **Edit**
4. Click **Save** (this regenerates with the new capability)
5. Download the new profile
6. In Xcode: Go to **Signing & Capabilities** and refresh profiles, or double-click the downloaded profile

### 1.3 Verify in Xcode (Optional but Recommended)

1. Open `app/ios/Runner.xcworkspace` in Xcode
2. Select the **Runner** target
3. Go to **Signing & Capabilities** tab
4. Verify "Sign In with Apple" appears in the capabilities list
5. If not, click **+ Capability** and add "Sign In with Apple"

---

## Step 2: Supabase Dashboard Configuration

### 2.1 Enable Apple Provider

1. Go to your [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project (TogetherRemind)
3. Navigate to **Authentication** → **Providers**
4. Find **Apple** in the list and click to expand

### 2.2 Configure Apple Provider

Fill in the following:

| Field | Value |
|-------|-------|
| **Enabled** | Toggle ON |
| **Client ID (for iOS)** | `com.togetherremind.togetherremind2` |

For iOS native sign-in, you only need the Client ID (your Bundle ID). The Secret Key and other fields are only needed for web-based Apple Sign-In.

### 2.3 Save Configuration

Click **Save** to apply the changes.

---

## Step 3: Enable in Flutter Code

Once both portal configurations are complete:

1. Open `app/lib/screens/onboarding_screen.dart`
2. Find the `_isAppleSignInAvailable` getter (around line 22)
3. Change from:
   ```dart
   bool get _isAppleSignInAvailable {
     return false; // Disabled until portal configuration is complete
     // if (kIsWeb) return false;
     // return Platform.isIOS;
   }
   ```
   To:
   ```dart
   bool get _isAppleSignInAvailable {
     if (kIsWeb) return false;
     return Platform.isIOS;
   }
   ```

---

## Step 4: Testing

### Test on Physical iOS Device

Apple Sign-In only works on physical iOS devices, not simulators.

1. Build and run on a physical iPhone:
   ```bash
   flutter run -d <device-id> --dart-define=BRAND=togetherRemind
   ```

2. On the onboarding screen, tap "Continue with Apple"

3. Complete Apple authentication

4. Verify you're navigated to the name entry or home screen

### Test Checklist

- [ ] First-time sign-in creates a new Supabase user
- [ ] Name is captured (Apple only provides name on first sign-in)
- [ ] Returning user sign-in finds existing account
- [ ] Session persists after app restart
- [ ] Sign out works correctly
- [ ] Email fallback ("Use email instead") still works

---

## Troubleshooting

### "Invalid Client" Error

- Verify the Bundle ID in Supabase matches exactly: `com.togetherremind.togetherremind2`
- Ensure Sign In with Apple is enabled in Apple Developer Portal
- Regenerate and re-download your provisioning profile

### "Authorization Failed" Error

- Check that the app is signed with a profile that has Sign In with Apple capability
- Verify the device is signed into an Apple ID
- Try signing out and back into iCloud on the device

### Button Doesn't Appear

- Verify `_isAppleSignInAvailable` returns `true`
- Ensure you're testing on iOS (not Android, web, or simulator)

### User Name Not Captured

Apple only provides the user's name on the **first** sign-in. If you need to test name capture:
1. Go to device Settings → Apple ID → Password & Security → Sign in with Apple
2. Find TogetherRemind and tap "Stop Using Apple ID"
3. Sign in again - name will be provided

---

## Files Reference

| File | Purpose |
|------|---------|
| `app/lib/services/auth_service.dart` | Contains `signInWithApple()` method |
| `app/lib/screens/onboarding_screen.dart` | UI with Apple Sign-In button |
| `app/ios/Runner/Runner.entitlements` | iOS capability declaration |
| `app/pubspec.yaml` | Flutter dependencies |

---

## Future Enhancements

### Android Support

Apple Sign-In on Android requires additional setup:
1. Create a Service ID in Apple Developer Portal
2. Configure redirect URLs
3. Set up a web server endpoint for the callback

Consider using Google Sign-In for Android users instead.

### Web Support

For web deployment, you'll need:
1. Service ID configuration
2. Domain verification in Apple Developer Portal
3. Callback URL configuration in Supabase

---

## Quick Reference

**Apple Developer Portal**: https://developer.apple.com/account/resources/identifiers

**Supabase Dashboard**: https://supabase.com/dashboard

**Bundle ID**: `com.togetherremind.togetherremind2`

**Toggle File**: `app/lib/screens/onboarding_screen.dart` line ~22

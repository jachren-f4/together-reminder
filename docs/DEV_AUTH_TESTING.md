# Dev Auth Testing Guide

This guide explains how to test the full new-user signup flow without requiring real email verification.

## Overview

The dev auth system allows testing the complete onboarding flow:
1. OnboardingScreen → "Continue with Email"
2. AuthScreen → Random email pre-filled → "Continue (Dev Mode)"
3. NameEntryScreen → Enter name → Continue
4. PairingScreen → Exchange 6-digit codes between devices
5. Welcome Quiz → Both users play through

## Quick Setup

### 1. Configure Flutter App (`app/lib/config/dev_config.dart`)

```dart
// Line 17: Show visual auth screens (don't skip to HomeScreen)
static const bool skipAuthInDev = false;

// Line 26: Skip OTP verification, use password auth with random email
static const bool skipOtpVerificationInDev = true;

// Line 72: Use localhost API for testing
static const bool useProductionApi = false;
```

### 2. Start Local API Server

```bash
cd /Users/joakimachren/Desktop/togetherremind/api
npm run dev
```

### 3. Clear App Data & Launch

```bash
# Clear Android app data
~/Library/Android/sdk/platform-tools/adb shell pm clear com.togetherremind.togetherremind

# Launch both apps
cd /Users/joakimachren/Desktop/togetherremind/app
flutter run -d emulator-5554 --flavor togetherremind --dart-define=BRAND=togetherRemind &
flutter run -d chrome --dart-define=BRAND=togetherRemind &
```

For Chrome, also clear site data: DevTools → Application → Clear site data

---

## How It Works

### The Two-Toggle System

| Toggle | Purpose | Effect |
|--------|---------|--------|
| `skipAuthInDev = false` | Show visual auth screens | Users see OnboardingScreen → AuthScreen → NameEntryScreen |
| `skipOtpVerificationInDev = true` | Skip email verification | Random email generated, no OTP code needed |

### Auth Flow with Dev Bypasses

```
┌─────────────────────┐
│  OnboardingScreen   │  "Continue with Email"
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│    AuthScreen       │  Random email pre-filled (e.g., test1234@dev.test)
│                     │  Button shows "Continue (Dev Mode)"
└─────────┬───────────┘
          │ devSignInWithEmail() creates real Supabase user
          ▼
┌─────────────────────┐
│  NameEntryScreen    │  Enter display name
└─────────┬───────────┘
          │ Saves name to user profile
          ▼
┌─────────────────────┐
│   PairingScreen     │  Exchange 6-digit codes with partner
└─────────┬───────────┘
          │ Creates couple in database
          ▼
┌─────────────────────┐
│   Welcome Quiz      │  First game together
└─────────────────────┘
```

### Password Generation

The dev signup uses deterministic passwords derived from the email:
```dart
// auth_service.dart - devSignInWithEmail()
final hash = sha256.convert(utf8.encode(email)).toString();
final password = 'DevPass_${hash.substring(0, 12)}_2024!';
```

This allows the same email to sign in again without knowing the password.

---

## Troubleshooting

### Thrown back to OnboardingScreen after signup

**Cause:** Auth tokens being cleared by stale data check.

**Fix:** Already fixed in `auth_wrapper.dart:80-81` - checks for existing tokens before clearing.

### Random email not appearing

**Cause:** `skipOtpVerificationInDev` is `false`.

**Fix:** Set `skipOtpVerificationInDev = true` in `dev_config.dart:26`.

### Auth screens not showing (goes straight to HomeScreen)

**Cause:** `skipAuthInDev` is `true`.

**Fix:** Set `skipAuthInDev = false` in `dev_config.dart:17`.

---

## File Reference

| File | Purpose |
|------|---------|
| `app/lib/config/dev_config.dart` | Flutter dev toggles |
| `app/lib/services/auth_service.dart` | `devSignInWithEmail()`, `getAuthHeaders()` |
| `app/lib/screens/auth_screen.dart` | Random email generation, dev sign-in UI |
| `app/lib/screens/name_entry_screen.dart` | Name input after auth |
| `app/lib/widgets/auth_wrapper.dart` | Auth state routing |

---

## Summary

To test the full new-user signup flow:

1. **Flutter:** `skipAuthInDev = false`, `skipOtpVerificationInDev = true`, `useProductionApi = false`
2. **Clear app data** on both devices
3. **Walk through:** Onboarding → Email → Name → Pairing → Welcome Quiz

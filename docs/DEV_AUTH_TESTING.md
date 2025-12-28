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

### 2. Configure API (`api/.env.local`)

```bash
# Line 19-20: DISABLE dev bypass so API uses real JWT tokens
AUTH_DEV_BYPASS_ENABLED=false
AUTH_DEV_USER_ID=<any-uuid>  # Not used when bypass is disabled
```

### 3. Start Local API Server

```bash
cd /Users/joakimachren/Desktop/togetherremind/api
npm run dev
```

### 4. Clear App Data & Launch

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

## Critical Configuration

### API Dev Bypass Must Be DISABLED

When `AUTH_DEV_BYPASS_ENABLED=true` in the API, it ignores JWT tokens and uses a hardcoded user ID. This causes "Couple not found" errors because:

1. Flutter creates NEW user with random email → gets user ID `abc123`
2. API ignores JWT, uses hardcoded `AUTH_DEV_USER_ID=xyz789`
3. API looks for couple with user `xyz789` → not found!

**Solution:** Set `AUTH_DEV_BYPASS_ENABLED=false` so API uses the real JWT token.

### When to Use Each Configuration

| Scenario | `skipAuthInDev` | `skipOtpVerificationInDev` | `AUTH_DEV_BYPASS_ENABLED` |
|----------|-----------------|----------------------------|---------------------------|
| **Test new user flow** | `false` | `true` | `false` |
| Skip all auth (existing couple) | `true` | `true` | `true` |
| Production-like testing | `false` | `false` | `false` |

---

## Troubleshooting

### "Couple not found" after pairing

**Cause:** API dev bypass is overriding the JWT token.

**Fix:** Set `AUTH_DEV_BYPASS_ENABLED=false` in `api/.env.local` and restart the API server.

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
| `api/.env.local` | API dev bypass toggle |
| `api/lib/auth/dev-middleware.ts` | API auth bypass logic |

---

## One-Click Setup Script

For future agents, here's a script to set up the dev auth testing environment:

```bash
#!/bin/bash
# setup_dev_auth_testing.sh

cd /Users/joakimachren/Desktop/togetherremind

# 1. Configure Flutter dev_config.dart
sed -i '' 's/static const bool skipAuthInDev = true/static const bool skipAuthInDev = false/' app/lib/config/dev_config.dart
sed -i '' 's/static const bool skipOtpVerificationInDev = false/static const bool skipOtpVerificationInDev = true/' app/lib/config/dev_config.dart
sed -i '' 's/static const bool useProductionApi = true/static const bool useProductionApi = false/' app/lib/config/dev_config.dart

# 2. Disable API dev bypass
sed -i '' 's/AUTH_DEV_BYPASS_ENABLED=true/AUTH_DEV_BYPASS_ENABLED=false/' api/.env.local

# 3. Kill existing processes
pkill -9 -f "flutter" 2>/dev/null || true
lsof -ti:3000 | xargs kill -9 2>/dev/null || true

# 4. Start API server
cd api && npm run dev &
sleep 5

# 5. Clear app data
cd ../app
~/Library/Android/sdk/platform-tools/adb shell pm clear com.togetherremind.togetherremind 2>/dev/null || true

# 6. Launch apps
flutter run -d emulator-5554 --flavor togetherremind --dart-define=BRAND=togetherRemind &
flutter run -d chrome --dart-define=BRAND=togetherRemind &

echo "Dev auth testing environment ready!"
echo "Chrome: Clear site data in DevTools → Application → Clear site data"
```

---

## Summary

To test the full new-user signup flow:

1. **Flutter:** `skipAuthInDev = false`, `skipOtpVerificationInDev = true`, `useProductionApi = false`
2. **API:** `AUTH_DEV_BYPASS_ENABLED = false`
3. **Clear app data** on both devices
4. **Walk through:** Onboarding → Email → Name → Pairing → Welcome Quiz

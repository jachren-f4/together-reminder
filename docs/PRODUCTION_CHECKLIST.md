# Production Readiness Checklist

This document tracks all items that must be addressed before shipping to the App Store.

**Last Updated:** 2025-01-12

---

## Status Legend
- [ ] Not fixed
- [x] Fixed
- ⚠️ Needs attention
- ✅ Safe (no action needed)

---

## 1. Development Bypass Flags

### 1.1 `skipOtpVerificationInDev` - CRITICAL
- **File:** `app/lib/config/dev_config.dart`
- **Line:** 69
- **Current Value:** `false`
- **Required Value:** `false`
- **Risk:** Users can sign up without email verification. Creates users with deterministic passwords instead of OTP magic links.
- **Status:** [x] Fixed (2025-01-12)

### 1.2 `validateProductionSafety()` Disabled - CRITICAL
- **File:** `app/lib/main.dart`
- **Line:** 48
- **Current State:** Enabled
- **Required State:** Uncommented
- **Risk:** Safety check that crashes app if dev flags are enabled in release mode is disabled. Without this, dev bypasses could silently ship to production.
- **Status:** [x] Fixed (2025-01-12)

### 1.3 `shouldBypassMagicLink()` Allows Test Emails - INTENTIONAL
- **File:** `app/lib/services/auth_service.dart`
- **Lines:** 121-125
- **Current Behavior:** Returns `true` for emails ending with `@dev.test` or containing `+test`, allowing OTP bypass
- **Purpose:** Intentional backdoor for developer testing in production
- **Note:** Allows signing in with `youremail+test@gmail.com` to bypass OTP
- **Status:** ✅ Intentional - no change needed

### 1.4 Dev Email Pre-fill in Auth Screen
- **File:** `app/lib/screens/auth_screen.dart`
- **Lines:** 49-52
- **Current Behavior:** Pre-fills `test{random}@dev.test` email when `skipOtpVerificationInDev` is true
- **Required Behavior:** No pre-fill in production
- **Risk:** Test email visible to users
- **Status:** [x] Fixed (2025-01-12) - automatically disabled when 1.1 was fixed

---

## 2. Other Dev Flags (Already Safe)

### 2.1 `skipAuthInDev`
- **File:** `app/lib/config/dev_config.dart`
- **Line:** 60
- **Current Value:** `false`
- **Status:** ✅ Safe

### 2.2 `skipSubscriptionCheckInDev`
- **File:** `app/lib/config/dev_config.dart`
- **Line:** 78
- **Current Value:** `true`
- **Note:** Only active when `kDebugMode` is true, automatically disabled in release builds
- **Status:** ✅ Safe

### 2.3 `allowAuthBypassInRelease`
- **File:** `app/lib/config/dev_config.dart`
- **Line:** 119
- **Current Value:** `false`
- **Status:** ✅ Safe

### 2.4 `useProductionApi`
- **File:** `app/lib/config/dev_config.dart`
- **Line:** 124
- **Current Value:** `false`
- **Note:** Only affects debug builds; release builds always use production API
- **Status:** ✅ Safe

---

## 3. Build Configuration

### 3.1 Device Target - iPhone Only
- **File:** `app/ios/Runner.xcodeproj/project.pbxproj`
- **Setting:** `TARGETED_DEVICE_FAMILY = 1`
- **Note:** Changed from `"1,2"` (Universal) to `1` (iPhone only) to skip iPad screenshots
- **Status:** [x] Fixed

### 3.2 Build Version
- **File:** `app/pubspec.yaml`
- **Line:** 19
- **Current:** `1.0.0+56`
- **Note:** Increment build number for each TestFlight/App Store upload
- **Status:** ⚠️ Check before each upload

---

## 4. Apple Review Account

### 4.1 Test Account for Apple Reviewer
- **Email:** `test7001@dev.test`
- **Account:** Pertsa (pre-paired with existing partner)
- **OTP Bypass:** Yes - `@dev.test` domain bypasses magic link
- **Note:** Reviewer can sign in without OTP verification
- **Status:** [ ] Verify account is paired and has activity

### 4.2 App Review Notes
Add this to App Store Connect → App Review Information → Notes:
```
This is a couples app requiring two paired users.

Test account credentials:
- Email: test7001@dev.test
- No password required - just enter the email and tap Continue

This account is pre-paired with a partner so you can experience the full app functionality including quizzes, games, and Love Points.
```
- **Status:** [ ] Add to App Store Connect

---

## 5. App Store Connect Requirements

### 5.1 Screenshots
- **6.5" Display:** 1284×2778px - Required
- **5.5" Display:** 1242×2208px - Optional (auto-scaled from 6.5")
- **Location:** `appstore/screenshots/6.5inch/` and `appstore/screenshots/5.5inch/`
- **Status:** [x] Created

### 5.2 App Metadata
- **Description:** Required
- **Keywords:** Required (100 chars max)
- **Support URL:** `https://jachren-f4.github.io/together-reminder/`
- **Privacy Policy URL:** `https://jachren-f4.github.io/together-reminder/privacy.html`
- **Status:** [ ] Verify in App Store Connect

### 5.3 In-App Purchases
- **Product:** Premium Monthly (`us2_premium_monthly`)
- **Status:** [ ] Verify attached to app version

---

## 5. API & Backend

### 5.1 API Environment Variables
- **Location:** `api/.env`
- **Checked for:** DEV, BYPASS, DEBUG flags
- **Status:** ✅ No dev flags found

### 5.2 Production API URL
- **URL:** `https://api-joakim-achrens-projects.vercel.app`
- **Config:** `app/lib/config/supabase_config.dart`
- **Note:** Release builds automatically use production URL
- **Status:** ✅ Safe

---

## 6. RevenueCat / Subscriptions

### 6.1 iOS API Key
- **File:** `app/lib/config/revenuecat_config.dart`
- **Status:** ✅ Configured (`appl_uMIdJjxUexRmzWrJQEoohTzaIEK`)

### 6.2 Android API Key
- **File:** `app/lib/config/revenuecat_config.dart`
- **Current:** `PASTE_YOUR_ANDROID_API_KEY_HERE`
- **Status:** ⚠️ Not configured (iOS-only release OK)

---

## 7. Pre-Release Commands

Run these before building the final release:

```bash
# 1. Fix dev flags (see sections 1.1-1.3)

# 2. Build release IPA
cd /Users/joakimachren/Desktop/togetherremind/app
flutter build ipa --release --dart-define=BRAND=us2

# 3. Upload to App Store Connect
xcrun altool --upload-app --type ios \
  -f "build/ios/ipa/Us 2.0.ipa" \
  --apiKey 54R6QHKMB4 \
  --apiIssuer e43a1b2a-f0d3-4d40-af64-a987db2c850a
```

---

## Change Log

| Date | Change | By |
|------|--------|-----|
| 2025-01-12 | Initial checklist created | Claude |
| 2025-01-12 | Added device target (iPhone only) | Claude |
| 2025-01-12 | Fixed `skipOtpVerificationInDev` → `false` | Claude |
| 2025-01-12 | Enabled `validateProductionSafety()` | Claude |
| 2025-01-12 | Added Apple review account info | Claude |
| 2025-01-12 | Built and uploaded v1.0.0+57 to App Store Connect | Claude |
| 2025-01-12 | Fixed privacy manifest: updated connectivity_plus 5.0.2 → 7.0.0 | Claude |
| 2025-01-12 | Built and uploaded v1.0.0+60 to App Store Connect | Claude |

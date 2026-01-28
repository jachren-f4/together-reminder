# App Store Review Tracking

This document tracks Apple App Store review submissions, rejections, and feedback for the Us 2.0 app.

---

## App Information

- **App Name:** Us 2.0
- **Bundle ID:** `com.togetherremind.togetherremind2`
- **App Store Connect:** [Link](https://appstoreconnect.apple.com)

---

## Review History

### Submission #1 - Expired Subscription Demo Account Issue

**Submission ID:** `ce9cebb6-b432-4e4e-99d0-321e47db07ba`
**Initial Build:** 1.0
**Status:** 🔄 Build 74 rejected - addressing metadata and HealthKit issues

#### Timeline

| Date | Event |
|------|-------|
| Jan 18, 2026 | Initial submission, rejected - need demo account with expired subscription |
| Jan 18, 2026 | Created demo account, replied with credentials via App Store Connect message |
| Jan 20, 2026 | Rejected again - app showing "PREMIUM ACTIVE" instead of expired |
| Jan 20, 2026 | Investigation revealed RevenueCat override bug |
| Jan 20, 2026 | Build 66 uploaded with fix |
| Jan 21, 2026 | Testing revealed purchase flow issue - app stayed on paywall after purchase |
| Jan 21, 2026 | Additional fix: Clear couple status cache after successful purchase |
| Jan 21, 2026 | Build 68 uploaded with purchase flow fix (UUID: fbd9af68-5dc2-4d51-8cc2-a2d2db3394bc) |
| Jan 21, 2026 | Build 70 added debug overlay triggered by triple-tap on Us logo |
| Jan 21, 2026 | Debug logs revealed Unicode character mismatch in entitlement ID |
| Jan 21, 2026 | Build 71 uploaded with fuzzy matching fix (UUID: 2b5b023f-93f8-4dc6-946f-7679edfee495) |
| Jan 21, 2026 | ✅ Build 71 verified - restore purchases working, user taken to main screen |
| Jan 21, 2026 | Build 74 submitted to Apple for review |
| Jan 21, 2026 | Demo account subscription expired in database for Apple testing |
| Jan 22, 2026 | Rejected - Guideline 2.3.2 (metadata) and 2.5.1 (HealthKit) |
| Jan 22, 2026 | Updated App Store description to clarify subscription requirements |
| Jan 22, 2026 | Added reviewer notes explaining Steps feature and HealthKit usage |

---

#### First Rejection - January 18, 2026

**Review Device:** iPad Air (5th generation)

**Apple's Feedback:**
> **Guideline 2.1 - Information Needed**
>
> We are not able to continue our review because we need access to a demo account with an expired subscription to review the entire purchase flow.

**What Apple Wants:**
1. See the paywall/subscription screen for expired users
2. Test the flow to re-subscribe
3. Verify app doesn't crash with expired subscription

**Initial Response:**
Created demo account and replied via App Store Connect message:
- Email: `us2appreview2026@gmail.com`
- Gmail Password: `Us2Review!Apple2026#`

---

#### Second Rejection - January 20, 2026

**Review Device:** iPad Air 11-inch (M3)

**Apple's Feedback:**
Same as before - still need expired subscription demo account.

**Apple's Screenshot Revealed the Problem:**
The reviewer successfully logged in, but saw:
- "PREMIUM ACTIVE" badge
- "You manage this subscription"
- "Renews Jan 12, 2027"

This was wrong - the account should show the paywall, not premium status.

---

#### Deep Investigation

**Database Query Results:**
```
Apple Review Account: us2appreview2026@gmail.com
User ID: 054b3551-0f69-4b38-96a2-ccee02483d1c
Couple ID: 16957918-207a-42fa-bd2c-f54e484d4920

Subscription Data in Database:
- subscription_status: 'expired'
- subscription_expires_at: 2026-01-18T11:52:41.821Z (in the past)
- subscription_product_id: 'us2_premium_monthly'
```

**The Mystery:**
- Database correctly showed `subscription_status: 'expired'`
- Database showed `subscription_expires_at: Jan 18, 2026`
- But app displayed "Renews Jan 12, 2027" - a completely different date
- The Jan 12, 2027 date existed in the database, but for DIFFERENT test couples

**Auth Session Analysis:**
```
Session 1: Jan 18, 16:30 UTC - IP: 81.175.211.140 (developer)
Session 2: Jan 20, 15:20 UTC - IP: 17.64.127.179 (Apple reviewer - Apple corporate IP)
```
Apple DID successfully log in.

**RevenueCat Investigation:**
- Only ONE sandbox customer existed in RevenueCat dashboard
- That customer had App User ID: `$RCAnonymousID:e007eb7125ee4d1bb2b92adf4becfda5`
- This was NOT the Apple review account (`054b3551-0f69-4b38-96a2-ccee02483d1c`)
- The sandbox customer had an active subscription that auto-renews

---

#### Root Cause

**The Bug:**
The `isPremium` getter in `subscription_service.dart` checked multiple sources:
1. Server couple subscription status
2. Cached couple status
3. **RevenueCat entitlements** (the problem)

If the server returned `isActive: false`, the code fell through to check RevenueCat. RevenueCat ties subscriptions to the **Apple ID on the device**, not the app's user account.

**What Happened:**
1. Apple reviewer's device had a sandbox Apple ID
2. That Apple ID had previously purchased a subscription (from earlier testing)
3. When reviewer logged in with the demo account, server correctly returned "expired"
4. But RevenueCat returned "active" based on the device's Apple ID
5. App showed "PREMIUM ACTIVE" because RevenueCat overrode the server

**Why "Jan 12, 2027":**
The profile screen displayed `coupleStatus.expiresAt` from the server for the "Renews" date, but the "PREMIUM ACTIVE" badge was triggered by RevenueCat. The mismatch between data sources caused confusing UI.

---

#### The Fix (Build 66)

**File:** `lib/services/subscription_service.dart`

**Change:** Made server status authoritative over RevenueCat for expired subscriptions.

```dart
// BEFORE: Server check, then fall through to RevenueCat
if (_coupleSubscriptionStatus?.isActive == true) {
  return true;
}
// ... eventually checks RevenueCat

// AFTER: Server "expired" is final, don't check RevenueCat
if (_coupleSubscriptionStatus?.isActive == true) {
  return true;
}

// If server explicitly says expired, trust that over RevenueCat
if (_coupleSubscriptionStatus?.status == 'expired') {
  return false;  // Don't fall through to RevenueCat
}
```

**Why This Is Correct:**
- Server is the source of truth for subscription status
- RevenueCat should only be used for NEW purchases (before server sync)
- An "expired" status from server means the subscription legitimately expired
- Device-level RevenueCat data from a different Apple ID shouldn't override this

---

#### Build 66 Submission

**Uploaded:** January 20, 2026 at 20:47 UTC
**Delivery UUID:** 80793ab5-d896-45a6-9429-3141840973c4

**Message to Apple:**
```
We've identified and fixed the issue. The demo account's subscription was correctly
marked as expired in our database, but the app was incorrectly displaying an active
subscription status due to device-level subscription data taking precedence.

We updated our subscription logic to ensure the server's subscription status is
authoritative. When an account has an expired subscription, the app now correctly
shows the paywall instead of premium status.

Build 66 has been uploaded and is available for review.

Demo Account (unchanged):
- Email: us2appreview2026@gmail.com
- Gmail Password: Us2Review!Apple2026#
```

---

#### Testing Revealed Additional Issue - January 21, 2026

**Testing Process:**
Before sending Build 66 to Apple, tested the full purchase flow with a sandbox account.

**Steps Taken:**
1. Logged in with demo account (expired subscription)
2. Verified paywall appeared ✓ (Build 66 fix worked!)
3. Tapped "Start Free Trial"
4. iOS purchase dialog appeared, completed purchase
5. RevenueCat dashboard showed successful purchase

**Problem Discovered:**
- App stayed on paywall after purchase completed
- "Restore Purchases" showed "No subscription found"
- Yet RevenueCat clearly had the subscription:
  - Customer ID: `054b3551-0f69-4b38-96a2-ccee02483d1c`
  - Entitlement: "Us 2.0 Pro" ✓
  - Product: `us2_premium_monthly` ✓

**Root Cause:**
The Build 66 fix was **too aggressive**. It blocked RevenueCat even after a NEW purchase:

1. User taps "Start Free Trial"
2. Paywall calls `checkCoupleSubscription()` → server returns "expired"
3. `_coupleSubscriptionStatus` is set to "expired" (both in-memory and Hive cache)
4. RevenueCat purchase succeeds
5. Server activation fails (network/timing issue)
6. `purchasePackage()` returns `success` anyway (activation will retry)
7. Paywall checks `isPremium`
8. `isPremium` sees `status == 'expired'` in cache → returns `false`
9. App stays on paywall!

**The Additional Fix:**
After a successful RevenueCat purchase/restore, clear both the in-memory AND cached couple status so `isPremium` can check RevenueCat directly:

```dart
// After RevenueCat purchase succeeds:
_clearCoupleStatus();  // Clears _coupleSubscriptionStatus AND Hive cache

// Now isPremium will:
// 1. See null status (not "expired")
// 2. Fall through to check RevenueCat
// 3. RevenueCat has entitlement → return true
// 4. User gets past paywall!
```

**File:** `lib/services/subscription_service.dart`

**Changes:**
- Added `_clearCoupleStatus()` helper method
- Called in `purchasePackage()` after successful purchase
- Called in `restorePurchases()` after successful restore

**Why This Doesn't Break The Apple Reviewer Fix:**
The Apple reviewer scenario:
1. Logs in (doesn't make a new purchase)
2. `checkCoupleSubscription()` returns "expired"
3. `isPremium` sees "expired" → returns `false` ✓
4. Paywall shown ✓

`_clearCoupleStatus()` is only called after `Purchases.purchasePackage()` or `Purchases.restorePurchases()` succeeds, not during regular login.

---

#### Third Rejection - January 22, 2026

**Submission ID:** `6cecd0e4-6dc4-49a8-a66e-33463320c19f`
**Review Device:** iPad Air 11-inch (M3)

**Apple's Feedback:**

**Issue 1: Guideline 2.3.2 - Accurate Metadata**
> We noticed your app's metadata refers to paid content or features, but they are not clearly identified as requiring additional purchase.

**Issue 2: Guideline 2.5.1 - HealthKit**
> Your app's binary includes references to HealthKit components, but the app does not appear to include any primary features that require health or fitness data.

---

**Response to Issue 1 (Metadata):**

Updated App Store description to clearly indicate subscription requirements:
- Added "Start with a 7-day free trial, then continue with Us 2.0 Premium to unlock unlimited activities and rewards" near the top
- Added dedicated SUBSCRIPTION INFO section explaining auto-renewal and subscription management
- Updated description saved to `appstore/description.txt`

**Response to Issue 2 (HealthKit):**

The Steps feature uses HealthKit but was not prominent enough for the reviewer to find it.

**Investigation findings:**
- Steps appears in the Games carousel (3rd position, after Linked and Word Search)
- Steps is iOS-only (skipped on web)
- Steps is NOT actually locked - any user can tap and open it immediately
- The "unlock chain" is purely visual guidance, not enforced

**Code evidence:** `StepsQuestCard` in `quest_carousel.dart` does not receive `isLocked` parameter and has no tap blocking logic, unlike regular `QuestCard` which checks lock state.

**Response:**
- Added reviewer notes explaining how to access Steps: Home screen → Games carousel → scroll right → Steps card (3rd position)
- Promoted Steps to its own section in App Store description (moved out of bullet list)
- Expanded Steps description to explain HealthKit integration purpose
- Reviewer notes saved to `appstore/reviewer_notes.txt`

---

#### Unicode Character Mismatch - Build 70/71

**Testing Process:**
Build 70 added a hidden debug overlay (triggered by triple-tap on Us logo) to diagnose restore issues in TestFlight.

**Debug Logs Revealed:**
```
activeEntitlements: [Us 2․0 Pro]
EXACT MATCH for "Us 2.0 Pro": NOT FOUND
```

**Root Cause:**
RevenueCat returns entitlement names with different Unicode characters than expected:
- **Expected:** `Us 2.0 Pro` (with U+002E FULL STOP for the period)
- **Actual:** `Us 2․0 Pro` (with U+2024 ONE DOT LEADER for the period)

The code was using `entitlements.active.containsKey('Us 2.0 Pro')` which failed because the period characters were different.

**The Fix (Build 71):**

1. Added fuzzy matching helpers to `RevenueCatConfig`:
```dart
static bool isPremiumEntitlement(String key) {
  final normalizedKey = _normalizeForComparison(key);
  final normalizedExpected = _normalizeForComparison(premiumEntitlement);
  if (normalizedKey == normalizedExpected) return true;
  // Fallback check for key parts
  return normalizedKey.contains('us2') && normalizedKey.contains('pro');
}

static String _normalizeForComparison(String s) {
  return s.toLowerCase()
      .replaceAll(RegExp(r'\s+'), '') // Remove whitespace
      .replaceAll('.', '')  // ASCII period U+002E
      .replaceAll('․', '')  // ONE DOT LEADER U+2024
      .replaceAll('·', ''); // MIDDLE DOT U+00B7
}
```

2. Updated `subscription_service.dart` with helper method:
```dart
EntitlementInfo? _getPremiumEntitlement() {
  if (_customerInfo == null) return null;
  // First try exact match
  final exactMatch = _customerInfo!.entitlements.active['Us 2.0 Pro'];
  if (exactMatch != null) return exactMatch;
  // Fall back to fuzzy matching
  for (final entry in _customerInfo!.entitlements.active.entries) {
    if (RevenueCatConfig.isPremiumEntitlement(entry.key)) {
      return entry.value;
    }
  }
  return null;
}
```

3. Replaced all exact key lookups with fuzzy matching throughout the service.

**Files Modified:**
- `lib/config/revenuecat_config.dart` - Added `isPremiumEntitlement()` and `_normalizeForComparison()`
- `lib/services/subscription_service.dart` - Added `_getPremiumEntitlement()` and `_hasRevenueCatPremium()`
- `lib/screens/paywall_screen.dart` - Updated debug overlay to show fuzzy match details

---

### Submission #2 - Version 1.0.1 (Marketing & ASO Update)

**Version:** 1.0.1 (Build 3)
**Submitted:** January 28, 2026
**Status:** 🔄 In Review

#### What's New Text
```
Crossword improvements and bug fixes:
• Improved clue readability with new text scaling
• Fixed splash screen background display
• Fixed contact links in Terms and Privacy pages
```

#### Changes Included

**1. New App Store Screenshots (9 total)**
- Professional marketing screenshots replacing placeholder images
- Location: `mockups/app_store_screenshots/marketing/style-us2/output/`
- Screens included:
  - Home screen
  - Quiz gameplay
  - Insights/Results
  - Word Search
  - Alignment visualization
  - Steps Together
  - Collection/Rewards
  - CTA/Download prompt
  - Crossword puzzle

**2. New Subtitle**
- **Previous:** (empty)
- **New:** "Daily games for two"

**3. Keywords Updated**
- **Previous:** `couples,relationship,quiz,love,dating,together,pair,connection,partner,marriage,attachment,anxious`
- **New:** `couples,quiz,relationship,games,together,connect,partner,activities,questions,word,fun,sync,rewards`
- **Rationale:**
  - Added unique differentiators (`sync`, `rewards`, `word`)
  - Removed competitor-adjacent terms (`pair`)
  - Maximized 100 character limit

**4. Code Fixes Included**
| Fix | Description |
|-----|-------------|
| G4 Crossword Clues | Split text at spaces with FittedBox scaling for better readability |
| Loading Screen | Gradient background now fills full screen width |
| URL Launcher | Fixed Terms/Privacy links on Android 11+ (removed canLaunchUrl check, added manifest queries) |

#### Related Documentation
- ASO plan: `marketing_agent/apps/us2/aso_plan.md`
- Release bundle: `marketing_agent/apps/us2/next_release_bundle.md`
- Competitor research: `marketing_agent/apps/us2/competitor_keyword_research.md`

#### Git Commit
```
6455b83 Implement G4 crossword clue system and fix URL launcher
```

---

## Lessons Learned

### 1. RevenueCat vs Server Authority
RevenueCat ties subscriptions to Apple ID, not app user accounts. When using a couple/family subscription model where the server tracks subscription status, the server must be authoritative. Don't let device-level RevenueCat data override explicit server states like "expired".

### 2. Sandbox Apple IDs Are Shared
Apple's review team uses shared sandbox Apple IDs. If any previous testing created subscriptions on those Apple IDs, ReviewCat will return them as active for ANY app account on that device.

### 3. Test With Fresh Devices
When testing expired subscription flows, use a device/Apple ID that has NEVER had an active subscription in your app.

### 4. Database vs Display Mismatch
When debugging subscription issues, check:
1. What the database shows
2. What the API returns
3. What RevenueCat returns
4. What the app displays
All four can be different due to caching and multiple data sources.

### 5. Test the Full Purchase Flow Before App Store Submission
Always test these scenarios with sandbox accounts BEFORE submitting:
1. New purchase from expired subscription state
2. Restore purchases from expired subscription state
3. New purchase with server activation failure (network off)
4. App restart after purchase (pending activation retry)

The fix for one issue (Apple reviewer seeing wrong status) can break another flow (new purchases not working).

### 6. RevenueCat May Use Different Unicode Characters
RevenueCat can return entitlement names with different Unicode characters than what you entered in the dashboard. Always use fuzzy/normalized string matching for entitlement ID lookups instead of exact string matching. Common character substitutions:
- Period: U+002E FULL STOP vs U+2024 ONE DOT LEADER
- Middle dot: U+00B7 MIDDLE DOT
- Spaces may also vary

**Always** normalize strings before comparison by removing/standardizing whitespace and period-like characters.

### 7. Clearly Disclose Subscriptions in Metadata
Apple requires paid content/features to be clearly labeled in App Store metadata. Include:
- Mention of free trial period near the top of description
- Dedicated SUBSCRIPTION INFO section with auto-renewal details
- Clear indication of what requires premium vs what's free

### 8. Make HealthKit Features Prominent
If your app uses HealthKit, the feature must be visible and easily accessible:
- Apple reviewers may not explore deeply - they need clear instructions
- Include HealthKit feature prominently in screenshots and description
- Provide step-by-step instructions in reviewer notes on how to access the feature
- Consider: Is the feature buried too deep in the UI?

---

## Common Rejection Reasons Reference

### Guideline 2.1 - App Completeness / Information Needed
- App crashes or has bugs
- Missing features that were advertised
- **Missing demo accounts** for testing subscriptions (active + expired)
- **RevenueCat/Apple ID conflicts** causing wrong subscription status
- **Fix:** Thorough testing; provide demo credentials in App Store Connect; ensure server is authoritative

### Guideline 2.3 - Accurate Metadata
- Screenshots don't match app functionality
- Description is misleading
- **Fix:** Update App Store Connect metadata

### Guideline 2.3.2 - Accurate Metadata (Paid Content)
- Metadata references paid content without clearly labeling it
- Subscription features not identified as requiring purchase
- **Fix:** Add clear subscription disclosure in description; add SUBSCRIPTION INFO section explaining trial, pricing, and auto-renewal

### Guideline 2.5.1 - Software Requirements (HealthKit)
- App includes HealthKit but feature isn't prominent/visible
- Reviewer can't find health-related functionality
- **Fix:** Make HealthKit feature more prominent in UI and metadata; provide clear instructions in reviewer notes on how to access the feature

### Guideline 3.1.1 - In-App Purchase
- Unlocking features without IAP
- External payment links
- **Fix:** Use RevenueCat/StoreKit for all purchases

### Guideline 4.2 - Minimum Functionality
- App is too simple
- Appears to be a web wrapper
- **Fix:** Demonstrate unique native functionality

### Guideline 5.1.1 - Data Collection and Storage
- Missing privacy policy
- Collecting data without consent
- **Fix:** Add privacy policy link, implement consent flows

### Guideline 5.1.2 - Data Use and Sharing
- Tracking without ATT consent
- **Fix:** Implement App Tracking Transparency if needed

---

## Submission Checklist

Before each submission, verify:

- [ ] All features tested on physical device
- [ ] No crashes or critical bugs
- [ ] Privacy policy URL is valid and accessible
- [ ] App Store screenshots are accurate
- [ ] Description matches current functionality
- [ ] **Subscription clearly disclosed** in description (trial period, premium features, auto-renewal)
- [ ] In-app purchases work correctly
- [ ] Push notifications have proper permission flow
- [ ] **HealthKit feature is prominent** and explained in reviewer notes (if applicable)
- [ ] Build uploaded via `xcrun altool` or Xcode
- [ ] **Demo account credentials provided** in App Review Information:
  - [ ] Expired subscription account (email + Gmail password for verification code)
  - [ ] Notes explaining login flow (app uses email verification, not passwords)
  - [ ] Instructions for accessing HealthKit features (e.g., "Steps card in Games carousel")
- [ ] **Subscription status tested on fresh device** (no previous purchases on that Apple ID)

---

## Demo Accounts

### Expired Subscription Account (for paywall testing)
- **Email:** us2appreview2026@gmail.com
- **Gmail Password:** Us2Review!Apple2026#
- **Database Status:** `subscription_status: 'expired'`
- **Expected Behavior:** Shows paywall on login
- **Note:** The app uses email verification (no app password). The Gmail password is only needed to access the inbox for the verification code.

### Login Instructions for Apple
1. Open the Us 2.0 app
2. Enter email: us2appreview2026@gmail.com
3. Tap "Continue" - verification code sent to email
4. Open Gmail (gmail.com) and sign in:
   - Email: us2appreview2026@gmail.com
   - Gmail password: Us2Review!Apple2026#
5. Find the email from "Us 2.0" with the 8-digit verification code
6. Enter the code in the app
7. Paywall appears (expired subscription)
8. Can test full purchase flow from there

---

## Technical Reference

### Subscription Status Flow
```
User logs in
    ↓
App calls GET /api/subscription/status
    ↓
Server queries couples table for subscription_status
    ↓
Returns: { status, isActive, expiresAt, ... }
    ↓
App's isPremium getter checks:
  1. Server status (authoritative)
  2. If server says "expired" → return false (STOP HERE - Build 66 fix)
  3. Cached status (for offline)
  4. RevenueCat (only for new purchases)
```

### Key Files
| File | Purpose |
|------|---------|
| `lib/services/subscription_service.dart` | Premium status logic, RevenueCat integration |
| `lib/models/couple_subscription_status.dart` | Subscription status model |
| `api/app/api/subscription/status/route.ts` | Server endpoint for subscription status |

### Database Tables
- `couples.subscription_status` - 'none', 'trial', 'active', 'cancelled', 'expired'
- `couples.subscription_expires_at` - Expiration timestamp
- `couples.subscription_user_id` - Who owns the subscription

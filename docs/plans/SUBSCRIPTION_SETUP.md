# Subscription Setup Plan

## Decision Summary

**Pricing Model:** Single tier, monthly only
- 7-day free trial → €9.99/month
- No annual tier (keeping it simple)

**Tools:**
- **RevenueCat** — Subscription infrastructure (purchases, receipt validation, entitlements)
- **Superwall** — Paywall presentation and A/B testing (Phase 2)

**Product IDs:**
- iOS: `us2_premium_monthly`
- Android: `us2_premium_monthly` (same ID)

---

## Phase A: Portal Configuration (Manual)

### A1. App Store Connect Setup

1. **Navigate to Subscriptions**
   - Go to [App Store Connect](https://appstoreconnect.apple.com)
   - Select "Us 2.0" app → Features → Subscriptions

2. **Create Subscription Group**
   - Click "+" to create new subscription group
   - Name: `Us 2.0 Premium`
   - This groups all subscription tiers (just one for now)

3. **Create Subscription Product**
   - Inside the group, click "+" to add subscription
   - Reference Name: `Premium Monthly` (internal only)
   - Product ID: `us2_premium_monthly`
   - Duration: 1 Month

4. **Set Pricing**
   - Click "Subscription Prices" → "+"
   - Base country: Choose your primary market
   - Price: €9.99 (or local equivalent tier)
   - Apple auto-generates prices for other regions

5. **Configure Free Trial**
   - Go to "Subscription Prices" section
   - Click "Set Up Introductory Offer" or find trial settings
   - Type: Free Trial
   - Duration: 7 days
   - Eligibility: New subscribers only

6. **Add Localization**
   - Add display name: "Us 2.0 Premium"
   - Add description: "Unlimited access to all relationship activities"
   - At minimum, add English localization

7. **Review Status**
   - Product should show "Ready to Submit" or similar
   - Note: Subscriptions can be tested in sandbox before app approval

- [ ] Subscription group created
- [ ] Product `us2_premium_monthly` created
- [ ] Pricing set (€9.99/month)
- [ ] 7-day free trial configured
- [ ] Localization added

### A2. RevenueCat Setup

1. **Create Project**
   - Go to [RevenueCat Dashboard](https://app.revenuecat.com)
   - Create new project: "Us 2.0"

2. **Add iOS App**
   - Click "Apps" → "+ New"
   - Platform: iOS
   - App name: "Us 2.0"
   - Bundle ID: `com.togetherremind.togetherremind2`

3. **Connect App Store Connect**
   - In RevenueCat, go to your iOS app → "App Store Connect API"
   - You need to create an API key in App Store Connect:
     - App Store Connect → Users and Access → Keys → App Store Connect API
     - Click "+" → Name: "RevenueCat" → Access: "Admin" or "App Manager"
     - Download the .p8 key file (only downloadable once!)
     - Note the Key ID and Issuer ID
   - Back in RevenueCat: Enter Issuer ID, Key ID, and upload .p8 file

4. **Create Entitlement**
   - Go to Project → Entitlements → "+ New"
   - Identifier: `premium`
   - Description: "Premium access to all features"

5. **Create Product**
   - Go to Products → "+ New"
   - Identifier: `us2_premium_monthly` (must match App Store Connect)
   - App: Select your iOS app

6. **Attach Product to Entitlement**
   - Go to the `premium` entitlement
   - Click "Attach" → Select `us2_premium_monthly`

7. **Create Offering**
   - Go to Offerings → "+ New"
   - Identifier: `default`
   - Add package:
     - Identifier: `$rc_monthly` (RevenueCat convention)
     - Product: `us2_premium_monthly`

8. **Get API Keys**
   - Go to Project → API Keys
   - Copy the **public** iOS API key (starts with `appl_`)
   - Save this for Flutter integration

- [x] RevenueCat project created
- [x] iOS app added with correct bundle ID
- [x] App Store Connect API connected
- [x] Entitlement `Us 2.0 Pro` created
- [x] Product `us2_premium_monthly` created and attached
- [x] Offering `default` created with monthly package
- [x] iOS API key copied for app integration

### A3. Test Sandbox User (Optional but Recommended)

1. **Create Sandbox Tester**
   - App Store Connect → Users and Access → Sandbox → Testers
   - Create a test account (use a real email you can access)

2. **On Test Device**
   - Settings → App Store → Sandbox Account
   - Sign in with sandbox tester credentials
   - This allows testing purchases without real charges

- [ ] Sandbox tester created
- [ ] Signed in on test device

---

## Phase B: Flutter Integration (Claude)

### B1. Add Dependencies

```yaml
# pubspec.yaml
dependencies:
  purchases_flutter: ^8.0.0
```

- [x] `purchases_flutter` added to pubspec.yaml
- [ ] `flutter pub get` run

### B2. Create SubscriptionService

Created `lib/services/subscription_service.dart`:

- [x] Initialize RevenueCat with API key
- [x] Implement `logIn(userId)` after auth
- [x] Implement `logOut()` on sign out
- [x] Implement `isPremium` getter (cached + fresh check)
- [x] Implement `getOfferings()` for paywall
- [x] Implement `purchasePackage()`
- [x] Implement `restorePurchases()`
- [x] Cache premium status in Hive for offline access

### B3. App Integration

Update initialization in `main.dart`:

```
1. Firebase
2. StorageService (Hive)
3. RevenueCat  ← NEW (after Hive - needs app_metadata box)
4. NotificationService
5. MockDataService
```

Integration points:
- [x] Initialize RevenueCat in main.dart
- [x] Call `logIn()` after successful Supabase auth (via AppBootstrapService)
- [x] Call `logOut()` on sign out (via AuthService.signOut)
- [x] Refresh subscription status on app resume
- [x] Add listener for subscription changes (CustomerInfoUpdateListener)

### B4. Basic Paywall UI

Create simple paywall (Superwall comes later):
- [x] Create `lib/screens/paywall_screen.dart`
- [x] Show subscription benefits
- [x] Display price with trial info
- [x] Purchase button
- [x] Restore purchases link
- [x] Loading/error states
- [x] Integrate into pairing flow (shows after successful pairing)
- [x] Skip logic for existing subscribers

### B5. Entitlement Gating

- [x] Add `SubscriptionService.isPremium` checks where needed
- [x] MainScreen checks subscription on load, shows paywall if lapsed
- [x] SubscriptionService now extends ChangeNotifier for reactive updates
- [ ] Add "Upgrade" button to settings screen (future enhancement)

---

## Phase C: Superwall (Future)

- [ ] Create Superwall account
- [ ] Connect to RevenueCat project
- [ ] Design paywall in dashboard
- [ ] Configure triggers
- [ ] Add Flutter SDK (`superwall_flutter`)
- [ ] Replace basic paywall with Superwall

---

## What to Gate (TBD)

Decisions needed on what requires premium:

| Feature | Free | Premium |
|---------|------|---------|
| Daily quests | ? | ? |
| All game types | ? | ? |
| Steps Together | ? | ? |
| LP multiplier | ? | ? |
| Ad removal | ? | ? |

---

## Paywall Trigger Points (TBD)

Potential places to show paywall:
- Locked feature tap
- Settings → "Upgrade" button
- After X days of free use
- After completing free content

---

## Why These Decisions

**Monthly only (no weekly):**
- Weekly feels predatory for a relationship/trust app
- Higher churn with 52 vs 12 renewal points
- Brand mismatch with intimacy-focused product

**No annual tier:**
- Simplicity over optimization
- One price = no decision paralysis
- Can add annual later if needed

**RevenueCat + Superwall combo:**
- RevenueCat handles purchase complexity
- Superwall allows no-code paywall iteration
- Industry standard pairing for mobile subscriptions

---

## Open Questions

1. What features are gated vs free?
2. Paywall design/copy
3. When to show paywall (triggers)
4. Restore purchases UI location

---

---

## Progress Summary

### Completed (2025-01-06)

**Phase A: Portal Configuration**
- App Store Connect: Subscription product `us2_premium_monthly` created (€9.99/month, 7-day trial)
- RevenueCat: Project configured, iOS app connected, entitlement and offering set up
- API key integrated into Flutter app

**Phase B: Flutter Integration**
- Added `purchases_flutter` v8.0.0 dependency
- Created `lib/config/revenuecat_config.dart` with API key
- Created `lib/services/subscription_service.dart` with full purchase flow
- Integrated into app initialization (`main.dart`)
- Added subscription login on auth (`app_bootstrap_service.dart`)
- Added subscription logout on sign out (`auth_service.dart`)
- Added subscription refresh on app resume

### Completed (2025-01-07)

**Phase B4: Paywall UI**
- Created `lib/screens/paywall_screen.dart` with Us 2.0 brand styling
- Features: Hero section, subscription card, 7-day trial badge, feature list, CTA button
- Integrated into pairing flow (`pairing_screen.dart`)
- Flow: Pairing Success → PaywallScreen → WelcomeQuiz/MainScreen
- Hard paywall: Users must start trial to access app
- Skip logic: Existing premium subscribers bypass paywall automatically

**Phase B5: Entitlement Gating (Hard Paywall)**
- MainScreen now checks subscription status on load
- If subscription lapsed/cancelled → shows PaywallScreen instead of app content
- No free tier: Everything requires active subscription or trial
- SubscriptionService extended with ChangeNotifier for reactive UI updates
- Network error fallback: Allows access if subscription check fails (don't lock out users)

**Subscription Flow Summary:**
```
New User:  Pairing → PaywallScreen → Start Trial → WelcomeQuiz → MainScreen
Returning: MainScreen → isPremium check → OK → App content
Lapsed:    MainScreen → isPremium check → FAIL → PaywallScreen → Resubscribe → App content
```

### Pending
- A1: App Store Connect screenshot (needed before App Review)
- A3: Sandbox tester setup for testing purchases
- Add "Upgrade" button to settings screen (optional)
- Phase C: Superwall integration (future)

---

*Status: Phase B - Flutter Integration COMPLETE (SDK, Paywall, and Gating done)*
*Last updated: 2025-01-07*

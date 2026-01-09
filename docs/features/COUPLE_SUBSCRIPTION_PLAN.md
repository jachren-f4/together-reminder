# Couple-Level Subscription System

## Overview

Implement a subscription system where **one subscription covers both users** in a couple. When either user subscribes, their partner automatically gets full access.

**Key Principles:**
- The `couples` table is the single source of truth for subscription status
- Only one user pays, both get access
- RevenueCat handles payment processing, our database tracks couple-level access
- Expiration is enforced via webhooks + expiration date fallback

---

## Foundation: RevenueCat & App Store Setup

*(Merged from docs/plans/SUBSCRIPTION_SETUP.md)*

### Pricing Model
- **Single tier, monthly only:** 7-day free trial → €9.99/month
- Product IDs: `us2_premium_monthly` (iOS and Android)

### App Store Connect Setup (Completed)
- Subscription product `us2_premium_monthly` created
- Price: €9.99/month with 7-day free trial
- Group: "Us 2.0 Premium"

### RevenueCat Configuration (Completed)
- Project: "Us 2.0"
- iOS app with bundle ID: `com.togetherremind.togetherremind2`
- Entitlement: `premium`
- Offering: `default` with `$rc_monthly` package

### Flutter Integration (Completed)
- `purchases_flutter: ^8.0.0` dependency
- `lib/config/revenuecat_config.dart` with API key
- `lib/services/subscription_service.dart` with RevenueCat integration
- Initialization in `main.dart`, login/logout tied to auth flow

---

## Implementation Checklist

### Phase 1: Database Schema
- [x] Create migration `035_couple_subscription.sql` with fields:
  - `subscription_status` (TEXT: 'none', 'trial', 'active', 'cancelled', 'expired', 'refunded')
  - `subscription_user_id` (UUID - who subscribed)
  - `subscription_started_at` (TIMESTAMPTZ)
  - `subscription_expires_at` (TIMESTAMPTZ)
  - `subscription_product_id` (TEXT - RevenueCat product ID)
- [ ] Run migration on Supabase *(Manual step required)*

### Phase 2: API Endpoints
- [x] Create `POST /api/subscription/activate` - Activate subscription for couple
- [x] Create `GET /api/subscription/status` - Get couple subscription status
- [x] Create `POST /api/subscription/webhook` - RevenueCat webhook handler

### Phase 3: Flutter - Paywall UI (Variant 7)
- [x] Update `PaywallScreen` headline to "One Subscription. Two Accounts."
- [x] Update subtitle to "You subscribe, your partner gets access too"
- [x] Create `AlreadySubscribedScreen` for when partner has subscribed

### Phase 4: Flutter - Subscription Service
- [x] Add `checkCoupleSubscription()` method to call `/api/subscription/status`
- [x] Update `purchasePackage()` to return `PurchaseResult` and call `/api/subscription/activate`
- [x] Handle `already_subscribed` response - navigate to AlreadySubscribedScreen
- [x] Update `isPremium` getter to check couple-level status
- [x] Add offline caching with 7-day grace period
- [x] Add retry logic for activation failures
- [x] Add pending activation for retry on app restart

### Phase 5: App Flow Integration
- [x] Update post-pairing flow to check couple subscription status
- [x] Update `AppBootstrapService` to fetch subscription status on launch
- [x] Update `ProfileScreen` to show subscription section with manager info
- [x] Add subscription transfer on re-pair (user with existing subscription pairs with new partner)

### Phase 6: Edge Cases
- [x] Paywall polling (5s) - detect when partner subscribes
- [x] Pre-purchase check - verify partner hasn't subscribed before initiating
- [x] Partner restore - check couple status first, then RevenueCat
- [x] Handle REFUND webhook event - revoke access immediately
- [x] Transfer subscription to new couple on re-pair

### Phase 7: Testing
- [ ] Test: User A subscribes → User A sees home
- [ ] Test: User B opens app → User B sees "Already Subscribed" screen
- [ ] Test: Both tap subscribe simultaneously → Only one charged
- [ ] Test: Subscription expires → Both see paywall
- [ ] Test: Either user can resubscribe after expiration
- [ ] Test: Paywall polling detects partner subscription
- [ ] Test: Refund revokes access for both users
- [ ] Test: Offline partner access with cached status

---

## Phase 1: Database Schema

### Migration: `035_couple_subscription.sql`

```sql
-- Couple-Level Subscription System
-- Migration: 035 - Add subscription fields to couples table

-- Add subscription fields to couples table
ALTER TABLE couples ADD COLUMN IF NOT EXISTS subscription_status TEXT DEFAULT 'none';
-- Values: 'none', 'trial', 'active', 'cancelled', 'expired'

ALTER TABLE couples ADD COLUMN IF NOT EXISTS subscription_user_id UUID REFERENCES auth.users(id);
-- The user who subscribed (manages the subscription)

ALTER TABLE couples ADD COLUMN IF NOT EXISTS subscription_started_at TIMESTAMPTZ;
-- When the subscription was first activated

ALTER TABLE couples ADD COLUMN IF NOT EXISTS subscription_expires_at TIMESTAMPTZ;
-- When the current billing period ends (for expiration checks)

ALTER TABLE couples ADD COLUMN IF NOT EXISTS subscription_product_id TEXT;
-- RevenueCat product ID (e.g., 'us2_premium_monthly')

-- Index for quick status lookups
CREATE INDEX IF NOT EXISTS idx_couples_subscription_status ON couples(subscription_status);
CREATE INDEX IF NOT EXISTS idx_couples_subscription_expires ON couples(subscription_expires_at);
```

---

## Phase 2: API Endpoints

### 2.1 POST /api/subscription/activate

Called by the app after RevenueCat purchase completes. Uses row locking to prevent race conditions.

**File:** `api/app/api/subscription/activate/route.ts`

```typescript
import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { withTransaction } from '@/lib/db/transaction';
import { getCoupleBasic } from '@/lib/couple/utils';

export async function POST(request: NextRequest) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    const body = await request.json();
    const { productId, expiresAt } = body;

    const couple = await getCoupleBasic(user.id);
    if (!couple) {
      return NextResponse.json({ error: 'No couple found' }, { status: 404 });
    }

    const result = await withTransaction(async (client) => {
      // Lock the couple row - prevents race condition
      const { rows } = await client.query(
        `SELECT subscription_status, subscription_user_id, u.name as subscriber_name
         FROM couples c
         LEFT JOIN auth.users u ON u.id = c.subscription_user_id
         WHERE c.id = $1
         FOR UPDATE`,
        [couple.coupleId]
      );

      const current = rows[0];

      // Check if already subscribed
      if (current.subscription_status === 'active' || current.subscription_status === 'trial') {
        // Get subscriber name for display
        const { rows: nameRows } = await client.query(
          `SELECT raw_user_meta_data->>'name' as name FROM auth.users WHERE id = $1`,
          [current.subscription_user_id]
        );

        return {
          alreadySubscribed: true,
          subscriberName: nameRows[0]?.name || 'Your partner',
          subscriberId: current.subscription_user_id
        };
      }

      // First one wins - activate subscription for couple
      await client.query(
        `UPDATE couples SET
           subscription_status = 'active',
           subscription_user_id = $1,
           subscription_started_at = NOW(),
           subscription_expires_at = $2,
           subscription_product_id = $3
         WHERE id = $4`,
        [user.id, expiresAt, productId, couple.coupleId]
      );

      return { alreadySubscribed: false };
    });

    if (result.alreadySubscribed) {
      return NextResponse.json({
        status: 'already_subscribed',
        subscriberName: result.subscriberName,
        message: `${result.subscriberName} already subscribed for both of you!`
      });
    }

    return NextResponse.json({
      status: 'activated',
      message: 'Subscription activated for both accounts'
    });

  } catch (error) {
    console.error('Subscription activation error:', error);
    return NextResponse.json({ error: 'Failed to activate subscription' }, { status: 500 });
  }
}
```

### 2.2 GET /api/subscription/status

Returns the couple's subscription status. Called on app launch and after pairing.

**File:** `api/app/api/subscription/status/route.ts`

```typescript
import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { getCoupleBasic } from '@/lib/couple/utils';

export async function GET(request: NextRequest) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    const couple = await getCoupleBasic(user.id);
    if (!couple) {
      return NextResponse.json({ error: 'No couple found' }, { status: 404 });
    }

    // Get subscription info with subscriber name
    const { data, error } = await supabase
      .from('couples')
      .select(`
        subscription_status,
        subscription_user_id,
        subscription_started_at,
        subscription_expires_at,
        subscription_product_id
      `)
      .eq('id', couple.coupleId)
      .single();

    if (error) throw error;

    // Check if expired (fallback if webhook was missed)
    let status = data.subscription_status || 'none';
    if (status === 'active' && data.subscription_expires_at) {
      const expiresAt = new Date(data.subscription_expires_at);
      if (expiresAt < new Date()) {
        // Update status to expired
        await supabase
          .from('couples')
          .update({ subscription_status: 'expired' })
          .eq('id', couple.coupleId);
        status = 'expired';
      }
    }

    // Get subscriber name if someone subscribed
    let subscriberName = null;
    if (data.subscription_user_id) {
      const { data: userData } = await supabase
        .from('auth.users')
        .select('raw_user_meta_data')
        .eq('id', data.subscription_user_id)
        .single();
      subscriberName = userData?.raw_user_meta_data?.name;
    }

    return NextResponse.json({
      status,
      isActive: status === 'active' || status === 'trial',
      subscribedByMe: data.subscription_user_id === user.id,
      subscriberName,
      expiresAt: data.subscription_expires_at,
      canManage: data.subscription_user_id === user.id
    });

  } catch (error) {
    console.error('Subscription status error:', error);
    return NextResponse.json({ error: 'Failed to get subscription status' }, { status: 500 });
  }
}
```

### 2.3 POST /api/subscription/webhook

Handles RevenueCat server-to-server webhook events.

**File:** `api/app/api/subscription/webhook/route.ts`

```typescript
import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

// Use service role for webhook (no user context)
const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

// Webhook event types from RevenueCat
type WebhookEvent =
  | 'INITIAL_PURCHASE'
  | 'RENEWAL'
  | 'CANCELLATION'
  | 'UNCANCELLATION'
  | 'EXPIRATION'
  | 'BILLING_ISSUE'
  | 'PRODUCT_CHANGE';

export async function POST(request: NextRequest) {
  try {
    // Verify webhook secret (optional but recommended)
    const authHeader = request.headers.get('Authorization');
    if (authHeader !== `Bearer ${process.env.REVENUECAT_WEBHOOK_SECRET}`) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const body = await request.json();
    const event = body.event as WebhookEvent;
    const appUserId = body.app_user_id; // This is our Supabase user ID
    const expiresAt = body.expiration_at_ms ? new Date(body.expiration_at_ms) : null;
    const productId = body.product_id;

    console.log(`RevenueCat webhook: ${event} for user ${appUserId}`);

    // Find the couple for this user
    const { data: couple } = await supabase
      .from('couples')
      .select('id')
      .or(`user1_id.eq.${appUserId},user2_id.eq.${appUserId}`)
      .single();

    if (!couple) {
      console.warn(`No couple found for user ${appUserId}`);
      return NextResponse.json({ received: true });
    }

    // Handle different event types
    switch (event) {
      case 'INITIAL_PURCHASE':
      case 'RENEWAL':
      case 'UNCANCELLATION':
        await supabase
          .from('couples')
          .update({
            subscription_status: 'active',
            subscription_expires_at: expiresAt?.toISOString(),
            subscription_product_id: productId
          })
          .eq('id', couple.id);
        break;

      case 'CANCELLATION':
        // Still active until expiration, just mark as cancelled
        await supabase
          .from('couples')
          .update({ subscription_status: 'cancelled' })
          .eq('id', couple.id);
        break;

      case 'EXPIRATION':
        await supabase
          .from('couples')
          .update({ subscription_status: 'expired' })
          .eq('id', couple.id);
        break;

      case 'BILLING_ISSUE':
        // Optionally: Send push notification to users
        console.warn(`Billing issue for couple ${couple.id}`);
        break;
    }

    return NextResponse.json({ received: true });

  } catch (error) {
    console.error('Webhook error:', error);
    return NextResponse.json({ error: 'Webhook processing failed' }, { status: 500 });
  }
}
```

---

## Phase 3: Flutter UI Changes

### 3.1 PaywallScreen - Variant 7 Messaging

**File:** `app/lib/screens/paywall_screen.dart`

**Reference:** `mockups/paywall/variant7-headline-simple.html`

#### Changes Required:

1. **Hero Title** (line ~302-305):
```dart
// BEFORE:
Text(
  widget.isLapsedUser
      ? 'Welcome Back!'
      : 'Your Journey to a\nDeeper Connection',
  ...
)

// AFTER:
Text(
  widget.isLapsedUser
      ? 'Welcome Back!'
      : 'One Subscription.\nTwo Accounts.',
  ...
)
```

2. **Hero Subtitle** (line ~316-320):
```dart
// BEFORE:
Text(
  widget.isLapsedUser
      ? 'We\'ve missed you'
      : 'Starts with just a few minutes a day',
  ...
)

// AFTER:
Text(
  widget.isLapsedUser
      ? 'We\'ve missed you'
      : 'You subscribe, your partner gets access too',
  ...
)
```

### 3.2 AlreadySubscribedScreen (New)

**File:** `app/lib/screens/already_subscribed_screen.dart`

**Reference:** `mockups/paywall/variant4-already-subscribed.html`

This screen is shown when the partner has already subscribed. It displays:
- Success checkmark icon
- "You're All Set!" headline
- "[Partner name] already subscribed for both of you."
- "PREMIUM ACTIVE" badge
- Feature list
- "Let's Go!" CTA button
- Note: "Subscription is managed by [Partner]. You'll keep access as long as the subscription is active."

---

## Phase 4: Flutter Service Changes

### 4.1 SubscriptionService Updates

**File:** `app/lib/services/subscription_service.dart`

#### New Methods to Add:

```dart
/// Check couple-level subscription status from server
Future<CoupleSubscriptionStatus> checkCoupleSubscription() async {
  final response = await ApiClient().get('/api/subscription/status');
  return CoupleSubscriptionStatus.fromJson(response);
}

/// Activate subscription for couple after RevenueCat purchase
Future<ActivationResult> activateForCouple({
  required String productId,
  required DateTime expiresAt,
}) async {
  final response = await ApiClient().post('/api/subscription/activate', body: {
    'productId': productId,
    'expiresAt': expiresAt.toIso8601String(),
  });
  return ActivationResult.fromJson(response);
}
```

#### Update purchasePackage():

```dart
Future<PurchaseResult> purchasePackage(Package package) async {
  // ... existing RevenueCat purchase code ...

  _customerInfo = await Purchases.purchasePackage(package);

  // NEW: After successful purchase, activate for couple
  if (isPremium) {
    final expiresAt = _getExpirationDate(_customerInfo!);
    final result = await activateForCouple(
      productId: package.storeProduct.identifier,
      expiresAt: expiresAt,
    );

    if (result.status == 'already_subscribed') {
      return PurchaseResult.alreadySubscribed(result.subscriberName);
    }
  }

  return PurchaseResult.success();
}
```

#### Update isPremium getter:

```dart
bool get isPremium {
  // Dev bypass
  if (kDebugMode && DevConfig.skipSubscriptionCheckInDev) {
    return true;
  }

  // Check cached couple subscription status first
  if (_coupleSubscriptionStatus?.isActive == true) {
    return true;
  }

  // Fall back to RevenueCat (for the subscriber's device)
  if (_customerInfo != null) {
    return _customerInfo!.entitlements.active.containsKey(RevenueCatConfig.premiumEntitlement);
  }

  return _getCachedPremiumStatus();
}
```

### 4.2 New Models

**File:** `app/lib/models/couple_subscription_status.dart`

```dart
class CoupleSubscriptionStatus {
  final String status; // 'none', 'trial', 'active', 'cancelled', 'expired'
  final bool isActive;
  final bool subscribedByMe;
  final String? subscriberName;
  final DateTime? expiresAt;
  final bool canManage;

  // ... fromJson, etc.
}

class ActivationResult {
  final String status; // 'activated' or 'already_subscribed'
  final String? subscriberName;
  final String? message;

  // ... fromJson, etc.
}

enum PurchaseResult {
  success,
  alreadySubscribed(String partnerName),
  cancelled,
  failed(String error);
}
```

---

## Phase 5: App Flow Integration

### 5.1 Post-Pairing Flow

**File:** `app/lib/screens/pairing_screen.dart`

After successful pairing, check if couple already has subscription:

```dart
Future<void> _onPairingComplete() async {
  // Check if couple already has subscription (partner subscribed before)
  final status = await SubscriptionService().checkCoupleSubscription();

  if (status.isActive) {
    // Partner already subscribed - skip paywall
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  } else {
    // No subscription - show paywall
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PaywallScreen(
        onContinue: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        ),
      )),
    );
  }
}
```

### 5.2 App Bootstrap

**File:** `app/lib/services/app_bootstrap_service.dart`

Add subscription status check to bootstrap:

```dart
Future<void> bootstrap() async {
  // ... existing bootstrap code ...

  // Check couple subscription status
  try {
    final status = await SubscriptionService().checkCoupleSubscription();
    SubscriptionService().setCoupleStatus(status);

    if (status.status == 'expired') {
      // Will show paywall on next navigation
      _subscriptionExpired = true;
    }
  } catch (e) {
    Logger.error('Failed to check subscription status', error: e);
  }
}
```

### 5.3 ProfileScreen Updates

**File:** `app/lib/screens/profile_screen.dart`

Update subscription section to show who manages:

```dart
Widget _buildSubscriptionSection() {
  final status = SubscriptionService().coupleStatus;

  if (status?.isActive != true) {
    return _buildSubscribeButton();
  }

  if (status!.subscribedByMe) {
    // User is the subscriber
    return ListTile(
      title: Text('Premium Active'),
      subtitle: Text('You manage this subscription'),
      trailing: TextButton(
        onPressed: _openSubscriptionManagement,
        child: Text('Manage'),
      ),
    );
  } else {
    // Partner is the subscriber
    return ListTile(
      title: Text('Premium Active'),
      subtitle: Text('Managed by ${status.subscriberName}'),
      trailing: Icon(Icons.check_circle, color: Colors.green),
    );
  }
}
```

---

## Expiration Handling

### How Expiration Works

1. **Subscription Created**: Store `subscription_expires_at` from RevenueCat
2. **Renewal**: RevenueCat webhook updates `subscription_expires_at`
3. **Cancellation**: Status → 'cancelled' (still active until expiry)
4. **Expiration**: RevenueCat webhook sets status → 'expired'
5. **Fallback**: `/api/subscription/status` checks expiration date if webhook missed

### Expiration Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    SUBSCRIPTION LIFECYCLE                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  User A subscribes                                               │
│       │                                                          │
│       ▼                                                          │
│  ┌─────────────┐    RevenueCat     ┌─────────────────────────┐  │
│  │ RevenueCat  │ ──────────────────▶ POST /webhook           │  │
│  │  Purchase   │   INITIAL_PURCHASE │ status = 'active'      │  │
│  └─────────────┘                    │ expires_at = date      │  │
│                                     └─────────────────────────┘  │
│                                                                  │
│  ... time passes ...                                             │
│                                                                  │
│  ┌─────────────┐    RevenueCat     ┌─────────────────────────┐  │
│  │  Renewal    │ ──────────────────▶ POST /webhook           │  │
│  │             │      RENEWAL       │ extends expires_at     │  │
│  └─────────────┘                    └─────────────────────────┘  │
│                                                                  │
│  ┌─────────────┐    RevenueCat     ┌─────────────────────────┐  │
│  │ User cancels│ ──────────────────▶ POST /webhook           │  │
│  │             │    CANCELLATION    │ status = 'cancelled'   │  │
│  └─────────────┘                    │ (still active til exp) │  │
│                                     └─────────────────────────┘  │
│                                                                  │
│  ┌─────────────┐    RevenueCat     ┌─────────────────────────┐  │
│  │  Period     │ ──────────────────▶ POST /webhook           │  │
│  │   ends      │     EXPIRATION     │ status = 'expired'     │  │
│  └─────────────┘                    └─────────────────────────┘  │
│                                                                  │
│  App opens (either user)                                         │
│       │                                                          │
│       ▼                                                          │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ GET /api/subscription/status                                │ │
│  │   - Returns status: 'expired'                               │ │
│  │   - Fallback: checks expires_at < NOW() if webhook missed   │ │
│  └─────────────────────────────────────────────────────────────┘ │
│       │                                                          │
│       ▼                                                          │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ PaywallScreen (isLapsedUser: true)                          │ │
│  │   "Welcome Back!"                                           │ │
│  │   Either user can resubscribe                               │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## RevenueCat Configuration

### 1. Webhook Setup

1. Go to RevenueCat Dashboard → Your App → Integrations → Webhooks
2. Add webhook URL: `https://api-joakim-achrens-projects.vercel.app/api/subscription/webhook`
3. Set Authorization Header: `Bearer YOUR_WEBHOOK_SECRET`
4. Enable events: `INITIAL_PURCHASE`, `RENEWAL`, `CANCELLATION`, `EXPIRATION`, `BILLING_ISSUE`

### 2. Environment Variables

Add to `api/.env`:
```
REVENUECAT_WEBHOOK_SECRET=your_secret_here
```

### 3. App User ID

Ensure the app logs into RevenueCat with Supabase user ID:
```dart
await Purchases.logIn(supabaseUserId);
```

---

## File Changes Summary

| File | Change Type | Description |
|------|-------------|-------------|
| `api/supabase/migrations/035_couple_subscription.sql` | NEW | Add subscription fields to couples |
| `api/app/api/subscription/activate/route.ts` | NEW | Activate subscription with row locking |
| `api/app/api/subscription/status/route.ts` | NEW | Get couple subscription status |
| `api/app/api/subscription/webhook/route.ts` | NEW | RevenueCat webhook handler |
| `app/lib/screens/paywall_screen.dart` | MODIFY | Update to Variant 7 messaging |
| `app/lib/screens/already_subscribed_screen.dart` | NEW | Partner already subscribed screen |
| `app/lib/services/subscription_service.dart` | MODIFY | Add couple-level subscription |
| `app/lib/models/couple_subscription_status.dart` | NEW | Status and result models |
| `app/lib/screens/pairing_screen.dart` | MODIFY | Check subscription after pairing |
| `app/lib/services/app_bootstrap_service.dart` | MODIFY | Check subscription on launch |
| `app/lib/screens/profile_screen.dart` | MODIFY | Show subscription manager info |

---

## Additional Edge Cases & Handling

### 1. Paywall Polling (Partner Just Subscribed)

**Problem:** Both users on paywall simultaneously. User A subscribes, User B doesn't know.

**Solution:** Poll subscription status on paywall screen.

**File:** `app/lib/screens/paywall_screen.dart`

```dart
class _PaywallScreenState extends State<PaywallScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
    _startPolling();  // NEW
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // Poll every 5 seconds to check if partner subscribed
  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final status = await SubscriptionService().checkCoupleSubscription();
        if (status.isActive && mounted) {
          _pollTimer?.cancel();
          // Partner subscribed! Show celebration and continue
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AlreadySubscribedScreen(
                subscriberName: status.subscriberName ?? 'Your partner',
                onContinue: widget.onContinue,
              ),
            ),
          );
        }
      } catch (e) {
        // Ignore polling errors
      }
    });
  }

  // Also check before initiating purchase
  Future<void> _startTrial() async {
    // Check if partner already subscribed before purchasing
    try {
      final status = await SubscriptionService().checkCoupleSubscription();
      if (status.isActive) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AlreadySubscribedScreen(
              subscriberName: status.subscriberName ?? 'Your partner',
              onContinue: widget.onContinue,
            ),
          ),
        );
        return;
      }
    } catch (e) {
      // Continue with purchase if check fails
    }

    // ... existing purchase code ...
  }
}
```

---

### 2. Restore Purchases for Partner

**Problem:** Partner taps "Restore" but has no RevenueCat purchase.

**Solution:** Check couple status first, only fall back to RevenueCat restore.

**File:** `app/lib/services/subscription_service.dart`

```dart
/// Restore purchases - checks couple status first, then RevenueCat
Future<RestoreResult> restorePurchases() async {
  // First: Check if partner already subscribed (couple-level)
  try {
    final status = await checkCoupleSubscription();
    if (status.isActive) {
      _coupleSubscriptionStatus = status;
      _updateCoupleStatusCache(status);
      notifyListeners();
      return RestoreResult.coupleActive(status.subscriberName);
    }
  } catch (e) {
    Logger.debug('Couple status check failed, trying RevenueCat', service: 'subscription');
  }

  // Second: Try RevenueCat restore (for the original subscriber)
  if (!kIsWeb && RevenueCatConfig.isConfigured) {
    try {
      _customerInfo = await Purchases.restorePurchases();
      if (isPremium) {
        // Subscriber restored - also activate for couple
        await _activateForCouple();
        return RestoreResult.revenueCatRestored();
      }
    } catch (e) {
      Logger.error('RevenueCat restore failed', error: e);
    }
  }

  return RestoreResult.nothingToRestore();
}

enum RestoreResult {
  coupleActive(String? partnerName),   // Partner subscribed
  revenueCatRestored(),                 // Own subscription restored
  nothingToRestore();                   // No subscription found
}
```

**File:** `app/lib/screens/paywall_screen.dart`

```dart
Future<void> _restorePurchases() async {
  setState(() => _isRestoring = true);

  try {
    final result = await _subscriptionService.restorePurchases();

    if (!mounted) return;

    switch (result) {
      case RestoreResult.coupleActive(partnerName: final name):
        // Partner subscribed - show success screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AlreadySubscribedScreen(
              subscriberName: name ?? 'Your partner',
              onContinue: widget.onContinue,
            ),
          ),
        );
        break;

      case RestoreResult.revenueCatRestored():
        widget.onContinue();
        break;

      case RestoreResult.nothingToRestore():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No subscription found')),
        );
        break;
    }
  } finally {
    if (mounted) setState(() => _isRestoring = false);
  }
}
```

---

### 3. Activate API Failure Recovery

**Problem:** RevenueCat purchase succeeds but `/api/subscription/activate` fails.

**Solution:**
1. Retry the activate call
2. Webhook serves as backup (will also set status)
3. Cache intent locally, retry on next app open

**File:** `app/lib/services/subscription_service.dart`

```dart
Future<bool> purchasePackage(Package package) async {
  // ... RevenueCat purchase ...
  _customerInfo = await Purchases.purchasePackage(package);

  if (isPremium) {
    // Try to activate for couple with retry
    await _activateForCoupleWithRetry(package);
  }

  return isPremium;
}

Future<void> _activateForCoupleWithRetry(Package package) async {
  const maxRetries = 3;

  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      final expiresAt = _getExpirationDate(_customerInfo!);
      await activateForCouple(
        productId: package.storeProduct.identifier,
        expiresAt: expiresAt,
      );
      // Clear any pending activation
      await _clearPendingActivation();
      return;
    } catch (e) {
      Logger.error('Activate attempt $attempt failed', error: e);

      if (attempt == maxRetries) {
        // Save pending activation for retry on next app open
        await _savePendingActivation(package.storeProduct.identifier);
        // Webhook will also activate, so not critical
        Logger.warn('Activate failed, webhook will handle it');
      } else {
        await Future.delayed(Duration(seconds: attempt));
      }
    }
  }
}

// Called on app startup
Future<void> retryPendingActivation() async {
  final pending = await _getPendingActivation();
  if (pending != null && isPremium) {
    try {
      final expiresAt = _getExpirationDate(_customerInfo!);
      await activateForCouple(productId: pending, expiresAt: expiresAt);
      await _clearPendingActivation();
    } catch (e) {
      Logger.error('Pending activation retry failed', error: e);
    }
  }
}
```

---

### 4. Offline Caching for Partner

**Problem:** Partner has no RevenueCat entitlement, needs offline access.

**Solution:** Cache `CoupleSubscriptionStatus` in Hive.

**File:** `app/lib/services/subscription_service.dart`

```dart
// Hive cache keys
static const String _coupleStatusCacheKey = 'couple_subscription_status';
static const String _coupleStatusCacheTimeKey = 'couple_subscription_status_time';

/// Cache couple subscription status for offline access
void _updateCoupleStatusCache(CoupleSubscriptionStatus status) {
  try {
    final box = Hive.box('app_metadata');
    box.put(_coupleStatusCacheKey, status.toJson());
    box.put(_coupleStatusCacheTimeKey, DateTime.now().toIso8601String());
  } catch (e) {
    Logger.debug('Failed to cache couple status: $e');
  }
}

/// Get cached couple subscription status (for offline)
CoupleSubscriptionStatus? _getCachedCoupleStatus() {
  try {
    final box = Hive.box('app_metadata');
    final json = box.get(_coupleStatusCacheKey);
    final cacheTime = box.get(_coupleStatusCacheTimeKey);

    if (json == null) return null;

    // Check if cache is still valid (within 7 days for offline grace period)
    if (cacheTime != null) {
      final cached = DateTime.parse(cacheTime);
      if (DateTime.now().difference(cached).inDays > 7) {
        return null; // Cache too old
      }
    }

    return CoupleSubscriptionStatus.fromJson(json);
  } catch (e) {
    return null;
  }
}

/// Updated isPremium getter with offline support
bool get isPremium {
  // Dev bypass
  if (kDebugMode && DevConfig.skipSubscriptionCheckInDev) {
    return true;
  }

  // Check live couple status first
  if (_coupleSubscriptionStatus?.isActive == true) {
    return true;
  }

  // Check cached couple status (for offline partner access)
  final cachedStatus = _getCachedCoupleStatus();
  if (cachedStatus?.isActive == true) {
    // Verify not expired
    if (cachedStatus!.expiresAt == null ||
        cachedStatus.expiresAt!.isAfter(DateTime.now())) {
      return true;
    }
  }

  // Fall back to RevenueCat (for subscriber's device)
  if (_customerInfo != null) {
    return _customerInfo!.entitlements.active.containsKey(
      RevenueCatConfig.premiumEntitlement
    );
  }

  return _getCachedPremiumStatus();
}
```

---

### 5. Refund Handling

**Problem:** RevenueCat processes refund, we need to revoke access.

**Solution:** Handle `REFUND` webhook event.

**File:** `api/app/api/subscription/webhook/route.ts`

Add to the switch statement:

```typescript
case 'REFUND':
  // Refund processed - revoke access immediately
  await supabase
    .from('couples')
    .update({
      subscription_status: 'refunded',
      subscription_expires_at: new Date().toISOString() // Expire now
    })
    .eq('id', couple.id);

  // Optionally: Log refund for analytics
  console.log(`Refund processed for couple ${couple.id}`);
  break;
```

Also update the type:

```typescript
type WebhookEvent =
  | 'INITIAL_PURCHASE'
  | 'RENEWAL'
  | 'CANCELLATION'
  | 'UNCANCELLATION'
  | 'EXPIRATION'
  | 'BILLING_ISSUE'
  | 'PRODUCT_CHANGE'
  | 'REFUND';  // Added
```

---

### 6. Unpair Handling

**Problem:** User unpairs - what happens to subscription?

**Policy Decision:**
- Subscriber keeps their RevenueCat subscription (they paid for it)
- Couple's subscription fields are cleared when couple is deleted
- If subscriber pairs with new person, new couple has no subscription (must resubscribe or we could detect & transfer)

**Implementation:**

The couple record is deleted on unpair (existing behavior), so subscription fields are automatically cleared. The subscriber still has their RevenueCat entitlement.

**Optional Enhancement:** Transfer subscription to new couple if subscriber re-pairs.

**File:** `app/lib/services/couple_pairing_service.dart` - Add to pairing flow:

```dart
Future<void> _onPairingComplete() async {
  // Check if current user has active RevenueCat subscription
  // If so, activate it for the new couple
  if (SubscriptionService().hasRevenueCatEntitlement) {
    try {
      await SubscriptionService().activateForCouple(
        productId: SubscriptionService().currentProductId!,
        expiresAt: SubscriptionService().currentExpiresAt!,
      );
      Logger.info('Transferred subscription to new couple');
    } catch (e) {
      Logger.error('Failed to transfer subscription', error: e);
    }
  }

  // Continue with normal flow...
}
```

---

## Updated Implementation Checklist

### Additional Tasks (Edge Cases)
- [ ] Add polling on PaywallScreen (5s interval)
- [ ] Check subscription before initiating purchase
- [ ] Update restore logic to check couple status first
- [ ] Add retry logic for activate API failure
- [ ] Save pending activation for retry on app restart
- [ ] Cache CoupleSubscriptionStatus in Hive for offline
- [ ] Add 7-day offline grace period
- [ ] Handle REFUND webhook event
- [ ] Add 'refunded' status handling
- [ ] Transfer subscription to new couple on re-pair (optional)

---

## Testing Checklist

### Happy Path
- [ ] User A subscribes → Couple status = 'active', User A sees home
- [ ] User B opens app → Sees "Already Subscribed" screen → Taps "Let's Go" → Home
- [ ] Both users can access all premium features

### Race Condition Prevention
- [ ] User A and User B tap subscribe simultaneously
- [ ] Only one RevenueCat charge occurs
- [ ] Second user sees "Already Subscribed" screen
- [ ] Database shows single `subscription_user_id`

### Expiration Flow
- [ ] Subscription expires (or simulate via RevenueCat sandbox)
- [ ] Webhook updates status to 'expired'
- [ ] Both users see paywall on next app open
- [ ] Either user can resubscribe

### Edge Cases
- [ ] User subscribes while offline → Syncs on next online
- [ ] Webhook fails → Expiration date fallback catches it
- [ ] User reinstalls app → Status restored from server
- [ ] Couple unpairs → Original subscriber keeps their RevenueCat subscription
- [ ] Subscriber re-pairs → Subscription transfers to new couple

### Paywall Polling
- [ ] User A on paywall, User B subscribes → User A sees AlreadySubscribedScreen within 5s
- [ ] User taps subscribe but partner just subscribed → Blocked, shown AlreadySubscribedScreen

### Restore for Partner
- [ ] Partner taps "Restore" → Checks couple status → Shows AlreadySubscribedScreen
- [ ] Subscriber taps "Restore" on new device → RevenueCat restore works → Activates for couple

### Offline Access
- [ ] Partner goes offline with cached status → Still has access
- [ ] Partner offline for >7 days → Access revoked (cache expired)
- [ ] Subscriber works offline via RevenueCat cache

### Failure Recovery
- [ ] Purchase succeeds, activate fails → Retries 3x → Saves pending
- [ ] App reopens with pending activation → Retries and clears
- [ ] Webhook activates even if app failed

### Refund
- [ ] Refund processed → Webhook sets status to 'refunded' → Both lose access

---

## Mockup References

| Screen | Mockup File |
|--------|-------------|
| Paywall (new messaging) | `mockups/paywall/variant7-headline-simple.html` |
| Already Subscribed | `mockups/paywall/variant4-already-subscribed.html` |
| All variants index | `mockups/paywall/index.html` |

---

## Implementation Status

**Completed:** 2025-01-09

All phases 1-6 have been implemented. See the checklist above for details.

**Pending Manual Steps:**
1. Run migration `035_couple_subscription.sql` on Supabase
2. Configure RevenueCat webhook URL: `https://api-joakim-achrens-projects.vercel.app/api/subscription/webhook`
3. Add `REVENUECAT_WEBHOOK_SECRET` to Vercel environment variables
4. Test all scenarios from the Testing Checklist (Phase 7)

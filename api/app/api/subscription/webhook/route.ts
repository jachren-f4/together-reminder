/**
 * POST /api/subscription/webhook
 *
 * Handles RevenueCat server-to-server webhook events.
 * This endpoint does NOT use user auth - it's called by RevenueCat servers
 * and authenticated via a shared secret in the Authorization header.
 *
 * Events handled:
 * - INITIAL_PURCHASE: First subscription purchase
 * - RENEWAL: Subscription renewed
 * - CANCELLATION: User cancelled (still active until expiration)
 * - UNCANCELLATION: User reactivated cancelled subscription
 * - EXPIRATION: Subscription period ended
 * - BILLING_ISSUE: Payment failed
 * - PRODUCT_CHANGE: User changed plan
 * - REFUND: Refund processed - revoke access immediately
 */

import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db/pool';

// Webhook event types from RevenueCat
type WebhookEvent =
  | 'INITIAL_PURCHASE'
  | 'RENEWAL'
  | 'CANCELLATION'
  | 'UNCANCELLATION'
  | 'EXPIRATION'
  | 'BILLING_ISSUE'
  | 'PRODUCT_CHANGE'
  | 'REFUND'
  | 'TEST'; // RevenueCat sends TEST events to verify webhook

export async function POST(request: NextRequest) {
  try {
    // Verify webhook secret
    const authHeader = request.headers.get('Authorization');
    const expectedSecret = process.env.REVENUECAT_WEBHOOK_SECRET;

    // In production, require the secret. In dev, allow without.
    if (expectedSecret && authHeader !== `Bearer ${expectedSecret}`) {
      console.warn('Webhook auth failed - invalid or missing secret');
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const body = await request.json();

    // RevenueCat wraps the event data
    const eventData = body.event || body;
    const event = eventData.type as WebhookEvent;
    const appUserId = eventData.app_user_id; // This is our Supabase user ID
    const expiresAt = eventData.expiration_at_ms
      ? new Date(eventData.expiration_at_ms)
      : null;
    const productId = eventData.product_id;

    console.log(`RevenueCat webhook: ${event} for user ${appUserId}`);

    // Handle test event
    if (event === 'TEST') {
      console.log('RevenueCat test webhook received');
      return NextResponse.json({ received: true });
    }

    if (!appUserId) {
      console.warn('Webhook missing app_user_id');
      return NextResponse.json({ received: true, warning: 'No app_user_id' });
    }

    // Find the couple for this user
    const { rows: coupleRows } = await query(
      `SELECT c.id FROM user_couples uc
       JOIN couples c ON c.id = uc.couple_id
       WHERE uc.user_id = $1`,
      [appUserId]
    );

    if (coupleRows.length === 0) {
      console.warn(`No couple found for user ${appUserId}`);
      // Still return 200 - don't make RevenueCat retry
      return NextResponse.json({ received: true, warning: 'No couple found' });
    }

    const coupleId = coupleRows[0].id;

    // Handle different event types
    switch (event) {
      case 'INITIAL_PURCHASE':
      case 'RENEWAL':
      case 'UNCANCELLATION':
        await query(
          `UPDATE couples SET
             subscription_status = 'active',
             subscription_expires_at = $1,
             subscription_product_id = $2,
             subscription_user_id = COALESCE(subscription_user_id, $3),
             subscription_started_at = COALESCE(subscription_started_at, NOW())
           WHERE id = $4`,
          [expiresAt?.toISOString() || null, productId, appUserId, coupleId]
        );
        console.log(`Subscription activated/renewed for couple ${coupleId}`);
        break;

      case 'CANCELLATION':
        // Still active until expiration, just mark as cancelled
        await query(
          `UPDATE couples SET subscription_status = 'cancelled' WHERE id = $1`,
          [coupleId]
        );
        console.log(`Subscription cancelled for couple ${coupleId}`);
        break;

      case 'EXPIRATION':
        await query(
          `UPDATE couples SET subscription_status = 'expired' WHERE id = $1`,
          [coupleId]
        );
        console.log(`Subscription expired for couple ${coupleId}`);
        break;

      case 'REFUND':
        // Refund processed - revoke access immediately
        await query(
          `UPDATE couples SET
             subscription_status = 'refunded',
             subscription_expires_at = NOW()
           WHERE id = $1`,
          [coupleId]
        );
        console.log(`Refund processed for couple ${coupleId}`);
        break;

      case 'BILLING_ISSUE':
        // Log but don't change status - RevenueCat handles retries
        console.warn(`Billing issue for couple ${coupleId}`);
        break;

      case 'PRODUCT_CHANGE':
        // Update product ID
        await query(
          `UPDATE couples SET subscription_product_id = $1 WHERE id = $2`,
          [productId, coupleId]
        );
        console.log(`Product changed for couple ${coupleId}`);
        break;

      default:
        console.log(`Unhandled webhook event: ${event}`);
    }

    return NextResponse.json({ received: true });
  } catch (error) {
    console.error('Webhook error:', error);
    // Return 500 so RevenueCat will retry
    return NextResponse.json(
      { error: 'Webhook processing failed' },
      { status: 500 }
    );
  }
}

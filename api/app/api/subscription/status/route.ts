/**
 * GET /api/subscription/status
 *
 * Returns the couple's subscription status.
 * Called on app launch, after pairing, and during paywall polling.
 *
 * Also performs expiration fallback check - if subscription appears active
 * but expires_at has passed (webhook might have been missed), marks as expired.
 */

import { NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { getCoupleBasic } from '@/lib/couple/utils';

export const GET = withAuthOrDevBypass(async (req, userId) => {
  try {
    const couple = await getCoupleBasic(userId);
    if (!couple) {
      return NextResponse.json({ error: 'No couple found' }, { status: 404 });
    }

    // Get subscription info
    const { rows } = await query(
      `SELECT
         subscription_status,
         subscription_user_id,
         subscription_started_at,
         subscription_expires_at,
         subscription_product_id
       FROM couples
       WHERE id = $1`,
      [couple.coupleId]
    );

    const data = rows[0];
    let status = data.subscription_status || 'none';

    // Expiration fallback check - if webhook was missed
    if (
      (status === 'active' || status === 'cancelled') &&
      data.subscription_expires_at
    ) {
      const expiresAt = new Date(data.subscription_expires_at);
      if (expiresAt < new Date()) {
        // Update status to expired
        await query(
          `UPDATE couples SET subscription_status = 'expired' WHERE id = $1`,
          [couple.coupleId]
        );
        status = 'expired';
      }
    }

    // Get subscriber name if someone subscribed
    let subscriberName = null;
    if (data.subscription_user_id) {
      const { rows: userRows } = await query(
        `SELECT raw_user_meta_data->>'name' as name FROM auth.users WHERE id = $1`,
        [data.subscription_user_id]
      );
      subscriberName = userRows[0]?.name || null;
    }

    return NextResponse.json({
      status,
      isActive: status === 'active' || status === 'trial',
      subscribedByMe: data.subscription_user_id === userId,
      subscriberName,
      subscriberId: data.subscription_user_id,
      expiresAt: data.subscription_expires_at,
      productId: data.subscription_product_id,
      canManage: data.subscription_user_id === userId,
    });
  } catch (error) {
    console.error('Subscription status error:', error);
    return NextResponse.json(
      { error: 'Failed to get subscription status' },
      { status: 500 }
    );
  }
});

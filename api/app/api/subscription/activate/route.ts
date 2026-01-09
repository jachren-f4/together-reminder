/**
 * POST /api/subscription/activate
 *
 * Activate subscription for a couple after RevenueCat purchase completes.
 * Uses row locking to prevent race conditions when both partners try to subscribe
 * simultaneously - first one wins, second sees "already_subscribed".
 */

import { NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { withTransaction } from '@/lib/db/transaction';
import { getCoupleBasic } from '@/lib/couple/utils';

export const POST = withAuthOrDevBypass(async (req, userId) => {
  try {
    const body = await req.json();
    const { productId, expiresAt } = body;

    if (!productId) {
      return NextResponse.json({ error: 'Missing productId' }, { status: 400 });
    }

    const couple = await getCoupleBasic(userId);
    if (!couple) {
      return NextResponse.json({ error: 'No couple found' }, { status: 404 });
    }

    const result = await withTransaction(async (client) => {
      // Lock the couple row - prevents race condition when both partners subscribe simultaneously
      const { rows } = await client.query(
        `SELECT subscription_status, subscription_user_id
         FROM couples
         WHERE id = $1
         FOR UPDATE`,
        [couple.coupleId]
      );

      const current = rows[0];

      // Check if already subscribed by partner
      if (
        (current.subscription_status === 'active' || current.subscription_status === 'trial') &&
        current.subscription_user_id !== userId
      ) {
        // Get subscriber name for display
        const { rows: nameRows } = await client.query(
          `SELECT raw_user_meta_data->>'name' as name FROM auth.users WHERE id = $1`,
          [current.subscription_user_id]
        );

        return {
          alreadySubscribed: true,
          subscriberName: nameRows[0]?.name || 'Your partner',
          subscriberId: current.subscription_user_id,
        };
      }

      // First one wins - activate subscription for couple
      await client.query(
        `UPDATE couples SET
           subscription_status = 'active',
           subscription_user_id = $1,
           subscription_started_at = COALESCE(subscription_started_at, NOW()),
           subscription_expires_at = $2,
           subscription_product_id = $3
         WHERE id = $4`,
        [userId, expiresAt || null, productId, couple.coupleId]
      );

      return { alreadySubscribed: false };
    });

    if (result.alreadySubscribed) {
      return NextResponse.json({
        status: 'already_subscribed',
        subscriberName: result.subscriberName,
        message: `${result.subscriberName} already subscribed for both of you!`,
      });
    }

    return NextResponse.json({
      status: 'activated',
      message: 'Subscription activated for both accounts',
    });
  } catch (error) {
    console.error('Subscription activation error:', error);
    return NextResponse.json(
      { error: 'Failed to activate subscription' },
      { status: 500 }
    );
  }
});

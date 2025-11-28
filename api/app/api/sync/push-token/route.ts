import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { NextResponse } from 'next/server';

/**
 * POST /api/sync/push-token
 *
 * Register or update the user's FCM push token.
 * Called on app startup to ensure we have the latest token.
 *
 * Body: { fcmToken: string, platform: 'ios' | 'android' | 'web', deviceName?: string }
 */
export const POST = withAuthOrDevBypass(async (req, userId) => {
  try {
    const body = await req.json();
    const { fcmToken, platform, deviceName } = body;

    if (!fcmToken) {
      return NextResponse.json({ error: 'fcmToken is required' }, { status: 400 });
    }

    if (!platform || !['ios', 'android', 'web'].includes(platform)) {
      return NextResponse.json(
        { error: 'platform must be ios, android, or web' },
        { status: 400 }
      );
    }

    // Upsert the push token
    await query(
      `INSERT INTO user_push_tokens (user_id, fcm_token, platform, device_name, updated_at)
       VALUES ($1, $2, $3, $4, NOW())
       ON CONFLICT (user_id)
       DO UPDATE SET
         fcm_token = EXCLUDED.fcm_token,
         platform = EXCLUDED.platform,
         device_name = COALESCE(EXCLUDED.device_name, user_push_tokens.device_name),
         updated_at = NOW()`,
      [userId, fcmToken, platform, deviceName || null]
    );

    console.log(`[PUSH TOKEN] Registered for user ${userId} on ${platform}`);

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Error registering push token:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
});

/**
 * GET /api/sync/push-token
 *
 * Get the partner's FCM push token for sending notifications.
 * Returns null if partner hasn't registered a token yet.
 *
 * Response: { partnerToken: string | null, partnerPlatform: string | null }
 */
export const GET = withAuthOrDevBypass(async (req, userId) => {
  try {
    // Find couple and partner
    const coupleResult = await query(
      `SELECT user1_id, user2_id FROM couples WHERE user1_id = $1 OR user2_id = $1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json({ partnerToken: null, partnerPlatform: null });
    }

    const couple = coupleResult.rows[0];
    const partnerId = couple.user1_id === userId ? couple.user2_id : couple.user1_id;

    // Get partner's push token
    const tokenResult = await query(
      `SELECT fcm_token, platform FROM user_push_tokens WHERE user_id = $1`,
      [partnerId]
    );

    if (tokenResult.rows.length === 0) {
      return NextResponse.json({ partnerToken: null, partnerPlatform: null });
    }

    const { fcm_token, platform } = tokenResult.rows[0];

    return NextResponse.json({
      partnerToken: fcm_token,
      partnerPlatform: platform,
    });
  } catch (error) {
    console.error('Error getting partner push token:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
});

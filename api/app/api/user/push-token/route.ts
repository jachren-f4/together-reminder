/**
 * User Push Token Endpoint
 *
 * Syncs FCM push token to the server for notifications.
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuth } from '@/lib/auth/middleware';
import { RateLimitPresets, withRateLimit } from '@/lib/auth/rate-limit';
import { query } from '@/lib/db/pool';

export const dynamic = 'force-dynamic';

// Handle CORS preflight
export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    },
  });
}

/**
 * Update user's push token
 *
 * POST /api/user/push-token
 * Body: { token: string, platform: 'ios' | 'android' | 'web', deviceName?: string }
 *
 * Returns: { success: true }
 */
export const POST = withRateLimit(
  RateLimitPresets.sync,
  withAuth(async (req, userId, email) => {
    try {
      const body = await req.json();
      const { token, platform, deviceName } = body;

      // Validate token
      if (!token || typeof token !== 'string') {
        return NextResponse.json(
          { error: 'Token is required' },
          { status: 400 }
        );
      }

      // Validate platform
      const validPlatforms = ['ios', 'android', 'web'];
      if (!platform || !validPlatforms.includes(platform)) {
        return NextResponse.json(
          { error: 'Platform must be ios, android, or web' },
          { status: 400 }
        );
      }

      // Upsert push token
      await query(
        `INSERT INTO user_push_tokens (user_id, fcm_token, platform, device_name, updated_at)
         VALUES ($1, $2, $3, $4, NOW())
         ON CONFLICT (user_id)
         DO UPDATE SET
           fcm_token = $2,
           platform = $3,
           device_name = COALESCE($4, user_push_tokens.device_name),
           updated_at = NOW()`,
        [userId, token, platform, deviceName || null]
      );

      console.log(`[PushToken] User ${userId} updated push token for ${platform}`);

      return NextResponse.json({ success: true });
    } catch (error) {
      console.error('Error updating push token:', error);
      return NextResponse.json(
        { error: 'Failed to update push token' },
        { status: 500 }
      );
    }
  })
);

/**
 * Get user's push token
 *
 * GET /api/user/push-token
 *
 * Returns: { token: string, platform: string } | { token: null }
 */
export const GET = withRateLimit(
  RateLimitPresets.sync,
  withAuth(async (req, userId, email) => {
    try {
      const result = await query(
        `SELECT fcm_token, platform, device_name, updated_at
         FROM user_push_tokens
         WHERE user_id = $1`,
        [userId]
      );

      if (result.rows.length === 0) {
        return NextResponse.json({ token: null });
      }

      const row = result.rows[0];
      return NextResponse.json({
        token: row.fcm_token,
        platform: row.platform,
        deviceName: row.device_name,
        updatedAt: row.updated_at,
      });
    } catch (error) {
      console.error('Error fetching push token:', error);
      return NextResponse.json(
        { error: 'Failed to fetch push token' },
        { status: 500 }
      );
    }
  })
);

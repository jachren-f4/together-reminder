/**
 * Complete Signup Endpoint
 *
 * Called after OTP verification to complete user profile setup.
 * Returns full user state including couple/partner if exists.
 * Idempotent - safe to call multiple times.
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
 * Complete user signup and return full state
 *
 * POST /api/user/complete-signup
 * Body: { pushToken?: string, platform?: string, name?: string }
 *
 * Returns: {
 *   user: { id, email, name, createdAt },
 *   couple: { id, createdAt } | null,
 *   partner: { id, name, email, avatarEmoji } | null
 * }
 */
export const POST = withRateLimit(
  RateLimitPresets.auth,
  withAuth(async (req, userId, email) => {
    try {
      // Parse optional body
      let pushToken: string | null = null;
      let platform: string | null = null;
      let name: string | null = null;
      let birthday: string | null = null;

      try {
        const body = await req.json();
        pushToken = body.pushToken || null;
        platform = body.platform || null;
        name = body.name || null;
        birthday = body.birthday || null;
      } catch {
        // Body is optional, ignore parse errors
      }

      // Get user info from auth.users
      const userResult = await query(
        `SELECT id, email, created_at, raw_user_meta_data
         FROM auth.users
         WHERE id = $1`,
        [userId]
      );

      if (userResult.rows.length === 0) {
        return NextResponse.json(
          { error: 'User not found' },
          { status: 404 }
        );
      }

      const userRow = userResult.rows[0];
      const metadata = userRow.raw_user_meta_data as Record<string, any> | null;
      const userName = metadata?.full_name || metadata?.name || null;
      const userBirthday = metadata?.birthday || null;

      // Build metadata updates object
      const metadataUpdates: Record<string, any> = {};

      // If name provided in request and different from stored, add to updates
      if (name && name !== userName) {
        metadataUpdates.full_name = name;
      }

      // If birthday provided in request and different from stored, add to updates
      if (birthday && birthday !== userBirthday) {
        metadataUpdates.birthday = birthday;
      }

      // Apply metadata updates if any
      if (Object.keys(metadataUpdates).length > 0) {
        await query(
          `UPDATE auth.users
           SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || $1::jsonb,
               updated_at = NOW()
           WHERE id = $2`,
          [JSON.stringify(metadataUpdates), userId]
        );
      }

      // Save push token if provided
      if (pushToken && platform) {
        await query(
          `INSERT INTO user_push_tokens (user_id, fcm_token, platform, updated_at)
           VALUES ($1, $2, $3, NOW())
           ON CONFLICT (user_id)
           DO UPDATE SET fcm_token = $2, platform = $3, updated_at = NOW()`,
          [userId, pushToken, platform]
        );
      }

      // Check if user is in a couple
      const coupleResult = await query(
        `SELECT
           c.id as couple_id,
           c.created_at as couple_created_at,
           CASE
             WHEN c.user1_id = $1 THEN c.user2_id
             ELSE c.user1_id
           END as partner_id
         FROM couples c
         WHERE c.user1_id = $1 OR c.user2_id = $1`,
        [userId]
      );

      let couple = null;
      let partner = null;

      if (coupleResult.rows.length > 0) {
        const coupleRow = coupleResult.rows[0];
        couple = {
          id: coupleRow.couple_id,
          createdAt: coupleRow.couple_created_at,
        };

        // Get partner info
        const partnerResult = await query(
          `SELECT u.id, u.email, u.raw_user_meta_data,
                  pt.fcm_token as push_token
           FROM auth.users u
           LEFT JOIN user_push_tokens pt ON pt.user_id = u.id
           WHERE u.id = $1`,
          [coupleRow.partner_id]
        );

        if (partnerResult.rows.length > 0) {
          const partnerRow = partnerResult.rows[0];
          const partnerMetadata = partnerRow.raw_user_meta_data as Record<string, any> | null;
          const partnerName = partnerMetadata?.full_name ||
                             partnerMetadata?.name ||
                             partnerRow.email?.split('@')[0] ||
                             'Partner';

          partner = {
            id: partnerRow.id,
            name: partnerName,
            email: partnerRow.email,
            pushToken: partnerRow.push_token || null,
            avatarEmoji: '💕',
          };
        }
      }

      // Build response
      const response = {
        user: {
          id: userId,
          email: userRow.email,
          name: name || userName,
          createdAt: userRow.created_at,
        },
        couple,
        partner,
      };

      console.log(`[CompleteSignup] User ${userId} completed signup. Couple: ${couple ? 'yes' : 'no'}`);

      return NextResponse.json(response);
    } catch (error) {
      console.error('Error in complete-signup:', error);
      return NextResponse.json(
        { error: 'Failed to complete signup' },
        { status: 500 }
      );
    }
  })
);

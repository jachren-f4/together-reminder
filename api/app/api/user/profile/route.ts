/**
 * User Profile Endpoint
 *
 * Returns full user state including couple/partner if exists.
 * Used for device switching and state restoration.
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
 * Get user profile with full state
 *
 * GET /api/user/profile
 *
 * Returns: {
 *   user: { id, email, name, createdAt },
 *   couple: { id, createdAt } | null,
 *   partner: { id, name, email, avatarEmoji } | null
 * }
 */
export const GET = withRateLimit(
  RateLimitPresets.sync,
  withAuth(async (req, userId, email) => {
    try {
      // Get user info from auth.users
      const userResult = await query(
        `SELECT u.id, u.email, u.created_at, u.raw_user_meta_data,
                pt.fcm_token as push_token, pt.platform
         FROM auth.users u
         LEFT JOIN user_push_tokens pt ON pt.user_id = u.id
         WHERE u.id = $1`,
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
          name: userName,
          pushToken: userRow.push_token || null,
          platform: userRow.platform || null,
          createdAt: userRow.created_at,
        },
        couple,
        partner,
      };

      return NextResponse.json(response);
    } catch (error) {
      console.error('Error fetching user profile:', error);
      return NextResponse.json(
        { error: 'Failed to fetch profile' },
        { status: 500 }
      );
    }
  })
);

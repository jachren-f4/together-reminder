/**
 * Couple Status Endpoint
 *
 * Check current pairing status and get partner info
 */

import { NextResponse } from 'next/server';
import { withAuth } from '@/lib/auth/middleware';
import { RateLimitPresets, withRateLimit } from '@/lib/auth/rate-limit';
import { query } from '@/lib/db/pool';

export const dynamic = 'force-dynamic';

/**
 * Get current couple status
 *
 * GET /api/couples/status
 *
 * Returns:
 * - If paired: { isPaired: true, coupleId, partnerId, partnerEmail, createdAt }
 * - If not paired: { isPaired: false }
 */
export const GET = withRateLimit(
  RateLimitPresets.sync,
  withAuth(async (req, userId) => {
    try {
      // Check if user is in a couple
      const coupleResult = await query(
        `SELECT
           c.id as couple_id,
           c.created_at,
           CASE
             WHEN c.user1_id = $1 THEN c.user2_id
             ELSE c.user1_id
           END as partner_id
         FROM couples c
         WHERE c.user1_id = $1 OR c.user2_id = $1`,
        [userId]
      );

      if (coupleResult.rows.length === 0) {
        return NextResponse.json({
          isPaired: false,
        });
      }

      const couple = coupleResult.rows[0];

      // Get partner info (email and name from metadata)
      const partnerResult = await query(
        `SELECT email, raw_user_meta_data FROM auth.users WHERE id = $1`,
        [couple.partner_id]
      );

      // Extract partner name from metadata or email
      const partnerEmail = partnerResult.rows[0]?.email || null;
      const partnerMetadata = partnerResult.rows[0]?.raw_user_meta_data as Record<string, any> | null;
      const partnerName = partnerMetadata?.full_name ||
                         partnerMetadata?.name ||
                         partnerEmail?.split('@')[0] ||
                         'Partner';

      return NextResponse.json({
        isPaired: true,
        coupleId: couple.couple_id,
        partnerId: couple.partner_id,
        partnerEmail,
        partnerName,
        createdAt: couple.created_at,
      });
    } catch (error) {
      console.error('Error fetching couple status:', error);
      return NextResponse.json(
        { error: 'Failed to fetch couple status' },
        { status: 500 }
      );
    }
  })
);

/**
 * Leave couple (unpair)
 *
 * DELETE /api/couples/status
 *
 * Returns: { success: true }
 */
export const DELETE = withRateLimit(
  RateLimitPresets.auth,
  withAuth(async (req, userId) => {
    try {
      // Delete couple where user is a member
      const result = await query(
        `DELETE FROM couples
         WHERE user1_id = $1 OR user2_id = $1
         RETURNING id`,
        [userId]
      );

      if (result.rows.length === 0) {
        return NextResponse.json(
          { error: 'You are not paired with anyone' },
          { status: 400 }
        );
      }

      return NextResponse.json({
        success: true,
        message: 'Successfully left couple',
      });
    } catch (error) {
      console.error('Error leaving couple:', error);
      return NextResponse.json(
        { error: 'Failed to leave couple' },
        { status: 500 }
      );
    }
  })
);

/**
 * Direct Couple Pairing Endpoint
 *
 * Pairs two users directly by userId (for QR code flow)
 * Unlike /join which requires an invite code, this allows direct pairing
 * when one user has the other's userId from a QR code.
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuth } from '@/lib/auth/middleware';
import { RateLimitPresets, withRateLimit } from '@/lib/auth/rate-limit';
import { query, getClient } from '@/lib/db/pool';
import { randomUUID } from 'crypto';

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
 * Pair directly with another user by their userId
 *
 * POST /api/couples/pair-direct
 * Body: { partnerId: string }
 *
 * Returns: { coupleId: string, partnerId: string, partnerEmail: string, partnerName: string }
 */
export const POST = withRateLimit(
  RateLimitPresets.auth,
  withAuth(async (req, userId, email) => {
    const client = await getClient();

    try {
      const body = await req.json();
      const { partnerId } = body;

      if (!partnerId || typeof partnerId !== 'string') {
        return NextResponse.json(
          { error: 'Partner ID is required' },
          { status: 400 }
        );
      }

      // Can't pair with yourself
      if (partnerId === userId) {
        client.release();
        return NextResponse.json(
          { error: 'You cannot pair with yourself' },
          { status: 400 }
        );
      }

      // Check if user already has a partner
      const existingCouple = await client.query(
        `SELECT id FROM couples
         WHERE user1_id = $1 OR user2_id = $1`,
        [userId]
      );

      if (existingCouple.rows.length > 0) {
        client.release();
        return NextResponse.json(
          { error: 'You are already paired with a partner' },
          { status: 400 }
        );
      }

      // Verify partner exists
      const partnerResult = await client.query(
        `SELECT id, email, raw_user_meta_data FROM auth.users WHERE id = $1`,
        [partnerId]
      );

      if (partnerResult.rows.length === 0) {
        client.release();
        return NextResponse.json(
          { error: 'Partner not found' },
          { status: 404 }
        );
      }

      // Start transaction
      await client.query('BEGIN');

      // Check if partner already has a couple (race condition protection)
      const partnerCouple = await client.query(
        `SELECT id FROM couples
         WHERE user1_id = $1 OR user2_id = $1
         FOR UPDATE`,
        [partnerId]
      );

      if (partnerCouple.rows.length > 0) {
        await client.query('ROLLBACK');
        client.release();
        return NextResponse.json(
          { error: 'This person is already paired with someone else' },
          { status: 400 }
        );
      }

      // Create couple (partner is user1, scanner is user2)
      const coupleId = randomUUID();
      const coupleResult = await client.query(
        `INSERT INTO couples (id, user1_id, user2_id, created_at, updated_at)
         VALUES ($1, $2, $3, NOW(), NOW())
         RETURNING created_at`,
        [coupleId, partnerId, userId]
      );
      const coupleCreatedAt = coupleResult.rows[0].created_at;

      // Get partner's push token (before releasing client)
      const partnerTokenResult = await client.query(
        `SELECT fcm_token FROM user_push_tokens WHERE user_id = $1`,
        [partnerId]
      );
      const partnerPushToken = partnerTokenResult.rows[0]?.fcm_token || null;

      await client.query('COMMIT');
      client.release();

      // Extract partner info
      const partnerEmail = partnerResult.rows[0]?.email || null;
      const partnerMetadata = partnerResult.rows[0]?.raw_user_meta_data as Record<string, any> | null;
      const partnerName = partnerMetadata?.full_name ||
                         partnerMetadata?.name ||
                         partnerEmail?.split('@')[0] ||
                         'Partner';

      console.log(`[Pairing] Direct pair created: ${userId} paired with ${partnerId}, coupleId: ${coupleId}`);

      return NextResponse.json({
        coupleId,
        partnerId,
        partnerEmail,
        partnerName,
        createdAt: coupleCreatedAt,
        // New format: complete partner object
        partner: {
          id: partnerId,
          name: partnerName,
          email: partnerEmail,
          pushToken: partnerPushToken,
          avatarEmoji: '💕',
        },
        message: 'Successfully paired!',
      });
    } catch (error) {
      await client.query('ROLLBACK');
      client.release();
      console.error('Error in direct pairing:', error);
      return NextResponse.json(
        { error: 'Failed to pair' },
        { status: 500 }
      );
    }
  })
);

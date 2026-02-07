/**
 * Couple Join Endpoint
 *
 * Accept an invite code and create couple relationship
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuth } from '@/lib/auth/middleware';
import { RateLimitPresets, withRateLimit } from '@/lib/auth/rate-limit';
import { query, getClient } from '@/lib/db/pool';
import { randomUUID } from 'crypto';
import { getPhantomPartnerId } from '@/lib/phantom/utils';
import { mergePhantomToReal } from '@/lib/phantom/merge';

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
 * Join a couple using invite code
 *
 * POST /api/couples/join
 * Body: { code: string }
 *
 * Returns: { coupleId: string, partnerId: string, partnerEmail: string }
 */
export const POST = withRateLimit(
  RateLimitPresets.auth,
  withAuth(async (req, userId, email) => {
    const client = await getClient();

    try {
      const body = await req.json();
      const { code } = body;

      if (!code || typeof code !== 'string') {
        return NextResponse.json(
          { error: 'Invite code is required' },
          { status: 400 }
        );
      }

      // Normalize code (remove spaces, convert to uppercase)
      const normalizedCode = code.trim().toUpperCase();

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

      // Start transaction
      await client.query('BEGIN');

      // Find and validate the invite code
      const inviteResult = await client.query(
        `SELECT id, created_by, expires_at
         FROM couple_invites
         WHERE UPPER(code) = $1
         AND used_at IS NULL
         AND expires_at > NOW()
         FOR UPDATE`,
        [normalizedCode]
      );

      if (inviteResult.rows.length === 0) {
        await client.query('ROLLBACK');
        client.release();
        return NextResponse.json(
          { error: 'Invalid or expired invite code' },
          { status: 400 }
        );
      }

      const invite = inviteResult.rows[0];
      const partnerId = invite.created_by;

      // Can't pair with yourself
      if (partnerId === userId) {
        await client.query('ROLLBACK');
        client.release();
        return NextResponse.json(
          { error: 'You cannot pair with yourself' },
          { status: 400 }
        );
      }

      // Check if partner already has a couple (race condition protection)
      const partnerCouple = await client.query(
        `SELECT id FROM couples
         WHERE user1_id = $1 OR user2_id = $1`,
        [partnerId]
      );

      if (partnerCouple.rows.length > 0) {
        // Partner has an existing couple — check if it has a phantom partner
        const existingCoupleId = partnerCouple.rows[0].id;
        const phantomUserId = await getPhantomPartnerId(existingCoupleId, client);

        if (!phantomUserId) {
          // No phantom — partner is genuinely paired with someone else
          await client.query('ROLLBACK');
          client.release();
          return NextResponse.json(
            { error: 'This person is already paired with someone else' },
            { status: 400 }
          );
        }

        // Phantom partner found — merge phantom into real user
        const mergeResult = await mergePhantomToReal(
          client,
          existingCoupleId,
          phantomUserId,
          userId
        );

        if (!mergeResult.success) {
          await client.query('ROLLBACK');
          client.release();
          console.error('Phantom merge failed:', mergeResult.error);
          return NextResponse.json(
            { error: 'Failed to complete pairing. Please try again.' },
            { status: 500 }
          );
        }

        // Mark invite as used (with the existing couple ID)
        await client.query(
          `UPDATE couple_invites
           SET used_at = NOW(), used_by = $1, couple_id = $2
           WHERE id = $3`,
          [userId, existingCoupleId, invite.id]
        );

        // Get partner info
        const partnerResult = await client.query(
          `SELECT email, raw_user_meta_data FROM auth.users WHERE id = $1`,
          [partnerId]
        );

        // Get partner's push token
        const partnerTokenResult = await client.query(
          `SELECT fcm_token FROM user_push_tokens WHERE user_id = $1`,
          [partnerId]
        );
        const partnerPushToken = partnerTokenResult.rows[0]?.fcm_token || null;

        // Get couple created_at
        const coupleInfo = await client.query(
          `SELECT created_at FROM couples WHERE id = $1`,
          [existingCoupleId]
        );

        await client.query('COMMIT');
        client.release();

        const partnerEmail = partnerResult.rows[0]?.email || null;
        const partnerMetadata = partnerResult.rows[0]?.raw_user_meta_data as Record<string, any> | null;
        const partnerName = partnerMetadata?.full_name ||
                           partnerMetadata?.name ||
                           partnerEmail?.split('@')[0] ||
                           'Partner';

        console.log(`Phantom merge complete: couple=${existingCoupleId}, phantom=${phantomUserId} → real=${userId}, tables=${mergeResult.tablesUpdated}`);

        return NextResponse.json({
          coupleId: existingCoupleId,
          partnerId,
          partnerEmail,
          partnerName,
          createdAt: coupleInfo.rows[0]?.created_at,
          partner: {
            id: partnerId,
            name: partnerName,
            email: partnerEmail,
            pushToken: partnerPushToken,
            avatarEmoji: '💕',
          },
          merged: true,
          message: 'Successfully paired!',
        });
      }

      // No existing couple — create a new one (standard flow)
      const coupleId = randomUUID();
      const coupleResult = await client.query(
        `INSERT INTO couples (id, user1_id, user2_id, created_at, updated_at)
         VALUES ($1, $2, $3, NOW(), NOW())
         RETURNING created_at`,
        [coupleId, partnerId, userId]
      );
      const coupleCreatedAt = coupleResult.rows[0].created_at;

      // Mark invite as used
      await client.query(
        `UPDATE couple_invites
         SET used_at = NOW(), used_by = $1, couple_id = $2
         WHERE id = $3`,
        [userId, coupleId, invite.id]
      );

      // Get partner info (email and name from metadata)
      const partnerResult = await client.query(
        `SELECT email, raw_user_meta_data FROM auth.users WHERE id = $1`,
        [partnerId]
      );

      // Get the invite creator's push token for notification
      const inviteWithToken = await client.query(
        `SELECT creator_push_token FROM couple_invites WHERE id = $1`,
        [invite.id]
      );

      // Get partner's push token (before releasing client)
      const partnerTokenResult = await client.query(
        `SELECT fcm_token FROM user_push_tokens WHERE user_id = $1`,
        [partnerId]
      );
      const partnerPushToken = partnerTokenResult.rows[0]?.fcm_token || null;

      await client.query('COMMIT');
      client.release();

      // Extract partner name from metadata or email
      const partnerEmail = partnerResult.rows[0]?.email || null;
      const partnerMetadata = partnerResult.rows[0]?.raw_user_meta_data as Record<string, any> | null;
      const partnerName = partnerMetadata?.full_name ||
                         partnerMetadata?.name ||
                         partnerEmail?.split('@')[0] ||
                         'Partner';

      // TODO: Send FCM notification to partner (code generator) if they have a push token
      const creatorPushToken = inviteWithToken.rows[0]?.creator_push_token;
      if (creatorPushToken) {
        // FCM notification will be implemented after database migration
      }

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
      console.error('Error joining couple:', error);
      return NextResponse.json(
        { error: 'Failed to join couple' },
        { status: 500 }
      );
    }
  })
);

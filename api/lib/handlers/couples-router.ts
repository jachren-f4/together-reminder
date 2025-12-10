/**
 * Couples Router - Route functions for the couples domain
 *
 * Exports route functions that dispatch to internal handlers:
 * - routeCouplesGET(req, subPath)
 * - routeCouplesPOST(req, subPath)
 * - routeCouplesDELETE(req, subPath)
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuth } from '@/lib/auth/middleware';
import { RateLimitPresets, withRateLimit } from '@/lib/auth/rate-limit';
import { query, getClient } from '@/lib/db/pool';
import { randomUUID } from 'crypto';

// ============================================================================
// ROUTER FUNCTIONS
// ============================================================================

/**
 * Route GET requests for couples domain
 */
export function routeCouplesGET(req: NextRequest, subPath: string[]) {
  const path = subPath.join('/');

  switch (path) {
    case 'invite':
      return withRateLimit(
        RateLimitPresets.auth,
        withAuth(handleInviteGET)
      )(req);
    case 'status':
      return withRateLimit(
        RateLimitPresets.sync,
        withAuth(handleStatusGET)
      )(req);
    default:
      return NextResponse.json({ error: `Unknown couples route: ${path}` }, { status: 404 });
  }
}

/**
 * Route POST requests for couples domain
 */
export function routeCouplesPOST(req: NextRequest, subPath: string[]) {
  const path = subPath.join('/');

  switch (path) {
    case 'invite':
      return withRateLimit(
        RateLimitPresets.auth,
        withAuth(handleInvitePOST)
      )(req);
    case 'join':
      return withRateLimit(
        RateLimitPresets.auth,
        withAuth(handleJoinPOST)
      )(req);
    case 'pair-direct':
      return withRateLimit(
        RateLimitPresets.auth,
        withAuth(handlePairDirectPOST)
      )(req);
    default:
      return NextResponse.json({ error: `Unknown couples route: ${path}` }, { status: 404 });
  }
}

/**
 * Route DELETE requests for couples domain
 */
export function routeCouplesDELETE(req: NextRequest, subPath: string[]) {
  const path = subPath.join('/');

  switch (path) {
    case 'status':
      return withRateLimit(
        RateLimitPresets.auth,
        withAuth(handleStatusDELETE)
      )(req);
    default:
      return NextResponse.json({ error: `Unknown couples route: ${path}` }, { status: 404 });
  }
}

// ============================================================================
// INVITE HANDLERS
// ============================================================================

/**
 * Get current active invite code
 *
 * GET /api/couples/invite
 *
 * Returns: { code: string, expiresAt: string } or { code: null }
 */
async function handleInviteGET(req: NextRequest, userId: string) {
  try {
    const result = await query(
      `SELECT code, expires_at
       FROM couple_invites
       WHERE created_by = $1
       AND used_at IS NULL
       AND expires_at > NOW()
       ORDER BY created_at DESC
       LIMIT 1`,
      [userId]
    );

    if (result.rows.length === 0) {
      return NextResponse.json({ code: null });
    }

    return NextResponse.json({
      code: result.rows[0].code,
      expiresAt: result.rows[0].expires_at,
    });
  } catch (error) {
    console.error('Error fetching invite code:', error);
    return NextResponse.json(
      { error: 'Failed to fetch invite code' },
      { status: 500 }
    );
  }
}

/**
 * Generate a new invite code
 *
 * POST /api/couples/invite
 *
 * Returns: { code: string, expiresAt: string }
 */
async function handleInvitePOST(req: NextRequest, userId: string) {
  try {
    // Parse request body for optional push token
    let pushToken: string | null = null;
    try {
      const body = await req.json();
      pushToken = body.pushToken || null;
    } catch {
      // No body or invalid JSON - that's fine
    }

    // Check if user already has a partner
    const existingCouple = await query(
      `SELECT id FROM couples
       WHERE user1_id = $1 OR user2_id = $1`,
      [userId]
    );

    if (existingCouple.rows.length > 0) {
      return NextResponse.json(
        { error: 'You are already paired with a partner' },
        { status: 400 }
      );
    }

    // Invalidate any existing active codes for this user
    await query(
      `UPDATE couple_invites
       SET expires_at = NOW()
       WHERE created_by = $1
       AND used_at IS NULL
       AND expires_at > NOW()`,
      [userId]
    );

    // Generate 6-digit code
    const code = Math.floor(100000 + Math.random() * 900000).toString();

    // Set expiry to 24 hours from now
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);

    // Insert new invite code with optional push token
    const result = await query(
      `INSERT INTO couple_invites (id, code, created_by, expires_at, creator_push_token)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING code, expires_at`,
      [randomUUID(), code, userId, expiresAt.toISOString(), pushToken]
    );

    return NextResponse.json({
      code: result.rows[0].code,
      expiresAt: result.rows[0].expires_at,
    });
  } catch (error: any) {
    console.error('Error generating invite code:', error);
    console.error('Error code:', error.code);
    console.error('Error message:', error.message);
    console.error('Error detail:', error.detail);

    // Handle unique constraint violation (unlikely but possible)
    if (error.code === '23505') {
      return NextResponse.json(
        { error: 'Please try again' },
        { status: 500 }
      );
    }

    // Return detailed error in development
    const isDev = process.env.NODE_ENV !== 'production';
    return NextResponse.json(
      {
        error: isDev ? `${error.message || 'Failed to generate invite code'}` : 'Failed to generate invite code',
        code: isDev ? error.code : undefined,
      },
      { status: 500 }
    );
  }
}

// ============================================================================
// JOIN HANDLER
// ============================================================================

/**
 * Join a couple using invite code
 *
 * POST /api/couples/join
 * Body: { code: string }
 *
 * Returns: { coupleId: string, partnerId: string, partnerEmail: string }
 */
async function handleJoinPOST(req: NextRequest, userId: string, email?: string) {
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
      await client.query('ROLLBACK');
      client.release();
      return NextResponse.json(
        { error: 'This person is already paired with someone else' },
        { status: 400 }
      );
    }

    // Create couple
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
}

// ============================================================================
// PAIR-DIRECT HANDLER
// ============================================================================

/**
 * Pair directly with another user by their userId
 *
 * POST /api/couples/pair-direct
 * Body: { partnerId: string }
 *
 * Returns: { coupleId: string, partnerId: string, partnerEmail: string, partnerName: string }
 */
async function handlePairDirectPOST(req: NextRequest, userId: string, email?: string) {
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
}

// ============================================================================
// STATUS HANDLERS
// ============================================================================

/**
 * Get current couple status
 *
 * GET /api/couples/status
 *
 * Returns:
 * - If paired: { isPaired: true, coupleId, partnerId, partnerEmail, createdAt }
 * - If not paired: { isPaired: false }
 */
async function handleStatusGET(req: NextRequest, userId: string) {
  try {
    console.log(`[Couple Status] Checking status for user: ${userId}`);

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

    console.log(`[Couple Status] Query returned ${coupleResult.rows.length} rows for user ${userId}`);

    if (coupleResult.rows.length === 0) {
      console.log(`[Couple Status] User ${userId} is NOT paired`);
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

    // Get partner's push token
    const partnerTokenResult = await query(
      `SELECT fcm_token FROM user_push_tokens WHERE user_id = $1`,
      [couple.partner_id]
    );
    const partnerPushToken = partnerTokenResult.rows[0]?.fcm_token || null;

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
      // New format: complete partner object
      partner: {
        id: couple.partner_id,
        name: partnerName,
        email: partnerEmail,
        pushToken: partnerPushToken,
        avatarEmoji: '💕',
      },
    });
  } catch (error) {
    console.error('Error fetching couple status:', error);
    return NextResponse.json(
      { error: 'Failed to fetch couple status' },
      { status: 500 }
    );
  }
}

/**
 * Leave couple (unpair)
 *
 * DELETE /api/couples/status
 *
 * Returns: { success: true }
 */
async function handleStatusDELETE(req: NextRequest, userId: string) {
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
}

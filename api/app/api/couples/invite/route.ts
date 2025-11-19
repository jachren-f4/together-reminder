/**
 * Couple Invite Code Generation Endpoint
 *
 * Generates a 6-digit invite code for couple pairing
 * Code expires after 24 hours
 */

import { NextResponse } from 'next/server';
import { withAuth } from '@/lib/auth/middleware';
import { RateLimitPresets, withRateLimit } from '@/lib/auth/rate-limit';
import { query } from '@/lib/db/pool';
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
 * Generate a new invite code
 *
 * POST /api/couples/invite
 *
 * Returns: { code: string, expiresAt: string }
 */
export const POST = withRateLimit(
  RateLimitPresets.auth,
  withAuth(async (req, userId) => {
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
  })
);

/**
 * Get current active invite code
 *
 * GET /api/couples/invite
 *
 * Returns: { code: string, expiresAt: string } or { code: null }
 */
export const GET = withRateLimit(
  RateLimitPresets.auth,
  withAuth(async (req, userId) => {
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
  })
);

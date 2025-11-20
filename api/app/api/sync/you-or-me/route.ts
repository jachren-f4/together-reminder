/**
 * You or Me Sync Endpoint
 *
 * Dual-write implementation for You or Me sessions
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuth } from '@/lib/auth/middleware';
import { query, getClient } from '@/lib/db/pool';

export const dynamic = 'force-dynamic';

// Handle CORS preflight
export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    },
  });
}

/**
 * Sync You or Me session to Supabase (Dual-Write)
 *
 * POST /api/sync/you-or-me
 * Body: {
 *   id: string (UUID),
 *   questions: array of questions (JSONB),
 *   createdAt: string (ISO8601),
 *   expiresAt?: string (ISO8601),
 * }
 */
export const POST = withAuth(async (req, userId, email) => {
  try {
    const body = await req.json();
    const {
      id,
      questions,
      createdAt,
      expiresAt,
    } = body;

    // Validate required fields
    if (!id || !questions || !createdAt) {
      return NextResponse.json(
        { error: 'Missing required fields' },
        { status: 400 }
      );
    }

    // Get couple_id for the user
    const coupleResult = await query(
      `SELECT id FROM couples WHERE user1_id = $1 OR user2_id = $1 LIMIT 1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json(
        { error: 'No couple found for user' },
        { status: 404 }
      );
    }

    const coupleId = coupleResult.rows[0].id;

    // Insert You or Me session
    await query(
      `INSERT INTO you_or_me_sessions (id, couple_id, questions, created_at, expires_at)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (id) DO NOTHING`,
      [id, coupleId, JSON.stringify(questions), createdAt, expiresAt || null]
    );

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Error syncing You or Me session:', error);
    return NextResponse.json(
      { error: 'Failed to sync You or Me session' },
      { status: 500 }
    );
  }
});

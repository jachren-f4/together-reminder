/**
 * Reminders & Pokes Sync Endpoint
 *
 * Dual-write implementation for reminders and pokes
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
 * Sync reminder/poke to Supabase (Dual-Write)
 *
 * POST /api/sync/reminders
 * Body: {
 *   id: string (UUID),
 *   type: 'sent' | 'received',
 *   fromUserId: string (UUID),
 *   toUserId: string (UUID),
 *   fromName: string,
 *   toName: string,
 *   text: string,
 *   category: 'reminder' | 'poke',
 *   emoji?: string,
 *   scheduledFor: string (ISO8601),
 *   status: 'pending' | 'sent' | 'delivered' | 'failed',
 *   createdAt: string (ISO8601),
 *   sentAt?: string (ISO8601),
 * }
 */
export const POST = withAuth(async (req, userId, email) => {
  try {
    const body = await req.json();
    const {
      id,
      type,
      fromName,
      toName,
      text,
      category = 'reminder',
      emoji,
      scheduledFor,
      status = 'pending',
      createdAt,
      sentAt,
    } = body;

    // Validate required fields
    if (!id || !type || !fromName || !toName || !text || !scheduledFor || !createdAt) {
      return NextResponse.json(
        { error: 'Missing required fields' },
        { status: 400 }
      );
    }

    // Get couple and determine user IDs
    const coupleResult = await query(
      `SELECT id, user1_id, user2_id FROM couples WHERE user1_id = $1 OR user2_id = $1 LIMIT 1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json(
        { error: 'No couple found for user' },
        { status: 404 }
      );
    }

    const { id: coupleId, user1_id, user2_id } = coupleResult.rows[0];

    // Determine fromUserId and toUserId based on type
    let fromUserId: string;
    let toUserId: string;

    if (type === 'sent') {
      fromUserId = userId;
      toUserId = user1_id === userId ? user2_id : user1_id;
    } else {
      // type === 'received'
      toUserId = userId;
      fromUserId = user1_id === userId ? user2_id : user1_id;
    }

    // Insert reminder/poke
    await query(
      `INSERT INTO reminders (
        id, couple_id, type, from_user_id, to_user_id, from_name, to_name,
        text, category, emoji, scheduled_for, status, created_at, sent_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
      ON CONFLICT (id) DO UPDATE SET
        status = EXCLUDED.status,
        sent_at = EXCLUDED.sent_at`,
      [
        id, coupleId, type, fromUserId, toUserId, fromName, toName,
        text, category, emoji, scheduledFor, status, createdAt, sentAt || null
      ]
    );

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Error syncing reminder/poke:', error);
    return NextResponse.json(
      { error: 'Failed to sync reminder/poke' },
      { status: 500 }
    );
  }
});

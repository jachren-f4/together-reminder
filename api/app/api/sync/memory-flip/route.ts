/**
 * Memory Flip Sync Endpoint
 *
 * Dual-write implementation for Memory Flip puzzles
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
 * Sync Memory Flip puzzle to Supabase (Dual-Write)
 *
 * POST /api/sync/memory-flip
 * Body: {
 *   id: string (UUID),
 *   date: string (YYYY-MM-DD),
 *   totalPairs: number,
 *   matchedPairs: number,
 *   cards: array of cards (JSONB),
 *   status: 'active' | 'completed',
 *   completionQuote?: string,
 *   createdAt: string (ISO8601),
 *   completedAt?: string (ISO8601),
 * }
 */
export const POST = withAuth(async (req, userId, email) => {
  try {
    const body = await req.json();
    const {
      id,
      date,
      totalPairs,
      matchedPairs,
      cards,
      status = 'active',
      completionQuote,
      createdAt,
      completedAt,
    } = body;

    // Validate required fields
    if (!id || !date || !totalPairs || matchedPairs === undefined || !cards || !createdAt) {
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

    // Insert Memory Flip puzzle
    await query(
      `INSERT INTO memory_puzzles (
        id, couple_id, date, total_pairs, matched_pairs, cards,
        status, completion_quote, created_at, completed_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
      ON CONFLICT (id) DO UPDATE SET
        matched_pairs = EXCLUDED.matched_pairs,
        cards = EXCLUDED.cards,
        status = EXCLUDED.status,
        completion_quote = EXCLUDED.completion_quote,
        completed_at = EXCLUDED.completed_at`,
      [
        id, coupleId, date, totalPairs, matchedPairs, JSON.stringify(cards),
        status, completionQuote || null, createdAt, completedAt || null
      ]
    );

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Error syncing Memory Flip puzzle:', error);
    return NextResponse.json(
      { error: 'Failed to sync Memory Flip puzzle' },
      { status: 500 }
    );
  }
});

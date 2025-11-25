/**
 * Development endpoint to reset Memory Flip data
 * Only available in development mode with AUTH_DEV_BYPASS_ENABLED
 */

import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db/pool';

export const dynamic = 'force-dynamic';

// Handle CORS preflight
export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Dev-User-Id',
    },
  });
}

/**
 * Reset Memory Flip data for development testing
 *
 * POST /api/dev/reset-memory-flip
 */
export async function POST(req: NextRequest) {
  try {
    // Only allow in development mode
    if (process.env.NODE_ENV !== 'development' || process.env.AUTH_DEV_BYPASS_ENABLED !== 'true') {
      return NextResponse.json(
        { error: 'This endpoint is only available in development mode' },
        { status: 403 }
      );
    }

    // Get user ID from header or environment
    const userId = req.headers.get('X-Dev-User-Id') || process.env.AUTH_DEV_USER_ID;

    if (!userId) {
      return NextResponse.json(
        { error: 'User ID required for reset' },
        { status: 400 }
      );
    }

    // Find the couple ID for this user
    const coupleResult = await query(
      'SELECT id FROM couples WHERE user1_id = $1 OR user2_id = $1 LIMIT 1',
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json(
        { error: 'No couple found for user' },
        { status: 404 }
      );
    }

    const coupleId = coupleResult.rows[0].id;

    // Delete all memory moves for this couple's puzzles
    await query(
      `DELETE FROM memory_moves
       WHERE puzzle_id IN (
         SELECT id FROM memory_puzzles
         WHERE couple_id = $1
       )`,
      [coupleId]
    );

    // Delete all memory puzzles for this couple
    const deleteResult = await query(
      'DELETE FROM memory_puzzles WHERE couple_id = $1 RETURNING id',
      [coupleId]
    );

    return NextResponse.json({
      success: true,
      message: 'Memory Flip data reset successfully',
      deletedPuzzles: deleteResult.rows.length,
      coupleId,
    }, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Dev-User-Id',
      }
    });

  } catch (error) {
    console.error('Error resetting Memory Flip data:', error);
    return NextResponse.json(
      { error: 'Failed to reset Memory Flip data' },
      { status: 500 }
    );
  }
}
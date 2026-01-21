/**
 * Linked Game Reset API Endpoint (Debug Only)
 *
 * POST: Reset Linked progress for a couple
 * - Deletes active matches
 * - Resets puzzle index to 0
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query, getClient } from '@/lib/db/pool';
import { getCoupleId } from '@/lib/couple/utils';

export const dynamic = 'force-dynamic';

export const POST = withAuthOrDevBypass(async (req: NextRequest, userId: string) => {
  console.log(`[Linked Reset] Starting reset for user ${userId}...`);

  const client = await getClient();

  try {
    // Get couple ID for this user (pass client to avoid pool exhaustion)
    const coupleId = await getCoupleId(userId, client);
    if (!coupleId) {
      console.log(`[Linked Reset] User ${userId} not in a couple, aborting`);
      client.release();
      return NextResponse.json({ error: 'User not in a couple' }, { status: 400 });
    }

    console.log(`[Linked Reset] Found couple ${coupleId}, deleting all matches...`);

    await client.query('BEGIN');

    // Delete ALL linked matches for this couple (active and completed)
    // Progress is tracked by completed matches, so deleting them resets to puzzle 0
    const { rows: deletedMatches } = await client.query(
      `DELETE FROM linked_matches WHERE couple_id = $1 RETURNING id, status`,
      [coupleId]
    );

    const activeCount = deletedMatches.filter(m => m.status === 'active').length;
    const completedCount = deletedMatches.filter(m => m.status === 'completed').length;

    await client.query('COMMIT');

    console.log(`[Linked Reset] ✅ SUCCESS - Couple ${coupleId}: deleted ${activeCount} active + ${completedCount} completed matches (total: ${deletedMatches.length})`);

    return NextResponse.json({
      success: true,
      deletedMatches: deletedMatches.length,
      activeDeleted: activeCount,
      completedDeleted: completedCount,
      message: `Linked progress reset: deleted ${activeCount} active + ${completedCount} completed matches`,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('[Linked Reset] Error:', error);
    return NextResponse.json({ error: 'Failed to reset Linked progress' }, { status: 500 });
  } finally {
    client.release();
  }
});

/**
 * Test-only endpoint to reset couple progress
 *
 * POST /api/dev/reset-couple-progress
 *
 * Only available in development environment
 * Used by integration tests to reset state between test runs
 */

import { NextRequest, NextResponse } from 'next/server';
import { getClient } from '@/lib/db/pool';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  // Security: Only allow in development
  if (process.env.NODE_ENV !== 'development') {
    return NextResponse.json(
      { error: 'Endpoint not available in production' },
      { status: 403 }
    );
  }

  const client = await getClient();

  try {
    const body = await req.json();
    const { coupleId } = body;

    if (!coupleId) {
      return NextResponse.json(
        { error: 'coupleId required' },
        { status: 400 }
      );
    }

    console.log(`\n🧹 [TEST] Resetting progress for couple: ${coupleId}\n`);

    await client.query('BEGIN');

    const results: Record<string, number> = {};

    // 1. Linked matches & moves
    const linkedMoves = await client.query(
      `DELETE FROM linked_moves
       WHERE match_id IN (SELECT id FROM linked_matches WHERE couple_id = $1)
       RETURNING id`,
      [coupleId]
    );
    results.linkedMoves = linkedMoves.rowCount || 0;

    const linkedMatches = await client.query(
      'DELETE FROM linked_matches WHERE couple_id = $1 RETURNING id',
      [coupleId]
    );
    results.linkedMatches = linkedMatches.rowCount || 0;

    // 2. Word search matches & moves
    const wsMoves = await client.query(
      `DELETE FROM word_search_moves
       WHERE match_id IN (SELECT id FROM word_search_matches WHERE couple_id = $1)
       RETURNING id`,
      [coupleId]
    );
    results.wordSearchMoves = wsMoves.rowCount || 0;

    const wsMatches = await client.query(
      'DELETE FROM word_search_matches WHERE couple_id = $1 RETURNING id',
      [coupleId]
    );
    results.wordSearchMatches = wsMatches.rowCount || 0;

    // 3. Quiz matches
    const quizMatches = await client.query(
      'DELETE FROM quiz_matches WHERE couple_id = $1 RETURNING id',
      [coupleId]
    );
    results.quizMatches = quizMatches.rowCount || 0;

    // 4. You-or-Me progression
    const yomProg = await client.query(
      'DELETE FROM you_or_me_progression WHERE couple_id = $1 RETURNING couple_id',
      [coupleId]
    );
    results.youOrMeProgression = yomProg.rowCount || 0;

    // 5. Branch progression
    const branchProg = await client.query(
      'DELETE FROM branch_progression WHERE couple_id = $1 RETURNING id',
      [coupleId]
    );
    results.branchProgression = branchProg.rowCount || 0;

    // 6. Quiz progression
    const quizProg = await client.query(
      'DELETE FROM quiz_progression WHERE couple_id = $1 RETURNING couple_id',
      [coupleId]
    );
    results.quizProgression = quizProg.rowCount || 0;

    // 7. Daily quests & completions
    const completions = await client.query(
      `DELETE FROM quest_completions
       WHERE quest_id IN (SELECT id FROM daily_quests WHERE couple_id = $1)
       RETURNING quest_id`,
      [coupleId]
    );
    results.questCompletions = completions.rowCount || 0;

    const quests = await client.query(
      'DELETE FROM daily_quests WHERE couple_id = $1 RETURNING id',
      [coupleId]
    );
    results.dailyQuests = quests.rowCount || 0;

    // 8. Love point awards (deprecated table)
    const lpAwards = await client.query(
      'DELETE FROM love_point_awards WHERE couple_id = $1 RETURNING id',
      [coupleId]
    );
    results.lovePointAwards = lpAwards.rowCount || 0;

    // 9. Love point transactions (get user IDs first)
    const coupleUsers = await client.query(
      'SELECT user1_id, user2_id FROM couples WHERE id = $1',
      [coupleId]
    );

    if (coupleUsers.rows.length > 0) {
      const { user1_id, user2_id } = coupleUsers.rows[0];
      const lpTxns = await client.query(
        'DELETE FROM love_point_transactions WHERE user_id IN ($1, $2) RETURNING id',
        [user1_id, user2_id]
      );
      results.lovePointTransactions = lpTxns.rowCount || 0;
    }

    // 10. Reset couple's total_lp to 0
    await client.query(
      'UPDATE couples SET total_lp = 0 WHERE id = $1',
      [coupleId]
    );
    results.lpReset = 1;

    // 11. Leaderboard entry
    const leaderboard = await client.query(
      'DELETE FROM couple_leaderboard WHERE couple_id = $1 RETURNING couple_id',
      [coupleId]
    );
    results.leaderboard = leaderboard.rowCount || 0;

    await client.query('COMMIT');

    console.log('✅ [TEST] Reset complete:', results);

    return NextResponse.json({
      success: true,
      coupleId,
      deleted: results,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ [TEST] Reset failed:', error);
    return NextResponse.json(
      { error: 'Failed to reset couple progress' },
      { status: 500 }
    );
  } finally {
    client.release();
  }
}

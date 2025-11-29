/**
 * Quest Status API Endpoint
 *
 * Returns quest completion status for polling by clients.
 * Replaces Firebase RTDB real-time listeners with HTTP polling.
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';

export const dynamic = 'force-dynamic';

/**
 * GET /api/sync/quest-status
 *
 * Returns quest completion status for the couple's quests.
 * Used by clients to poll for partner's quest completions.
 *
 * Query params:
 * - date: Optional date in YYYY-MM-DD format (defaults to today)
 *
 * Response:
 * {
 *   quests: [
 *     {
 *       questId: "quiz:classic:2025-11-29",
 *       questType: "quiz",
 *       status: "completed" | "in_progress" | "pending",
 *       userCompleted: true,
 *       partnerCompleted: true,
 *       matchId: "uuid" (if applicable),
 *       lpAwarded: 30 (if completed)
 *     }
 *   ],
 *   totalLp: 1160
 * }
 */
export const GET = withAuthOrDevBypass(async (req, userId, email) => {
  try {
    const { searchParams } = new URL(req.url);
    const dateParam = searchParams.get('date');

    // Default to today's date
    const date = dateParam || new Date().toISOString().split('T')[0];

    // Get couple info
    const coupleResult = await query(
      `SELECT id, user1_id, user2_id, total_lp FROM couples WHERE user1_id = $1 OR user2_id = $1 LIMIT 1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json(
        { error: 'No couple found for user' },
        { status: 404 }
      );
    }

    const { id: coupleId, user1_id, user2_id, total_lp } = coupleResult.rows[0];
    const partnerId = userId === user1_id ? user2_id : user1_id;
    const isPlayer1 = userId === user1_id;

    // Get quiz matches for today (includes both classic/affirmation quizzes and you_or_me)
    // All game types use the quiz_matches table
    const quizMatchesResult = await query(
      `SELECT id, quiz_type, quiz_id, status,
              player1_answer_count, player2_answer_count,
              player1_score, player2_score,
              match_percentage, completed_at
       FROM quiz_matches
       WHERE couple_id = $1 AND DATE(created_at) = $2`,
      [coupleId, date]
    );

    // Build quest status list
    const quests: any[] = [];

    // Process quiz matches (includes classic, affirmation, and you_or_me)
    for (const match of quizMatchesResult.rows) {
      const userAnswered = isPlayer1
        ? (match.player1_answer_count || 0) > 0
        : (match.player2_answer_count || 0) > 0;
      const partnerAnswered = isPlayer1
        ? (match.player2_answer_count || 0) > 0
        : (match.player1_answer_count || 0) > 0;

      quests.push({
        questId: match.quiz_id,
        questType: match.quiz_type,
        status: match.status,
        userCompleted: userAnswered,
        partnerCompleted: partnerAnswered,
        matchId: match.id,
        matchPercentage: match.match_percentage,
        player1Score: match.player1_score,
        player2Score: match.player2_score,
        lpAwarded: match.status === 'completed' ? 30 : 0,
      });
    }

    return NextResponse.json({
      quests,
      totalLp: total_lp || 0,
      userId,
      partnerId,
      date,
    });
  } catch (error) {
    console.error('Error fetching quest status:', error);
    return NextResponse.json(
      { error: 'Failed to fetch quest status' },
      { status: 500 }
    );
  }
});

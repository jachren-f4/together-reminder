/**
 * Unified Game Status Endpoint
 *
 * Single polling endpoint for ALL game types.
 * Returns status of all games for the current day (or specified date).
 *
 * GET /api/sync/game/status?date=2025-11-29
 *
 * Response:
 * {
 *   games: [
 *     {
 *       type: "classic",
 *       matchId: "uuid",
 *       status: "active",
 *       userAnswered: true,
 *       partnerAnswered: false,
 *       ...
 *     }
 *   ],
 *   totalLp: 1160
 * }
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { getCouple, buildGameState, buildResult, loadQuiz, GameType, GameMatch } from '@/lib/game/handler';

export const dynamic = 'force-dynamic';

export const GET = withAuthOrDevBypass(async (req: NextRequest, userId: string, email?: string) => {
  try {
    const { searchParams } = new URL(req.url);
    const dateParam = searchParams.get('date');
    const typeFilter = searchParams.get('type'); // Optional: filter by game type

    // Default to today's date
    const date = dateParam || new Date().toISOString().split('T')[0];

    // Get couple info
    const couple = await getCouple(userId);
    if (!couple) {
      return NextResponse.json(
        { error: 'User is not part of a couple' },
        { status: 404 }
      );
    }

    // Build query based on optional type filter
    let matchQuery = `
      SELECT * FROM quiz_matches
      WHERE couple_id = $1 AND date = $2
    `;
    const params: any[] = [couple.coupleId, date];

    if (typeFilter) {
      matchQuery += ` AND quiz_type = $3`;
      params.push(typeFilter);
    }

    matchQuery += ` ORDER BY created_at DESC`;

    const matchesResult = await query(matchQuery, params);

    // Build game status for each match
    const games = matchesResult.rows.map((row: any) => {
      const match = parseMatch(row);
      const state = buildGameState(match, couple);
      const result = buildResult(match, couple);

      return {
        type: match.quizType,
        matchId: match.id,
        quizId: match.quizId,
        branch: match.branch,
        status: match.status,
        userAnswered: state.userAnswered,
        partnerAnswered: state.partnerAnswered,
        canSubmit: state.canSubmit,
        isMyTurn: state.isMyTurn,
        isCompleted: state.isCompleted,
        createdAt: match.createdAt,
        completedAt: match.completedAt,
        // Include result data if completed
        ...(result && {
          matchPercentage: result.matchPercentage,
          lpEarned: result.lpEarned,
        }),
      };
    });

    return NextResponse.json({
      success: true,
      games,
      totalLp: couple.totalLp,
      userId,
      partnerId: couple.partnerId,
      date,
    });
  } catch (error) {
    console.error('Error in game status endpoint:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
});

function parseMatch(row: any): GameMatch {
  return {
    id: row.id,
    quizId: row.quiz_id,
    quizType: row.quiz_type,
    branch: row.branch,
    status: row.status,
    player1Answers: typeof row.player1_answers === 'string'
      ? JSON.parse(row.player1_answers)
      : row.player1_answers || [],
    player2Answers: typeof row.player2_answers === 'string'
      ? JSON.parse(row.player2_answers)
      : row.player2_answers || [],
    player1AnswerCount: row.player1_answer_count || 0,
    player2AnswerCount: row.player2_answer_count || 0,
    matchPercentage: row.match_percentage,
    player1Score: row.player1_score || 0,
    player2Score: row.player2_score || 0,
    currentTurnUserId: row.current_turn_user_id,
    turnNumber: row.turn_number || 1,
    date: row.date,
    createdAt: row.created_at,
    completedAt: row.completed_at,
  };
}

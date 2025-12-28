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
 *   games: [...],           // Today's matches
 *   completedCounts: {      // Total completed per type (all time)
 *     classic: 5,
 *     affirmation: 3,
 *     you_or_me: 4,
 *     linked: 2,
 *     word_search: 1
 *   },
 *   available: [...]        // What's available to play next
 *   totalLp: 1160
 * }
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { getCouple, buildGameState, buildResult, getCurrentBranch, loadQuizOrder, loadQuiz, GameType, GameMatch } from '@/lib/game/handler';

export const dynamic = 'force-dynamic';

const GAME_TYPES: GameType[] = ['classic', 'affirmation', 'you_or_me'];

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

    // Build game status for each match (buildResult is async, so use Promise.all)
    const games = await Promise.all(matchesResult.rows.map(async (row: any) => {
      const match = parseMatch(row);
      const state = buildGameState(match, couple);
      const result = await buildResult(match, couple);

      // Load quiz metadata for display (title/description)
      const quiz = loadQuiz(match.quizType as GameType, match.branch, match.quizId);

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
        // Include quiz metadata for display
        quizName: quiz?.name || null,
        quizDescription: quiz?.description || null,
        // Include result data if completed
        ...(result && {
          matchPercentage: result.matchPercentage,
          lpEarned: result.lpEarned,
        }),
      };
    }));

    // Get total completed counts per game type (all time)
    const countsResult = await query(
      `SELECT quiz_type, COUNT(*) as count
       FROM quiz_matches
       WHERE couple_id = $1 AND status = 'completed'
       GROUP BY quiz_type`,
      [couple.coupleId]
    );

    const completedCounts: Record<string, number> = {};
    for (const row of countsResult.rows) {
      completedCounts[row.quiz_type] = parseInt(row.count, 10);
    }

    // Also get linked and word_search counts
    const linkedCount = await query(
      `SELECT COUNT(*) as count FROM linked_matches WHERE couple_id = $1 AND status = 'completed'`,
      [couple.coupleId]
    );
    const wordSearchCount = await query(
      `SELECT COUNT(*) as count FROM word_search_matches WHERE couple_id = $1 AND status = 'completed'`,
      [couple.coupleId]
    );
    completedCounts['linked'] = parseInt(linkedCount.rows[0]?.count || '0', 10);
    completedCounts['word_search'] = parseInt(wordSearchCount.rows[0]?.count || '0', 10);

    // Get what's available next for each game type
    const available: any[] = [];
    for (const gameType of GAME_TYPES) {
      const branch = await getCurrentBranch(couple.coupleId, gameType);
      const quizOrder = loadQuizOrder(gameType, branch);

      // Find completed quizzes in this branch
      const completedInBranch = await query(
        `SELECT DISTINCT quiz_id FROM quiz_matches
         WHERE couple_id = $1 AND quiz_type = $2 AND branch = $3 AND status = 'completed'`,
        [couple.coupleId, gameType, branch]
      );
      const completedSet = new Set(completedInBranch.rows.map(r => r.quiz_id));

      // Find next uncompleted quiz
      const nextQuizId = quizOrder.find(id => !completedSet.has(id)) || quizOrder[0];

      // Check if there's already an active match today
      const activeToday = games.find(g => g.type === gameType && g.status === 'active');

      available.push({
        type: gameType,
        branch,
        nextQuizId,
        completedInBranch: completedSet.size,
        totalInBranch: quizOrder.length,
        hasActiveMatch: !!activeToday,
        activeMatchId: activeToday?.matchId || null,
      });
    }

    return NextResponse.json({
      success: true,
      games,
      completedCounts,
      available,
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

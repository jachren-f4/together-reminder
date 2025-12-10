/**
 * Consolidated Game Route (Catch-All)
 *
 * Handles multiple game-related endpoints via Next.js catch-all routing:
 *
 * GET /api/sync/game/status → Game status polling
 * POST /api/sync/game/{type}/play → Unified game play (type = classic|affirmation|you_or_me)
 *
 * This route consolidates what were previously separate nested routes:
 * - /api/sync/game/status/route.ts
 * - /api/sync/game/[type]/play/route.ts
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { RouteContext } from '@/lib/auth/middleware';
import { query } from '@/lib/db/pool';
import {
  getCouple,
  buildGameState,
  buildResult,
  getCurrentBranch,
  loadQuizOrder,
  GameType,
  GameMatch,
  getOrCreateMatch,
  getMatchById,
  submitAnswers,
} from '@/lib/game/handler';

export const dynamic = 'force-dynamic';

const GAME_TYPES: GameType[] = ['classic', 'affirmation', 'you_or_me'];
const VALID_GAME_TYPES = ['classic', 'affirmation', 'you_or_me'] as const;

// ============================================================================
// GET Handler - Routes to different handlers based on slug
// ============================================================================

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ slug: string[] }> }
) {
  const { slug } = await params;
  const path = slug?.join('/') || '';

  if (path === 'status') {
    return handleGameStatusGET(req);
  }

  return NextResponse.json(
    { error: `Unknown GET path: /api/sync/game/${path}` },
    { status: 404 }
  );
}

// ============================================================================
// POST Handler - Routes to different handlers based on slug
// ============================================================================

export async function POST(
  req: NextRequest,
  context: { params: Promise<{ slug: string[] }> }
) {
  const { slug } = await context.params;

  // slug[0] = type (classic|affirmation|you_or_me), slug[1] = 'play'
  if (slug?.length === 2 && slug[1] === 'play') {
    const type = slug[0];
    // Pass the type via context so the auth wrapper can access it
    return handleGamePlay(req, { params: Promise.resolve({ slug, gameType: type }) });
  }

  const path = slug?.join('/') || '';
  return NextResponse.json(
    { error: `Unknown POST path: /api/sync/game/${path}` },
    { status: 404 }
  );
}

// ============================================================================
// Handler: Game Status (GET /api/sync/game/status)
// ============================================================================

const handleGameStatusGET = withAuthOrDevBypass(async (req: NextRequest, userId: string, email?: string) => {
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

// ============================================================================
// Handler: Game Play (POST /api/sync/game/{type}/play)
// ============================================================================

const handleGamePlay = withAuthOrDevBypass(async (
  req: NextRequest,
  userId: string,
  email?: string,
  context?: RouteContext
) => {
  try {
    // Extract game type from context params
    // The params contain { slug: string[], gameType: string } passed from POST handler
    const resolvedParams = context?.params
      ? (typeof context.params === 'object' && 'then' in context.params
          ? await context.params
          : context.params)
      : null;
    const gameType = (resolvedParams as any)?.gameType;

    // Validate game type
    if (!VALID_GAME_TYPES.includes(gameType as any)) {
      return NextResponse.json(
        { error: `Invalid game type: ${gameType}. Valid types: ${VALID_GAME_TYPES.join(', ')}` },
        { status: 400 }
      );
    }

    const body = await req.json();
    const { localDate, matchId, answers } = body;

    // Get couple info
    const couple = await getCouple(userId);
    if (!couple) {
      return NextResponse.json(
        { error: 'User is not part of a couple' },
        { status: 404 }
      );
    }

    // Determine what action to take based on request params
    const hasMatchId = !!matchId;
    const hasAnswers = answers && Array.isArray(answers) && answers.length > 0;
    const hasLocalDate = !!localDate;

    let match;
    let quiz;
    let isNew = false;

    // Case 1: matchId provided - fetch existing match
    if (hasMatchId) {
      match = await getMatchById(matchId);
      if (!match) {
        return NextResponse.json(
          { error: 'Match not found' },
          { status: 404 }
        );
      }
      // Verify match type matches request type
      if (match.quizType !== gameType) {
        return NextResponse.json(
          { error: `Match type mismatch. Match is ${match.quizType}, requested ${gameType}` },
          { status: 400 }
        );
      }
    }
    // Case 2: No matchId - create or get today's match
    else if (hasLocalDate) {
      const result = await getOrCreateMatch(couple, gameType as GameType, localDate);
      match = result.match;
      quiz = result.quiz;
      isNew = result.isNew;
    }
    // Case 3: Neither matchId nor localDate - error
    else {
      return NextResponse.json(
        { error: 'Either matchId or localDate is required' },
        { status: 400 }
      );
    }

    // If answers provided, submit them
    let result = null;
    if (hasAnswers) {
      try {
        const submitResult = await submitAnswers(match, couple, answers);
        match = submitResult.match;
        result = submitResult.result;
      } catch (error: any) {
        return NextResponse.json(
          { error: error.message || 'Failed to submit answers' },
          { status: 400 }
        );
      }
    }

    // Build game state
    const state = buildGameState(match, couple);

    // Build response
    const response: any = {
      success: true,
      match: {
        id: match.id,
        quizId: match.quizId,
        quizType: match.quizType,
        branch: match.branch,
        status: match.status,
        date: match.date,
        createdAt: match.createdAt,
      },
      state: {
        canSubmit: state.canSubmit,
        userAnswered: state.userAnswered,
        partnerAnswered: state.partnerAnswered,
        isCompleted: state.isCompleted,
        isMyTurn: state.isMyTurn,
      },
      isNew,
    };

    // Include quiz questions if this is a new match or user hasn't answered
    if (quiz && !state.userAnswered) {
      response.quiz = {
        id: quiz.id,
        name: quiz.name,
        questions: quiz.questions,
      };
    }

    // Include result if completed
    if (result) {
      response.result = {
        matchPercentage: result.matchPercentage,
        lpEarned: result.lpEarned,
        userAnswers: result.userAnswers,
        partnerAnswers: result.partnerAnswers,
      };
      response.bothAnswered = true;
      response.isCompleted = true;
    }

    // Include completion data if match is completed
    if (match.status === 'completed') {
      const completedResult = buildResult(match, couple);
      if (completedResult) {
        response.result = {
          matchPercentage: completedResult.matchPercentage,
          lpEarned: completedResult.lpEarned,
          userAnswers: completedResult.userAnswers,
          partnerAnswers: completedResult.partnerAnswers,
        };
      }
    }

    return NextResponse.json(response);
  } catch (error) {
    console.error('Error in game play endpoint:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
});

// ============================================================================
// Utility Functions
// ============================================================================

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

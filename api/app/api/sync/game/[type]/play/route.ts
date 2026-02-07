/**
 * Unified Game Play Endpoint
 *
 * Smart endpoint that handles both starting and submitting games.
 * Works for all game types: classic, affirmation, you_or_me
 *
 * POST /api/sync/game/{type}/play
 *
 * Request body variants:
 * 1. Start new game:     { localDate: "2025-11-29" }
 * 2. Submit answers:     { matchId: "uuid", answers: [0,1,2,1,0] }
 * 3. Start AND submit:   { localDate: "2025-11-29", answers: [0,1,2,1,0] }
 * 4. Get current state:  { matchId: "uuid" }
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { RouteContext } from '@/lib/auth/middleware';
import {
  GameType,
  CoupleInfo,
  getCouple,
  getOrCreateMatch,
  getMatchById,
  submitAnswers,
  buildGameState,
  buildResult,
  loadQuiz,
} from '@/lib/game/handler';
import { validateOnBehalfOf } from '@/lib/phantom/on-behalf-of';

export const dynamic = 'force-dynamic';

const VALID_GAME_TYPES = ['classic', 'affirmation', 'you_or_me'] as const;

export const POST = withAuthOrDevBypass(async (
  req: NextRequest,
  userId: string,
  email?: string,
  context?: RouteContext
) => {
  try {
    const params = context?.params;
    const resolvedParams = params instanceof Promise ? await params : params;
    const gameType = resolvedParams?.type;

    // Validate game type
    if (!VALID_GAME_TYPES.includes(gameType as any)) {
      return NextResponse.json(
        { error: `Invalid game type: ${gameType}. Valid types: ${VALID_GAME_TYPES.join(', ')}` },
        { status: 400 }
      );
    }

    const body = await req.json();
    const { localDate, matchId, answers, onBehalfOf } = body;

    // Get couple info
    const couple = await getCouple(userId);
    if (!couple) {
      return NextResponse.json(
        { error: 'User is not part of a couple' },
        { status: 404 }
      );
    }

    // Handle onBehalfOf for single-phone mode (phantom user)
    let effectiveCouple: CoupleInfo = couple;
    if (onBehalfOf) {
      const validation = await validateOnBehalfOf(userId, onBehalfOf);
      if (!validation.valid) {
        return NextResponse.json(
          { error: validation.error },
          { status: 403 }
        );
      }
      // Create a modified couple where isPlayer1 reflects the phantom user's position
      const phantomIsPlayer1 = onBehalfOf === couple.user1Id;
      effectiveCouple = {
        ...couple,
        isPlayer1: phantomIsPlayer1,
        partnerId: phantomIsPlayer1 ? couple.user2Id : couple.user1Id,
      };
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
      console.log(`🎯 PLAY ROUTE: Fetching match by ID: ${matchId}`);
      match = await getMatchById(matchId);
      if (!match) {
        console.log(`🎯 PLAY ROUTE: Match NOT found for ID: ${matchId}`);
        return NextResponse.json(
          { error: 'Match not found' },
          { status: 404 }
        );
      }
      console.log(`🎯 PLAY ROUTE: Match found - status=${match.status}, p1AnswerCount=${(match as any).player1AnswerCount}, p2AnswerCount=${(match as any).player2AnswerCount}`);
      // Verify match type matches request type
      if (match.quizType !== gameType) {
        return NextResponse.json(
          { error: `Match type mismatch. Match is ${match.quizType}, requested ${gameType}` },
          { status: 400 }
        );
      }
      // Load quiz data for the match (needed for results comparison)
      quiz = loadQuiz(gameType as GameType, match.branch, match.quizId);
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
        const submitResult = await submitAnswers(match, effectiveCouple, answers);
        match = submitResult.match;
        result = submitResult.result;
      } catch (error: any) {
        return NextResponse.json(
          { error: error.message || 'Failed to submit answers' },
          { status: 400 }
        );
      }
    }

    // Build game state (use original couple for the caller's perspective)
    console.log(`🎯 PLAY ROUTE: Building game state - userId=${userId}, couple.isPlayer1=${couple.isPlayer1}, couple.user1Id=${couple.user1Id}, couple.user2Id=${couple.user2Id}`);
    const state = buildGameState(match, couple);
    console.log(`🎯 PLAY ROUTE: Game state built - userAnswered=${state.userAnswered}, partnerAnswered=${state.partnerAnswered}, isCompleted=${state.isCompleted}`);

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

    // Include quiz questions if:
    // - User hasn't answered yet (needs to play)
    // - OR match is completed (needed for results comparison)
    if (quiz && (!state.userAnswered || match.status === 'completed')) {
      response.quiz = {
        id: quiz.id,
        name: quiz.name,
        description: quiz.description,
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
      const completedResult = await buildResult(match, couple, { checkLpStatus: true });
      if (completedResult) {
        response.result = {
          matchPercentage: completedResult.matchPercentage,
          lpEarned: completedResult.lpEarned,
          userAnswers: completedResult.userAnswers,
          partnerAnswers: completedResult.partnerAnswers,
          // Include LP status for completed matches
          alreadyGrantedToday: completedResult.alreadyGrantedToday,
          resetInMs: completedResult.resetInMs,
          canPlayMore: completedResult.canPlayMore,
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

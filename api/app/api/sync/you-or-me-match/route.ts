/**
 * You-or-Me Match API Endpoint
 *
 * Server-side match creation and retrieval for You-or-Me game.
 * This is a turn-based game where players answer "you" or "me" to each question.
 *
 * POST: Create or return existing active match for today
 * GET: Get current match state (for polling)
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { readFileSync } from 'fs';
import { join } from 'path';

export const dynamic = 'force-dynamic';

// Branch names
const BRANCH_NAMES = ['playful', 'reflective', 'intimate'];

// Load quiz data from server JSON files
function loadQuiz(branch: string, quizId: string): any {
  try {
    const quizPath = join(process.cwd(), 'data', 'puzzles', 'you-or-me', branch, `${quizId}.json`);
    const quizData = readFileSync(quizPath, 'utf-8');
    return JSON.parse(quizData);
  } catch (error) {
    console.error(`Failed to load you-or-me quiz ${quizId} from ${branch}:`, error);
    return null;
  }
}

// Load quiz order for a branch
function loadQuizOrder(branch: string): string[] {
  try {
    const orderPath = join(process.cwd(), 'data', 'puzzles', 'you-or-me', branch, 'quiz-order.json');
    const orderData = readFileSync(orderPath, 'utf-8');
    const config = JSON.parse(orderData);
    return config.quizzes || [];
  } catch (error) {
    console.error(`Failed to load quiz order for you-or-me/${branch}:`, error);
    return [];
  }
}

// Get current branch for couple based on branch_progression
async function getCurrentBranch(coupleId: string): Promise<string> {
  const result = await query(
    `SELECT current_branch FROM branch_progression
     WHERE couple_id = $1 AND activity_type = 'you_or_me'`,
    [coupleId]
  );

  if (result.rows.length === 0) {
    // No progression record, default to first branch
    return BRANCH_NAMES[0];
  }

  const branchIndex = result.rows[0].current_branch;
  return BRANCH_NAMES[branchIndex % BRANCH_NAMES.length];
}

// Get next quiz for couple
async function getNextQuizForCouple(
  coupleId: string,
  localDate: string
): Promise<{ quizId: string | null; activeMatch: any | null; branch: string }> {
  const branch = await getCurrentBranch(coupleId);
  const quizOrder = loadQuizOrder(branch);

  // Check for existing match for today (active or completed)
  const existingResult = await query(
    `SELECT * FROM quiz_matches
     WHERE couple_id = $1 AND quiz_type = 'you_or_me' AND date = $2
     ORDER BY created_at DESC LIMIT 1`,
    [coupleId, localDate]
  );

  if (existingResult.rows.length > 0) {
    const match = existingResult.rows[0];
    return { quizId: match.quiz_id, activeMatch: match, branch };
  }

  // Get all completed quizzes for this couple in this branch
  const completedResult = await query(
    `SELECT DISTINCT quiz_id FROM quiz_matches
     WHERE couple_id = $1 AND quiz_type = 'you_or_me' AND branch = $2 AND status = 'completed'`,
    [coupleId, branch]
  );

  const completedQuizzes = new Set(completedResult.rows.map(r => r.quiz_id));

  // Find first uncompleted quiz
  for (const quizId of quizOrder) {
    if (!completedQuizzes.has(quizId)) {
      return { quizId, activeMatch: null, branch };
    }
  }

  // All quizzes in this branch completed - cycle to first
  return { quizId: quizOrder[0] || null, activeMatch: null, branch };
}

/**
 * POST /api/sync/you-or-me-match
 *
 * Creates a new match if none exists for today, or returns existing match.
 *
 * Request body:
 * {
 *   localDate: "2025-11-28"
 * }
 */
export const POST = withAuthOrDevBypass(async (req, userId, email) => {
  try {
    const body = await req.json();
    const { localDate } = body;

    if (!localDate) {
      return NextResponse.json(
        { error: 'Missing required field: localDate' },
        { status: 400 }
      );
    }

    // Get couple info with first_player_id
    const coupleResult = await query(
      `SELECT id, user1_id, user2_id, first_player_id FROM couples WHERE user1_id = $1 OR user2_id = $1 LIMIT 1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json(
        { error: 'No couple found for user' },
        { status: 404 }
      );
    }

    const { id: coupleId, user1_id, user2_id, first_player_id } = coupleResult.rows[0];

    // Get next quiz for this couple
    const { quizId, activeMatch, branch } = await getNextQuizForCouple(coupleId, localDate);

    if (!quizId) {
      return NextResponse.json(
        { error: 'No quizzes available', code: 'NO_QUIZZES' },
        { status: 404 }
      );
    }

    // Load quiz from server JSON
    const quiz = loadQuiz(branch, quizId);

    if (!quiz) {
      return NextResponse.json(
        { error: 'Quiz not found' },
        { status: 404 }
      );
    }

    let match;
    let isNewMatch = false;

    if (activeMatch) {
      // Return existing match
      match = activeMatch;
    } else {
      // Create new match
      isNewMatch = true;

      // Determine first player (use couple preference or default to user2)
      const firstPlayer = first_player_id || user2_id;

      const insertResult = await query(
        `INSERT INTO quiz_matches (
          couple_id, quiz_id, quiz_type, branch, status,
          player1_answers, player2_answers,
          player1_answer_count, player2_answer_count,
          current_turn_user_id, turn_number,
          player1_id, player2_id, date, created_at
        )
        VALUES ($1, $2, 'you_or_me', $3, 'active', '[]', '[]', 0, 0, $4, 1, $5, $6, $7, NOW())
        RETURNING *`,
        [coupleId, quizId, branch, firstPlayer, user1_id, user2_id, localDate]
      );

      match = insertResult.rows[0];
    }

    // Calculate game state
    const isPlayer1 = userId === user1_id;
    const isMyTurn = match.current_turn_user_id === userId;
    const player1Answers = typeof match.player1_answers === 'string'
      ? JSON.parse(match.player1_answers)
      : match.player1_answers || [];
    const player2Answers = typeof match.player2_answers === 'string'
      ? JSON.parse(match.player2_answers)
      : match.player2_answers || [];

    return NextResponse.json({
      success: true,
      isNewMatch,
      match: {
        id: match.id,
        quizId: match.quiz_id,
        quizType: 'you_or_me',
        branch: match.branch,
        status: match.status,
        player1Answers,
        player2Answers,
        player1AnswerCount: match.player1_answer_count,
        player2AnswerCount: match.player2_answer_count,
        currentTurnUserId: match.current_turn_user_id,
        turnNumber: match.turn_number,
        player1Score: match.player1_score || 0,
        player2Score: match.player2_score || 0,
        player1Id: match.player1_id,
        player2Id: match.player2_id,
        date: match.date,
        createdAt: match.created_at,
        completedAt: match.completed_at,
      },
      quiz: {
        quizId: quiz.quizId,
        title: quiz.title,
        branch: quiz.branch,
        questions: quiz.questions,
        totalQuestions: quiz.questions.length,
      },
      gameState: {
        isMyTurn,
        canPlay: isMyTurn && match.status === 'active',
        currentQuestion: Math.floor(match.turn_number / 2),
        myAnswerCount: isPlayer1 ? match.player1_answer_count : match.player2_answer_count,
        partnerAnswerCount: isPlayer1 ? match.player2_answer_count : match.player1_answer_count,
        myScore: isPlayer1 ? (match.player1_score || 0) : (match.player2_score || 0),
        partnerScore: isPlayer1 ? (match.player2_score || 0) : (match.player1_score || 0),
        isCompleted: match.status === 'completed',
      }
    });
  } catch (error) {
    console.error('Error in You-or-Me Match API:', error);
    return NextResponse.json(
      { error: 'Failed to get/create match' },
      { status: 500 }
    );
  }
});

/**
 * GET /api/sync/you-or-me-match
 *
 * Get current match state for polling.
 *
 * Query params:
 * - matchId: UUID of the match to poll
 */
export const GET = withAuthOrDevBypass(async (req, userId, email) => {
  try {
    const { searchParams } = new URL(req.url);
    const matchId = searchParams.get('matchId');

    if (!matchId) {
      return NextResponse.json(
        { error: 'Missing matchId parameter' },
        { status: 400 }
      );
    }

    // Get couple info
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

    const { user1_id } = coupleResult.rows[0];

    // Get match
    const result = await query(
      `SELECT * FROM quiz_matches WHERE id = $1`,
      [matchId]
    );

    if (result.rows.length === 0) {
      return NextResponse.json(
        { error: 'Match not found', code: 'NO_MATCH' },
        { status: 404 }
      );
    }

    const match = result.rows[0];
    const isPlayer1 = userId === user1_id;
    const isMyTurn = match.current_turn_user_id === userId;
    const player1Answers = typeof match.player1_answers === 'string'
      ? JSON.parse(match.player1_answers)
      : match.player1_answers || [];
    const player2Answers = typeof match.player2_answers === 'string'
      ? JSON.parse(match.player2_answers)
      : match.player2_answers || [];

    // Load quiz for response
    const quiz = loadQuiz(match.branch, match.quiz_id);

    return NextResponse.json({
      success: true,
      match: {
        id: match.id,
        quizId: match.quiz_id,
        quizType: 'you_or_me',
        branch: match.branch,
        status: match.status,
        player1Answers,
        player2Answers,
        player1AnswerCount: match.player1_answer_count,
        player2AnswerCount: match.player2_answer_count,
        currentTurnUserId: match.current_turn_user_id,
        turnNumber: match.turn_number,
        player1Score: match.player1_score || 0,
        player2Score: match.player2_score || 0,
        player1Id: match.player1_id,
        player2Id: match.player2_id,
        date: match.date,
        createdAt: match.created_at,
        completedAt: match.completed_at,
      },
      quiz: quiz ? {
        quizId: quiz.quizId,
        title: quiz.title,
        branch: quiz.branch,
        questions: quiz.questions,
        totalQuestions: quiz.questions.length,
      } : null,
      gameState: {
        isMyTurn,
        canPlay: isMyTurn && match.status === 'active',
        currentQuestion: Math.floor(match.turn_number / 2),
        myAnswerCount: isPlayer1 ? match.player1_answer_count : match.player2_answer_count,
        partnerAnswerCount: isPlayer1 ? match.player2_answer_count : match.player1_answer_count,
        myScore: isPlayer1 ? (match.player1_score || 0) : (match.player2_score || 0),
        partnerScore: isPlayer1 ? (match.player2_score || 0) : (match.player1_score || 0),
        isCompleted: match.status === 'completed',
      }
    });
  } catch (error) {
    console.error('Error getting You-or-Me match:', error);
    return NextResponse.json(
      { error: 'Failed to get match' },
      { status: 500 }
    );
  }
});

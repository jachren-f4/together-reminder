/**
 * Quiz Match API Endpoint
 *
 * Server-side match creation and retrieval for Classic and Affirmation quizzes.
 * Mirrors the Linked game pattern:
 * - POST: Create or return existing active match for today
 * - GET: Get current match state (for polling)
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { readFileSync } from 'fs';
import { join } from 'path';

export const dynamic = 'force-dynamic';

// Quiz types supported by this endpoint
type QuizType = 'classic' | 'affirmation';

// Branch names for each quiz type
const BRANCH_NAMES: Record<QuizType, string[]> = {
  classic: ['lighthearted', 'deep', 'spicy'],
  affirmation: ['practical', 'emotional', 'spiritual'],
};

// Load quiz data from server JSON files
function loadQuiz(quizType: QuizType, branch: string, quizId: string): any {
  try {
    const folder = quizType === 'classic' ? 'classic-quiz' : quizType;
    const quizPath = join(process.cwd(), 'data', 'puzzles', folder, branch, `${quizId}.json`);
    const quizData = readFileSync(quizPath, 'utf-8');
    return JSON.parse(quizData);
  } catch (error) {
    console.error(`Failed to load quiz ${quizId} from ${branch}:`, error);
    return null;
  }
}

// Load quiz order for a branch
function loadQuizOrder(quizType: QuizType, branch: string): string[] {
  try {
    const folder = quizType === 'classic' ? 'classic-quiz' : quizType;
    const orderPath = join(process.cwd(), 'data', 'puzzles', folder, branch, 'quiz-order.json');
    const orderData = readFileSync(orderPath, 'utf-8');
    const config = JSON.parse(orderData);
    return config.quizzes || [];
  } catch (error) {
    console.error(`Failed to load quiz order for ${quizType}/${branch}:`, error);
    return [];
  }
}

// Get current branch for couple based on branch_progression
async function getCurrentBranch(coupleId: string, quizType: QuizType): Promise<string> {
  const activityType = quizType === 'classic' ? 'classic_quiz' : 'affirmation_quiz';

  const result = await query(
    `SELECT current_branch FROM branch_progression
     WHERE couple_id = $1 AND activity_type = $2`,
    [coupleId, activityType]
  );

  if (result.rows.length === 0) {
    // No progression record, default to first branch
    return BRANCH_NAMES[quizType][0];
  }

  const branchIndex = result.rows[0].current_branch;
  return BRANCH_NAMES[quizType][branchIndex % BRANCH_NAMES[quizType].length];
}

// Get next quiz for couple (finds first uncompleted quiz for current branch)
async function getNextQuizForCouple(
  coupleId: string,
  quizType: QuizType,
  localDate: string
): Promise<{ quizId: string | null; activeMatch: any | null; branch: string }> {
  const branch = await getCurrentBranch(coupleId, quizType);
  const quizOrder = loadQuizOrder(quizType, branch);

  // Check for existing match for today (active or completed)
  const existingResult = await query(
    `SELECT * FROM quiz_matches
     WHERE couple_id = $1 AND quiz_type = $2 AND date = $3
     ORDER BY created_at DESC LIMIT 1`,
    [coupleId, quizType, localDate]
  );

  if (existingResult.rows.length > 0) {
    const match = existingResult.rows[0];
    return { quizId: match.quiz_id, activeMatch: match, branch };
  }

  // Get all completed quizzes for this couple in this branch
  const completedResult = await query(
    `SELECT DISTINCT quiz_id FROM quiz_matches
     WHERE couple_id = $1 AND quiz_type = $2 AND branch = $3 AND status = 'completed'`,
    [coupleId, quizType, branch]
  );

  const completedQuizzes = new Set(completedResult.rows.map(r => r.quiz_id));

  // Find first uncompleted quiz
  for (const quizId of quizOrder) {
    if (!completedQuizzes.has(quizId)) {
      return { quizId, activeMatch: null, branch };
    }
  }

  // All quizzes in this branch completed - use first one (cycle)
  return { quizId: quizOrder[0] || null, activeMatch: null, branch };
}

/**
 * POST /api/sync/quiz-match
 *
 * Creates a new match if none exists for today, or returns existing match.
 *
 * Request body:
 * {
 *   localDate: "2025-11-28",
 *   quizType: "classic" | "affirmation"
 * }
 */
export const POST = withAuthOrDevBypass(async (req, userId, email) => {
  try {
    const body = await req.json();
    const { localDate, quizType } = body;

    if (!localDate || !quizType) {
      return NextResponse.json(
        { error: 'Missing required fields: localDate, quizType' },
        { status: 400 }
      );
    }

    if (!['classic', 'affirmation'].includes(quizType)) {
      return NextResponse.json(
        { error: 'Invalid quizType. Must be "classic" or "affirmation"' },
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

    const { id: coupleId, user1_id, user2_id } = coupleResult.rows[0];

    // Get next quiz for this couple
    const { quizId, activeMatch, branch } = await getNextQuizForCouple(coupleId, quizType, localDate);

    if (!quizId) {
      return NextResponse.json(
        { error: 'No quizzes available', code: 'NO_QUIZZES' },
        { status: 404 }
      );
    }

    // Load quiz from server JSON
    const quiz = loadQuiz(quizType, branch, quizId);

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

      const insertResult = await query(
        `INSERT INTO quiz_matches (
          couple_id, quiz_id, quiz_type, branch, status,
          player1_answers, player2_answers,
          player1_answer_count, player2_answer_count,
          player1_id, player2_id, date, created_at
        )
        VALUES ($1, $2, $3, $4, 'active', '[]', '[]', 0, 0, $5, $6, $7, NOW())
        RETURNING *`,
        [coupleId, quizId, quizType, branch, user1_id, user2_id, localDate]
      );

      match = insertResult.rows[0];
    }

    // Calculate game state
    const isPlayer1 = userId === user1_id;
    const player1Answers = typeof match.player1_answers === 'string'
      ? JSON.parse(match.player1_answers)
      : match.player1_answers || [];
    const player2Answers = typeof match.player2_answers === 'string'
      ? JSON.parse(match.player2_answers)
      : match.player2_answers || [];

    const hasUserAnswered = isPlayer1
      ? player1Answers.length > 0
      : player2Answers.length > 0;
    const hasPartnerAnswered = isPlayer1
      ? player2Answers.length > 0
      : player1Answers.length > 0;

    return NextResponse.json({
      success: true,
      isNewMatch,
      match: {
        id: match.id,
        quizId: match.quiz_id,
        quizType: match.quiz_type,
        branch: match.branch,
        status: match.status,
        player1Answers,
        player2Answers,
        matchPercentage: match.match_percentage,
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
        description: quiz.description,
        questions: quiz.questions,
      },
      gameState: {
        hasUserAnswered,
        hasPartnerAnswered,
        isCompleted: match.status === 'completed',
        canAnswer: !hasUserAnswered && match.status === 'active',
      }
    });
  } catch (error) {
    console.error('Error in Quiz Match API:', error);
    return NextResponse.json(
      { error: 'Failed to get/create match' },
      { status: 500 }
    );
  }
});

/**
 * GET /api/sync/quiz-match
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
    const player1Answers = typeof match.player1_answers === 'string'
      ? JSON.parse(match.player1_answers)
      : match.player1_answers || [];
    const player2Answers = typeof match.player2_answers === 'string'
      ? JSON.parse(match.player2_answers)
      : match.player2_answers || [];

    const hasUserAnswered = isPlayer1
      ? player1Answers.length > 0
      : player2Answers.length > 0;
    const hasPartnerAnswered = isPlayer1
      ? player2Answers.length > 0
      : player1Answers.length > 0;

    // Load quiz for response
    const quiz = loadQuiz(match.quiz_type, match.branch, match.quiz_id);

    return NextResponse.json({
      success: true,
      match: {
        id: match.id,
        quizId: match.quiz_id,
        quizType: match.quiz_type,
        branch: match.branch,
        status: match.status,
        player1Answers,
        player2Answers,
        matchPercentage: match.match_percentage,
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
        description: quiz.description,
        questions: quiz.questions,
      } : null,
      gameState: {
        hasUserAnswered,
        hasPartnerAnswered,
        isCompleted: match.status === 'completed',
        canAnswer: !hasUserAnswered && match.status === 'active',
      }
    });
  } catch (error) {
    console.error('Error getting quiz match:', error);
    return NextResponse.json(
      { error: 'Failed to get match' },
      { status: 500 }
    );
  }
});

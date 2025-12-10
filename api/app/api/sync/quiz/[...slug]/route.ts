/**
 * Consolidated Quiz API Routes
 *
 * Handles all /api/sync/quiz/* routes:
 * - GET/POST /api/sync/quiz - Session creation and retrieval
 * - POST /api/sync/quiz/submit - Answer submission
 * - GET /api/sync/quiz/{sessionId} - Specific session polling
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { RouteContext } from '@/lib/auth/middleware';
import { query, getClient } from '@/lib/db/pool';
import { getCoupleBasic } from '@/lib/couple/utils';
import { LP_REWARDS, LP_BONUSES } from '@/lib/lp/config';

export const dynamic = 'force-dynamic';

/**
 * GET handler for quiz routes
 */
export async function GET(
  req: NextRequest,
  context: { params: Promise<{ slug: string[] }> }
) {
  const { slug = [] } = await context.params;
  const path = slug.join('/');

  // Route to appropriate handler
  if (path === '' || slug.length === 0) {
    // GET /api/sync/quiz - get session
    return handleQuizGET(req);
  }

  // Check if slug[0] is a UUID (sessionId)
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (slug.length === 1 && uuidRegex.test(slug[0])) {
    // GET /api/sync/quiz/{sessionId} - pass sessionId via context
    return handleQuizSessionGET(req, { params: Promise.resolve({ slug, sessionId: slug[0] }) });
  }

  return NextResponse.json({ error: 'Unknown path' }, { status: 404 });
}

/**
 * POST handler for quiz routes
 */
export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ slug: string[] }> }
) {
  const { slug = [] } = await params;
  const path = slug.join('/');

  // Route to appropriate handler
  if (path === '' || slug.length === 0) {
    // POST /api/sync/quiz - create session
    return handleQuizPOST(req);
  }

  if (path === 'submit') {
    // POST /api/sync/quiz/submit
    return handleQuizSubmitPOST(req);
  }

  return NextResponse.json({ error: 'Unknown path' }, { status: 404 });
}

/**
 * GET /api/sync/quiz
 *
 * Get quiz session for today (or specified date/formatType)
 *
 * Query params:
 *   date?: string (YYYY-MM-DD) - defaults to today
 *   formatType?: string - filter by format type
 *   sessionId?: string - get specific session by ID
 */
const handleQuizGET = withAuthOrDevBypass(async (req, userId, email) => {
  try {
    const { searchParams } = new URL(req.url);
    const date = searchParams.get('date');
    const formatType = searchParams.get('formatType');
    const sessionId = searchParams.get('sessionId');

    // Get couple info
    const couple = await getCoupleBasic(userId);
    if (!couple) {
      return NextResponse.json(
        { error: 'No couple found for user' },
        { status: 404 }
      );
    }

    const { coupleId, user1Id: user1_id } = couple;

    let result;

    if (sessionId) {
      // Get specific session by ID
      result = await query(
        `SELECT * FROM quiz_sessions WHERE id = $1 AND couple_id = $2`,
        [sessionId, coupleId]
      );
    } else if (date && formatType) {
      // Get session by date and format
      result = await query(
        `SELECT * FROM quiz_sessions
         WHERE couple_id = $1 AND date = $2 AND format_type = $3
         LIMIT 1`,
        [coupleId, date, formatType]
      );
    } else if (date) {
      // Get all sessions for date
      result = await query(
        `SELECT * FROM quiz_sessions
         WHERE couple_id = $1 AND date = $2
         ORDER BY created_at DESC`,
        [coupleId, date]
      );
    } else {
      // Get most recent active session
      result = await query(
        `SELECT * FROM quiz_sessions
         WHERE couple_id = $1 AND status = 'waiting_for_answers'
         ORDER BY created_at DESC
         LIMIT 1`,
        [coupleId]
      );
    }

    if (result.rows.length === 0) {
      return NextResponse.json(
        { error: 'No session found', code: 'NO_SESSION' },
        { status: 404 }
      );
    }

    // Return single or multiple sessions
    if (sessionId || formatType || !date) {
      return NextResponse.json({
        success: true,
        session: formatSessionForClient(result.rows[0], userId, user1_id),
      });
    } else {
      return NextResponse.json({
        success: true,
        sessions: result.rows.map((s: any) => formatSessionForClient(s, userId, user1_id)),
      });
    }
  } catch (error) {
    console.error('Error in Quiz API GET:', error);
    return NextResponse.json(
      { error: 'Failed to get quiz session' },
      { status: 500 }
    );
  }
});

/**
 * POST /api/sync/quiz
 *
 * Create a new quiz session or return existing one for today.
 *
 * Body: {
 *   date: string (YYYY-MM-DD) - local date for the quiz
 *   formatType: 'classic' | 'affirmation'
 *   questions: Array<{ id, text, choices, correctIndex?, ... }> - questions for the quiz
 *   subjectUserId?: string - who the quiz is about (defaults to creator)
 *   quizName?: string - display name (for affirmation quizzes)
 *   category?: string - category (for affirmation quizzes)
 *   dailyQuestId?: string - link to daily quest
 * }
 */
const handleQuizPOST = withAuthOrDevBypass(async (req, userId, email) => {
  try {
    const body = await req.json();
    const {
      date,
      formatType,
      questions,
      subjectUserId,
      quizName,
      category,
      dailyQuestId,
    } = body;

    // Validate required fields
    if (!date || !formatType || !questions || !Array.isArray(questions)) {
      return NextResponse.json(
        { error: 'Missing required fields: date, formatType, questions' },
        { status: 400 }
      );
    }

    // Validate formatType
    if (!['classic', 'affirmation', 'speed_round', 'would_you_rather'].includes(formatType)) {
      return NextResponse.json(
        { error: 'Invalid formatType. Must be: classic, affirmation, speed_round, or would_you_rather' },
        { status: 400 }
      );
    }

    // Get couple info
    const couple = await getCoupleBasic(userId);
    if (!couple) {
      return NextResponse.json(
        { error: 'No couple found for user' },
        { status: 404 }
      );
    }

    const { coupleId, user1Id: user1_id, user2Id: user2_id, partnerId } = couple;

    // Check for existing session for this couple/format/date
    const existingResult = await query(
      `SELECT * FROM quiz_sessions
       WHERE couple_id = $1 AND format_type = $2 AND date = $3
       LIMIT 1`,
      [coupleId, formatType, date]
    );

    if (existingResult.rows.length > 0) {
      // Return existing session
      const session = existingResult.rows[0];
      return NextResponse.json({
        success: true,
        isNew: false,
        session: formatSessionForClient(session, userId, user1_id),
      });
    }

    // Create new session
    const effectiveSubjectUserId = subjectUserId || userId;
    const expiresAt = new Date(date);
    expiresAt.setHours(23, 59, 59, 999);

    const insertResult = await query(
      `INSERT INTO quiz_sessions (
        couple_id, created_by, format_type, questions, quiz_name, category,
        is_daily_quest, subject_user_id, initiated_by, daily_quest_id,
        date, status, created_at, expires_at, answers, predictions
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'waiting_for_answers', NOW(), $12, '{}', '{}')
      RETURNING *`,
      [
        coupleId,
        userId,
        formatType,
        JSON.stringify(questions),
        quizName || null,
        category || null,
        !!dailyQuestId,
        effectiveSubjectUserId,
        userId,
        dailyQuestId || null,
        date,
        expiresAt,
      ]
    );

    const session = insertResult.rows[0];

    return NextResponse.json({
      success: true,
      isNew: true,
      session: formatSessionForClient(session, userId, user1_id),
    });
  } catch (error) {
    console.error('Error in Quiz API POST:', error);
    return NextResponse.json(
      { error: 'Failed to create/get quiz session' },
      { status: 500 }
    );
  }
});

/**
 * POST /api/sync/quiz/submit
 *
 * Submit answers for a quiz session
 *
 * Body: {
 *   sessionId: string - the quiz session ID
 *   answers: number[] - array of answer indices
 *   predictions?: number[] - for Would You Rather format
 * }
 */
const handleQuizSubmitPOST = withAuthOrDevBypass(async (req, userId, email) => {
  const client = await getClient();

  try {
    const body = await req.json();
    const { sessionId, answers, predictions } = body;

    // Validate required fields
    if (!sessionId || !answers || !Array.isArray(answers)) {
      return NextResponse.json(
        { error: 'Missing required fields: sessionId, answers' },
        { status: 400 }
      );
    }

    await client.query('BEGIN');

    // Get couple info
    const coupleResult = await client.query(
      `SELECT id, user1_id, user2_id FROM couples WHERE user1_id = $1 OR user2_id = $1 LIMIT 1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return NextResponse.json(
        { error: 'No couple found for user' },
        { status: 404 }
      );
    }

    const { id: coupleId, user1_id, user2_id } = coupleResult.rows[0];
    const partnerId = userId === user1_id ? user2_id : user1_id;

    // Lock session for update
    const sessionResult = await client.query(
      `SELECT * FROM quiz_sessions WHERE id = $1 AND couple_id = $2 FOR UPDATE`,
      [sessionId, coupleId]
    );

    if (sessionResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return NextResponse.json(
        { error: 'Session not found' },
        { status: 404 }
      );
    }

    const session = sessionResult.rows[0];

    // Check if session is already completed
    if (session.status === 'completed') {
      await client.query('ROLLBACK');
      return NextResponse.json(
        { error: 'Quiz already completed', code: 'ALREADY_COMPLETED' },
        { status: 400 }
      );
    }

    // Check if user has already answered
    const existingAnswers = typeof session.answers === 'string'
      ? JSON.parse(session.answers)
      : session.answers || {};

    if (existingAnswers[userId]) {
      await client.query('ROLLBACK');
      return NextResponse.json(
        { error: 'You have already answered this quiz', code: 'ALREADY_ANSWERED' },
        { status: 400 }
      );
    }

    // Update answers
    existingAnswers[userId] = answers;

    // Handle predictions for Would You Rather
    let existingPredictions = typeof session.predictions === 'string'
      ? JSON.parse(session.predictions)
      : session.predictions || {};

    if (predictions && Array.isArray(predictions)) {
      existingPredictions[userId] = predictions;
    }

    // Check if both users have answered
    const bothAnswered = Object.keys(existingAnswers).length >= 2;
    let matchPercentage = null;
    let lpEarned = null;
    let alignmentMatches = 0;
    let predictionScores: Record<string, number> = {};
    let completedAt = null;

    if (bothAnswered) {
      // Calculate results based on format type
      if (session.format_type === 'affirmation') {
        // Affirmation quizzes don't have match percentage
        // Each user answers for themselves
        lpEarned = LP_REWARDS.QUIZ_AFFIRMATION;
        completedAt = new Date();
      } else if (session.format_type === 'would_you_rather') {
        // Calculate Would You Rather results
        const result = calculateWouldYouRatherResults(
          existingAnswers,
          existingPredictions,
          user1_id,
          user2_id
        );
        matchPercentage = result.overallAccuracy;
        alignmentMatches = result.alignmentMatches;
        predictionScores = result.predictionScores;
        lpEarned = result.lpEarned;
        completedAt = new Date();
      } else {
        // Classic quiz: Calculate match percentage
        matchPercentage = calculateClassicMatchPercentage(
          existingAnswers,
          session.subject_user_id,
          user1_id,
          user2_id
        );
        lpEarned = LP_REWARDS.QUIZ_CLASSIC;
        completedAt = new Date();
      }

      // Award LP using couples.total_lp (single source of truth)
      if (lpEarned && lpEarned > 0) {
        // Update couples.total_lp directly (avoids connection pool issues by using same client)
        await client.query(
          `UPDATE couples SET total_lp = COALESCE(total_lp, 0) + $1 WHERE id = $2`,
          [lpEarned, coupleId]
        );

        // Record LP transaction for audit trail
        await client.query(
          `INSERT INTO love_point_transactions (user_id, amount, source, description, created_at)
           VALUES ($1, $2, $3, $4, NOW()), ($5, $2, $3, $4, NOW())`,
          [user1_id, lpEarned, `quiz_${session.format_type}`, `quiz_complete (${sessionId})`, user2_id]
        );
      }

      // Advance branch progression for quiz activity
      const activityType = session.format_type === 'affirmation' ? 'affirmation' : 'classicQuiz';
      await client.query(
        `INSERT INTO branch_progression (couple_id, activity_type, current_branch, total_completions, max_branches)
         VALUES ($1, $2, 0, 1, 5)
         ON CONFLICT (couple_id, activity_type)
         DO UPDATE SET
           total_completions = branch_progression.total_completions + 1,
           current_branch = (branch_progression.total_completions + 1) % 5,
           last_completed_at = NOW(),
           updated_at = NOW()`,
        [coupleId, activityType]
      );
    }

    // Update session
    await client.query(
      `UPDATE quiz_sessions SET
        answers = $1,
        predictions = $2,
        status = $3,
        match_percentage = $4,
        lp_earned = $5,
        alignment_matches = $6,
        prediction_scores = $7,
        completed_at = $8
      WHERE id = $9`,
      [
        JSON.stringify(existingAnswers),
        JSON.stringify(existingPredictions),
        bothAnswered ? 'completed' : 'waiting_for_answers',
        matchPercentage,
        lpEarned,
        alignmentMatches,
        JSON.stringify(predictionScores),
        completedAt,
        sessionId,
      ]
    );

    await client.query('COMMIT');

    return NextResponse.json({
      success: true,
      bothAnswered,
      isCompleted: bothAnswered,
      matchPercentage,
      lpEarned,
      alignmentMatches,
      predictionScores,
      answers: existingAnswers,
      predictions: existingPredictions,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error submitting quiz answers:', error);
    return NextResponse.json(
      { error: 'Failed to submit answers' },
      { status: 500 }
    );
  } finally {
    client.release();
  }
});

/**
 * GET /api/sync/quiz/[sessionId]
 *
 * Poll specific quiz session state
 */
const handleQuizSessionGET = withAuthOrDevBypass(async (req, userId, email, context?: RouteContext) => {
  try {
    // Extract sessionId from context params
    const resolvedParams = context?.params
      ? (typeof context.params === 'object' && 'then' in context.params
          ? await context.params
          : context.params)
      : null;
    const sessionId = (resolvedParams as any)?.sessionId as string | undefined;

    if (!sessionId) {
      return NextResponse.json(
        { error: 'Session ID required' },
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
    const partnerId = userId === user1_id ? user2_id : user1_id;

    // Get session
    const sessionResult = await query(
      `SELECT * FROM quiz_sessions WHERE id = $1 AND couple_id = $2`,
      [sessionId, coupleId]
    );

    if (sessionResult.rows.length === 0) {
      return NextResponse.json(
        { error: 'Session not found', code: 'NO_SESSION' },
        { status: 404 }
      );
    }

    const session = sessionResult.rows[0];

    // Parse JSON fields
    const answers = typeof session.answers === 'string'
      ? JSON.parse(session.answers)
      : session.answers || {};

    const predictions = typeof session.predictions === 'string'
      ? JSON.parse(session.predictions)
      : session.predictions || {};

    const questions = typeof session.questions === 'string'
      ? JSON.parse(session.questions)
      : session.questions || [];

    const predictionScores = typeof session.prediction_scores === 'string'
      ? JSON.parse(session.prediction_scores)
      : session.prediction_scores || {};

    // Compute state for this user
    const hasUserAnswered = !!answers[userId];
    const hasPartnerAnswered = !!answers[partnerId];
    const isCompleted = session.status === 'completed';

    return NextResponse.json({
      success: true,
      session: {
        id: session.id,
        coupleId: session.couple_id,
        formatType: session.format_type,
        status: session.status,
        questions,
        answers,
        predictions,
        subjectUserId: session.subject_user_id,
        initiatedBy: session.initiated_by,
        quizName: session.quiz_name,
        category: session.category,
        isDailyQuest: session.is_daily_quest,
        dailyQuestId: session.daily_quest_id,
        date: session.date,
        matchPercentage: session.match_percentage,
        lpEarned: session.lp_earned,
        alignmentMatches: session.alignment_matches,
        predictionScores,
        createdAt: session.created_at,
        expiresAt: session.expires_at,
        completedAt: session.completed_at,
      },
      state: {
        hasUserAnswered,
        hasPartnerAnswered,
        isCompleted,
        isWaitingForPartner: hasUserAnswered && !hasPartnerAnswered && !isCompleted,
        canAnswer: !hasUserAnswered && !isCompleted,
      },
    });
  } catch (error) {
    console.error('Error polling quiz session:', error);
    return NextResponse.json(
      { error: 'Failed to get session' },
      { status: 500 }
    );
  }
});

/**
 * Format session for client response
 */
function formatSessionForClient(session: any, userId: string, user1Id: string): any {
  const answers = typeof session.answers === 'string'
    ? JSON.parse(session.answers)
    : session.answers || {};

  const predictions = typeof session.predictions === 'string'
    ? JSON.parse(session.predictions)
    : session.predictions || {};

  const questions = typeof session.questions === 'string'
    ? JSON.parse(session.questions)
    : session.questions || [];

  const isPlayer1 = userId === user1Id;
  const hasUserAnswered = !!answers[userId];
  const partnerId = isPlayer1 ? session.couple_id : user1Id; // This needs couple info

  return {
    id: session.id,
    coupleId: session.couple_id,
    formatType: session.format_type,
    status: session.status,
    questions,
    answers,
    predictions,
    subjectUserId: session.subject_user_id,
    initiatedBy: session.initiated_by,
    quizName: session.quiz_name,
    category: session.category,
    isDailyQuest: session.is_daily_quest,
    dailyQuestId: session.daily_quest_id,
    date: session.date,
    matchPercentage: session.match_percentage,
    lpEarned: session.lp_earned,
    alignmentMatches: session.alignment_matches,
    predictionScores: session.prediction_scores,
    createdAt: session.created_at,
    expiresAt: session.expires_at,
    completedAt: session.completed_at,
    // Computed fields
    hasUserAnswered,
    isCompleted: session.status === 'completed',
  };
}

/**
 * Calculate match percentage for classic quiz
 * Compares predictor's guesses against subject's actual answers
 */
function calculateClassicMatchPercentage(
  answers: Record<string, number[]>,
  subjectUserId: string,
  user1Id: string,
  user2Id: string
): number {
  const subjectAnswers = answers[subjectUserId];
  const predictorId = subjectUserId === user1Id ? user2Id : user1Id;
  const predictorAnswers = answers[predictorId];

  if (!subjectAnswers || !predictorAnswers) {
    return 0;
  }

  let matches = 0;
  const totalQuestions = Math.min(subjectAnswers.length, predictorAnswers.length);

  for (let i = 0; i < totalQuestions; i++) {
    if (subjectAnswers[i] === predictorAnswers[i]) {
      matches++;
    }
  }

  return totalQuestions > 0 ? Math.round((matches / totalQuestions) * 100) : 0;
}

/**
 * Calculate Would You Rather results
 * - Alignment: Both chose same answer
 * - Prediction accuracy: How well each predicted partner's answer
 */
function calculateWouldYouRatherResults(
  answers: Record<string, number[]>,
  predictions: Record<string, number[]>,
  user1Id: string,
  user2Id: string
): {
  overallAccuracy: number;
  alignmentMatches: number;
  predictionScores: Record<string, number>;
  lpEarned: number;
} {
  const user1Answers = answers[user1Id] || [];
  const user2Answers = answers[user2Id] || [];
  const user1Predictions = predictions[user1Id] || [];
  const user2Predictions = predictions[user2Id] || [];

  let alignmentMatches = 0;
  let user1Correct = 0;
  let user2Correct = 0;
  const totalQuestions = Math.min(user1Answers.length, user2Answers.length);

  for (let i = 0; i < totalQuestions; i++) {
    // Check alignment (both chose same)
    if (user1Answers[i] === user2Answers[i]) {
      alignmentMatches++;
    }

    // Check user1's prediction of user2's answer
    if (user1Predictions[i] === user2Answers[i]) {
      user1Correct++;
    }

    // Check user2's prediction of user1's answer
    if (user2Predictions[i] === user1Answers[i]) {
      user2Correct++;
    }
  }

  const totalPredictions = totalQuestions * 2;
  const totalCorrect = user1Correct + user2Correct;
  const overallAccuracy = totalPredictions > 0
    ? Math.round((totalCorrect / totalPredictions) * 100)
    : 0;

  // LP based on combined accuracy and alignment
  const baseLP = LP_REWARDS.QUIZ_WOULD_YOU_RATHER;
  const alignmentBonus = alignmentMatches * LP_BONUSES.WYR_ALIGNMENT_PER_MATCH;
  const lpEarned = baseLP + alignmentBonus;

  return {
    overallAccuracy,
    alignmentMatches,
    predictionScores: {
      [user1Id]: user1Correct,
      [user2Id]: user2Correct,
    },
    lpEarned,
  };
}

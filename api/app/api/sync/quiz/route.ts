/**
 * Quiz API Endpoint
 *
 * Server-side session creation and retrieval for Classic and Affirmation quizzes
 * POST: Create or return existing session for today
 * GET: Get current session state
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { getCoupleBasic } from '@/lib/couple/utils';

export const dynamic = 'force-dynamic';

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
export const POST = withAuthOrDevBypass(async (req, userId, email) => {
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
 * GET /api/sync/quiz
 *
 * Get quiz session for today (or specified date/formatType)
 *
 * Query params:
 *   date?: string (YYYY-MM-DD) - defaults to today
 *   formatType?: string - filter by format type
 *   sessionId?: string - get specific session by ID
 */
export const GET = withAuthOrDevBypass(async (req, userId, email) => {
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

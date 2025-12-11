/**
 * You or Me API Endpoint
 *
 * Server-side session creation and retrieval for You or Me game
 * POST: Create or return existing session for today
 * GET: Get current session state
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';

export const dynamic = 'force-dynamic';

/**
 * POST /api/sync/you-or-me
 *
 * Create a new You or Me session or return existing one for today.
 *
 * Body: {
 *   date: string (YYYY-MM-DD) - local date for the session
 *   questions: Array<{ id, prompt, content, category }> - 10 questions
 *   questId?: string - link to daily quest
 *   branch?: string - content branch
 * }
 */
export const POST = withAuthOrDevBypass(async (req, userId, email) => {
  try {
    const body = await req.json();
    const {
      date,
      questions,
      questId,
      branch,
    } = body;

    // Validate required fields
    if (!date || !questions || !Array.isArray(questions)) {
      return NextResponse.json(
        { error: 'Missing required fields: date, questions' },
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

    // Check for existing session for this couple/date
    const existingResult = await query(
      `SELECT * FROM you_or_me_sessions
       WHERE couple_id = $1 AND date = $2
       LIMIT 1`,
      [coupleId, date]
    );

    if (existingResult.rows.length > 0) {
      // Return existing session
      const session = existingResult.rows[0];
      return NextResponse.json({
        success: true,
        isNew: false,
        session: formatSessionForClient(session, userId, partnerId),
      });
    }

    // Create new session
    const expiresAt = new Date(date);
    expiresAt.setHours(23, 59, 59, 999);

    const insertResult = await query(
      `INSERT INTO you_or_me_sessions (
        couple_id, user_id, partner_id, quest_id, questions,
        date, branch, status, initiated_by, subject_user_id,
        created_at, expires_at, answers
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, 'in_progress', $8, $9, NOW(), $10, '{}')
      RETURNING *`,
      [
        coupleId,
        userId,
        partnerId,
        questId || null,
        JSON.stringify(questions),
        date,
        branch || null,
        userId,
        userId,
        expiresAt,
      ]
    );

    const session = insertResult.rows[0];

    return NextResponse.json({
      success: true,
      isNew: true,
      session: formatSessionForClient(session, userId, partnerId),
    });
  } catch (error) {
    console.error('Error in You or Me API POST:', error);
    return NextResponse.json(
      { error: 'Failed to create/get You or Me session' },
      { status: 500 }
    );
  }
});

/**
 * GET /api/sync/you-or-me
 *
 * Get You or Me session for today (or specified date)
 *
 * Query params:
 *   date?: string (YYYY-MM-DD) - defaults to today
 *   sessionId?: string - get specific session by ID
 */
export const GET = withAuthOrDevBypass(async (req, userId, email) => {
  try {
    const { searchParams } = new URL(req.url);
    const date = searchParams.get('date');
    const sessionId = searchParams.get('sessionId');

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

    let result;

    if (sessionId) {
      // Get specific session by ID
      result = await query(
        `SELECT * FROM you_or_me_sessions WHERE id = $1 AND couple_id = $2`,
        [sessionId, coupleId]
      );
    } else if (date) {
      // Get session by date
      result = await query(
        `SELECT * FROM you_or_me_sessions
         WHERE couple_id = $1 AND date = $2
         LIMIT 1`,
        [coupleId, date]
      );
    } else {
      // Get most recent active session
      result = await query(
        `SELECT * FROM you_or_me_sessions
         WHERE couple_id = $1 AND status = 'in_progress'
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

    return NextResponse.json({
      success: true,
      session: formatSessionForClient(result.rows[0], userId, partnerId),
    });
  } catch (error) {
    console.error('Error in You or Me API GET:', error);
    return NextResponse.json(
      { error: 'Failed to get You or Me session' },
      { status: 500 }
    );
  }
});

/**
 * Format session for client response
 */
function formatSessionForClient(session: any, userId: string, partnerId: string): any {
  const answers = typeof session.answers === 'string'
    ? JSON.parse(session.answers)
    : session.answers || {};

  const questions = typeof session.questions === 'string'
    ? JSON.parse(session.questions)
    : session.questions || [];

  const userAnswers = answers[userId] || [];
  const partnerAnswers = answers[partnerId] || [];

  return {
    id: session.id,
    coupleId: session.couple_id,
    userId: session.user_id,
    partnerId: session.partner_id,
    questId: session.quest_id,
    questions,
    answers,
    status: session.status,
    date: session.date,
    branch: session.branch,
    initiatedBy: session.initiated_by,
    subjectUserId: session.subject_user_id,
    lpEarned: session.lp_earned,
    createdAt: session.created_at,
    expiresAt: session.expires_at,
    completedAt: session.completed_at,
    // Computed fields
    userAnswerCount: userAnswers.length,
    partnerAnswerCount: partnerAnswers.length,
    totalQuestions: questions.length,
    hasUserCompleted: userAnswers.length >= questions.length,
    hasPartnerCompleted: partnerAnswers.length >= questions.length,
    isCompleted: session.status === 'completed',
  };
}

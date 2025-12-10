/**
 * Consolidated You or Me API Routes
 *
 * Handles all /api/sync/you-or-me/* routes:
 * - GET/POST /api/sync/you-or-me - Session creation and retrieval
 * - POST /api/sync/you-or-me/submit - Answer submission
 * - GET /api/sync/you-or-me/{sessionId} - Specific session polling
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { RouteContext } from '@/lib/auth/middleware';
import { query, getClient } from '@/lib/db/pool';
import { LP_REWARDS } from '@/lib/lp/config';

export const dynamic = 'force-dynamic';

// ============================================================================
// GET Handler - Route dispatcher
// ============================================================================

export async function GET(
  req: NextRequest,
  context: { params: Promise<{ slug?: string[] }> }
) {
  const { slug = [] } = await context.params;
  const path = slug.join('/');

  // GET /api/sync/you-or-me - get session
  if (path === '' || slug.length === 0) {
    return handleYouOrMeGET(req);
  }

  // Check if slug[0] is a UUID (sessionId)
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (slug.length === 1 && uuidRegex.test(slug[0])) {
    // GET /api/sync/you-or-me/{sessionId} - pass sessionId via context
    return handleYouOrMeSessionGET(req, { params: Promise.resolve({ slug, sessionId: slug[0] }) });
  }

  return NextResponse.json({ error: 'Unknown path' }, { status: 404 });
}

// ============================================================================
// POST Handler - Route dispatcher
// ============================================================================

export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ slug?: string[] }> }
) {
  const { slug = [] } = await params;
  const path = slug.join('/');

  // POST /api/sync/you-or-me - create session
  if (path === '' || slug.length === 0) {
    return handleYouOrMePOST(req);
  }

  // POST /api/sync/you-or-me/submit
  if (path === 'submit') {
    return handleYouOrMeSubmitPOST(req);
  }

  return NextResponse.json({ error: 'Unknown path' }, { status: 404 });
}

// ============================================================================
// GET /api/sync/you-or-me - Get session
// ============================================================================

/**
 * GET /api/sync/you-or-me
 *
 * Get You or Me session for today (or specified date)
 *
 * Query params:
 *   date?: string (YYYY-MM-DD) - defaults to today
 *   sessionId?: string - get specific session by ID
 */
const handleYouOrMeGET = withAuthOrDevBypass(async (req, userId, email) => {
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

// ============================================================================
// POST /api/sync/you-or-me - Create session
// ============================================================================

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
const handleYouOrMePOST = withAuthOrDevBypass(async (req, userId, email) => {
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

// ============================================================================
// POST /api/sync/you-or-me/submit - Submit answers
// ============================================================================

/**
 * POST /api/sync/you-or-me/submit
 *
 * Submit answer(s) for a You or Me session
 * Supports incremental submission (one answer at a time)
 *
 * Body: {
 *   sessionId: string - the session ID
 *   answer: { questionId, questionPrompt, questionContent, answerValue, answeredAt }
 *   OR
 *   answers: Array<{ questionId, questionPrompt, questionContent, answerValue, answeredAt }>
 * }
 */
const handleYouOrMeSubmitPOST = withAuthOrDevBypass(async (req, userId, email) => {
  const client = await getClient();

  try {
    const body = await req.json();
    const { sessionId, answer, answers: bulkAnswers } = body;

    // Support both single answer and bulk answers
    const answersToSubmit = bulkAnswers || (answer ? [answer] : []);

    // Validate required fields
    if (!sessionId || answersToSubmit.length === 0) {
      return NextResponse.json(
        { error: 'Missing required fields: sessionId, answer or answers' },
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
      `SELECT * FROM you_or_me_sessions WHERE id = $1 AND couple_id = $2 FOR UPDATE`,
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
        { error: 'Session already completed', code: 'ALREADY_COMPLETED' },
        { status: 400 }
      );
    }

    // Get existing answers
    const existingAnswers = typeof session.answers === 'string'
      ? JSON.parse(session.answers)
      : session.answers || {};

    const questions = typeof session.questions === 'string'
      ? JSON.parse(session.questions)
      : session.questions || [];

    const totalQuestions = questions.length;

    // Initialize user's answers array if not exists
    if (!existingAnswers[userId]) {
      existingAnswers[userId] = [];
    }

    // Add new answers (avoiding duplicates by questionId)
    const existingQuestionIds = new Set(
      existingAnswers[userId].map((a: any) => a.questionId)
    );

    for (const ans of answersToSubmit) {
      if (!existingQuestionIds.has(ans.questionId)) {
        existingAnswers[userId].push({
          questionId: ans.questionId,
          questionPrompt: ans.questionPrompt,
          questionContent: ans.questionContent,
          answerValue: ans.answerValue,
          answeredAt: ans.answeredAt || new Date().toISOString(),
        });
        existingQuestionIds.add(ans.questionId);
      }
    }

    // Check completion status
    const userAnswerCount = existingAnswers[userId]?.length || 0;
    const partnerAnswerCount = existingAnswers[partnerId]?.length || 0;
    const userComplete = userAnswerCount >= totalQuestions;
    const partnerComplete = partnerAnswerCount >= totalQuestions;
    const bothComplete = userComplete && partnerComplete;

    let lpEarned = null;
    let completedAt = null;

    if (bothComplete) {
      lpEarned = LP_REWARDS.YOU_OR_ME;
      completedAt = new Date();

      // Award LP using couples.total_lp (single source of truth)
      await client.query(
        `UPDATE couples SET total_lp = COALESCE(total_lp, 0) + $1 WHERE id = $2`,
        [lpEarned, coupleId]
      );

      // Record LP transaction for audit trail
      await client.query(
        `INSERT INTO love_point_transactions (user_id, amount, source, description, created_at)
         VALUES ($1, $2, 'you_or_me_complete', $3, NOW()), ($4, $2, 'you_or_me_complete', $3, NOW())`,
        [user1_id, lpEarned, `you_or_me_complete (${sessionId})`, user2_id]
      );

      // Advance branch progression for You or Me
      await client.query(
        `INSERT INTO branch_progression (couple_id, activity_type, current_branch, total_completions, max_branches)
         VALUES ($1, 'youOrMe', 0, 1, 5)
         ON CONFLICT (couple_id, activity_type)
         DO UPDATE SET
           total_completions = branch_progression.total_completions + 1,
           current_branch = (branch_progression.total_completions + 1) % 5,
           last_completed_at = NOW(),
           updated_at = NOW()`,
        [coupleId]
      );
    }

    // Update session
    await client.query(
      `UPDATE you_or_me_sessions SET
        answers = $1,
        status = $2,
        lp_earned = $3,
        completed_at = $4
      WHERE id = $5`,
      [
        JSON.stringify(existingAnswers),
        bothComplete ? 'completed' : 'in_progress',
        lpEarned,
        completedAt,
        sessionId,
      ]
    );

    await client.query('COMMIT');

    return NextResponse.json({
      success: true,
      userAnswerCount,
      partnerAnswerCount,
      totalQuestions,
      userComplete,
      partnerComplete,
      isCompleted: bothComplete,
      lpEarned,
      answers: existingAnswers,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error submitting You or Me answers:', error);
    return NextResponse.json(
      { error: 'Failed to submit answers' },
      { status: 500 }
    );
  } finally {
    client.release();
  }
});

// ============================================================================
// GET /api/sync/you-or-me/{sessionId} - Poll session
// ============================================================================

/**
 * GET /api/sync/you-or-me/[sessionId]
 *
 * Poll specific You or Me session state
 */
const handleYouOrMeSessionGET = withAuthOrDevBypass(
  async (req: NextRequest, userId: string, email?: string, context?: RouteContext) => {
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
        `SELECT * FROM you_or_me_sessions WHERE id = $1 AND couple_id = $2`,
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

      const questions = typeof session.questions === 'string'
        ? JSON.parse(session.questions)
        : session.questions || [];

      const totalQuestions = questions.length;
      const userAnswers = answers[userId] || [];
      const partnerAnswers = answers[partnerId] || [];
      const userAnswerCount = userAnswers.length;
      const partnerAnswerCount = partnerAnswers.length;

      // Compute state
      const userComplete = userAnswerCount >= totalQuestions;
      const partnerComplete = partnerAnswerCount >= totalQuestions;
      const isCompleted = session.status === 'completed';

      return NextResponse.json({
        success: true,
        session: {
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
        },
        state: {
          userAnswerCount,
          partnerAnswerCount,
          totalQuestions,
          userComplete,
          partnerComplete,
          isCompleted,
          isWaitingForPartner: userComplete && !partnerComplete && !isCompleted,
          canAnswer: !userComplete && !isCompleted,
          progress: {
            user: totalQuestions > 0 ? Math.round((userAnswerCount / totalQuestions) * 100) : 0,
            partner: totalQuestions > 0 ? Math.round((partnerAnswerCount / totalQuestions) * 100) : 0,
          },
        },
      });
    } catch (error) {
      console.error('Error polling You or Me session:', error);
      return NextResponse.json(
        { error: 'Failed to get session' },
        { status: 500 }
      );
    }
  }
);

// ============================================================================
// Shared Utilities
// ============================================================================

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

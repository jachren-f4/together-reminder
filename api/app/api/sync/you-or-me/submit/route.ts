/**
 * You or Me Answer Submission API
 *
 * POST /api/sync/you-or-me/submit - Submit answer(s) for a You or Me session
 * Supports partial submissions (one question at a time)
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query, getClient } from '@/lib/db/pool';
import { LP_REWARDS } from '@/lib/lp/config';
import { recordActivityPlay, getCooldownStatus } from '@/lib/magnets';
import { validateOnBehalfOf } from '@/lib/phantom/on-behalf-of';

export const dynamic = 'force-dynamic';

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
 *   onBehalfOf?: string - phantom user ID for single-phone mode
 * }
 */
export const POST = withAuthOrDevBypass(async (req, userId, email) => {
  const client = await getClient();

  try {
    const body = await req.json();
    const { sessionId, answer, answers: bulkAnswers, onBehalfOf } = body;

    // Support both single answer and bulk answers
    const answersToSubmit = bulkAnswers || (answer ? [answer] : []);

    // Validate required fields
    if (!sessionId || answersToSubmit.length === 0) {
      return NextResponse.json(
        { error: 'Missing required fields: sessionId, answer or answers' },
        { status: 400 }
      );
    }

    // Resolve effective user ID (supports single-phone mode via onBehalfOf)
    const onBehalfOfResult = await validateOnBehalfOf(userId, onBehalfOf);
    if (!onBehalfOfResult.valid) {
      return NextResponse.json(
        { error: onBehalfOfResult.error },
        { status: 403 }
      );
    }
    const effectiveUserId = onBehalfOfResult.effectiveUserId;

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

    // Get existing answers for cooldown and duplicate check
    const existingAnswersRaw = typeof session.answers === 'string'
      ? JSON.parse(session.answers)
      : session.answers || {};

    // Server-side cooldown check (safety net for client bypass)
    // Only check if user hasn't submitted any answers yet (allows completing in-progress games)
    if (!existingAnswersRaw[effectiveUserId] || existingAnswersRaw[effectiveUserId].length === 0) {
      const cooldownStatus = await getCooldownStatus(coupleId, 'you_or_me');

      if (!cooldownStatus.canPlay) {
        await client.query('ROLLBACK');
        return NextResponse.json(
          {
            error: 'Activity is on cooldown',
            code: 'ON_COOLDOWN',
            cooldownEndsAt: cooldownStatus.cooldownEndsAt?.toISOString(),
            cooldownRemainingMs: cooldownStatus.cooldownRemainingMs,
          },
          { status: 429 }
        );
      }
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
    if (!existingAnswers[effectiveUserId]) {
      existingAnswers[effectiveUserId] = [];
    }

    // Add new answers (avoiding duplicates by questionId)
    const existingQuestionIds = new Set(
      existingAnswers[effectiveUserId].map((a: any) => a.questionId)
    );

    for (const ans of answersToSubmit) {
      if (!existingQuestionIds.has(ans.questionId)) {
        existingAnswers[effectiveUserId].push({
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
    const userAnswerCount = existingAnswers[effectiveUserId]?.length || 0;
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

      // Record activity play for cooldown tracking (Magnet Collection System)
      // Pass client to avoid connection pool deadlock
      await recordActivityPlay(coupleId, 'you_or_me', client);
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

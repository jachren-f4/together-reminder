/**
 * You or Me Answer Submission API
 *
 * POST /api/sync/you-or-me/submit - Submit answer(s) for a You or Me session
 * Supports partial submissions (one question at a time)
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query, getClient } from '@/lib/db/pool';

export const dynamic = 'force-dynamic';

// LP reward for completing You or Me
const LP_REWARD = 30;

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
export const POST = withAuthOrDevBypass(async (req, userId, email) => {
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
      lpEarned = LP_REWARD;
      completedAt = new Date();

      // Award LP to both users (use session ID as related_id to prevent duplicates)
      await client.query(
        `INSERT INTO love_point_awards (id, couple_id, amount, reason, related_id, created_at)
         VALUES (gen_random_uuid(), $1, $2, 'you_or_me', $3, NOW())
         ON CONFLICT (couple_id, related_id) DO NOTHING`,
        [coupleId, lpEarned, sessionId]
      );

      // Update user LP totals
      await client.query(
        `UPDATE user_love_points SET total_points = total_points + $1, updated_at = NOW()
         WHERE user_id = $2`,
        [lpEarned, user1_id]
      );
      await client.query(
        `UPDATE user_love_points SET total_points = total_points + $1, updated_at = NOW()
         WHERE user_id = $2`,
        [lpEarned, user2_id]
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

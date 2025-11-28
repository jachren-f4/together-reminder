/**
 * You or Me Session Poll API
 *
 * GET /api/sync/you-or-me/[sessionId] - Get specific session state (for polling)
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';

export const dynamic = 'force-dynamic';

/**
 * GET /api/sync/you-or-me/[sessionId]
 *
 * Poll specific You or Me session state
 */
export const GET = withAuthOrDevBypass(async (req, userId, email, context) => {
  try {
    const resolvedParams = context?.params ? (await context.params) : null;
    const sessionId = resolvedParams?.sessionId;

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
});

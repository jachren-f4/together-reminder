/**
 * Quiz Session Poll API
 *
 * GET /api/sync/quiz/[sessionId] - Get specific session state (for polling)
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';

export const dynamic = 'force-dynamic';

/**
 * GET /api/sync/quiz/[sessionId]
 *
 * Poll specific quiz session state
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

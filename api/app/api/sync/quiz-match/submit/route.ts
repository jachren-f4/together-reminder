/**
 * Quiz Match Submit API Endpoint
 *
 * Handles answer submission for Classic and Affirmation quizzes.
 * Awards LP when both players have answered.
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { awardLP } from '@/lib/lp/award';

export const dynamic = 'force-dynamic';

// LP rewards
const LP_REWARDS = {
  classic: 30,
  affirmation: 30,
};

// Calculate match percentage for classic quiz (how many answers match)
function calculateMatchPercentage(player1Answers: number[], player2Answers: number[]): number {
  if (player1Answers.length === 0 || player2Answers.length === 0) {
    return 0;
  }

  const totalQuestions = Math.min(player1Answers.length, player2Answers.length);
  let matches = 0;

  for (let i = 0; i < totalQuestions; i++) {
    if (player1Answers[i] === player2Answers[i]) {
      matches++;
    }
  }

  return Math.round((matches / totalQuestions) * 100);
}

/**
 * POST /api/sync/quiz-match/submit
 *
 * Submit answers for a quiz match.
 *
 * Request body:
 * {
 *   matchId: "uuid",
 *   answers: [0, 2, 1, 3, 4]  // Answer indices for each question
 * }
 */
export const POST = withAuthOrDevBypass(async (req, userId, email) => {
  try {
    const body = await req.json();
    const { matchId, answers } = body;

    if (!matchId || !answers || !Array.isArray(answers)) {
      return NextResponse.json(
        { error: 'Missing required fields: matchId, answers (array)' },
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
    const isPlayer1 = userId === user1_id;

    // Get current match
    const matchResult = await query(
      `SELECT * FROM quiz_matches WHERE id = $1 AND couple_id = $2`,
      [matchId, coupleId]
    );

    if (matchResult.rows.length === 0) {
      return NextResponse.json(
        { error: 'Match not found', code: 'NO_MATCH' },
        { status: 404 }
      );
    }

    const match = matchResult.rows[0];

    // Check match is still active
    if (match.status !== 'active') {
      return NextResponse.json(
        { error: 'Match already completed', code: 'ALREADY_COMPLETED' },
        { status: 400 }
      );
    }

    // Parse existing answers
    const player1Answers = typeof match.player1_answers === 'string'
      ? JSON.parse(match.player1_answers)
      : match.player1_answers || [];
    const player2Answers = typeof match.player2_answers === 'string'
      ? JSON.parse(match.player2_answers)
      : match.player2_answers || [];

    // Check if user already answered
    const hasUserAnswered = isPlayer1
      ? player1Answers.length > 0
      : player2Answers.length > 0;

    if (hasUserAnswered) {
      return NextResponse.json(
        { error: 'Already submitted answers', code: 'ALREADY_ANSWERED' },
        { status: 400 }
      );
    }

    // Update answers
    const updatedPlayer1Answers = isPlayer1 ? answers : player1Answers;
    const updatedPlayer2Answers = isPlayer1 ? player2Answers : answers;

    // Check if both players have now answered
    const bothAnswered = updatedPlayer1Answers.length > 0 && updatedPlayer2Answers.length > 0;

    let matchPercentage = null;
    let lpEarned = 0;
    let newStatus = 'active';

    if (bothAnswered) {
      // Calculate match percentage
      matchPercentage = calculateMatchPercentage(updatedPlayer1Answers, updatedPlayer2Answers);

      // Mark as completed
      newStatus = 'completed';

      // Award LP using shared utility (updates couples.total_lp)
      lpEarned = LP_REWARDS[match.quiz_type as keyof typeof LP_REWARDS] || 30;
      await awardLP(coupleId, lpEarned, 'quiz_complete', matchId);
    }

    // Update match in database
    const updateResult = await query(
      `UPDATE quiz_matches
       SET player1_answers = $1,
           player2_answers = $2,
           player1_answer_count = $3,
           player2_answer_count = $4,
           match_percentage = $5,
           status = $6,
           completed_at = $7
       WHERE id = $8
       RETURNING *`,
      [
        JSON.stringify(updatedPlayer1Answers),
        JSON.stringify(updatedPlayer2Answers),
        updatedPlayer1Answers.length,
        updatedPlayer2Answers.length,
        matchPercentage,
        newStatus,
        bothAnswered ? new Date().toISOString() : null,
        matchId,
      ]
    );

    const updatedMatch = updateResult.rows[0];

    return NextResponse.json({
      success: true,
      bothAnswered,
      isCompleted: newStatus === 'completed',
      matchPercentage,
      lpEarned,
      match: {
        id: updatedMatch.id,
        quizId: updatedMatch.quiz_id,
        quizType: updatedMatch.quiz_type,
        status: updatedMatch.status,
        player1Answers: updatedPlayer1Answers,
        player2Answers: updatedPlayer2Answers,
        matchPercentage: updatedMatch.match_percentage,
        completedAt: updatedMatch.completed_at,
      },
      gameState: {
        hasUserAnswered: true,
        hasPartnerAnswered: bothAnswered,
        isCompleted: newStatus === 'completed',
        canAnswer: false,
      }
    });
  } catch (error) {
    console.error('Error submitting quiz answers:', error);
    return NextResponse.json(
      { error: 'Failed to submit answers' },
      { status: 500 }
    );
  }
});

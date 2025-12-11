/**
 * Quiz Answer Submission API
 *
 * POST /api/sync/quiz/submit - Submit answers for a quiz session
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query, getClient } from '@/lib/db/pool';
import { LP_REWARDS, LP_BONUSES } from '@/lib/lp/config';

export const dynamic = 'force-dynamic';

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
export const POST = withAuthOrDevBypass(async (req, userId, email) => {
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

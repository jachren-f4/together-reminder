/**
 * Welcome Quiz API
 *
 * GET /api/welcome-quiz - Get welcome quiz questions and status
 * Returns questions and current completion status for the couple.
 */

import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { NextResponse } from 'next/server';
import { getCoupleBasic } from '@/lib/couple/utils';

// Welcome quiz questions - hardcoded for consistency
const WELCOME_QUIZ_QUESTIONS = [
  {
    id: 'wq1',
    question: 'Who said "I love you" first?',
    options: ['Me', 'My partner', 'We said it at the same time'],
  },
  {
    id: 'wq2',
    question: 'Who usually apologizes first after a disagreement?',
    options: ['Me', 'My partner', 'We both apologize equally'],
  },
  {
    id: 'wq3',
    question: 'Who is more likely to plan a surprise date?',
    options: ['Me', 'My partner', 'We both love planning surprises'],
  },
];

export const GET = withAuthOrDevBypass(async (_req, userId) => {
  try {
    // Find couple
    const couple = await getCoupleBasic(userId);
    if (!couple) {
      return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
    }

    const { coupleId, partnerId } = couple;

    // Check if user has already submitted answers
    const userAnswerResult = await query(
      `SELECT * FROM welcome_quiz_answers WHERE couple_id = $1 AND user_id = $2`,
      [coupleId, userId]
    );
    const userHasAnswered = userAnswerResult.rows.length > 0;

    // Check if partner has submitted answers
    const partnerAnswerResult = await query(
      `SELECT * FROM welcome_quiz_answers WHERE couple_id = $1 AND user_id = $2`,
      [coupleId, partnerId]
    );
    const partnerHasAnswered = partnerAnswerResult.rows.length > 0;

    // Get results if both have answered
    let results = null;
    if (userHasAnswered && partnerHasAnswered) {
      const resultsQuery = await query(
        `SELECT * FROM get_welcome_quiz_results($1)`,
        [coupleId]
      );

      results = {
        questions: resultsQuery.rows.map((row) => ({
          questionId: row.question_id,
          question: WELCOME_QUIZ_QUESTIONS.find((q) => q.id === row.question_id)?.question || '',
          user1Answer: row.user1_answer,
          user2Answer: row.user2_answer,
          isMatch: row.is_match,
        })),
        matchCount: resultsQuery.rows.filter((r) => r.is_match).length,
        totalQuestions: resultsQuery.rows.length,
      };
    }

    return NextResponse.json({
      questions: WELCOME_QUIZ_QUESTIONS,
      status: {
        userHasAnswered,
        partnerHasAnswered,
        bothCompleted: userHasAnswered && partnerHasAnswered,
      },
      results,
    });
  } catch (error) {
    console.error('Error fetching welcome quiz:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
});

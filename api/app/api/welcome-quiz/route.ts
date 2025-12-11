/**
 * Welcome Quiz API
 *
 * GET /api/welcome-quiz - Get welcome quiz questions and status
 * Returns questions and current completion status for the couple.
 *
 * Answer Denormalization:
 * Answers are stored as normalized user IDs ("Me" → userId, "My partner" → partnerId).
 * When returning results, we convert back to human-readable format from the viewer's perspective.
 */

import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { NextResponse } from 'next/server';
import { getCoupleBasic } from '@/lib/couple/utils';

/**
 * Convert a normalized answer (user ID) back to display format.
 * Viewer-relative: if answer is viewer's ID → "Me", if partner's ID → "My partner"
 */
function denormalizeAnswer(answer: string, viewerUserId: string, partnerId: string): string {
  // Check if the answer looks like a UUID (normalized user ID)
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (uuidPattern.test(answer)) {
    // Convert back to relative answer from viewer's perspective
    if (answer === viewerUserId) {
      return 'Me';
    } else if (answer === partnerId) {
      return 'My partner';
    }
  }
  // Return as-is (it's either a non-relative answer or already human-readable)
  return answer;
}

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

      // Also fetch the raw stored answers to get originalAnswer for display
      const answersQuery = await query(
        `SELECT user_id, answers FROM welcome_quiz_answers WHERE couple_id = $1`,
        [coupleId]
      );

      // Build lookup: visitorUserId -> { questionId -> originalAnswer }
      const answersByUser: Record<string, Record<string, string>> = {};
      for (const row of answersQuery.rows) {
        const userAnswers: Record<string, string> = {};
        const parsedAnswers = typeof row.answers === 'string'
          ? JSON.parse(row.answers)
          : row.answers;
        for (const a of parsedAnswers) {
          // Use originalAnswer if available (new format), otherwise use answer (old format)
          userAnswers[a.questionId] = a.originalAnswer || a.answer;
        }
        answersByUser[row.user_id] = userAnswers;
      }

      results = {
        questions: resultsQuery.rows.map((row: {
          question_id: string;
          user1_id: string;
          user1_answer: string;
          user2_id: string;
          user2_answer: string;
          is_match: boolean;
        }) => {
          const questionDef = WELCOME_QUIZ_QUESTIONS.find((q) => q.id === row.question_id);

          // Determine which user in the database row is the viewer vs partner
          const viewerIsUser1 = row.user1_id === userId;

          // Get the raw answers (might be originalAnswer or normalized UUID)
          const rawUser1Answer = answersByUser[row.user1_id]?.[row.question_id] || row.user1_answer;
          const rawUser2Answer = answersByUser[row.user2_id]?.[row.question_id] || row.user2_answer;

          // Map to viewer-relative order: userAnswer = viewer's answer, partnerAnswer = partner's answer
          const rawUserAnswer = viewerIsUser1 ? rawUser1Answer : rawUser2Answer;
          const rawPartnerAnswer = viewerIsUser1 ? rawUser2Answer : rawUser1Answer;

          // Denormalize UUIDs back to human-readable format for the viewer
          // From viewer's perspective: viewer's ID → "Me", partner's ID → "My partner"
          const userAnswer = denormalizeAnswer(rawUserAnswer, userId, partnerId);
          const partnerAnswer = denormalizeAnswer(rawPartnerAnswer, userId, partnerId);

          return {
            questionId: row.question_id,
            question: questionDef?.question || '',
            // Return viewer-relative answers (user1Answer = viewer, user2Answer = partner)
            user1Answer: userAnswer,
            user2Answer: partnerAnswer,
            isMatch: row.is_match,
          };
        }),
        matchCount: resultsQuery.rows.filter((r: { is_match: boolean }) => r.is_match).length,
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

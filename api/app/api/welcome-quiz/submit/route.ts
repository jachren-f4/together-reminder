/**
 * POST /api/welcome-quiz/submit
 *
 * Submit answers for the welcome quiz.
 * If both partners have submitted, triggers the unlock for daily quizzes.
 *
 * Match Logic:
 * Questions like "Who said I love you first?" have options: "Me", "My partner", "Both"
 * When User A says "Me" and User B says "My partner", they're both pointing to User A.
 * We normalize these answers to user IDs before comparing:
 * - "Me" → the submitter's user_id
 * - "My partner" → the partner's user_id
 * - Other options (like "Both" or "We said it at the same time") stay as-is
 */

import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { NextResponse } from 'next/server';
import { getCoupleBasic } from '@/lib/couple/utils';
import { withTransaction } from '@/lib/db/transaction';
import { awardLP } from '@/lib/lp/award';

// Welcome quiz questions - must match route.ts
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

interface Answer {
  questionId: string;
  answer: string;
}

/**
 * Normalize relative answers ("Me"/"My partner") to user IDs for comparison.
 * This allows correct matching when User A says "Me" and User B says "My partner"
 * (both pointing to User A).
 */
function normalizeAnswer(answer: string, userId: string, partnerId: string): string {
  if (answer === 'Me') {
    return userId;
  } else if (answer === 'My partner') {
    return partnerId;
  }
  // For answers like "We said it at the same time" or "We both...", keep as-is
  return answer;
}

/**
 * Convert a normalized answer (user ID) back to display format.
 * Used for legacy data that doesn't have originalAnswer stored.
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

export const POST = withAuthOrDevBypass(async (req, userId) => {
  try {
    console.log('[welcome-quiz/submit] Starting submit for userId:', userId);

    const body = await req.json();
    const { answers } = body as { answers: Answer[] };
    console.log('[welcome-quiz/submit] Received answers:', JSON.stringify(answers));

    if (!answers || !Array.isArray(answers) || answers.length === 0) {
      console.log('[welcome-quiz/submit] Invalid answers - returning 400');
      return NextResponse.json({ error: 'Invalid answers' }, { status: 400 });
    }

    // Find couple
    const couple = await getCoupleBasic(userId);
    console.log('[welcome-quiz/submit] Couple lookup result:', couple);
    if (!couple) {
      console.log('[welcome-quiz/submit] No couple found - returning 404');
      return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
    }

    const { coupleId, partnerId } = couple;

    // Normalize answers: convert "Me"/"My partner" to user IDs for correct matching
    const normalizedAnswers = answers.map(a => ({
      questionId: a.questionId,
      answer: normalizeAnswer(a.answer, userId, partnerId),
      originalAnswer: a.answer, // Keep original for display
    }));
    console.log('[welcome-quiz/submit] Normalized answers:', JSON.stringify(normalizedAnswers));

    const result = await withTransaction(async (client) => {
      // Insert or update user's answers (store normalized version)
      await client.query(
        `INSERT INTO welcome_quiz_answers (couple_id, user_id, answers)
         VALUES ($1, $2, $3)
         ON CONFLICT (couple_id, user_id)
         DO UPDATE SET answers = $3, completed_at = NOW()`,
        [coupleId, userId, JSON.stringify(normalizedAnswers)]
      );

      // Check if partner has also answered
      const partnerResult = await client.query(
        `SELECT * FROM welcome_quiz_answers WHERE couple_id = $1 AND user_id = $2`,
        [coupleId, partnerId]
      );
      const partnerHasAnswered = partnerResult.rows.length > 0;

      // If both completed, trigger the unlock
      if (partnerHasAnswered) {
        // Ensure unlock state exists
        await client.query(
          `INSERT INTO couple_unlocks (couple_id)
           VALUES ($1)
           ON CONFLICT (couple_id) DO NOTHING`,
          [coupleId]
        );

        // Check if not already unlocked
        const unlockResult = await client.query(
          `SELECT classic_quiz_unlocked FROM couple_unlocks WHERE couple_id = $1 FOR UPDATE`,
          [coupleId]
        );

        if (!unlockResult.rows[0]?.classic_quiz_unlocked) {
          // Unlock daily quizzes (LP awarded after transaction commits)
          await client.query(
            `UPDATE couple_unlocks
             SET welcome_quiz_completed = true,
                 classic_quiz_unlocked = true,
                 affirmation_quiz_unlocked = true
             WHERE couple_id = $1`,
            [coupleId]
          );
        }

        // Get results from PostgreSQL
        const resultsQuery = await client.query(
          `SELECT * FROM get_welcome_quiz_results($1)`,
          [coupleId]
        );

        // Also fetch the raw stored answers to get originalAnswer for display
        const answersQuery = await client.query(
          `SELECT user_id, answers FROM welcome_quiz_answers WHERE couple_id = $1`,
          [coupleId]
        );

        // Build lookup: userId -> { questionId -> originalAnswer }
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

        // Transform results: add question text and display-friendly answers
        const questions = resultsQuery.rows.map((row: {
          question_id: string;
          user1_id: string;
          user1_answer: string;
          user2_id: string;
          user2_answer: string;
          is_match: boolean;
        }) => {
          const questionDef = WELCOME_QUIZ_QUESTIONS.find(q => q.id === row.question_id);

          // Get the raw answer (might be originalAnswer or normalized UUID)
          let user1Answer = answersByUser[row.user1_id]?.[row.question_id] || row.user1_answer;
          let user2Answer = answersByUser[row.user2_id]?.[row.question_id] || row.user2_answer;

          // Denormalize UUIDs back to human-readable format for the viewer
          // From viewer's perspective: viewer is "Me", partner is "My partner"
          user1Answer = denormalizeAnswer(user1Answer, userId, partnerId);
          user2Answer = denormalizeAnswer(user2Answer, userId, partnerId);

          return {
            questionId: row.question_id,
            question: questionDef?.question || '', // Add question text for Bug 2
            user1Answer,
            user2Answer,
            isMatch: row.is_match,
          };
        });

        return {
          submitted: true,
          bothCompleted: true,
          results: {
            matchCount: questions.filter((q: { isMatch: boolean }) => q.isMatch).length,
            totalQuestions: questions.length,
            questions,
          },
        };
      }

      // Partner hasn't answered yet
      return {
        submitted: true,
        bothCompleted: false,
        waitingForPartner: true,
      };
    });

    console.log('[welcome-quiz/submit] Transaction result:', JSON.stringify(result));

    // Award LP when both partners complete (30 LP for welcome quiz)
    // This is outside the transaction but uses idempotency via relatedId
    if (result.bothCompleted) {
      try {
        const lpResult = await awardLP(coupleId, 30, 'welcome_quiz', coupleId);
        console.log('[welcome-quiz/submit] LP award result:', lpResult);
      } catch (lpError) {
        // Log but don't fail the request - quiz completion is more important
        console.error('[welcome-quiz/submit] LP award error (non-fatal):', lpError);
      }
    }

    return NextResponse.json(result);
  } catch (error) {
    console.error('[welcome-quiz/submit] Error:', error);
    console.error('[welcome-quiz/submit] Error stack:', error instanceof Error ? error.stack : 'no stack');
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
});

/**
 * POST /api/welcome-quiz/submit
 *
 * Submit answers for the welcome quiz.
 * If both partners have submitted, triggers the unlock for daily quizzes.
 */

import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { NextResponse } from 'next/server';
import { getCoupleBasic } from '@/lib/couple/utils';
import { withTransaction } from '@/lib/db/transaction';

interface Answer {
  questionId: string;
  answer: string;
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

    const result = await withTransaction(async (client) => {
      // Insert or update user's answers
      await client.query(
        `INSERT INTO welcome_quiz_answers (couple_id, user_id, answers)
         VALUES ($1, $2, $3)
         ON CONFLICT (couple_id, user_id)
         DO UPDATE SET answers = $3, completed_at = NOW()`,
        [coupleId, userId, JSON.stringify(answers)]
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

        let lpAwarded = 0;
        if (!unlockResult.rows[0]?.classic_quiz_unlocked) {
          // Unlock daily quizzes
          await client.query(
            `UPDATE couple_unlocks
             SET welcome_quiz_completed = true,
                 classic_quiz_unlocked = true,
                 affirmation_quiz_unlocked = true
             WHERE couple_id = $1`,
            [coupleId]
          );

          // Award LP
          lpAwarded = 30;
          await client.query(
            `UPDATE couples SET total_lp = total_lp + $1 WHERE id = $2`,
            [lpAwarded, coupleId]
          );

          // Log transaction (user_id is the one who triggered the unlock)
          await client.query(
            `INSERT INTO love_point_transactions (user_id, amount, source, description)
             VALUES ($1, $2, $3, $4)`,
            [userId, lpAwarded, 'unlock', 'Unlocked: classic_quiz, affirmation_quiz']
          );
        }

        // Get results
        const resultsQuery = await client.query(
          `SELECT * FROM get_welcome_quiz_results($1)`,
          [coupleId]
        );

        // Transform snake_case from PostgreSQL to camelCase for Flutter
        const questions = resultsQuery.rows.map((row: {
          question_id: string;
          user1_id: string;
          user1_answer: string;
          user2_id: string;
          user2_answer: string;
          is_match: boolean;
        }) => ({
          questionId: row.question_id,
          user1Answer: row.user1_answer,
          user2Answer: row.user2_answer,
          isMatch: row.is_match,
        }));

        return {
          submitted: true,
          bothCompleted: true,
          lpAwarded,
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
    return NextResponse.json(result);
  } catch (error) {
    console.error('[welcome-quiz/submit] Error:', error);
    console.error('[welcome-quiz/submit] Error stack:', error instanceof Error ? error.stack : 'no stack');
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
});

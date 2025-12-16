/**
 * POST /api/unlocks/complete
 *
 * Called when a user completes a feature that triggers an unlock.
 * Updates the unlock state (NO LP awarded - LP comes from game completion only).
 *
 * Triggers:
 * - 'welcome_quiz' -> Unlocks classic_quiz + affirmation_quiz
 * - 'daily_quiz' -> Marks classic/affirmation as completed based on quizType param
 *                   Unlocks you_or_me only when BOTH are completed
 * - 'you_or_me' -> Unlocks linked
 * - 'linked' -> Unlocks word_search
 * - 'word_search' -> Unlocks steps (marks onboarding complete)
 */

import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { NextResponse } from 'next/server';
import { getCouple } from '@/lib/couple/utils';
import { withTransaction } from '@/lib/db/transaction';

type UnlockTrigger = 'welcome_quiz' | 'daily_quiz' | 'you_or_me' | 'linked' | 'word_search';

interface UnlockResult {
  success: boolean;
  newlyUnlocked: string[];
  unlockState: {
    welcomeQuizCompleted: boolean;
    classicQuizUnlocked: boolean;
    classicQuizCompleted: boolean;
    affirmationQuizUnlocked: boolean;
    affirmationQuizCompleted: boolean;
    youOrMeUnlocked: boolean;
    linkedUnlocked: boolean;
    wordSearchUnlocked: boolean;
    stepsUnlocked: boolean;
    onboardingCompleted: boolean;
  };
}

export const POST = withAuthOrDevBypass(async (req, userId) => {
  try {
    const body = await req.json();
    const { trigger, quizType } = body as { trigger: UnlockTrigger; quizType?: 'classic' | 'affirmation' };

    if (!trigger) {
      return NextResponse.json({ error: 'Missing trigger' }, { status: 400 });
    }

    // Find couple
    const couple = await getCouple(userId);
    if (!couple) {
      return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
    }

    const { coupleId } = couple;

    // Process unlock within transaction
    const result = await withTransaction(async (client) => {
      // Ensure unlock state exists
      await client.query(
        `INSERT INTO couple_unlocks (couple_id)
         VALUES ($1)
         ON CONFLICT (couple_id) DO NOTHING`,
        [coupleId]
      );

      // Get current state
      const currentResult = await client.query(
        `SELECT * FROM couple_unlocks WHERE couple_id = $1 FOR UPDATE`,
        [coupleId]
      );
      const current = currentResult.rows[0];

      // Safety check - if no row found, something went wrong with the insert
      if (!current) {
        console.error(`No couple_unlocks row found for couple ${coupleId} after INSERT`);
        throw new Error('Failed to initialize unlock state');
      }

      const newlyUnlocked: string[] = [];

      // Determine what to unlock based on trigger
      // NOTE: No LP is awarded for unlocking - LP comes from game completion only
      switch (trigger) {
        case 'welcome_quiz':
          // Only unlock if not already unlocked
          if (!current.classic_quiz_unlocked) {
            await client.query(
              `UPDATE couple_unlocks
               SET welcome_quiz_completed = true,
                   classic_quiz_unlocked = true,
                   affirmation_quiz_unlocked = true
               WHERE couple_id = $1`,
              [coupleId]
            );
            newlyUnlocked.push('classic_quiz', 'affirmation_quiz');
          }
          break;

        case 'daily_quiz':
          // Track which quiz type was completed
          // You or Me only unlocks when BOTH Classic AND Affirmation are completed
          if (quizType === 'classic' && !current.classic_quiz_completed) {
            await client.query(
              `UPDATE couple_unlocks
               SET classic_quiz_completed = true
               WHERE couple_id = $1`,
              [coupleId]
            );
            // Refetch to get updated state
            const afterClassic = await client.query(
              `SELECT * FROM couple_unlocks WHERE couple_id = $1`,
              [coupleId]
            );
            // Check if both are now completed and you_or_me not yet unlocked
            if (afterClassic.rows[0].affirmation_quiz_completed && !afterClassic.rows[0].you_or_me_unlocked) {
              await client.query(
                `UPDATE couple_unlocks
                 SET you_or_me_unlocked = true
                 WHERE couple_id = $1`,
                [coupleId]
              );
              newlyUnlocked.push('you_or_me');
            }
          } else if (quizType === 'affirmation' && !current.affirmation_quiz_completed) {
            await client.query(
              `UPDATE couple_unlocks
               SET affirmation_quiz_completed = true
               WHERE couple_id = $1`,
              [coupleId]
            );
            // Refetch to get updated state
            const afterAffirmation = await client.query(
              `SELECT * FROM couple_unlocks WHERE couple_id = $1`,
              [coupleId]
            );
            // Check if both are now completed and you_or_me not yet unlocked
            if (afterAffirmation.rows[0].classic_quiz_completed && !afterAffirmation.rows[0].you_or_me_unlocked) {
              await client.query(
                `UPDATE couple_unlocks
                 SET you_or_me_unlocked = true
                 WHERE couple_id = $1`,
                [coupleId]
              );
              newlyUnlocked.push('you_or_me');
            }
          } else if (!quizType) {
            // Fallback for old clients that don't send quizType
            // Old behavior: unlock immediately (to not break existing functionality)
            console.warn('daily_quiz trigger without quizType - using legacy behavior');
            if (!current.you_or_me_unlocked) {
              await client.query(
                `UPDATE couple_unlocks
                 SET you_or_me_unlocked = true
                 WHERE couple_id = $1`,
                [coupleId]
              );
              newlyUnlocked.push('you_or_me');
            }
          }
          break;

        case 'you_or_me':
          // Only unlock if not already unlocked
          if (!current.linked_unlocked) {
            await client.query(
              `UPDATE couple_unlocks
               SET linked_unlocked = true
               WHERE couple_id = $1`,
              [coupleId]
            );
            newlyUnlocked.push('linked');
          }
          break;

        case 'linked':
          // Only unlock if not already unlocked
          if (!current.word_search_unlocked) {
            await client.query(
              `UPDATE couple_unlocks
               SET word_search_unlocked = true
               WHERE couple_id = $1`,
              [coupleId]
            );
            newlyUnlocked.push('word_search');
          }
          break;

        case 'word_search':
          // Only unlock if not already unlocked
          if (!current.steps_unlocked) {
            await client.query(
              `UPDATE couple_unlocks
               SET steps_unlocked = true,
                   onboarding_completed = true
               WHERE couple_id = $1`,
              [coupleId]
            );
            newlyUnlocked.push('steps');
          }
          break;

        default:
          throw new Error(`Unknown trigger: ${trigger}`);
      }

      // Get updated state
      const updatedResult = await client.query(
        `SELECT * FROM couple_unlocks WHERE couple_id = $1`,
        [coupleId]
      );
      const updated = updatedResult.rows[0];

      return {
        success: true,
        newlyUnlocked,
        unlockState: {
          welcomeQuizCompleted: updated.welcome_quiz_completed,
          classicQuizUnlocked: updated.classic_quiz_unlocked,
          classicQuizCompleted: updated.classic_quiz_completed ?? false,
          affirmationQuizUnlocked: updated.affirmation_quiz_unlocked,
          affirmationQuizCompleted: updated.affirmation_quiz_completed ?? false,
          youOrMeUnlocked: updated.you_or_me_unlocked,
          linkedUnlocked: updated.linked_unlocked,
          wordSearchUnlocked: updated.word_search_unlocked,
          stepsUnlocked: updated.steps_unlocked,
          onboardingCompleted: updated.onboarding_completed,
        },
      } as UnlockResult;
    });

    return NextResponse.json(result);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const errorStack = error instanceof Error ? error.stack : '';
    console.error('Error completing unlock:', {
      error: errorMessage,
      stack: errorStack,
      userId,
      trigger: (await req.clone().json().catch(() => ({}))).trigger,
    });
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
});

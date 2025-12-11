/**
 * POST /api/unlocks/complete
 *
 * Called when a user completes a feature that triggers an unlock.
 * Updates the unlock state and awards LP for the unlock.
 *
 * Triggers:
 * - 'welcome_quiz' -> Unlocks classic_quiz + affirmation_quiz (+30 LP)
 * - 'daily_quiz' -> Unlocks you_or_me (+30 LP)
 * - 'you_or_me' -> Unlocks linked (+30 LP)
 * - 'linked' -> Unlocks word_search (+30 LP)
 * - 'word_search' -> Unlocks steps (+30 LP, marks onboarding complete)
 */

import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { NextResponse } from 'next/server';
import { getCouple } from '@/lib/couple/utils';
import { withTransaction } from '@/lib/db/transaction';

type UnlockTrigger = 'welcome_quiz' | 'daily_quiz' | 'you_or_me' | 'linked' | 'word_search';

interface UnlockResult {
  success: boolean;
  lpAwarded: number;
  newlyUnlocked: string[];
  unlockState: {
    welcomeQuizCompleted: boolean;
    classicQuizUnlocked: boolean;
    affirmationQuizUnlocked: boolean;
    youOrMeUnlocked: boolean;
    linkedUnlocked: boolean;
    wordSearchUnlocked: boolean;
    stepsUnlocked: boolean;
    onboardingCompleted: boolean;
  };
}

const UNLOCK_LP = 30;

export const POST = withAuthOrDevBypass(async (req, userId) => {
  try {
    const body = await req.json();
    const { trigger } = body as { trigger: UnlockTrigger };

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

      let lpAwarded = 0;
      const newlyUnlocked: string[] = [];

      // Determine what to unlock based on trigger
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
            lpAwarded = UNLOCK_LP;
            newlyUnlocked.push('classic_quiz', 'affirmation_quiz');
          }
          break;

        case 'daily_quiz':
          // Only unlock if not already unlocked
          if (!current.you_or_me_unlocked) {
            await client.query(
              `UPDATE couple_unlocks
               SET you_or_me_unlocked = true
               WHERE couple_id = $1`,
              [coupleId]
            );
            lpAwarded = UNLOCK_LP;
            newlyUnlocked.push('you_or_me');
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
            lpAwarded = UNLOCK_LP;
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
            lpAwarded = UNLOCK_LP;
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
            lpAwarded = UNLOCK_LP;
            newlyUnlocked.push('steps');
          }
          break;

        default:
          throw new Error(`Unknown trigger: ${trigger}`);
      }

      // Award LP if any unlock happened
      if (lpAwarded > 0) {
        await client.query(
          `UPDATE couples SET total_lp = total_lp + $1 WHERE id = $2`,
          [lpAwarded, coupleId]
        );

        // Log the LP transaction
        await client.query(
          `INSERT INTO love_point_transactions (couple_id, amount, source, description)
           VALUES ($1, $2, $3, $4)`,
          [coupleId, lpAwarded, 'unlock', `Unlocked: ${newlyUnlocked.join(', ')}`]
        );
      }

      // Get updated state
      const updatedResult = await client.query(
        `SELECT * FROM couple_unlocks WHERE couple_id = $1`,
        [coupleId]
      );
      const updated = updatedResult.rows[0];

      return {
        success: true,
        lpAwarded,
        newlyUnlocked,
        unlockState: {
          welcomeQuizCompleted: updated.welcome_quiz_completed,
          classicQuizUnlocked: updated.classic_quiz_unlocked,
          affirmationQuizUnlocked: updated.affirmation_quiz_unlocked,
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
    console.error('Error completing unlock:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
});

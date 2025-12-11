/**
 * GET /api/unlocks
 *
 * Returns the unlock state for the current user's couple.
 * Creates default unlock state if none exists.
 */

import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { NextResponse } from 'next/server';
import { getCoupleId } from '@/lib/couple/utils';

export interface UnlockState {
  coupleId: string;
  welcomeQuizCompleted: boolean;
  classicQuizUnlocked: boolean;
  affirmationQuizUnlocked: boolean;
  youOrMeUnlocked: boolean;
  linkedUnlocked: boolean;
  wordSearchUnlocked: boolean;
  stepsUnlocked: boolean;
  onboardingCompleted: boolean;
  lpIntroShown: boolean;
}

export const GET = withAuthOrDevBypass(async (_req, userId) => {
  try {
    // Find couple
    const coupleId = await getCoupleId(userId);
    if (!coupleId) {
      return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
    }

    // Get or create unlock state
    let result = await query(
      `SELECT * FROM couple_unlocks WHERE couple_id = $1`,
      [coupleId]
    );

    // If no unlock state exists, create default
    if (result.rows.length === 0) {
      result = await query(
        `INSERT INTO couple_unlocks (couple_id)
         VALUES ($1)
         ON CONFLICT (couple_id) DO NOTHING
         RETURNING *`,
        [coupleId]
      );

      // Race condition: another request might have inserted, so fetch again
      if (result.rows.length === 0) {
        result = await query(
          `SELECT * FROM couple_unlocks WHERE couple_id = $1`,
          [coupleId]
        );
      }
    }

    const row = result.rows[0];

    const unlockState: UnlockState = {
      coupleId: row.couple_id,
      welcomeQuizCompleted: row.welcome_quiz_completed,
      classicQuizUnlocked: row.classic_quiz_unlocked,
      affirmationQuizUnlocked: row.affirmation_quiz_unlocked,
      youOrMeUnlocked: row.you_or_me_unlocked,
      linkedUnlocked: row.linked_unlocked,
      wordSearchUnlocked: row.word_search_unlocked,
      stepsUnlocked: row.steps_unlocked,
      onboardingCompleted: row.onboarding_completed,
      lpIntroShown: row.lp_intro_shown,
    };

    return NextResponse.json(unlockState);
  } catch (error) {
    console.error('Error fetching unlock state:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
});

/**
 * PATCH /api/unlocks
 *
 * Updates specific fields in the unlock state.
 * Used for marking LP intro as shown.
 */
export const PATCH = withAuthOrDevBypass(async (req, userId) => {
  try {
    const body = await req.json();
    const { lpIntroShown } = body;

    // Find couple
    const coupleId = await getCoupleId(userId);
    if (!coupleId) {
      return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
    }

    // Update only allowed fields
    if (typeof lpIntroShown === 'boolean') {
      await query(
        `UPDATE couple_unlocks
         SET lp_intro_shown = $1
         WHERE couple_id = $2`,
        [lpIntroShown, coupleId]
      );
    }

    // Return updated state
    const result = await query(
      `SELECT * FROM couple_unlocks WHERE couple_id = $1`,
      [coupleId]
    );

    if (result.rows.length === 0) {
      return NextResponse.json({ error: 'Unlock state not found' }, { status: 404 });
    }

    const row = result.rows[0];

    const unlockState: UnlockState = {
      coupleId: row.couple_id,
      welcomeQuizCompleted: row.welcome_quiz_completed,
      classicQuizUnlocked: row.classic_quiz_unlocked,
      affirmationQuizUnlocked: row.affirmation_quiz_unlocked,
      youOrMeUnlocked: row.you_or_me_unlocked,
      linkedUnlocked: row.linked_unlocked,
      wordSearchUnlocked: row.word_search_unlocked,
      stepsUnlocked: row.steps_unlocked,
      onboardingCompleted: row.onboarding_completed,
      lpIntroShown: row.lp_intro_shown,
    };

    return NextResponse.json(unlockState);
  } catch (error) {
    console.error('Error updating unlock state:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
});

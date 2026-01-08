/**
 * Magnet Quiz Availability API
 *
 * GET /api/magnets/quizzes - Get available quizzes based on unlocked magnets
 *
 * Returns count of available (unplayed) quizzes per type and whether
 * the couple has exhausted all available quizzes.
 */

import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { getCouple } from '@/lib/couple/utils';
import {
  getAvailableQuizzes,
  hasExhaustedQuizzes,
  selectDailyQuiz,
  getQuizPackStats,
} from '@/lib/quests';
import { getMagnetProgress } from '@/lib/magnets';
import { NextResponse } from 'next/server';

export interface QuizAvailabilityResponse {
  // Per-type availability
  classic: {
    available: number;
    exhausted: boolean;
    selectedQuiz: { quizId: string; isReplay: boolean } | null;
  };
  affirmation: {
    available: number;
    exhausted: boolean;
    selectedQuiz: { quizId: string; isReplay: boolean } | null;
  };
  you_or_me: {
    available: number;
    exhausted: boolean;
    selectedQuiz: { quizId: string; isReplay: boolean } | null;
  };

  // Overall status
  anyExhausted: boolean;
  allExhausted: boolean;

  // Magnet context
  unlockedMagnets: number;
  totalQuizzesAvailable: number;
}

export const GET = withAuthOrDevBypass(async (req, userId) => {
  try {
    const couple = await getCouple(userId);

    if (!couple) {
      return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
    }

    const { coupleId, totalLp } = couple;

    // Get magnet progress
    const magnetProgress = getMagnetProgress(totalLp);

    // Get available quizzes for each type
    const [classicAvailable, affirmationAvailable, youOrMeAvailable] = await Promise.all([
      getAvailableQuizzes(coupleId, 'classic'),
      getAvailableQuizzes(coupleId, 'affirmation'),
      getAvailableQuizzes(coupleId, 'you_or_me'),
    ]);

    // Check exhaustion status
    const classicExhausted = classicAvailable.length === 0;
    const affirmationExhausted = affirmationAvailable.length === 0;
    const youOrMeExhausted = youOrMeAvailable.length === 0;

    // Select daily quizzes (will return replay if exhausted)
    const [classicSelected, affirmationSelected, youOrMeSelected] = await Promise.all([
      selectDailyQuiz(coupleId, 'classic'),
      selectDailyQuiz(coupleId, 'affirmation'),
      selectDailyQuiz(coupleId, 'you_or_me'),
    ]);

    const response: QuizAvailabilityResponse = {
      classic: {
        available: classicAvailable.length,
        exhausted: classicExhausted,
        selectedQuiz: classicSelected,
      },
      affirmation: {
        available: affirmationAvailable.length,
        exhausted: affirmationExhausted,
        selectedQuiz: affirmationSelected,
      },
      you_or_me: {
        available: youOrMeAvailable.length,
        exhausted: youOrMeExhausted,
        selectedQuiz: youOrMeSelected,
      },

      anyExhausted: classicExhausted || affirmationExhausted || youOrMeExhausted,
      allExhausted: classicExhausted && affirmationExhausted && youOrMeExhausted,

      unlockedMagnets: magnetProgress.unlockedCount,
      totalQuizzesAvailable: classicAvailable.length + affirmationAvailable.length + youOrMeAvailable.length,
    };

    return NextResponse.json(response);
  } catch (error) {
    console.error('Error fetching quiz availability:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
});

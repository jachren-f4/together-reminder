/**
 * Journal Weekly Insights API Endpoint
 *
 * GET /api/journal/insights?start={date}
 *
 * Returns aggregated insights for a specific week (Monday-Sunday).
 * Calculates:
 * - Total questions explored
 * - Aligned answers count
 * - Days connected
 * - Quest counts by type
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { getCoupleId } from '@/lib/couple/utils';

export const dynamic = 'force-dynamic';

interface WeeklyInsights {
  totalQuestions: number;
  alignedAnswers: number;
  daysConnected: number;
  possibleDays: number;
  dailyQuestsCompleted: number;
  sideQuestsCompleted: number;
  stepsTogetherCompleted: number;
  totalQuestsCompleted: number;
  hasActivity: boolean;
}

/**
 * GET /api/journal/insights
 *
 * Query params:
 * - start: Week start date in ISO format (YYYY-MM-DD), must be a Monday
 *
 * Returns aggregated insights for the week
 */
export const GET = withAuthOrDevBypass(async (req: NextRequest, userId: string) => {
  try {
    const { searchParams } = new URL(req.url);
    const startParam = searchParams.get('start');

    if (!startParam) {
      return NextResponse.json(
        { error: 'Missing start parameter' },
        { status: 400 }
      );
    }

    // Parse and validate date
    const weekStart = new Date(startParam);
    if (isNaN(weekStart.getTime())) {
      return NextResponse.json(
        { error: 'Invalid date format' },
        { status: 400 }
      );
    }

    // Calculate week end (start + 7 days)
    const weekEnd = new Date(weekStart);
    weekEnd.setDate(weekEnd.getDate() + 7);

    // Get couple info
    const coupleId = await getCoupleId(userId);
    if (!coupleId) {
      return NextResponse.json(
        { error: 'Couple not found' },
        { status: 404 }
      );
    }

    // Get couple creation date to calculate possible days
    const coupleResult = await query(
      `SELECT created_at FROM couples WHERE id = $1`,
      [coupleId]
    );
    const coupleCreatedAt = coupleResult.rows[0]?.created_at
      ? new Date(coupleResult.rows[0].created_at)
      : null;

    // Calculate possible days in this week
    let possibleDays = 7;
    if (coupleCreatedAt && coupleCreatedAt > weekStart) {
      // Couple was created mid-week
      const daysFromCreation = Math.ceil(
        (weekEnd.getTime() - coupleCreatedAt.getTime()) / (1000 * 60 * 60 * 24)
      );
      possibleDays = Math.min(7, Math.max(0, daysFromCreation));
    }

    // Track unique days with activity
    const daysWithActivity = new Set<string>();

    // Initialize counters
    let totalQuestions = 0;
    let alignedAnswers = 0;
    let dailyQuestsCompleted = 0;
    let sideQuestsCompleted = 0;
    let stepsTogetherCompleted = 0;

    // 1. Aggregate from quiz matches (classic, affirmation, you_or_me)
    // Note: You or Me now uses quiz_matches table with quiz_type='you_or_me'
    const quizResult = await query(
      `SELECT
        qm.id, qm.quiz_type, qm.completed_at, qm.player1_answers, qm.player2_answers,
        qm.player1_answer_count, qm.player2_answer_count
       FROM quiz_matches qm
       WHERE qm.couple_id = $1
         AND qm.status = 'completed'
         AND qm.quiz_type IN ('classic', 'affirmation', 'you_or_me')
         AND qm.completed_at >= $2
         AND qm.completed_at < $3`,
      [coupleId, weekStart.toISOString(), weekEnd.toISOString()]
    );

    for (const row of quizResult.rows) {
      // Track day
      const dayKey = new Date(row.completed_at).toISOString().slice(0, 10);
      daysWithActivity.add(dayKey);

      // All quiz types are daily quests
      dailyQuestsCompleted++;

      // Parse answers
      const player1Answers = typeof row.player1_answers === 'string'
        ? JSON.parse(row.player1_answers)
        : row.player1_answers || [];
      const player2Answers = typeof row.player2_answers === 'string'
        ? JSON.parse(row.player2_answers)
        : row.player2_answers || [];

      // Count questions
      const questionCount = Math.max(player1Answers.length, player2Answers.length);
      totalQuestions += questionCount;

      // Count aligned answers
      const minLength = Math.min(player1Answers.length, player2Answers.length);
      for (let i = 0; i < minLength; i++) {
        if (player1Answers[i] === player2Answers[i]) {
          alignedAnswers++;
        }
      }
    }

    // NOTE: you_or_me_sessions table is legacy - You or Me now uses quiz_matches with quiz_type='you_or_me'

    // 3. Aggregate from Linked matches (side quest)
    const linkedResult = await query(
      `SELECT completed_at
       FROM linked_matches
       WHERE couple_id = $1
         AND status = 'completed'
         AND completed_at >= $2
         AND completed_at < $3`,
      [coupleId, weekStart.toISOString(), weekEnd.toISOString()]
    );

    for (const row of linkedResult.rows) {
      const dayKey = new Date(row.completed_at).toISOString().slice(0, 10);
      daysWithActivity.add(dayKey);
      sideQuestsCompleted++;
    }

    // 4. Aggregate from Word Search matches (side quest)
    const wordSearchResult = await query(
      `SELECT completed_at
       FROM word_search_matches
       WHERE couple_id = $1
         AND status = 'completed'
         AND completed_at >= $2
         AND completed_at < $3`,
      [coupleId, weekStart.toISOString(), weekEnd.toISOString()]
    );

    for (const row of wordSearchResult.rows) {
      const dayKey = new Date(row.completed_at).toISOString().slice(0, 10);
      daysWithActivity.add(dayKey);
      sideQuestsCompleted++;
    }

    // 5. Aggregate from Steps Together claims (from steps_rewards table)
    const stepsResult = await query(
      `SELECT claimed_at
       FROM steps_rewards
       WHERE couple_id = $1
         AND claimed_at >= $2
         AND claimed_at < $3`,
      [coupleId, weekStart.toISOString(), weekEnd.toISOString()]
    );

    for (const row of stepsResult.rows) {
      const dayKey = new Date(row.claimed_at).toISOString().slice(0, 10);
      daysWithActivity.add(dayKey);
      stepsTogetherCompleted++;
    }

    const daysConnected = daysWithActivity.size;
    const totalQuestsCompleted =
      dailyQuestsCompleted + sideQuestsCompleted + stepsTogetherCompleted;

    const insights: WeeklyInsights = {
      totalQuestions,
      alignedAnswers,
      daysConnected,
      possibleDays,
      dailyQuestsCompleted,
      sideQuestsCompleted,
      stepsTogetherCompleted,
      totalQuestsCompleted,
      hasActivity: totalQuestsCompleted > 0,
    };

    return NextResponse.json({
      success: true,
      weekStart: weekStart.toISOString(),
      weekEnd: weekEnd.toISOString(),
      insights,
    });
  } catch (error) {
    console.error('Error fetching journal insights:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
});

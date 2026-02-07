/**
 * Journal Week API Endpoint
 *
 * GET /api/journal/week?start={date}
 *
 * Returns all completed entries for a specific week (Monday-Sunday).
 * Combines data from:
 * - quiz_sessions (completed quizzes)
 * - you_or_me_sessions (completed You or Me games)
 * - linked_matches (completed Linked games)
 * - word_search_matches (completed Word Search games)
 * - steps_together_claims (completed Steps Together)
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { getCoupleBasic } from '@/lib/couple/utils';

export const dynamic = 'force-dynamic';

// Entry types matching Flutter JournalEntryType enum
type JournalEntryType =
  | 'classicQuiz'
  | 'affirmationQuiz'
  | 'welcomeQuiz'
  | 'youOrMe'
  | 'linked'
  | 'wordSearch'
  | 'stepsTogether';

interface JournalEntry {
  entryId: string;
  type: JournalEntryType;
  title: string;
  completedAt: string;
  contentId: string;
  // Quiz fields
  alignedCount?: number;
  differentCount?: number;
  // Game fields
  userScore?: number;
  partnerScore?: number;
  totalTurns?: number;
  userHintsUsed?: number;
  partnerHintsUsed?: number;
  // Word Search specific
  userPoints?: number;
  partnerPoints?: number;
  // Steps Together specific
  combinedSteps?: number;
  stepGoal?: number;
  // Winner
  winnerId?: string | null;
}

/**
 * GET /api/journal/week
 *
 * Query params:
 * - start: Week start date in ISO format (YYYY-MM-DD), must be a Monday
 *
 * Returns entries sorted by completedAt descending
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
    const couple = await getCoupleBasic(userId);
    if (!couple) {
      return NextResponse.json(
        { error: 'Couple not found' },
        { status: 404 }
      );
    }

    const { coupleId, isPlayer1 } = couple;
    const entries: JournalEntry[] = [];

    // 1. Fetch completed quiz matches (classic, affirmation, and you_or_me)
    // Note: Uses quiz_matches table which stores completed game data for all quiz types
    const quizResult = await query(
      `SELECT
        qm.id, qm.quiz_type, qm.branch, qm.quiz_id, qm.completed_at, qm.status,
        qm.player1_answers, qm.player2_answers, qm.match_percentage,
        qm.player1_score, qm.player2_score
       FROM quiz_matches qm
       WHERE qm.couple_id = $1
         AND qm.status = 'completed'
         AND qm.quiz_type IN ('classic', 'affirmation', 'you_or_me')
         AND qm.completed_at >= $2
         AND qm.completed_at < $3
       ORDER BY qm.completed_at DESC`,
      [coupleId, weekStart.toISOString(), weekEnd.toISOString()]
    );

    for (const row of quizResult.rows) {
      // Parse answers to calculate alignment
      const player1Answers = typeof row.player1_answers === 'string'
        ? JSON.parse(row.player1_answers)
        : row.player1_answers || [];
      const player2Answers = typeof row.player2_answers === 'string'
        ? JSON.parse(row.player2_answers)
        : row.player2_answers || [];

      // Count aligned vs different
      let alignedCount = 0;
      let differentCount = 0;
      const minLength = Math.min(player1Answers.length, player2Answers.length);
      for (let i = 0; i < minLength; i++) {
        if (player1Answers[i] === player2Answers[i]) {
          alignedCount++;
        } else {
          differentCount++;
        }
      }

      // Determine entry type from quiz_type
      let entryType: JournalEntryType = 'classicQuiz';
      if (row.quiz_type === 'affirmation') {
        entryType = 'affirmationQuiz';
      } else if (row.quiz_type === 'you_or_me') {
        entryType = 'youOrMe';
      }

      // Get quiz name from branch
      const branchNames: Record<string, string> = {
        // Classic quiz branches
        'lighthearted': 'Lighthearted Quiz',
        'playful': 'Playful Quiz',
        'deep': 'Deep Dive Quiz',
        // Affirmation quiz branches
        'connection': 'Connection Quiz',
        'attachment': 'Attachment Quiz',
        'growth': 'Growth Quiz',
        'emotional': 'Emotional Connection',
        'physical': 'Physical Connection',
      };
      // For you_or_me, use "You or Me" as title
      const title = row.quiz_type === 'you_or_me'
        ? 'You or Me'
        : (branchNames[row.branch] || 'Quiz');

      entries.push({
        entryId: row.quiz_type === 'you_or_me' ? `yom_${row.id}` : `quiz_${row.id}`,
        type: entryType,
        title,
        completedAt: row.completed_at,
        contentId: row.id,
        alignedCount,
        differentCount,
      });
    }

    // NOTE: you_or_me_sessions table is legacy - You or Me now uses quiz_matches with quiz_type='you_or_me'

    // 3. Fetch completed Linked matches
    const linkedResult = await query(
      `SELECT
        id, puzzle_id, player1_score, player2_score, turn_number,
        player1_vision, player2_vision, winner_id, completed_at,
        player1_id, player2_id
       FROM linked_matches
       WHERE couple_id = $1
         AND status = 'completed'
         AND completed_at >= $2
         AND completed_at < $3
       ORDER BY completed_at DESC`,
      [coupleId, weekStart.toISOString(), weekEnd.toISOString()]
    );

    for (const row of linkedResult.rows) {
      // Calculate hints used (starting vision is 2, each hint reduces by 1)
      const player1HintsUsed = 2 - (row.player1_vision ?? 2);
      const player2HintsUsed = 2 - (row.player2_vision ?? 2);

      entries.push({
        entryId: `linked_${row.id}`,
        type: 'linked',
        title: 'Crossword',
        completedAt: row.completed_at,
        contentId: row.id,
        userScore: isPlayer1 ? row.player1_score : row.player2_score,
        partnerScore: isPlayer1 ? row.player2_score : row.player1_score,
        totalTurns: row.turn_number,
        userHintsUsed: isPlayer1 ? player1HintsUsed : player2HintsUsed,
        partnerHintsUsed: isPlayer1 ? player2HintsUsed : player1HintsUsed,
        winnerId: row.winner_id,
      });
    }

    // 4. Fetch completed Word Search matches
    const wordSearchResult = await query(
      `SELECT
        id, puzzle_id, player1_words_found, player2_words_found,
        player1_score, player2_score, player1_hints, player2_hints,
        turn_number, winner_id, completed_at,
        player1_id, player2_id
       FROM word_search_matches
       WHERE couple_id = $1
         AND status = 'completed'
         AND completed_at >= $2
         AND completed_at < $3
       ORDER BY completed_at DESC`,
      [coupleId, weekStart.toISOString(), weekEnd.toISOString()]
    );

    for (const row of wordSearchResult.rows) {
      // Calculate hints used (starting hints is 3)
      const player1HintsUsed = 3 - (row.player1_hints ?? 3);
      const player2HintsUsed = 3 - (row.player2_hints ?? 3);

      entries.push({
        entryId: `ws_${row.id}`,
        type: 'wordSearch',
        title: 'Word Search',
        completedAt: row.completed_at,
        contentId: row.id,
        userScore: isPlayer1 ? row.player1_words_found : row.player2_words_found,
        partnerScore: isPlayer1 ? row.player2_words_found : row.player1_words_found,
        userPoints: isPlayer1 ? row.player1_score : row.player2_score,
        partnerPoints: isPlayer1 ? row.player2_score : row.player1_score,
        totalTurns: row.turn_number,
        userHintsUsed: isPlayer1 ? player1HintsUsed : player2HintsUsed,
        partnerHintsUsed: isPlayer1 ? player2HintsUsed : player1HintsUsed,
        winnerId: row.winner_id,
      });
    }

    // 5. Fetch Steps Together claims (from steps_rewards table)
    const stepsResult = await query(
      `SELECT
        id, combined_steps, lp_earned, claimed_at
       FROM steps_rewards
       WHERE couple_id = $1
         AND claimed_at >= $2
         AND claimed_at < $3
       ORDER BY claimed_at DESC`,
      [coupleId, weekStart.toISOString(), weekEnd.toISOString()]
    );

    for (const row of stepsResult.rows) {
      entries.push({
        entryId: `steps_${row.id}`,
        type: 'stepsTogether',
        title: 'Steps Together',
        completedAt: row.claimed_at,
        contentId: row.id,
        combinedSteps: row.combined_steps,
        stepGoal: row.lp_earned > 0 ? 10000 : 0, // Threshold is 10K steps
      });
    }

    // Sort all entries by completedAt descending
    entries.sort((a, b) =>
      new Date(b.completedAt).getTime() - new Date(a.completedAt).getTime()
    );

    return NextResponse.json({
      success: true,
      weekStart: weekStart.toISOString(),
      weekEnd: weekEnd.toISOString(),
      entries,
    });
  } catch (error) {
    console.error('Error fetching journal week:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
});

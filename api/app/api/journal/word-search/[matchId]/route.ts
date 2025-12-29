/**
 * Journal Word Search Details API Endpoint
 *
 * GET /api/journal/word-search/[matchId]
 *
 * Returns detailed information about a completed Word Search game.
 * Used in the journal detail bottom sheet.
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { getCoupleBasic } from '@/lib/couple/utils';

export const dynamic = 'force-dynamic';

interface FoundWord {
  word: string;
  foundBy: string; // user ID who found it
  foundByName: string; // 'You' or partner name
  points: number;
}

interface WordSearchDetails {
  matchId: string;
  puzzleId: string;
  completedAt: string;
  userWordsFound: number;
  partnerWordsFound: number;
  userScore: number;
  partnerScore: number;
  totalTurns: number;
  userHintsUsed: number;
  partnerHintsUsed: number;
  winnerId: string | null;
  isTie: boolean;
  words: FoundWord[];
}

/**
 * GET /api/journal/word-search/[matchId]
 *
 * Returns detailed information about a Word Search game
 */
export const GET = withAuthOrDevBypass(async (req: NextRequest, userId: string, email?: string, context?: any) => {
  try {
    const resolvedParams = context?.params ? (await context.params) : null;
    const matchId = resolvedParams?.matchId;

    if (!matchId) {
      return NextResponse.json(
        { error: 'Match ID required' },
        { status: 400 }
      );
    }

    // Get couple info
    const couple = await getCoupleBasic(userId);
    if (!couple) {
      return NextResponse.json(
        { error: 'Couple not found' },
        { status: 404 }
      );
    }

    const { coupleId, partnerId, isPlayer1 } = couple;

    // Get match details
    const matchResult = await query(
      `SELECT
        id, puzzle_id, status, found_words,
        player1_words_found, player2_words_found,
        player1_score, player2_score, turn_number,
        player1_hints, player2_hints, winner_id,
        player1_id, player2_id, completed_at
       FROM word_search_matches
       WHERE id = $1 AND couple_id = $2`,
      [matchId, coupleId]
    );

    if (matchResult.rows.length === 0) {
      return NextResponse.json(
        { error: 'Match not found' },
        { status: 404 }
      );
    }

    const match = matchResult.rows[0];

    if (match.status !== 'completed') {
      return NextResponse.json(
        { error: 'Match not completed' },
        { status: 400 }
      );
    }

    // Parse found words
    const foundWordsData = typeof match.found_words === 'string'
      ? JSON.parse(match.found_words)
      : match.found_words || [];

    const userWordsFound = isPlayer1 ? match.player1_words_found : match.player2_words_found;
    const partnerWordsFound = isPlayer1 ? match.player2_words_found : match.player1_words_found;
    const userScore = isPlayer1 ? (match.player1_score || 0) : (match.player2_score || 0);
    const partnerScore = isPlayer1 ? (match.player2_score || 0) : (match.player1_score || 0);
    const player1HintsUsed = 3 - (match.player1_hints ?? 3);
    const player2HintsUsed = 3 - (match.player2_hints ?? 3);
    const userHintsUsed = isPlayer1 ? player1HintsUsed : player2HintsUsed;
    const partnerHintsUsed = isPlayer1 ? player2HintsUsed : player1HintsUsed;

    const isTie = userScore === partnerScore;

    // Transform found words for response
    const words: FoundWord[] = foundWordsData.map((fw: any) => ({
      word: fw.word || '',
      foundBy: fw.foundBy || '',
      foundByName: fw.foundBy === userId ? 'You' : 'Partner',
      points: fw.points || 0,
    }));

    const details: WordSearchDetails = {
      matchId: match.id,
      puzzleId: match.puzzle_id,
      completedAt: match.completed_at,
      userWordsFound,
      partnerWordsFound,
      userScore,
      partnerScore,
      totalTurns: match.turn_number,
      userHintsUsed,
      partnerHintsUsed,
      winnerId: match.winner_id,
      isTie,
      words,
    };

    return NextResponse.json({
      success: true,
      details,
    });
  } catch (error) {
    console.error('Error fetching word search details:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
});

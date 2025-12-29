/**
 * Journal Linked Details API Endpoint
 *
 * GET /api/journal/linked/[matchId]
 *
 * Returns detailed information about a completed Linked game.
 * Used in the journal detail bottom sheet.
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { getCoupleBasic } from '@/lib/couple/utils';

export const dynamic = 'force-dynamic';

interface CompletedWord {
  word: string;
  foundBy: string; // user ID who found it
  foundByName: string; // 'You' or partner name
}

interface LinkedDetails {
  matchId: string;
  puzzleId: string;
  completedAt: string;
  userScore: number;
  partnerScore: number;
  totalTurns: number;
  userHintsUsed: number;
  partnerHintsUsed: number;
  winnerId: string | null;
  isTie: boolean;
  words: CompletedWord[];
}

/**
 * GET /api/journal/linked/[matchId]
 *
 * Returns detailed information about a Linked game
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
        id, puzzle_id, status, board_state,
        player1_score, player2_score, turn_number,
        player1_vision, player2_vision, winner_id,
        player1_id, player2_id, completed_at
       FROM linked_matches
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

    // Parse board state to extract words found by each player
    const boardState = typeof match.board_state === 'string'
      ? JSON.parse(match.board_state)
      : match.board_state || {};

    // boardState.cells contains objects like { value: 'A', lockedBy: 'userId' }
    // We need to reconstruct which words were found by whom
    // For now, return simplified data

    const userScore = isPlayer1 ? match.player1_score : match.player2_score;
    const partnerScore = isPlayer1 ? match.player2_score : match.player1_score;
    const player1HintsUsed = 2 - (match.player1_vision ?? 2);
    const player2HintsUsed = 2 - (match.player2_vision ?? 2);
    const userHintsUsed = isPlayer1 ? player1HintsUsed : player2HintsUsed;
    const partnerHintsUsed = isPlayer1 ? player2HintsUsed : player1HintsUsed;

    const isTie = userScore === partnerScore;

    // Extract words from board state if available
    const words: CompletedWord[] = [];

    // boardState may contain a wordsFound array or we need to reconstruct from cells
    if (boardState.wordsFound && Array.isArray(boardState.wordsFound)) {
      for (const wordInfo of boardState.wordsFound) {
        words.push({
          word: wordInfo.word || '',
          foundBy: wordInfo.foundBy || '',
          foundByName: wordInfo.foundBy === userId ? 'You' : 'Partner',
        });
      }
    }

    const details: LinkedDetails = {
      matchId: match.id,
      puzzleId: match.puzzle_id,
      completedAt: match.completed_at,
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
    console.error('Error fetching linked details:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
});

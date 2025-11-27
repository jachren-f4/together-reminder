/**
 * Word Search Game Match Polling API
 *
 * GET /api/sync/word-search/[matchId] - Poll specific match state
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { readFileSync } from 'fs';
import { join } from 'path';

export const dynamic = 'force-dynamic';

// Load puzzle data
function loadPuzzle(puzzleId: string): any {
  try {
    const puzzlePath = join(process.cwd(), 'data', 'puzzles', 'word-search', `${puzzleId}.json`);
    const puzzleData = readFileSync(puzzlePath, 'utf-8');
    return JSON.parse(puzzleData);
  } catch (error) {
    console.error(`Failed to load word search puzzle ${puzzleId}:`, error);
    return null;
  }
}

// Get puzzle data for client (without word positions)
function getPuzzleForClient(puzzle: any): any {
  const words = Object.keys(puzzle.words);

  return {
    puzzleId: puzzle.puzzleId,
    title: puzzle.title,
    theme: puzzle.theme,
    size: puzzle.size,
    grid: puzzle.grid,
    words: words,
  };
}

/**
 * GET /api/sync/word-search/[matchId]
 *
 * Poll specific match state (used during partner's turn)
 */
export const GET = withAuthOrDevBypass(async (req, userId, email, params) => {
  try {
    const matchId = params?.matchId;

    if (!matchId) {
      return NextResponse.json(
        { error: 'Match ID required' },
        { status: 400 }
      );
    }

    // Get couple info
    const coupleResult = await query(
      `SELECT id, user1_id, user2_id FROM couples WHERE user1_id = $1 OR user2_id = $1 LIMIT 1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json(
        { error: 'No couple found for user' },
        { status: 404 }
      );
    }

    const { id: coupleId, user1_id, user2_id } = coupleResult.rows[0];

    // Get match
    const result = await query(
      `SELECT * FROM word_search_matches WHERE id = $1 AND couple_id = $2`,
      [matchId, coupleId]
    );

    if (result.rows.length === 0) {
      return NextResponse.json(
        { error: 'Match not found', code: 'NO_MATCH' },
        { status: 404 }
      );
    }

    const match = result.rows[0];
    const isPlayer1 = userId === user1_id;
    const isMyTurn = match.current_turn_user_id === userId;
    const foundWords = typeof match.found_words === 'string'
      ? JSON.parse(match.found_words)
      : match.found_words || [];

    // Load puzzle for client
    const puzzle = loadPuzzle(match.puzzle_id);

    return NextResponse.json({
      success: true,
      match: {
        matchId: match.id,
        puzzleId: match.puzzle_id,
        status: match.status,
        foundWords,
        currentTurnUserId: match.current_turn_user_id,
        turnNumber: match.turn_number,
        wordsFoundThisTurn: match.words_found_this_turn,
        player1WordsFound: match.player1_words_found,
        player2WordsFound: match.player2_words_found,
        player1Hints: match.player1_hints,
        player2Hints: match.player2_hints,
        player1Id: match.player1_id,
        player2Id: match.player2_id,
        winnerId: match.winner_id,
        createdAt: match.created_at,
        completedAt: match.completed_at,
      },
      puzzle: puzzle ? getPuzzleForClient(puzzle) : null,
      gameState: {
        isMyTurn,
        canPlay: isMyTurn && match.status === 'active',
        wordsRemainingThisTurn: 3 - match.words_found_this_turn,
        myWordsFound: isPlayer1 ? match.player1_words_found : match.player2_words_found,
        partnerWordsFound: isPlayer1 ? match.player2_words_found : match.player1_words_found,
        myHints: isPlayer1 ? match.player1_hints : match.player2_hints,
        partnerHints: isPlayer1 ? match.player2_hints : match.player1_hints,
        progressPercent: Math.round((foundWords.length / 12) * 100),
      }
    });
  } catch (error) {
    console.error('Error polling Word Search match:', error);
    return NextResponse.json(
      { error: 'Failed to poll match' },
      { status: 500 }
    );
  }
});

/**
 * Word Search Game Hint API
 *
 * POST /api/sync/word-search/hint - Use a hint to reveal first letter position
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query, getClient } from '@/lib/db/pool';
import { readFileSync } from 'fs';
import { join } from 'path';

export const dynamic = 'force-dynamic';

// Direction deltas for a 10-column grid
const DIRECTION_DELTAS: Record<string, number> = {
  'R': 1, 'L': -1, 'D': 10, 'U': -10,
  'DR': 11, 'DL': 9, 'UR': -9, 'UL': -11
};

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

// Convert flat index to row/col
function indexToPosition(index: number, cols: number = 10): { row: number; col: number } {
  return {
    row: Math.floor(index / cols),
    col: index % cols
  };
}

/**
 * POST /api/sync/word-search/hint
 *
 * Use a hint to reveal the first letter position of a random unfound word
 *
 * Body: {
 *   matchId: string
 * }
 */
export const POST = withAuthOrDevBypass(async (req, userId, email) => {
  const client = await getClient();

  try {
    const body = await req.json();
    const { matchId } = body;

    if (!matchId) {
      return NextResponse.json(
        { error: 'matchId required' },
        { status: 400 }
      );
    }

    await client.query('BEGIN');

    // Get couple info
    const coupleResult = await client.query(
      `SELECT id, user1_id, user2_id FROM couples WHERE user1_id = $1 OR user2_id = $1 LIMIT 1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return NextResponse.json(
        { error: 'No couple found for user' },
        { status: 404 }
      );
    }

    const { id: coupleId, user1_id, user2_id } = coupleResult.rows[0];
    const isPlayer1 = userId === user1_id;

    // Lock match for update
    const matchResult = await client.query(
      `SELECT * FROM word_search_matches WHERE id = $1 AND couple_id = $2 FOR UPDATE`,
      [matchId, coupleId]
    );

    if (matchResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return NextResponse.json(
        { error: 'Match not found' },
        { status: 404 }
      );
    }

    const match = matchResult.rows[0];

    // Validate it's the player's turn
    if (match.current_turn_user_id !== userId) {
      await client.query('ROLLBACK');
      return NextResponse.json(
        { error: 'NOT_YOUR_TURN', message: "It's not your turn" },
        { status: 403 }
      );
    }

    // Validate match is active
    if (match.status !== 'active') {
      await client.query('ROLLBACK');
      return NextResponse.json(
        { error: 'GAME_NOT_ACTIVE', message: 'Game is not active' },
        { status: 400 }
      );
    }

    // Check hints remaining
    const hintsRemaining = isPlayer1 ? match.player1_hints : match.player2_hints;
    if (hintsRemaining <= 0) {
      await client.query('ROLLBACK');
      return NextResponse.json(
        { error: 'NO_HINTS', message: 'No hints remaining' },
        { status: 400 }
      );
    }

    // Load puzzle
    const puzzle = loadPuzzle(match.puzzle_id);
    if (!puzzle) {
      await client.query('ROLLBACK');
      return NextResponse.json(
        { error: 'Puzzle not found' },
        { status: 500 }
      );
    }

    const foundWords = typeof match.found_words === 'string'
      ? JSON.parse(match.found_words)
      : match.found_words || [];

    // Find unfound words
    const foundWordSet = new Set(foundWords.map((fw: any) => fw.word));
    const unfoundWords = Object.keys(puzzle.words).filter(w => !foundWordSet.has(w));

    if (unfoundWords.length === 0) {
      await client.query('ROLLBACK');
      return NextResponse.json(
        { error: 'NO_WORDS_LEFT', message: 'All words already found' },
        { status: 400 }
      );
    }

    // Pick a random unfound word
    const randomWord = unfoundWords[Math.floor(Math.random() * unfoundWords.length)];
    const wordPosition = puzzle.words[randomWord];
    const [startIndexStr] = wordPosition.split(',');
    const startIndex = parseInt(startIndexStr);
    const firstLetterPosition = indexToPosition(startIndex, puzzle.size.cols);

    // Decrement hints
    const newHints = hintsRemaining - 1;
    const updateColumn = isPlayer1 ? 'player1_hints' : 'player2_hints';

    await client.query(
      `UPDATE word_search_matches SET ${updateColumn} = $1 WHERE id = $2`,
      [newHints, matchId]
    );

    await client.query('COMMIT');

    return NextResponse.json({
      success: true,
      hint: {
        word: randomWord,
        firstLetterPosition
      },
      hintsRemaining: newHints
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error using hint:', error);
    return NextResponse.json(
      { error: 'Failed to use hint' },
      { status: 500 }
    );
  } finally {
    client.release();
  }
});

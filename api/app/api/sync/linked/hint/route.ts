/**
 * Linked Game Hint Power-Up API
 *
 * POST /api/sync/linked/hint - Use hint to highlight valid cells
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query, getClient } from '@/lib/db/pool';
import { readFileSync } from 'fs';
import { join } from 'path';

export const dynamic = 'force-dynamic';

// Load puzzle data
function loadPuzzle(puzzleId: string): any {
  try {
    const puzzlePath = join(process.cwd(), 'data', 'puzzles', `${puzzleId}.json`);
    const puzzleData = readFileSync(puzzlePath, 'utf-8');
    return JSON.parse(puzzleData);
  } catch (error) {
    console.error(`Failed to load puzzle ${puzzleId}:`, error);
    return null;
  }
}

// Find valid cells for current rack letters
function findValidCells(
  puzzle: any,
  boardState: Record<string, string>,
  rack: string[]
): number[] {
  const { grid, size } = puzzle;
  const validCells: number[] = [];
  const rackSet = new Set(rack.map(l => l.toUpperCase()));

  for (let i = 0; i < grid.length; i++) {
    const row = Math.floor(i / size.cols);
    const col = i % size.cols;

    // Skip clue frame
    if (row === 0 || col === 0) continue;

    // Skip void cells
    if (grid[i] === '.') continue;

    // Skip already locked cells
    if (boardState[i.toString()]) continue;

    // Check if the solution letter is in the rack
    const solutionLetter = grid[i].toUpperCase();
    if (rackSet.has(solutionLetter)) {
      validCells.push(i);
    }
  }

  return validCells;
}

/**
 * POST /api/sync/linked/hint
 *
 * Use hint power-up to highlight valid cell positions
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
      `SELECT * FROM linked_matches WHERE id = $1 AND couple_id = $2 FOR UPDATE`,
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

    // Check if player has hints remaining
    const currentVision = isPlayer1 ? match.player1_vision : match.player2_vision;
    if (currentVision <= 0) {
      await client.query('ROLLBACK');
      return NextResponse.json(
        { error: 'NO_HINTS_REMAINING', message: 'No hints remaining' },
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

    const currentRack = match.current_rack || [];
    const boardState = typeof match.board_state === 'string'
      ? JSON.parse(match.board_state)
      : match.board_state || {};

    // Find valid cells for current rack
    const validCells = findValidCells(puzzle, boardState, currentRack);

    // Decrement hint count
    const newVision = currentVision - 1;
    const updateField = isPlayer1 ? 'player1_vision' : 'player2_vision';

    await client.query(
      `UPDATE linked_matches SET ${updateField} = $1 WHERE id = $2`,
      [newVision, matchId]
    );

    await client.query('COMMIT');

    return NextResponse.json({
      success: true,
      validCells,
      hintsRemaining: newVision,
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

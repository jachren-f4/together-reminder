/**
 * Linked Game Turn Submission API
 *
 * POST /api/sync/linked/submit - Submit letter placements for validation
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query, getClient } from '@/lib/db/pool';
import { LP_REWARDS, SCORING } from '@/lib/lp/config';
import { recordActivityPlay } from '@/lib/magnets';
import { readFileSync } from 'fs';
import { join } from 'path';

export const dynamic = 'force-dynamic';

// Load puzzle data from branch-specific path (including solution)
function loadPuzzle(puzzleId: string, branch?: string): any {
  try {
    // Use branch path (default to 'casual' if no branch specified)
    const branchFolder = branch || 'casual';
    const puzzlePath = join(process.cwd(), 'data', 'puzzles', 'linked', branchFolder, `${puzzleId}.json`);
    const puzzleData = readFileSync(puzzlePath, 'utf-8');
    return JSON.parse(puzzleData);
  } catch (error) {
    console.error(`Failed to load puzzle ${puzzleId}:`, error);
    return null;
  }
}

// Generate new rack from remaining unfilled cells
function generateRack(puzzle: any, boardState: Record<string, string>, maxSize: number = 5): string[] {
  const { grid, size } = puzzle;
  const available: string[] = [];

  for (let i = 0; i < grid.length; i++) {
    const row = Math.floor(i / size.cols);
    const col = i % size.cols;

    // Skip clue frame
    if (row === 0 || col === 0) continue;

    // Skip void cells
    if (grid[i] === '.') continue;

    // Skip already locked cells
    if (boardState[i.toString()]) continue;

    // Add letter to available pool
    available.push(grid[i].toUpperCase());
  }

  // Shuffle and take up to maxSize
  const shuffled = available.sort(() => Math.random() - 0.5);
  return shuffled.slice(0, Math.min(maxSize, shuffled.length));
}

// Check if a word is completed after placement
interface WordCompletion {
  word: string;
  cells: number[];
  bonus: number;
}

function checkWordCompletions(
  puzzle: any,
  boardState: Record<string, string>,
  newlyLockedCells: number[]
): WordCompletion[] {
  const completedWords: WordCompletion[] = [];
  const { clues, grid, size } = puzzle;

  // Helper to check a single direction
  function checkDirection(targetIndex: number, direction: 'across' | 'down'): WordCompletion | null {
    const wordCells: number[] = [];
    let word = '';
    let allFilled = true;
    let hasNewCell = false;

    let currentIndex = targetIndex;
    const stepSize = direction === 'across' ? 1 : size.cols;

    while (currentIndex < grid.length) {
      const row = Math.floor(currentIndex / size.cols);
      const col = currentIndex % size.cols;

      // Stop if we hit the clue frame or boundary
      if (row === 0 || col === 0) break;

      // Stop if we hit a void cell
      if (grid[currentIndex] === '.') break;

      // For across: stop if we go past the right edge
      if (direction === 'across' && col >= size.cols) break;

      wordCells.push(currentIndex);

      // Check if this cell is filled (locked)
      const lockedLetter = boardState[currentIndex.toString()];
      if (lockedLetter) {
        word += lockedLetter;
        if (newlyLockedCells.includes(currentIndex)) {
          hasNewCell = true;
        }
      } else {
        allFilled = false;
        break;
      }

      // Move to next cell
      currentIndex += stepSize;

      // For across: stop if we wrapped to next row
      if (direction === 'across') {
        const newCol = currentIndex % size.cols;
        if (newCol === 0) break;
      }
    }

    // If all cells are filled and at least one was just placed, it's a completion
    if (allFilled && hasNewCell && word.length > 1) {
      const bonus = word.length * 10;
      return { word, cells: wordCells, bonus };
    }
    return null;
  }

  // For each clue, check if all cells are now filled
  for (const [clueNum, clue] of Object.entries(clues) as [string, any][]) {
    // Check for dual-direction clues (have nested 'across' and/or 'down' objects)
    if (clue.across || clue.down) {
      // Check across direction if present
      if (clue.across && clue.across.target_index !== undefined) {
        const result = checkDirection(clue.across.target_index, 'across');
        if (result) completedWords.push(result);
      }
      // Check down direction if present
      if (clue.down && clue.down.target_index !== undefined) {
        const result = checkDirection(clue.down.target_index, 'down');
        if (result) completedWords.push(result);
      }
    } else if (clue.target_index !== undefined && clue.arrow) {
      // Single-direction clue (legacy format)
      const result = checkDirection(clue.target_index, clue.arrow);
      if (result) completedWords.push(result);
    }
  }

  return completedWords;
}

/**
 * POST /api/sync/linked/submit
 *
 * Submit letter placements for validation
 *
 * Body: {
 *   matchId: string,
 *   placements: Array<{ cellIndex: number, letter: string }>
 * }
 */
export const POST = withAuthOrDevBypass(async (req, userId, email) => {
  const client = await getClient();

  try {
    const body = await req.json();
    const { matchId, placements } = body;

    if (!matchId || !placements || !Array.isArray(placements)) {
      return NextResponse.json(
        { error: 'matchId and placements array required' },
        { status: 400 }
      );
    }

    if (placements.length === 0) {
      return NextResponse.json(
        { error: 'At least one placement required' },
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

    // Load puzzle with solution (use stored branch, fallback to casual for old matches)
    const puzzle = loadPuzzle(match.puzzle_id, match.branch || 'casual');
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

    // Validate placements against rack
    const rackCopy = [...currentRack];
    for (const placement of placements) {
      const letterIndex = rackCopy.indexOf(placement.letter.toUpperCase());
      if (letterIndex === -1) {
        await client.query('ROLLBACK');
        return NextResponse.json(
          { error: 'INVALID_LETTER', message: `Letter ${placement.letter} not in rack` },
          { status: 400 }
        );
      }
      rackCopy.splice(letterIndex, 1);
    }

    // Validate and process placements
    const results: Array<{ cellIndex: number; correct: boolean }> = [];
    const newlyLockedCells: number[] = [];
    let pointsEarned = 0;

    for (const placement of placements) {
      const { cellIndex, letter } = placement;
      const expectedLetter = puzzle.grid[cellIndex]?.toUpperCase();

      // Check if cell is already locked
      if (boardState[cellIndex.toString()]) {
        results.push({ cellIndex, correct: false });
        continue;
      }

      // Check if letter is correct
      const isCorrect = letter.toUpperCase() === expectedLetter;
      results.push({ cellIndex, correct: isCorrect });

      if (isCorrect) {
        // Lock the cell
        boardState[cellIndex.toString()] = letter.toUpperCase();
        newlyLockedCells.push(cellIndex);
        pointsEarned += SCORING.LINKED_POINTS_PER_LETTER;
      }
    }

    // Check for word completions
    const completedWords = checkWordCompletions(puzzle, boardState, newlyLockedCells);

    // Add word bonuses
    for (const word of completedWords) {
      pointsEarned += word.bonus;
    }

    // Update scores
    const newLockedCount = Object.keys(boardState).length;
    const newPlayer1Score = isPlayer1
      ? (match.player1_score || 0) + pointsEarned
      : match.player1_score || 0;
    const newPlayer2Score = !isPlayer1
      ? (match.player2_score || 0) + pointsEarned
      : match.player2_score || 0;

    // Check if game is complete
    const gameComplete = newLockedCount >= match.total_answer_cells;

    // Determine winner if game complete
    let winnerId = null;
    let nextBranch = null;
    let lpEarned = 0;
    if (gameComplete) {
      if (newPlayer1Score > newPlayer2Score) {
        winnerId = user1_id;
      } else if (newPlayer2Score > newPlayer1Score) {
        winnerId = user2_id;
      }
      // If tied, winnerId stays null

      // Award LP directly (no daily gating - cooldowns handle frequency)
      lpEarned = LP_REWARDS.LINKED;
      await client.query(
        `UPDATE couples SET total_lp = COALESCE(total_lp, 0) + $1 WHERE id = $2`,
        [lpEarned, coupleId]
      );

      // Record LP transaction for audit trail
      await client.query(
        `INSERT INTO love_point_transactions (user_id, amount, source, description, created_at)
         VALUES ($1, $2, $3, $4, NOW()), ($5, $2, $3, $4, NOW())`,
        [user1_id, lpEarned, 'linked_complete', `linked_complete (${matchId})`, user2_id]
      );
      console.log(`🎯 Linked LP Award: awarded=${lpEarned}`);

      // Advance branch progression for Linked activity
      // This makes the next puzzle come from the next branch (casual -> romantic -> adult -> casual)
      const branchResult = await client.query(
        `INSERT INTO branch_progression (couple_id, activity_type, current_branch, total_completions, max_branches)
         VALUES ($1, 'linked', 0, 1, 3)
         ON CONFLICT (couple_id, activity_type)
         DO UPDATE SET
           total_completions = branch_progression.total_completions + 1,
           current_branch = (branch_progression.total_completions + 1) % branch_progression.max_branches,
           last_completed_at = NOW(),
           updated_at = NOW()
         RETURNING current_branch`,
        [coupleId]
      );
      nextBranch = branchResult.rows[0]?.current_branch ?? 0;

      // Record activity play for cooldown tracking (Magnet Collection System)
      // Pass client to avoid connection pool deadlock
      await recordActivityPlay(coupleId, 'linked', client);
    }

    // Generate new rack and switch turns
    const nextPlayerId = userId === user1_id ? user2_id : user1_id;
    const nextRack = gameComplete ? [] : generateRack(puzzle, boardState);

    // Update match
    await client.query(
      `UPDATE linked_matches SET
        board_state = $1,
        current_rack = $2,
        current_turn_user_id = $3,
        turn_number = turn_number + 1,
        player1_score = $4,
        player2_score = $5,
        locked_cell_count = $6,
        status = $7,
        winner_id = $8,
        completed_at = $9
      WHERE id = $10`,
      [
        JSON.stringify(boardState),
        nextRack,
        nextPlayerId,
        newPlayer1Score,
        newPlayer2Score,
        newLockedCount,
        gameComplete ? 'completed' : 'active',
        winnerId,
        gameComplete ? new Date() : null,
        matchId,
      ]
    );

    // Record move in audit table
    await client.query(
      `INSERT INTO linked_moves (match_id, player_id, placements, points_earned, words_completed, turn_number)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [
        matchId,
        userId,
        JSON.stringify(placements),
        pointsEarned,
        JSON.stringify(completedWords),
        match.turn_number,
      ]
    );

    await client.query('COMMIT');

    return NextResponse.json({
      success: true,
      results,
      pointsEarned,
      completedWords,
      newScore: isPlayer1 ? newPlayer1Score : newPlayer2Score,
      gameComplete,
      nextRack: gameComplete ? null : nextRack,
      winnerId,
      newLockedCount,
      nextBranch: gameComplete ? nextBranch : null,  // Branch for next puzzle (0=casual, 1=romantic, 2=adult)
      // LP awarded (no daily gating - cooldowns handle frequency)
      lpEarned,
      alreadyGrantedToday: false,
      canPlayMore: true,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error submitting turn:', error);
    return NextResponse.json(
      { error: 'Failed to submit turn' },
      { status: 500 }
    );
  } finally {
    client.release();
  }
});

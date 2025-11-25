/**
 * Linked Game API Endpoint
 *
 * Server-side match creation and retrieval for arroword puzzle game
 * POST: Create or return existing active match
 * GET: Get current match state
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

// Load puzzle order config
function loadPuzzleOrder(): string[] {
  try {
    const orderPath = join(process.cwd(), 'data', 'puzzles', 'puzzle-order.json');
    const orderData = readFileSync(orderPath, 'utf-8');
    const config = JSON.parse(orderData);
    return config.puzzles || [];
  } catch (error) {
    console.error('Failed to load puzzle order:', error);
    // Fallback to default
    return ['arroword_001'];
  }
}

// Get next puzzle for couple (finds first uncompleted puzzle in order)
async function getNextPuzzleForCouple(coupleId: string): Promise<{ puzzleId: string | null; activeMatch: any | null }> {
  const puzzleOrder = loadPuzzleOrder();

  // Check for any active match first
  const activeResult = await query(
    `SELECT * FROM linked_matches WHERE couple_id = $1 AND status = 'active' ORDER BY created_at DESC LIMIT 1`,
    [coupleId]
  );

  if (activeResult.rows.length > 0) {
    return { puzzleId: activeResult.rows[0].puzzle_id, activeMatch: activeResult.rows[0] };
  }

  // Get all completed puzzles for this couple
  const completedResult = await query(
    `SELECT DISTINCT puzzle_id FROM linked_matches WHERE couple_id = $1 AND status = 'completed'`,
    [coupleId]
  );

  const completedPuzzles = new Set(completedResult.rows.map(r => r.puzzle_id));

  // Find first uncompleted puzzle
  for (const puzzleId of puzzleOrder) {
    if (!completedPuzzles.has(puzzleId)) {
      return { puzzleId, activeMatch: null };
    }
  }

  // All puzzles completed
  return { puzzleId: null, activeMatch: null };
}

// Calculate total answer cells from puzzle
function countAnswerCells(puzzle: any): number {
  const { grid, gridnums } = puzzle;
  let count = 0;

  for (let i = 0; i < grid.length; i++) {
    // Answer cells are non-void cells that are not in row 0 or col 0 (clue frame)
    const row = Math.floor(i / puzzle.size.cols);
    const col = i % puzzle.size.cols;

    // Skip clue frame (row 0 and col 0)
    if (row === 0 || col === 0) continue;

    // Skip void cells
    if (grid[i] === '.') continue;

    // This is an answer cell
    count++;
  }

  return count;
}

// Generate rack from remaining unfilled cells
function generateRack(puzzle: any, boardState: Record<string, string>, maxSize: number = 5): string[] {
  const { grid, gridnums, size } = puzzle;
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

// Transform clues for client (convert image filenames to full URLs)
function transformCluesForClient(clues: any, puzzleId: string, baseUrl: string): any {
  const transformed: any = {};

  for (const [key, clue] of Object.entries(clues)) {
    const clueData = clue as any;
    transformed[key] = { ...clueData };

    // Transform image clue content from filename to full URL
    if (clueData.type === 'image' && clueData.content) {
      transformed[key].content = `${baseUrl}/api/puzzles/images/${puzzleId}/${clueData.content}`;
    }
  }

  return transformed;
}

// Get puzzle data without solution (for client)
// Includes cellTypes array to tell client which cells are void/clue/answer
function getPuzzleForClient(puzzle: any, baseUrl: string = ''): any {
  const { grid, gridnums, size, clues } = puzzle;
  const cellTypes: string[] = [];

  for (let i = 0; i < grid.length; i++) {
    const row = Math.floor(i / size.cols);
    const col = i % size.cols;

    // Check if it's a clue cell (has clue number AND matching clue data)
    const clueNum = gridnums[i];
    if (clueNum > 0 && clues[clueNum.toString()]) {
      cellTypes.push('clue');
    }
    // Void cells: '.' in grid and not a clue cell
    else if (grid[i] === '.') {
      cellTypes.push('void');
    }
    // Answer cells: has a letter (not '.')
    else {
      cellTypes.push('answer');
    }
  }

  return {
    puzzleId: puzzle.puzzleId,
    title: puzzle.title,
    author: puzzle.author,
    size: puzzle.size,
    clues: transformCluesForClient(clues, puzzle.puzzleId, baseUrl),
    gridnums: puzzle.gridnums,
    cellTypes: cellTypes,
    // NOTE: grid (solution) is NOT sent to client
  };
}

/**
 * POST /api/sync/linked
 *
 * Creates a new match if none exists, or returns existing active match.
 */
export const POST = withAuthOrDevBypass(async (req, userId, email) => {
  try {
    // Extract base URL for image paths
    const baseUrl = new URL(req.url).origin;

    // Get couple info
    const coupleResult = await query(
      `SELECT id, user1_id, user2_id, first_player_id FROM couples WHERE user1_id = $1 OR user2_id = $1 LIMIT 1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json(
        { error: 'No couple found for user' },
        { status: 404 }
      );
    }

    const { id: coupleId, user1_id, user2_id, first_player_id } = coupleResult.rows[0];

    // Get next puzzle for this couple (active match or first uncompleted)
    const { puzzleId, activeMatch } = await getNextPuzzleForCouple(coupleId);

    if (!puzzleId) {
      return NextResponse.json(
        { error: 'All puzzles completed', code: 'ALL_COMPLETED' },
        { status: 404 }
      );
    }

    const puzzle = loadPuzzle(puzzleId);

    if (!puzzle) {
      return NextResponse.json(
        { error: 'Puzzle not found' },
        { status: 404 }
      );
    }

    let match;
    let isNewMatch = false;

    if (activeMatch) {
      // Return existing active match
      match = activeMatch;
    } else {
      // Create new match
      isNewMatch = true;
      const totalAnswerCells = countAnswerCells(puzzle);

      // Determine first player (use couple preference or default to user2)
      const firstPlayer = first_player_id || user2_id;
      const boardState = {};
      const initialRack = generateRack(puzzle, boardState);

      const insertResult = await query(
        `INSERT INTO linked_matches (
          couple_id, puzzle_id, status, board_state, current_rack,
          current_turn_user_id, turn_number, player1_score, player2_score,
          player1_vision, player2_vision, locked_cell_count, total_answer_cells,
          player1_id, player2_id, created_at
        )
        VALUES ($1, $2, 'active', $3, $4, $5, 1, 0, 0, 2, 2, 0, $6, $7, $8, NOW())
        RETURNING *`,
        [
          coupleId, puzzleId, JSON.stringify(boardState), initialRack,
          firstPlayer, totalAnswerCells, user1_id, user2_id
        ]
      );

      match = insertResult.rows[0];
    }

    // Calculate game state for response
    const isPlayer1 = userId === user1_id;
    const isMyTurn = match.current_turn_user_id === userId;
    const boardState = typeof match.board_state === 'string'
      ? JSON.parse(match.board_state)
      : match.board_state || {};

    // Only include rack if it's the user's turn
    const currentRack = isMyTurn ? (match.current_rack || []) : null;

    return NextResponse.json({
      success: true,
      isNewMatch,
      match: {
        matchId: match.id,
        puzzleId: match.puzzle_id,
        status: match.status,
        boardState,
        currentRack,
        currentTurnUserId: match.current_turn_user_id,
        turnNumber: match.turn_number,
        player1Score: match.player1_score || 0,
        player2Score: match.player2_score || 0,
        player1Vision: match.player1_vision ?? 2,
        player2Vision: match.player2_vision ?? 2,
        lockedCellCount: match.locked_cell_count || 0,
        totalAnswerCells: match.total_answer_cells,
        player1Id: match.player1_id,
        player2Id: match.player2_id,
        createdAt: match.created_at,
        completedAt: match.completed_at,
      },
      puzzle: getPuzzleForClient(puzzle, baseUrl),
      gameState: {
        isMyTurn,
        canPlay: isMyTurn && match.status === 'active',
        myScore: isPlayer1 ? (match.player1_score || 0) : (match.player2_score || 0),
        partnerScore: isPlayer1 ? (match.player2_score || 0) : (match.player1_score || 0),
        myVision: isPlayer1 ? (match.player1_vision ?? 2) : (match.player2_vision ?? 2),
        partnerVision: isPlayer1 ? (match.player2_vision ?? 2) : (match.player1_vision ?? 2),
        progressPercent: match.total_answer_cells > 0
          ? Math.round((match.locked_cell_count / match.total_answer_cells) * 100)
          : 0,
      }
    });
  } catch (error) {
    console.error('Error in Linked API:', error);
    return NextResponse.json(
      { error: 'Failed to get/create match' },
      { status: 500 }
    );
  }
});

/**
 * GET /api/sync/linked
 *
 * Get current active match state
 */
export const GET = withAuthOrDevBypass(async (req, userId, email) => {
  try {
    // Extract base URL for image paths
    const baseUrl = new URL(req.url).origin;

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

    // Get active match
    const result = await query(
      `SELECT * FROM linked_matches WHERE couple_id = $1 AND status = 'active' ORDER BY created_at DESC LIMIT 1`,
      [coupleId]
    );

    if (result.rows.length === 0) {
      return NextResponse.json(
        { error: 'No active match found', code: 'NO_MATCH' },
        { status: 404 }
      );
    }

    const match = result.rows[0];
    const isPlayer1 = userId === user1_id;
    const isMyTurn = match.current_turn_user_id === userId;
    const boardState = typeof match.board_state === 'string'
      ? JSON.parse(match.board_state)
      : match.board_state || {};

    // Load puzzle for client
    const puzzle = loadPuzzle(match.puzzle_id);

    return NextResponse.json({
      success: true,
      match: {
        matchId: match.id,
        puzzleId: match.puzzle_id,
        status: match.status,
        boardState,
        currentRack: isMyTurn ? (match.current_rack || []) : null,
        currentTurnUserId: match.current_turn_user_id,
        turnNumber: match.turn_number,
        player1Score: match.player1_score || 0,
        player2Score: match.player2_score || 0,
        player1Vision: match.player1_vision ?? 2,
        player2Vision: match.player2_vision ?? 2,
        lockedCellCount: match.locked_cell_count || 0,
        totalAnswerCells: match.total_answer_cells,
        player1Id: match.player1_id,
        player2Id: match.player2_id,
        createdAt: match.created_at,
        completedAt: match.completed_at,
      },
      puzzle: puzzle ? getPuzzleForClient(puzzle, baseUrl) : null,
      gameState: {
        isMyTurn,
        canPlay: isMyTurn && match.status === 'active',
        myScore: isPlayer1 ? (match.player1_score || 0) : (match.player2_score || 0),
        partnerScore: isPlayer1 ? (match.player2_score || 0) : (match.player1_score || 0),
        myVision: isPlayer1 ? (match.player1_vision ?? 2) : (match.player2_vision ?? 2),
        partnerVision: isPlayer1 ? (match.player2_vision ?? 2) : (match.player1_vision ?? 2),
        progressPercent: match.total_answer_cells > 0
          ? Math.round((match.locked_cell_count / match.total_answer_cells) * 100)
          : 0,
      }
    });
  } catch (error) {
    console.error('Error getting Linked match:', error);
    return NextResponse.json(
      { error: 'Failed to get match' },
      { status: 500 }
    );
  }
});

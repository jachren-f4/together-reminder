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
import { getCooldownStatus, COOLDOWN_HOURS } from '@/lib/magnets/cooldowns';

export const dynamic = 'force-dynamic';

// Load puzzle data from branch-specific path
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

// Load puzzle order config from branch-specific path
// If gridProgression is true, use puzzle-order-v2.json (5x7 -> 6x8 -> 7x9 progression)
// Otherwise use puzzle-order.json (original 7x9 puzzles first)
function loadPuzzleOrder(branch?: string, gridProgression: boolean = false): string[] {
  try {
    // Use branch path (default to 'casual' if no branch specified)
    const branchFolder = branch || 'casual';

    // Use v2 order file if client supports grid progression
    const orderFileName = gridProgression ? 'puzzle-order-v2.json' : 'puzzle-order.json';
    const orderPath = join(process.cwd(), 'data', 'puzzles', 'linked', branchFolder, orderFileName);

    const orderData = readFileSync(orderPath, 'utf-8');
    const config = JSON.parse(orderData);
    return config.puzzles || [];
  } catch (error) {
    // If v2 file doesn't exist, fall back to original
    if (gridProgression) {
      console.log(`puzzle-order-v2.json not found for branch ${branch}, falling back to puzzle-order.json`);
      return loadPuzzleOrder(branch, false);
    }
    console.error('Failed to load puzzle order:', error);
    // Fallback to default
    return ['puzzle_001'];
  }
}

// Get current branch for couple based on completion count
async function getCurrentBranch(coupleId: string): Promise<string> {
  // Check for branch_progression record
  const result = await query(
    `SELECT current_branch, total_completions, max_branches
     FROM branch_progression
     WHERE couple_id = $1 AND activity_type = 'linked'`,
    [coupleId]
  );

  if (result.rows.length === 0) {
    // No progression record, default to first branch (casual)
    return 'casual';
  }

  const { current_branch } = result.rows[0];
  return getBranchFolderName('linked', current_branch);
}

// Map activity type and branch index to folder name
function getBranchFolderName(activityType: string, branchIndex: number): string {
  const branchNames: Record<string, string[]> = {
    linked: ['casual', 'romantic', 'adult'],
    wordSearch: ['everyday', 'passionate', 'naughty'],
  };

  const folders = branchNames[activityType] || ['default'];
  return folders[branchIndex % folders.length];
}

// Get next puzzle for couple (finds first uncompleted puzzle in order for current branch)
async function getNextPuzzleForCouple(coupleId: string, gridProgression: boolean = false): Promise<{ puzzleId: string | null; activeMatch: any | null; branch: string }> {
  // Get current branch for this couple
  const branch = await getCurrentBranch(coupleId);

  // Load puzzle order for this branch (use v2 if client supports grid progression)
  const puzzleOrder = loadPuzzleOrder(branch, gridProgression);

  // Check for any active match first
  const activeResult = await query(
    `SELECT * FROM linked_matches WHERE couple_id = $1 AND status = 'active' ORDER BY created_at DESC LIMIT 1`,
    [coupleId]
  );

  if (activeResult.rows.length > 0) {
    return { puzzleId: activeResult.rows[0].puzzle_id, activeMatch: activeResult.rows[0], branch };
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
      return { puzzleId, activeMatch: null, branch };
    }
  }

  // All puzzles completed
  return { puzzleId: null, activeMatch: null, branch };
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
  const { grid, size, clues } = puzzle;
  const cellTypes: string[] = [];
  const cols = size.cols;

  // Build a set of clue cell indices from target_index values
  // For "across" clue with target_index X, clue cell is at X-1 (left of answer)
  // For "down" clue with target_index X, clue cell is at X-cols (above answer)
  const clueCellIndices = new Set<number>();

  // Helper to add clue cell index
  const addClueCellIndex = (targetIndex: number, direction: string) => {
    let clueCellIndex: number;
    if (direction === 'across') {
      clueCellIndex = targetIndex - 1;
    } else if (direction === 'down') {
      clueCellIndex = targetIndex - cols;
    } else {
      return;
    }
    if (clueCellIndex >= 0 && clueCellIndex < grid.length) {
      clueCellIndices.add(clueCellIndex);
    }
  };

  for (const [clueNum, clueData] of Object.entries(clues)) {
    const clue = clueData as any;

    // Check for single-direction format (has 'arrow' key)
    if (clue.arrow !== undefined) {
      const targetIndex = clue.target_index;
      if (targetIndex !== undefined) {
        addClueCellIndex(targetIndex, clue.arrow);
      }
    } else {
      // Dual-direction format (has 'across' and/or 'down' keys)
      if (clue.across?.target_index !== undefined) {
        addClueCellIndex(clue.across.target_index, 'across');
      }
      if (clue.down?.target_index !== undefined) {
        addClueCellIndex(clue.down.target_index, 'down');
      }
    }
  }

  // Now build cellTypes array
  for (let i = 0; i < grid.length; i++) {
    if (clueCellIndices.has(i)) {
      cellTypes.push('clue');
    } else if (grid[i] === '.') {
      cellTypes.push('void');
    } else {
      cellTypes.push('answer');
    }
  }

  return {
    puzzleId: puzzle.puzzleId,
    title: puzzle.title,
    author: puzzle.author,
    size: puzzle.size,
    clues: transformCluesForClient(clues, puzzle.puzzleId, baseUrl),
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

    // Parse request body to check for gridProgression flag
    let gridProgression = false;
    try {
      const body = await req.json();
      gridProgression = body.gridProgression === true;
    } catch {
      // No body or invalid JSON - use default (no grid progression)
    }

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
    // Pass gridProgression flag to use v2 puzzle order if client supports it
    const { puzzleId, activeMatch, branch } = await getNextPuzzleForCouple(coupleId, gridProgression);

    // If no active match, check magnet cooldown (8h cooldown after 2 plays)
    if (!activeMatch) {
      const cooldownStatus = await getCooldownStatus(coupleId, 'linked');
      if (!cooldownStatus.canPlay) {
        // Format remaining time
        const remainingMs = cooldownStatus.cooldownRemainingMs || 0;
        const remainingHours = Math.ceil(remainingMs / (1000 * 60 * 60));
        const message = remainingHours <= 1
          ? 'Next puzzle available in less than an hour'
          : `Next puzzle available in ${remainingHours} hours`;

        return NextResponse.json({
          success: false,
          code: 'COOLDOWN_ACTIVE',
          message,
          cooldownEndsAt: cooldownStatus.cooldownEndsAt?.toISOString() || null,
          cooldownRemainingMs: cooldownStatus.cooldownRemainingMs,
          remainingInBatch: cooldownStatus.remainingInBatch,
        });
      }
    }

    if (!puzzleId) {
      return NextResponse.json(
        { error: 'All puzzles completed', code: 'ALL_COMPLETED' },
        { status: 404 }
      );
    }

    // Load puzzle from branch-specific path (falls back to legacy)
    const puzzle = loadPuzzle(puzzleId, branch);

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
          couple_id, puzzle_id, branch, status, board_state, current_rack,
          current_turn_user_id, turn_number, player1_score, player2_score,
          player1_vision, player2_vision, locked_cell_count, total_answer_cells,
          player1_id, player2_id, created_at
        )
        VALUES ($1, $2, $3, 'active', $4, $5, $6, 1, 0, 0, 2, 2, 0, $7, $8, $9, NOW())
        RETURNING *`,
        [
          coupleId, puzzleId, branch, JSON.stringify(boardState), initialRack,
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

    // Load puzzle for client (use stored branch, fallback to casual for old matches)
    const puzzle = loadPuzzle(match.puzzle_id, match.branch || 'casual');

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

/**
 * Linked Game Handlers
 *
 * Handles all linked game operations:
 * - GET/POST `` (empty) → Session management (create/get active match)
 * - GET `{matchId}` → Specific match state (polling)
 * - POST `submit` → Submit letter placements
 * - POST `hint` → Use hint power-up
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query, getClient } from '@/lib/db/pool';
import { LP_REWARDS, SCORING } from '@/lib/lp/config';
import { readFileSync } from 'fs';
import { join } from 'path';

// Check if cooldown is enabled (defaults to true in production)
const COOLDOWN_ENABLED = process.env.PUZZLE_COOLDOWN_ENABLED !== 'false';

// ============================================================================
// Shared Utility Functions
// ============================================================================

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
function loadPuzzleOrder(branch?: string): string[] {
  try {
    // Use branch path (default to 'casual' if no branch specified)
    const branchFolder = branch || 'casual';
    const orderPath = join(process.cwd(), 'data', 'puzzles', 'linked', branchFolder, 'puzzle-order.json');
    const orderData = readFileSync(orderPath, 'utf-8');
    const config = JSON.parse(orderData);
    return config.puzzles || [];
  } catch (error) {
    console.error('Failed to load puzzle order:', error);
    // Fallback to default
    return ['puzzle_001'];
  }
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

// Check if cooldown is active (last completion was on client's local date)
async function isCooldownActive(coupleId: string, clientLocalDate: string | null): Promise<boolean> {
  if (!COOLDOWN_ENABLED || !clientLocalDate) {
    return false;
  }

  // Get most recent completed match
  const result = await query(
    `SELECT completed_at FROM linked_matches
     WHERE couple_id = $1 AND status = 'completed'
     ORDER BY completed_at DESC LIMIT 1`,
    [coupleId]
  );

  if (result.rows.length === 0) {
    return false; // No completed matches, no cooldown
  }

  const completedAt = new Date(result.rows[0].completed_at);

  // Check if completion was on the same day as client's local date
  // We compare the date strings to avoid timezone issues
  const completedDateStr = completedAt.toISOString().split('T')[0];

  return completedDateStr === clientLocalDate;
}

// Get next puzzle for couple (finds first uncompleted puzzle in order for current branch)
async function getNextPuzzleForCouple(coupleId: string): Promise<{ puzzleId: string | null; activeMatch: any | null; branch: string }> {
  // Get current branch for this couple
  const branch = await getCurrentBranch(coupleId);

  // Load puzzle order for this branch
  const puzzleOrder = loadPuzzleOrder(branch);

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

  for (const [clueNum, clueData] of Object.entries(clues)) {
    const clue = clueData as any;
    const targetIndex = clue.target_index;
    if (targetIndex === undefined) continue;

    let clueCellIndex: number;
    if (clue.arrow === 'across') {
      clueCellIndex = targetIndex - 1;
    } else if (clue.arrow === 'down') {
      clueCellIndex = targetIndex - cols;
    } else {
      continue;
    }

    if (clueCellIndex >= 0 && clueCellIndex < grid.length) {
      clueCellIndices.add(clueCellIndex);
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
  const { clues, grid, gridnums, size } = puzzle;

  // For each clue, check if all cells are now filled
  for (const [clueNum, clue] of Object.entries(clues) as [string, any][]) {
    const targetIndex = clue.target_index;
    const direction = clue.arrow;
    const wordCells: number[] = [];
    let word = '';
    let allFilled = true;
    let hasNewCell = false;

    // Trace the word from target_index
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
      completedWords.push({
        word,
        cells: wordCells,
        bonus,
      });
    }
  }

  return completedWords;
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

// ============================================================================
// Session Handlers (Empty Slug)
// ============================================================================

/**
 * POST /api/sync/linked
 *
 * Creates a new match if none exists, or returns existing active match.
 */
async function handleSessionPost(req: NextRequest, userId: string): Promise<NextResponse> {
  try {
    // Extract base URL for image paths
    const baseUrl = new URL(req.url).origin;

    // Parse request body for localDate
    let localDate: string | null = null;
    try {
      const body = await req.json();
      localDate = body.localDate || null;
    } catch {
      // No body or invalid JSON, continue without localDate
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
    const { puzzleId, activeMatch, branch } = await getNextPuzzleForCouple(coupleId);

    // If no active match and cooldown is active, return cooldown response
    if (!activeMatch && await isCooldownActive(coupleId, localDate)) {
      return NextResponse.json({
        success: false,
        code: 'COOLDOWN_ACTIVE',
        message: 'Next puzzle available tomorrow',
        cooldownEnabled: true,
      });
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
}

/**
 * GET /api/sync/linked
 *
 * Get current active match state
 */
async function handleSessionGet(req: NextRequest, userId: string): Promise<NextResponse> {
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
}

// ============================================================================
// Match Polling Handler (GET with matchId)
// ============================================================================

/**
 * GET /api/sync/linked/[matchId]
 *
 * Get specific match state - used for polling during partner's turn
 */
async function handleMatchGet(req: NextRequest, userId: string, matchId: string): Promise<NextResponse> {
  try {
    // Extract base URL for image paths
    const baseUrl = new URL(req.url).origin;

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
      `SELECT * FROM linked_matches WHERE id = $1 AND couple_id = $2 LIMIT 1`,
      [matchId, coupleId]
    );

    if (result.rows.length === 0) {
      return NextResponse.json(
        { error: 'Match not found', code: 'NOT_FOUND' },
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
        winnerId: match.winner_id,
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
}

// ============================================================================
// Submit Handler (POST submit)
// ============================================================================

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
async function handleSubmitPost(req: NextRequest, userId: string): Promise<NextResponse> {
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

    // Load puzzle with solution
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
    if (gameComplete) {
      if (newPlayer1Score > newPlayer2Score) {
        winnerId = user1_id;
      } else if (newPlayer2Score > newPlayer1Score) {
        winnerId = user2_id;
      }
      // If tied, winnerId stays null

      // Award LP directly using the same client (avoids connection pool issues)
      await client.query(
        `UPDATE couples SET total_lp = COALESCE(total_lp, 0) + $1 WHERE id = $2`,
        [LP_REWARDS.LINKED, coupleId]
      );

      // Record LP transaction for audit trail
      await client.query(
        `INSERT INTO love_point_transactions (user_id, amount, source, description, created_at)
         VALUES ($1, $2, 'linked_complete', $3, NOW()), ($4, $2, 'linked_complete', $3, NOW())`,
        [user1_id, LP_REWARDS.LINKED, `linked_complete (${matchId})`, user2_id]
      );

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
}

// ============================================================================
// Hint Handler (POST hint)
// ============================================================================

/**
 * POST /api/sync/linked/hint
 *
 * Use hint power-up to highlight valid cell positions
 *
 * Body: {
 *   matchId: string
 *   remainingRack?: string[]  // Optional: letters still available (after draft placements)
 * }
 */
async function handleHintPost(req: NextRequest, userId: string): Promise<NextResponse> {
  const client = await getClient();

  try {
    const body = await req.json();
    const { matchId, remainingRack } = body;

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

    // Use remainingRack if provided (accounts for draft placements), otherwise use full rack
    const rackToUse = remainingRack && Array.isArray(remainingRack) && remainingRack.length > 0
      ? remainingRack
      : match.current_rack || [];
    const boardState = typeof match.board_state === 'string'
      ? JSON.parse(match.board_state)
      : match.board_state || {};

    // Find valid cells for remaining rack letters
    const validCells = findValidCells(puzzle, boardState, rackToUse);

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
}

// ============================================================================
// Route Dispatch Functions (exported for use in main sync route)
// ============================================================================

/**
 * Route linked GET requests to appropriate handlers
 */
export function routeLinkedGET(req: NextRequest, subPath: string): Promise<NextResponse> {
  // Empty path → get active session
  if (!subPath || subPath === '') {
    return withAuthOrDevBypass(async (req: NextRequest, userId: string) => {
      return handleSessionGet(req, userId);
    })(req);
  }

  // UUID format → specific match polling
  if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(subPath)) {
    return withAuthOrDevBypass(async (req: NextRequest, userId: string) => {
      return handleMatchGet(req, userId, subPath);
    })(req);
  }

  // Unknown GET path
  return Promise.resolve(NextResponse.json(
    { error: `Unknown GET path: /api/sync/linked/${subPath}` },
    { status: 404 }
  ));
}

/**
 * Route linked POST requests to appropriate handlers
 */
export function routeLinkedPOST(req: NextRequest, subPath: string): Promise<NextResponse> {
  // Empty path → create/get session
  if (!subPath || subPath === '') {
    return withAuthOrDevBypass(async (req: NextRequest, userId: string) => {
      return handleSessionPost(req, userId);
    })(req);
  }

  // submit endpoint
  if (subPath === 'submit') {
    return withAuthOrDevBypass(async (req: NextRequest, userId: string) => {
      return handleSubmitPost(req, userId);
    })(req);
  }

  // hint endpoint
  if (subPath === 'hint') {
    return withAuthOrDevBypass(async (req: NextRequest, userId: string) => {
      return handleHintPost(req, userId);
    })(req);
  }

  // Unknown POST path
  return Promise.resolve(NextResponse.json(
    { error: `Unknown POST path: /api/sync/linked/${subPath}` },
    { status: 404 }
  ));
}

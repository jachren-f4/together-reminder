/**
 * Word Search Game API Endpoint
 *
 * Server-side match creation and retrieval for word search puzzle game
 * POST: Create or return existing active match
 * GET: Get current match state
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { readFileSync } from 'fs';
import { join } from 'path';

export const dynamic = 'force-dynamic';

// Check if cooldown is enabled (defaults to true in production)
const COOLDOWN_ENABLED = process.env.PUZZLE_COOLDOWN_ENABLED !== 'false';

// Direction deltas for a 10-column grid
const DIRECTION_DELTAS: Record<string, number> = {
  'R': 1, 'L': -1, 'D': 10, 'U': -10,
  'DR': 11, 'DL': 9, 'UR': -9, 'UL': -11
};

// Check if cooldown is active (last completion was on client's local date)
async function isCooldownActive(coupleId: string, clientLocalDate: string | null): Promise<boolean> {
  if (!COOLDOWN_ENABLED || !clientLocalDate) {
    return false;
  }

  // Get most recent completed match
  const result = await query(
    `SELECT completed_at FROM word_search_matches
     WHERE couple_id = $1 AND status = 'completed'
     ORDER BY completed_at DESC LIMIT 1`,
    [coupleId]
  );

  if (result.rows.length === 0) {
    return false; // No completed matches, no cooldown
  }

  const completedAt = new Date(result.rows[0].completed_at);
  const clientDate = new Date(clientLocalDate + 'T00:00:00'); // Parse as local date

  // Check if completion was on the same day as client's local date
  // We compare the date strings to avoid timezone issues
  const completedDateStr = completedAt.toISOString().split('T')[0];

  return completedDateStr === clientLocalDate;
}

// Load puzzle data from branch-specific path
function loadPuzzle(puzzleId: string, branch?: string): any {
  try {
    // Use branch path (default to 'everyday' if no branch specified)
    const branchFolder = branch || 'everyday';
    const puzzlePath = join(process.cwd(), 'data', 'puzzles', 'word-search', branchFolder, `${puzzleId}.json`);
    const puzzleData = readFileSync(puzzlePath, 'utf-8');
    return JSON.parse(puzzleData);
  } catch (error) {
    console.error(`Failed to load word search puzzle ${puzzleId}:`, error);
    return null;
  }
}

// Load puzzle order config from branch-specific path
function loadPuzzleOrder(branch?: string): string[] {
  try {
    // Use branch path (default to 'everyday' if no branch specified)
    const branchFolder = branch || 'everyday';
    const orderPath = join(process.cwd(), 'data', 'puzzles', 'word-search', branchFolder, 'puzzle-order.json');
    const orderData = readFileSync(orderPath, 'utf-8');
    const config = JSON.parse(orderData);
    return config.puzzles || [];
  } catch (error) {
    console.error('Failed to load word search puzzle order:', error);
    return ['ws_001'];
  }
}

// Get current branch for couple based on completion count
async function getCurrentBranch(coupleId: string): Promise<string> {
  // Check for branch_progression record
  const result = await query(
    `SELECT current_branch, total_completions, max_branches
     FROM branch_progression
     WHERE couple_id = $1 AND activity_type = 'wordSearch'`,
    [coupleId]
  );

  if (result.rows.length === 0) {
    // No progression record, default to first branch (everyday)
    return 'everyday';
  }

  const { current_branch } = result.rows[0];
  return getBranchFolderName(current_branch);
}

// Map branch index to folder name
function getBranchFolderName(branchIndex: number): string {
  const folders = ['everyday', 'passionate', 'naughty'];
  return folders[branchIndex % folders.length];
}

// Get next puzzle for couple (finds first uncompleted puzzle in order for current branch)
async function getNextPuzzleForCouple(coupleId: string): Promise<{ puzzleId: string | null; activeMatch: any | null; branch: string }> {
  // Get current branch for this couple
  const branch = await getCurrentBranch(coupleId);

  // Load puzzle order for this branch
  const puzzleOrder = loadPuzzleOrder(branch);

  // Check for any active match first
  const activeResult = await query(
    `SELECT * FROM word_search_matches WHERE couple_id = $1 AND status = 'active' ORDER BY created_at DESC LIMIT 1`,
    [coupleId]
  );

  if (activeResult.rows.length > 0) {
    return { puzzleId: activeResult.rows[0].puzzle_id, activeMatch: activeResult.rows[0], branch };
  }

  // Get all completed puzzles for this couple
  const completedResult = await query(
    `SELECT DISTINCT puzzle_id FROM word_search_matches WHERE couple_id = $1 AND status = 'completed'`,
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

// Get puzzle data for client (without word positions - client must find them)
function getPuzzleForClient(puzzle: any): any {
  // Convert word positions object to just array of words
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
 * POST /api/sync/word-search
 *
 * Creates a new match if none exists, or returns existing active match.
 * Body: { localDate?: string } - Client's local date in YYYY-MM-DD format for cooldown check
 */
export const POST = withAuthOrDevBypass(async (req, userId, email) => {
  try {
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

      // Determine first player (use couple preference or default to user2)
      const firstPlayer = first_player_id || user2_id;

      const insertResult = await query(
        `INSERT INTO word_search_matches (
          couple_id, puzzle_id, status, found_words,
          current_turn_user_id, turn_number, words_found_this_turn,
          player1_words_found, player2_words_found,
          player1_hints, player2_hints,
          player1_id, player2_id, created_at
        )
        VALUES ($1, $2, 'active', '[]', $3, 1, 0, 0, 0, 3, 3, $4, $5, NOW())
        RETURNING *`,
        [coupleId, puzzleId, firstPlayer, user1_id, user2_id]
      );

      match = insertResult.rows[0];
    }

    // Calculate game state for response
    const isPlayer1 = userId === user1_id;
    const isMyTurn = match.current_turn_user_id === userId;
    const foundWords = typeof match.found_words === 'string'
      ? JSON.parse(match.found_words)
      : match.found_words || [];

    return NextResponse.json({
      success: true,
      isNewMatch,
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
        player1Score: match.player1_score || 0,
        player2Score: match.player2_score || 0,
        player1Hints: match.player1_hints,
        player2Hints: match.player2_hints,
        player1Id: match.player1_id,
        player2Id: match.player2_id,
        winnerId: match.winner_id,
        createdAt: match.created_at,
        completedAt: match.completed_at,
      },
      puzzle: getPuzzleForClient(puzzle),
      gameState: {
        isMyTurn,
        canPlay: isMyTurn && match.status === 'active',
        wordsRemainingThisTurn: 3 - match.words_found_this_turn,
        myWordsFound: isPlayer1 ? match.player1_words_found : match.player2_words_found,
        partnerWordsFound: isPlayer1 ? match.player2_words_found : match.player1_words_found,
        myScore: isPlayer1 ? (match.player1_score || 0) : (match.player2_score || 0),
        partnerScore: isPlayer1 ? (match.player2_score || 0) : (match.player1_score || 0),
        myHints: isPlayer1 ? match.player1_hints : match.player2_hints,
        partnerHints: isPlayer1 ? match.player2_hints : match.player1_hints,
        progressPercent: Math.round((foundWords.length / 12) * 100),
      }
    });
  } catch (error) {
    console.error('Error in Word Search API:', error);
    return NextResponse.json(
      { error: 'Failed to get/create match' },
      { status: 500 }
    );
  }
});

/**
 * GET /api/sync/word-search
 *
 * Get current active match state
 */
export const GET = withAuthOrDevBypass(async (req, userId, email) => {
  try {
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
      `SELECT * FROM word_search_matches WHERE couple_id = $1 AND status = 'active' ORDER BY created_at DESC LIMIT 1`,
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
        player1Score: match.player1_score || 0,
        player2Score: match.player2_score || 0,
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
        myScore: isPlayer1 ? (match.player1_score || 0) : (match.player2_score || 0),
        partnerScore: isPlayer1 ? (match.player2_score || 0) : (match.player1_score || 0),
        myHints: isPlayer1 ? match.player1_hints : match.player2_hints,
        partnerHints: isPlayer1 ? match.player2_hints : match.player1_hints,
        progressPercent: Math.round((foundWords.length / 12) * 100),
      }
    });
  } catch (error) {
    console.error('Error getting Word Search match:', error);
    return NextResponse.json(
      { error: 'Failed to get match' },
      { status: 500 }
    );
  }
});

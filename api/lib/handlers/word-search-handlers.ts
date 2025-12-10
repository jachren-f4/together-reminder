/**
 * Word Search Game Handlers
 *
 * Handles all word-search endpoints:
 * - GET/POST `` (empty) → word-search session
 * - GET `{matchId}` → specific match polling (UUID)
 * - POST `submit` → submit found word
 * - POST `hint` → use hint
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query, getClient } from '@/lib/db/pool';
import { getCouple, getCoupleBasic } from '@/lib/couple/utils';
import {
  loadPuzzle,
  getCurrentBranch,
  isCooldownActive,
  getNextPuzzle,
} from '@/lib/puzzle/loader';
import { LP_REWARDS, SCORING } from '@/lib/lp/config';
import { readFileSync } from 'fs';
import { join } from 'path';

// Direction deltas for a 10-column grid
const DIRECTION_DELTAS: Record<string, number> = {
  'R': 1, 'L': -1, 'D': 10, 'U': -10,
  'DR': 11, 'DL': 9, 'UR': -9, 'UL': -11
};

// Map branch index to folder name
function getBranchFolderName(branchIndex: number): string {
  const folders = ['everyday', 'passionate', 'naughty'];
  return folders[branchIndex % folders.length];
}

// Get current branch folder for couple (accepts client for use within transactions)
async function getCurrentBranchFolder(coupleId: string, client: any): Promise<string> {
  const result = await client.query(
    `SELECT current_branch FROM branch_progression
     WHERE couple_id = $1 AND activity_type = 'wordSearch'`,
    [coupleId]
  );

  if (result.rows.length === 0) {
    return 'everyday'; // Default to first branch
  }

  return getBranchFolderName(result.rows[0].current_branch);
}

// Load puzzle data from branch-specific path (including word positions for validation)
function loadPuzzleWithPositions(puzzleId: string, branch: string): any {
  try {
    const puzzlePath = join(process.cwd(), 'data', 'puzzles', 'word-search', branch, `${puzzleId}.json`);
    const puzzleData = readFileSync(puzzlePath, 'utf-8');
    return JSON.parse(puzzleData);
  } catch (error) {
    console.error(`Failed to load word search puzzle ${puzzleId} from branch ${branch}:`, error);
    return null;
  }
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

// Get word indices from position format "startIndex,direction"
function getWordIndices(positionStr: string, wordLength: number, cols: number = 10): number[] {
  const [startIndexStr, direction] = positionStr.split(',');
  const startIndex = parseInt(startIndexStr);
  const delta = DIRECTION_DELTAS[direction] || 0;

  return Array.from({ length: wordLength }, (_, i) => startIndex + (i * delta));
}

// Convert flat index to row/col
function indexToPosition(index: number, cols: number = 10): { row: number; col: number } {
  return {
    row: Math.floor(index / cols),
    col: index % cols
  };
}

// Validate that submitted positions match the word's actual position in puzzle
function validateWordPositions(
  puzzle: any,
  word: string,
  submittedPositions: Array<{ row: number; col: number }>
): boolean {
  const wordPosition = puzzle.words[word];
  if (!wordPosition) return false;

  const cols = puzzle.size.cols;
  const expectedIndices = getWordIndices(wordPosition, word.length, cols);
  const expectedPositions = expectedIndices.map(i => indexToPosition(i, cols));

  // Check both forward and backward (word can be found in either direction)
  const forwardMatch = submittedPositions.every((pos, i) =>
    pos.row === expectedPositions[i].row && pos.col === expectedPositions[i].col
  );

  if (forwardMatch) return true;

  // Check reversed
  const reversedPositions = [...expectedPositions].reverse();
  const backwardMatch = submittedPositions.every((pos, i) =>
    pos.row === reversedPositions[i].row && pos.col === reversedPositions[i].col
  );

  return backwardMatch;
}

// Helper to build match response
function buildMatchResponse(match: any, puzzle: any, userId: string, isPlayer1: boolean) {
  const isMyTurn = match.current_turn_user_id === userId;
  const foundWords = typeof match.found_words === 'string'
    ? JSON.parse(match.found_words)
    : match.found_words || [];

  return {
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
  };
}

// ============================================================================
// Session Handlers
// ============================================================================

/**
 * POST /api/sync/word-search (empty slug)
 *
 * Creates a new match if none exists, or returns existing active match.
 * Body: { localDate?: string } - Client's local date in YYYY-MM-DD format for cooldown check
 */
async function handleCreateOrGetSession(req: NextRequest, userId: string, email?: string) {
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
    const couple = await getCouple(userId);
    if (!couple) {
      return NextResponse.json(
        { error: 'No couple found for user' },
        { status: 404 }
      );
    }

    const { coupleId, user1Id, user2Id, firstPlayerId, isPlayer1 } = couple;

    // Get next puzzle for this couple (active match or first uncompleted)
    const { puzzleId, activeMatch, branch } = await getNextPuzzle(coupleId, 'wordSearch');

    // If no active match and cooldown is active, return cooldown response
    if (!activeMatch && await isCooldownActive(coupleId, 'wordSearch', localDate)) {
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

    // Load puzzle from branch-specific path
    const puzzle = loadPuzzle('wordSearch', puzzleId, branch);

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
      const firstPlayer = firstPlayerId || user2Id;

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
        [coupleId, puzzleId, firstPlayer, user1Id, user2Id]
      );

      match = insertResult.rows[0];
    }

    const response = buildMatchResponse(match, puzzle, userId, isPlayer1);
    return NextResponse.json({
      ...response,
      isNewMatch,
    });
  } catch (error) {
    console.error('Error in Word Search API:', error);
    return NextResponse.json(
      { error: 'Failed to get/create match' },
      { status: 500 }
    );
  }
}

/**
 * GET /api/sync/word-search (empty slug)
 *
 * Get current active match state
 */
async function handleGetActiveSession(req: NextRequest, userId: string, email?: string) {
  try {
    // Get couple info
    const couple = await getCoupleBasic(userId);
    if (!couple) {
      return NextResponse.json(
        { error: 'No couple found for user' },
        { status: 404 }
      );
    }

    const { coupleId, user1Id, isPlayer1 } = couple;

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

    // Get current branch for this couple
    const branch = await getCurrentBranch(coupleId, 'wordSearch');

    // Load puzzle for client from correct branch
    const puzzle = loadPuzzle('wordSearch', match.puzzle_id, branch);

    return NextResponse.json(buildMatchResponse(match, puzzle, userId, isPlayer1));
  } catch (error) {
    console.error('Error getting Word Search match:', error);
    return NextResponse.json(
      { error: 'Failed to get match' },
      { status: 500 }
    );
  }
}

/**
 * GET /api/sync/word-search/{matchId}
 *
 * Poll specific match state (used during partner's turn)
 */
async function handleGetSpecificMatch(req: NextRequest, userId: string, email: string | undefined, matchId: string) {
  try {
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

    // Get current branch for this couple
    const branch = await getCurrentBranch(coupleId, 'wordSearch');

    // Load puzzle for client from correct branch
    const puzzle = loadPuzzle('wordSearch', match.puzzle_id, branch);

    return NextResponse.json(buildMatchResponse(match, puzzle, userId, isPlayer1));
  } catch (error) {
    console.error('Error polling Word Search match:', error);
    return NextResponse.json(
      { error: 'Failed to poll match' },
      { status: 500 }
    );
  }
}

// ============================================================================
// Submit Handler
// ============================================================================

/**
 * POST /api/sync/word-search/submit
 *
 * Submit a found word for validation
 *
 * Body: {
 *   matchId: string,
 *   word: string,
 *   positions: Array<{ row: number, col: number }>
 * }
 */
async function handleSubmitWord(req: NextRequest, userId: string, email?: string) {
  const client = await getClient();

  try {
    const body = await req.json();
    const { matchId, word, positions } = body;

    if (!matchId || !word || !positions || !Array.isArray(positions)) {
      return NextResponse.json(
        { error: 'matchId, word, and positions array required' },
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

    // Get current branch for this couple (needed to load correct puzzle file)
    const branch = await getCurrentBranchFolder(coupleId, client);

    // Load puzzle with positions from correct branch
    const puzzle = loadPuzzleWithPositions(match.puzzle_id, branch);
    if (!puzzle) {
      await client.query('ROLLBACK');
      return NextResponse.json(
        { error: `Puzzle not found: ${match.puzzle_id} in branch ${branch}` },
        { status: 500 }
      );
    }

    const upperWord = word.toUpperCase();
    const foundWords = typeof match.found_words === 'string'
      ? JSON.parse(match.found_words)
      : match.found_words || [];

    // Check if word is in puzzle
    if (!puzzle.words[upperWord]) {
      await client.query('ROLLBACK');
      return NextResponse.json({
        success: true,
        valid: false,
        reason: 'Word not in puzzle'
      });
    }

    // Check if word was already found
    if (foundWords.some((fw: any) => fw.word === upperWord)) {
      await client.query('ROLLBACK');
      return NextResponse.json({
        success: true,
        valid: false,
        reason: 'Word already found'
      });
    }

    // Validate positions match the word
    if (!validateWordPositions(puzzle, upperWord, positions)) {
      await client.query('ROLLBACK');
      return NextResponse.json({
        success: true,
        valid: false,
        reason: 'Invalid positions for word'
      });
    }

    // Word is valid! Lock it
    const colorIndex = foundWords.length % 5;
    const pointsEarned = upperWord.length * SCORING.WORD_SEARCH_POINTS_PER_LETTER;

    foundWords.push({
      word: upperWord,
      foundBy: userId,
      turnNumber: match.turn_number,
      positions: positions,
      colorIndex: colorIndex
    });

    // Update counts and scores
    const newWordsFoundThisTurn = match.words_found_this_turn + 1;
    const newPlayerWordsFound = isPlayer1
      ? match.player1_words_found + 1
      : match.player2_words_found + 1;
    const newPlayerScore = isPlayer1
      ? (match.player1_score || 0) + pointsEarned
      : (match.player2_score || 0) + pointsEarned;

    // Check if turn complete (3 words)
    const turnComplete = newWordsFoundThisTurn >= 3;

    // Check if game complete (12 words)
    const gameComplete = foundWords.length >= 12;

    // Determine next state
    let newStatus = 'active';
    let winnerId = null;
    let completedAt = null;
    let nextBranch = null;

    if (gameComplete) {
      newStatus = 'completed';
      completedAt = new Date();

      // Determine winner by SCORE (not word count)
      const finalP1Score = isPlayer1 ? newPlayerScore : (match.player1_score || 0);
      const finalP2Score = isPlayer1 ? (match.player2_score || 0) : newPlayerScore;

      if (finalP1Score > finalP2Score) {
        winnerId = user1_id;
      } else if (finalP2Score > finalP1Score) {
        winnerId = user2_id;
      }
      // If tied, winnerId stays null

      // Award LP directly using the same client (avoids connection pool issues)
      await client.query(
        `UPDATE couples SET total_lp = COALESCE(total_lp, 0) + $1 WHERE id = $2`,
        [LP_REWARDS.WORD_SEARCH, coupleId]
      );

      // Record LP transaction for audit trail
      await client.query(
        `INSERT INTO love_point_transactions (user_id, amount, source, description, created_at)
         VALUES ($1, $2, 'word_search_complete', $3, NOW()), ($4, $2, 'word_search_complete', $3, NOW())`,
        [user1_id, LP_REWARDS.WORD_SEARCH, `word_search_complete (${matchId})`, user2_id]
      );

      // Advance branch progression for Word Search activity
      // This makes the next puzzle come from the next branch (everyday -> passionate -> naughty -> everyday)
      const branchResult = await client.query(
        `INSERT INTO branch_progression (couple_id, activity_type, current_branch, total_completions, max_branches)
         VALUES ($1, 'wordSearch', 0, 1, 3)
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

    // Switch turns if turn complete and game not over
    const nextTurnUserId = turnComplete && !gameComplete
      ? (userId === user1_id ? user2_id : user1_id)
      : match.current_turn_user_id;

    const nextWordsFoundThisTurn = turnComplete ? 0 : newWordsFoundThisTurn;
    const nextTurnNumber = turnComplete && !gameComplete
      ? match.turn_number + 1
      : match.turn_number;

    // Update match
    await client.query(
      `UPDATE word_search_matches SET
        found_words = $1,
        current_turn_user_id = $2,
        turn_number = $3,
        words_found_this_turn = $4,
        player1_words_found = $5,
        player2_words_found = $6,
        player1_score = $7,
        player2_score = $8,
        status = $9,
        winner_id = $10,
        completed_at = $11
      WHERE id = $12`,
      [
        JSON.stringify(foundWords),
        nextTurnUserId,
        nextTurnNumber,
        nextWordsFoundThisTurn,
        isPlayer1 ? newPlayerWordsFound : match.player1_words_found,
        isPlayer1 ? match.player2_words_found : newPlayerWordsFound,
        isPlayer1 ? newPlayerScore : (match.player1_score || 0),
        isPlayer1 ? (match.player2_score || 0) : newPlayerScore,
        newStatus,
        winnerId,
        completedAt,
        matchId
      ]
    );

    // Record move in audit table
    await client.query(
      `INSERT INTO word_search_moves (match_id, player_id, word, positions, turn_number)
       VALUES ($1, $2, $3, $4, $5)`,
      [matchId, userId, upperWord, JSON.stringify(positions), match.turn_number]
    );

    await client.query('COMMIT');

    return NextResponse.json({
      success: true,
      valid: true,
      pointsEarned,
      wordsFoundThisTurn: nextWordsFoundThisTurn,
      turnComplete,
      gameComplete,
      nextTurnUserId: turnComplete && !gameComplete ? nextTurnUserId : null,
      colorIndex,
      winnerId,
      nextBranch: gameComplete ? nextBranch : null,  // Branch for next puzzle (0=everyday, 1=passionate, 2=naughty)
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error submitting word:', error);
    return NextResponse.json(
      { error: 'Failed to submit word' },
      { status: 500 }
    );
  } finally {
    client.release();
  }
}

// ============================================================================
// Hint Handler
// ============================================================================

/**
 * POST /api/sync/word-search/hint
 *
 * Use a hint to reveal the first letter position of a random unfound word
 *
 * Body: {
 *   matchId: string
 * }
 */
async function handleUseHint(req: NextRequest, userId: string, email?: string) {
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

    // Get current branch for this couple
    const branch = await getCurrentBranchFolder(coupleId, client);

    // Load puzzle from correct branch
    const puzzle = loadPuzzleWithPositions(match.puzzle_id, branch);
    if (!puzzle) {
      await client.query('ROLLBACK');
      return NextResponse.json(
        { error: `Puzzle not found: ${match.puzzle_id} in branch ${branch}` },
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
}

// ============================================================================
// Route Dispatch Functions (exported for use in main sync route)
// ============================================================================

/**
 * Route word-search GET requests to appropriate handlers
 */
export function routeWordSearchGET(req: NextRequest, subPath: string): Promise<NextResponse> {
  // Empty path → get active session
  if (!subPath || subPath === '') {
    return withAuthOrDevBypass(async (req: NextRequest, userId: string, email?: string) => {
      return handleGetActiveSession(req, userId, email);
    })(req);
  }

  // UUID format → specific match polling
  if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(subPath)) {
    return withAuthOrDevBypass(async (req: NextRequest, userId: string, email?: string) => {
      return handleGetSpecificMatch(req, userId, email, subPath);
    })(req);
  }

  // Unknown GET path
  return Promise.resolve(NextResponse.json(
    { error: `Unknown GET path: /api/sync/word-search/${subPath}` },
    { status: 404 }
  ));
}

/**
 * Route word-search POST requests to appropriate handlers
 */
export function routeWordSearchPOST(req: NextRequest, subPath: string): Promise<NextResponse> {
  // Empty path → create/get session
  if (!subPath || subPath === '') {
    return withAuthOrDevBypass(async (req: NextRequest, userId: string, email?: string) => {
      return handleCreateOrGetSession(req, userId, email);
    })(req);
  }

  // submit endpoint
  if (subPath === 'submit') {
    return withAuthOrDevBypass(async (req: NextRequest, userId: string, email?: string) => {
      return handleSubmitWord(req, userId, email);
    })(req);
  }

  // hint endpoint
  if (subPath === 'hint') {
    return withAuthOrDevBypass(async (req: NextRequest, userId: string, email?: string) => {
      return handleUseHint(req, userId, email);
    })(req);
  }

  // Unknown POST path
  return Promise.resolve(NextResponse.json(
    { error: `Unknown POST path: /api/sync/word-search/${subPath}` },
    { status: 404 }
  ));
}

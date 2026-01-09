/**
 * Word Search Game Word Submission API
 *
 * POST /api/sync/word-search/submit - Submit a found word for validation
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query, getClient } from '@/lib/db/pool';
import { LP_REWARDS, SCORING } from '@/lib/lp/config';
import { tryAwardDailyLp, LpGrantResult } from '@/lib/lp/grant-service';
import { recordActivityPlay } from '@/lib/magnets';
import { readFileSync } from 'fs';
import { join } from 'path';

export const dynamic = 'force-dynamic';

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
function loadPuzzle(puzzleId: string, branch: string): any {
  try {
    const puzzlePath = join(process.cwd(), 'data', 'puzzles', 'word-search', branch, `${puzzleId}.json`);
    const puzzleData = readFileSync(puzzlePath, 'utf-8');
    return JSON.parse(puzzleData);
  } catch (error) {
    console.error(`Failed to load word search puzzle ${puzzleId} from branch ${branch}:`, error);
    return null;
  }
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
export const POST = withAuthOrDevBypass(async (req, userId, email) => {
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
    const puzzle = loadPuzzle(match.puzzle_id, branch);
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
    let lpGrantResult: LpGrantResult | null = null;

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

      // Use new daily LP grant system
      lpGrantResult = await tryAwardDailyLp(client, coupleId, 'word_search', matchId);
      console.log(`🎯 Word Search LP Grant Result: lpAwarded=${lpGrantResult.lpAwarded}, alreadyGrantedToday=${lpGrantResult.alreadyGrantedToday}`);

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

      // Record activity play for cooldown tracking (Magnet Collection System)
      // Pass client to avoid connection pool deadlock
      await recordActivityPlay(coupleId, 'wordsearch', client);
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
      // LP status from daily grant system
      lpEarned: lpGrantResult?.lpAwarded ?? 0,
      alreadyGrantedToday: lpGrantResult?.alreadyGrantedToday ?? false,
      resetInMs: lpGrantResult?.resetInMs ?? 0,
      canPlayMore: lpGrantResult?.canPlayMore ?? true,
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
});

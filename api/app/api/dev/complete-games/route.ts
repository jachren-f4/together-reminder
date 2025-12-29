/**
 * Dev Endpoint: Complete Games with Dummy Answers
 *
 * POST /api/dev/complete-games
 *
 * Completes active game matches for a couple by submitting random/auto-fill answers
 * for both users. Used for testing branch cycling without manual gameplay.
 *
 * Server handles EVERYTHING:
 * - Creates new match
 * - Completes it with auto-generated answers
 * - Awards LP
 * - Advances branch progression
 *
 * Supports all game types:
 * - classic, affirmation, you_or_me: Quiz-based (quiz_matches table)
 * - linked: Arroword puzzle (linked_matches table) - auto-fills all cells
 * - word_search: Word search puzzle (word_search_matches table) - auto-finds all words
 *
 * Request body:
 * {
 *   localDate?: string,
 *   gameTypes?: string[],  // Default: ['classic', 'affirmation', 'you_or_me', 'linked', 'word_search']
 * }
 *
 * Response:
 * {
 *   success: true,
 *   completed: [{ matchId, gameType, quizId/puzzleId, branch, matchPercentage?, lpEarned }],
 *   totalLp: number,
 *   branches: { classicQuiz: 0, affirmation: 1, youOrMe: 2, linked: 0, wordSearch: 1 }
 * }
 */

import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db/pool';
import { awardLP } from '@/lib/lp/award';
import { getCouple, getOrCreateMatch, GameType, advanceBranch, advanceBranchGeneric } from '@/lib/game/handler';
import { randomUUID } from 'crypto';
import { readFileSync } from 'fs';
import { join } from 'path';
import { LP_REWARDS } from '@/lib/lp/config';

export const dynamic = 'force-dynamic';

// Only allow in dev mode
const IS_DEV = process.env.NODE_ENV === 'development';

// Game config for branch advancement
const GAME_CONFIG: Record<string, { activityType: string; numBranches: number; table?: string }> = {
  classic: { activityType: 'classicQuiz', numBranches: 5 },
  affirmation: { activityType: 'affirmation', numBranches: 5 },
  you_or_me: { activityType: 'youOrMe', numBranches: 5 },
  linked: { activityType: 'linked', numBranches: 3, table: 'linked_matches' },
  word_search: { activityType: 'wordSearch', numBranches: 3, table: 'word_search_matches' },
};

// Branch folder names for puzzle games
const BRANCH_FOLDERS: Record<string, string[]> = {
  linked: ['casual', 'romantic', 'adult'],
  word_search: ['everyday', 'passionate', 'naughty'],
};

interface CompletedGame {
  matchId: string;
  gameType: string;
  puzzleId?: string;
  quizId?: string;
  branch: string;
  matchPercentage?: number;
  lpEarned: number;
}

// Load puzzle from file
function loadPuzzle(gameType: string, branch: string, puzzleId: string): any {
  try {
    const folder = gameType === 'linked' ? 'linked' : 'word-search';
    const puzzlePath = join(process.cwd(), 'data', 'puzzles', folder, branch, `${puzzleId}.json`);
    return JSON.parse(readFileSync(puzzlePath, 'utf-8'));
  } catch (error) {
    console.error(`Failed to load puzzle ${puzzleId}:`, error);
    return null;
  }
}

// Load puzzle order for a branch
function loadPuzzleOrder(gameType: string, branch: string): string[] {
  try {
    const folder = gameType === 'linked' ? 'linked' : 'word-search';
    const orderPath = join(process.cwd(), 'data', 'puzzles', folder, branch, 'puzzle-order.json');
    const config = JSON.parse(readFileSync(orderPath, 'utf-8'));
    return config.puzzles || [];
  } catch (error) {
    console.error(`Failed to load puzzle order for ${gameType}/${branch}:`, error);
    return gameType === 'linked' ? ['puzzle_001'] : ['ws_001'];
  }
}

// Get current branch folder name for a game type
async function getCurrentBranchFolder(coupleId: string, gameType: string): Promise<string> {
  const config = GAME_CONFIG[gameType];
  const folders = BRANCH_FOLDERS[gameType];

  const result = await query(
    `SELECT current_branch FROM branch_progression WHERE couple_id = $1 AND activity_type = $2`,
    [coupleId, config.activityType]
  );

  const branchIndex = result.rows[0]?.current_branch ?? 0;
  return folders[branchIndex % folders.length];
}

// Get next puzzle for couple (finds first uncompleted puzzle in order)
async function getNextPuzzle(coupleId: string, gameType: string, table: string): Promise<{ puzzleId: string | null; branch: string }> {
  const branch = await getCurrentBranchFolder(coupleId, gameType);
  const puzzleOrder = loadPuzzleOrder(gameType, branch);

  // Get completed puzzles
  const completedResult = await query(
    `SELECT DISTINCT puzzle_id FROM ${table} WHERE couple_id = $1 AND status = 'completed'`,
    [coupleId]
  );
  const completedPuzzles = new Set(completedResult.rows.map(r => r.puzzle_id));

  // Find first uncompleted
  for (const puzzleId of puzzleOrder) {
    if (!completedPuzzles.has(puzzleId)) {
      return { puzzleId, branch };
    }
  }

  // All completed, return first one (cycling)
  return { puzzleId: puzzleOrder[0] || null, branch };
}

// Complete a linked match by auto-filling all cells
async function completeLinkedMatch(
  coupleId: string,
  user1Id: string,
  user2Id: string,
  firstPlayerId: string | null
): Promise<CompletedGame | null> {
  const { puzzleId, branch } = await getNextPuzzle(coupleId, 'linked', 'linked_matches');
  if (!puzzleId) return null;

  const puzzle = loadPuzzle('linked', branch, puzzleId);
  if (!puzzle) return null;

  // Count answer cells and build full board state
  const { grid, size } = puzzle;
  const boardState: Record<string, string> = {};
  let answerCellCount = 0;

  for (let i = 0; i < grid.length; i++) {
    const row = Math.floor(i / size.cols);
    const col = i % size.cols;
    if (row === 0 || col === 0) continue;  // Skip clue frame
    if (grid[i] === '.') continue;  // Skip void cells
    boardState[i.toString()] = grid[i].toUpperCase();
    answerCellCount++;
  }

  // Create completed match
  const matchId = randomUUID();
  const startingPlayer = firstPlayerId || user1Id;

  await query(
    `INSERT INTO linked_matches (
      id, couple_id, puzzle_id, status,
      board_state, current_rack, current_turn_user_id, turn_number,
      player1_score, player2_score, player1_id, player2_id,
      total_answer_cells, locked_cell_count, winner_id, completed_at
    ) VALUES ($1, $2, $3, 'completed', $4, ARRAY[]::text[], $5, 1, 50, 50, $6, $7, $8, $8, NULL, NOW())`,
    [matchId, coupleId, puzzleId, JSON.stringify(boardState), startingPlayer, user1Id, user2Id, answerCellCount]
  );

  // Award LP
  const lpEarned = LP_REWARDS.LINKED;
  await awardLP(coupleId, lpEarned, 'linked_complete', `dev_${matchId}`);

  // Advance branch using shared function
  await advanceBranchGeneric(coupleId, 'linked', 3);

  return { matchId, gameType: 'linked', puzzleId, branch, lpEarned };
}

// Complete a word search match by auto-finding all words
async function completeWordSearchMatch(
  coupleId: string,
  user1Id: string,
  user2Id: string,
  firstPlayerId: string | null
): Promise<CompletedGame | null> {
  const { puzzleId, branch } = await getNextPuzzle(coupleId, 'word_search', 'word_search_matches');
  if (!puzzleId) return null;

  const puzzle = loadPuzzle('word_search', branch, puzzleId);
  if (!puzzle) return null;

  // Build found words with positions
  const words = Object.keys(puzzle.words);
  const foundWords = words.map((word, i) => ({
    word: word.toUpperCase(),
    foundBy: i % 2 === 0 ? user1Id : user2Id,  // Alternate between players
    turnNumber: Math.floor(i / 3) + 1,
    positions: [],  // Not needed for completion
    colorIndex: i % 5
  }));

  const wordsPerPlayer = Math.ceil(words.length / 2);
  const player1Score = wordsPerPlayer * 50;
  const player2Score = (words.length - wordsPerPlayer) * 50;

  // Create completed match
  const matchId = randomUUID();
  const startingPlayer = firstPlayerId || user1Id;

  await query(
    `INSERT INTO word_search_matches (
      id, couple_id, puzzle_id, status,
      found_words, current_turn_user_id, turn_number,
      words_found_this_turn, player1_words_found, player2_words_found,
      player1_score, player2_score, player1_id, player2_id,
      winner_id, completed_at
    ) VALUES ($1, $2, $3, 'completed', $4, $5, 1, 0, $6, $7, $8, $9, $10, $11, NULL, NOW())`,
    [
      matchId, coupleId, puzzleId, JSON.stringify(foundWords),
      startingPlayer, wordsPerPlayer, words.length - wordsPerPlayer,
      player1Score, player2Score, user1Id, user2Id
    ]
  );

  // Award LP
  const lpEarned = LP_REWARDS.WORD_SEARCH;
  await awardLP(coupleId, lpEarned, 'word_search_complete', `dev_${matchId}`);

  // Advance branch using shared function
  await advanceBranchGeneric(coupleId, 'wordSearch', 3);

  return { matchId, gameType: 'word_search', puzzleId, branch, lpEarned };
}

export async function POST(req: NextRequest) {
  // Security: Only allow in development
  if (!IS_DEV) {
    return NextResponse.json(
      { error: 'Dev endpoints disabled in production' },
      { status: 403 }
    );
  }

  try {
    const body = await req.json();
    const {
      localDate = new Date().toISOString().split('T')[0],
      gameTypes = ['classic', 'affirmation', 'you_or_me', 'linked', 'word_search'],
    } = body;

    // Get user from dev bypass header (X-Dev-User-Id)
    const userId = req.headers.get('X-Dev-User-Id');
    if (!userId) {
      return NextResponse.json(
        { error: 'X-Dev-User-Id header required for dev bypass' },
        { status: 400 }
      );
    }

    // Get couple info using shared function
    const coupleInfo = await getCouple(userId);
    if (!coupleInfo) {
      return NextResponse.json(
        { error: `User ${userId} not in a couple` },
        { status: 404 }
      );
    }

    // Extract fields for puzzle games that need them directly
    const { coupleId, user1Id: user1_id, user2Id: user2_id, firstPlayerId: first_player_id } = coupleInfo;

    const completed: CompletedGame[] = [];

    // Process each game type
    for (const gameType of gameTypes) {
      const config = GAME_CONFIG[gameType];
      if (!config) {
        console.log(`Unknown game type: ${gameType}`);
        continue;
      }

      // Handle puzzle-based games separately
      if (gameType === 'linked') {
        const result = await completeLinkedMatch(coupleId, user1_id, user2_id, first_player_id);
        if (result) {
          completed.push(result);
          console.log(`Completed linked: puzzleId=${result.puzzleId}, branch=${result.branch}`);
        }
        continue;
      }

      if (gameType === 'word_search') {
        const result = await completeWordSearchMatch(coupleId, user1_id, user2_id, first_player_id);
        if (result) {
          completed.push(result);
          console.log(`Completed word_search: puzzleId=${result.puzzleId}, branch=${result.branch}`);
        }
        continue;
      }

      // Quiz-based games (classic, affirmation, you_or_me)
      const internalGameType: GameType = gameType === 'you_or_me' ? 'you_or_me' : gameType as GameType;

      let match;
      let matchId;

      try {
        // First, check for existing active matches for this game type today
        // This handles the case where user opened quiz screen (creating a match) before using debug menu
        const existingActiveResult = await query(
          `SELECT id, quiz_id, branch FROM quiz_matches
           WHERE couple_id = $1 AND quiz_type = $2 AND date = $3 AND status = 'active'
           LIMIT 1`,
          [coupleId, internalGameType, localDate]
        );

        if (existingActiveResult.rows.length > 0) {
          // Complete the existing match (user "peeked" at quiz screen)
          const existingMatch = existingActiveResult.rows[0];
          matchId = existingMatch.id;
          match = {
            id: existingMatch.id,
            quizId: existingMatch.quiz_id,
            branch: existingMatch.branch
          };
          console.log(`Completing existing active ${gameType} match: ${matchId} (${match.quizId}/${match.branch})`);
        } else {
          // No existing match - create a new one
          const { match: newMatch } = await getOrCreateMatch(coupleInfo, internalGameType, localDate, { forceNew: true });
          match = newMatch;
          matchId = match.id;
          console.log(`Created new ${gameType} match: ${matchId} (${match.quizId}/${match.branch})`);
        }
      } catch (e) {
        console.log(`Could not get/create ${gameType} match: ${e}`);
        continue;
      }

      // Generate random answers
      const questionCount = 10;
      const maxOption = gameType === 'you_or_me' ? 2 : 4;

      const player1Answers = Array.from({ length: questionCount }, () =>
        Math.floor(Math.random() * maxOption)
      );
      const player2Answers = Array.from({ length: questionCount }, () =>
        Math.floor(Math.random() * maxOption)
      );

      // Calculate match percentage
      let matches = 0;
      if (gameType === 'you_or_me') {
        for (let i = 0; i < questionCount; i++) {
          const invertedP2 = player2Answers[i] === 0 ? 1 : 0;
          if (player1Answers[i] === invertedP2) matches++;
        }
      } else {
        for (let i = 0; i < questionCount; i++) {
          if (player1Answers[i] === player2Answers[i]) matches++;
        }
      }

      const matchPercentage = Math.round((matches / questionCount) * 100);
      const lpEarned = 30;

      // Complete the match (whether existing or new)
      await query(
        `UPDATE quiz_matches
         SET player1_answers = $1,
             player2_answers = $2,
             player1_answer_count = $3,
             player2_answer_count = $4,
             match_percentage = $5,
             status = 'completed',
             completed_at = NOW()
         WHERE id = $6`,
        [
          JSON.stringify(player1Answers),
          JSON.stringify(player2Answers),
          player1Answers.length,
          player2Answers.length,
          matchPercentage,
          matchId,
        ]
      );

      // Award LP
      const uniqueAwardId = `dev_${matchId}_${randomUUID().slice(0, 8)}`;
      await awardLP(coupleId, lpEarned, `${gameType}_complete`, uniqueAwardId);

      // Advance branch using shared function
      await advanceBranch(coupleId, internalGameType);

      completed.push({
        matchId,
        gameType,
        quizId: match.quizId,
        branch: match.branch,
        matchPercentage,
        lpEarned,
      });

      console.log(`Completed ${gameType}: matchId=${matchId}, quizId=${match.quizId}, branch=${match.branch}`);
    }

    // Fetch final state
    const lpResult = await query('SELECT total_lp FROM couples WHERE id = $1', [coupleId]);
    const branchResult = await query(
      'SELECT activity_type, current_branch FROM branch_progression WHERE couple_id = $1',
      [coupleId]
    );

    const branches: Record<string, number> = {};
    for (const row of branchResult.rows) {
      branches[row.activity_type] = row.current_branch;
    }

    return NextResponse.json({
      success: true,
      completed,
      totalLp: lpResult.rows[0]?.total_lp || 0,
      branches,
      message: `Completed ${completed.length} game(s) for couple ${coupleId}`,
    });
  } catch (error) {
    console.error('Error completing games:', error);
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Unknown error' },
      { status: 500 }
    );
  }
}

/**
 * Dev Router - Centralized routing for development endpoints
 *
 * This file exports routing functions for the /api/dev/* endpoints.
 * All handler logic is internal to this file, and the router functions
 * dispatch to the appropriate handlers based on the path.
 *
 * Security: All routes require AUTH_DEV_BYPASS_ENABLED=true
 *
 * Routes:
 * - GET  /api/dev/user-data?userId=<uuid>           - Fetch user and couple data for dev auth bypass
 * - POST /api/dev/reset-games                        - Reset game data for a couple
 * - POST /api/dev/reset-couple-progress              - Reset all progress for a couple (comprehensive)
 * - POST /api/dev/complete-games                     - Complete games with dummy answers
 * - POST /api/dev/update-password                    - Update user password for dev sign-in
 */

import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';
import { query, getClient } from '@/lib/db/pool';
import { awardLP } from '@/lib/lp/award';
import { getCouple, getOrCreateMatch, GameType, advanceBranch, advanceBranchGeneric } from '@/lib/game/handler';
import { randomUUID } from 'crypto';
import { readFileSync } from 'fs';
import { join } from 'path';
import { LP_REWARDS } from '@/lib/lp/config';

// ============================================================================
// Environment & Config
// ============================================================================

const supabaseUrl = process.env.SUPABASE_URL!;
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

// Security check - only allow when dev bypass is enabled
const isDevModeEnabled = process.env.NODE_ENV === 'development' || process.env.AUTH_DEV_BYPASS_ENABLED === 'true';

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

// ============================================================================
// Shared Helper Functions
// ============================================================================

function createSupabaseAdminClient() {
  return createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
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

// ============================================================================
// Route Handlers
// ============================================================================

/**
 * GET /api/dev/user-data
 * Fetch user and couple data for dev auth bypass
 */
async function handleUserData(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get('userId');

    if (!userId) {
      return NextResponse.json(
        { error: 'userId query parameter required' },
        { status: 400 }
      );
    }

    const supabase = createSupabaseAdminClient();

    // 1. Get user data from Supabase Auth
    const { data: authUser, error: authError } = await supabase.auth.admin.getUserById(userId);

    if (authError || !authUser) {
      return NextResponse.json(
        { error: `User not found: ${userId}` },
        { status: 404 }
      );
    }

    // 2. Get couple relationship
    const { data: couples, error: coupleError } = await supabase
      .from('couples')
      .select('*')
      .or(`user1_id.eq.${userId},user2_id.eq.${userId}`)
      .limit(1);

    if (coupleError) {
      console.error('Error fetching couple:', coupleError);
    }

    let partnerData = null;
    let coupleData = null;

    if (couples && couples.length > 0) {
      coupleData = couples[0];
      const partnerId = coupleData.user1_id === userId ? coupleData.user2_id : coupleData.user1_id;

      // 3. Get partner's data
      const { data: partner, error: partnerError } = await supabase.auth.admin.getUserById(partnerId);

      if (partner && !partnerError) {
        partnerData = {
          id: partner.user.id,
          email: partner.user.email,
          name: partner.user.user_metadata?.full_name || partner.user.email?.split('@')[0] || 'Partner',
          avatarEmoji: partner.user.user_metadata?.avatar_emoji || '👤',
          createdAt: partner.user.created_at,
        };
      }
    }

    // 4. Return formatted data for Flutter app
    return NextResponse.json({
      user: {
        id: authUser.user.id,
        email: authUser.user.email,
        name: authUser.user.user_metadata?.full_name || authUser.user.email?.split('@')[0] || 'User',
        avatarEmoji: authUser.user.user_metadata?.avatar_emoji || '👤',
        createdAt: authUser.user.created_at,
      },
      partner: partnerData,
      couple: coupleData ? {
        id: coupleData.id,
        user1Id: coupleData.user1_id,
        user2Id: coupleData.user2_id,
        createdAt: coupleData.created_at,
      } : null,
    });

  } catch (error: any) {
    console.error('Error in /api/dev/user-data:', error);
    return NextResponse.json(
      { error: 'Internal server error', details: error.message },
      { status: 500 }
    );
  }
}

/**
 * POST /api/dev/reset-games
 * Reset game data for a couple
 */
async function handleResetGames(request: NextRequest) {
  try {
    const body = await request.json();
    let { coupleId } = body;
    const { userId } = body;

    const supabase = createSupabaseAdminClient();

    // If userId provided, look up couple ID
    if (userId && !coupleId) {
      const { data: couple, error: coupleError } = await supabase
        .from('couples')
        .select('id')
        .or(`user1_id.eq.${userId},user2_id.eq.${userId}`)
        .single();

      if (coupleError || !couple) {
        return NextResponse.json(
          { error: 'No couple found for userId', userId },
          { status: 404 }
        );
      }
      coupleId = couple.id;
      console.log(`[reset-games] Looked up couple ID ${coupleId} from userId ${userId}`);
    }

    if (!coupleId) {
      return NextResponse.json(
        { error: 'Either coupleId or userId is required in request body' },
        { status: 400 }
      );
    }

    // Delete quiz_matches for this couple
    const { data: deletedQuizMatches, error: quizError } = await supabase
      .from('quiz_matches')
      .delete()
      .eq('couple_id', coupleId)
      .select('id');

    if (quizError) {
      console.error('Error deleting quiz_matches:', quizError);
    }

    // Delete you_or_me_sessions for this couple
    const { data: deletedYomSessions, error: yomError } = await supabase
      .from('you_or_me_sessions')
      .delete()
      .eq('couple_id', coupleId)
      .select('id');

    if (yomError) {
      console.error('Error deleting you_or_me_sessions:', yomError);
    }

    const quizCount = deletedQuizMatches?.length ?? 0;
    const yomCount = deletedYomSessions?.length ?? 0;

    console.log(`[reset-games] Deleted ${quizCount} quiz matches and ${yomCount} you-or-me sessions for couple ${coupleId}`);

    return NextResponse.json({
      success: true,
      coupleId,
      deleted: {
        quizMatches: quizCount,
        youOrMeSessions: yomCount,
      },
    });

  } catch (error: any) {
    console.error('Error in /api/dev/reset-games:', error);
    return NextResponse.json(
      { error: 'Internal server error', details: error.message },
      { status: 500 }
    );
  }
}

/**
 * POST /api/dev/reset-couple-progress
 * Reset all progress for a couple (comprehensive)
 */
async function handleResetCoupleProgress(request: NextRequest) {
  const client = await getClient();

  try {
    const body = await request.json();
    const { coupleId } = body;

    if (!coupleId) {
      return NextResponse.json(
        { error: 'coupleId required' },
        { status: 400 }
      );
    }

    console.log(`\n🧹 [TEST] Resetting progress for couple: ${coupleId}\n`);

    await client.query('BEGIN');

    const results: Record<string, number> = {};

    // 1. Linked matches & moves
    const linkedMoves = await client.query(
      `DELETE FROM linked_moves
       WHERE match_id IN (SELECT id FROM linked_matches WHERE couple_id = $1)
       RETURNING id`,
      [coupleId]
    );
    results.linkedMoves = linkedMoves.rowCount || 0;

    const linkedMatches = await client.query(
      'DELETE FROM linked_matches WHERE couple_id = $1 RETURNING id',
      [coupleId]
    );
    results.linkedMatches = linkedMatches.rowCount || 0;

    // 2. Word search matches & moves
    const wsMoves = await client.query(
      `DELETE FROM word_search_moves
       WHERE match_id IN (SELECT id FROM word_search_matches WHERE couple_id = $1)
       RETURNING id`,
      [coupleId]
    );
    results.wordSearchMoves = wsMoves.rowCount || 0;

    const wsMatches = await client.query(
      'DELETE FROM word_search_matches WHERE couple_id = $1 RETURNING id',
      [coupleId]
    );
    results.wordSearchMatches = wsMatches.rowCount || 0;

    // 3. Quiz matches
    const quizMatches = await client.query(
      'DELETE FROM quiz_matches WHERE couple_id = $1 RETURNING id',
      [coupleId]
    );
    results.quizMatches = quizMatches.rowCount || 0;

    // 4. You-or-Me progression
    const yomProg = await client.query(
      'DELETE FROM you_or_me_progression WHERE couple_id = $1 RETURNING couple_id',
      [coupleId]
    );
    results.youOrMeProgression = yomProg.rowCount || 0;

    // 5. Branch progression
    const branchProg = await client.query(
      'DELETE FROM branch_progression WHERE couple_id = $1 RETURNING id',
      [coupleId]
    );
    results.branchProgression = branchProg.rowCount || 0;

    // 6. Quiz progression
    const quizProg = await client.query(
      'DELETE FROM quiz_progression WHERE couple_id = $1 RETURNING couple_id',
      [coupleId]
    );
    results.quizProgression = quizProg.rowCount || 0;

    // 7. Daily quests & completions
    const completions = await client.query(
      `DELETE FROM quest_completions
       WHERE quest_id IN (SELECT id FROM daily_quests WHERE couple_id = $1)
       RETURNING quest_id`,
      [coupleId]
    );
    results.questCompletions = completions.rowCount || 0;

    const quests = await client.query(
      'DELETE FROM daily_quests WHERE couple_id = $1 RETURNING id',
      [coupleId]
    );
    results.dailyQuests = quests.rowCount || 0;

    // 8. Love point awards (deprecated table)
    const lpAwards = await client.query(
      'DELETE FROM love_point_awards WHERE couple_id = $1 RETURNING id',
      [coupleId]
    );
    results.lovePointAwards = lpAwards.rowCount || 0;

    // 9. Love point transactions (get user IDs first)
    const coupleUsers = await client.query(
      'SELECT user1_id, user2_id FROM couples WHERE id = $1',
      [coupleId]
    );

    if (coupleUsers.rows.length > 0) {
      const { user1_id, user2_id } = coupleUsers.rows[0];
      const lpTxns = await client.query(
        'DELETE FROM love_point_transactions WHERE user_id IN ($1, $2) RETURNING id',
        [user1_id, user2_id]
      );
      results.lovePointTransactions = lpTxns.rowCount || 0;
    }

    // 10. Reset couple's total_lp to 0
    await client.query(
      'UPDATE couples SET total_lp = 0 WHERE id = $1',
      [coupleId]
    );
    results.lpReset = 1;

    // 11. Leaderboard entry
    const leaderboard = await client.query(
      'DELETE FROM couple_leaderboard WHERE couple_id = $1 RETURNING couple_id',
      [coupleId]
    );
    results.leaderboard = leaderboard.rowCount || 0;

    await client.query('COMMIT');

    console.log('✅ [TEST] Reset complete:', results);

    return NextResponse.json({
      success: true,
      coupleId,
      deleted: results,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ [TEST] Reset failed:', error);
    return NextResponse.json(
      { error: 'Failed to reset couple progress' },
      { status: 500 }
    );
  } finally {
    client.release();
  }
}

/**
 * POST /api/dev/complete-games
 * Complete games with dummy answers
 */
async function handleCompleteGames(request: NextRequest) {
  try {
    const body = await request.json();
    const {
      localDate = new Date().toISOString().split('T')[0],
      gameTypes = ['classic', 'affirmation', 'you_or_me', 'linked', 'word_search'],
    } = body;

    // Get user from dev bypass header (X-Dev-User-Id)
    const userId = request.headers.get('X-Dev-User-Id');
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

/**
 * POST /api/dev/update-password
 * Update user password for dev sign-in
 */
async function handleUpdatePassword(request: NextRequest) {
  try {
    const body = await request.json();
    const { email, password } = body;

    if (!email || !password) {
      return NextResponse.json(
        { error: 'email and password are required' },
        { status: 400 }
      );
    }

    console.log(`[DEV] Updating password for: ${email}`);

    const supabase = createSupabaseAdminClient();

    // 1. Find user by email
    const { data: users, error: listError } = await supabase.auth.admin.listUsers();

    if (listError) {
      console.error('[DEV] Error listing users:', listError);
      return NextResponse.json(
        { error: 'Failed to list users', details: listError.message },
        { status: 500 }
      );
    }

    const user = users.users.find(u => u.email?.toLowerCase() === email.toLowerCase());

    if (!user) {
      console.log(`[DEV] User not found: ${email}`);
      return NextResponse.json(
        { error: 'User not found', email },
        { status: 404 }
      );
    }

    console.log(`[DEV] Found user: ${user.id}`);

    // 2. Update user's password using admin API
    const { data: updatedUser, error: updateError } = await supabase.auth.admin.updateUserById(
      user.id,
      {
        password,
        email_confirm: true, // Also confirm email to ensure sign-in works
      }
    );

    if (updateError) {
      console.error('[DEV] Error updating password:', updateError);
      return NextResponse.json(
        { error: 'Failed to update password', details: updateError.message },
        { status: 500 }
      );
    }

    console.log(`[DEV] Password updated successfully for: ${email}`);

    return NextResponse.json({
      success: true,
      userId: updatedUser.user.id,
      email: updatedUser.user.email,
      message: 'Password updated - you can now sign in',
    });

  } catch (error: any) {
    console.error('[DEV] Error in /api/dev/update-password:', error);
    return NextResponse.json(
      { error: 'Internal server error', details: error.message },
      { status: 500 }
    );
  }
}

// ============================================================================
// Exported Router Functions
// ============================================================================

/**
 * Routes GET requests to dev endpoints
 * @param req - NextRequest object
 * @param subPath - Array of path segments (e.g., ['user-data'])
 */
export async function routeDevGET(req: NextRequest, subPath: string[]): Promise<NextResponse> {
  // Security check
  if (!isDevModeEnabled) {
    return NextResponse.json(
      { error: 'Dev endpoints disabled in production' },
      { status: 403 }
    );
  }

  const path = subPath[0];

  // Route to appropriate handler
  switch (path) {
    case 'user-data':
      return handleUserData(req);
    default:
      return NextResponse.json(
        { error: `GET method not supported for /api/dev/${path}` },
        { status: 405 }
      );
  }
}

/**
 * Routes POST requests to dev endpoints
 * @param req - NextRequest object
 * @param subPath - Array of path segments (e.g., ['reset-games'])
 */
export async function routeDevPOST(req: NextRequest, subPath: string[]): Promise<NextResponse> {
  // Security check
  if (!isDevModeEnabled) {
    return NextResponse.json(
      { error: 'Dev endpoints disabled in production' },
      { status: 403 }
    );
  }

  const path = subPath[0];

  // Route to appropriate handler
  switch (path) {
    case 'reset-games':
      return handleResetGames(req);
    case 'reset-couple-progress':
      return handleResetCoupleProgress(req);
    case 'complete-games':
      return handleCompleteGames(req);
    case 'update-password':
      return handleUpdatePassword(req);
    default:
      return NextResponse.json(
        { error: `POST method not supported for /api/dev/${path}` },
        { status: 405 }
      );
  }
}

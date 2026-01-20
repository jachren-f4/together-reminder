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
import { getCouple, getCoupleBasic } from '@/lib/couple/utils';
import {
  loadPuzzle,
  getCurrentBranch,
  getNextPuzzle,
} from '@/lib/puzzle/loader';
import { getCooldownStatus, COOLDOWN_HOURS } from '@/lib/magnets/cooldowns';

export const dynamic = 'force-dynamic';

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
 * Uses magnet cooldown system (2 plays, then 8h cooldown).
 */
export const POST = withAuthOrDevBypass(async (req, userId, email) => {
  try {
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

    // If no active match, check magnet cooldown (8h cooldown after 2 plays)
    if (!activeMatch) {
      const cooldownStatus = await getCooldownStatus(coupleId, 'wordsearch');
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
          couple_id, puzzle_id, branch, status, found_words,
          current_turn_user_id, turn_number, words_found_this_turn,
          player1_words_found, player2_words_found,
          player1_hints, player2_hints,
          player1_id, player2_id, created_at
        )
        VALUES ($1, $2, $3, 'active', '[]', $4, 1, 0, 0, 0, 3, 3, $5, $6, NOW())
        RETURNING *`,
        [coupleId, puzzleId, branch, firstPlayer, user1Id, user2Id]
      );

      match = insertResult.rows[0];
    }

    // Calculate game state for response
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
    const isMyTurn = match.current_turn_user_id === userId;
    const foundWords = typeof match.found_words === 'string'
      ? JSON.parse(match.found_words)
      : match.found_words || [];

    // Use the branch stored with the match
    const branch = match.branch || 'casual';

    // Load puzzle for client from the match's branch
    const puzzle = loadPuzzle('wordSearch', match.puzzle_id, branch);

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

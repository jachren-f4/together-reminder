/**
 * Memory Flip Puzzle State Endpoint
 *
 * Retrieves current state of a Memory Flip puzzle
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';

export const dynamic = 'force-dynamic';

/**
 * Get current puzzle state
 *
 * GET /api/sync/memory-flip/:puzzleId
 */
export const GET = withAuthOrDevBypass(async (req: NextRequest, userId, email) => {
  try {
    // Extract puzzleId from URL path
    const url = new URL(req.url);
    const pathParts = url.pathname.split('/');
    const puzzleId = pathParts[pathParts.length - 1];

    if (!puzzleId) {
      return NextResponse.json(
        { error: 'Puzzle ID is required' },
        { status: 400 }
      );
    }

    // Get puzzle state
    const puzzleResult = await query(
      `SELECT mp.*, c.user1_id, c.user2_id
       FROM memory_puzzles mp
       JOIN couples c ON mp.couple_id = c.id
       WHERE mp.id = $1
         AND (c.user1_id = $2 OR c.user2_id = $2)`,
      [puzzleId, userId]
    );

    if (puzzleResult.rows.length === 0) {
      return NextResponse.json(
        { error: 'Puzzle not found' },
        { status: 404 }
      );
    }

    const puzzle = puzzleResult.rows[0];

    // Determine if user is player1 or player2
    const isPlayer1 = userId === puzzle.user1_id;

    // Check and recharge flips inline (since DB function may not exist yet)
    let myFlipsRemaining = isPlayer1 ? (puzzle.player1_flips_remaining || 6) : (puzzle.player2_flips_remaining || 6);
    const myFlipsResetAt = isPlayer1 ? puzzle.player1_flips_reset_at : puzzle.player2_flips_reset_at;

    // Recharge flips if timer has passed
    if (myFlipsRemaining === 0 && myFlipsResetAt && new Date(myFlipsResetAt) <= new Date()) {
      myFlipsRemaining = 6;
      // Update in database
      const updateField = isPlayer1 ? 'player1_flips_remaining' : 'player2_flips_remaining';
      const resetField = isPlayer1 ? 'player1_flips_reset_at' : 'player2_flips_reset_at';
      await query(
        `UPDATE memory_puzzles SET ${updateField} = 6, ${resetField} = NULL WHERE id = $1`,
        [puzzleId]
      );
    }

    // Get recent moves (without metadata lookup for now)
    let moves: any[] = [];
    try {
      const movesResult = await query(
        `SELECT * FROM memory_moves WHERE puzzle_id = $1 ORDER BY created_at DESC LIMIT 10`,
        [puzzleId]
      );
      moves = movesResult.rows;
    } catch (e) {
      // memory_moves table might not exist yet
      console.log('Note: memory_moves table may not exist yet');
    }

    // Determine if it's the user's turn
    const isMyTurn = puzzle.current_player_id === userId;

    // Calculate time until flip reset
    let timeUntilFlipReset = null;
    if (isPlayer1 && puzzle.player1_flips_reset_at) {
      const resetTime = new Date(puzzle.player1_flips_reset_at).getTime();
      const now = Date.now();
      if (resetTime > now) {
        timeUntilFlipReset = Math.floor((resetTime - now) / 1000); // seconds
      }
    } else if (!isPlayer1 && puzzle.player2_flips_reset_at) {
      const resetTime = new Date(puzzle.player2_flips_reset_at).getTime();
      const now = Date.now();
      if (resetTime > now) {
        timeUntilFlipReset = Math.floor((resetTime - now) / 1000); // seconds
      }
    }

    // Can play if it's their turn and they have flips
    const canPlay = isMyTurn && myFlipsRemaining >= 2 && puzzle.game_phase === 'active';

    // Format response
    return NextResponse.json({
      puzzle: {
        id: puzzle.id,
        createdAt: puzzle.created_at,
        expiresAt: puzzle.expires_at,
        currentPlayerId: puzzle.current_player_id,
        turnNumber: puzzle.turn_number,
        turnStartedAt: puzzle.turn_started_at,
        turnExpiresAt: puzzle.turn_expires_at,
        gamePhase: puzzle.game_phase || 'waiting',
        totalPairs: puzzle.total_pairs,
        matchedPairs: puzzle.matched_pairs || 0,
        player1Pairs: puzzle.player1_pairs || 0,
        player2Pairs: puzzle.player2_pairs || 0,
        cards: typeof puzzle.cards === 'string' ? JSON.parse(puzzle.cards || '[]') : (puzzle.cards || []),
        player1FlipsRemaining: puzzle.player1_flips_remaining || 6,
        player1FlipsResetAt: puzzle.player1_flips_reset_at,
        player2FlipsRemaining: puzzle.player2_flips_remaining || 6,
        player2FlipsResetAt: puzzle.player2_flips_reset_at,
        status: puzzle.status,
        completedAt: puzzle.completed_at
      },
      moves: moves.map((move: any) => ({
        turnNumber: move.turn_number,
        playerId: move.player_id,
        matchFound: move.match_found,
        pairId: move.pair_id,
        createdAt: move.created_at
      })),
      isMyTurn,
      canPlay,
      myFlipsRemaining,
      timeUntilFlipReset
    });

  } catch (error) {
    console.error('Error fetching Memory Flip puzzle:', error);
    return NextResponse.json(
      { error: 'Failed to fetch puzzle state' },
      { status: 500 }
    );
  }
});
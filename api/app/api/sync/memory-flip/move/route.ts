/**
 * Memory Flip Move Validation Endpoint
 *
 * Handles turn-based move submission and validation for Memory Flip game
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query, getClient } from '@/lib/db/pool';

export const dynamic = 'force-dynamic';

/**
 * Submit a move (flip 2 cards) in turn-based Memory Flip
 *
 * POST /api/sync/memory-flip/move
 * Body: {
 *   puzzleId: string,
 *   card1Id: string,
 *   card2Id: string
 * }
 */
export const POST = withAuthOrDevBypass(async (req, userId, email) => {
  const client = await getClient();

  try {
    await client.query('BEGIN');

    const body = await req.json();
    const { puzzleId, card1Id, card2Id } = body;

    // Validate required fields
    if (!puzzleId || !card1Id || !card2Id) {
      await client.query('ROLLBACK');
      return NextResponse.json(
        { success: false, error: 'MISSING_FIELDS' },
        { status: 400 }
      );
    }

    // Get puzzle state with lock for update
    const puzzleResult = await client.query(
      `SELECT mp.*, c.user1_id, c.user2_id
       FROM memory_puzzles mp
       JOIN couples c ON mp.couple_id = c.id
       WHERE mp.id = $1
       FOR UPDATE`,
      [puzzleId]
    );

    if (puzzleResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return NextResponse.json(
        { success: false, error: 'PUZZLE_NOT_FOUND' },
        { status: 404 }
      );
    }

    const puzzle = puzzleResult.rows[0];

    // Validate game is active
    if (puzzle.game_phase !== 'active' && puzzle.game_phase !== 'waiting') {
      await client.query('ROLLBACK');
      return NextResponse.json(
        { success: false, error: 'GAME_NOT_ACTIVE' },
        { status: 400 }
      );
    }

    // If game is waiting, initialize it
    if (puzzle.game_phase === 'waiting') {
      // Determine first player (alphabetically by user ID)
      const firstPlayer = puzzle.user1_id < puzzle.user2_id
        ? puzzle.user1_id
        : puzzle.user2_id;

      await client.query(
        `UPDATE memory_puzzles
         SET game_phase = 'active',
             current_player_id = $1,
             turn_number = 1,
             turn_started_at = NOW(),
             turn_expires_at = NOW() + INTERVAL '5 hours'
         WHERE id = $2`,
        [firstPlayer, puzzleId]
      );

      puzzle.current_player_id = firstPlayer;
      puzzle.turn_number = 1;
      puzzle.game_phase = 'active';
    }

    // Check if it's the player's turn
    if (puzzle.current_player_id !== userId) {
      await client.query('ROLLBACK');
      return NextResponse.json(
        {
          success: false,
          error: 'NOT_YOUR_TURN',
          currentPlayerId: puzzle.current_player_id,
          turnExpiresAt: puzzle.turn_expires_at
        },
        { status: 403 }
      );
    }

    // Check turn timeout
    if (puzzle.turn_expires_at && new Date(puzzle.turn_expires_at) < new Date()) {
      // Auto-advance turn inline
      const nextPlayer = puzzle.current_player_id === puzzle.user1_id
        ? puzzle.user2_id
        : puzzle.user1_id;
      await client.query(
        `UPDATE memory_puzzles SET
          current_player_id = $1,
          turn_number = turn_number + 1,
          turn_started_at = NOW(),
          turn_expires_at = NOW() + INTERVAL '5 hours'
         WHERE id = $2`,
        [nextPlayer, puzzleId]
      );

      await client.query('COMMIT');
      return NextResponse.json(
        {
          success: false,
          error: 'TURN_EXPIRED',
          message: 'Turn has expired and was advanced to the other player'
        },
        { status: 403 }
      );
    }

    // Check and recharge flips inline (database function may not exist)
    const isPlayer1ForFlips = userId === puzzle.user1_id;
    let flipsRemaining = isPlayer1ForFlips
      ? (puzzle.player1_flips_remaining ?? 6)
      : (puzzle.player2_flips_remaining ?? 6);
    const flipsResetAt = isPlayer1ForFlips
      ? puzzle.player1_flips_reset_at
      : puzzle.player2_flips_reset_at;

    // Recharge flips if timer has passed
    if (flipsRemaining === 0 && flipsResetAt && new Date(flipsResetAt) <= new Date()) {
      flipsRemaining = 6;
      const updateField = isPlayer1ForFlips ? 'player1_flips_remaining' : 'player2_flips_remaining';
      const resetField = isPlayer1ForFlips ? 'player1_flips_reset_at' : 'player2_flips_reset_at';
      await client.query(
        `UPDATE memory_puzzles SET ${updateField} = 6, ${resetField} = NULL WHERE id = $1`,
        [puzzleId]
      );
    }

    // Check if player has enough flips
    if (flipsRemaining < 2) {
      await client.query('ROLLBACK');
      return NextResponse.json(
        {
          success: false,
          error: 'INSUFFICIENT_FLIPS',
          flipsRemaining,
          message: 'You need at least 2 flips to make a move'
        },
        { status: 403 }
      );
    }

    // Parse cards if it's a string, otherwise use as-is
    const cards = typeof puzzle.cards === 'string' ? JSON.parse(puzzle.cards) : puzzle.cards;
    const card1 = cards.find((c: any) => c.id === card1Id);
    const card2 = cards.find((c: any) => c.id === card2Id);

    if (!card1 || !card2) {
      await client.query('ROLLBACK');
      return NextResponse.json(
        { success: false, error: 'INVALID_CARDS' },
        { status: 400 }
      );
    }

    if (card1.status === 'matched' || card2.status === 'matched') {
      await client.query('ROLLBACK');
      return NextResponse.json(
        { success: false, error: 'CARD_ALREADY_MATCHED' },
        { status: 400 }
      );
    }

    // Check if cards match
    const matchFound = card1.pairId === card2.pairId;

    // Update cards if match found
    if (matchFound) {
      card1.status = 'matched';
      card2.status = 'matched';

      // Update scores
      const isPlayer1 = userId === puzzle.user1_id;
      if (isPlayer1) {
        puzzle.player1_pairs = (puzzle.player1_pairs || 0) + 1;
      } else {
        puzzle.player2_pairs = (puzzle.player2_pairs || 0) + 1;
      }

      puzzle.matched_pairs = (puzzle.matched_pairs || 0) + 1;
    }

    // Deduct flips from the player
    const isPlayer1 = userId === puzzle.user1_id;
    const newFlipsRemaining = flipsRemaining - 2;

    if (isPlayer1) {
      puzzle.player1_flips_remaining = newFlipsRemaining;
      // Set reset timer if flips exhausted
      if (newFlipsRemaining === 0 && !puzzle.player1_flips_reset_at) {
        puzzle.player1_flips_reset_at = new Date(Date.now() + 5 * 60 * 60 * 1000); // 5 hours
      }
    } else {
      puzzle.player2_flips_remaining = newFlipsRemaining;
      // Set reset timer if flips exhausted
      if (newFlipsRemaining === 0 && !puzzle.player2_flips_reset_at) {
        puzzle.player2_flips_reset_at = new Date(Date.now() + 5 * 60 * 60 * 1000); // 5 hours
      }
    }

    // Check if game is completed
    const gameCompleted = puzzle.matched_pairs >= puzzle.total_pairs ||
                         (puzzle.player1_flips_remaining === 0 &&
                          puzzle.player2_flips_remaining === 0);

    if (gameCompleted) {
      puzzle.game_phase = 'completed';
      puzzle.status = 'completed';
      puzzle.completed_at = new Date().toISOString();
    }

    // Always advance turn after a move (no bonus turns)
    const nextPlayerId = userId === puzzle.user1_id ? puzzle.user2_id : puzzle.user1_id;

    // Update puzzle in database
    const updateResult = await client.query(
      `UPDATE memory_puzzles SET
        cards = $1,
        matched_pairs = $2,
        player1_pairs = $3,
        player2_pairs = $4,
        player1_flips_remaining = $5,
        player1_flips_reset_at = $6,
        player2_flips_remaining = $7,
        player2_flips_reset_at = $8,
        current_player_id = $9,
        turn_number = turn_number + 1,
        turn_started_at = NOW(),
        turn_expires_at = NOW() + INTERVAL '5 hours',
        game_phase = $10,
        status = $11,
        completed_at = $12
       WHERE id = $13
       RETURNING *`,
      [
        JSON.stringify(cards),
        puzzle.matched_pairs,
        puzzle.player1_pairs || 0,
        puzzle.player2_pairs || 0,
        puzzle.player1_flips_remaining,
        puzzle.player1_flips_reset_at,
        puzzle.player2_flips_remaining,
        puzzle.player2_flips_reset_at,
        gameCompleted ? null : nextPlayerId,
        puzzle.game_phase,
        puzzle.status,
        puzzle.completed_at,
        puzzleId
      ]
    );

    // Record the move in memory_moves table
    await client.query(
      `INSERT INTO memory_moves (
        puzzle_id, player_id, card1_id, card2_id,
        card1_position, card2_position, match_found,
        pair_id, turn_number, flips_remaining_after
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
      [
        puzzleId,
        userId,
        card1Id,
        card2Id,
        cards.findIndex((c: any) => c.id === card1Id),
        cards.findIndex((c: any) => c.id === card2Id),
        matchFound,
        matchFound ? card1.pairId : null,
        puzzle.turn_number,
        newFlipsRemaining
      ]
    );

    await client.query('COMMIT');

    const updatedPuzzle = updateResult.rows[0];

    // Return response
    return NextResponse.json({
      success: true,
      matchFound,
      turnAdvanced: !gameCompleted,
      nextPlayerId: gameCompleted ? null : nextPlayerId,
      gameCompleted,
      puzzle: {
        id: updatedPuzzle.id,
        currentPlayerId: updatedPuzzle.current_player_id,
        turnNumber: updatedPuzzle.turn_number,
        player1Pairs: updatedPuzzle.player1_pairs || 0,
        player2Pairs: updatedPuzzle.player2_pairs || 0,
        matchedPairs: updatedPuzzle.matched_pairs,
        totalPairs: updatedPuzzle.total_pairs,
        cards: typeof updatedPuzzle.cards === 'string' ? JSON.parse(updatedPuzzle.cards) : updatedPuzzle.cards,
        gamePhase: updatedPuzzle.game_phase,
        status: updatedPuzzle.status
      },
      playerFlipsRemaining: newFlipsRemaining,
      partnerFlipsRemaining: isPlayer1
        ? puzzle.player2_flips_remaining
        : puzzle.player1_flips_remaining
    });

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error processing Memory Flip move:', error);
    return NextResponse.json(
      { success: false, error: 'INTERNAL_ERROR' },
      { status: 500 }
    );
  } finally {
    client.release();
  }
});
/**
 * Memory Flip API Endpoint
 *
 * Server-side puzzle creation and retrieval
 * POST: Create or return existing puzzle for today
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';

export const dynamic = 'force-dynamic';

// Emoji pairs for puzzle generation (server-side)
const EMOJI_PAIRS = [
  '🌸', '💐', '🌹', '❤️', '💕', '💖', '💍', '💎',
  '🌙', '⭐', '🌟', '✨', '🌈', '☀️', '☕', '🍕',
  '🍝', '🍷', '🍰', '🎵', '🎶', '🎬', '📚', '📖',
  '🎨', '🎭', '🎮', '📷', '🌴', '🏔️', '🏖️', '✈️',
];

const COMPLETION_QUOTES = [
  'Together, we make the perfect match',
  'Every memory with you is a treasure',
  'You complete me in every way',
  'Our love story keeps getting better',
  'Two hearts, one beautiful journey',
];

const DEFAULT_PAIR_COUNT = 8; // 8 pairs = 16 cards (4×4 grid)
const FLIPS_PER_RECHARGE = 6;

/**
 * Generate puzzle cards server-side
 */
function generateCards(puzzleId: string, pairCount: number): any[] {
  // Shuffle and pick emojis
  const shuffledEmojis = [...EMOJI_PAIRS].sort(() => Math.random() - 0.5);
  const selectedEmojis = shuffledEmojis.slice(0, pairCount);

  const cards: any[] = [];

  // Create 2 cards per emoji
  for (let i = 0; i < selectedEmojis.length; i++) {
    const emoji = selectedEmojis[i];
    const pairId = `pair-${i}`;

    cards.push({
      id: `card-${i * 2}`,
      emoji,
      pairId,
      status: 'hidden',
      position: i * 2,
    });

    cards.push({
      id: `card-${i * 2 + 1}`,
      emoji,
      pairId,
      status: 'hidden',
      position: i * 2 + 1,
    });
  }

  // Shuffle card positions
  cards.sort(() => Math.random() - 0.5);
  cards.forEach((card, idx) => { card.position = idx; });

  return cards;
}

/**
 * POST /api/sync/memory-flip
 *
 * Creates a new puzzle for today if none exists, or returns existing puzzle.
 * This is the single source of truth - no client-side generation.
 */
export const POST = withAuthOrDevBypass(async (req, userId, email) => {
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
    const today = new Date().toISOString().substring(0, 10);
    const puzzleId = `puzzle_${today}`;

    // Check if puzzle exists for today
    const existingResult = await query(
      `SELECT * FROM memory_puzzles WHERE couple_id = $1 AND date = $2 LIMIT 1`,
      [coupleId, today]
    );

    let puzzle;
    let isNewPuzzle = false;

    if (existingResult.rows.length > 0) {
      // Return existing puzzle
      puzzle = existingResult.rows[0];
    } else {
      // Create new puzzle server-side
      isNewPuzzle = true;
      const cards = generateCards(puzzleId, DEFAULT_PAIR_COUNT);
      const completionQuote = COMPLETION_QUOTES[Math.floor(Math.random() * COMPLETION_QUOTES.length)];

      // Determine first player (alphabetically by user ID for consistency)
      const firstPlayer = user1_id < user2_id ? user1_id : user2_id;

      const insertResult = await query(
        `INSERT INTO memory_puzzles (
          id, couple_id, date, total_pairs, matched_pairs, cards,
          status, game_phase, completion_quote, created_at,
          current_player_id, turn_number, turn_started_at, turn_expires_at,
          player1_flips_remaining, player2_flips_remaining,
          player1_pairs, player2_pairs
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW(), $10, 1, NOW(), NOW() + INTERVAL '5 hours', $11, $11, 0, 0)
        RETURNING *`,
        [
          puzzleId, coupleId, today, DEFAULT_PAIR_COUNT, 0, JSON.stringify(cards),
          'active', 'active', completionQuote, firstPlayer, FLIPS_PER_RECHARGE
        ]
      );

      puzzle = insertResult.rows[0];
    }

    // Calculate game state for response
    const isPlayer1 = userId === user1_id;
    const isMyTurn = puzzle.current_player_id === userId;
    const myFlipsRemaining = isPlayer1
      ? (puzzle.player1_flips_remaining ?? FLIPS_PER_RECHARGE)
      : (puzzle.player2_flips_remaining ?? FLIPS_PER_RECHARGE);
    const partnerFlipsRemaining = isPlayer1
      ? (puzzle.player2_flips_remaining ?? FLIPS_PER_RECHARGE)
      : (puzzle.player1_flips_remaining ?? FLIPS_PER_RECHARGE);

    // Calculate time until turn expires
    let timeUntilTurnExpires = null;
    if (puzzle.turn_expires_at) {
      const expiresAt = new Date(puzzle.turn_expires_at);
      const now = new Date();
      timeUntilTurnExpires = Math.max(0, Math.floor((expiresAt.getTime() - now.getTime()) / 1000));
    }

    // Parse cards if stored as string
    const cards = typeof puzzle.cards === 'string' ? JSON.parse(puzzle.cards) : puzzle.cards;

    return NextResponse.json({
      success: true,
      isNewPuzzle,
      puzzle: {
        id: puzzle.id,
        date: puzzle.date,
        totalPairs: puzzle.total_pairs,
        matchedPairs: puzzle.matched_pairs,
        cards,
        status: puzzle.status,
        gamePhase: puzzle.game_phase,
        completionQuote: puzzle.completion_quote,
        createdAt: puzzle.created_at,
        completedAt: puzzle.completed_at,
        currentPlayerId: puzzle.current_player_id,
        turnNumber: puzzle.turn_number,
        player1Pairs: puzzle.player1_pairs || 0,
        player2Pairs: puzzle.player2_pairs || 0,
      },
      gameState: {
        isMyTurn,
        canPlay: isMyTurn && myFlipsRemaining >= 2 && puzzle.status === 'active',
        myFlipsRemaining,
        partnerFlipsRemaining,
        timeUntilTurnExpires,
        myPairs: isPlayer1 ? (puzzle.player1_pairs || 0) : (puzzle.player2_pairs || 0),
        partnerPairs: isPlayer1 ? (puzzle.player2_pairs || 0) : (puzzle.player1_pairs || 0),
      }
    });
  } catch (error) {
    console.error('Error in Memory Flip API:', error);
    return NextResponse.json(
      { error: 'Failed to get/create puzzle' },
      { status: 500 }
    );
  }
});

/**
 * GET /api/sync/memory-flip
 *
 * Get current puzzle state (same as POST but doesn't create)
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
    const today = new Date().toISOString().substring(0, 10);

    // Get today's puzzle
    const result = await query(
      `SELECT * FROM memory_puzzles WHERE couple_id = $1 AND date = $2 LIMIT 1`,
      [coupleId, today]
    );

    if (result.rows.length === 0) {
      return NextResponse.json(
        { error: 'No puzzle found for today', code: 'NO_PUZZLE' },
        { status: 404 }
      );
    }

    const puzzle = result.rows[0];
    const isPlayer1 = userId === user1_id;
    const isMyTurn = puzzle.current_player_id === userId;
    const myFlipsRemaining = isPlayer1
      ? (puzzle.player1_flips_remaining ?? FLIPS_PER_RECHARGE)
      : (puzzle.player2_flips_remaining ?? FLIPS_PER_RECHARGE);

    let timeUntilTurnExpires = null;
    if (puzzle.turn_expires_at) {
      const expiresAt = new Date(puzzle.turn_expires_at);
      const now = new Date();
      timeUntilTurnExpires = Math.max(0, Math.floor((expiresAt.getTime() - now.getTime()) / 1000));
    }

    const cards = typeof puzzle.cards === 'string' ? JSON.parse(puzzle.cards) : puzzle.cards;

    return NextResponse.json({
      success: true,
      puzzle: {
        id: puzzle.id,
        date: puzzle.date,
        totalPairs: puzzle.total_pairs,
        matchedPairs: puzzle.matched_pairs,
        cards,
        status: puzzle.status,
        gamePhase: puzzle.game_phase,
        completionQuote: puzzle.completion_quote,
        createdAt: puzzle.created_at,
        completedAt: puzzle.completed_at,
        currentPlayerId: puzzle.current_player_id,
        turnNumber: puzzle.turn_number,
        player1Pairs: puzzle.player1_pairs || 0,
        player2Pairs: puzzle.player2_pairs || 0,
      },
      gameState: {
        isMyTurn,
        canPlay: isMyTurn && myFlipsRemaining >= 2 && puzzle.status === 'active',
        myFlipsRemaining,
        partnerFlipsRemaining: isPlayer1
          ? (puzzle.player2_flips_remaining ?? FLIPS_PER_RECHARGE)
          : (puzzle.player1_flips_remaining ?? FLIPS_PER_RECHARGE),
        timeUntilTurnExpires,
        myPairs: isPlayer1 ? (puzzle.player1_pairs || 0) : (puzzle.player2_pairs || 0),
        partnerPairs: isPlayer1 ? (puzzle.player2_pairs || 0) : (puzzle.player1_pairs || 0),
      }
    });
  } catch (error) {
    console.error('Error getting Memory Flip puzzle:', error);
    return NextResponse.json(
      { error: 'Failed to get puzzle' },
      { status: 500 }
    );
  }
});

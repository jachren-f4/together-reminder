/**
 * Linked Game Match State API
 *
 * GET /api/sync/linked/[matchId] - Get specific match state (for polling)
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { readFileSync } from 'fs';
import { join } from 'path';

export const dynamic = 'force-dynamic';

// Load puzzle data
function loadPuzzle(puzzleId: string): any {
  try {
    const puzzlePath = join(process.cwd(), 'data', 'puzzles', `${puzzleId}.json`);
    const puzzleData = readFileSync(puzzlePath, 'utf-8');
    return JSON.parse(puzzleData);
  } catch (error) {
    console.error(`Failed to load puzzle ${puzzleId}:`, error);
    return null;
  }
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

/**
 * GET /api/sync/linked/[matchId]
 *
 * Get specific match state - used for polling during partner's turn
 */
export const GET = withAuthOrDevBypass(async (req, userId, email, { params }) => {
  try {
    // Extract base URL for image paths
    const baseUrl = new URL(req.url).origin;

    const { matchId } = await params;

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
});

/**
 * Linked Game Test Helpers
 *
 * API client and utilities for testing the Linked (crossword) game.
 * Extends BaseTestApi for shared request functionality.
 */

// Re-export shared utilities for convenience
export { TEST_CONFIG, LINKED_CONFIG } from './test-config';
export {
  assert,
  assertEqual,
  assertGte,
  runTest,
  printSummary,
  resetTestData,
  sleep,
  getTodayDate,
} from './test-utils';
export { createTestClients } from './base-test-api';

import { BaseTestApi } from './base-test-api';

// ============================================================================
// Types
// ============================================================================

interface Placement {
  index: number;
  letter: string;
}

interface SubmitResult {
  success: boolean;
  results?: Array<{
    index: number;
    letter: string;
    correct: boolean;
  }>;
  pointsEarned?: number;
  wordBonuses?: Array<{
    word: string;
    points: number;
  }>;
  turnComplete?: boolean;
  gameComplete?: boolean;
  winnerId?: string | null;
}

interface MatchData {
  matchId: string;
  status: string;
  puzzleId: string;
  currentTurnUserId: string;
  currentRack?: Array<{ letter: string; index: number }>;
  player1Score: number;
  player2Score: number;
}

interface GameState {
  isMyTurn: boolean;
  canPlay: boolean;
  myScore: number;
  partnerScore: number;
}

interface PuzzleData {
  grid: Array<{
    type: string;
    letter?: string | null;
    clue?: string;
  }>;
}

interface LinkedMatchResponse {
  success: boolean;
  match: MatchData;
  gameState: GameState;
  puzzle?: PuzzleData;
}

// Combined type for easier test access
interface LinkedMatch extends MatchData {
  gameState?: GameState;
  puzzle?: PuzzleData;
}

// ============================================================================
// Linked Test API Client
// ============================================================================

/**
 * API client for making authenticated requests to the Linked API
 */
export class LinkedTestApi extends BaseTestApi {
  /**
   * Get or create a Linked match for today
   */
  async getOrCreateMatch(): Promise<LinkedMatch> {
    const now = new Date();
    const localDate = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;

    const response = await this.request<LinkedMatchResponse>('POST', '/api/sync/linked', { localDate });
    // Combine match data with gameState and puzzle for easier test access
    return {
      ...response.match,
      gameState: response.gameState,
      puzzle: response.puzzle,
    };
  }

  /**
   * Poll match state by ID
   */
  async pollMatch(matchId: string): Promise<LinkedMatch> {
    const response = await this.request<LinkedMatchResponse>('GET', `/api/sync/linked/${matchId}`);
    return {
      ...response.match,
      gameState: response.gameState,
      puzzle: response.puzzle,
    };
  }

  /**
   * Submit placements for a turn
   */
  async submitTurn(matchId: string, placements: Placement[]): Promise<SubmitResult> {
    return this.request<SubmitResult>('POST', '/api/sync/linked/submit', {
      matchId,
      placements,
    });
  }
}

// ============================================================================
// Linked-Specific Utilities
// ============================================================================

/**
 * Find empty answer cells in a grid
 */
export function findEmptyAnswerCells(
  grid: Array<{ type: string; letter?: string | null }>
): number[] {
  const emptyCells: number[] = [];
  for (let i = 0; i < grid.length; i++) {
    const cell = grid[i];
    if (cell.type === 'answer' && cell.letter == null) {
      emptyCells.push(i);
    }
  }
  return emptyCells;
}

/**
 * Wait for a condition to be true
 */
export async function waitFor(
  condition: () => Promise<boolean>,
  options: { timeout?: number; interval?: number } = {}
): Promise<boolean> {
  const { timeout = 5000, interval = 100 } = options;
  const deadline = Date.now() + timeout;

  while (Date.now() < deadline) {
    if (await condition()) {
      return true;
    }
    await new Promise((resolve) => setTimeout(resolve, interval));
  }

  return false;
}

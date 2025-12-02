/**
 * Word Search Game Test Helpers
 *
 * API client and utilities for testing the Word Search game.
 * Extends BaseTestApi for shared request functionality.
 */

// Re-export shared utilities for convenience
export { TEST_CONFIG, WORD_SEARCH_CONFIG } from './test-config';
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

interface Position {
  row: number;
  col: number;
}

interface WordSubmitResult {
  success: boolean;
  valid: boolean;
  reason?: string;
  pointsEarned?: number;
  wordsFoundThisTurn?: number;
  turnComplete?: boolean;
  gameComplete?: boolean;
  nextTurnUserId?: string | null;
  colorIndex?: number;
  winnerId?: string | null;
  nextBranch?: number | null;
}

interface FoundWord {
  word: string;
  foundByUserId: string;
  turnNumber: number;
  positions: Position[];
  colorIndex: number;
}

interface MatchData {
  matchId: string;
  status: string;
  puzzleId: string;
  foundWords: FoundWord[];
  currentTurnUserId: string;
  turnNumber: number;
  wordsFoundThisTurn: number;
  player1WordsFound: number;
  player2WordsFound: number;
  player1Score: number;
  player2Score: number;
  player1Hints: number;
  player2Hints: number;
  player1Id: string;
  player2Id: string;
  winnerId: string | null;
  createdAt: string;
  completedAt: string | null;
}

interface PuzzleData {
  puzzleId: string;
  title: string;
  theme: string;
  size: { rows: number; cols: number };
  grid: string; // 100-char flat string for 10x10
  words: string[]; // Just the word strings
  wordsWithPositions?: Record<string, string>; // word -> "startIndex,direction"
}

interface GameState {
  isMyTurn: boolean;
  canPlay: boolean;
  wordsRemainingThisTurn: number;
  myWordsFound: number;
  partnerWordsFound: number;
  myScore: number;
  partnerScore: number;
  myHints: number;
  partnerHints: number;
  progressPercent: number;
}

interface WordSearchMatchResponse {
  success: boolean;
  isNewMatch?: boolean;
  match: MatchData;
  puzzle: PuzzleData;
  gameState: GameState;
}

interface CooldownResponse {
  success: false;
  code: 'COOLDOWN_ACTIVE';
  message: string;
  cooldownEnabled: boolean;
}

// Combined type for easier test access
interface WordSearchMatch extends MatchData {
  gameState?: GameState;
  puzzle?: PuzzleData;
}

// ============================================================================
// Word Search Test API Client
// ============================================================================

/**
 * API client for making authenticated requests to the Word Search API
 */
export class WordSearchTestApi extends BaseTestApi {
  /**
   * Get or create a Word Search match for today
   */
  async getOrCreateMatch(): Promise<WordSearchMatch> {
    const now = new Date();
    const localDate = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;

    const response = await this.request<WordSearchMatchResponse | CooldownResponse>('POST', '/api/sync/word-search', { localDate });

    // Handle cooldown response
    if ('code' in response && response.code === 'COOLDOWN_ACTIVE') {
      throw new Error('COOLDOWN_ACTIVE');
    }

    const matchResponse = response as WordSearchMatchResponse;
    // Combine match data with gameState and puzzle for easier test access
    return {
      ...matchResponse.match,
      gameState: matchResponse.gameState,
      puzzle: matchResponse.puzzle,
    };
  }

  /**
   * Poll match state by ID
   */
  async pollMatch(matchId: string): Promise<WordSearchMatch> {
    const response = await this.request<WordSearchMatchResponse>('GET', `/api/sync/word-search/${matchId}`);
    return {
      ...response.match,
      gameState: response.gameState,
      puzzle: response.puzzle,
    };
  }

  /**
   * Submit a word for validation
   */
  async submitWord(matchId: string, word: string, positions: Position[]): Promise<WordSubmitResult> {
    return this.request<WordSubmitResult>('POST', '/api/sync/word-search/submit', {
      matchId,
      word,
      positions,
    });
  }

  /**
   * Use a hint
   */
  async useHint(matchId: string): Promise<{ success: boolean; hint?: Position; word?: string }> {
    return this.request('POST', '/api/sync/word-search/hint', { matchId });
  }
}

// ============================================================================
// Word Search-Specific Utilities
// ============================================================================

// Direction deltas for a 10-column grid
const DIRECTION_DELTAS: Record<string, number> = {
  'R': 1, 'L': -1, 'D': 10, 'U': -10,
  'DR': 11, 'DL': 9, 'UR': -9, 'UL': -11
};

/**
 * Get word positions from position format "startIndex,direction"
 */
export function getWordPositions(positionStr: string, wordLength: number, cols: number = 10): Position[] {
  const [startIndexStr, direction] = positionStr.split(',');
  const startIndex = parseInt(startIndexStr);
  const delta = DIRECTION_DELTAS[direction] || 0;

  return Array.from({ length: wordLength }, (_, i) => {
    const index = startIndex + (i * delta);
    return {
      row: Math.floor(index / cols),
      col: index % cols
    };
  });
}

/**
 * Find an unfound word from the puzzle
 * Returns word and its positions, or null if all words found
 */
export function findUnfoundWord(
  puzzle: PuzzleData,
  foundWords: FoundWord[]
): { word: string; positions: Position[] } | null {
  const foundWordSet = new Set(foundWords.map(fw => fw.word.toUpperCase()));

  // puzzle.words is just strings, but the full puzzle data has word positions
  // We need the wordsWithPositions for positions
  if (!puzzle.wordsWithPositions) {
    // If no positions available, just return word without positions
    for (const word of puzzle.words) {
      if (!foundWordSet.has(word.toUpperCase())) {
        return { word, positions: [] };
      }
    }
    return null;
  }

  for (const [word, positionStr] of Object.entries(puzzle.wordsWithPositions)) {
    if (!foundWordSet.has(word.toUpperCase())) {
      const positions = getWordPositions(positionStr, word.length);
      return { word, positions };
    }
  }

  return null;
}

/**
 * Calculate expected points for a word
 */
export function calculateWordPoints(word: string, pointsPerLetter: number = 10): number {
  return word.length * pointsPerLetter;
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

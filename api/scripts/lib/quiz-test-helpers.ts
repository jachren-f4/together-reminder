/**
 * Classic Quiz Test Helpers
 *
 * API client and utilities for testing the Classic Quiz game.
 * Extends BaseTestApi for shared request functionality.
 */

// Re-export shared utilities for convenience
export { TEST_CONFIG, QUIZ_CONFIG } from './test-config';
export {
  assert,
  assertEqual,
  assertGte,
  runTest,
  printSummary,
  resetTestData,
  sleep,
  getTodayDate,
  generateRandomAnswers,
  generateMatchingAnswers,
  generateNonMatchingAnswers,
  calculateMatchPercentage,
} from './test-utils';
export { createTestClients } from './base-test-api';

import { BaseTestApi } from './base-test-api';
import { getTodayDate } from './test-utils';

// ============================================================================
// Types
// ============================================================================

// Game types supported by the unified API
export type GameType = 'classic' | 'affirmation' | 'you_or_me';

interface GameState {
  canSubmit: boolean;
  userAnswered: boolean;
  partnerAnswered: boolean;
  isCompleted: boolean;
  isMyTurn?: boolean | null;
}

interface QuizQuestion {
  id: string;
  text: string;
  choices: string[];
}

interface Quiz {
  id: string;
  name: string;
  questions: QuizQuestion[];
}

interface MatchData {
  id: string;
  quizId: string;
  quizType: string;
  branch: string;
  status: string;
  date: string;
  createdAt: string;
}

interface GameResult {
  matchPercentage: number;
  lpEarned: number;
  userAnswers: number[];
  partnerAnswers: number[];
}

interface PlayResponse {
  success: boolean;
  match: MatchData;
  state: GameState;
  isNew: boolean;
  quiz?: Quiz;
  result?: GameResult | null;
  bothAnswered: boolean;
  isCompleted: boolean;
}

interface StatusGame {
  type: string;
  matchId: string;
  quizId: string;
  branch: string;
  status: string;
  userAnswered: boolean;
  partnerAnswered: boolean;
  canSubmit: boolean;
  isMyTurn?: boolean;
  isCompleted: boolean;
  matchPercentage?: number;
  lpEarned?: number;
}

interface StatusResponse {
  success: boolean;
  games: StatusGame[];
  totalLp: number;
  userId: string;
  partnerId: string;
  date: string;
}

// ============================================================================
// Quiz Test API Client
// ============================================================================

/**
 * API client for making authenticated requests to the Quiz API
 */
export class QuizTestApi extends BaseTestApi {
  /**
   * Get game status for a specific date
   */
  async getGameStatus(date?: string, type?: GameType): Promise<StatusResponse> {
    const today = date || getTodayDate();
    let path = `/api/sync/game/status?date=${today}`;
    if (type) {
      path += `&type=${type}`;
    }
    return this.request<StatusResponse>('GET', path);
  }

  /**
   * Start a new quiz or get existing match
   */
  async startQuiz(type: GameType, localDate?: string): Promise<PlayResponse> {
    const date = localDate || getTodayDate();
    return this.request<PlayResponse>('POST', `/api/sync/game/${type}/play`, {
      localDate: date,
    });
  }

  /**
   * Submit answers for a quiz
   */
  async submitAnswers(type: GameType, matchId: string, answers: number[]): Promise<PlayResponse> {
    return this.request<PlayResponse>('POST', `/api/sync/game/${type}/play`, {
      matchId,
      answers,
    });
  }

  /**
   * Start and submit answers in one call
   */
  async startAndSubmit(type: GameType, answers: number[], localDate?: string): Promise<PlayResponse> {
    const date = localDate || getTodayDate();
    return this.request<PlayResponse>('POST', `/api/sync/game/${type}/play`, {
      localDate: date,
      answers,
    });
  }

  /**
   * Get match state by matchId
   */
  async getMatchState(type: GameType, matchId: string): Promise<PlayResponse> {
    return this.request<PlayResponse>('POST', `/api/sync/game/${type}/play`, {
      matchId,
    });
  }
}

/**
 * Unified Game Handler
 *
 * Shared utilities for all game types (quiz, you-or-me, etc).
 * Reduces code duplication across game endpoints.
 */

import { query } from '@/lib/db/pool';
import { awardLP } from '@/lib/lp/award';
import {
  tryAwardDailyLpStandalone,
  getLpStatusStandalone,
  gameTypeToContentType,
  LpGrantResult,
} from '@/lib/lp/grant-service';
import { recordActivityPlay, type ActivityType } from '@/lib/magnets';
import { recalculateAndCacheProfile } from '@/lib/us-profile/cache';
import { readFileSync } from 'fs';
import { join } from 'path';

// =============================================================================
// Types
// =============================================================================

export type GameType = 'classic' | 'affirmation' | 'you_or_me';

export interface CoupleInfo {
  coupleId: string;
  user1Id: string;
  user2Id: string;
  firstPlayerId: string | null;
  totalLp: number;
  isPlayer1: boolean;
  partnerId: string;
}

export interface GameMatch {
  id: string;
  quizId: string;
  quizType: GameType;
  branch: string;
  status: 'active' | 'completed';
  player1Answers: number[];
  player2Answers: number[];
  player1AnswerCount: number;
  player2AnswerCount: number;
  matchPercentage: number | null;
  player1Score: number;
  player2Score: number;
  currentTurnUserId: string | null;
  turnNumber: number;
  date: string;
  createdAt: string;
  completedAt: string | null;
}

export interface GameState {
  canSubmit: boolean;
  userAnswered: boolean;
  partnerAnswered: boolean;
  isCompleted: boolean;
  isMyTurn?: boolean;  // for turn-based games
}

export interface GameResult {
  matchPercentage: number;
  lpEarned: number;
  userAnswers: number[];
  partnerAnswers: number[];
  userScore?: number;
  partnerScore?: number;
  // LP Daily Reset status
  alreadyGrantedToday?: boolean;
  resetInMs?: number;
  canPlayMore?: boolean;
}

// =============================================================================
// Configuration
// =============================================================================

const GAME_CONFIG: Record<GameType, {
  branches: string[];
  activityType: string;
  folder: string;
  lpReward: number;
  isTurnBased: boolean;
}> = {
  classic: {
    // First 2 are playful (40%), next 3 are deep/therapeutic (60%)
    branches: ['lighthearted', 'playful', 'connection', 'attachment', 'growth'],
    activityType: 'classicQuiz',  // Match Flutter's BranchableActivityType.classicQuiz.name
    folder: 'classic-quiz',
    lpReward: 30,
    isTurnBased: false,
  },
  affirmation: {
    // First 2 are playful (40%), next 3 are deep/therapeutic (60%)
    branches: ['lighthearted', 'playful', 'connection', 'attachment', 'growth'],
    activityType: 'affirmation',  // Match Flutter's BranchableActivityType.affirmation.name
    folder: 'affirmation',
    lpReward: 30,
    isTurnBased: false,
  },
  you_or_me: {
    // First 2 are playful (40%), next 3 are deep/therapeutic (60%)
    branches: ['lighthearted', 'playful', 'connection', 'attachment', 'growth'],
    activityType: 'youOrMe',  // Match Flutter's BranchableActivityType.youOrMe.name
    folder: 'you-or-me',
    lpReward: 30,
    isTurnBased: true,
  },
};

// =============================================================================
// Couple Utilities
// =============================================================================

export async function getCouple(userId: string): Promise<CoupleInfo | null> {
  const result = await query(
    `SELECT id, user1_id, user2_id, first_player_id, total_lp
     FROM couples
     WHERE user1_id = $1 OR user2_id = $1
     LIMIT 1`,
    [userId]
  );

  if (result.rows.length === 0) {
    console.log(`🎯 getCouple: No couple found for userId=${userId}`);
    return null;
  }

  const row = result.rows[0];
  const isPlayer1 = userId === row.user1_id;

  console.log(`🎯 getCouple: userId=${userId}, coupleId=${row.id}, user1_id=${row.user1_id}, user2_id=${row.user2_id}, isPlayer1=${isPlayer1}`);

  return {
    coupleId: row.id,
    user1Id: row.user1_id,
    user2Id: row.user2_id,
    firstPlayerId: row.first_player_id,
    totalLp: row.total_lp || 0,
    isPlayer1,
    partnerId: isPlayer1 ? row.user2_id : row.user1_id,
  };
}

// =============================================================================
// Quiz Loading
// =============================================================================

export function loadQuiz(gameType: GameType, branch: string, quizId: string): any {
  try {
    const config = GAME_CONFIG[gameType];
    const quizPath = join(process.cwd(), 'data', 'puzzles', config.folder, branch, `${quizId}.json`);
    const quizData = readFileSync(quizPath, 'utf-8');
    const rawQuiz = JSON.parse(quizData);

    // Normalize quiz format to common structure
    // For you_or_me: questions have { id, prompt, content } -> { id, text, choices: [] }
    // For classic/affirmation: questions have { id, text, choices }
    if (gameType === 'you_or_me') {
      return {
        id: rawQuiz.quizId || quizId,
        name: rawQuiz.title || 'You or Me',
        description: rawQuiz.description || null,
        questions: (rawQuiz.questions || []).map((q: any) => ({
          id: q.id,
          // Combine prompt and content into text format expected by Flutter
          text: `${q.prompt}\n${q.content}`,
          choices: ['You', 'Me'], // You or Me always has these two choices
        })),
      };
    }

    // For classic and affirmation, normalize to consistent structure
    // Affirmation uses scaleLabels while classic uses choices - normalize to choices
    const normalizedQuestions = (rawQuiz.questions || []).map((q: any) => ({
      id: q.id,
      text: q.text,
      // Use choices if present, otherwise map scaleLabels to choices
      choices: q.choices || q.scaleLabels || [],
      category: q.category || '',
    }));

    return {
      id: rawQuiz.quizId || rawQuiz.id || quizId,
      name: rawQuiz.title || rawQuiz.name || 'Quiz',
      description: rawQuiz.description || null,
      questions: normalizedQuestions,
    };
  } catch (error) {
    console.error(`Failed to load quiz ${quizId} from ${gameType}/${branch}:`, error);
    return null;
  }
}

export function loadQuizOrder(gameType: GameType, branch: string): string[] {
  try {
    const config = GAME_CONFIG[gameType];
    const orderPath = join(process.cwd(), 'data', 'puzzles', config.folder, branch, 'quiz-order.json');
    const orderData = readFileSync(orderPath, 'utf-8');
    const configData = JSON.parse(orderData);
    return configData.quizzes || [];
  } catch (error) {
    console.error(`Failed to load quiz order for ${gameType}/${branch}:`, error);
    return [];
  }
}

// =============================================================================
// Quiz Info (without creating match)
// =============================================================================

/**
 * Get info about the next quiz that would be played, without creating a match.
 * Used for displaying quiz metadata on home screen before game starts.
 */
export async function getNextQuizInfo(
  coupleId: string,
  gameType: GameType,
  date: string
): Promise<{ quizId: string; branch: string; name: string; description: string | null } | null> {
  try {
    const branch = await getCurrentBranch(coupleId, gameType);

    // Check for existing match today
    const existingResult = await query(
      `SELECT quiz_id, branch FROM quiz_matches
       WHERE couple_id = $1 AND quiz_type = $2 AND date = $3
       ORDER BY created_at DESC LIMIT 1`,
      [coupleId, gameType, date]
    );

    let quizId: string;
    let quizBranch: string;

    if (existingResult.rows.length > 0) {
      // Use existing match's quiz
      quizId = existingResult.rows[0].quiz_id;
      quizBranch = existingResult.rows[0].branch;
    } else {
      // Determine next quiz from progression
      const quizOrder = loadQuizOrder(gameType, branch);
      const completedResult = await query(
        `SELECT DISTINCT quiz_id FROM quiz_matches
         WHERE couple_id = $1 AND quiz_type = $2 AND branch = $3 AND status = 'completed'`,
        [coupleId, gameType, branch]
      );

      const completedQuizzes = new Set(completedResult.rows.map(r => r.quiz_id));
      quizId = quizOrder.find(id => !completedQuizzes.has(id)) || quizOrder[0];
      quizBranch = branch;

      if (!quizId) {
        return null;
      }
    }

    // Load quiz metadata
    const quiz = loadQuiz(gameType, quizBranch, quizId);
    if (!quiz) {
      return null;
    }

    return {
      quizId,
      branch: quizBranch,
      name: quiz.name,
      description: quiz.description,
    };
  } catch (error) {
    console.error(`Failed to get next quiz info for ${gameType}:`, error);
    return null;
  }
}

// =============================================================================
// Branch Management
// =============================================================================

export async function getCurrentBranch(coupleId: string, gameType: GameType): Promise<string> {
  const config = GAME_CONFIG[gameType];

  const result = await query(
    `SELECT current_branch FROM branch_progression
     WHERE couple_id = $1 AND activity_type = $2`,
    [coupleId, config.activityType]
  );

  if (result.rows.length === 0) {
    return config.branches[0];
  }

  const branchIndex = result.rows[0].current_branch;
  return config.branches[branchIndex % config.branches.length];
}

/**
 * Advance branch progression after a game is completed.
 *
 * Formula: current_branch = total_completions % max_branches
 * - After 1st completion: total=1, branch=1%5=1 (playful)
 * - After 2nd completion: total=2, branch=2%5=2 (connection)
 * - After 5th completion: total=5, branch=5%5=0 (back to lighthearted)
 *
 * Uses UPSERT to handle first-time creation vs update.
 */
export async function advanceBranch(coupleId: string, gameType: GameType): Promise<{ newBranch: number; totalCompletions: number }> {
  const config = GAME_CONFIG[gameType];
  const numBranches = config.branches.length;

  return advanceBranchGeneric(coupleId, config.activityType, numBranches);
}

/**
 * Generic branch advancement for any activity type.
 * Used by both quiz games (via advanceBranch) and puzzle games (linked, word_search).
 */
export async function advanceBranchGeneric(
  coupleId: string,
  activityType: string,
  numBranches: number
): Promise<{ newBranch: number; totalCompletions: number }> {
  const result = await query(
    `INSERT INTO branch_progression (couple_id, activity_type, current_branch, total_completions, max_branches)
     VALUES ($1, $2, 1, 1, $3)
     ON CONFLICT (couple_id, activity_type)
     DO UPDATE SET
       total_completions = branch_progression.total_completions + 1,
       current_branch = (branch_progression.total_completions + 1) % $3,
       last_completed_at = NOW(),
       updated_at = NOW()
     RETURNING current_branch, total_completions`,
    [coupleId, activityType, numBranches]
  );

  return {
    newBranch: result.rows[0].current_branch,
    totalCompletions: result.rows[0].total_completions,
  };
}

// =============================================================================
// Match Management
// =============================================================================

export async function getOrCreateMatch(
  couple: CoupleInfo,
  gameType: GameType,
  localDate: string,
  options?: { forceNew?: boolean }
): Promise<{ match: GameMatch; quiz: any; isNew: boolean }> {
  const branch = await getCurrentBranch(couple.coupleId, gameType);
  const config = GAME_CONFIG[gameType];

  // Check for existing active match today (skip if forceNew for dev testing)
  if (!options?.forceNew) {
    const existingResult = await query(
      `SELECT * FROM quiz_matches
       WHERE couple_id = $1 AND quiz_type = $2 AND date = $3 AND status = 'active'
       ORDER BY created_at DESC LIMIT 1`,
      [couple.coupleId, gameType, localDate]
    );

    if (existingResult.rows.length > 0) {
      const match = parseMatch(existingResult.rows[0]);
      const quiz = loadQuiz(gameType, match.branch, match.quizId);
      return { match, quiz, isNew: false };
    }
  }

  // Find next quiz
  const quizOrder = loadQuizOrder(gameType, branch);
  const completedResult = await query(
    `SELECT DISTINCT quiz_id FROM quiz_matches
     WHERE couple_id = $1 AND quiz_type = $2 AND branch = $3 AND status = 'completed'`,
    [couple.coupleId, gameType, branch]
  );

  const completedQuizzes = new Set(completedResult.rows.map(r => r.quiz_id));
  let quizId = quizOrder.find(id => !completedQuizzes.has(id)) || quizOrder[0];

  if (!quizId) {
    throw new Error('No quizzes available');
  }

  const quiz = loadQuiz(gameType, branch, quizId);
  if (!quiz) {
    throw new Error('Quiz not found');
  }

  // Determine first player for turn-based games
  const firstTurnUser = config.isTurnBased
    ? (couple.firstPlayerId || couple.user2Id)
    : null;

  // Create new match
  const insertResult = await query(
    `INSERT INTO quiz_matches (
      couple_id, quiz_id, quiz_type, branch, status,
      player1_answers, player2_answers,
      player1_answer_count, player2_answer_count,
      current_turn_user_id, turn_number,
      player1_id, player2_id, date, created_at
    )
    VALUES ($1, $2, $3, $4, 'active', '[]', '[]', 0, 0, $5, 1, $6, $7, $8, NOW())
    RETURNING *`,
    [couple.coupleId, quizId, gameType, branch, firstTurnUser, couple.user1Id, couple.user2Id, localDate]
  );

  const match = parseMatch(insertResult.rows[0]);
  return { match, quiz, isNew: true };
}

export async function getMatchById(matchId: string): Promise<GameMatch | null> {
  const result = await query(
    `SELECT * FROM quiz_matches WHERE id = $1`,
    [matchId]
  );

  if (result.rows.length === 0) {
    console.log(`🎯 getMatchById: No match found for id=${matchId}`);
    return null;
  }

  const match = parseMatch(result.rows[0]);
  console.log(`🎯 getMatchById: Found match id=${matchId}, status=${match.status}, p1Count=${match.player1AnswerCount}, p2Count=${match.player2AnswerCount}`);
  return match;
}

function parseMatch(row: any): GameMatch {
  return {
    id: row.id,
    quizId: row.quiz_id,
    quizType: row.quiz_type,
    branch: row.branch,
    status: row.status,
    player1Answers: typeof row.player1_answers === 'string'
      ? JSON.parse(row.player1_answers)
      : row.player1_answers || [],
    player2Answers: typeof row.player2_answers === 'string'
      ? JSON.parse(row.player2_answers)
      : row.player2_answers || [],
    player1AnswerCount: row.player1_answer_count || 0,
    player2AnswerCount: row.player2_answer_count || 0,
    matchPercentage: row.match_percentage,
    player1Score: row.player1_score || 0,
    player2Score: row.player2_score || 0,
    currentTurnUserId: row.current_turn_user_id,
    turnNumber: row.turn_number || 1,
    date: row.date,
    createdAt: row.created_at,
    completedAt: row.completed_at,
  };
}

// =============================================================================
// Answer Submission
// =============================================================================

export async function submitAnswers(
  match: GameMatch,
  couple: CoupleInfo,
  answers: number[]
): Promise<{ match: GameMatch; result: GameResult | null }> {
  const config = GAME_CONFIG[match.quizType];

  console.log(`🎯 submitAnswers: matchId=${match.id}, isPlayer1=${couple.isPlayer1}, incomingAnswerCount=${answers.length}`);
  console.log(`🎯 submitAnswers: BEFORE - p1Count=${match.player1AnswerCount}, p2Count=${match.player2AnswerCount}, status=${match.status}`);

  // Check if user already answered
  const userAnswered = couple.isPlayer1
    ? match.player1AnswerCount > 0
    : match.player2AnswerCount > 0;

  if (userAnswered) {
    console.log(`🎯 submitAnswers: User already answered! isPlayer1=${couple.isPlayer1}`);
    throw new Error('Already submitted answers');
  }

  // Update answers
  const updatedPlayer1Answers = couple.isPlayer1 ? answers : match.player1Answers;
  const updatedPlayer2Answers = couple.isPlayer1 ? match.player2Answers : answers;

  console.log(`🎯 submitAnswers: Updated p1Len=${updatedPlayer1Answers.length}, p2Len=${updatedPlayer2Answers.length}`);

  // Check if both answered
  const bothAnswered = updatedPlayer1Answers.length > 0 && updatedPlayer2Answers.length > 0;

  let matchPercentage: number | null = null;
  let lpEarned = 0;
  let newStatus = 'active';
  let lpGrantResult: LpGrantResult | null = null;

  if (bothAnswered) {
    matchPercentage = calculateMatchPercentage(updatedPlayer1Answers, updatedPlayer2Answers, match.quizType);
    newStatus = 'completed';

    // Use new daily LP grant system
    const contentType = gameTypeToContentType(match.quizType);
    lpGrantResult = await tryAwardDailyLpStandalone(couple.coupleId, contentType, match.id);
    lpEarned = lpGrantResult.lpAwarded;

    console.log(`🎯 LP Grant Result: lpAwarded=${lpGrantResult.lpAwarded}, alreadyGrantedToday=${lpGrantResult.alreadyGrantedToday}, contentType=${contentType}`);

    // Advance branch progression
    await advanceBranch(couple.coupleId, match.quizType);

    // Record activity play for cooldown tracking (Magnet Collection System)
    const cooldownActivityType: ActivityType = match.quizType === 'affirmation'
      ? 'affirmation_quiz'
      : match.quizType === 'you_or_me'
        ? 'you_or_me'
        : 'classic_quiz';
    await recordActivityPlay(couple.coupleId, cooldownActivityType);
    console.log(`🎯 Recorded activity play for ${cooldownActivityType}`);

    // Recalculate Us Profile cache (async, non-blocking)
    recalculateAndCacheProfile(couple.coupleId).catch(err => {
      console.error('Failed to recalculate Us Profile:', err);
    });
  }

  // Update database
  const updateResult = await query(
    `UPDATE quiz_matches
     SET player1_answers = $1,
         player2_answers = $2,
         player1_answer_count = $3,
         player2_answer_count = $4,
         match_percentage = $5,
         status = $6,
         completed_at = $7
     WHERE id = $8
     RETURNING *`,
    [
      JSON.stringify(updatedPlayer1Answers),
      JSON.stringify(updatedPlayer2Answers),
      updatedPlayer1Answers.length,
      updatedPlayer2Answers.length,
      matchPercentage,
      newStatus,
      bothAnswered ? new Date().toISOString() : null,
      match.id,
    ]
  );

  const updatedMatch = parseMatch(updateResult.rows[0]);

  console.log(`🎯 submitAnswers: AFTER UPDATE - status=${updatedMatch.status}, p1Count=${updatedMatch.player1AnswerCount}, p2Count=${updatedMatch.player2AnswerCount}, bothAnswered=${bothAnswered}`);

  const gameResult: GameResult | null = bothAnswered ? {
    matchPercentage: matchPercentage!,
    lpEarned,
    userAnswers: couple.isPlayer1 ? updatedPlayer1Answers : updatedPlayer2Answers,
    partnerAnswers: couple.isPlayer1 ? updatedPlayer2Answers : updatedPlayer1Answers,
    // Include LP status from daily grant system
    alreadyGrantedToday: lpGrantResult?.alreadyGrantedToday,
    resetInMs: lpGrantResult?.resetInMs,
    canPlayMore: lpGrantResult?.canPlayMore,
  } : null;

  return { match: updatedMatch, result: gameResult };
}

function calculateMatchPercentage(p1: number[], p2: number[], gameType?: GameType): number {
  if (p1.length === 0 || p2.length === 0) return 0;
  const total = Math.min(p1.length, p2.length);
  let matches = 0;

  // For you_or_me games, answers are relative (me=1, you=0) to each player.
  // A "match" means both picked the SAME PERSON.
  // Player1 picking "Player2" sends 0 (you), Player2 picking "Player2" sends 1 (me).
  // So we need to invert player2's answers: 0↔1 before comparison.
  // This way, if both picked Player2: p1[i]=0, inverted p2[i]=0 → MATCH!
  const compareP2 = gameType === 'you_or_me'
    ? p2.map(v => v === 0 ? 1 : 0)  // Invert: 0→1, 1→0
    : p2;

  for (let i = 0; i < total; i++) {
    if (p1[i] === compareP2[i]) matches++;
  }
  return Math.round((matches / total) * 100);
}

// =============================================================================
// Game State
// =============================================================================

export function buildGameState(match: GameMatch, couple: CoupleInfo): GameState {
  const config = GAME_CONFIG[match.quizType];

  const userAnswered = couple.isPlayer1
    ? match.player1AnswerCount > 0
    : match.player2AnswerCount > 0;
  const partnerAnswered = couple.isPlayer1
    ? match.player2AnswerCount > 0
    : match.player1AnswerCount > 0;

  const isCompleted = match.status === 'completed';
  const isMyTurn = config.isTurnBased
    ? match.currentTurnUserId === (couple.isPlayer1 ? couple.user1Id : couple.user2Id)
    : undefined;

  const canSubmit = !userAnswered && match.status === 'active' &&
    (config.isTurnBased ? isMyTurn === true : true);

  return {
    canSubmit,
    userAnswered,
    partnerAnswered,
    isCompleted,
    isMyTurn,
  };
}

/**
 * Build game result for a completed match.
 *
 * @param match - The completed match
 * @param couple - Couple info
 * @param options - Optional settings
 * @param options.checkLpStatus - If true, checks daily LP grant status (async)
 * @returns GameResult or null if not completed
 */
export async function buildResult(
  match: GameMatch,
  couple: CoupleInfo,
  options?: { checkLpStatus?: boolean }
): Promise<GameResult | null> {
  if (match.status !== 'completed') return null;

  const config = GAME_CONFIG[match.quizType];

  // Base result
  const result: GameResult = {
    matchPercentage: match.matchPercentage || 0,
    lpEarned: config.lpReward, // Default to full reward
    userAnswers: couple.isPlayer1 ? match.player1Answers : match.player2Answers,
    partnerAnswers: couple.isPlayer1 ? match.player2Answers : match.player1Answers,
    userScore: couple.isPlayer1 ? match.player1Score : match.player2Score,
    partnerScore: couple.isPlayer1 ? match.player2Score : match.player1Score,
  };

  // Optionally check LP grant status for "already earned today" info
  if (options?.checkLpStatus) {
    try {
      const contentType = gameTypeToContentType(match.quizType);
      // Get current LP status without awarding (read-only check)
      const lpStatus = await getLpStatusStandalone(couple.coupleId, contentType);

      result.alreadyGrantedToday = lpStatus.alreadyGrantedToday;
      result.resetInMs = lpStatus.resetInMs;
      result.canPlayMore = lpStatus.canPlayMore;
    } catch (error) {
      console.error('Failed to check LP status:', error);
      // Don't fail the result - just omit LP status
    }
  }

  return result;
}

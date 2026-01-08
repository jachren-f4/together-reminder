/**
 * Quiz Selection Service for Magnet Collection System
 *
 * Selects quizzes based on couple's unlocked magnets.
 *
 * Quiz packs:
 * - magnet_id: 0 or null = starter quizzes (before first magnet)
 * - magnet_id: 1-30 = unlocked with that magnet
 *
 * Each magnet unlocks 18 quizzes: 6 classic + 6 affirmation + 6 you-or-me
 */

import { readFileSync, readdirSync } from 'fs';
import { join } from 'path';
import { query } from '../db/pool';
import { getUnlockedMagnetCount } from '../magnets/calculator';

export type QuizType = 'classic' | 'affirmation' | 'you_or_me';

interface QuizMetadata {
  quizId: string;
  title: string;
  branch: string;
  magnet_id: number | null;
}

// Cache for quiz metadata (loaded once at startup)
let quizCache: Map<QuizType, QuizMetadata[]> | null = null;

/**
 * Load all quiz metadata from disk (cached)
 */
function loadQuizMetadata(): Map<QuizType, QuizMetadata[]> {
  if (quizCache) return quizCache;

  const puzzlesPath = join(process.cwd(), 'data', 'puzzles');
  const cache = new Map<QuizType, QuizMetadata[]>();

  const typeConfig: { type: QuizType; folder: string; prefix: string }[] = [
    { type: 'classic', folder: 'classic-quiz', prefix: 'quiz_' },
    { type: 'affirmation', folder: 'affirmation', prefix: 'affirmation_' },
    { type: 'you_or_me', folder: 'you-or-me', prefix: 'quiz_' },
  ];

  for (const { type, folder, prefix } of typeConfig) {
    const quizzes: QuizMetadata[] = [];
    const typePath = join(puzzlesPath, folder);

    try {
      const branches = readdirSync(typePath, { withFileTypes: true })
        .filter(d => d.isDirectory())
        .map(d => d.name);

      for (const branch of branches) {
        const branchPath = join(typePath, branch);
        const files = readdirSync(branchPath)
          .filter(f => f.startsWith(prefix) && f.endsWith('.json'));

        for (const file of files) {
          try {
            const filePath = join(branchPath, file);
            const content = JSON.parse(readFileSync(filePath, 'utf-8'));
            quizzes.push({
              quizId: content.quizId,
              title: content.title,
              branch: content.branch,
              magnet_id: content.magnet_id ?? null,
            });
          } catch (e) {
            console.error(`Error loading quiz ${file}:`, e);
          }
        }
      }
    } catch (e) {
      console.error(`Error loading ${type} quizzes:`, e);
    }

    cache.set(type, quizzes);
  }

  quizCache = cache;
  return cache;
}

/**
 * Get quizzes available for a couple based on their LP
 */
export async function getAvailableQuizzes(
  coupleId: string,
  quizType: QuizType
): Promise<string[]> {
  // 1. Get couple's LP to calculate unlocked magnets
  const coupleResult = await query(
    'SELECT total_lp FROM couples WHERE id = $1',
    [coupleId]
  );

  if (coupleResult.rows.length === 0) {
    throw new Error(`Couple not found: ${coupleId}`);
  }

  const totalLp = coupleResult.rows[0].total_lp || 0;
  const unlockedMagnets = getUnlockedMagnetCount(totalLp);

  // 2. Get all quizzes for this type
  const allQuizzes = loadQuizMetadata().get(quizType) || [];

  // 3. Filter to quizzes from unlocked packs
  // magnet_id 0 or null = starter, always available
  // magnet_id 1-N = available if N <= unlockedMagnets
  const availableQuizzes = allQuizzes.filter(q => {
    const magnetId = q.magnet_id ?? 0;
    return magnetId === 0 || magnetId <= unlockedMagnets;
  });

  // 4. Get completed quiz IDs for this couple
  const completedResult = await query(
    `SELECT DISTINCT quiz_id FROM quiz_matches
     WHERE couple_id = $1 AND quiz_type = $2 AND status = 'completed'`,
    [coupleId, quizType === 'you_or_me' ? 'you_or_me' : quizType]
  );

  const completedIds = new Set(completedResult.rows.map(r => r.quiz_id));

  // 5. Return unplayed quizzes
  return availableQuizzes
    .filter(q => !completedIds.has(q.quizId))
    .map(q => q.quizId);
}

/**
 * Get all quizzes for a specific magnet pack
 */
export function getQuizzesForMagnet(
  quizType: QuizType,
  magnetId: number
): QuizMetadata[] {
  const allQuizzes = loadQuizMetadata().get(quizType) || [];
  return allQuizzes.filter(q => (q.magnet_id ?? 0) === magnetId);
}

/**
 * Get starter quizzes (available before first magnet)
 */
export function getStarterQuizzes(quizType: QuizType): QuizMetadata[] {
  return getQuizzesForMagnet(quizType, 0);
}

/**
 * Check if a couple has exhausted all available quizzes
 */
export async function hasExhaustedQuizzes(
  coupleId: string,
  quizType: QuizType
): Promise<boolean> {
  const available = await getAvailableQuizzes(coupleId, quizType);
  return available.length === 0;
}

/**
 * Select a quiz for replay when all quizzes are exhausted
 * Returns the least recently played quiz from the most recent magnet pack
 */
export async function selectReplayQuiz(
  coupleId: string,
  quizType: QuizType
): Promise<string | null> {
  // Get couple's unlocked magnets
  const coupleResult = await query(
    'SELECT total_lp FROM couples WHERE id = $1',
    [coupleId]
  );

  if (coupleResult.rows.length === 0) return null;

  const totalLp = coupleResult.rows[0].total_lp || 0;
  const unlockedMagnets = getUnlockedMagnetCount(totalLp);

  // Get quizzes from most recent magnet pack (or starter if 0)
  const targetMagnet = unlockedMagnets > 0 ? unlockedMagnets : 0;
  const packQuizzes = getQuizzesForMagnet(quizType, targetMagnet);

  if (packQuizzes.length === 0) return null;

  // Get the least recently played quiz from this pack
  const quizIds = packQuizzes.map(q => q.quizId);
  const result = await query(
    `SELECT quiz_id FROM quiz_matches
     WHERE couple_id = $1 AND quiz_type = $2 AND quiz_id = ANY($3)
     ORDER BY completed_at ASC
     LIMIT 1`,
    [coupleId, quizType === 'you_or_me' ? 'you_or_me' : quizType, quizIds]
  );

  return result.rows[0]?.quiz_id ?? packQuizzes[0].quizId;
}

/**
 * Select a quiz for daily quest
 */
export async function selectDailyQuiz(
  coupleId: string,
  quizType: QuizType
): Promise<{ quizId: string; isReplay: boolean }> {
  const available = await getAvailableQuizzes(coupleId, quizType);

  if (available.length > 0) {
    // Random selection from available quizzes
    const randomIndex = Math.floor(Math.random() * available.length);
    return { quizId: available[randomIndex], isReplay: false };
  }

  // All quizzes exhausted - select for replay
  const replayQuiz = await selectReplayQuiz(coupleId, quizType);
  if (replayQuiz) {
    return { quizId: replayQuiz, isReplay: true };
  }

  // Fallback to first starter quiz (should never happen)
  const starters = getStarterQuizzes(quizType);
  return { quizId: starters[0]?.quizId ?? 'quiz_001', isReplay: true };
}

/**
 * Get quiz pack statistics
 */
export function getQuizPackStats(): {
  type: QuizType;
  total: number;
  byMagnet: { magnetId: number; count: number }[];
}[] {
  const metadata = loadQuizMetadata();
  const stats = [];

  for (const [type, quizzes] of metadata.entries()) {
    const byMagnet = new Map<number, number>();

    for (const quiz of quizzes) {
      const magnetId = quiz.magnet_id ?? 0;
      byMagnet.set(magnetId, (byMagnet.get(magnetId) ?? 0) + 1);
    }

    stats.push({
      type,
      total: quizzes.length,
      byMagnet: Array.from(byMagnet.entries())
        .map(([magnetId, count]) => ({ magnetId, count }))
        .sort((a, b) => a.magnetId - b.magnetId),
    });
  }

  return stats;
}

/**
 * Clear quiz cache (for testing or when quizzes are updated)
 */
export function clearQuizCache(): void {
  quizCache = null;
}

/**
 * LP Grant Service
 *
 * Handles daily LP grant tracking with race-condition safe operations.
 * Uses INSERT ... ON CONFLICT for atomic "grant once per day" logic.
 */

import { PoolClient } from 'pg';
import {
  getLpDay,
  getTimeUntilReset,
  isUnlimitedContentAllowed,
  LpContentType,
} from './daily-reset';
import { withTransaction } from '@/lib/db/transaction';

/**
 * Result of attempting to grant daily LP
 */
export interface LpGrantResult {
  /** Whether LP was awarded in this request */
  lpAwarded: number;
  /** Whether LP was already granted today for this content type */
  alreadyGrantedToday: boolean;
  /** Milliseconds until LP resets */
  resetInMs: number;
  /** Whether the user can play more content (based on LP_ALLOW_UNLIMITED_CONTENT) */
  canPlayMore: boolean;
  /** The LP day this grant applies to */
  lpDay: string;
}

/**
 * Result of checking if new content can be started
 */
export interface ContentAccessResult {
  /** Whether the user is allowed to start new content */
  allowed: boolean;
  /** Milliseconds until LP resets (if blocked) */
  resetInMs: number;
  /** Message to display if blocked */
  message?: string;
}

/**
 * Standard LP amount per content type
 */
const LP_AMOUNT = 30;

/**
 * Try to award daily LP for a content type
 *
 * Uses atomic INSERT ... ON CONFLICT to ensure only one grant per couple
 * per content type per LP day. Safe for concurrent requests.
 *
 * @param client - Database client (should be in a transaction)
 * @param coupleId - The couple's ID
 * @param contentType - Type of content (classic_quiz, affirmation_quiz, etc.)
 * @param matchId - Optional match ID for tracking
 * @returns Grant result with LP awarded and status
 */
export async function tryAwardDailyLp(
  client: PoolClient,
  coupleId: string,
  contentType: LpContentType,
  matchId?: string
): Promise<LpGrantResult> {
  const now = new Date();
  const lpDay = getLpDay(now);
  const resetInMs = getTimeUntilReset(now);

  // Atomic insert - only succeeds if no grant exists for this couple/type/day
  const insertResult = await client.query(
    `
    INSERT INTO daily_lp_grants (couple_id, content_type, lp_day, lp_amount, match_id)
    VALUES ($1, $2, $3, $4, $5)
    ON CONFLICT (couple_id, content_type, lp_day) DO NOTHING
    RETURNING id
    `,
    [coupleId, contentType, lpDay, LP_AMOUNT, matchId || null]
  );

  const wasInserted = (insertResult.rowCount ?? 0) > 0;

  if (wasInserted) {
    // First grant today - award the LP directly using the transaction client
    // Update couple's total LP
    await client.query(
      `UPDATE couples SET total_lp = COALESCE(total_lp, 0) + $1 WHERE id = $2`,
      [LP_AMOUNT, coupleId]
    );

    // Record LP transaction for audit trail (for both users)
    const coupleResult = await client.query(
      `SELECT user1_id, user2_id FROM couples WHERE id = $1`,
      [coupleId]
    );

    if (coupleResult.rows.length > 0) {
      const { user1_id, user2_id } = coupleResult.rows[0];
      const description = matchId
        ? `daily_${contentType} (${matchId})`
        : `daily_${contentType}`;

      await client.query(
        `INSERT INTO love_point_transactions (user_id, amount, source, description, created_at)
         VALUES ($1, $2, $3, $4, NOW()), ($5, $2, $3, $4, NOW())`,
        [user1_id, LP_AMOUNT, `daily_${contentType}`, description, user2_id]
      );
    }

    return {
      lpAwarded: LP_AMOUNT,
      alreadyGrantedToday: false,
      resetInMs,
      canPlayMore: true,
      lpDay,
    };
  } else {
    // Already granted today
    return {
      lpAwarded: 0,
      alreadyGrantedToday: true,
      resetInMs,
      canPlayMore: isUnlimitedContentAllowed(),
      lpDay,
    };
  }
}

/**
 * Check if a couple has already earned LP for a content type today
 *
 * @param client - Database client
 * @param coupleId - The couple's ID
 * @param contentType - Type of content to check
 * @returns Whether LP was already granted today
 */
export async function hasEarnedLpToday(
  client: PoolClient,
  coupleId: string,
  contentType: LpContentType
): Promise<boolean> {
  const lpDay = getLpDay();

  const result = await client.query(
    `
    SELECT 1 FROM daily_lp_grants
    WHERE couple_id = $1 AND content_type = $2 AND lp_day = $3
    LIMIT 1
    `,
    [coupleId, contentType, lpDay]
  );

  return (result.rowCount ?? 0) > 0;
}

/**
 * Check if new content can be started (for optional content locking)
 *
 * @param client - Database client
 * @param coupleId - The couple's ID
 * @param contentType - Type of content to check
 * @returns Access result with allowed status and reset time
 */
export async function canStartNewContent(
  client: PoolClient,
  coupleId: string,
  contentType: LpContentType
): Promise<ContentAccessResult> {
  // If unlimited content is allowed, always permit
  if (isUnlimitedContentAllowed()) {
    return { allowed: true, resetInMs: 0 };
  }

  const alreadyEarned = await hasEarnedLpToday(client, coupleId, contentType);
  const resetInMs = getTimeUntilReset();

  if (alreadyEarned) {
    return {
      allowed: false,
      resetInMs,
      message: `You've already earned LP for this today. New content available at reset.`,
    };
  }

  return { allowed: true, resetInMs: 0 };
}

/**
 * Get all LP grants for a couple today
 *
 * Useful for displaying which content types have already earned LP
 *
 * @param client - Database client
 * @param coupleId - The couple's ID
 * @returns Array of content types that have earned LP today
 */
export async function getTodaysGrants(
  client: PoolClient,
  coupleId: string
): Promise<LpContentType[]> {
  const lpDay = getLpDay();

  const result = await client.query(
    `
    SELECT content_type FROM daily_lp_grants
    WHERE couple_id = $1 AND lp_day = $2
    `,
    [coupleId, lpDay]
  );

  return result.rows.map((row) => row.content_type as LpContentType);
}

/**
 * Clean up old LP grant records
 *
 * Removes records older than the specified number of days.
 * Should be called periodically (e.g., daily cron job).
 *
 * @param client - Database client
 * @param daysToKeep - Number of days of records to retain (default: 7)
 * @returns Number of records deleted
 */
export async function cleanupOldGrants(
  client: PoolClient,
  daysToKeep: number = 7
): Promise<number> {
  const cutoffDate = new Date();
  cutoffDate.setUTCDate(cutoffDate.getUTCDate() - daysToKeep);
  const cutoffDay = cutoffDate.toISOString().split('T')[0];

  const result = await client.query(
    `
    DELETE FROM daily_lp_grants
    WHERE lp_day < $1
    `,
    [cutoffDay]
  );

  return result.rowCount || 0;
}

// =============================================================================
// Standalone Functions (manage their own transactions)
// =============================================================================

/**
 * Try to award daily LP for a content type (standalone version)
 *
 * This version manages its own transaction and can be called directly
 * from handlers that don't use transactions.
 *
 * @param coupleId - The couple's ID
 * @param contentType - Type of content (classic_quiz, affirmation_quiz, etc.)
 * @param matchId - Optional match ID for tracking
 * @returns Grant result with LP awarded and status
 */
export async function tryAwardDailyLpStandalone(
  coupleId: string,
  contentType: LpContentType,
  matchId?: string
): Promise<LpGrantResult> {
  return withTransaction(async (client) => {
    return tryAwardDailyLp(client, coupleId, contentType, matchId);
  });
}

/**
 * Check LP grant status without awarding (read-only)
 *
 * Use this to check if LP has already been granted today for a content type
 * without attempting to award it.
 *
 * @param coupleId - The couple's ID
 * @param contentType - Type of content to check
 * @returns LP status (alreadyGrantedToday, resetInMs, canPlayMore)
 */
export async function getLpStatusStandalone(
  coupleId: string,
  contentType: LpContentType
): Promise<Omit<LpGrantResult, 'lpAwarded' | 'lpDay'> & { alreadyGrantedToday: boolean }> {
  return withTransaction(async (client) => {
    const alreadyGranted = await hasEarnedLpToday(client, coupleId, contentType);
    const resetInMs = getTimeUntilReset();

    return {
      alreadyGrantedToday: alreadyGranted,
      resetInMs,
      canPlayMore: isUnlimitedContentAllowed(),
    };
  });
}

/**
 * Map game type to LP content type
 *
 * @param gameType - Game type (classic, affirmation, you_or_me)
 * @returns Corresponding LP content type
 */
export function gameTypeToContentType(gameType: string): LpContentType {
  switch (gameType) {
    case 'classic':
      return 'classic_quiz';
    case 'affirmation':
      return 'affirmation_quiz';
    case 'you_or_me':
      return 'you_or_me';
    default:
      throw new Error(`Unknown game type: ${gameType}`);
  }
}

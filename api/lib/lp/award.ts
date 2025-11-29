/**
 * Love Points (LP) Award Utility
 *
 * Single source of truth for awarding LP to couples.
 * Updates couples.total_lp (atomic, single row) instead of per-user tables.
 *
 * Usage:
 *   import { awardLP } from '@/lib/lp/award';
 *   const newTotal = await awardLP(coupleId, 30, 'quiz_complete', matchId);
 */

import { query } from '@/lib/db/pool';

export interface AwardLPResult {
  success: boolean;
  newTotal: number;
  awarded: number;
  alreadyAwarded?: boolean;
}

/**
 * Award LP to a couple (single source of truth).
 *
 * @param coupleId - The couple's UUID
 * @param amount - LP amount to award (must be positive)
 * @param source - Source identifier (e.g., 'quiz_complete', 'linked_complete', 'steps_claim')
 * @param relatedId - Optional related entity ID for idempotency (e.g., matchId, puzzleId, dateKey)
 * @returns The new total LP for the couple
 *
 * Idempotency: If relatedId is provided, the same (coupleId, source, relatedId)
 * combination will not award LP twice.
 */
export async function awardLP(
  coupleId: string,
  amount: number,
  source: string,
  relatedId?: string
): Promise<AwardLPResult> {
  if (amount <= 0) {
    throw new Error('LP amount must be positive');
  }

  // Check for duplicate award if relatedId provided (idempotency)
  if (relatedId) {
    const existingResult = await query(
      `SELECT id FROM love_point_transactions
       WHERE source = $1
       AND description LIKE $2
       AND created_at > NOW() - INTERVAL '24 hours'
       LIMIT 1`,
      [source, `%${relatedId}%`]
    );

    if (existingResult.rows.length > 0) {
      // Already awarded for this related entity
      const currentResult = await query(
        `SELECT total_lp FROM couples WHERE id = $1`,
        [coupleId]
      );
      return {
        success: true,
        newTotal: currentResult.rows[0]?.total_lp || 0,
        awarded: 0,
        alreadyAwarded: true
      };
    }
  }

  // Update couples.total_lp (atomic, single row)
  const updateResult = await query(
    `UPDATE couples
     SET total_lp = COALESCE(total_lp, 0) + $1
     WHERE id = $2
     RETURNING total_lp`,
    [amount, coupleId]
  );

  if (updateResult.rows.length === 0) {
    throw new Error(`Couple not found: ${coupleId}`);
  }

  const newTotal = updateResult.rows[0].total_lp;

  // Record transaction for audit trail
  // Get both user IDs for the transaction log
  const coupleResult = await query(
    `SELECT user1_id, user2_id FROM couples WHERE id = $1`,
    [coupleId]
  );

  if (coupleResult.rows.length > 0) {
    const { user1_id, user2_id } = coupleResult.rows[0];
    const description = relatedId
      ? `${source} (${relatedId})`
      : source;

    // Record transaction for both users (for compatibility with existing transaction history)
    for (const userId of [user1_id, user2_id]) {
      await query(
        `INSERT INTO love_point_transactions (user_id, amount, source, description, created_at)
         VALUES ($1, $2, $3, $4, NOW())`,
        [userId, amount, source, description]
      );
    }
  }

  return {
    success: true,
    newTotal,
    awarded: amount,
    alreadyAwarded: false
  };
}

/**
 * Get the current LP total for a couple.
 *
 * @param coupleId - The couple's UUID
 * @returns The current LP total
 */
export async function getCoupleLP(coupleId: string): Promise<number> {
  const result = await query(
    `SELECT total_lp FROM couples WHERE id = $1`,
    [coupleId]
  );

  if (result.rows.length === 0) {
    throw new Error(`Couple not found: ${coupleId}`);
  }

  return result.rows[0].total_lp || 0;
}

/**
 * Get the current LP total for a user (via their couple).
 *
 * @param userId - The user's UUID
 * @returns The current LP total for the user's couple
 */
export async function getUserLP(userId: string): Promise<number> {
  const result = await query(
    `SELECT c.total_lp
     FROM couples c
     WHERE c.user1_id = $1 OR c.user2_id = $1
     LIMIT 1`,
    [userId]
  );

  if (result.rows.length === 0) {
    return 0; // User not in a couple
  }

  return result.rows[0].total_lp || 0;
}

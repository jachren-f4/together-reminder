/**
 * Couple Utilities
 *
 * Shared utilities for fetching and working with couple data across all API routes.
 * Centralizes the common pattern of looking up couple info from a user ID.
 */

import { query } from '@/lib/db/pool';
import { PoolClient } from 'pg';

// =============================================================================
// Types
// =============================================================================

export interface CoupleInfo {
  coupleId: string;
  user1Id: string;
  user2Id: string;
  firstPlayerId: string | null;
  totalLp: number;
  isPlayer1: boolean;
  partnerId: string;
}

export interface CoupleBasicInfo {
  coupleId: string;
  user1Id: string;
  user2Id: string;
  isPlayer1: boolean;
  partnerId: string;
}

// =============================================================================
// Couple Fetching Functions
// =============================================================================

/**
 * Get full couple info including LP and first player preference.
 * Use this when you need all couple data including game preferences.
 *
 * @param userId - The user ID to look up couple for
 * @param client - Optional database client (for use within transactions)
 * @returns CoupleInfo or null if no couple found
 *
 * @example
 * const couple = await getCouple(userId);
 * if (!couple) {
 *   return NextResponse.json({ error: 'No couple found' }, { status: 404 });
 * }
 * const { coupleId, partnerId, isPlayer1 } = couple;
 */
export async function getCouple(
  userId: string,
  client?: PoolClient
): Promise<CoupleInfo | null> {
  const queryFn = client ? client.query.bind(client) : query;

  const result = await queryFn(
    `SELECT id, user1_id, user2_id, first_player_id, total_lp
     FROM couples
     WHERE user1_id = $1 OR user2_id = $1
     LIMIT 1`,
    [userId]
  );

  if (result.rows.length === 0) return null;

  const row = result.rows[0];
  const isPlayer1 = userId === row.user1_id;

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

/**
 * Get basic couple info (just IDs).
 * Use this when you only need couple/partner IDs, not LP or preferences.
 * Slightly more efficient query than getCouple().
 *
 * @param userId - The user ID to look up couple for
 * @param client - Optional database client (for use within transactions)
 * @returns CoupleBasicInfo or null if no couple found
 *
 * @example
 * const couple = await getCoupleBasic(userId);
 * if (!couple) {
 *   return NextResponse.json({ error: 'No couple found' }, { status: 404 });
 * }
 */
export async function getCoupleBasic(
  userId: string,
  client?: PoolClient
): Promise<CoupleBasicInfo | null> {
  const queryFn = client ? client.query.bind(client) : query;

  const result = await queryFn(
    `SELECT id, user1_id, user2_id
     FROM couples
     WHERE user1_id = $1 OR user2_id = $1
     LIMIT 1`,
    [userId]
  );

  if (result.rows.length === 0) return null;

  const row = result.rows[0];
  const isPlayer1 = userId === row.user1_id;

  return {
    coupleId: row.id,
    user1Id: row.user1_id,
    user2Id: row.user2_id,
    isPlayer1,
    partnerId: isPlayer1 ? row.user2_id : row.user1_id,
  };
}

/**
 * Get just the couple ID for a user.
 * Use this when you only need the couple ID, nothing else.
 *
 * @param userId - The user ID to look up couple for
 * @param client - Optional database client (for use within transactions)
 * @returns couple ID string or null if no couple found
 */
export async function getCoupleId(
  userId: string,
  client?: PoolClient
): Promise<string | null> {
  const queryFn = client ? client.query.bind(client) : query;

  const result = await queryFn(
    `SELECT id FROM couples WHERE user1_id = $1 OR user2_id = $1 LIMIT 1`,
    [userId]
  );

  return result.rows.length > 0 ? result.rows[0].id : null;
}

// =============================================================================
// Helper Functions
// =============================================================================

/**
 * Determine which player the user is (1 or 2) and get partner ID.
 * Useful when you already have couple data and just need to determine roles.
 *
 * @param userId - The user to check
 * @param user1Id - The couple's user1_id
 * @param user2Id - The couple's user2_id
 */
export function getPlayerInfo(
  userId: string,
  user1Id: string,
  user2Id: string
): { isPlayer1: boolean; partnerId: string } {
  const isPlayer1 = userId === user1Id;
  return {
    isPlayer1,
    partnerId: isPlayer1 ? user2Id : user1Id,
  };
}

/**
 * Phantom User Utilities
 *
 * Phantom users are real Supabase Auth accounts that nobody logs into.
 * They represent a partner in single-phone mode, allowing all 20+ API
 * endpoints to work unchanged (server always sees two real user IDs).
 *
 * Phantom users are identified by `raw_user_meta_data->>'is_phantom' = 'true'`
 * and have email format `phantom-{uuid}@internal.togetherremind.app`.
 */

import { query } from '@/lib/db/pool';
import { PoolClient } from 'pg';

/**
 * Check if a user is a phantom user.
 *
 * @param userId - The user ID to check
 * @param client - Optional database client (for use within transactions)
 * @returns true if the user is a phantom user
 */
export async function isPhantomUser(
  userId: string,
  client?: PoolClient
): Promise<boolean> {
  const queryFn = client ? client.query.bind(client) : query;

  const result = await queryFn(
    `SELECT id FROM auth.users
     WHERE id = $1 AND raw_user_meta_data->>'is_phantom' = 'true'`,
    [userId]
  );

  return result.rows.length > 0;
}

/**
 * Get the phantom partner's user ID for a couple, if one exists.
 *
 * @param coupleId - The couple ID to check
 * @param client - Optional database client (for use within transactions)
 * @returns The phantom user's ID, or null if no phantom partner
 */
export async function getPhantomPartnerId(
  coupleId: string,
  client?: PoolClient
): Promise<string | null> {
  const queryFn = client ? client.query.bind(client) : query;

  const result = await queryFn(
    `SELECT u.id
     FROM couples c
     JOIN auth.users u ON u.id IN (c.user1_id, c.user2_id)
     WHERE c.id = $1 AND u.raw_user_meta_data->>'is_phantom' = 'true'`,
    [coupleId]
  );

  return result.rows.length > 0 ? result.rows[0].id : null;
}

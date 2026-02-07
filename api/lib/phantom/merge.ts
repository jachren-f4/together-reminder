/**
 * Phantom-to-Real User Merge
 *
 * When a real user joins a couple that has a phantom partner,
 * this module transfers all game history from the phantom user
 * to the real user and deletes the phantom account.
 *
 * This is an atomic operation — all updates happen in a single
 * database transaction. If any step fails, everything rolls back.
 *
 * Tables updated:
 * - couples: user2_id (phantom → real)
 * - quiz_sessions: created_by, subject_user_id, initiated_by
 * - you_or_me_sessions: user_id, partner_id, initiated_by, subject_user_id
 * - linked_matches: player1_id, player2_id, current_turn_user_id, winner_id
 * - linked_moves: player_id
 * - word_search_matches: player1_id, player2_id, current_turn_user_id, winner_id
 * - word_search_moves: player_id
 * - quest_completions: user_id
 * - love_point_transactions: user_id
 * - user_couples: user_id
 * - auth.users: phantom row deleted
 */

import { PoolClient } from 'pg';

export interface MergeResult {
  success: boolean;
  error?: string;
  tablesUpdated: number;
}

/**
 * Merge a phantom user into a real user within an existing transaction.
 *
 * @param client - Database client (must already be in a transaction)
 * @param coupleId - The couple ID
 * @param phantomUserId - The phantom user's ID (to be replaced)
 * @param realUserId - The real user's ID (replacement)
 */
export async function mergePhantomToReal(
  client: PoolClient,
  coupleId: string,
  phantomUserId: string,
  realUserId: string
): Promise<MergeResult> {
  let tablesUpdated = 0;

  try {
    // 1. Update couples table — replace phantom with real user
    // The phantom is always user2 (created by create-with-phantom endpoint)
    await client.query(
      `UPDATE couples SET user2_id = $1, updated_at = NOW()
       WHERE id = $2 AND user2_id = $3`,
      [realUserId, coupleId, phantomUserId]
    );
    tablesUpdated++;

    // 2. Update user_couples mapping
    await client.query(
      `UPDATE user_couples SET user_id = $1
       WHERE user_id = $2 AND couple_id = $3`,
      [realUserId, phantomUserId, coupleId]
    );
    tablesUpdated++;

    // 3. Quiz sessions — update all user ID references
    await client.query(
      `UPDATE quiz_sessions SET created_by = $1
       WHERE created_by = $2 AND couple_id = $3`,
      [realUserId, phantomUserId, coupleId]
    );
    await client.query(
      `UPDATE quiz_sessions SET subject_user_id = $1
       WHERE subject_user_id = $2 AND couple_id = $3`,
      [realUserId, phantomUserId, coupleId]
    );
    await client.query(
      `UPDATE quiz_sessions SET initiated_by = $1
       WHERE initiated_by = $2 AND couple_id = $3`,
      [realUserId, phantomUserId, coupleId]
    );
    tablesUpdated++;

    // 4. You-or-Me sessions
    await client.query(
      `UPDATE you_or_me_sessions SET user_id = $1
       WHERE user_id = $2 AND couple_id = $3`,
      [realUserId, phantomUserId, coupleId]
    );
    await client.query(
      `UPDATE you_or_me_sessions SET partner_id = $1
       WHERE partner_id = $2 AND couple_id = $3`,
      [realUserId, phantomUserId, coupleId]
    );
    await client.query(
      `UPDATE you_or_me_sessions SET initiated_by = $1
       WHERE initiated_by = $2 AND couple_id = $3`,
      [realUserId, phantomUserId, coupleId]
    );
    await client.query(
      `UPDATE you_or_me_sessions SET subject_user_id = $1
       WHERE subject_user_id = $2 AND couple_id = $3`,
      [realUserId, phantomUserId, coupleId]
    );
    tablesUpdated++;

    // 5. Linked matches
    await client.query(
      `UPDATE linked_matches SET player1_id = $1
       WHERE player1_id = $2 AND couple_id = $3`,
      [realUserId, phantomUserId, coupleId]
    );
    await client.query(
      `UPDATE linked_matches SET player2_id = $1
       WHERE player2_id = $2 AND couple_id = $3`,
      [realUserId, phantomUserId, coupleId]
    );
    await client.query(
      `UPDATE linked_matches SET current_turn_user_id = $1
       WHERE current_turn_user_id = $2 AND couple_id = $3`,
      [realUserId, phantomUserId, coupleId]
    );
    await client.query(
      `UPDATE linked_matches SET winner_id = $1
       WHERE winner_id = $2 AND couple_id = $3`,
      [realUserId, phantomUserId, coupleId]
    );
    tablesUpdated++;

    // 6. Linked moves
    await client.query(
      `UPDATE linked_moves SET player_id = $1
       WHERE player_id = $2 AND match_id IN (
         SELECT id FROM linked_matches WHERE couple_id = $3
       )`,
      [realUserId, phantomUserId, coupleId]
    );
    tablesUpdated++;

    // 7. Word search matches
    await client.query(
      `UPDATE word_search_matches SET player1_id = $1
       WHERE player1_id = $2 AND couple_id = $3`,
      [realUserId, phantomUserId, coupleId]
    );
    await client.query(
      `UPDATE word_search_matches SET player2_id = $1
       WHERE player2_id = $2 AND couple_id = $3`,
      [realUserId, phantomUserId, coupleId]
    );
    await client.query(
      `UPDATE word_search_matches SET current_turn_user_id = $1
       WHERE current_turn_user_id = $2 AND couple_id = $3`,
      [realUserId, phantomUserId, coupleId]
    );
    await client.query(
      `UPDATE word_search_matches SET winner_id = $1
       WHERE winner_id = $2 AND couple_id = $3`,
      [realUserId, phantomUserId, coupleId]
    );
    tablesUpdated++;

    // 8. Word search moves
    await client.query(
      `UPDATE word_search_moves SET player_id = $1
       WHERE player_id = $2 AND match_id IN (
         SELECT id FROM word_search_matches WHERE couple_id = $3
       )`,
      [realUserId, phantomUserId, coupleId]
    );
    tablesUpdated++;

    // 9. Quest completions
    await client.query(
      `UPDATE quest_completions SET user_id = $1
       WHERE user_id = $2 AND couple_id = $3`,
      [realUserId, phantomUserId, coupleId]
    );
    tablesUpdated++;

    // 10. Love point transactions
    await client.query(
      `UPDATE love_point_transactions SET user_id = $1
       WHERE user_id = $2 AND couple_id = $3`,
      [realUserId, phantomUserId, coupleId]
    );
    tablesUpdated++;

    // 11. LP daily grants
    await client.query(
      `UPDATE lp_daily_grants SET user_id = $1
       WHERE user_id = $2 AND couple_id = $3`,
      [realUserId, phantomUserId, coupleId]
    );
    tablesUpdated++;

    // 12. Delete phantom user's push tokens (they had none, but be safe)
    await client.query(
      `DELETE FROM user_push_tokens WHERE user_id = $1`,
      [phantomUserId]
    );

    // 13. Delete phantom auth account
    await client.query(
      `DELETE FROM auth.users WHERE id = $1`,
      [phantomUserId]
    );
    tablesUpdated++;

    return { success: true, tablesUpdated };
  } catch (error) {
    console.error('Merge phantom-to-real failed:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Merge failed',
      tablesUpdated,
    };
  }
}

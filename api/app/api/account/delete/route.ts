/**
 * Account Deletion Endpoint
 *
 * Permanently deletes a user's account and all associated data.
 * Required for App Store compliance (Guideline 5.1.1(v)).
 *
 * DELETE /api/account/delete
 *
 * Flow:
 * 1. Verify user authentication
 * 2. Get user's couple info (if any)
 * 3. Delete all user data from tables (in FK-safe order)
 * 4. Unpair from couple (set user column to NULL)
 * 5. Delete user from auth.users
 * 6. Return success
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuth } from '@/lib/auth/middleware';
import { withTransaction } from '@/lib/db/transaction';
import { getCoupleBasic } from '@/lib/couple/utils';
import { createClient } from '@/lib/supabase/server';
import { PoolClient } from 'pg';

export const dynamic = 'force-dynamic';

// Handle CORS preflight
export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    },
  });
}

/**
 * Helper to safely delete from a table (ignores if table doesn't exist)
 * Uses SAVEPOINT to prevent transaction abort on missing tables
 */
async function safeDelete(
  client: PoolClient,
  sql: string,
  params: any[] = []
): Promise<number> {
  const savepointName = `sp_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;

  try {
    await client.query(`SAVEPOINT ${savepointName}`);
    const result = await client.query(sql, params);
    await client.query(`RELEASE SAVEPOINT ${savepointName}`);
    return result.rowCount ?? 0;
  } catch (e: any) {
    // Rollback to savepoint to keep transaction valid
    await client.query(`ROLLBACK TO SAVEPOINT ${savepointName}`);

    // Table might not exist - that's OK
    if (e.code === '42P01') {
      return 0;
    }
    // Re-throw other errors
    throw e;
  }
}

/**
 * Delete user account and all associated data
 */
export const DELETE = withAuth(async (req, userId, email) => {
  console.log(`[Account Delete] Starting deletion for user: ${userId} (${email})`);

  try {
    // Get couple info before deletion
    const couple = await getCoupleBasic(userId);
    const coupleId = couple?.coupleId;
    const partnerId = couple?.partnerId;
    const isPlayer1 = couple?.isPlayer1;

    // Execute all deletions in a transaction
    await withTransaction(async (client) => {
      console.log(`[Account Delete] Deleting data for user: ${userId}`);

      // 1. Delete user-specific data (no couple dependency)
      await safeDelete(client,
        `DELETE FROM user_push_tokens WHERE user_id = $1`,
        [userId]
      );

      await safeDelete(client,
        `DELETE FROM push_tokens WHERE user_id = $1`,
        [userId]
      );

      // 2. If user is in a couple, delete couple-related data
      if (coupleId) {
        console.log(`[Account Delete] Deleting couple data for couple: ${coupleId}`);

        // Quest completions (FK to daily_quests)
        await safeDelete(client,
          `DELETE FROM quest_completions WHERE quest_id IN (SELECT id FROM daily_quests WHERE couple_id = $1)`,
          [coupleId]
        );

        // Daily quests
        await safeDelete(client,
          `DELETE FROM daily_quests WHERE couple_id = $1`,
          [coupleId]
        );

        // Quiz data
        await safeDelete(client,
          `DELETE FROM quiz_answers WHERE session_id IN (SELECT id FROM quiz_sessions WHERE couple_id = $1)`,
          [coupleId]
        );
        await safeDelete(client,
          `DELETE FROM quiz_sessions WHERE couple_id = $1`,
          [coupleId]
        );
        await safeDelete(client,
          `DELETE FROM quiz_matches WHERE couple_id = $1`,
          [coupleId]
        );
        await safeDelete(client,
          `DELETE FROM quiz_progression WHERE couple_id = $1`,
          [coupleId]
        );

        // You or Me data
        await safeDelete(client,
          `DELETE FROM you_or_me_answers WHERE session_id IN (SELECT id FROM you_or_me_sessions WHERE couple_id = $1)`,
          [coupleId]
        );
        await safeDelete(client,
          `DELETE FROM you_or_me_sessions WHERE couple_id = $1`,
          [coupleId]
        );
        await safeDelete(client,
          `DELETE FROM you_or_me_matches WHERE couple_id = $1`,
          [coupleId]
        );
        await safeDelete(client,
          `DELETE FROM you_or_me_progression WHERE couple_id = $1`,
          [coupleId]
        );

        // Linked puzzle data
        await safeDelete(client,
          `DELETE FROM linked_moves WHERE match_id IN (SELECT id FROM linked_matches WHERE couple_id = $1)`,
          [coupleId]
        );
        await safeDelete(client,
          `DELETE FROM linked_matches WHERE couple_id = $1`,
          [coupleId]
        );

        // Word search data
        await safeDelete(client,
          `DELETE FROM word_search_moves WHERE match_id IN (SELECT id FROM word_search_matches WHERE couple_id = $1)`,
          [coupleId]
        );
        await safeDelete(client,
          `DELETE FROM word_search_matches WHERE couple_id = $1`,
          [coupleId]
        );

        // Branch progression
        await safeDelete(client,
          `DELETE FROM branch_progression WHERE couple_id = $1`,
          [coupleId]
        );

        // Steps data
        await safeDelete(client,
          `DELETE FROM step_claims WHERE couple_id = $1`,
          [coupleId]
        );
        await safeDelete(client,
          `DELETE FROM steps_daily WHERE user_id = $1`,
          [userId]
        );
        await safeDelete(client,
          `DELETE FROM steps_connections WHERE user_id = $1`,
          [userId]
        );

        // LP grants
        await safeDelete(client,
          `DELETE FROM lp_grants WHERE couple_id = $1`,
          [coupleId]
        );

        // Love points data
        await safeDelete(client,
          `DELETE FROM love_point_awards WHERE couple_id = $1`,
          [coupleId]
        );
        await safeDelete(client,
          `DELETE FROM love_point_transactions WHERE couple_id = $1`,
          [coupleId]
        );
        await safeDelete(client,
          `DELETE FROM user_love_points WHERE user_id = $1`,
          [userId]
        );
        await safeDelete(client,
          `DELETE FROM couple_leaderboard WHERE couple_id = $1`,
          [coupleId]
        );

        // Unlocks
        await safeDelete(client,
          `DELETE FROM couple_unlocks WHERE couple_id = $1`,
          [coupleId]
        );

        // Welcome quiz
        await safeDelete(client,
          `DELETE FROM welcome_quiz_answers WHERE user_id = $1`,
          [userId]
        );

        // Reminders
        await safeDelete(client,
          `DELETE FROM reminders WHERE couple_id = $1`,
          [coupleId]
        );

        // Magnets
        await safeDelete(client,
          `DELETE FROM couple_magnets WHERE couple_id = $1`,
          [coupleId]
        );

        // User couples lookup
        await safeDelete(client,
          `DELETE FROM user_couples WHERE user_id = $1`,
          [userId]
        );

        // 3. Update couple: set this user's column to NULL
        // If partner exists, they become unpaired. If both NULL, delete couple.
        if (isPlayer1) {
          await client.query(
            `UPDATE couples SET user1_id = NULL WHERE id = $1`,
            [coupleId]
          );
        } else {
          await client.query(
            `UPDATE couples SET user2_id = NULL WHERE id = $1`,
            [coupleId]
          );
        }

        // Check if both users are now NULL, if so delete the couple
        const coupleCheck = await client.query(
          `SELECT user1_id, user2_id FROM couples WHERE id = $1`,
          [coupleId]
        );

        if (coupleCheck.rows.length > 0) {
          const { user1_id, user2_id } = coupleCheck.rows[0];
          if (!user1_id && !user2_id) {
            // Both users gone, delete couple
            await client.query(`DELETE FROM couples WHERE id = $1`, [coupleId]);
            console.log(`[Account Delete] Deleted empty couple: ${coupleId}`);
          }
        }
      }

      // 4. Delete from users table (if exists)
      await safeDelete(client,
        `DELETE FROM users WHERE id = $1`,
        [userId]
      );

      console.log(`[Account Delete] Database deletion complete for user: ${userId}`);
    });

    // 5. Delete from Supabase auth.users (outside transaction, uses Supabase client)
    console.log(`[Account Delete] Deleting from auth.users: ${userId}`);
    const supabase = createClient();
    const { error: authError } = await supabase.auth.admin.deleteUser(userId);

    if (authError) {
      console.error(`[Account Delete] Failed to delete from auth.users:`, authError);
      // Don't fail the whole operation - the data is already deleted
      // The auth entry will be orphaned but that's acceptable
    } else {
      console.log(`[Account Delete] Successfully deleted from auth.users: ${userId}`);
    }

    console.log(`[Account Delete] Account deletion complete for user: ${userId}`);

    return NextResponse.json({
      success: true,
      message: 'Account deleted successfully',
    });
  } catch (error) {
    console.error('[Account Delete] Error:', error);
    return NextResponse.json(
      { error: 'Failed to delete account' },
      { status: 500 }
    );
  }
});

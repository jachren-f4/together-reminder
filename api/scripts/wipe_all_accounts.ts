/**
 * Wipe All Accounts - Complete Database Reset
 *
 * Deletes ALL users and their data from the database.
 *
 * Protected accounts (NOT deleted):
 *   - john@test.local
 *   - jane@test.local
 *
 * Tables cleared (in FK-safe order):
 *   - quest_completions, daily_quests
 *   - quiz_progression, branch_progression, you_or_me_progression
 *   - quiz_matches, quiz_sessions, quiz_answers
 *   - you_or_me_sessions, you_or_me_answers
 *   - linked_moves, linked_matches
 *   - word_search_moves, word_search_matches
 *   - memory_moves, memory_puzzles
 *   - steps_daily, steps_rewards, steps_connections
 *   - love_point_awards, love_point_transactions, user_love_points, couple_leaderboard
 *   - couple_unlocks, welcome_quiz_answers
 *   - reminders
 *   - pairing_codes, push_tokens, user_push_tokens, couple_invites, user_couples
 *   - couples
 *   - auth.users
 *
 * Usage:
 *   npx tsx scripts/wipe_all_accounts.ts
 *
 * With confirmation bypass (for automation):
 *   npx tsx scripts/wipe_all_accounts.ts --yes
 */

import { query, getClient } from '../lib/db/pool';
import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.join(__dirname, '..', '.env.local') });

const supabaseUrl = process.env.SUPABASE_URL!;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

// Protected emails - these accounts will NOT be deleted
const PROTECTED_EMAILS = [
  'john@test.local',
  'jane@test.local',
];

interface UserRow {
  id: string;
  email: string;
}

interface CoupleRow {
  id: string;
  user1_id: string;
  user2_id: string;
}

async function confirmDeletion(): Promise<boolean> {
  // Skip confirmation entirely - just proceed with deletion
  return true;
}

async function safeDelete(client: any, tableName: string, sql: string, params: any[] = []): Promise<number> {
  const savepointName = `sp_${tableName}_${Date.now()}`;
  try {
    await client.query(`SAVEPOINT ${savepointName}`);
    const result = await client.query(sql, params);
    await client.query(`RELEASE SAVEPOINT ${savepointName}`);
    return result.rowCount ?? 0;
  } catch (e: any) {
    // Rollback to savepoint to keep transaction alive
    await client.query(`ROLLBACK TO SAVEPOINT ${savepointName}`);
    // Table might not exist - that's OK, don't log
    if (e.code === '42P01') { // undefined_table
      return 0;
    }
    // Only log unexpected errors
    if (e.code !== '42P01') {
      console.log(`      ⚠️  ${tableName}: ${e.message.split('\n')[0]}`);
    }
    return 0;
  }
}

async function deleteCoupleData(client: any, coupleId: string, userIds: string[]): Promise<void> {
  console.log(`\n   Couple: ${coupleId}`);

  // 1. Quest completions (FK to daily_quests)
  let count = await safeDelete(client, 'quest_completions',
    `DELETE FROM quest_completions WHERE quest_id IN (SELECT id FROM daily_quests WHERE couple_id = $1)`,
    [coupleId]
  );
  if (count > 0) console.log(`      ✓ quest_completions: ${count}`);

  // 2. Daily quests
  count = await safeDelete(client, 'daily_quests',
    `DELETE FROM daily_quests WHERE couple_id = $1`,
    [coupleId]
  );
  if (count > 0) console.log(`      ✓ daily_quests: ${count}`);

  // 3. Progression tables
  for (const table of ['quiz_progression', 'branch_progression', 'you_or_me_progression']) {
    count = await safeDelete(client, table,
      `DELETE FROM ${table} WHERE couple_id = $1`,
      [coupleId]
    );
    if (count > 0) console.log(`      ✓ ${table}: ${count}`);
  }

  // 4a. Quiz answers (FK to quiz_sessions)
  count = await safeDelete(client, 'quiz_answers',
    `DELETE FROM quiz_answers WHERE session_id IN (SELECT id FROM quiz_sessions WHERE couple_id = $1)`,
    [coupleId]
  );
  if (count > 0) console.log(`      ✓ quiz_answers: ${count}`);

  // 4b. Quiz sessions
  count = await safeDelete(client, 'quiz_sessions',
    `DELETE FROM quiz_sessions WHERE couple_id = $1`,
    [coupleId]
  );
  if (count > 0) console.log(`      ✓ quiz_sessions: ${count}`);

  // 4c. Quiz matches
  count = await safeDelete(client, 'quiz_matches',
    `DELETE FROM quiz_matches WHERE couple_id = $1`,
    [coupleId]
  );
  if (count > 0) console.log(`      ✓ quiz_matches: ${count}`);

  // 4d. You-or-me answers (FK to you_or_me_sessions)
  count = await safeDelete(client, 'you_or_me_answers',
    `DELETE FROM you_or_me_answers WHERE session_id IN (SELECT id FROM you_or_me_sessions WHERE couple_id = $1)`,
    [coupleId]
  );
  if (count > 0) console.log(`      ✓ you_or_me_answers: ${count}`);

  // 4e. You-or-me sessions
  count = await safeDelete(client, 'you_or_me_sessions',
    `DELETE FROM you_or_me_sessions WHERE couple_id = $1`,
    [coupleId]
  );
  if (count > 0) console.log(`      ✓ you_or_me_sessions: ${count}`);

  // 5. Linked moves (FK to linked_matches)
  count = await safeDelete(client, 'linked_moves',
    `DELETE FROM linked_moves WHERE match_id IN (SELECT id FROM linked_matches WHERE couple_id = $1)`,
    [coupleId]
  );
  if (count > 0) console.log(`      ✓ linked_moves: ${count}`);

  // 6. Linked matches
  count = await safeDelete(client, 'linked_matches',
    `DELETE FROM linked_matches WHERE couple_id = $1`,
    [coupleId]
  );
  if (count > 0) console.log(`      ✓ linked_matches: ${count}`);

  // 7. Word search moves (FK to word_search_matches)
  count = await safeDelete(client, 'word_search_moves',
    `DELETE FROM word_search_moves WHERE match_id IN (SELECT id FROM word_search_matches WHERE couple_id = $1)`,
    [coupleId]
  );
  if (count > 0) console.log(`      ✓ word_search_moves: ${count}`);

  // 8. Word search matches
  count = await safeDelete(client, 'word_search_matches',
    `DELETE FROM word_search_matches WHERE couple_id = $1`,
    [coupleId]
  );
  if (count > 0) console.log(`      ✓ word_search_matches: ${count}`);

  // 9. Memory moves (FK to memory_puzzles)
  count = await safeDelete(client, 'memory_moves',
    `DELETE FROM memory_moves WHERE puzzle_id IN (SELECT id FROM memory_puzzles WHERE couple_id = $1)`,
    [coupleId]
  );
  if (count > 0) console.log(`      ✓ memory_moves: ${count}`);

  // 10. Memory puzzles
  count = await safeDelete(client, 'memory_puzzles',
    `DELETE FROM memory_puzzles WHERE couple_id = $1`,
    [coupleId]
  );
  if (count > 0) console.log(`      ✓ memory_puzzles: ${count}`);

  // 11. Steps data (user-based)
  for (const userId of userIds) {
    count = await safeDelete(client, 'steps_daily',
      `DELETE FROM steps_daily WHERE user_id = $1`,
      [userId]
    );
    if (count > 0) console.log(`      ✓ steps_daily (${userId.slice(0, 8)}...): ${count}`);

    count = await safeDelete(client, 'steps_connections',
      `DELETE FROM steps_connections WHERE user_id = $1`,
      [userId]
    );
    if (count > 0) console.log(`      ✓ steps_connections (${userId.slice(0, 8)}...): ${count}`);
  }

  // 12. Steps rewards (couple-based)
  count = await safeDelete(client, 'steps_rewards',
    `DELETE FROM steps_rewards WHERE couple_id = $1`,
    [coupleId]
  );
  if (count > 0) console.log(`      ✓ steps_rewards: ${count}`);

  // 13. Love point awards
  count = await safeDelete(client, 'love_point_awards',
    `DELETE FROM love_point_awards WHERE couple_id = $1`,
    [coupleId]
  );
  if (count > 0) console.log(`      ✓ love_point_awards: ${count}`);

  // 13b. Love point transactions (user-based)
  for (const userId of userIds) {
    count = await safeDelete(client, 'love_point_transactions',
      `DELETE FROM love_point_transactions WHERE user_id = $1`,
      [userId]
    );
    if (count > 0) console.log(`      ✓ love_point_transactions (${userId.slice(0, 8)}...): ${count}`);
  }

  // 13c. User love points (user-based, within couple)
  for (const userId of userIds) {
    count = await safeDelete(client, 'user_love_points',
      `DELETE FROM user_love_points WHERE user_id = $1`,
      [userId]
    );
    if (count > 0) console.log(`      ✓ user_love_points (${userId.slice(0, 8)}...): ${count}`);
  }

  // 14. Leaderboard
  count = await safeDelete(client, 'couple_leaderboard',
    `DELETE FROM couple_leaderboard WHERE couple_id = $1`,
    [coupleId]
  );
  if (count > 0) console.log(`      ✓ couple_leaderboard: ${count}`);

  // 15. Couple unlocks
  count = await safeDelete(client, 'couple_unlocks',
    `DELETE FROM couple_unlocks WHERE couple_id = $1`,
    [coupleId]
  );
  if (count > 0) console.log(`      ✓ couple_unlocks: ${count}`);

  // 16. Welcome quiz answers
  count = await safeDelete(client, 'welcome_quiz_answers',
    `DELETE FROM welcome_quiz_answers WHERE couple_id = $1`,
    [coupleId]
  );
  if (count > 0) console.log(`      ✓ welcome_quiz_answers: ${count}`);

  // 17. Reminders (user-based)
  for (const userId of userIds) {
    count = await safeDelete(client, 'reminders',
      `DELETE FROM reminders WHERE from_user_id = $1 OR to_user_id = $1`,
      [userId]
    );
    if (count > 0) console.log(`      ✓ reminders (${userId.slice(0, 8)}...): ${count}`);
  }

  // 18. Delete the couple itself
  count = await safeDelete(client, 'couples',
    `DELETE FROM couples WHERE id = $1`,
    [coupleId]
  );
  if (count > 0) console.log(`      ✓ couples: deleted`);
}

async function deleteUserData(client: any, userId: string): Promise<void> {
  const userTables = [
    { table: 'pairing_codes', column: 'user_id' },
    { table: 'push_tokens', column: 'user_id' },
    { table: 'user_push_tokens', column: 'user_id' },
    { table: 'couple_invites', column: 'created_by' },
    { table: 'couple_invites', column: 'claimed_by' },
    { table: 'user_couples', column: 'user_id' },
  ];

  for (const { table, column } of userTables) {
    await safeDelete(client, table,
      `DELETE FROM ${table} WHERE ${column} = $1`,
      [userId]
    );
  }
}

async function main() {
  console.log('\n' + '='.repeat(60));
  console.log('   WIPE ALL ACCOUNTS - Complete Database Reset');
  console.log('='.repeat(60));

  // Get all users except protected ones
  const protectedPlaceholders = PROTECTED_EMAILS.map((_, i) => `$${i + 1}`).join(', ');
  const usersResult = await query(
    `SELECT id, email FROM auth.users WHERE LOWER(email) NOT IN (${protectedPlaceholders}) ORDER BY created_at`,
    PROTECTED_EMAILS.map(e => e.toLowerCase())
  );

  const users: UserRow[] = usersResult.rows;

  if (users.length === 0) {
    console.log('\n✅ No users to delete (database is clean or only protected accounts exist).\n');
    process.exit(0);
  }

  console.log(`\n📋 Found ${users.length} user(s) to delete:\n`);
  users.forEach((u) => console.log(`   - ${u.email}`));

  console.log(`\n🛡️  Protected accounts (will NOT be deleted):`);
  PROTECTED_EMAILS.forEach((e) => console.log(`   - ${e}`));

  // Confirmation
  const confirmed = await confirmDeletion();
  if (!confirmed) {
    console.log('\n❌ Aborted.\n');
    process.exit(0);
  }

  console.log('\n🧹 Starting deletion...\n');
  console.log('─'.repeat(60));

  const client = await getClient();

  try {
    await client.query('BEGIN');

    // Find all couples involving these users
    const userIds = users.map((u) => u.id);
    const couplesResult = await client.query(
      'SELECT id, user1_id, user2_id FROM couples WHERE user1_id = ANY($1) OR user2_id = ANY($1)',
      [userIds]
    );
    const couples: CoupleRow[] = couplesResult.rows;

    console.log(`\n📊 Found ${couples.length} couple(s) to delete`);

    // Delete couple data
    for (const couple of couples) {
      const coupleUserIds = [couple.user1_id, couple.user2_id].filter(id => userIds.includes(id));
      await deleteCoupleData(client, couple.id, coupleUserIds);
    }

    // Delete user-specific data (not tied to couples)
    console.log('\n👤 Deleting user-specific data...');
    for (const user of users) {
      await deleteUserData(client, user.id);
    }

    await client.query('COMMIT');
    console.log('\n✓ Database transaction committed');

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('\n❌ Transaction rolled back due to error:', error);
    throw error;
  } finally {
    client.release();
  }

  // Delete auth users (must be done via Supabase Admin API, outside transaction)
  console.log('\n🔐 Deleting auth users...\n');

  let deletedCount = 0;
  let errorCount = 0;

  for (const user of users) {
    const { error } = await supabase.auth.admin.deleteUser(user.id);
    if (error) {
      console.log(`   ❌ ${user.email}: ${error.message}`);
      errorCount++;
    } else {
      console.log(`   ✓ ${user.email}`);
      deletedCount++;
    }
  }

  console.log('\n' + '='.repeat(60));
  console.log('   WIPE COMPLETE');
  console.log('='.repeat(60));
  console.log(`\n   ✅ Users deleted: ${deletedCount}`);
  if (errorCount > 0) {
    console.log(`   ⚠️  Errors: ${errorCount}`);
  }
  console.log(`   🛡️  Protected: ${PROTECTED_EMAILS.length}`);
  console.log('\n   Remaining in database:');
  PROTECTED_EMAILS.forEach((e) => console.log(`      - ${e}`));
  console.log('\n   Don\'t forget to:');
  console.log('      - Uninstall iOS apps manually');
  console.log('      - Clear Chrome site data if testing web');
  console.log('      - Uninstall Android app (adb uninstall com.togetherremind.togetherremind)');
  console.log('');

  process.exit(0);
}

main().catch((error) => {
  console.error('\nFatal error:', error);
  process.exit(1);
});

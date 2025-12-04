/**
 * Wipe ALL accounts except protected dummy accounts
 *
 * This completely removes all users from the database, including:
 * - All couple data and progress
 * - Push tokens
 * - Auth records
 *
 * Protected accounts (not deleted):
 * - john@test.local (aaaaaaaa-1111-1111-1111-111111111111)
 * - jane@test.local (aaaaaaaa-2222-2222-2222-222222222222)
 *
 * Usage:
 *   npx tsx scripts/wipe_all_accounts.ts
 */

import { createClient } from '@supabase/supabase-js';
import { query, getClient } from '../lib/db/pool';
import * as dotenv from 'dotenv';
import * as path from 'path';

// Load environment variables from .env.local
dotenv.config({ path: path.join(__dirname, '..', '.env.local') });

// Validate required environment variables
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing required environment variables:');
  if (!supabaseUrl) console.error('   - SUPABASE_URL');
  if (!supabaseServiceKey) console.error('   - SUPABASE_SERVICE_ROLE_KEY');
  console.error('\nMake sure api/.env.local exists with these values.');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

// Protected accounts - these will NOT be deleted
const PROTECTED_USER_IDS = [
  'aaaaaaaa-1111-1111-1111-111111111111', // john@test.local
  'aaaaaaaa-2222-2222-2222-222222222222', // jane@test.local
];

const PROTECTED_COUPLE_ID = '11111111-1111-1111-1111-111111111111'; // John & Jane's couple

async function getAllUsers(): Promise<{ id: string; email: string }[]> {
  console.log('\n🔍 Finding all users...\n');

  const users: { id: string; email: string }[] = [];

  try {
    const result = await query(
      `SELECT id, email FROM auth.users WHERE id NOT IN ($1, $2)`,
      PROTECTED_USER_IDS
    );

    for (const row of result.rows) {
      users.push({ id: row.id, email: row.email });
      console.log(`   Found: ${row.email} → ${row.id}`);
    }
  } catch (e) {
    console.error('Error querying auth.users:', e);
  }

  return users;
}

async function findCouplesForUsers(userIds: string[]): Promise<string[]> {
  const coupleIds: string[] = [];

  for (const userId of userIds) {
    const result = await query(
      `SELECT id FROM couples WHERE (user1_id = $1 OR user2_id = $1) AND id != $2`,
      [userId, PROTECTED_COUPLE_ID]
    );

    for (const row of result.rows) {
      if (!coupleIds.includes(row.id)) {
        coupleIds.push(row.id);
      }
    }
  }

  return coupleIds;
}

async function wipeCoupleData(coupleId: string, client: any) {
  console.log(`\n   Wiping couple: ${coupleId}`);

  // Quest completions
  await client.query(
    `DELETE FROM quest_completions WHERE quest_id IN (SELECT id FROM daily_quests WHERE couple_id = $1)`,
    [coupleId]
  );

  // Daily quests
  await client.query('DELETE FROM daily_quests WHERE couple_id = $1', [coupleId]);

  // Quiz progression
  await client.query('DELETE FROM quiz_progression WHERE couple_id = $1', [coupleId]);

  // Branch progression
  await client.query('DELETE FROM branch_progression WHERE couple_id = $1', [coupleId]);

  // Quiz matches
  await client.query('DELETE FROM quiz_matches WHERE couple_id = $1', [coupleId]);

  // You-or-me progression
  await client.query('DELETE FROM you_or_me_progression WHERE couple_id = $1', [coupleId]);

  // Linked moves
  await client.query(
    `DELETE FROM linked_moves WHERE match_id IN (SELECT id FROM linked_matches WHERE couple_id = $1)`,
    [coupleId]
  );

  // Linked matches
  await client.query('DELETE FROM linked_matches WHERE couple_id = $1', [coupleId]);

  // Word search moves
  await client.query(
    `DELETE FROM word_search_moves WHERE match_id IN (SELECT id FROM word_search_matches WHERE couple_id = $1)`,
    [coupleId]
  );

  // Word search matches
  await client.query('DELETE FROM word_search_matches WHERE couple_id = $1', [coupleId]);

  // Memory moves (optional table)
  try {
    await client.query(
      `DELETE FROM memory_moves WHERE puzzle_id IN (SELECT id FROM memory_puzzles WHERE couple_id = $1)`,
      [coupleId]
    );
    await client.query('DELETE FROM memory_puzzles WHERE couple_id = $1', [coupleId]);
  } catch (e) {
    // Table might not exist
  }

  // LP awards
  await client.query('DELETE FROM love_point_awards WHERE couple_id = $1', [coupleId]);

  // Leaderboard
  await client.query('DELETE FROM couple_leaderboard WHERE couple_id = $1', [coupleId]);

  // Steps (optional tables)
  try {
    const couple = await client.query('SELECT user1_id, user2_id FROM couples WHERE id = $1', [coupleId]);
    if (couple.rows.length > 0) {
      const { user1_id, user2_id } = couple.rows[0];
      await client.query('DELETE FROM steps_daily WHERE user_id IN ($1, $2)', [user1_id, user2_id]);
      await client.query('DELETE FROM steps_rewards WHERE couple_id = $1', [coupleId]);
    }
  } catch (e) {
    // Tables might not exist
  }

  console.log(`   ✓ Couple data wiped`);
}

async function wipeUserData(userId: string, client: any) {
  console.log(`   Wiping user data: ${userId}`);

  // Push tokens
  await client.query('DELETE FROM push_tokens WHERE user_id = $1', [userId]);

  // Pairing codes
  await client.query('DELETE FROM pairing_codes WHERE user_id = $1', [userId]);

  console.log(`   ✓ User data wiped`);
}

async function deleteCouple(coupleId: string, client: any) {
  await client.query('DELETE FROM couples WHERE id = $1', [coupleId]);
  console.log(`   ✓ Couple deleted: ${coupleId}`);
}

async function deleteAuthUser(userId: string, email: string) {
  const { error } = await supabase.auth.admin.deleteUser(userId);

  if (error) {
    console.error(`   ✗ Failed to delete auth user ${email}: ${error.message}`);
  } else {
    console.log(`   ✓ Auth user deleted: ${email}`);
  }
}

async function main() {
  console.log('\n' + '='.repeat(60));
  console.log('   WIPE ALL ACCOUNTS (except John & Jane)');
  console.log('='.repeat(60));
  console.log('\n   Protected accounts:');
  console.log('   - john@test.local');
  console.log('   - jane@test.local');

  // Find all users except protected ones
  const users = await getAllUsers();

  if (users.length === 0) {
    console.log('\n⚠️  No users to wipe (only protected accounts exist)\n');
    process.exit(0);
  }

  console.log(`\n📊 Found ${users.length} user(s) to wipe`);

  const userIds = users.map(u => u.id);

  // Find couples
  console.log('\n🔍 Finding couples...');
  const coupleIds = await findCouplesForUsers(userIds);

  if (coupleIds.length > 0) {
    console.log(`   Found ${coupleIds.length} couple(s): ${coupleIds.join(', ')}`);
  } else {
    console.log('   No couples found for these users');
  }

  // Start database operations
  const client = await getClient();

  try {
    await client.query('BEGIN');

    // Wipe couple data
    console.log('\n🧹 Wiping couple data...');
    for (const coupleId of coupleIds) {
      await wipeCoupleData(coupleId, client);
    }

    // Wipe user data
    console.log('\n🧹 Wiping user data...');
    for (const userId of userIds) {
      await wipeUserData(userId, client);
    }

    // Delete couples
    console.log('\n🗑️  Deleting couples...');
    for (const coupleId of coupleIds) {
      await deleteCouple(coupleId, client);
    }

    await client.query('COMMIT');

    // Delete auth users (outside transaction)
    console.log('\n🗑️  Deleting auth users...');
    for (const user of users) {
      await deleteAuthUser(user.id, user.email);
    }

    console.log('\n' + '='.repeat(60));
    console.log('✅ All accounts wiped successfully!');
    console.log('='.repeat(60));
    console.log('\n📝 Protected accounts remain:');
    console.log('   - john@test.local');
    console.log('   - jane@test.local');
    console.log('\n📝 Note: Uninstall apps on devices to clear local data\n');

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('\n❌ Failed to wipe accounts:', error);
    throw error;
  } finally {
    client.release();
  }

  process.exit(0);
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});

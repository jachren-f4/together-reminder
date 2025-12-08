/**
 * Reset Test Accounts
 *
 * Deletes test1@togetherremind.com and test2@togetherremind.com
 * and all their associated data (couples, quests, etc.)
 *
 * Usage:
 *   npx tsx scripts/reset_test_accounts.ts
 */

import { query } from '../lib/db/pool';
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

const TEST_EMAILS = [
  'test1@togetherremind.com',
  'test2@togetherremind.com',
];

async function main() {
  console.log('\n=== Reset Test Accounts ===\n');

  // Find users
  const placeholders = TEST_EMAILS.map((_, i) => `$${i + 1}`).join(', ');
  const users = await query(
    `SELECT id, email FROM auth.users WHERE LOWER(email) IN (${placeholders})`,
    TEST_EMAILS.map(e => e.toLowerCase())
  );

  if (users.rows.length === 0) {
    console.log('No test accounts found - already clean!');
    process.exit(0);
  }

  const userIds = users.rows.map((u: any) => u.id);
  console.log(`Found ${users.rows.length} user(s):`);
  users.rows.forEach((u: any) => console.log(`  - ${u.email}`));

  // Find couples
  const couples = await query(
    'SELECT id FROM couples WHERE user1_id = ANY($1) OR user2_id = ANY($1)',
    [userIds]
  );

  // Delete couple data
  for (const couple of couples.rows) {
    console.log(`\nDeleting couple data: ${couple.id}`);

    // Delete in order to avoid FK constraints
    const tables = [
      'quest_completions',
      'daily_quests',
      'quiz_progression',
      'branch_progression',
      'quiz_matches',
      'you_or_me_progression',
      'linked_moves',
      'linked_matches',
      'word_search_moves',
      'word_search_matches',
      'love_point_awards',
      'couple_leaderboard',
      'couples',
    ];

    for (const table of tables) {
      try {
        if (table === 'quest_completions') {
          await query(
            `DELETE FROM quest_completions WHERE quest_id IN (SELECT id FROM daily_quests WHERE couple_id = $1)`,
            [couple.id]
          );
        } else if (table === 'linked_moves') {
          await query(
            `DELETE FROM linked_moves WHERE match_id IN (SELECT id FROM linked_matches WHERE couple_id = $1)`,
            [couple.id]
          );
        } else if (table === 'word_search_moves') {
          await query(
            `DELETE FROM word_search_moves WHERE match_id IN (SELECT id FROM word_search_matches WHERE couple_id = $1)`,
            [couple.id]
          );
        } else if (table === 'couples') {
          await query(`DELETE FROM couples WHERE id = $1`, [couple.id]);
        } else {
          await query(`DELETE FROM ${table} WHERE couple_id = $1`, [couple.id]);
        }
      } catch (e) {
        // Table might not exist, that's OK
      }
    }
  }

  // Delete user data
  console.log('\nDeleting user data...');
  for (const userId of userIds) {
    const userTables = ['pairing_codes', 'push_tokens', 'user_push_tokens', 'couple_invites'];
    for (const table of userTables) {
      try {
        const col = table === 'couple_invites' ? 'created_by' : 'user_id';
        await query(`DELETE FROM ${table} WHERE ${col} = $1`, [userId]);
      } catch (e) {
        // Table might not exist
      }
    }
  }

  // Delete auth users
  console.log('\nDeleting auth users...');
  for (const user of users.rows) {
    const { error } = await supabase.auth.admin.deleteUser(user.id);
    if (error) {
      console.log(`  Error deleting ${user.email}: ${error.message}`);
    } else {
      console.log(`  Deleted: ${user.email}`);
    }
  }

  console.log('\n=== Done! ===\n');
  process.exit(0);
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});

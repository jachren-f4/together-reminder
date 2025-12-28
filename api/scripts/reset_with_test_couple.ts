/**
 * Reset Database with Test Couple
 *
 * Wipes ALL accounts and data, then creates a known test couple.
 * The couple is ready for testing - welcome quiz completed, daily quests generated.
 *
 * Test Users:
 *   - Pertsa: test7001@dev.test (a451049e-183e-47bd-9527-d0b077cd7ac1)
 *   - Kilu: test8001@dev.test (248360c7-fdcc-4e89-b302-005300600779)
 *
 * Passwords use deterministic dev format: DevPass_{sha256(email).substring(0,12)}_2024!
 * Compatible with skipOtpVerificationInDev=true
 *
 * Usage:
 *   npx tsx scripts/reset_with_test_couple.ts
 */

import { query, getClient } from '../lib/db/pool';
import { createClient } from '@supabase/supabase-js';
import { createHash } from 'crypto';
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

// ============================================================================
// TEST COUPLE DATA (HARDCODED)
// ============================================================================

const TEST_USERS = {
  pertsa: {
    id: 'a451049e-183e-47bd-9527-d0b077cd7ac1',
    email: 'test7001@dev.test',
    username: 'Pertsa',
  },
  kilu: {
    id: '248360c7-fdcc-4e89-b302-005300600779',
    email: 'test8001@dev.test',
    username: 'Kilu',
  },
};

const TEST_COUPLE = {
  id: 'd9ffe5a8-325b-43b1-8819-11c6d8fa8e98',
  user1_id: TEST_USERS.pertsa.id,
  user2_id: TEST_USERS.kilu.id,
  brand_id: 'togetherremind',
  total_lp: 30,
};

const TEST_COUPLE_UNLOCKS = {
  couple_id: TEST_COUPLE.id,
  welcome_quiz_completed: true,
  classic_quiz_unlocked: true,
  affirmation_quiz_unlocked: true,
  you_or_me_unlocked: false,
  linked_unlocked: false,
  word_search_unlocked: false,
  steps_unlocked: false,
  onboarding_completed: false,
  lp_intro_shown: true,
  classic_quiz_completed: false,
  affirmation_quiz_completed: false,
};

const TEST_DAILY_QUESTS = [
  {
    id: 'quest_test_classic',
    couple_id: TEST_COUPLE.id,
    quest_type: 'quiz',
    content_id: 'quiz:classic:test',
    sort_order: 0,
    is_side_quest: false,
    metadata: { quizName: 'Lighthearted Quiz', formatType: 'classic' },
    brand_id: 'togetherremind',
  },
  {
    id: 'quest_test_affirmation',
    couple_id: TEST_COUPLE.id,
    quest_type: 'quiz',
    content_id: 'quiz:affirmation:test',
    sort_order: 1,
    is_side_quest: false,
    metadata: { quizName: null, formatType: 'affirmation' },
    brand_id: 'togetherremind',
  },
  {
    id: 'quest_test_youorme',
    couple_id: TEST_COUPLE.id,
    quest_type: 'youOrMe',
    content_id: 'youorme_test',
    sort_order: 2,
    is_side_quest: false,
    metadata: { quizName: null, formatType: 'youOrMe' },
    brand_id: 'togetherremind',
  },
];

const TEST_WELCOME_QUIZ_ANSWERS = [
  {
    id: 'wqa_kilu',
    couple_id: TEST_COUPLE.id,
    user_id: TEST_USERS.kilu.id,
    answers: [
      { answer: 'We said it at the same time', questionId: 'wq1', originalAnswer: 'We said it at the same time' },
      { answer: TEST_USERS.pertsa.id, questionId: 'wq2', originalAnswer: 'My partner' },
      { answer: TEST_USERS.kilu.id, questionId: 'wq3', originalAnswer: 'Me' },
    ],
  },
  {
    id: 'wqa_pertsa',
    couple_id: TEST_COUPLE.id,
    user_id: TEST_USERS.pertsa.id,
    answers: [
      { answer: TEST_USERS.pertsa.id, questionId: 'wq1', originalAnswer: 'Me' },
      { answer: TEST_USERS.pertsa.id, questionId: 'wq2', originalAnswer: 'Me' },
      { answer: TEST_USERS.kilu.id, questionId: 'wq3', originalAnswer: 'My partner' },
    ],
  },
];

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

function getDevPassword(email: string): string {
  const hash = createHash('sha256').update(email).digest('hex');
  return `DevPass_${hash.substring(0, 12)}_2024!`;
}

async function deleteAllUsers(): Promise<void> {
  console.log('\n🧹 Wiping all existing data...\n');

  // Get all users
  const usersResult = await query('SELECT id, email FROM auth.users');
  const users = usersResult.rows;

  if (users.length === 0) {
    console.log('   No users to delete');
    return;
  }

  console.log(`   Found ${users.length} user(s) to delete`);

  // Delete all data from tables in FK-safe order (each table in its own transaction)
  const tables = [
    'quest_completions',
    'daily_quests',
    'quiz_progression',
    'branch_progression',
    'you_or_me_progression',
    'quiz_answers',
    'quiz_sessions',
    'quiz_matches',
    'you_or_me_answers',
    'you_or_me_sessions',
    'linked_moves',
    'linked_matches',
    'word_search_moves',
    'word_search_matches',
    'memory_moves',
    'memory_puzzles',
    'steps_daily',
    'steps_rewards',
    'steps_connections',
    'love_point_awards',
    'love_point_transactions',
    'user_love_points',
    'couple_leaderboard',
    'couple_unlocks',
    'welcome_quiz_answers',
    'reminders',
    'pairing_codes',
    'push_tokens',
    'user_push_tokens',
    'couple_invites',
    'user_couples',
    'couples',
  ];

  for (const table of tables) {
    try {
      await query(`DELETE FROM ${table}`);
      console.log(`   ✓ ${table}`);
    } catch (e: any) {
      if (e.code !== '42P01') { // Ignore "table doesn't exist"
        console.log(`   ⚠️  ${table}: ${e.message.split('\n')[0]}`);
      }
    }
  }

  // Delete auth users via Supabase admin API
  console.log('\n🔐 Deleting auth users...');
  for (const user of users) {
    const { error } = await supabase.auth.admin.deleteUser(user.id);
    if (error) {
      console.log(`   ⚠️  ${user.email}: ${error.message}`);
    } else {
      console.log(`   ✓ ${user.email}`);
    }
  }
}

// Store the actual IDs that Supabase generates
const actualUserIds: { pertsa?: string; kilu?: string } = {};

async function createTestUsers(): Promise<void> {
  console.log('\n👤 Creating test users...\n');

  for (const [name, user] of Object.entries(TEST_USERS)) {
    const password = getDevPassword(user.email);

    // Create user via Supabase admin API
    // Note: App reads 'full_name' from user_metadata, not 'username'
    const { data, error } = await supabase.auth.admin.createUser({
      email: user.email,
      password: password,
      email_confirm: true,
      user_metadata: {
        full_name: user.username,
      },
    });

    if (error) {
      console.error(`   ❌ Failed to create ${name}: ${error.message}`);
      throw error;
    }

    const newId = data.user?.id;
    if (!newId) {
      throw new Error(`No user ID returned for ${name}`);
    }

    // Store the actual ID
    (actualUserIds as any)[name] = newId;

    console.log(`   ✓ ${user.username} (${user.email})`);
    console.log(`      ID: ${newId}`);
    console.log(`      Password: ${password}`);
  }
}

async function createTestData(): Promise<void> {
  console.log('\n📊 Creating test data...\n');

  // Use the actual user IDs from Supabase
  const pertsaId = actualUserIds.pertsa!;
  const kiluId = actualUserIds.kilu!;

  const client = await getClient();
  try {
    await client.query('BEGIN');

    // 1. Create couple
    await client.query(
      `INSERT INTO couples (id, user1_id, user2_id, brand_id, total_lp, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, NOW(), NOW())`,
      [TEST_COUPLE.id, pertsaId, kiluId, TEST_COUPLE.brand_id, TEST_COUPLE.total_lp]
    );
    console.log('   ✓ couples');

    // 2. Create couple_unlocks
    await client.query(
      `INSERT INTO couple_unlocks (
        couple_id, welcome_quiz_completed, classic_quiz_unlocked, affirmation_quiz_unlocked,
        you_or_me_unlocked, linked_unlocked, word_search_unlocked, steps_unlocked,
        onboarding_completed, lp_intro_shown, classic_quiz_completed, affirmation_quiz_completed,
        created_at, updated_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NOW(), NOW())`,
      [
        TEST_COUPLE.id,
        TEST_COUPLE_UNLOCKS.welcome_quiz_completed,
        TEST_COUPLE_UNLOCKS.classic_quiz_unlocked,
        TEST_COUPLE_UNLOCKS.affirmation_quiz_unlocked,
        TEST_COUPLE_UNLOCKS.you_or_me_unlocked,
        TEST_COUPLE_UNLOCKS.linked_unlocked,
        TEST_COUPLE_UNLOCKS.word_search_unlocked,
        TEST_COUPLE_UNLOCKS.steps_unlocked,
        TEST_COUPLE_UNLOCKS.onboarding_completed,
        TEST_COUPLE_UNLOCKS.lp_intro_shown,
        TEST_COUPLE_UNLOCKS.classic_quiz_completed,
        TEST_COUPLE_UNLOCKS.affirmation_quiz_completed,
      ]
    );
    console.log('   ✓ couple_unlocks');

    // 3. Create daily quests
    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);
    const expiry = new Date(today);
    expiry.setUTCHours(23, 59, 59, 0);

    for (const quest of TEST_DAILY_QUESTS) {
      await client.query(
        `INSERT INTO daily_quests (
          id, couple_id, date, quest_type, content_id, sort_order,
          is_side_quest, metadata, generated_at, expires_at, brand_id
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW(), $9, $10)`,
        [
          quest.id,
          TEST_COUPLE.id,
          today,
          quest.quest_type,
          quest.content_id,
          quest.sort_order,
          quest.is_side_quest,
          JSON.stringify(quest.metadata),
          expiry,
          quest.brand_id,
        ]
      );
    }
    console.log('   ✓ daily_quests (3 quests)');

    // 4. Create welcome quiz answers (with actual user IDs)
    const welcomeAnswersKilu = [
      { answer: 'We said it at the same time', questionId: 'wq1', originalAnswer: 'We said it at the same time' },
      { answer: pertsaId, questionId: 'wq2', originalAnswer: 'My partner' },
      { answer: kiluId, questionId: 'wq3', originalAnswer: 'Me' },
    ];
    const welcomeAnswersPertsa = [
      { answer: pertsaId, questionId: 'wq1', originalAnswer: 'Me' },
      { answer: pertsaId, questionId: 'wq2', originalAnswer: 'Me' },
      { answer: kiluId, questionId: 'wq3', originalAnswer: 'My partner' },
    ];

    await client.query(
      `INSERT INTO welcome_quiz_answers (couple_id, user_id, answers, completed_at)
       VALUES ($1, $2, $3, NOW())`,
      [TEST_COUPLE.id, kiluId, JSON.stringify(welcomeAnswersKilu)]
    );
    await client.query(
      `INSERT INTO welcome_quiz_answers (couple_id, user_id, answers, completed_at)
       VALUES ($1, $2, $3, NOW())`,
      [TEST_COUPLE.id, pertsaId, JSON.stringify(welcomeAnswersPertsa)]
    );
    console.log('   ✓ welcome_quiz_answers (2 records)');

    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

async function main() {
  console.log('\n' + '='.repeat(60));
  console.log('   RESET WITH TEST COUPLE');
  console.log('='.repeat(60));

  // Step 1: Delete all existing data
  await deleteAllUsers();

  // Step 2: Create test users
  await createTestUsers();

  // Step 3: Create test data
  await createTestData();

  console.log('\n' + '='.repeat(60));
  console.log('   RESET COMPLETE');
  console.log('='.repeat(60));

  console.log('\n   Test Couple Ready:');
  console.log(`      - ${TEST_USERS.pertsa.username}: ${TEST_USERS.pertsa.email} (ID: ${actualUserIds.pertsa})`);
  console.log(`      - ${TEST_USERS.kilu.username}: ${TEST_USERS.kilu.email} (ID: ${actualUserIds.kilu})`);
  console.log(`      - Couple ID: ${TEST_COUPLE.id}`);

  console.log('\n   Passwords (deterministic dev format):');
  console.log(`      - ${TEST_USERS.pertsa.email}: ${getDevPassword(TEST_USERS.pertsa.email)}`);
  console.log(`      - ${TEST_USERS.kilu.email}: ${getDevPassword(TEST_USERS.kilu.email)}`);

  console.log('\n   State:');
  console.log('      - Welcome quiz: completed');
  console.log('      - Daily quests: generated (3 quests)');
  console.log('      - LP: 30');
  console.log('      - Unlocks: Classic + Affirmation quiz unlocked');

  console.log('\n   Don\'t forget to:');
  console.log('      - Clear app data on devices/emulators (uninstall or clear storage)');
  console.log('      - Use skipOtpVerificationInDev=true for dev password auth');
  console.log('      - Login with the emails above (password auto-generated)');
  console.log('');

  process.exit(0);
}

main().catch((error) => {
  console.error('\nFatal error:', error);
  process.exit(1);
});

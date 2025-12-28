/**
 * Reset Database with Test Couple - You or Me Ready State
 *
 * Wipes ALL accounts and data, then creates a test couple at the state where:
 * - Welcome Quiz: completed
 * - Classic Quiz: completed (both users)
 * - Affirmation Quiz: completed (both users)
 * - You or Me: Pertsa has answered, waiting for Kilu
 *
 * This allows testing:
 * 1. You or Me results screen (when Kilu completes)
 * 2. Linked game (unlocks after You or Me)
 * 3. Word Search (unlocks after Linked)
 *
 * Test Users:
 *   - Pertsa: test7001@dev.test
 *   - Kilu: test8001@dev.test
 *
 * Passwords use deterministic dev format: DevPass_{sha256(email).substring(0,12)}_2024!
 *
 * Usage:
 *   npx tsx scripts/reset_test_couple_youorme_ready.ts
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
// TEST COUPLE DATA
// ============================================================================

const TEST_USERS = {
  pertsa: {
    email: 'test7001@dev.test',
    username: 'Pertsa',
  },
  kilu: {
    email: 'test8001@dev.test',
    username: 'Kilu',
  },
};

const TEST_COUPLE_ID = 'd9ffe5a8-325b-43b1-8819-11c6d8fa8e98';

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

function getDevPassword(email: string): string {
  const hash = createHash('sha256').update(email).digest('hex');
  return `DevPass_${hash.substring(0, 12)}_2024!`;
}

// Store the actual IDs that Supabase generates
const actualUserIds: { pertsa?: string; kilu?: string } = {};

async function deleteAllUsers(): Promise<void> {
  console.log('\n🧹 Wiping all existing data...\n');

  const usersResult = await query('SELECT id, email FROM auth.users');
  const users = usersResult.rows;

  if (users.length === 0) {
    console.log('   No users to delete');
    return;
  }

  console.log(`   Found ${users.length} user(s) to delete`);

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
      if (e.code !== '42P01') {
        console.log(`   ⚠️  ${table}: ${e.message.split('\n')[0]}`);
      }
    }
  }

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

async function createTestUsers(): Promise<void> {
  console.log('\n👤 Creating test users...\n');

  for (const [name, user] of Object.entries(TEST_USERS)) {
    const password = getDevPassword(user.email);

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

    (actualUserIds as any)[name] = newId;

    console.log(`   ✓ ${user.username} (${user.email})`);
    console.log(`      ID: ${newId}`);
    console.log(`      Password: ${password}`);
  }
}

async function createTestData(): Promise<void> {
  console.log('\n📊 Creating test data...\n');

  const pertsaId = actualUserIds.pertsa!;
  const kiluId = actualUserIds.kilu!;
  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);
  const todayStr = today.toISOString().split('T')[0];
  const expiry = new Date(today);
  expiry.setUTCHours(23, 59, 59, 0);

  const client = await getClient();
  try {
    await client.query('BEGIN');

    // 1. Create couple with 90 LP (welcome + classic + affirmation)
    await client.query(
      `INSERT INTO couples (id, user1_id, user2_id, brand_id, total_lp, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, NOW(), NOW())`,
      [TEST_COUPLE_ID, pertsaId, kiluId, 'togetherremind', 90]
    );
    console.log('   ✓ couples (90 LP)');

    // 2. Create couple_unlocks - You or Me is unlocked but not completed
    await client.query(
      `INSERT INTO couple_unlocks (
        couple_id, welcome_quiz_completed, classic_quiz_unlocked, affirmation_quiz_unlocked,
        you_or_me_unlocked, linked_unlocked, word_search_unlocked, steps_unlocked,
        onboarding_completed, lp_intro_shown, classic_quiz_completed, affirmation_quiz_completed,
        created_at, updated_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NOW(), NOW())`,
      [
        TEST_COUPLE_ID,
        true,  // welcome_quiz_completed
        true,  // classic_quiz_unlocked
        true,  // affirmation_quiz_unlocked
        true,  // you_or_me_unlocked
        false, // linked_unlocked (unlocks after You or Me)
        false, // word_search_unlocked
        false, // steps_unlocked
        false, // onboarding_completed
        true,  // lp_intro_shown
        true,  // classic_quiz_completed
        true,  // affirmation_quiz_completed
      ]
    );
    console.log('   ✓ couple_unlocks (You or Me unlocked)');

    // 3. Create daily quests for today
    const quests = [
      {
        id: 'quest_classic_' + todayStr,
        quest_type: 'quiz',
        content_id: 'quiz:classic:completed',
        sort_order: 0,
        metadata: { quizName: 'Lighthearted Quiz', formatType: 'classic' },
      },
      {
        id: 'quest_affirmation_' + todayStr,
        quest_type: 'quiz',
        content_id: 'quiz:affirmation:completed',
        sort_order: 1,
        metadata: { quizName: null, formatType: 'affirmation' },
      },
      {
        id: 'quest_youorme_' + todayStr,
        quest_type: 'youOrMe',
        content_id: 'youorme:active',
        sort_order: 2,
        metadata: { quizName: null, formatType: 'youOrMe' },
      },
    ];

    for (const quest of quests) {
      await client.query(
        `INSERT INTO daily_quests (
          id, couple_id, date, quest_type, content_id, sort_order,
          is_side_quest, metadata, generated_at, expires_at, brand_id
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW(), $9, $10)`,
        [
          quest.id,
          TEST_COUPLE_ID,
          today,
          quest.quest_type,
          quest.content_id,
          quest.sort_order,
          false,
          JSON.stringify(quest.metadata),
          expiry,
          'togetherremind',
        ]
      );
    }
    console.log('   ✓ daily_quests (3 quests)');

    // 4. Create quest_completions for classic and affirmation (both users)
    const completedQuestIds = [quests[0].id, quests[1].id];
    for (const questId of completedQuestIds) {
      await client.query(
        `INSERT INTO quest_completions (quest_id, user_id, completed_at) VALUES ($1, $2, NOW())`,
        [questId, pertsaId]
      );
      await client.query(
        `INSERT INTO quest_completions (quest_id, user_id, completed_at) VALUES ($1, $2, NOW())`,
        [questId, kiluId]
      );
    }
    // Pertsa completed You or Me, Kilu hasn't
    await client.query(
      `INSERT INTO quest_completions (quest_id, user_id, completed_at) VALUES ($1, $2, NOW())`,
      [quests[2].id, pertsaId]
    );
    console.log('   ✓ quest_completions (classic + affirmation: both, youorme: Pertsa only)');

    // 5. Create welcome quiz answers
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
      `INSERT INTO welcome_quiz_answers (couple_id, user_id, answers, completed_at) VALUES ($1, $2, $3, NOW())`,
      [TEST_COUPLE_ID, kiluId, JSON.stringify(welcomeAnswersKilu)]
    );
    await client.query(
      `INSERT INTO welcome_quiz_answers (couple_id, user_id, answers, completed_at) VALUES ($1, $2, $3, NOW())`,
      [TEST_COUPLE_ID, pertsaId, JSON.stringify(welcomeAnswersPertsa)]
    );
    console.log('   ✓ welcome_quiz_answers');

    // 6. Create completed quiz_matches for classic and affirmation
    // Classic quiz match (completed)
    await client.query(
      `INSERT INTO quiz_matches (
        id, couple_id, quiz_id, quiz_type, branch, status,
        player1_answers, player2_answers, player1_answer_count, player2_answer_count,
        match_percentage, player1_score, player2_score,
        player1_id, player2_id, date, created_at, completed_at
      ) VALUES (
        gen_random_uuid(), $1, 'quiz_001', 'classic', 'lighthearted', 'completed',
        $2, $3, 5, 5, 80, 4, 4, $4, $5, $6, NOW(), NOW()
      )`,
      [
        TEST_COUPLE_ID,
        JSON.stringify([0, 1, 2, 0, 1]),  // Pertsa's answers
        JSON.stringify([0, 1, 2, 1, 1]),  // Kilu's answers (4/5 match = 80%)
        pertsaId,
        kiluId,
        today,
      ]
    );
    console.log('   ✓ quiz_matches: classic (completed, 80%)');

    // Affirmation quiz match (completed)
    await client.query(
      `INSERT INTO quiz_matches (
        id, couple_id, quiz_id, quiz_type, branch, status,
        player1_answers, player2_answers, player1_answer_count, player2_answer_count,
        match_percentage, player1_score, player2_score,
        player1_id, player2_id, date, created_at, completed_at
      ) VALUES (
        gen_random_uuid(), $1, 'affirmation_001', 'affirmation', 'emotional', 'completed',
        $2, $3, 5, 5, 60, 3, 3, $4, $5, $6, NOW(), NOW()
      )`,
      [
        TEST_COUPLE_ID,
        JSON.stringify([0, 0, 1, 2, 0]),  // Pertsa's answers
        JSON.stringify([0, 1, 1, 2, 1]),  // Kilu's answers (3/5 match = 60%)
        pertsaId,
        kiluId,
        today,
      ]
    );
    console.log('   ✓ quiz_matches: affirmation (completed, 60%)');

    // 7. Create active You or Me match - Pertsa answered, Kilu hasn't
    // Using relative encoding: 0 = partner, 1 = self
    // Quiz files are named quiz_001.json in data/puzzles/you-or-me/{branch}/
    await client.query(
      `INSERT INTO quiz_matches (
        couple_id, quiz_id, quiz_type, branch, status,
        player1_answers, player2_answers, player1_answer_count, player2_answer_count,
        current_turn_user_id, turn_number,
        player1_id, player2_id, date, created_at
      ) VALUES (
        $1, 'quiz_001', 'you_or_me', 'playful', 'active',
        $2, $3, 10, 0, $4, 1, $5, $6, $7, NOW()
      )`,
      [
        TEST_COUPLE_ID,
        JSON.stringify([1, 0, 1, 1, 0, 0, 1, 0, 1, 0]),  // Pertsa's 10 answers
        JSON.stringify([]),  // Kilu hasn't answered yet
        kiluId,  // It's Kilu's turn
        pertsaId,
        kiluId,
        today,
      ]
    );
    console.log('   ✓ quiz_matches: you_or_me (active, Pertsa answered, waiting for Kilu)');

    // 8. Create LP transaction records (one per user per source)
    const lpSources = [
      { source: 'welcome_quiz', amount: 30 },
      { source: 'classic_quiz', amount: 30 },
      { source: 'affirmation_quiz', amount: 30 },
    ];
    for (const lp of lpSources) {
      // Record for Pertsa
      await client.query(
        `INSERT INTO love_point_transactions (user_id, amount, source, created_at)
         VALUES ($1, $2, $3, NOW())`,
        [pertsaId, lp.amount, lp.source]
      );
      // Record for Kilu
      await client.query(
        `INSERT INTO love_point_transactions (user_id, amount, source, created_at)
         VALUES ($1, $2, $3, NOW())`,
        [kiluId, lp.amount, lp.source]
      );
    }
    console.log('   ✓ love_point_transactions (6 records)');

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
  console.log('   RESET WITH TEST COUPLE - YOU OR ME READY');
  console.log('='.repeat(60));

  await deleteAllUsers();
  await createTestUsers();
  await createTestData();

  console.log('\n' + '='.repeat(60));
  console.log('   RESET COMPLETE');
  console.log('='.repeat(60));

  console.log('\n   Test Couple Ready:');
  console.log(`      - ${TEST_USERS.pertsa.username}: ${TEST_USERS.pertsa.email} (ID: ${actualUserIds.pertsa})`);
  console.log(`      - ${TEST_USERS.kilu.username}: ${TEST_USERS.kilu.email} (ID: ${actualUserIds.kilu})`);
  console.log(`      - Couple ID: ${TEST_COUPLE_ID}`);

  console.log('\n   Passwords (deterministic dev format):');
  console.log(`      - ${TEST_USERS.pertsa.email}: ${getDevPassword(TEST_USERS.pertsa.email)}`);
  console.log(`      - ${TEST_USERS.kilu.email}: ${getDevPassword(TEST_USERS.kilu.email)}`);

  console.log('\n   State:');
  console.log('      - Welcome Quiz: ✅ completed');
  console.log('      - Classic Quiz: ✅ completed (both users)');
  console.log('      - Affirmation Quiz: ✅ completed (both users)');
  console.log('      - You or Me: ⏳ Pertsa answered, waiting for Kilu');
  console.log('      - Linked: 🔒 locked (unlocks after You or Me)');
  console.log('      - Word Search: 🔒 locked (unlocks after Linked)');
  console.log('      - LP: 90');

  console.log('\n   Testing flow:');
  console.log('      1. Login as Kilu → tap You or Me → complete quiz → see results');
  console.log('      2. Linked should unlock → test Linked game');
  console.log('      3. Word Search should unlock → test Word Search');

  console.log('\n   Don\'t forget to:');
  console.log('      - Clear app data on devices/emulators');
  console.log('      - Use skipOtpVerificationInDev=true');
  console.log('');

  process.exit(0);
}

main().catch((error) => {
  console.error('\nFatal error:', error);
  process.exit(1);
});

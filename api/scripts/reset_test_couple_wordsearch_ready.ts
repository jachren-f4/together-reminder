/**
 * Reset Database with Test Couple - Word Search Ready State
 *
 * Wipes ALL accounts and data, then creates a test couple at the state where:
 * - Welcome Quiz: completed
 * - Classic Quiz: completed (both users)
 * - Affirmation Quiz: completed (both users)
 * - You or Me: completed (both users)
 * - Linked: completed (puzzle_001 finished)
 * - Word Search: in progress (Kilu did turn 1, Pertsa's turn)
 *
 * This allows testing:
 * 1. Word Search game from mid-game state
 * 2. Turn-based gameplay between partners
 * 3. Word Search completion flow
 *
 * Test Users:
 *   - Pertsa: test7001@dev.test
 *   - Kilu: test8001@dev.test
 *
 * Passwords use deterministic dev format: DevPass_{sha256(email).substring(0,12)}_2024!
 *
 * Usage:
 *   npx tsx scripts/reset_test_couple_wordsearch_ready.ts
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
const LINKED_MATCH_ID = 'a1b2c3d4-1111-2222-3333-444455556666';
const WORD_SEARCH_MATCH_ID = 'b2c3d4e5-2222-3333-4444-555566667777';

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

    // 1. Create couple with 150 LP (welcome + classic + affirmation + you_or_me + linked)
    await client.query(
      `INSERT INTO couples (id, user1_id, user2_id, brand_id, total_lp, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, NOW(), NOW())`,
      [TEST_COUPLE_ID, pertsaId, kiluId, 'togetherremind', 150]
    );
    console.log('   ✓ couples (150 LP)');

    // 2. Create couple_unlocks - Word Search is unlocked
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
        true,  // linked_unlocked
        true,  // word_search_unlocked (just unlocked!)
        false, // steps_unlocked
        false, // onboarding_completed
        true,  // lp_intro_shown
        true,  // classic_quiz_completed
        true,  // affirmation_quiz_completed
      ]
    );
    console.log('   ✓ couple_unlocks (Word Search unlocked)');

    // 3. Create daily quests for today (all completed)
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
        content_id: 'youorme:completed',
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

    // 4. Create quest_completions for ALL quests (both users)
    for (const quest of quests) {
      await client.query(
        `INSERT INTO quest_completions (quest_id, user_id, completed_at) VALUES ($1, $2, NOW())`,
        [quest.id, pertsaId]
      );
      await client.query(
        `INSERT INTO quest_completions (quest_id, user_id, completed_at) VALUES ($1, $2, NOW())`,
        [quest.id, kiluId]
      );
    }
    console.log('   ✓ quest_completions (all quests completed by both users)');

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
        JSON.stringify([0, 1, 2, 0, 1]),
        JSON.stringify([0, 1, 2, 1, 1]),
        pertsaId,
        kiluId,
        today,
      ]
    );
    console.log('   ✓ quiz_matches: classic (completed, 80%)');

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
        JSON.stringify([0, 0, 1, 2, 0]),
        JSON.stringify([0, 1, 1, 2, 1]),
        pertsaId,
        kiluId,
        today,
      ]
    );
    console.log('   ✓ quiz_matches: affirmation (completed, 60%)');

    // 7. Create completed You or Me match
    await client.query(
      `INSERT INTO quiz_matches (
        id, couple_id, quiz_id, quiz_type, branch, status,
        player1_answers, player2_answers, player1_answer_count, player2_answer_count,
        match_percentage, player1_score, player2_score,
        player1_id, player2_id, date, created_at, completed_at
      ) VALUES (
        gen_random_uuid(), $1, 'quiz_001', 'you_or_me', 'playful', 'completed',
        $2, $3, 10, 10, 70, 7, 7, $4, $5, $6, NOW(), NOW()
      )`,
      [
        TEST_COUPLE_ID,
        JSON.stringify([1, 0, 1, 1, 0, 0, 1, 0, 1, 0]),
        JSON.stringify([1, 0, 1, 0, 0, 0, 1, 1, 1, 0]),
        pertsaId,
        kiluId,
        today,
      ]
    );
    console.log('   ✓ quiz_matches: you_or_me (completed, 70%)');

    // 8. Create COMPLETED Linked match (puzzle_001)
    // Board state: all answer cells filled based on puzzle_001 grid
    // Grid from puzzle_001 (7 cols):
    // Row 0: ".", ".", ".", ".", ".", ".", "."  (indices 0-6, all void/clue)
    // Row 1: ".", "T", ".", "H", "O", "P", "E"  (indices 7-13)
    // Row 2: ".", "O", "V", "E", "R", ".", "."  (indices 14-20)
    // Row 3: ".", "A", ".", ".", ".", "H", "I"  (indices 21-27)
    // Row 4: ".", "S", "U", "N", ".", "A", "S"  (indices 28-34)
    // Row 5: ".", "T", ".", "A", ".", "L", "."  (indices 35-41)
    // Row 6: ".", ".", "O", "N", ".", "V", "."  (indices 42-48)
    // Row 7: ".", ".", ".", "N", "E", "E", "D"  (indices 49-55)
    // Row 8: ".", "W", "A", "Y", ".", ".", "O"  (indices 56-62)
    const linkedBoardState = {
      "8": "T", "10": "H", "11": "O", "12": "P", "13": "E",
      "15": "O", "16": "V", "17": "E", "18": "R",
      "22": "A", "26": "H", "27": "I",
      "29": "S", "30": "U", "31": "N", "33": "A", "34": "S",
      "36": "T", "38": "A", "40": "L",
      "44": "O", "45": "N", "47": "V",
      "52": "N", "53": "E", "54": "E", "55": "D",
      "57": "W", "58": "A", "59": "Y", "62": "O"
    };
    const totalAnswerCells = Object.keys(linkedBoardState).length; // 30 cells

    await client.query(
      `INSERT INTO linked_matches (
        id, couple_id, puzzle_id, status, board_state, current_rack,
        current_turn_user_id, turn_number, player1_score, player2_score,
        player1_vision, player2_vision, locked_cell_count, total_answer_cells,
        player1_id, player2_id, created_at, completed_at
      ) VALUES ($1, $2, $3, $4, $5, $6::text[], $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, NOW(), NOW())`,
      [
        LINKED_MATCH_ID,
        TEST_COUPLE_ID,
        'puzzle_001',
        'completed',
        JSON.stringify(linkedBoardState),
        '{}', // empty rack - game is done (PostgreSQL array format)
        kiluId, // last turn was Kilu
        12, // 12 turns played
        45, // Pertsa's score
        42, // Kilu's score
        0, // visions used
        0,
        totalAnswerCells,
        totalAnswerCells,
        pertsaId,
        kiluId,
      ]
    );
    console.log('   ✓ linked_matches: puzzle_001 (completed)');

    // 9. Create ACTIVE Word Search match (ws_001)
    // Kilu went first and found 2 words: WALK and GRIN
    const foundWords = ['WALK', 'GRIN'];

    await client.query(
      `INSERT INTO word_search_matches (
        id, couple_id, puzzle_id, status, found_words,
        current_turn_user_id, turn_number, words_found_this_turn,
        player1_words_found, player2_words_found,
        player1_score, player2_score,
        player1_hints, player2_hints,
        player1_id, player2_id, created_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, NOW())`,
      [
        WORD_SEARCH_MATCH_ID,
        TEST_COUPLE_ID,
        'ws_001',
        'active',
        JSON.stringify(foundWords),
        pertsaId, // Pertsa's turn now
        2, // Turn 2 (Kilu did turn 1)
        0, // words found this turn (Pertsa hasn't started)
        0, // Pertsa found 0 words
        2, // Kilu found 2 words
        0, // Pertsa score
        8, // Kilu score (WALK=4 + GRIN=4)
        3, // Pertsa hints remaining
        3, // Kilu hints remaining
        pertsaId,
        kiluId,
      ]
    );
    console.log('   ✓ word_search_matches: ws_001 (active, Pertsa\'s turn)');

    // 10. Create LP transaction records
    const lpSources = [
      { source: 'welcome_quiz', amount: 30 },
      { source: 'classic_quiz', amount: 30 },
      { source: 'affirmation_quiz', amount: 30 },
      { source: 'you_or_me', amount: 30 },
      { source: 'linked', amount: 30 },
    ];
    for (const lp of lpSources) {
      await client.query(
        `INSERT INTO love_point_transactions (user_id, amount, source, created_at)
         VALUES ($1, $2, $3, NOW())`,
        [pertsaId, lp.amount, lp.source]
      );
      await client.query(
        `INSERT INTO love_point_transactions (user_id, amount, source, created_at)
         VALUES ($1, $2, $3, NOW())`,
        [kiluId, lp.amount, lp.source]
      );
    }
    console.log('   ✓ love_point_transactions (10 records)');

    // 11. Create branch_progression for linked (completed first puzzle)
    await client.query(
      `INSERT INTO branch_progression (couple_id, activity_type, current_branch, total_completions, max_branches, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, NOW(), NOW())`,
      [TEST_COUPLE_ID, 'linked', 0, 1, 3]
    );
    console.log('   ✓ branch_progression: linked (1 completion)');

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
  console.log('   RESET WITH TEST COUPLE - WORD SEARCH READY');
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
  console.log('      - You or Me: ✅ completed (both users)');
  console.log('      - Linked: ✅ completed (puzzle_001)');
  console.log('      - Word Search: 🎮 in progress (Kilu found WALK, GRIN)');
  console.log('      - Current turn: Pertsa');
  console.log('      - LP: 150');

  console.log('\n   Testing flow:');
  console.log('      1. Login as Pertsa → Word Search shows "Your turn"');
  console.log('      2. Login as Kilu → Word Search shows "Partner\'s turn"');
  console.log('      3. Play as Pertsa → find words, submit turn');
  console.log('      4. Complete puzzle → Steps Together unlocks');

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

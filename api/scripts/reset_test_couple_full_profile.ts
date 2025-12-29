/**
 * Reset Database with Test Couple - Full Us Profile State
 *
 * Wipes ALL accounts and data, then creates a test couple with:
 * - 12+ completed quizzes (to unlock full Us Profile)
 * - Varied answers to populate dimensions, love languages, values
 * - Completed You or Me matches (for partner perception)
 * - All games unlocked
 * - Rich discoveries (different answers between partners)
 *
 * This allows testing:
 * 1. Full Us Profile with all sections visible
 * 2. Dimensions with slider positions
 * 3. Love languages
 * 4. Discoveries with "Try This" actions
 * 5. Partner perception from You or Me
 *
 * Test Users:
 *   - Pertsa: test7001@dev.test
 *   - Kilu: test8001@dev.test
 *
 * Usage:
 *   npx tsx scripts/reset_test_couple_full_profile.ts
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
    'us_profile_cache',
    'conversation_starters',
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

    // 1. Create couple with high LP
    // Note: user_couples is auto-populated by trigger_sync_user_couples
    const totalLP = 450; // 30 * 15 quizzes worth
    await client.query(
      `INSERT INTO couples (id, user1_id, user2_id, brand_id, total_lp, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, NOW(), NOW())`,
      [TEST_COUPLE_ID, pertsaId, kiluId, 'togetherremind', totalLP]
    );
    console.log(`   ✓ couples (${totalLP} LP) + user_couples (auto via trigger)`);

    // 2. Create couple_unlocks - All games unlocked
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
        true,  // word_search_unlocked
        true,  // steps_unlocked
        true,  // onboarding_completed
        true,  // lp_intro_shown
        true,  // classic_quiz_completed
        true,  // affirmation_quiz_completed
      ]
    );
    console.log('   ✓ couple_unlocks (all games unlocked)');

    // 3. Create welcome quiz answers
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

    // 4. Create 12 completed quiz_matches with varied answers
    // This will populate dimensions, love languages, values, and discoveries
    const quizMatches = [
      // Classic quizzes - connection branch (has dimension & love language metadata)
      {
        quizId: 'quiz_001', quizType: 'classic', branch: 'connection',
        p1Answers: [0, 0, 1, 2, 0],  // Pertsa: words of affirmation, internal processor
        p2Answers: [2, 2, 2, 2, 2],  // Kilu: quality time, external processor
        matchPct: 40,
      },
      {
        quizId: 'quiz_002', quizType: 'classic', branch: 'connection',
        p1Answers: [1, 0, 0, 1, 3],
        p2Answers: [1, 1, 2, 1, 1],
        matchPct: 60,
      },
      {
        quizId: 'quiz_003', quizType: 'classic', branch: 'connection',
        p1Answers: [0, 2, 1, 0, 2],
        p2Answers: [0, 1, 1, 0, 0],
        matchPct: 60,
      },
      // Classic quizzes - attachment branch
      {
        quizId: 'quiz_001', quizType: 'classic', branch: 'attachment',
        p1Answers: [0, 1, 2, 0, 1],
        p2Answers: [2, 0, 2, 1, 1],
        matchPct: 40,
      },
      {
        quizId: 'quiz_002', quizType: 'classic', branch: 'attachment',
        p1Answers: [1, 1, 0, 2, 0],
        p2Answers: [1, 0, 0, 2, 2],
        matchPct: 60,
      },
      // Classic quizzes - growth branch
      {
        quizId: 'quiz_001', quizType: 'classic', branch: 'growth',
        p1Answers: [0, 0, 1, 1, 2],
        p2Answers: [1, 0, 1, 0, 2],
        matchPct: 60,
      },
      {
        quizId: 'quiz_002', quizType: 'classic', branch: 'growth',
        p1Answers: [2, 1, 0, 0, 1],
        p2Answers: [2, 2, 0, 0, 1],
        matchPct: 80,
      },
      // Affirmation quizzes - use correct quiz IDs (affirmation_001, etc.)
      {
        quizId: 'affirmation_001', quizType: 'affirmation', branch: 'connection',
        p1Answers: [4, 3, 4, 5, 4],  // Scale 1-5
        p2Answers: [3, 4, 3, 4, 3],
        matchPct: 70,
      },
      {
        quizId: 'affirmation_002', quizType: 'affirmation', branch: 'connection',
        p1Answers: [5, 4, 4, 5, 5],
        p2Answers: [4, 4, 5, 4, 5],
        matchPct: 80,
      },
      // More classic quizzes to reach 10+ total
      {
        quizId: 'quiz_003', quizType: 'classic', branch: 'growth',
        p1Answers: [0, 1, 2, 0, 1],
        p2Answers: [1, 1, 2, 1, 0],
        matchPct: 40,
      },
      {
        quizId: 'quiz_004', quizType: 'classic', branch: 'connection',
        p1Answers: [1, 0, 1, 2, 0],
        p2Answers: [0, 0, 2, 2, 0],
        matchPct: 60,
      },
      {
        quizId: 'quiz_005', quizType: 'classic', branch: 'connection',
        p1Answers: [2, 1, 0, 1, 2],
        p2Answers: [2, 2, 0, 0, 2],
        matchPct: 60,
      },
    ];

    let matchCount = 0;
    for (const match of quizMatches) {
      // Create dates spread over the past week
      const matchDate = new Date(today);
      matchDate.setDate(matchDate.getDate() - Math.floor(matchCount / 2));

      await client.query(
        `INSERT INTO quiz_matches (
          id, couple_id, quiz_id, quiz_type, branch, status,
          player1_answers, player2_answers, player1_answer_count, player2_answer_count,
          match_percentage, player1_score, player2_score,
          player1_id, player2_id, date, created_at, completed_at
        ) VALUES (
          gen_random_uuid(), $1, $2, $3, $4, 'completed',
          $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, NOW(), NOW()
        )`,
        [
          TEST_COUPLE_ID,
          match.quizId,
          match.quizType,
          match.branch,
          JSON.stringify(match.p1Answers),
          JSON.stringify(match.p2Answers),
          match.p1Answers.length,
          match.p2Answers.length,
          match.matchPct,
          Math.round(match.p1Answers.length * match.matchPct / 100),
          Math.round(match.p2Answers.length * match.matchPct / 100),
          pertsaId,
          kiluId,
          matchDate,
        ]
      );
      matchCount++;
    }
    console.log(`   ✓ quiz_matches (${matchCount} completed quizzes)`);

    // 5. Create 3 You or Me matches for partner perception
    // Valid branches: playful, connection, attachment, growth, lighthearted
    const youOrMeMatches = [
      {
        quizId: 'quiz_001', branch: 'playful',
        // For You or Me: 0 = partner, 1 = self (relative encoding)
        // Pertsa answers about who: [0,1,0,1,0] = partner,me,partner,me,partner
        // Kilu answers about who: [1,0,1,0,1] = me,partner,me,partner,me
        p1Answers: [0, 1, 0, 1, 0],
        p2Answers: [1, 0, 1, 0, 1],
      },
      {
        quizId: 'quiz_002', branch: 'playful',
        p1Answers: [1, 0, 1, 1, 0],
        p2Answers: [0, 1, 0, 1, 1],
      },
      {
        quizId: 'quiz_001', branch: 'connection',
        p1Answers: [0, 0, 1, 0, 1],
        p2Answers: [1, 1, 0, 1, 0],
      },
    ];

    for (const match of youOrMeMatches) {
      await client.query(
        `INSERT INTO quiz_matches (
          id, couple_id, quiz_id, quiz_type, branch, status,
          player1_answers, player2_answers, player1_answer_count, player2_answer_count,
          match_percentage, player1_score, player2_score,
          player1_id, player2_id, date, created_at, completed_at
        ) VALUES (
          gen_random_uuid(), $1, $2, 'you_or_me', $3, 'completed',
          $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, NOW(), NOW()
        )`,
        [
          TEST_COUPLE_ID,
          match.quizId,
          match.branch,
          JSON.stringify(match.p1Answers),
          JSON.stringify(match.p2Answers),
          match.p1Answers.length,
          match.p2Answers.length,
          60, // Match percentage
          3,
          3,
          pertsaId,
          kiluId,
          today,
        ]
      );
    }
    console.log(`   ✓ quiz_matches (${youOrMeMatches.length} You or Me completed)`);

    // 6. Create daily quests for today (all completed)
    const quests = [
      {
        id: 'quest_classic_' + todayStr,
        quest_type: 'quiz',
        content_id: 'quiz:classic:completed',
        sort_order: 0,
        metadata: { quizName: 'Connection Quiz', formatType: 'classic' },
      },
      {
        id: 'quest_affirmation_' + todayStr,
        quest_type: 'quiz',
        content_id: 'quiz:affirmation:completed',
        sort_order: 1,
        metadata: { quizName: 'Emotional Intimacy', formatType: 'affirmation' },
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

      // Mark all quests as completed by both users
      await client.query(
        `INSERT INTO quest_completions (quest_id, user_id, completed_at) VALUES ($1, $2, NOW())`,
        [quest.id, pertsaId]
      );
      await client.query(
        `INSERT INTO quest_completions (quest_id, user_id, completed_at) VALUES ($1, $2, NOW())`,
        [quest.id, kiluId]
      );
    }
    console.log('   ✓ daily_quests (3 quests, all completed)');

    // 7. Create LP transaction records
    // Multiple sources representing completed activities
    const lpSources = [
      { source: 'welcome_quiz', amount: 30 },
      { source: 'classic_quiz', amount: 30 },
      { source: 'classic_quiz', amount: 30 },
      { source: 'classic_quiz', amount: 30 },
      { source: 'classic_quiz', amount: 30 },
      { source: 'classic_quiz', amount: 30 },
      { source: 'affirmation_quiz', amount: 30 },
      { source: 'affirmation_quiz', amount: 30 },
      { source: 'you_or_me', amount: 30 },
      { source: 'you_or_me', amount: 30 },
      { source: 'you_or_me', amount: 30 },
      { source: 'linked', amount: 30 },
      { source: 'linked', amount: 30 },
      { source: 'word_search', amount: 30 },
      { source: 'word_search', amount: 30 },
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
    console.log(`   ✓ love_point_transactions (${lpSources.length * 2} records)`);

    // 8. Create some completed Linked and Word Search matches
    // Linked matches - use correct schema: board_state, total_answer_cells
    await client.query(
      `INSERT INTO linked_matches (
        id, couple_id, puzzle_id, branch, status, current_turn_user_id,
        player1_id, player2_id, board_state, total_answer_cells, created_at, completed_at
      ) VALUES (
        gen_random_uuid(), $1, 'puzzle_001', 'casual', 'completed', NULL,
        $2, $3, $4, 15, NOW(), NOW()
      )`,
      [TEST_COUPLE_ID, pertsaId, kiluId, JSON.stringify({})]
    );
    await client.query(
      `INSERT INTO linked_matches (
        id, couple_id, puzzle_id, branch, status, current_turn_user_id,
        player1_id, player2_id, board_state, total_answer_cells, created_at, completed_at
      ) VALUES (
        gen_random_uuid(), $1, 'puzzle_002', 'romantic', 'completed', NULL,
        $2, $3, $4, 15, NOW(), NOW()
      )`,
      [TEST_COUPLE_ID, pertsaId, kiluId, JSON.stringify({})]
    );
    console.log('   ✓ linked_matches (2 completed)');

    // Word Search matches - use correct schema: player1_hints, player2_hints (not hint_count)
    await client.query(
      `INSERT INTO word_search_matches (
        id, couple_id, puzzle_id, status, current_turn_user_id,
        player1_id, player2_id, found_words, player1_hints, player2_hints, created_at, completed_at
      ) VALUES (
        gen_random_uuid(), $1, 'puzzle_001', 'completed', NULL,
        $2, $3, $4, 3, 3, NOW(), NOW()
      )`,
      [TEST_COUPLE_ID, pertsaId, kiluId, JSON.stringify(['LOVE', 'HEART', 'CARE'])]
    );
    await client.query(
      `INSERT INTO word_search_matches (
        id, couple_id, puzzle_id, status, current_turn_user_id,
        player1_id, player2_id, found_words, player1_hints, player2_hints, created_at, completed_at
      ) VALUES (
        gen_random_uuid(), $1, 'puzzle_002', 'completed', NULL,
        $2, $3, $4, 3, 3, NOW(), NOW()
      )`,
      [TEST_COUPLE_ID, pertsaId, kiluId, JSON.stringify(['KISS', 'HUG', 'ROMANCE'])]
    );
    console.log('   ✓ word_search_matches (2 completed)');

    // 9. Directly seed us_profile_cache with rich mock data
    // This bypasses the calculator since quiz JSONs don't have metadata yet
    const mockProfileData = {
      user1Insights: {
        dimensions: [
          { dimensionId: 'stress_processing', leftCount: 8, rightCount: 2, totalAnswers: 10, position: -0.6 },
          { dimensionId: 'social_energy', leftCount: 3, rightCount: 7, totalAnswers: 10, position: 0.4 },
          { dimensionId: 'planning_style', leftCount: 5, rightCount: 5, totalAnswers: 10, position: 0 },
          { dimensionId: 'conflict_approach', leftCount: 7, rightCount: 3, totalAnswers: 10, position: -0.4 },
        ],
        loveLanguages: [
          { language: 'words_of_affirmation', count: 8 },
          { language: 'quality_time', count: 5 },
          { language: 'physical_touch', count: 3 },
          { language: 'acts_of_service', count: 2 },
          { language: 'receiving_gifts', count: 1 },
        ],
        connectionTendencies: [
          { tendency: 'reassurance_needs', totalScore: 35, answerCount: 10, averageScore: 3.5 },
          { tendency: 'closeness_comfort', totalScore: 40, answerCount: 10, averageScore: 4.0 },
        ],
        partnerPerceptionTraits: [
          { trait: 'More romantic', perceivedBy: 'user2', questionText: 'Who is more romantic?' },
          { trait: 'Better listener', perceivedBy: 'user2', questionText: 'Who is a better listener?' },
          { trait: 'More adventurous', perceivedBy: 'user2', questionText: 'Who is more adventurous?' },
        ],
      },
      user2Insights: {
        dimensions: [
          { dimensionId: 'stress_processing', leftCount: 2, rightCount: 8, totalAnswers: 10, position: 0.6 },
          { dimensionId: 'social_energy', leftCount: 6, rightCount: 4, totalAnswers: 10, position: -0.2 },
          { dimensionId: 'planning_style', leftCount: 2, rightCount: 8, totalAnswers: 10, position: 0.6 },
          { dimensionId: 'conflict_approach', leftCount: 3, rightCount: 7, totalAnswers: 10, position: 0.4 },
        ],
        loveLanguages: [
          { language: 'quality_time', count: 7 },
          { language: 'physical_touch', count: 6 },
          { language: 'words_of_affirmation', count: 4 },
          { language: 'acts_of_service', count: 2 },
          { language: 'receiving_gifts', count: 1 },
        ],
        connectionTendencies: [
          { tendency: 'reassurance_needs', totalScore: 28, answerCount: 10, averageScore: 2.8 },
          { tendency: 'closeness_comfort', totalScore: 42, answerCount: 10, averageScore: 4.2 },
        ],
        partnerPerceptionTraits: [
          { trait: 'More organized', perceivedBy: 'user1', questionText: 'Who is more organized?' },
          { trait: 'More patient', perceivedBy: 'user1', questionText: 'Who is more patient?' },
          { trait: 'Funnier', perceivedBy: 'user1', questionText: 'Who is funnier?' },
        ],
      },
      coupleInsights: {
        valueAlignments: [
          { valueId: 'honesty_trust', count: 8 },
          { valueId: 'adventure_growth', count: 6 },
          { valueId: 'quality_time', count: 5 },
          { valueId: 'family_traditions', count: 4 },
          { valueId: 'financial_security', count: 3 },
        ],
        discoveries: [
          {
            quizId: 'quiz_001', quizType: 'classic', questionId: 'q1',
            questionText: 'What makes you feel most loved?',
            user1Answer: 'Hearing "I love you"',
            user2Answer: 'Quality time together',
            category: 'love_languages',
          },
          {
            quizId: 'quiz_001', quizType: 'classic', questionId: 'q2',
            questionText: 'How do you prefer to handle disagreements?',
            user1Answer: 'Take time to think first',
            user2Answer: 'Talk it out immediately',
            category: 'conflict',
          },
          {
            quizId: 'quiz_002', quizType: 'classic', questionId: 'q1',
            questionText: 'When stressed, what helps you most?',
            user1Answer: 'Being alone with my thoughts',
            user2Answer: 'Talking to someone about it',
            category: 'stress',
          },
          {
            quizId: 'quiz_002', quizType: 'classic', questionId: 'q3',
            questionText: 'How do you prefer to spend a free weekend?',
            user1Answer: 'Quiet time at home',
            user2Answer: 'Going out with friends',
            category: 'social',
          },
          {
            quizId: 'quiz_003', quizType: 'classic', questionId: 'q2',
            questionText: 'How important is planning ahead?',
            user1Answer: 'I like to be flexible',
            user2Answer: 'I prefer having a plan',
            category: 'planning',
          },
          {
            quizId: 'quiz_003', quizType: 'classic', questionId: 'q4',
            questionText: 'What\'s your ideal vacation?',
            user1Answer: 'Relaxing beach getaway',
            user2Answer: 'Adventure trip with activities',
            category: 'lifestyle',
          },
          {
            quizId: 'quiz_004', quizType: 'classic', questionId: 'q1',
            questionText: 'How do you show appreciation?',
            user1Answer: 'Telling them what I appreciate',
            user2Answer: 'Doing something nice for them',
            category: 'appreciation',
          },
          {
            quizId: 'quiz_004', quizType: 'classic', questionId: 'q3',
            questionText: 'What\'s most important in a relationship?',
            user1Answer: 'Open communication',
            user2Answer: 'Trust and loyalty',
            category: 'values',
          },
        ],
        questionsExplored: 60,
        totalDiscoveries: 8,
        // Action stats for tracking engagement (seeded for testing)
        actionStats: {
          insightsActedOn: 3,
          conversationsHad: 5,
        },
      },
      totalQuizzesCompleted: 15,
    };

    await client.query(
      `INSERT INTO us_profile_cache (couple_id, user1_insights, user2_insights, couple_insights, total_quizzes_completed, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
       ON CONFLICT (couple_id) DO UPDATE SET
         user1_insights = $2,
         user2_insights = $3,
         couple_insights = $4,
         total_quizzes_completed = $5,
         updated_at = NOW()`,
      [
        TEST_COUPLE_ID,
        JSON.stringify(mockProfileData.user1Insights),
        JSON.stringify(mockProfileData.user2Insights),
        JSON.stringify(mockProfileData.coupleInsights),
        mockProfileData.totalQuizzesCompleted,
      ]
    );
    console.log('   ✓ us_profile_cache (rich mock profile data)');

    // 10. Create conversation starters
    // Schema: trigger_type TEXT, data JSONB { triggerData, promptText, contextText }
    const starters = [
      {
        triggerType: 'value',
        data: {
          triggerData: { valueId: 'honesty_trust', count: 8 },
          promptText: 'You both value honesty and trust highly. Talk about a time when being honest with each other strengthened your relationship.',
          contextText: 'Based on your shared value alignment',
        },
      },
      {
        triggerType: 'dimension',
        data: {
          triggerData: { dimensionId: 'stress_processing', user1Position: -0.6, user2Position: 0.6 },
          promptText: 'Pertsa prefers to process stress internally while Kilu likes to talk it out. How can you better support each other during stressful times?',
          contextText: 'Based on your stress processing difference',
        },
      },
      {
        triggerType: 'love_language',
        data: {
          triggerData: { user1Primary: 'words_of_affirmation', user2Primary: 'quality_time' },
          promptText: 'Your love languages differ - Pertsa values words of affirmation while Kilu prefers quality time. When was the last time you spoke each other\'s love language?',
          contextText: 'Based on your love language difference',
        },
      },
      {
        triggerType: 'discovery',
        data: {
          triggerData: { category: 'planning', questionText: 'How important is planning ahead?' },
          promptText: 'You discovered you have different planning styles. Share one situation where this difference created friction and how you could handle it better.',
          contextText: 'From your discovery about planning preferences',
        },
      },
      {
        triggerType: 'discovery',
        data: {
          triggerData: { trait: 'More romantic', perceivedBy: 'user2' },
          promptText: 'Kilu perceives Pertsa as more romantic. Pertsa, do you agree? What does romance mean to each of you?',
          contextText: 'Based on You or Me perception',
        },
      },
    ];

    for (const starter of starters) {
      await client.query(
        `INSERT INTO conversation_starters (couple_id, trigger_type, data, dismissed, discussed, created_at)
         VALUES ($1, $2, $3, false, false, NOW())`,
        [TEST_COUPLE_ID, starter.triggerType, JSON.stringify(starter.data)]
      );
    }
    console.log(`   ✓ conversation_starters (${starters.length} starters)`);

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
  console.log('   RESET WITH TEST COUPLE - FULL US PROFILE');
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
  console.log('      - Classic Quizzes: ✅ 12 completed');
  console.log('      - Affirmation Quizzes: ✅ 2 completed');
  console.log('      - You or Me: ✅ 3 completed');
  console.log('      - Linked: ✅ 2 completed');
  console.log('      - Word Search: ✅ 2 completed');
  console.log('      - All games: ✅ unlocked');
  console.log('      - LP: 450');

  console.log('\n   Us Profile will show:');
  console.log('      - Dimensions: 4 (stress_processing, social_energy, etc.)');
  console.log('      - Love Languages: Both users ranked');
  console.log('      - Discoveries: Multiple different answers');
  console.log('      - Partner Perception: From You or Me answers');
  console.log('      - Values: Based on question categories');
  console.log('      - Progressive Reveal: Level "established"');

  console.log('\n   Testing flow:');
  console.log('      1. Login as either user');
  console.log('      2. Go to Profile → Us Profile');
  console.log('      3. See full profile with all sections');

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

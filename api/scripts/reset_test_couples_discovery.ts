/**
 * Reset Database with Two Test Couples - Discovery System Testing
 *
 * Creates two contrasting couples to test the discovery relevance system:
 *
 * COUPLE 1: Pertsa & Kilu (Aligned Soulmates)
 * - Similar answers, high match percentages (70-90%)
 * - Few discoveries (~8) - only minor differences
 * - Use case: Testing low-discovery, high-alignment profiles
 *
 * COUPLE 2: Bob & Alice (Opposites Attract)
 * - Very different answers, low match percentages (30-50%)
 * - Many discoveries (~25) - fundamental differences
 * - Use case: Testing high-discovery, high-stakes profiles
 *
 * Test Users:
 *   Couple 1:
 *     - Pertsa: test7001@dev.test
 *     - Kilu: test8001@dev.test
 *   Couple 2:
 *     - Bob: test7002@dev.test
 *     - Alice: test8002@dev.test
 *
 * Usage:
 *   npx tsx scripts/reset_test_couples_discovery.ts
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
// TEST DATA DEFINITIONS
// ============================================================================

const TEST_USERS = {
  // Couple 1: Aligned
  pertsa: { email: 'test7001@dev.test', username: 'Pertsa' },
  kilu: { email: 'test8001@dev.test', username: 'Kilu' },
  // Couple 2: Opposites
  bob: { email: 'test7002@dev.test', username: 'Bob' },
  alice: { email: 'test8002@dev.test', username: 'Alice' },
};

const COUPLE_IDS = {
  aligned: 'd9ffe5a8-325b-43b1-8819-11c6d8fa8e98',
  opposites: 'e8ffe5a8-325b-43b1-8819-11c6d8fa8e99',
};

// Store actual user IDs from Supabase
const actualUserIds: Record<string, string> = {};

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

function getDevPassword(email: string): string {
  const hash = createHash('sha256').update(email).digest('hex');
  return `DevPass_${hash.substring(0, 12)}_2024!`;
}

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
      user_metadata: { full_name: user.username },
    });

    if (error) {
      console.error(`   ❌ Failed to create ${name}: ${error.message}`);
      throw error;
    }

    actualUserIds[name] = data.user?.id!;
    console.log(`   ✓ ${user.username} (${user.email})`);
  }
}

// ============================================================================
// COUPLE 1: PERTSA & KILU (ALIGNED)
// ============================================================================

async function createAlignedCouple(client: any): Promise<void> {
  console.log('\n📊 Creating Couple 1: Pertsa & Kilu (Aligned)...\n');

  const pertsaId = actualUserIds.pertsa;
  const kiluId = actualUserIds.kilu;
  const coupleId = COUPLE_IDS.aligned;
  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);

  // Create couple
  await client.query(
    `INSERT INTO couples (id, user1_id, user2_id, brand_id, total_lp, created_at, updated_at)
     VALUES ($1, $2, $3, 'togetherremind', 360, NOW(), NOW())`,
    [coupleId, pertsaId, kiluId]
  );
  console.log('   ✓ couples (360 LP)');

  // Unlock all games
  await client.query(
    `INSERT INTO couple_unlocks (
      couple_id, welcome_quiz_completed, classic_quiz_unlocked, affirmation_quiz_unlocked,
      you_or_me_unlocked, linked_unlocked, word_search_unlocked, steps_unlocked,
      onboarding_completed, lp_intro_shown, classic_quiz_completed, affirmation_quiz_completed,
      created_at, updated_at
    ) VALUES ($1, true, true, true, true, true, true, true, true, true, true, true, NOW(), NOW())`,
    [coupleId]
  );
  console.log('   ✓ couple_unlocks');

  // Create 12 quizzes with SIMILAR answers (high match %)
  // This couple agrees on most things - few discoveries
  const alignedQuizzes = [
    // Classic quizzes - answers are very similar (1-2 differences per quiz)
    { quizId: 'quiz_001', branch: 'connection', p1: [0, 0, 1, 2, 0], p2: [0, 0, 1, 2, 1], match: 80 },
    { quizId: 'quiz_002', branch: 'connection', p1: [1, 1, 0, 1, 2], p2: [1, 1, 0, 1, 2], match: 100 },
    { quizId: 'quiz_003', branch: 'connection', p1: [2, 0, 2, 0, 1], p2: [2, 0, 2, 1, 1], match: 80 },
    { quizId: 'quiz_001', branch: 'attachment', p1: [0, 1, 1, 2, 0], p2: [0, 1, 1, 2, 0], match: 100 },
    { quizId: 'quiz_002', branch: 'attachment', p1: [1, 0, 2, 1, 1], p2: [1, 0, 2, 1, 0], match: 80 },
    { quizId: 'quiz_001', branch: 'growth', p1: [0, 2, 1, 0, 2], p2: [0, 2, 1, 0, 2], match: 100 },
    { quizId: 'quiz_002', branch: 'growth', p1: [2, 1, 0, 2, 1], p2: [2, 1, 1, 2, 1], match: 80 },
    { quizId: 'quiz_003', branch: 'growth', p1: [1, 1, 2, 0, 0], p2: [1, 1, 2, 0, 0], match: 100 },
    // Affirmation quizzes
    { quizId: 'affirmation_001', branch: 'connection', p1: [4, 4, 5, 4, 4], p2: [4, 4, 5, 4, 5], match: 80, type: 'affirmation' },
    { quizId: 'affirmation_002', branch: 'connection', p1: [5, 4, 4, 5, 4], p2: [5, 4, 4, 5, 4], match: 100, type: 'affirmation' },
    // More classic to reach 12
    { quizId: 'quiz_004', branch: 'connection', p1: [0, 1, 2, 0, 1], p2: [0, 1, 2, 0, 1], match: 100 },
    { quizId: 'quiz_005', branch: 'connection', p1: [1, 0, 1, 2, 0], p2: [1, 0, 1, 2, 1], match: 80 },
  ];

  for (let i = 0; i < alignedQuizzes.length; i++) {
    const q = alignedQuizzes[i];
    const matchDate = new Date(today);
    matchDate.setDate(matchDate.getDate() - Math.floor(i / 2));

    await client.query(
      `INSERT INTO quiz_matches (
        id, couple_id, quiz_id, quiz_type, branch, status,
        player1_answers, player2_answers, player1_answer_count, player2_answer_count,
        match_percentage, player1_score, player2_score,
        player1_id, player2_id, date, created_at, completed_at
      ) VALUES (
        gen_random_uuid(), $1, $2, $3, $4, 'completed',
        $5, $6, 5, 5, $7, $8, $8, $9, $10, $11, NOW(), NOW()
      )`,
      [
        coupleId, q.quizId, q.type || 'classic', q.branch,
        JSON.stringify(q.p1), JSON.stringify(q.p2),
        q.match, Math.round(q.match / 20),
        pertsaId, kiluId, matchDate,
      ]
    );
  }
  console.log(`   ✓ quiz_matches (${alignedQuizzes.length} quizzes, avg 90% match)`);

  // Create profile cache with few discoveries
  const alignedProfile = {
    user1Insights: {
      dimensions: [
        { dimensionId: 'stress_processing', position: -0.2 },
        { dimensionId: 'social_energy', position: 0.3 },
        { dimensionId: 'planning_style', position: 0.1 },
        { dimensionId: 'conflict_approach', position: -0.1 },
      ],
      loveLanguages: [
        { language: 'quality_time', count: 7 },
        { language: 'words_of_affirmation', count: 6 },
        { language: 'physical_touch', count: 4 },
      ],
    },
    user2Insights: {
      dimensions: [
        { dimensionId: 'stress_processing', position: -0.1 },
        { dimensionId: 'social_energy', position: 0.2 },
        { dimensionId: 'planning_style', position: 0.2 },
        { dimensionId: 'conflict_approach', position: 0.0 },
      ],
      loveLanguages: [
        { language: 'quality_time', count: 8 },
        { language: 'words_of_affirmation', count: 5 },
        { language: 'physical_touch', count: 5 },
      ],
    },
    coupleInsights: {
      discoveries: [
        // Only 8 discoveries - minor differences
        {
          quizId: 'quiz_001', questionId: 'q5', category: 'lifestyle',
          questionText: 'How do you prefer to spend a lazy Sunday?',
          user1Answer: 'Reading together in silence',
          user2Answer: 'Watching a movie together',
        },
        {
          quizId: 'quiz_003', questionId: 'q4', category: 'social',
          questionText: 'At a party, you typically...',
          user1Answer: 'Stay close to my partner',
          user2Answer: 'Mingle but check in often',
        },
        {
          quizId: 'quiz_002', questionId: 'q5', category: 'appreciation',
          questionText: 'What makes you feel most appreciated?',
          user1Answer: 'Verbal acknowledgment',
          user2Answer: 'Small thoughtful gestures',
        },
        {
          quizId: 'quiz_005', questionId: 'q5', category: 'daily_routines',
          questionText: 'Morning routine preference?',
          user1Answer: 'Slow and relaxed start',
          user2Answer: 'Efficient and structured',
        },
        {
          quizId: 'quiz_001', questionId: 'q2', category: 'communication',
          questionText: 'When something bothers you, you...',
          user1Answer: 'Bring it up when ready',
          user2Answer: 'Mention it casually',
        },
        {
          quizId: 'quiz_004', questionId: 'q1', category: 'leisure',
          questionText: 'Ideal vacation style?',
          user1Answer: 'Beach relaxation',
          user2Answer: 'Cultural exploration',
        },
        {
          quizId: 'affirmation_001', questionId: 'q5', category: 'emotional_support',
          questionText: 'I feel most supported when...',
          user1Answer: 'Partner listens without solving',
          user2Answer: 'Partner offers solutions',
        },
        {
          quizId: 'quiz_003', questionId: 'q2', category: 'household',
          questionText: 'Approach to household chores?',
          user1Answer: 'Do them together',
          user2Answer: 'Divide and conquer',
        },
      ],
      totalDiscoveries: 8,
    },
    totalQuizzesCompleted: 12,
  };

  await client.query(
    `INSERT INTO us_profile_cache (couple_id, user1_insights, user2_insights, couple_insights, total_quizzes_completed, created_at, updated_at)
     VALUES ($1, $2, $3, $4, $5, NOW(), NOW())`,
    [
      coupleId,
      JSON.stringify(alignedProfile.user1Insights),
      JSON.stringify(alignedProfile.user2Insights),
      JSON.stringify(alignedProfile.coupleInsights),
      alignedProfile.totalQuizzesCompleted,
    ]
  );
  console.log('   ✓ us_profile_cache (8 discoveries, aligned couple)');
}

// ============================================================================
// COUPLE 2: BOB & ALICE (OPPOSITES)
// ============================================================================

async function createOppositesCouple(client: any): Promise<void> {
  console.log('\n📊 Creating Couple 2: Bob & Alice (Opposites)...\n');

  const bobId = actualUserIds.bob;
  const aliceId = actualUserIds.alice;
  const coupleId = COUPLE_IDS.opposites;
  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);

  // Create couple
  await client.query(
    `INSERT INTO couples (id, user1_id, user2_id, brand_id, total_lp, created_at, updated_at)
     VALUES ($1, $2, $3, 'togetherremind', 360, NOW(), NOW())`,
    [coupleId, bobId, aliceId]
  );
  console.log('   ✓ couples (360 LP)');

  // Unlock all games
  await client.query(
    `INSERT INTO couple_unlocks (
      couple_id, welcome_quiz_completed, classic_quiz_unlocked, affirmation_quiz_unlocked,
      you_or_me_unlocked, linked_unlocked, word_search_unlocked, steps_unlocked,
      onboarding_completed, lp_intro_shown, classic_quiz_completed, affirmation_quiz_completed,
      created_at, updated_at
    ) VALUES ($1, true, true, true, true, true, true, true, true, true, true, true, NOW(), NOW())`,
    [coupleId]
  );
  console.log('   ✓ couple_unlocks');

  // Create 12 quizzes with OPPOSITE answers (low match %)
  // This couple disagrees on most things - many discoveries
  const oppositeQuizzes = [
    // Classic quizzes - answers are very different (3-4 differences per quiz)
    { quizId: 'quiz_001', branch: 'connection', p1: [0, 0, 0, 0, 0], p2: [2, 2, 2, 2, 2], match: 20 },
    { quizId: 'quiz_002', branch: 'connection', p1: [0, 1, 0, 1, 0], p2: [2, 0, 2, 0, 2], match: 20 },
    { quizId: 'quiz_003', branch: 'connection', p1: [1, 0, 1, 0, 1], p2: [0, 2, 0, 2, 0], match: 20 },
    { quizId: 'quiz_001', branch: 'attachment', p1: [0, 0, 0, 0, 0], p2: [2, 2, 2, 2, 1], match: 20 },
    { quizId: 'quiz_002', branch: 'attachment', p1: [1, 1, 0, 0, 1], p2: [0, 0, 2, 2, 0], match: 20 },
    { quizId: 'quiz_001', branch: 'growth', p1: [0, 0, 1, 0, 0], p2: [2, 2, 0, 2, 2], match: 20 },
    { quizId: 'quiz_002', branch: 'growth', p1: [0, 1, 0, 1, 0], p2: [2, 0, 2, 0, 2], match: 20 },
    { quizId: 'quiz_003', branch: 'growth', p1: [1, 0, 0, 0, 1], p2: [0, 2, 2, 2, 0], match: 20 },
    // Affirmation quizzes - opposite ends of scale
    { quizId: 'affirmation_001', branch: 'connection', p1: [5, 5, 5, 5, 5], p2: [2, 2, 2, 2, 2], match: 20, type: 'affirmation' },
    { quizId: 'affirmation_002', branch: 'connection', p1: [1, 1, 5, 5, 1], p2: [5, 5, 1, 1, 5], match: 20, type: 'affirmation' },
    // More classic
    { quizId: 'quiz_004', branch: 'connection', p1: [0, 0, 0, 0, 0], p2: [2, 2, 2, 2, 2], match: 0 },
    { quizId: 'quiz_005', branch: 'connection', p1: [0, 1, 0, 1, 0], p2: [2, 0, 2, 0, 2], match: 20 },
  ];

  for (let i = 0; i < oppositeQuizzes.length; i++) {
    const q = oppositeQuizzes[i];
    const matchDate = new Date(today);
    matchDate.setDate(matchDate.getDate() - Math.floor(i / 2));

    await client.query(
      `INSERT INTO quiz_matches (
        id, couple_id, quiz_id, quiz_type, branch, status,
        player1_answers, player2_answers, player1_answer_count, player2_answer_count,
        match_percentage, player1_score, player2_score,
        player1_id, player2_id, date, created_at, completed_at
      ) VALUES (
        gen_random_uuid(), $1, $2, $3, $4, 'completed',
        $5, $6, 5, 5, $7, $8, $8, $9, $10, $11, NOW(), NOW()
      )`,
      [
        coupleId, q.quizId, q.type || 'classic', q.branch,
        JSON.stringify(q.p1), JSON.stringify(q.p2),
        q.match, Math.round(q.match / 20),
        bobId, aliceId, matchDate,
      ]
    );
  }
  console.log(`   ✓ quiz_matches (${oppositeQuizzes.length} quizzes, avg 20% match)`);

  // Create profile cache with MANY discoveries across different categories
  const oppositesProfile = {
    user1Insights: {
      dimensions: [
        { dimensionId: 'stress_processing', position: -0.8 },  // Bob: very internal
        { dimensionId: 'social_energy', position: -0.7 },      // Bob: introvert
        { dimensionId: 'planning_style', position: -0.6 },     // Bob: spontaneous
        { dimensionId: 'conflict_approach', position: -0.8 },  // Bob: needs space
      ],
      loveLanguages: [
        { language: 'words_of_affirmation', count: 9 },
        { language: 'quality_time', count: 3 },
        { language: 'physical_touch', count: 2 },
      ],
    },
    user2Insights: {
      dimensions: [
        { dimensionId: 'stress_processing', position: 0.8 },   // Alice: very external
        { dimensionId: 'social_energy', position: 0.7 },       // Alice: extrovert
        { dimensionId: 'planning_style', position: 0.6 },      // Alice: structured
        { dimensionId: 'conflict_approach', position: 0.8 },   // Alice: address immediately
      ],
      loveLanguages: [
        { language: 'physical_touch', count: 8 },
        { language: 'acts_of_service', count: 6 },
        { language: 'quality_time', count: 4 },
      ],
    },
    coupleInsights: {
      discoveries: [
        // HIGH STAKES (8 discoveries)
        {
          quizId: 'quiz_001', questionId: 'q1', category: 'family_planning',
          questionText: 'How do you feel about having children?',
          user1Answer: 'Definitely want kids in the next few years',
          user2Answer: 'Still figuring out if parenthood is for me',
          stakesLevel: 'high',
        },
        {
          quizId: 'quiz_001', questionId: 'q2', category: 'finances',
          questionText: 'When money is tight, you prefer to...',
          user1Answer: 'Cut back on everything equally',
          user2Answer: 'Prioritize what matters, cut the rest completely',
          stakesLevel: 'high',
        },
        {
          quizId: 'quiz_002', questionId: 'q1', category: 'career',
          questionText: 'Career vs family time priority?',
          user1Answer: 'Career comes first in these years',
          user2Answer: 'Family time is non-negotiable',
          stakesLevel: 'high',
        },
        {
          quizId: 'quiz_002', questionId: 'q3', category: 'intimacy',
          questionText: 'Ideal frequency of physical intimacy?',
          user1Answer: 'Several times a week',
          user2Answer: 'Quality over quantity, maybe weekly',
          stakesLevel: 'high',
        },
        {
          quizId: 'quiz_003', questionId: 'q1', category: 'living_location',
          questionText: 'Where do you want to live long-term?',
          user1Answer: 'City center, close to everything',
          user2Answer: 'Quiet suburbs with nature',
          stakesLevel: 'high',
        },
        {
          quizId: 'quiz_003', questionId: 'q2', category: 'in_laws',
          questionText: 'How often should we see extended family?',
          user1Answer: 'Monthly at most',
          user2Answer: 'Every week if possible',
          stakesLevel: 'high',
        },
        {
          quizId: 'quiz_004', questionId: 'q1', category: 'financial_philosophy',
          questionText: 'How should we handle savings?',
          user1Answer: 'Save aggressively, enjoy later',
          user2Answer: 'Balance saving with enjoying now',
          stakesLevel: 'high',
        },
        {
          quizId: 'quiz_004', questionId: 'q2', category: 'life_goals',
          questionText: 'What does success look like in 10 years?',
          user1Answer: 'Financial independence and freedom',
          user2Answer: 'Strong family and community roots',
          stakesLevel: 'high',
        },

        // MEDIUM STAKES (10 discoveries)
        {
          quizId: 'quiz_001', questionId: 'q3', category: 'stress',
          questionText: 'When stressed, what helps you most?',
          user1Answer: 'Being alone with my thoughts',
          user2Answer: 'Talking to someone about it',
          stakesLevel: 'medium',
        },
        {
          quizId: 'quiz_001', questionId: 'q4', category: 'conflict',
          questionText: 'After a disagreement, you need...',
          user1Answer: 'Time alone to process',
          user2Answer: 'To talk it through immediately',
          stakesLevel: 'medium',
        },
        {
          quizId: 'quiz_002', questionId: 'q2', category: 'communication',
          questionText: 'How do you prefer to discuss problems?',
          user1Answer: 'Think first, discuss when ready',
          user2Answer: 'Talk through it as it happens',
          stakesLevel: 'medium',
        },
        {
          quizId: 'quiz_002', questionId: 'q4', category: 'social',
          questionText: 'Ideal weekend plans?',
          user1Answer: 'Quiet time at home',
          user2Answer: 'Going out with friends',
          stakesLevel: 'medium',
        },
        {
          quizId: 'quiz_003', questionId: 'q3', category: 'daily_routines',
          questionText: 'Morning routine preference?',
          user1Answer: 'Slow start, no set schedule',
          user2Answer: 'Early alarm, structured morning',
          stakesLevel: 'medium',
        },
        {
          quizId: 'quiz_003', questionId: 'q4', category: 'household',
          questionText: 'How clean should the house be?',
          user1Answer: 'Lived-in and comfortable',
          user2Answer: 'Spotless and organized',
          stakesLevel: 'medium',
        },
        {
          quizId: 'quiz_004', questionId: 'q3', category: 'work_life_balance',
          questionText: 'Working from home preference?',
          user1Answer: 'Love it, more focus',
          user2Answer: 'Need the office for separation',
          stakesLevel: 'medium',
        },
        {
          quizId: 'quiz_004', questionId: 'q4', category: 'emotional_support',
          questionText: 'When you're upset, you want...',
          user1Answer: 'Space to figure it out',
          user2Answer: 'Comfort and presence',
          stakesLevel: 'medium',
        },
        {
          quizId: 'quiz_005', questionId: 'q1', category: 'friendships',
          questionText: 'How important are separate friendships?',
          user1Answer: 'Very important, need own space',
          user2Answer: 'Prefer shared friend groups',
          stakesLevel: 'medium',
        },
        {
          quizId: 'quiz_005', questionId: 'q2', category: 'trust',
          questionText: 'Sharing passwords and accounts?',
          user1Answer: 'Some privacy is healthy',
          user2Answer: 'Complete transparency always',
          stakesLevel: 'medium',
        },

        // LIGHT STAKES (7 discoveries)
        {
          quizId: 'quiz_001', questionId: 'q5', category: 'food',
          questionText: 'Dining out vs cooking at home?',
          user1Answer: 'Cook at home most nights',
          user2Answer: 'Eat out or order in often',
          stakesLevel: 'light',
        },
        {
          quizId: 'quiz_002', questionId: 'q5', category: 'entertainment',
          questionText: 'Movie night preference?',
          user1Answer: 'Action and sci-fi',
          user2Answer: 'Romantic comedies',
          stakesLevel: 'light',
        },
        {
          quizId: 'quiz_003', questionId: 'q5', category: 'hobbies',
          questionText: 'How do you like to exercise?',
          user1Answer: 'Solo activities like running',
          user2Answer: 'Group classes or team sports',
          stakesLevel: 'light',
        },
        {
          quizId: 'quiz_004', questionId: 'q5', category: 'travel',
          questionText: 'Vacation planning style?',
          user1Answer: 'Go with the flow',
          user2Answer: 'Detailed itinerary',
          stakesLevel: 'light',
        },
        {
          quizId: 'quiz_005', questionId: 'q3', category: 'aesthetics',
          questionText: 'Home decor preference?',
          user1Answer: 'Minimalist and clean',
          user2Answer: 'Cozy and full of personality',
          stakesLevel: 'light',
        },
        {
          quizId: 'quiz_005', questionId: 'q4', category: 'leisure',
          questionText: 'Ideal way to relax?',
          user1Answer: 'Gaming or reading alone',
          user2Answer: 'Social activities or crafts',
          stakesLevel: 'light',
        },
        {
          quizId: 'quiz_005', questionId: 'q5', category: 'dining',
          questionText: 'Splitting the bill on dates?',
          user1Answer: 'Take turns paying',
          user2Answer: 'Always split evenly',
          stakesLevel: 'light',
        },
      ],
      totalDiscoveries: 25,
    },
    totalQuizzesCompleted: 12,
  };

  await client.query(
    `INSERT INTO us_profile_cache (couple_id, user1_insights, user2_insights, couple_insights, total_quizzes_completed, created_at, updated_at)
     VALUES ($1, $2, $3, $4, $5, NOW(), NOW())`,
    [
      coupleId,
      JSON.stringify(oppositesProfile.user1Insights),
      JSON.stringify(oppositesProfile.user2Insights),
      JSON.stringify(oppositesProfile.coupleInsights),
      oppositesProfile.totalQuizzesCompleted,
    ]
  );
  console.log('   ✓ us_profile_cache (25 discoveries: 8 high, 10 medium, 7 light stakes)');
}

// ============================================================================
// MAIN
// ============================================================================

async function main() {
  console.log('\n' + '='.repeat(70));
  console.log('   RESET WITH TWO TEST COUPLES - DISCOVERY SYSTEM TESTING');
  console.log('='.repeat(70));

  await deleteAllUsers();
  await createTestUsers();

  const client = await getClient();
  try {
    await client.query('BEGIN');
    await createAlignedCouple(client);
    await createOppositesCouple(client);
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }

  console.log('\n' + '='.repeat(70));
  console.log('   RESET COMPLETE');
  console.log('='.repeat(70));

  console.log('\n   COUPLE 1: Pertsa & Kilu (Aligned Soulmates)');
  console.log('   ─────────────────────────────────────────');
  console.log(`      Email: ${TEST_USERS.pertsa.email} / ${TEST_USERS.kilu.email}`);
  console.log(`      Password: ${getDevPassword(TEST_USERS.pertsa.email)}`);
  console.log('      Discoveries: 8 (minor lifestyle differences)');
  console.log('      Match rate: ~90%');
  console.log('      Use case: Testing aligned couple, few discoveries');

  console.log('\n   COUPLE 2: Bob & Alice (Opposites Attract)');
  console.log('   ─────────────────────────────────────────');
  console.log(`      Email: ${TEST_USERS.bob.email} / ${TEST_USERS.alice.email}`);
  console.log(`      Password: ${getDevPassword(TEST_USERS.bob.email)}`);
  console.log('      Discoveries: 25 (8 high, 10 medium, 7 light stakes)');
  console.log('      Match rate: ~20%');
  console.log('      Use case: Testing discovery ranking, stakes categorization');

  console.log('\n   Testing the Discovery Relevance System:');
  console.log('      1. Login as Bob → See many high-stakes discoveries');
  console.log('      2. Login as Pertsa → See few, light discoveries');
  console.log('      3. Compare how "Worth Discussing" surfaces different content');

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

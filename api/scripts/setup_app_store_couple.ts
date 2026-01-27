/**
 * Setup App Store Screenshot Couple
 *
 * Creates a test couple with 7 days of "active" usage history for
 * taking realistic App Store screenshots on a physical device.
 *
 * Test Users:
 *   - Johnny: test2011@dev.test
 *   - Julia: test2015@dev.test
 *
 * What gets created:
 *   - 2,800 LP (3 magnets unlocked, 78% to 4th)
 *   - 7 days of quiz history (14 quizzes total)
 *   - 3 completed You or Me games
 *   - 4 completed Linked matches
 *   - 4 completed Word Search matches
 *   - 7 days of steps data with rewards
 *   - All games unlocked
 *   - Full Us Profile with discoveries
 *
 * Usage:
 *   npx tsx scripts/setup_app_store_couple.ts
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
  johnny: { email: 'test2011@dev.test', username: 'Johnny' },
  julia: { email: 'test2015@dev.test', username: 'Julia' },
};

const COUPLE_ID = 'a1b2c3d4-5678-9abc-def0-123456789abc';

// Store actual user IDs from Supabase
const actualUserIds: Record<string, string> = {};

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

function getDevPassword(email: string): string {
  const hash = createHash('sha256').update(email).digest('hex');
  return `DevPass_${hash.substring(0, 12)}_2024!`;
}

function daysAgo(days: number): Date {
  const date = new Date();
  date.setDate(date.getDate() - days);
  date.setUTCHours(12, 0, 0, 0);
  return date;
}

function daysAgoDateStr(days: number): string {
  const date = new Date();
  date.setDate(date.getDate() - days);
  return date.toISOString().split('T')[0];
}

async function deleteTestUsers(): Promise<void> {
  console.log('\n🧹 Cleaning up existing test users...\n');

  // Find and delete our specific test users
  const emails = Object.values(TEST_USERS).map(u => u.email);
  const usersResult = await query(
    'SELECT id, email FROM auth.users WHERE email = ANY($1)',
    [emails]
  );

  if (usersResult.rows.length === 0) {
    console.log('   No existing test users found');
    return;
  }

  const userIds = usersResult.rows.map(r => r.id);
  console.log(`   Found ${usersResult.rows.length} test user(s) to delete`);

  // Delete related data in order
  const tables = [
    'us_profile_cache',
    'conversation_starters',
    'quest_completions',
    'daily_quests',
    'quiz_matches',
    'linked_moves',
    'linked_matches',
    'word_search_moves',
    'word_search_matches',
    'steps_daily',
    'steps_rewards',
    'steps_connections',
    'love_point_awards',
    'couple_unlocks',
    'push_tokens',
    'user_couples',
    'couples',
  ];

  // Find couples for these users
  const couplesResult = await query(
    'SELECT id FROM couples WHERE user1_id = ANY($1) OR user2_id = ANY($1)',
    [userIds]
  );
  const coupleIds = couplesResult.rows.map(r => r.id);

  if (coupleIds.length > 0) {
    for (const table of tables) {
      try {
        if (table === 'couples') {
          await query('DELETE FROM couples WHERE id = ANY($1)', [coupleIds]);
        } else if (table === 'user_couples') {
          await query('DELETE FROM user_couples WHERE user_id = ANY($1)', [userIds]);
        } else if (table === 'push_tokens') {
          await query('DELETE FROM push_tokens WHERE user_id = ANY($1)', [userIds]);
        } else {
          await query(`DELETE FROM ${table} WHERE couple_id = ANY($1)`, [coupleIds]);
        }
        console.log(`   ✓ ${table}`);
      } catch (e: any) {
        if (e.code !== '42P01') {
          console.log(`   ⚠️  ${table}: ${e.message.split('\n')[0]}`);
        }
      }
    }
  }

  // Delete auth users
  console.log('\n🔐 Deleting auth users...');
  for (const user of usersResult.rows) {
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

    if (!data.user?.id) {
      throw new Error(`Failed to get user ID for ${name}`);
    }

    actualUserIds[name] = data.user.id;
    console.log(`   ✓ ${user.username} (${user.email}) -> ${data.user.id}`);
  }
}

// ============================================================================
// DATA CREATION
// ============================================================================

async function createAppStoreCouple(client: any): Promise<void> {
  console.log('\n📊 Creating App Store couple: Johnny & Julia...\n');

  const johnnyId = actualUserIds.johnny;
  const juliaId = actualUserIds.julia;
  const coupleId = COUPLE_ID;

  // Create couple with 2,800 LP (3 magnets, 78% to 4th)
  // Magnet thresholds: 600, 1300, 2100, 3000, 4000
  // Also give them a 1-year premium subscription
  const oneYearFromNow = new Date();
  oneYearFromNow.setFullYear(oneYearFromNow.getFullYear() + 1);

  await client.query(
    `INSERT INTO couples (id, user1_id, user2_id, brand_id, total_lp,
       subscription_status, subscription_user_id, subscription_started_at,
       subscription_expires_at, subscription_product_id,
       created_at, updated_at)
     VALUES ($1, $2, $3, 'togetherremind', 2800,
       'active', $2, $4, $5, 'us2_yearly_premium',
       $4, NOW())`,
    [coupleId, johnnyId, juliaId, daysAgo(7), oneYearFromNow]
  );
  console.log('   ✓ couples (2,800 LP, 1-year premium subscription)');

  // Unlock all games
  await client.query(
    `INSERT INTO couple_unlocks (
      couple_id, welcome_quiz_completed, classic_quiz_unlocked, affirmation_quiz_unlocked,
      you_or_me_unlocked, linked_unlocked, word_search_unlocked, steps_unlocked,
      onboarding_completed, lp_intro_shown, classic_quiz_completed, affirmation_quiz_completed,
      created_at, updated_at
    ) VALUES ($1, true, true, true, true, true, true, true, true, true, true, true, $2, NOW())`,
    [coupleId, daysAgo(7)]
  );
  console.log('   ✓ couple_unlocks (all games unlocked)');

  // -------------------------------------------------------------------------
  // QUIZZES - 14 quizzes over 7 days (2 per day)
  // -------------------------------------------------------------------------
  const quizzes = [
    // Day 7 (oldest)
    { quizId: 'quiz_001', type: 'classic', branch: 'connection', day: 7, p1: [0, 1, 2, 0, 1], p2: [0, 1, 2, 1, 1], match: 80 },
    { quizId: 'affirmation_001', type: 'affirmation', branch: 'connection', day: 7, p1: [4, 4, 5, 4, 4], p2: [4, 5, 5, 4, 4], match: 80 },
    // Day 6
    { quizId: 'quiz_002', type: 'classic', branch: 'attachment', day: 6, p1: [1, 0, 1, 2, 0], p2: [1, 0, 1, 2, 0], match: 100 },
    { quizId: 'affirmation_002', type: 'affirmation', branch: 'attachment', day: 6, p1: [5, 4, 4, 5, 4], p2: [5, 4, 4, 5, 5], match: 80 },
    // Day 5
    { quizId: 'quiz_003', type: 'classic', branch: 'growth', day: 5, p1: [2, 1, 0, 1, 2], p2: [2, 1, 0, 1, 2], match: 100 },
    { quizId: 'affirmation_003', type: 'affirmation', branch: 'growth', day: 5, p1: [4, 5, 5, 4, 5], p2: [4, 5, 5, 3, 5], match: 80 },
    // Day 4
    { quizId: 'quiz_004', type: 'classic', branch: 'connection', day: 4, p1: [0, 2, 1, 0, 1], p2: [0, 2, 1, 0, 2], match: 80 },
    { quizId: 'affirmation_004', type: 'affirmation', branch: 'connection', day: 4, p1: [5, 5, 4, 4, 5], p2: [5, 5, 4, 4, 5], match: 100 },
    // Day 3
    { quizId: 'quiz_005', type: 'classic', branch: 'attachment', day: 3, p1: [1, 1, 2, 0, 1], p2: [1, 1, 2, 0, 0], match: 80 },
    { quizId: 'affirmation_005', type: 'affirmation', branch: 'attachment', day: 3, p1: [4, 4, 5, 5, 4], p2: [4, 4, 5, 5, 4], match: 100 },
    // Day 2
    { quizId: 'quiz_006', type: 'classic', branch: 'growth', day: 2, p1: [2, 0, 1, 1, 2], p2: [2, 0, 1, 2, 2], match: 80 },
    { quizId: 'affirmation_006', type: 'affirmation', branch: 'growth', day: 2, p1: [5, 4, 5, 4, 5], p2: [5, 4, 5, 4, 5], match: 100 },
    // Day 1 (yesterday)
    { quizId: 'quiz_007', type: 'classic', branch: 'connection', day: 1, p1: [0, 1, 0, 2, 1], p2: [0, 1, 0, 2, 1], match: 100 },
    { quizId: 'affirmation_007', type: 'affirmation', branch: 'connection', day: 1, p1: [4, 5, 4, 5, 4], p2: [4, 5, 4, 5, 5], match: 80 },
  ];

  for (const q of quizzes) {
    await client.query(
      `INSERT INTO quiz_matches (
        id, couple_id, quiz_id, quiz_type, branch, status,
        player1_answers, player2_answers, player1_answer_count, player2_answer_count,
        match_percentage, player1_score, player2_score,
        player1_id, player2_id, date, created_at, completed_at
      ) VALUES (
        gen_random_uuid(), $1, $2, $3, $4, 'completed',
        $5, $6, 5, 5, $7, $8, $8, $9, $10, $11, $12, $12
      )`,
      [
        coupleId, q.quizId, q.type, q.branch,
        JSON.stringify(q.p1), JSON.stringify(q.p2),
        q.match, Math.round(q.match / 20),
        johnnyId, juliaId, daysAgoDateStr(q.day), daysAgo(q.day),
      ]
    );
  }
  console.log(`   ✓ quiz_matches (${quizzes.length} quizzes over 7 days)`);

  // -------------------------------------------------------------------------
  // YOU OR ME - 3 completed games
  // -------------------------------------------------------------------------
  const youOrMeGames = [
    { quizId: 'you_or_me_001', branch: 'playful', day: 6, p1: [0, 1, 0, 1, 0], p2: [0, 1, 0, 1, 0], match: 100 },
    { quizId: 'you_or_me_002', branch: 'connection', day: 4, p1: [1, 0, 1, 0, 1], p2: [1, 0, 1, 1, 1], match: 80 },
    { quizId: 'you_or_me_003', branch: 'playful', day: 2, p1: [0, 0, 1, 1, 0], p2: [0, 0, 1, 1, 0], match: 100 },
  ];

  for (const g of youOrMeGames) {
    await client.query(
      `INSERT INTO quiz_matches (
        id, couple_id, quiz_id, quiz_type, branch, status,
        player1_answers, player2_answers, player1_answer_count, player2_answer_count,
        match_percentage, player1_score, player2_score,
        player1_id, player2_id, date, created_at, completed_at
      ) VALUES (
        gen_random_uuid(), $1, $2, 'you_or_me', $3, 'completed',
        $4, $5, 5, 5, $6, $7, $7, $8, $9, $10, $11, $11
      )`,
      [
        coupleId, g.quizId, g.branch,
        JSON.stringify(g.p1), JSON.stringify(g.p2),
        g.match, Math.round(g.match / 20),
        johnnyId, juliaId, daysAgoDateStr(g.day), daysAgo(g.day),
      ]
    );
  }
  console.log(`   ✓ quiz_matches (${youOrMeGames.length} You or Me games)`);

  // -------------------------------------------------------------------------
  // LINKED MATCHES - 4 completed games
  // -------------------------------------------------------------------------
  const linkedMatches = [
    { puzzleId: 'linked_casual_001', branch: 'casual', day: 6 },
    { puzzleId: 'linked_romantic_001', branch: 'romantic', day: 4 },
    { puzzleId: 'linked_casual_002', branch: 'casual', day: 3 },
    { puzzleId: 'linked_romantic_002', branch: 'romantic', day: 1 },
  ];

  for (const match of linkedMatches) {
    await client.query(
      `INSERT INTO linked_matches (
        couple_id, puzzle_id, branch, status, board_state, current_rack,
        current_turn_user_id, turn_number, player1_score, player2_score,
        player1_vision, player2_vision, locked_cell_count, total_answer_cells,
        player1_id, player2_id, created_at, completed_at
      ) VALUES (
        $1, $2, $3, 'completed', '{}'::jsonb, ARRAY[]::text[],
        $4, 10, 5, 5, 5, 5, 10, 10,
        $5, $6, $7, $7
      )`,
      [coupleId, match.puzzleId, match.branch, johnnyId, johnnyId, juliaId, daysAgo(match.day)]
    );
  }
  console.log(`   ✓ linked_matches (${linkedMatches.length} completed games)`);

  // -------------------------------------------------------------------------
  // WORD SEARCH MATCHES - 4 completed games
  // -------------------------------------------------------------------------
  const wordSearchMatches = [
    { puzzleId: 'ws_everyday_001', branch: 'everyday', day: 5 },
    { puzzleId: 'ws_passionate_001', branch: 'passionate', day: 4 },
    { puzzleId: 'ws_everyday_002', branch: 'everyday', day: 2 },
    { puzzleId: 'ws_passionate_002', branch: 'passionate', day: 1 },
  ];

  for (const match of wordSearchMatches) {
    await client.query(
      `INSERT INTO word_search_matches (
        couple_id, puzzle_id, branch, status, found_words,
        current_turn_user_id, turn_number, words_found_this_turn,
        player1_words_found, player2_words_found,
        player1_hints, player2_hints,
        player1_id, player2_id, created_at, completed_at
      ) VALUES (
        $1, $2, $3, 'completed', '["LOVE", "HEART", "KISS", "HUG"]',
        $4, 8, 0, 4, 4, 1, 1, $5, $6, $7, $7
      )`,
      [coupleId, match.puzzleId, match.branch, johnnyId, johnnyId, juliaId, daysAgo(match.day)]
    );
  }
  console.log(`   ✓ word_search_matches (${wordSearchMatches.length} completed games)`);

  // -------------------------------------------------------------------------
  // STEPS TOGETHER - 7 days of step data
  // -------------------------------------------------------------------------
  for (let day = 7; day >= 1; day--) {
    const johnnySteps = 5000 + Math.floor(Math.random() * 7000); // 5000-12000 steps
    const juliaSteps = 5000 + Math.floor(Math.random() * 7000);
    const dayDate = daysAgo(day);
    const dateStr = dayDate.toISOString().split('T')[0];

    // Insert Johnny's steps
    await client.query(
      `INSERT INTO steps_daily (couple_id, user_id, date_key, steps, last_sync_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $5)`,
      [coupleId, johnnyId, dateStr, johnnySteps, dayDate]
    );

    // Insert Julia's steps
    await client.query(
      `INSERT INTO steps_daily (couple_id, user_id, date_key, steps, last_sync_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $5)`,
      [coupleId, juliaId, dateStr, juliaSteps, dayDate]
    );

    // Create a reward for completed goals (both reached 5000+)
    await client.query(
      `INSERT INTO steps_rewards (couple_id, date_key, combined_steps, lp_earned, claimed_by)
       VALUES ($1, $2, $3, 15, $4)`,
      [coupleId, dateStr, johnnySteps + juliaSteps, johnnyId]
    );
  }
  console.log('   ✓ steps_daily (7 days of step data for both users)');
  console.log('   ✓ steps_rewards (7 daily goal rewards)');

  // -------------------------------------------------------------------------
  // US PROFILE CACHE - Full profile with discoveries
  // -------------------------------------------------------------------------
  const profileCache = {
    user1Insights: {
      dimensions: [
        { dimensionId: 'stress_processing', position: 0.3 },
        { dimensionId: 'social_energy', position: 0.4 },
        { dimensionId: 'planning_style', position: 0.2 },
        { dimensionId: 'conflict_approach', position: 0.1 },
      ],
      loveLanguages: [
        { language: 'quality_time', count: 8 },
        { language: 'words_of_affirmation', count: 6 },
        { language: 'physical_touch', count: 5 },
      ],
      partnerPerceptionTraits: [
        { trait: 'More romantic', perceivedBy: 'user2', questionText: 'Who is more romantic?' },
        { trait: 'Better cook', perceivedBy: 'user2', questionText: 'Who is a better cook?' },
        { trait: 'More spontaneous', perceivedBy: 'user2', questionText: 'Who is more spontaneous?' },
      ],
    },
    user2Insights: {
      dimensions: [
        { dimensionId: 'stress_processing', position: 0.2 },
        { dimensionId: 'social_energy', position: 0.5 },
        { dimensionId: 'planning_style', position: 0.3 },
        { dimensionId: 'conflict_approach', position: 0.2 },
      ],
      loveLanguages: [
        { language: 'quality_time', count: 7 },
        { language: 'acts_of_service', count: 6 },
        { language: 'physical_touch', count: 5 },
      ],
      partnerPerceptionTraits: [
        { trait: 'More organized', perceivedBy: 'user1', questionText: 'Who is more organized?' },
        { trait: 'Better listener', perceivedBy: 'user1', questionText: 'Who is a better listener?' },
        { trait: 'More patient', perceivedBy: 'user1', questionText: 'Who is more patient?' },
      ],
    },
    coupleInsights: {
      discoveries: [
        {
          quizId: 'quiz_001', questionId: 'q1', category: 'lifestyle',
          questionText: 'How do you prefer to spend a lazy Sunday?',
          user1Answer: 'Exploring somewhere new',
          user2Answer: 'Relaxing at home together',
        },
        {
          quizId: 'quiz_002', questionId: 'q3', category: 'communication',
          questionText: 'When something bothers you, you...',
          user1Answer: 'Bring it up right away',
          user2Answer: 'Process it first, then discuss',
        },
        {
          quizId: 'quiz_003', questionId: 'q2', category: 'social',
          questionText: 'Ideal weekend with friends?',
          user1Answer: 'Dinner party at home',
          user2Answer: 'Going out to a restaurant',
        },
        {
          quizId: 'quiz_004', questionId: 'q4', category: 'leisure',
          questionText: 'Favorite way to unwind?',
          user1Answer: 'Watching movies together',
          user2Answer: 'Reading or quiet time',
        },
        {
          quizId: 'quiz_005', questionId: 'q5', category: 'travel',
          questionText: 'Vacation planning style?',
          user1Answer: 'Spontaneous adventures',
          user2Answer: 'Well-planned itinerary',
        },
      ],
      totalDiscoveries: 5,
      valueAlignments: [
        { valueId: 'quality_time', count: 9 },
        { valueId: 'honesty_trust', count: 8 },
        { valueId: 'adventure_growth', count: 6 },
        { valueId: 'family_traditions', count: 5 },
      ],
      actionStats: {
        insightsActedOn: 3,
        conversationsHad: 5,
      },
    },
    totalQuizzesCompleted: 14,
  };

  await client.query(
    `INSERT INTO us_profile_cache (couple_id, user1_insights, user2_insights, couple_insights, total_quizzes_completed, created_at, updated_at)
     VALUES ($1, $2, $3, $4, $5, $6, NOW())`,
    [
      coupleId,
      JSON.stringify(profileCache.user1Insights),
      JSON.stringify(profileCache.user2Insights),
      JSON.stringify(profileCache.coupleInsights),
      profileCache.totalQuizzesCompleted,
      daysAgo(7),
    ]
  );
  console.log('   ✓ us_profile_cache (5 discoveries, full profile)');

  // -------------------------------------------------------------------------
  // CONVERSATION STARTERS
  // -------------------------------------------------------------------------
  const starters = [
    {
      triggerType: 'value',
      data: {
        triggerData: { valueId: 'quality_time', count: 9 },
        promptText: 'Quality time is your top shared value. What does your ideal quality time together look like?',
        contextText: 'Based on your shared value alignment',
      },
    },
    {
      triggerType: 'discovery',
      data: {
        triggerData: { category: 'lifestyle', questionText: 'How do you prefer to spend a lazy Sunday?' },
        promptText: 'You have different Sunday preferences - Johnny likes exploring while Julia prefers home time. How can you balance both?',
        contextText: 'From your recent discovery',
      },
    },
  ];

  for (const starter of starters) {
    await client.query(
      `INSERT INTO conversation_starters (couple_id, trigger_type, data, dismissed, discussed, created_at)
       VALUES ($1, $2, $3, false, false, $4)`,
      [coupleId, starter.triggerType, JSON.stringify(starter.data), daysAgo(3)]
    );
  }
  console.log(`   ✓ conversation_starters (${starters.length} starters)`);
}

// ============================================================================
// MAIN
// ============================================================================

async function main() {
  console.log('\n' + '='.repeat(70));
  console.log('   APP STORE SCREENSHOT COUPLE SETUP');
  console.log('   Johnny & Julia - 7 Days Active');
  console.log('='.repeat(70));

  await deleteTestUsers();
  await createTestUsers();

  const client = await getClient();
  try {
    await client.query('BEGIN');
    await createAppStoreCouple(client);
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }

  // Final summary
  console.log('\n' + '='.repeat(70));
  console.log('   SETUP COMPLETE');
  console.log('='.repeat(70));

  console.log('\n   Johnny & Julia - App Store Screenshot Couple');
  console.log('   ─────────────────────────────────────────────');
  console.log(`   Johnny: ${TEST_USERS.johnny.email}`);
  console.log(`   Julia:  ${TEST_USERS.julia.email}`);
  console.log(`   Password: ${getDevPassword(TEST_USERS.johnny.email)}`);
  console.log('');
  console.log('   Stats:');
  console.log('   • Premium subscription (1 year)');
  console.log('   • 2,800 LP (3 magnets unlocked, 78% to 4th)');
  console.log('   • 14 quizzes completed (7 classic, 7 affirmation)');
  console.log('   • 3 You or Me games');
  console.log('   • 4 Linked puzzles');
  console.log('   • 4 Word Search games');
  console.log('   • 7 days of steps data');
  console.log('   • All games unlocked');
  console.log('');
  console.log('   Taking Screenshots:');
  console.log('   1. Clear app data on device');
  console.log('   2. flutter run -d <device-id> --dart-define=BRAND=us2 --release');
  console.log('   3. Log in as Johnny or Julia');
  console.log('   4. Navigate to screens and capture');
  console.log('');
  console.log('   Tip: Use skipOtpVerificationInDev=true in dev_config.dart');
  console.log('');

  process.exit(0);
}

main().catch((error) => {
  console.error('\nFatal error:', error);
  process.exit(1);
});

/**
 * Reset ALL progress for a specific couple
 *
 * This wipes:
 * - Daily quests & completions
 * - Quiz progression & branch progression
 * - All game matches (Quiz, You-or-Me, Linked, Word Search, Memory)
 * - Love Points (resets to 0)
 * - Steps data & rewards
 * - Leaderboard entries
 *
 * Usage:
 *   npx tsx scripts/reset_couple_progress.ts [coupleId]
 *
 * If no coupleId provided, uses the dev test couple: 11111111-1111-1111-1111-111111111111
 */

import { query, getClient } from '../lib/db/pool';

// Dev test couple ID (TestiY + Jokke)
const DEV_COUPLE_ID = '11111111-1111-1111-1111-111111111111';

async function resetCoupleProgress(coupleId: string) {
  const client = await getClient();

  try {
    console.log(`\n🧹 Resetting ALL progress for couple: ${coupleId}\n`);
    console.log('=' .repeat(60));

    await client.query('BEGIN');

    // 1. Daily Quests & Completions
    console.log('\n📋 Daily Quests & Completions:');
    const completions = await client.query(
      `DELETE FROM quest_completions
       WHERE quest_id IN (SELECT id FROM daily_quests WHERE couple_id = $1)
       RETURNING quest_id`,
      [coupleId]
    );
    console.log(`   ✓ Deleted ${completions.rowCount} quest completions`);

    const quests = await client.query(
      'DELETE FROM daily_quests WHERE couple_id = $1 RETURNING id',
      [coupleId]
    );
    console.log(`   ✓ Deleted ${quests.rowCount} daily quests`);

    // 2. Quiz Progression
    console.log('\n📊 Quiz Progression:');
    const quizProg = await client.query(
      'DELETE FROM quiz_progression WHERE couple_id = $1 RETURNING couple_id',
      [coupleId]
    );
    console.log(`   ✓ Deleted ${quizProg.rowCount} quiz progression records`);

    // 3. Branch Progression (all activities)
    const branchProg = await client.query(
      'DELETE FROM branch_progression WHERE couple_id = $1 RETURNING id',
      [coupleId]
    );
    console.log(`   ✓ Deleted ${branchProg.rowCount} branch progression records`);

    // 4. Quiz Matches (classic, affirmation, you_or_me)
    console.log('\n🎯 Quiz Matches:');
    const quizMatches = await client.query(
      'DELETE FROM quiz_matches WHERE couple_id = $1 RETURNING id',
      [coupleId]
    );
    console.log(`   ✓ Deleted ${quizMatches.rowCount} quiz matches`);

    // 5. You-or-Me Progression
    const yomProg = await client.query(
      'DELETE FROM you_or_me_progression WHERE couple_id = $1 RETURNING couple_id',
      [coupleId]
    );
    console.log(`   ✓ Deleted ${yomProg.rowCount} you-or-me progression records`);

    // 6. Linked Matches & Moves
    console.log('\n🔗 Linked Game:');
    const linkedMoves = await client.query(
      `DELETE FROM linked_moves
       WHERE match_id IN (SELECT id FROM linked_matches WHERE couple_id = $1)
       RETURNING id`,
      [coupleId]
    );
    console.log(`   ✓ Deleted ${linkedMoves.rowCount} linked moves`);

    const linkedMatches = await client.query(
      'DELETE FROM linked_matches WHERE couple_id = $1 RETURNING id',
      [coupleId]
    );
    console.log(`   ✓ Deleted ${linkedMatches.rowCount} linked matches`);

    // 7. Word Search Matches & Moves
    console.log('\n🔍 Word Search:');
    const wsMoves = await client.query(
      `DELETE FROM word_search_moves
       WHERE match_id IN (SELECT id FROM word_search_matches WHERE couple_id = $1)
       RETURNING id`,
      [coupleId]
    );
    console.log(`   ✓ Deleted ${wsMoves.rowCount} word search moves`);

    const wsMatches = await client.query(
      'DELETE FROM word_search_matches WHERE couple_id = $1 RETURNING id',
      [coupleId]
    );
    console.log(`   ✓ Deleted ${wsMatches.rowCount} word search matches`);

    // 8. Memory Puzzles & Moves
    console.log('\n🃏 Memory Flip:');
    const memMoves = await client.query(
      `DELETE FROM memory_moves
       WHERE puzzle_id IN (SELECT id FROM memory_puzzles WHERE couple_id = $1)
       RETURNING id`,
      [coupleId]
    );
    console.log(`   ✓ Deleted ${memMoves.rowCount} memory moves`);

    const memPuzzles = await client.query(
      'DELETE FROM memory_puzzles WHERE couple_id = $1 RETURNING id',
      [coupleId]
    );
    console.log(`   ✓ Deleted ${memPuzzles.rowCount} memory puzzles`);

    // 9. Steps Data (tables may not exist in all environments)
    console.log('\n👟 Steps Together:');
    // Get user IDs for this couple
    const coupleUsers = await client.query(
      'SELECT user1_id, user2_id FROM couples WHERE id = $1',
      [coupleId]
    );

    if (coupleUsers.rows.length > 0) {
      const { user1_id, user2_id } = coupleUsers.rows[0];

      // Use SAVEPOINT for optional tables
      await client.query('SAVEPOINT steps_daily_sp');
      try {
        const stepsDaily = await client.query(
          'DELETE FROM steps_daily WHERE user_id IN ($1, $2) RETURNING user_id',
          [user1_id, user2_id]
        );
        console.log(`   ✓ Deleted ${stepsDaily.rowCount} daily step records`);
        await client.query('RELEASE SAVEPOINT steps_daily_sp');
      } catch {
        await client.query('ROLLBACK TO SAVEPOINT steps_daily_sp');
        console.log(`   - steps_daily table not found (skipped)`);
      }

      await client.query('SAVEPOINT steps_rewards_sp');
      try {
        const stepsRewards = await client.query(
          'DELETE FROM steps_rewards WHERE couple_id = $1 RETURNING couple_id',
          [coupleId]
        );
        console.log(`   ✓ Deleted ${stepsRewards.rowCount} step rewards`);
        await client.query('RELEASE SAVEPOINT steps_rewards_sp');
      } catch {
        await client.query('ROLLBACK TO SAVEPOINT steps_rewards_sp');
        console.log(`   - steps_rewards table not found (skipped)`);
      }
    }

    // 10. Love Points
    console.log('\n💰 Love Points:');
    const lpAwards = await client.query(
      'DELETE FROM love_point_awards WHERE couple_id = $1 RETURNING id',
      [coupleId]
    );
    console.log(`   ✓ Deleted ${lpAwards.rowCount} LP award records`);

    // Reset couple's total_lp to 0
    const lpReset = await client.query(
      'UPDATE couples SET total_lp = 0 WHERE id = $1 RETURNING total_lp',
      [coupleId]
    );
    if (lpReset.rowCount > 0) {
      console.log(`   ✓ Reset couple total_lp to 0`);
    }

    // 11. Leaderboard
    console.log('\n🏆 Leaderboard:');
    const leaderboard = await client.query(
      'DELETE FROM couple_leaderboard WHERE couple_id = $1 RETURNING couple_id',
      [coupleId]
    );
    console.log(`   ✓ Deleted ${leaderboard.rowCount} leaderboard entries`);

    await client.query('COMMIT');

    console.log('\n' + '=' .repeat(60));
    console.log('✅ Supabase progress reset complete!\n');

    return true;
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Failed to reset progress:', error);
    throw error;
  } finally {
    client.release();
  }
}

// Verification function
async function verifyReset(coupleId: string) {
  console.log('\n🔍 Verifying reset...\n');

  const checks = [
    { name: 'daily_quests', query: 'SELECT COUNT(*) FROM daily_quests WHERE couple_id = $1' },
    { name: 'quiz_progression', query: 'SELECT COUNT(*) FROM quiz_progression WHERE couple_id = $1' },
    { name: 'branch_progression', query: 'SELECT COUNT(*) FROM branch_progression WHERE couple_id = $1' },
    { name: 'quiz_matches', query: 'SELECT COUNT(*) FROM quiz_matches WHERE couple_id = $1' },
    { name: 'linked_matches', query: 'SELECT COUNT(*) FROM linked_matches WHERE couple_id = $1' },
    { name: 'word_search_matches', query: 'SELECT COUNT(*) FROM word_search_matches WHERE couple_id = $1' },
    { name: 'memory_puzzles', query: 'SELECT COUNT(*) FROM memory_puzzles WHERE couple_id = $1' },
    { name: 'love_point_awards', query: 'SELECT COUNT(*) FROM love_point_awards WHERE couple_id = $1' },
    { name: 'couple_leaderboard', query: 'SELECT COUNT(*) FROM couple_leaderboard WHERE couple_id = $1' },
  ];

  let allClear = true;
  for (const check of checks) {
    try {
      const result = await query(check.query, [coupleId]);
      const count = parseInt(result.rows[0].count);
      const status = count === 0 ? '✓' : '✗';
      console.log(`   ${status} ${check.name}: ${count} rows`);
      if (count > 0) allClear = false;
    } catch (e) {
      console.log(`   ? ${check.name}: table may not exist`);
    }
  }

  // Check LP reset
  try {
    const lpResult = await query('SELECT total_lp FROM couples WHERE id = $1', [coupleId]);
    const lp = lpResult.rows[0]?.total_lp ?? 'N/A';
    const status = lp === 0 ? '✓' : '✗';
    console.log(`   ${status} couples.total_lp: ${lp}`);
    if (lp !== 0) allClear = false;
  } catch (e) {
    console.log(`   ? couples.total_lp: could not check`);
  }

  console.log('');
  if (allClear) {
    console.log('✅ All Supabase data cleared successfully!\n');
  } else {
    console.log('⚠️  Some data remains - check above for details\n');
  }
}

// Main
async function main() {
  const coupleId = process.argv[2] || DEV_COUPLE_ID;

  console.log('\n' + '='.repeat(60));
  console.log('   COUPLE PROGRESS RESET - SUPABASE');
  console.log('='.repeat(60));

  await resetCoupleProgress(coupleId);
  await verifyReset(coupleId);

  console.log('📝 Note: This only resets Supabase. You also need to:');
  console.log('   1. Uninstall Android app (clears Hive)');
  console.log('   2. Clear Chrome site data (clears web Hive)\n');

  process.exit(0);
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});

/**
 * Check if any quests exist in Supabase daily_quests table
 */

import { query } from '../lib/db/pool';

async function checkData() {
  try {
    console.log('🔍 Checking for quests in Supabase...\n');

    // Check total count
    const countResult = await query('SELECT COUNT(*) FROM daily_quests', []);
    const totalQuests = parseInt(countResult.rows[0].count);

    console.log(`📊 Total quests in database: ${totalQuests}`);

    if (totalQuests > 0) {
      // Show sample quests
      const sampleResult = await query(
        'SELECT id, couple_id, date, quest_type, content_id FROM daily_quests ORDER BY generated_at DESC LIMIT 5',
        []
      );

      console.log('\n📋 Sample quests:');
      sampleResult.rows.forEach((row, i) => {
        console.log(`\n${i + 1}. ID: ${row.id}`);
        console.log(`   Type: ${row.quest_type}`);
        console.log(`   Content ID: ${row.content_id}`);
        console.log(`   Date: ${row.date}`);
      });
    } else {
      console.log('\n❌ No quests found in database!');
      console.log('\n💡 This means quest sync from Flutter is failing.');
      console.log('   Check Flutter logs for "Supabase dual-write" errors.');
    }

    // Check quest completions
    const completionsResult = await query('SELECT COUNT(*) FROM quest_completions', []);
    const totalCompletions = parseInt(completionsResult.rows[0].count);
    console.log(`\n📊 Total quest completions: ${totalCompletions}`);

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

checkData();

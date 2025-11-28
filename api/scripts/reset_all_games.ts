/**
 * Reset ALL Game Data for Testing (Jokke & TestiY)
 *
 * Deletes all game matches from Supabase:
 * - Linked matches
 * - Word Search matches
 * - Memory Flip puzzles and moves
 *
 * Test users (from DevConfig):
 * - User 1 (Android): c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28 (TestiY)
 * - User 2 (Chrome):  d71425a3-a92f-404e-bfbe-a54c4cb58b6a (Jokke)
 *
 * Usage: cd api && npx tsx scripts/reset_all_games.ts
 */

import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: '.env.local' });

// Couple ID for Jokke & TestiY
const COUPLE_ID = '11111111-1111-1111-1111-111111111111';

async function resetAllGames() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !supabaseKey) {
    console.error('Missing Supabase credentials in .env.local');
    process.exit(1);
  }

  const supabase = createClient(supabaseUrl, supabaseKey);

  console.log(`🧹 Resetting all games for couple: ${COUPLE_ID}\n`);

  // 1. Reset Linked matches
  console.log('1️⃣  Linked matches...');
  const { data: linkedData, error: linkedError } = await supabase
    .from('linked_matches')
    .delete()
    .eq('couple_id', COUPLE_ID)
    .select();

  if (linkedError) {
    console.error('   ❌ Error:', linkedError.message);
  } else if (linkedData && linkedData.length > 0) {
    console.log(`   ✅ Deleted ${linkedData.length} match(es)`);
  } else {
    console.log('   ℹ️  No matches found');
  }

  // 2. Reset Word Search matches
  console.log('2️⃣  Word Search matches...');
  const { data: wsData, error: wsError } = await supabase
    .from('word_search_matches')
    .delete()
    .eq('couple_id', COUPLE_ID)
    .select();

  if (wsError) {
    console.error('   ❌ Error:', wsError.message);
  } else if (wsData && wsData.length > 0) {
    console.log(`   ✅ Deleted ${wsData.length} match(es)`);
  } else {
    console.log('   ℹ️  No matches found');
  }

  // 3. Reset Quiz Sessions
  console.log('3️⃣  Quiz Sessions...');
  const { data: quizData, error: quizError } = await supabase
    .from('quiz_sessions')
    .delete()
    .eq('couple_id', COUPLE_ID)
    .select();

  if (quizError) {
    console.error('   ❌ Error:', quizError.message);
  } else if (quizData && quizData.length > 0) {
    console.log(`   ✅ Deleted ${quizData.length} session(s)`);
  } else {
    console.log('   ℹ️  No sessions found');
  }

  // 4. Reset You or Me Sessions
  console.log('4️⃣  You or Me Sessions...');
  const { data: yomData, error: yomError } = await supabase
    .from('you_or_me_sessions')
    .delete()
    .eq('couple_id', COUPLE_ID)
    .select();

  if (yomError) {
    console.error('   ❌ Error:', yomError.message);
  } else if (yomData && yomData.length > 0) {
    console.log(`   ✅ Deleted ${yomData.length} session(s)`);
  } else {
    console.log('   ℹ️  No sessions found');
  }

  // 5. Reset Daily Quests
  console.log('5️⃣  Daily Quests...');
  const { data: questData, error: questError } = await supabase
    .from('daily_quests')
    .delete()
    .eq('couple_id', COUPLE_ID)
    .select();

  if (questError) {
    console.error('   ❌ Error:', questError.message);
  } else if (questData && questData.length > 0) {
    console.log(`   ✅ Deleted ${questData.length} quest(s)`);
  } else {
    console.log('   ℹ️  No quests found');
  }

  console.log('\n✨ All games reset! Ready for fresh testing.');
  console.log('\nNext steps:');
  console.log('1. Hard refresh Chrome (Cmd+Shift+R) or restart the app');
  console.log('2. Enter Side Quests to start fresh games');
}

resetAllGames();

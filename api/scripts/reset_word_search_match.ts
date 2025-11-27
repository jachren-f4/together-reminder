/**
 * Reset Word Search Match for Testing
 *
 * Deletes the word search match from Supabase so a fresh one is created
 * with the current puzzle.
 *
 * Usage: cd api && npx tsx scripts/reset_word_search_match.ts
 */

import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: '.env.local' });

const COUPLE_ID = '11111111-1111-1111-1111-111111111111';

async function resetWordSearchMatch() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !supabaseKey) {
    console.error('Missing Supabase credentials in .env.local');
    process.exit(1);
  }

  const supabase = createClient(supabaseUrl, supabaseKey);

  console.log(`Deleting word search match for couple: ${COUPLE_ID}`);

  const { data, error } = await supabase
    .from('word_search_matches')
    .delete()
    .eq('couple_id', COUPLE_ID)
    .select();

  if (error) {
    console.error('Error deleting match:', error.message);
    process.exit(1);
  }

  if (data && data.length > 0) {
    console.log(`✅ Deleted ${data.length} match(es)`);
  } else {
    console.log('ℹ️  No existing match found (already clean)');
  }

  console.log('\nNext steps:');
  console.log('1. Hard refresh Chrome (Cmd+Shift+R) or restart the app');
  console.log('2. Enter Side Quests → Word Search to start a fresh game');
}

resetWordSearchMatch();

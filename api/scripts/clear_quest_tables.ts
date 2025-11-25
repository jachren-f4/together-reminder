/**
 * Clear quest and game-related tables for clean testing
 *
 * Truncates quest_completions, daily_quests, and memory_puzzles tables
 * to ensure fresh state for dual-write testing
 *
 * NOTE: Requires Supabase to be running locally (supabase start)
 */

import { query } from '../lib/db/pool';

// Set default DATABASE_URL for local Supabase if not already set
if (!process.env.DATABASE_URL && !process.env.DATABASE_POOL_URL) {
  process.env.DATABASE_URL = 'postgresql://postgres:postgres@localhost:54322/postgres';
}

async function clearTables() {
  try {
    console.log('🧹 Clearing quest and game tables...');

    // Clear completions first (has foreign key to daily_quests)
    await query('TRUNCATE TABLE quest_completions CASCADE;', []);
    console.log('✅ Cleared quest_completions');

    // Clear quests
    await query('TRUNCATE TABLE daily_quests CASCADE;', []);
    console.log('✅ Cleared daily_quests');

    // Clear Memory Flip puzzles
    await query('TRUNCATE TABLE memory_puzzles CASCADE;', []);
    console.log('✅ Cleared memory_puzzles');

    console.log('');
    console.log('✅ All tables cleared successfully!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Failed to clear tables:', error);
    process.exit(1);
  }
}

clearTables();

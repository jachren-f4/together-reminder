/**
 * Apply Migration 010: First Player Preference
 *
 * Adds global "who goes first" preference for turn-based games:
 * - Adds first_player_id column to couples table
 * - Adds index for efficient lookups
 * - Adds constraint to ensure first_player_id is a couple member
 */

import { config } from 'dotenv';
import { readFileSync } from 'fs';
import { join } from 'path';
import { query } from '../lib/db/pool';

// Load environment variables from .env.local
config({ path: join(__dirname, '../.env.local') });

async function applyMigration() {
  try {
    console.log('📦 Reading migration file...');
    const migrationPath = join(__dirname, '../supabase/migrations/010_first_player_preference.sql');
    const sql = readFileSync(migrationPath, 'utf-8');

    console.log('🚀 Applying migration 010...');
    await query(sql, []);

    console.log('✅ Migration 010 applied successfully!');
    console.log('');
    console.log('Changes applied:');
    console.log('  📋 couples table:');
    console.log('    - Added first_player_id column (nullable)');
    console.log('    - NULL defaults to user2_id (latest joiner) at runtime');
    console.log('');
    console.log('  🔍 Index:');
    console.log('    - idx_couples_first_player for efficient lookups');
    console.log('');
    console.log('  ✅ Constraint:');
    console.log('    - valid_first_player ensures first_player_id is user1_id or user2_id');
    console.log('');
    console.log('Next steps:');
    console.log('  - Preference syncs automatically via Firebase RTDB');
    console.log('  - Partners can change preference in Settings → Game Preferences');
    console.log('  - Future turn-based features should use CouplePreferencesService.getFirstPlayerId()');

    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

applyMigration();

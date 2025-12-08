/**
 * Apply Migration 008: Fix session ID types
 *
 * Changes you_or_me_sessions and memory_puzzles ID columns from UUID to TEXT
 * to match Flutter's ID generation format
 */

import { readFileSync } from 'fs';
import { join } from 'path';
import { query } from '../lib/db/pool';

async function applyMigration() {
  try {
    console.log('📦 Reading migration file...');
    const migrationPath = join(__dirname, '../supabase/migrations/008_fix_session_id_types.sql');
    const sql = readFileSync(migrationPath, 'utf-8');

    console.log('🚀 Applying migration 008...');
    await query(sql, []);

    console.log('✅ Migration 008 applied successfully!');
    console.log('');
    console.log('Fixed ID types:');
    console.log('  - you_or_me_sessions.id: UUID → TEXT');
    console.log('  - memory_puzzles.id: UUID → TEXT');
    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

applyMigration();

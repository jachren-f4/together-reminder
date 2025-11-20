import { readFileSync } from 'fs';
import { join } from 'path';
import { query } from '../lib/db/pool';

async function applyMigration() {
  try {
    console.log('📦 Reading migration file...');
    const migrationPath = join(__dirname, '../supabase/migrations/006_fix_quest_id_types.sql');
    const sql = readFileSync(migrationPath, 'utf-8');

    console.log('🚀 Applying migration 006...');
    await query(sql, []);

    console.log('✅ Migration 006 applied successfully!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

applyMigration();

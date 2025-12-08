import { readFileSync } from 'fs';
import { join } from 'path';
import { query } from '../lib/db/pool';

async function applyMigration() {
  try {
    console.log('📦 Reading migration file...');
    const migrationPath = join(__dirname, '../supabase/migrations/007_add_reminders_pokes.sql');
    const sql = readFileSync(migrationPath, 'utf-8');

    console.log('🚀 Applying migration 007...');
    await query(sql, []);

    console.log('✅ Migration 007 applied successfully!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

applyMigration();

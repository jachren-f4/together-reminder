/**
 * Apply Migration 011: Linked Game Tables
 *
 * Creates tables for the Linked (arroword puzzle) turn-based game:
 * - linked_matches: Main game state
 * - linked_moves: Move history for auditing
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
    const migrationPath = join(__dirname, '../supabase/migrations/011_linked_game.sql');
    const sql = readFileSync(migrationPath, 'utf-8');

    console.log('🚀 Applying migration 011...');
    await query(sql, []);

    console.log('✅ Migration 011 applied successfully!');
    console.log('');
    console.log('Tables created:');
    console.log('  📋 linked_matches:');
    console.log('    - Stores active/completed puzzle matches');
    console.log('    - Tracks scores, board state, turns');
    console.log('');
    console.log('  📝 linked_moves:');
    console.log('    - Move history for debugging');
    console.log('    - Records each letter placement');
    console.log('');
    console.log('Indexes created:');
    console.log('  - idx_linked_matches_couple_puzzle');
    console.log('  - idx_linked_matches_status');
    console.log('  - idx_linked_moves_match');

    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

applyMigration();

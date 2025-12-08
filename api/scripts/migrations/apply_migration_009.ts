/**
 * Apply Migration 009: Memory Flip Turn-Based System
 *
 * Converts Memory Flip from real-time to turn-based gameplay:
 * - Adds turn state columns to memory_puzzles
 * - Creates memory_moves audit table
 * - Implements RLS policies for turn-based access control
 * - Adds helper functions for turn management
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
    const migrationPath = join(__dirname, '../supabase/migrations/009_memory_flip_turn_based.sql');
    const sql = readFileSync(migrationPath, 'utf-8');

    console.log('🚀 Applying migration 009...');
    await query(sql, []);

    console.log('✅ Migration 009 applied successfully!');
    console.log('');
    console.log('Changes applied:');
    console.log('  📋 memory_puzzles table:');
    console.log('    - Added turn state tracking (current_player_id, turn_number, turn_expires_at)');
    console.log('    - Added scoring (player1_pairs, player2_pairs)');
    console.log('    - Added flip allowances (6 flips per 5 hours per player)');
    console.log('    - Added game phase tracking');
    console.log('');
    console.log('  📝 memory_moves table:');
    console.log('    - Created audit table for all moves');
    console.log('    - Tracks card selections, matches, and turn numbers');
    console.log('');
    console.log('  🔐 RLS Policies:');
    console.log('    - View: Both players can see puzzles');
    console.log('    - Update: Only current player during their turn');
    console.log('    - Insert: Either player can create puzzles');
    console.log('    - Moves: Only current player can insert, both can view');
    console.log('');
    console.log('  🔧 Helper Functions:');
    console.log('    - advance_memory_flip_turn(): Advances turn to next player');
    console.log('    - check_and_recharge_flips(): Handles 5-hour flip recharge');

    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

applyMigration();
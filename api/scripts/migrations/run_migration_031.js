/**
 * Migration 031: Create daily_lp_grants table
 *
 * This table tracks LP grants per couple per content type per day,
 * enabling the "unlimited play, daily LP cap" system.
 *
 * Run with: node scripts/migrations/run_migration_031.js
 */

require('dotenv').config({ path: '.env.local' });
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

async function runMigration() {
  const client = await pool.connect();

  try {
    console.log('Starting migration 031: Create daily_lp_grants table...');

    await client.query('BEGIN');

    // Create the daily_lp_grants table
    await client.query(`
      CREATE TABLE IF NOT EXISTS daily_lp_grants (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
        content_type TEXT NOT NULL,
        lp_day DATE NOT NULL,
        lp_amount INT NOT NULL DEFAULT 30,
        match_id TEXT,
        granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        UNIQUE(couple_id, content_type, lp_day)
      );
    `);
    console.log('  - Created daily_lp_grants table');

    // Create index for efficient lookups by couple
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_daily_lp_grants_couple_day
      ON daily_lp_grants(couple_id, lp_day);
    `);
    console.log('  - Created index on (couple_id, lp_day)');

    // Create index for cleanup of old records
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_daily_lp_grants_lp_day
      ON daily_lp_grants(lp_day);
    `);
    console.log('  - Created index on lp_day for cleanup queries');

    await client.query('COMMIT');
    console.log('Migration 031 completed successfully!');

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Migration 031 failed:', error);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

runMigration().catch(console.error);

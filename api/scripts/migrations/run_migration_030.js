// Run migration 030 - Add classic_quiz_completed and affirmation_quiz_completed columns
// These track whether each quiz type has been completed (not just unlocked)
// You or Me only unlocks when BOTH are completed
const { Pool } = require('pg');
require('dotenv').config({ path: '.env.local' });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function runMigration() {
  const client = await pool.connect();
  try {
    console.log('Adding classic_quiz_completed column...');
    await client.query(`
      ALTER TABLE couple_unlocks
      ADD COLUMN IF NOT EXISTS classic_quiz_completed BOOLEAN DEFAULT FALSE;
    `);

    console.log('Adding affirmation_quiz_completed column...');
    await client.query(`
      ALTER TABLE couple_unlocks
      ADD COLUMN IF NOT EXISTS affirmation_quiz_completed BOOLEAN DEFAULT FALSE;
    `);

    console.log('Updating existing rows where you_or_me is already unlocked...');
    // For existing couples that already have you_or_me unlocked,
    // mark both quiz types as completed (to maintain consistency)
    await client.query(`
      UPDATE couple_unlocks
      SET classic_quiz_completed = true,
          affirmation_quiz_completed = true
      WHERE you_or_me_unlocked = true;
    `);

    console.log('✅ Migration 030 completed successfully!');
    console.log('   - Added classic_quiz_completed column');
    console.log('   - Added affirmation_quiz_completed column');
    console.log('   - Updated existing rows where you_or_me was already unlocked');
  } catch (err) {
    console.error('❌ Migration failed:', err);
  } finally {
    client.release();
    await pool.end();
  }
}

runMigration();

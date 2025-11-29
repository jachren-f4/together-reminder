/**
 * Run migration 023: Create quiz_matches table
 * Usage: node scripts/run_migration_023.js
 */

const { Pool } = require('pg');
const dotenv = require('dotenv');
const path = require('path');
const fs = require('fs');

dotenv.config({ path: path.join(__dirname, '../.env.local') });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

async function runMigration() {
  const client = await pool.connect();
  try {
    console.log('Running migration 023: Create quiz_matches table...');

    const migrationSQL = fs.readFileSync(
      path.join(__dirname, '../supabase/migrations/023_quiz_matches.sql'),
      'utf-8'
    );

    await client.query(migrationSQL);

    console.log('✅ Migration 023 successful!');

    // Verify the table was created
    const result = await client.query(`
      SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_name = 'quiz_matches'
      ORDER BY ordinal_position;
    `);

    console.log('\n📋 Table structure:');
    result.rows.forEach(row => {
      console.log(`  - ${row.column_name}: ${row.data_type}`);
    });

  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

runMigration();

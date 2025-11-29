// Run migration 024 - love_point_transactions table
const { Pool } = require('pg');
require('dotenv').config({ path: '.env.local' });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function runMigration() {
  const client = await pool.connect();
  try {
    console.log('Creating love_point_transactions table...');

    await client.query(`
      CREATE TABLE IF NOT EXISTS love_point_transactions (
        id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
        user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
        amount INT NOT NULL,
        source VARCHAR(50) NOT NULL,
        description TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
      );
    `);

    console.log('Creating indexes...');
    await client.query(`CREATE INDEX IF NOT EXISTS idx_lp_transactions_user_id ON love_point_transactions(user_id);`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_lp_transactions_created_at ON love_point_transactions(created_at DESC);`);

    console.log('Enabling RLS...');
    await client.query(`ALTER TABLE love_point_transactions ENABLE ROW LEVEL SECURITY;`);

    // Check if policy exists before creating
    const policyCheck = await client.query(`
      SELECT 1 FROM pg_policies
      WHERE tablename = 'love_point_transactions' AND policyname = 'lp_transactions_select'
    `);

    if (policyCheck.rows.length === 0) {
      console.log('Creating RLS policies...');
      await client.query(`
        CREATE POLICY lp_transactions_select ON love_point_transactions
          FOR SELECT USING (user_id = auth.uid());
      `);
      await client.query(`
        CREATE POLICY lp_transactions_insert ON love_point_transactions
          FOR INSERT WITH CHECK (true);
      `);
    } else {
      console.log('RLS policies already exist');
    }

    console.log('✅ Migration 024 completed successfully!');
  } catch (err) {
    console.error('❌ Migration failed:', err);
  } finally {
    client.release();
    await pool.end();
  }
}

runMigration();

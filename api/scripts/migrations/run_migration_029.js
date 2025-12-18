// Run migration 029 - couple_unlocks table for guided onboarding
const { Pool } = require('pg');
require('dotenv').config({ path: '.env.local' });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function runMigration() {
  const client = await pool.connect();
  try {
    console.log('Creating couple_unlocks table...');

    await client.query(`
      CREATE TABLE IF NOT EXISTS couple_unlocks (
        couple_id UUID REFERENCES couples(id) ON DELETE CASCADE PRIMARY KEY,

        -- Welcome Quiz state
        welcome_quiz_completed BOOLEAN DEFAULT FALSE,

        -- Feature unlocks (unlocked after completing previous feature)
        classic_quiz_unlocked BOOLEAN DEFAULT FALSE,
        affirmation_quiz_unlocked BOOLEAN DEFAULT FALSE,
        you_or_me_unlocked BOOLEAN DEFAULT FALSE,
        linked_unlocked BOOLEAN DEFAULT FALSE,
        word_search_unlocked BOOLEAN DEFAULT FALSE,
        steps_unlocked BOOLEAN DEFAULT FALSE,

        -- Track if onboarding is fully complete (all features unlocked)
        onboarding_completed BOOLEAN DEFAULT FALSE,

        -- LP intro shown flag (per-couple, shown when first landing on home)
        lp_intro_shown BOOLEAN DEFAULT FALSE,

        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);

    console.log('Creating index...');
    await client.query(`CREATE INDEX IF NOT EXISTS idx_couple_unlocks_couple_id ON couple_unlocks(couple_id);`);

    console.log('Creating trigger function...');
    await client.query(`
      CREATE OR REPLACE FUNCTION update_couple_unlocks_updated_at()
      RETURNS TRIGGER AS $$
      BEGIN
        NEW.updated_at = NOW();
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    `);

    console.log('Creating trigger...');
    await client.query(`DROP TRIGGER IF EXISTS trigger_couple_unlocks_updated_at ON couple_unlocks;`);
    await client.query(`
      CREATE TRIGGER trigger_couple_unlocks_updated_at
        BEFORE UPDATE ON couple_unlocks
        FOR EACH ROW
        EXECUTE FUNCTION update_couple_unlocks_updated_at();
    `);

    console.log('Creating welcome_quiz_answers table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS welcome_quiz_answers (
        id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
        couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,
        user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,

        -- Store answers as JSONB array: [{"questionId": "q1", "answer": "A"}, ...]
        answers JSONB NOT NULL DEFAULT '[]',

        completed_at TIMESTAMPTZ DEFAULT NOW(),

        -- Each user can only have one answer set per couple
        UNIQUE(couple_id, user_id)
      );
    `);

    console.log('Creating indexes for welcome_quiz_answers...');
    await client.query(`CREATE INDEX IF NOT EXISTS idx_welcome_quiz_answers_couple ON welcome_quiz_answers(couple_id);`);
    await client.query(`CREATE INDEX IF NOT EXISTS idx_welcome_quiz_answers_user ON welcome_quiz_answers(user_id);`);

    console.log('Creating helper functions...');
    await client.query(`
      CREATE OR REPLACE FUNCTION check_welcome_quiz_completion(p_couple_id UUID)
      RETURNS BOOLEAN AS $$
      DECLARE
        answer_count INTEGER;
      BEGIN
        SELECT COUNT(*) INTO answer_count
        FROM welcome_quiz_answers
        WHERE couple_id = p_couple_id;

        RETURN answer_count >= 2;
      END;
      $$ LANGUAGE plpgsql;
    `);

    console.log('Enabling RLS...');
    await client.query(`ALTER TABLE couple_unlocks ENABLE ROW LEVEL SECURITY;`);
    await client.query(`ALTER TABLE welcome_quiz_answers ENABLE ROW LEVEL SECURITY;`);

    // Check if policies exist before creating
    const policyCheck1 = await client.query(`
      SELECT 1 FROM pg_policies
      WHERE tablename = 'couple_unlocks' AND policyname = 'couple_unlocks_select'
    `);

    if (policyCheck1.rows.length === 0) {
      console.log('Creating RLS policies for couple_unlocks...');
      await client.query(`
        CREATE POLICY couple_unlocks_select ON couple_unlocks
          FOR SELECT
          USING (
            couple_id IN (
              SELECT c.id FROM couples c
              WHERE c.user1_id = auth.uid() OR c.user2_id = auth.uid()
            )
          );
      `);
      await client.query(`
        CREATE POLICY couple_unlocks_insert ON couple_unlocks
          FOR INSERT
          WITH CHECK (
            couple_id IN (
              SELECT c.id FROM couples c
              WHERE c.user1_id = auth.uid() OR c.user2_id = auth.uid()
            )
          );
      `);
      await client.query(`
        CREATE POLICY couple_unlocks_update ON couple_unlocks
          FOR UPDATE
          USING (
            couple_id IN (
              SELECT c.id FROM couples c
              WHERE c.user1_id = auth.uid() OR c.user2_id = auth.uid()
            )
          );
      `);
    } else {
      console.log('RLS policies for couple_unlocks already exist');
    }

    const policyCheck2 = await client.query(`
      SELECT 1 FROM pg_policies
      WHERE tablename = 'welcome_quiz_answers' AND policyname = 'welcome_quiz_answers_select'
    `);

    if (policyCheck2.rows.length === 0) {
      console.log('Creating RLS policies for welcome_quiz_answers...');
      await client.query(`
        CREATE POLICY welcome_quiz_answers_select ON welcome_quiz_answers
          FOR SELECT
          USING (
            couple_id IN (
              SELECT c.id FROM couples c
              WHERE c.user1_id = auth.uid() OR c.user2_id = auth.uid()
            )
          );
      `);
      await client.query(`
        CREATE POLICY welcome_quiz_answers_insert ON welcome_quiz_answers
          FOR INSERT WITH CHECK (user_id = auth.uid());
      `);
      await client.query(`
        CREATE POLICY welcome_quiz_answers_update ON welcome_quiz_answers
          FOR UPDATE USING (user_id = auth.uid());
      `);
    } else {
      console.log('RLS policies for welcome_quiz_answers already exist');
    }

    console.log('Granting permissions...');
    await client.query(`GRANT ALL ON couple_unlocks TO service_role;`);
    await client.query(`GRANT ALL ON welcome_quiz_answers TO service_role;`);
    await client.query(`GRANT EXECUTE ON FUNCTION check_welcome_quiz_completion TO service_role;`);

    console.log('✅ Migration 029 completed successfully!');
  } catch (err) {
    console.error('❌ Migration failed:', err);
  } finally {
    client.release();
    await pool.end();
  }
}

runMigration();

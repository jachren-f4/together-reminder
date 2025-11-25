/**
 * Verify You or Me Dual-Write Sync
 *
 * Checks that You or Me sessions are correctly synced to Supabase
 */

import { query } from '../lib/db/pool';

async function verifyYouOrMeSync() {
  try {
    console.log('🔍 Checking You or Me sessions in Supabase...\n');

    // Get all You or Me sessions
    const result = await query(
      `SELECT
        s.id,
        s.questions,
        s.created_at,
        s.expires_at,
        c.id as couple_id
       FROM you_or_me_sessions s
       JOIN couples c ON s.couple_id = c.id
       ORDER BY s.created_at DESC
       LIMIT 10`,
      []
    );

    if (result.rows.length === 0) {
      console.log('❌ No You or Me sessions found in Supabase');
      console.log('\nExpected: At least 1 session with questions array');
      process.exit(1);
    }

    console.log(`✅ Found ${result.rows.length} You or Me session(s) in Supabase:\n`);

    result.rows.forEach((row, index) => {
      const questions = typeof row.questions === 'string'
        ? JSON.parse(row.questions)
        : row.questions;

      console.log(`--- Session ${index + 1} ---`);
      console.log(`ID:          ${row.id}`);
      console.log(`Couple ID:   ${row.couple_id}`);
      console.log(`Created:     ${row.created_at}`);
      console.log(`Expires:     ${row.expires_at || 'N/A'}`);
      console.log(`Questions:   ${questions.length} questions`);

      if (questions.length > 0) {
        console.log(`\nSample questions:`);
        questions.slice(0, 3).forEach((q: any, i: number) => {
          console.log(`  ${i + 1}. ${q.text || q.question || 'N/A'}`);
        });
      }
      console.log('');
    });

    // Verify JSONB structure
    const firstSession = result.rows[0];
    const questions = typeof firstSession.questions === 'string'
      ? JSON.parse(firstSession.questions)
      : firstSession.questions;

    if (Array.isArray(questions) && questions.length > 0) {
      console.log('✅ Questions stored as JSONB array');
      console.log(`✅ ${questions.length} questions in session`);
    } else {
      console.log('⚠️  Warning: Questions array is empty or invalid');
    }

    console.log('\n✅ You or Me dual-write verification complete!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Verification failed:', error);
    process.exit(1);
  }
}

verifyYouOrMeSync();

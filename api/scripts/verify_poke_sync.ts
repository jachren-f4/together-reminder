/**
 * Verify Poke Dual-Write Sync
 *
 * Checks that pokes are correctly synced to Supabase reminders table
 */

import { query } from '../lib/db/pool';

async function verifyPokeSync() {
  try {
    console.log('🔍 Checking pokes in Supabase...\n');

    // Get all pokes (category='poke')
    const result = await query(
      `SELECT
        r.id,
        r.type,
        r.category,
        r.from_name,
        r.to_name,
        r.text,
        r.emoji,
        r.status,
        r.created_at,
        r.sent_at,
        c.id as couple_id
       FROM reminders r
       JOIN couples c ON r.couple_id = c.id
       WHERE r.category = 'poke'
       ORDER BY r.created_at DESC
       LIMIT 10`,
      []
    );

    if (result.rows.length === 0) {
      console.log('❌ No pokes found in Supabase');
      console.log('\nExpected: At least 2 rows (one "sent", one "received")');
      process.exit(1);
    }

    console.log(`✅ Found ${result.rows.length} poke(s) in Supabase:\n`);

    result.rows.forEach((row, index) => {
      console.log(`--- Poke ${index + 1} ---`);
      console.log(`ID:          ${row.id}`);
      console.log(`Type:        ${row.type}`);
      console.log(`Category:    ${row.category}`);
      console.log(`From:        ${row.from_name}`);
      console.log(`To:          ${row.to_name}`);
      console.log(`Text:        ${row.text}`);
      console.log(`Emoji:       ${row.emoji || 'N/A'}`);
      console.log(`Status:      ${row.status}`);
      console.log(`Couple ID:   ${row.couple_id}`);
      console.log(`Created:     ${row.created_at}`);
      console.log(`Sent:        ${row.sent_at || 'N/A'}`);
      console.log('');
    });

    // Verify we have both sent and received
    const types = new Set(result.rows.map(r => r.type));
    if (types.has('sent') && types.has('received')) {
      console.log('✅ Both "sent" and "received" pokes found');
    } else {
      console.log('⚠️  Warning: Expected both "sent" and "received" pokes');
      console.log(`   Found types: ${Array.from(types).join(', ')}`);
    }

    console.log('\n✅ Poke dual-write verification complete!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Verification failed:', error);
    process.exit(1);
  }
}

verifyPokeSync();

/**
 * Verify Memory Flip Dual-Write Sync
 *
 * Checks that Memory Flip puzzles are correctly synced to Supabase
 */

import { query } from '../lib/db/pool';

async function verifyMemoryFlipSync() {
  try {
    console.log('🔍 Checking Memory Flip puzzles in Supabase...\n');

    // Get all Memory Flip puzzles
    const result = await query(
      `SELECT
        p.id,
        p.date,
        p.total_pairs,
        p.matched_pairs,
        p.cards,
        p.status,
        p.completion_quote,
        p.created_at,
        p.completed_at,
        c.id as couple_id
       FROM memory_puzzles p
       JOIN couples c ON p.couple_id = c.id
       ORDER BY p.created_at DESC
       LIMIT 10`,
      []
    );

    if (result.rows.length === 0) {
      console.log('❌ No Memory Flip puzzles found in Supabase');
      console.log('\nExpected: At least 1 puzzle with cards array');
      process.exit(1);
    }

    console.log(`✅ Found ${result.rows.length} Memory Flip puzzle(s) in Supabase:\n`);

    result.rows.forEach((row, index) => {
      const cards = typeof row.cards === 'string'
        ? JSON.parse(row.cards)
        : row.cards;

      console.log(`--- Puzzle ${index + 1} ---`);
      console.log(`ID:              ${row.id}`);
      console.log(`Couple ID:       ${row.couple_id}`);
      console.log(`Date:            ${row.date}`);
      console.log(`Total Pairs:     ${row.total_pairs}`);
      console.log(`Matched Pairs:   ${row.matched_pairs}`);
      console.log(`Status:          ${row.status}`);
      console.log(`Completion Quote: ${row.completion_quote || 'N/A'}`);
      console.log(`Created:         ${row.created_at}`);
      console.log(`Completed:       ${row.completed_at || 'N/A'}`);
      console.log(`Cards:           ${cards.length} cards`);

      if (cards.length > 0) {
        console.log(`\nSample cards:`);
        cards.slice(0, 4).forEach((card: any, i: number) => {
          console.log(`  ${i + 1}. ${card.emoji} (${card.status}) - Position ${card.position}`);
        });
      }
      console.log('');
    });

    // Verify JSONB structure
    const firstPuzzle = result.rows[0];
    const cards = typeof firstPuzzle.cards === 'string'
      ? JSON.parse(firstPuzzle.cards)
      : firstPuzzle.cards;

    if (Array.isArray(cards) && cards.length > 0) {
      console.log('✅ Cards stored as JSONB array');
      console.log(`✅ ${cards.length} cards in puzzle`);
      console.log(`✅ ${firstPuzzle.matched_pairs}/${firstPuzzle.total_pairs} pairs matched`);
    } else {
      console.log('⚠️  Warning: Cards array is empty or invalid');
    }

    // Verify date format (YYYY-MM-DD)
    const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
    if (dateRegex.test(firstPuzzle.date)) {
      console.log('✅ Date stored in YYYY-MM-DD format');
    } else {
      console.log(`⚠️  Warning: Date format incorrect: ${firstPuzzle.date}`);
    }

    console.log('\n✅ Memory Flip dual-write verification complete!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Verification failed:', error);
    process.exit(1);
  }
}

verifyMemoryFlipSync();

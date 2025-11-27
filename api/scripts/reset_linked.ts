/**
 * Reset linked_matches for test couple (Jokke & TestiY)
 *
 * Usage: cd api && npx tsx scripts/reset_linked.ts
 */

import { config } from 'dotenv';
import { join } from 'path';
import { query } from '../lib/db/pool';

config({ path: join(__dirname, '../.env.local') });

// Couple ID for Jokke (634e2af3-1625-4532-89c0-2d0900a2690a) & TestiY (e2ecabb7-43ee-422c-b49c-f0636d57e6d2)
const COUPLE_ID = '11111111-1111-1111-1111-111111111111';

async function reset() {
  try {
    console.log(`Deleting linked matches for couple: ${COUPLE_ID}`);

    const result = await query('DELETE FROM linked_matches WHERE couple_id = $1 RETURNING id', [COUPLE_ID]);

    if (result.rows.length > 0) {
      console.log(`✅ Deleted ${result.rows.length} linked match(es)`);
    } else {
      console.log('ℹ️  No existing matches found (already clean)');
    }

    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

reset();

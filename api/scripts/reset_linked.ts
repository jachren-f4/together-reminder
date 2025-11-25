/**
 * Reset linked_matches for test couple
 */

import { config } from 'dotenv';
import { join } from 'path';
import { query } from '../lib/db/pool';

config({ path: join(__dirname, '../.env.local') });

async function reset() {
  try {
    const coupleId = '09c1566c-3fa9-4562-acc8-79bd203010c2';

    const result = await query('DELETE FROM linked_matches WHERE couple_id = $1 RETURNING id', [coupleId]);
    console.log('Deleted', result.rows.length, 'linked matches');

    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

reset();

import { query, getClient } from '../lib/db/pool';

async function resetLinked() {
  const client = await getClient();

  try {
    // Get all couples with linked progress
    const { rows: couples } = await client.query(
      'SELECT id, linked_puzzle_index, linked_branch FROM couples'
    );
    console.log('Couples with Linked progress:', couples);

    // Reset linked progress for all couples
    await client.query('UPDATE couples SET linked_puzzle_index = 0');
    console.log('Reset linked_puzzle_index to 0 for all couples');

    // Delete active linked matches
    const { rows: deleted } = await client.query(
      "DELETE FROM linked_matches WHERE status = 'active' RETURNING id"
    );
    console.log('Deleted active matches:', deleted.length);

  } finally {
    client.release();
  }
}

resetLinked();

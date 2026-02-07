/**
 * Reset Linked cooldown for a specific user
 * Usage: npx tsx scripts/reset_linked_cooldown.ts test2011@dev.test
 */

import { query } from '../lib/db/pool';

async function main() {
  const email = process.argv[2] || 'test2011@dev.test';

  console.log(`Looking up user: ${email}`);

  // Find user by email (using auth.users and couples tables)
  const userResult = await query(
    `SELECT u.id, c.id as couple_id
     FROM auth.users u
     LEFT JOIN couples c ON c.user1_id = u.id OR c.user2_id = u.id
     WHERE u.email = $1`,
    [email]
  );

  if (userResult.rows.length === 0) {
    console.log(`User not found: ${email}`);
    process.exit(1);
  }

  const coupleId = userResult.rows[0].couple_id;
  console.log('Found user with couple_id:', coupleId);

  if (!coupleId) {
    console.log('User has no couple_id');
    process.exit(1);
  }

  // Get current cooldowns
  const coupleResult = await query(
    'SELECT cooldowns FROM couples WHERE id = $1',
    [coupleId]
  );

  console.log('Current cooldowns:', JSON.stringify(coupleResult.rows[0]?.cooldowns, null, 2));

  // Remove linked cooldown
  const cooldowns = coupleResult.rows[0]?.cooldowns || {};
  delete cooldowns['linked'];

  // Update
  await query(
    'UPDATE couples SET cooldowns = $1, updated_at = NOW() WHERE id = $2',
    [JSON.stringify(cooldowns), coupleId]
  );

  console.log('✅ Linked cooldown reset for couple', coupleId);

  // Verify
  const verifyResult = await query(
    'SELECT cooldowns FROM couples WHERE id = $1',
    [coupleId]
  );
  console.log('New cooldowns:', JSON.stringify(verifyResult.rows[0]?.cooldowns, null, 2));

  process.exit(0);
}

main().catch(e => {
  console.error('Error:', e);
  process.exit(1);
});

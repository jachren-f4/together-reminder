import { config } from 'dotenv';
config({ path: '.env.local' });
import { query } from '../lib/db/pool';

async function expireSubscription() {
  const coupleId = '16957918-207a-42fa-bd2c-f54e484d4920';

  // First check current status
  const before = await query(
    'SELECT subscription_status, subscription_expires_at FROM couples WHERE id = $1',
    [coupleId]
  );
  console.log('Before:', before.rows[0]);

  // Update to expired with past date
  await query(`
    UPDATE couples
    SET subscription_status = 'expired',
        subscription_expires_at = NOW() - INTERVAL '1 day'
    WHERE id = $1
  `, [coupleId]);

  // Verify
  const after = await query(
    'SELECT subscription_status, subscription_expires_at FROM couples WHERE id = $1',
    [coupleId]
  );
  console.log('After:', after.rows[0]);

  process.exit(0);
}

expireSubscription().catch(e => {
  console.error(e);
  process.exit(1);
});

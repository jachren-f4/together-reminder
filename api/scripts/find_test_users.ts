/**
 * Find existing test users in database for dev auth bypass
 */

import { config } from 'dotenv';
import { query } from '../lib/db/pool';

// Load .env.local
config({ path: '.env.local' });

async function findTestUsers() {
  try {
    console.log('🔍 Looking for existing couples in database...\n');

    const result = await query(
      'SELECT user1_id, user2_id FROM couples LIMIT 1',
      []
    );

    if (result.rows.length > 0) {
      console.log('✅ Found existing couple:');
      console.log(`   User 1 ID: ${result.rows[0].user1_id}`);
      console.log(`   User 2 ID: ${result.rows[0].user2_id}`);
      console.log('\n📋 Add to .env.local:');
      console.log(`AUTH_DEV_BYPASS_ENABLED=true`);
      console.log(`AUTH_DEV_USER_ID=${result.rows[0].user1_id}`);
      console.log(`AUTH_DEV_USER_EMAIL=dev-user1@togetherremind.local`);
    } else {
      console.log('❌ No couples found in database');
      console.log('\n💡 You need to create a test couple first.');
      console.log('   Run: npx tsx scripts/create_test_couple.ts');
    }

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

findTestUsers();

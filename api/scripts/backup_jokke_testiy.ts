/**
 * Backup Jokke & Testi-Y account info
 *
 * Saves their user IDs and couple relationship to a JSON file
 * so they can be referenced later without being accidentally deleted.
 *
 * Usage:
 *   npx tsx scripts/backup_jokke_testiy.ts
 */

import * as dotenv from 'dotenv';
import * as path from 'path';

// Load environment variables
dotenv.config({ path: path.join(__dirname, '..', '.env.local') });

import { query } from '../lib/db/pool';
import * as fs from 'fs';

// Known test account emails
const JOKKE_EMAIL = 'joakim.achren@fingersoft.net';
const TESTIY_EMAIL = 'joachren@gmail.com';

interface BackupData {
  backupDate: string;
  jokke: {
    email: string;
    userId: string | null;
    name: string | null;
  };
  testiy: {
    email: string;
    userId: string | null;
    name: string | null;
  };
  couple: {
    coupleId: string | null;
    createdAt: string | null;
    totalLp: number | null;
  };
}

async function main() {
  console.log('\n' + '='.repeat(60));
  console.log('   BACKUP JOKKE & TESTI-Y');
  console.log('='.repeat(60));

  const backup: BackupData = {
    backupDate: new Date().toISOString(),
    jokke: { email: JOKKE_EMAIL, userId: null, name: null },
    testiy: { email: TESTIY_EMAIL, userId: null, name: null },
    couple: { coupleId: null, createdAt: null, totalLp: null },
  };

  // Find Jokke
  console.log('\n🔍 Looking up Jokke...');
  const jokkeResult = await query(
    `SELECT id, email, raw_user_meta_data FROM auth.users WHERE LOWER(email) = $1`,
    [JOKKE_EMAIL.toLowerCase()]
  );

  if (jokkeResult.rows.length > 0) {
    const jokke = jokkeResult.rows[0];
    backup.jokke.userId = jokke.id;
    backup.jokke.name = jokke.raw_user_meta_data?.full_name || jokke.raw_user_meta_data?.name || null;
    console.log(`   ✓ Found: ${jokke.email}`);
    console.log(`     ID: ${jokke.id}`);
    console.log(`     Name: ${backup.jokke.name || '(not set)'}`);
  } else {
    console.log(`   ✗ Not found: ${JOKKE_EMAIL}`);
  }

  // Find Testi-Y
  console.log('\n🔍 Looking up Testi-Y...');
  const testiyResult = await query(
    `SELECT id, email, raw_user_meta_data FROM auth.users WHERE LOWER(email) = $1`,
    [TESTIY_EMAIL.toLowerCase()]
  );

  if (testiyResult.rows.length > 0) {
    const testiy = testiyResult.rows[0];
    backup.testiy.userId = testiy.id;
    backup.testiy.name = testiy.raw_user_meta_data?.full_name || testiy.raw_user_meta_data?.name || null;
    console.log(`   ✓ Found: ${testiy.email}`);
    console.log(`     ID: ${testiy.id}`);
    console.log(`     Name: ${backup.testiy.name || '(not set)'}`);
  } else {
    console.log(`   ✗ Not found: ${TESTIY_EMAIL}`);
  }

  // Find their couple relationship
  if (backup.jokke.userId && backup.testiy.userId) {
    console.log('\n🔍 Looking up couple relationship...');
    const coupleResult = await query(
      `SELECT id, created_at, total_lp FROM couples
       WHERE (user1_id = $1 AND user2_id = $2)
          OR (user1_id = $2 AND user2_id = $1)`,
      [backup.jokke.userId, backup.testiy.userId]
    );

    if (coupleResult.rows.length > 0) {
      const couple = coupleResult.rows[0];
      backup.couple.coupleId = couple.id;
      backup.couple.createdAt = couple.created_at;
      backup.couple.totalLp = couple.total_lp;
      console.log(`   ✓ Found couple!`);
      console.log(`     Couple ID: ${couple.id}`);
      console.log(`     Created: ${couple.created_at}`);
      console.log(`     Total LP: ${couple.total_lp}`);
    } else {
      console.log(`   ✗ No couple found between Jokke and Testi-Y`);
    }
  }

  // Save backup file
  const backupPath = path.join(__dirname, 'jokke_testiy_backup.json');
  fs.writeFileSync(backupPath, JSON.stringify(backup, null, 2));
  console.log(`\n💾 Backup saved to: ${backupPath}`);

  console.log('\n' + '='.repeat(60));
  console.log('✅ Backup complete!');
  console.log('='.repeat(60) + '\n');

  process.exit(0);
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});

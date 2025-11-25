/**
 * Check daily_quests table schema to see if migration 006 was applied
 */

import { query } from '../lib/db/pool';

async function checkSchema() {
  try {
    console.log('🔍 Checking daily_quests table schema...\n');

    const result = await query(`
      SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_name = 'daily_quests'
      ORDER BY ordinal_position
    `, []);

    console.log('📋 Column types:');
    result.rows.forEach(row => {
      const indicator = row.column_name === 'id' && row.data_type === 'text' ? '✅' :
                       row.column_name === 'id' && row.data_type === 'uuid' ? '❌' : '  ';
      console.log(`${indicator} ${row.column_name}: ${row.data_type}`);
    });

    const idColumn = result.rows.find(r => r.column_name === 'id');
    console.log('\n📊 Migration 006 status:');
    if (idColumn?.data_type === 'text') {
      console.log('✅ Migration 006 APPLIED - ID column is TEXT');
    } else {
      console.log('❌ Migration 006 NOT APPLIED - ID column is UUID');
      console.log('\n💡 To fix: cd /Users/joakimachren/Desktop/togetherremind/api && npx tsx scripts/apply_migration_006.ts');
    }

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

checkSchema();

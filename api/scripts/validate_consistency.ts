import { Pool } from 'pg';
import fs from 'fs';
import path from 'path';

// Configuration
const DATABASE_URL = process.env.DATABASE_URL;
const FIREBASE_DB_URL = process.env.FIREBASE_DB_URL; // e.g. https://your-project.firebaseio.com
const FIREBASE_SECRET = process.env.FIREBASE_SECRET; // Database secret from Firebase Console

if (!DATABASE_URL || !FIREBASE_DB_URL || !FIREBASE_SECRET) {
    console.error('❌ Error: DATABASE_URL, FIREBASE_DB_URL, and FIREBASE_SECRET are required.');
    console.error('Usage: DATABASE_URL=... FIREBASE_DB_URL=... FIREBASE_SECRET=... npx ts-node scripts/validate_consistency.ts');
    process.exit(1);
}

const pool = new Pool({
    connectionString: DATABASE_URL,
});

async function fetchFirebaseData(path: string) {
    const url = `${FIREBASE_DB_URL}/${path}.json?auth=${FIREBASE_SECRET}`;
    const response = await fetch(url);
    if (!response.ok) {
        throw new Error(`Firebase fetch failed: ${response.statusText}`);
    }
    return await response.json();
}

async function validateConsistency() {
    console.log('🔍 Starting Consistency Validation...');

    try {
        // 1. Fetch all couples from Supabase
        const couplesResult = await pool.query('SELECT id, user1_id, user2_id FROM couples');
        const couples = couplesResult.rows;
        console.log(`Found ${couples.length} couples in Supabase.`);

        let totalDrift = 0;
        let checkedItems = 0;

        for (const couple of couples) {
            console.log(`\nChecking couple ${couple.id}...`);

            // --- Validate Love Points ---
            // Firebase: /couples/{coupleId}/lovePoints
            // Supabase: user_love_points (sum of both users) or love_point_awards

            // Note: Mapping IDs might be tricky if Firebase uses different IDs.
            // Assuming couple.id is the same in both (migrated).

            const fbLovePoints = await fetchFirebaseData(`couples/${couple.id}/lovePoints`);
            const pgLovePointsResult = await pool.query(
                `SELECT SUM(total_points) as total FROM user_love_points WHERE user_id IN ($1, $2)`,
                [couple.user1_id, couple.user2_id]
            );
            const pgTotal = parseInt(pgLovePointsResult.rows[0].total || '0');

            // Firebase structure might vary, assuming simple total or summing transactions
            // If Firebase stores total directly:
            const fbTotal = fbLovePoints?.total || 0;

            if (fbTotal !== pgTotal) {
                console.error(`❌ Love Points Mismatch: FB=${fbTotal}, PG=${pgTotal}`);
                totalDrift++;
            } else {
                console.log(`✅ Love Points Synced: ${fbTotal}`);
            }
            checkedItems++;

            // --- Validate Daily Quests ---
            // Firebase: /couples/{coupleId}/dailyQuests/{date}
            const today = new Date().toISOString().split('T')[0];
            const fbQuests = await fetchFirebaseData(`couples/${couple.id}/dailyQuests/${today}`);

            const pgQuestsResult = await pool.query(
                `SELECT COUNT(*) as count FROM daily_quests WHERE couple_id = $1 AND date = $2`,
                [couple.id, today]
            );
            const pgQuestCount = parseInt(pgQuestsResult.rows[0].count || '0');

            const fbQuestCount = fbQuests ? Object.keys(fbQuests).length : 0;

            if (fbQuestCount !== pgQuestCount) {
                console.error(`❌ Daily Quests Mismatch (${today}): FB=${fbQuestCount}, PG=${pgQuestCount}`);
                totalDrift++;
            } else {
                console.log(`✅ Daily Quests Synced: ${fbQuestCount}`);
            }
            checkedItems++;
        }

        console.log('\n' + '='.repeat(50));
        console.log(`📊 Validation Complete`);
        console.log(`   Checked Items: ${checkedItems}`);
        console.log(`   Drift Incidents: ${totalDrift}`);
        console.log(`   Consistency: ${((1 - totalDrift / checkedItems) * 100).toFixed(2)}%`);

        if (totalDrift > 0) {
            process.exit(1);
        } else {
            process.exit(0);
        }

    } catch (error) {
        console.error('Error during validation:', error);
        process.exit(1);
    } finally {
        await pool.end();
    }
}

validateConsistency();

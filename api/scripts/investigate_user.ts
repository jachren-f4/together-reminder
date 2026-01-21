/**
 * Investigate a user account - see all activity
 *
 * Usage:
 *   npx tsx scripts/investigate_user.ts us2appreview2026@gmail.com
 */

import { query } from '../lib/db/pool';

async function investigateUser(email: string) {
  console.log(`\n🔍 Investigating user: ${email}\n`);
  console.log('='.repeat(60));

  // 1. Find user in auth.users
  console.log('\n👤 User Info:');
  const userResult = await query(
    `SELECT id, email, created_at, last_sign_in_at, updated_at
     FROM auth.users WHERE email = $1`,
    [email]
  );

  if (userResult.rows.length === 0) {
    console.log('   ❌ User not found in auth.users');
    return;
  }

  const user = userResult.rows[0];
  console.log(`   ID: ${user.id}`);
  console.log(`   Email: ${user.email}`);
  console.log(`   Created: ${user.created_at}`);
  console.log(`   Last sign in: ${user.last_sign_in_at}`);
  console.log(`   Updated: ${user.updated_at}`);

  // 2. Find user profile
  console.log('\n📋 User Profile:');
  const profileResult = await query(
    `SELECT id, display_name, couple_id, created_at, push_token, device_type
     FROM users WHERE id = $1`,
    [user.id]
  );

  if (profileResult.rows.length === 0) {
    console.log('   ❌ No profile found in users table');
  } else {
    const profile = profileResult.rows[0];
    console.log(`   Display name: ${profile.display_name}`);
    console.log(`   Couple ID: ${profile.couple_id}`);
    console.log(`   Created: ${profile.created_at}`);
    console.log(`   Push token: ${profile.push_token ? 'Yes (' + profile.push_token.substring(0, 20) + '...)' : 'None'}`);
    console.log(`   Device type: ${profile.device_type || 'Unknown'}`);

    // 3. Find couple info
    if (profile.couple_id) {
      console.log('\n💑 Couple Info:');
      const coupleResult = await query(
        `SELECT c.id, c.user1_id, c.user2_id, c.total_lp, c.created_at,
                u1.display_name as user1_name, u2.display_name as user2_name
         FROM couples c
         LEFT JOIN users u1 ON c.user1_id = u1.id
         LEFT JOIN users u2 ON c.user2_id = u2.id
         WHERE c.id = $1`,
        [profile.couple_id]
      );

      if (coupleResult.rows.length > 0) {
        const couple = coupleResult.rows[0];
        console.log(`   User 1: ${couple.user1_name} (${couple.user1_id})`);
        console.log(`   User 2: ${couple.user2_name || 'Not paired'} (${couple.user2_id || 'N/A'})`);
        console.log(`   Total LP: ${couple.total_lp}`);
        console.log(`   Created: ${couple.created_at}`);

        // 4. Check game activity
        const coupleId = profile.couple_id;

        console.log('\n🎮 Game Activity:');

        // Quiz matches
        const quizMatches = await query(
          `SELECT id, quiz_type, status, created_at, completed_at
           FROM quiz_matches WHERE couple_id = $1 ORDER BY created_at DESC LIMIT 5`,
          [coupleId]
        );
        console.log(`   Quiz matches: ${quizMatches.rowCount}`);
        for (const m of quizMatches.rows) {
          console.log(`     - ${m.quiz_type} (${m.status}) @ ${m.created_at}`);
        }

        // Linked matches
        const linkedMatches = await query(
          `SELECT id, puzzle_id, status, created_at, completed_at
           FROM linked_matches WHERE couple_id = $1 ORDER BY created_at DESC LIMIT 5`,
          [coupleId]
        );
        console.log(`   Linked matches: ${linkedMatches.rowCount}`);
        for (const m of linkedMatches.rows) {
          console.log(`     - ${m.puzzle_id} (${m.status}) @ ${m.created_at}`);
        }

        // Word search matches
        const wsMatches = await query(
          `SELECT id, puzzle_id, status, created_at, completed_at
           FROM word_search_matches WHERE couple_id = $1 ORDER BY created_at DESC LIMIT 5`,
          [coupleId]
        );
        console.log(`   Word Search matches: ${wsMatches.rowCount}`);
        for (const m of wsMatches.rows) {
          console.log(`     - ${m.puzzle_id} (${m.status}) @ ${m.created_at}`);
        }

        // Daily quests
        const quests = await query(
          `SELECT id, quest_date, created_at
           FROM daily_quests WHERE couple_id = $1 ORDER BY created_at DESC LIMIT 5`,
          [coupleId]
        );
        console.log(`   Daily quests: ${quests.rowCount}`);
        for (const q of quests.rows) {
          console.log(`     - ${q.quest_date} @ ${q.created_at}`);
        }

        // LP awards
        console.log('\n💰 Love Point Awards:');
        const lpAwards = await query(
          `SELECT id, amount, reason, created_at
           FROM love_point_awards WHERE couple_id = $1 ORDER BY created_at DESC LIMIT 10`,
          [coupleId]
        );
        console.log(`   Total awards: ${lpAwards.rowCount}`);
        for (const a of lpAwards.rows) {
          console.log(`     - +${a.amount} LP (${a.reason}) @ ${a.created_at}`);
        }
      }
    }
  }

  // 5. Check recent auth activity (sessions)
  console.log('\n🔐 Recent Auth Sessions:');
  try {
    const sessions = await query(
      `SELECT id, created_at, updated_at, user_agent, ip
       FROM auth.sessions WHERE user_id = $1 ORDER BY created_at DESC LIMIT 5`,
      [user.id]
    );
    console.log(`   Sessions: ${sessions.rowCount}`);
    for (const s of sessions.rows) {
      console.log(`     - Created: ${s.created_at}`);
      console.log(`       Updated: ${s.updated_at}`);
      console.log(`       IP: ${s.ip || 'Unknown'}`);
      console.log(`       UA: ${(s.user_agent || 'Unknown').substring(0, 60)}...`);
    }
  } catch (e) {
    console.log('   Could not query sessions');
  }

  console.log('\n' + '='.repeat(60));
  console.log('✅ Investigation complete\n');
}

// Main
async function main() {
  const email = process.argv[2];

  if (!email) {
    console.log('Usage: npx tsx scripts/investigate_user.ts <email>');
    process.exit(1);
  }

  await investigateUser(email);
  process.exit(0);
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});

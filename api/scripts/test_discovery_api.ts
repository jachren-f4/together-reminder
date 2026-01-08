/**
 * Test Discovery Relevance API
 *
 * Tests the /api/us-profile endpoint with the discovery relevance system.
 *
 * Usage:
 *   npx tsx scripts/test_discovery_api.ts
 */

import { createClient } from '@supabase/supabase-js';
import { createHash } from 'crypto';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.join(__dirname, '..', '.env.local') });

const supabaseUrl = process.env.SUPABASE_URL!;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY!;

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('Missing SUPABASE_URL or SUPABASE_ANON_KEY');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseAnonKey);

function getDevPassword(email: string): string {
  const hash = createHash('sha256').update(email).digest('hex');
  return `DevPass_${hash.substring(0, 12)}_2024!`;
}

async function testDiscoveryAPI() {
  console.log('\n=== Testing Discovery Relevance API ===\n');

  // Login as Bob (from opposites couple)
  const bobEmail = 'test7002@dev.test';
  const bobPassword = getDevPassword(bobEmail);

  console.log(`Logging in as Bob (${bobEmail})...`);

  const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
    email: bobEmail,
    password: bobPassword,
  });

  if (authError) {
    console.error('Auth error:', authError.message);
    process.exit(1);
  }

  console.log('✓ Logged in successfully\n');

  // Get access token
  const accessToken = authData.session?.access_token;
  if (!accessToken) {
    console.error('No access token');
    process.exit(1);
  }

  // Call the API
  const apiUrl = 'http://localhost:3000/api/us-profile';
  console.log(`Calling ${apiUrl}...`);

  const response = await fetch(apiUrl, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
  });

  if (!response.ok) {
    const text = await response.text();
    console.error(`API Error (${response.status}):`, text);
    process.exit(1);
  }

  const data = await response.json();
  console.log('✓ API responded successfully\n');

  // Display discovery section
  console.log('=== Discovery Section ===\n');
  const discoveries = data.profile?.discoveries;

  if (!discoveries) {
    console.log('No discoveries section in response');
    console.log('Full profile structure:', Object.keys(data.profile || {}));
    process.exit(1);
  }

  console.log(`Context Label: ${discoveries.contextLabel}`);
  console.log(`Total Count: ${discoveries.totalCount}`);
  console.log('');

  if (discoveries.featured) {
    console.log('=== Featured Discovery ===');
    const f = discoveries.featured;
    console.log(`  ID: ${f.id}`);
    console.log(`  Stakes: ${f.stakesLevel}`);
    console.log(`  Score: ${f.relevanceScore}`);
    console.log(`  Question: ${f.questionText}`);
    console.log(`  User1: ${f.user1Answer}`);
    console.log(`  User2: ${f.user2Answer}`);
    console.log(`  Appreciation: user=${f.appreciation.userAppreciated}, partner=${f.appreciation.partnerAppreciated}`);
    if (f.conversationGuide) {
      console.log(`  Guide: ${f.conversationGuide.acknowledgment}`);
    }
    if (f.timingBadge) {
      console.log(`  Timing: ${f.timingBadge.label}`);
    }
    console.log('');
  }

  console.log('=== Other Discoveries ===');
  for (const d of discoveries.others) {
    console.log(`  [${d.stakesLevel}] ${d.id} (score: ${d.relevanceScore})`);
    console.log(`     Q: ${d.questionText.substring(0, 50)}...`);
  }

  // Test appreciate toggle
  console.log('\n=== Testing Appreciate Toggle ===\n');

  if (discoveries.featured) {
    const discoveryId = discoveries.featured.id;
    console.log(`Appreciating discovery: ${discoveryId}`);

    const appreciateResponse = await fetch(
      `http://localhost:3000/api/us-profile/discovery/${discoveryId}/appreciate`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      }
    );

    if (!appreciateResponse.ok) {
      const text = await appreciateResponse.text();
      console.error(`Appreciate Error (${appreciateResponse.status}):`, text);
    } else {
      const appreciateData = await appreciateResponse.json();
      console.log('✓ Appreciate toggle response:', JSON.stringify(appreciateData, null, 2));
    }
  }

  console.log('\n=== Test Complete ===\n');
  process.exit(0);
}

testDiscoveryAPI().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});

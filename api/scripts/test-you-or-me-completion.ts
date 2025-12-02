/**
 * Test script to verify You-or-Me completion awards LP correctly
 *
 * Usage: npx tsx scripts/test-you-or-me-completion.ts
 */

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL!;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY!;
const API_URL = 'http://localhost:3000';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// Dev user IDs from config
const USER1_ID = 'c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28'; // Android/TestiY
const USER2_ID = 'd71425a3-a92f-404e-bfbe-a54c4cb58b6a'; // Chrome/Jokke

async function main() {
  console.log('🎮 Testing You-or-Me completion LP award...\n');

  // 1. Get couple info
  const { data: couple } = await supabase
    .from('couples')
    .select('id, total_lp')
    .or(`user1_id.eq.${USER1_ID},user2_id.eq.${USER1_ID}`)
    .single();

  if (!couple) {
    console.error('❌ No couple found');
    process.exit(1);
  }

  console.log(`📊 Current LP: ${couple.total_lp}`);
  const startingLP = couple.total_lp;

  // 2. Create a new you-or-me session
  const sessionId = crypto.randomUUID();
  const questions = [
    { id: 'q1', prompt: 'Test Q1', content: 'Question 1 content' },
    { id: 'q2', prompt: 'Test Q2', content: 'Question 2 content' },
  ];

  const { error: insertError } = await supabase.from('you_or_me_sessions').insert({
    id: sessionId,
    couple_id: couple.id,
    questions: questions,
    answers: {},
    status: 'in_progress',
  });

  if (insertError) {
    console.error('❌ Failed to create session:', insertError.message);
    process.exit(1);
  }

  console.log(`✅ Created you-or-me session ${sessionId}`);

  // 3. Submit answers for User 1 (all questions)
  console.log('\n🚀 Submitting User 1 answers...');
  const response1 = await fetch(`${API_URL}/api/sync/you-or-me/submit`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Dev-User-Id': USER1_ID,
    },
    body: JSON.stringify({
      sessionId,
      answers: questions.map((q, i) => ({
        questionId: q.id,
        questionPrompt: q.prompt,
        questionContent: q.content,
        answerValue: i % 2, // 0 or 1
        answeredAt: new Date().toISOString(),
      })),
    }),
  });

  const result1 = await response1.json();
  console.log('📨 User 1 Response:', JSON.stringify(result1, null, 2));

  if (!result1.success) {
    console.error('❌ User 1 submission failed:', result1.error);
    process.exit(1);
  }

  if (result1.isCompleted) {
    console.error('❌ Session should not be completed after first user');
    process.exit(1);
  }

  // 4. Submit answers for User 2 (all questions)
  console.log('\n🚀 Submitting User 2 answers...');
  const response2 = await fetch(`${API_URL}/api/sync/you-or-me/submit`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Dev-User-Id': USER2_ID,
    },
    body: JSON.stringify({
      sessionId,
      answers: questions.map((q, i) => ({
        questionId: q.id,
        questionPrompt: q.prompt,
        questionContent: q.content,
        answerValue: i % 2, // 0 or 1
        answeredAt: new Date().toISOString(),
      })),
    }),
  });

  const result2 = await response2.json();
  console.log('📨 User 2 Response:', JSON.stringify(result2, null, 2));

  if (!result2.success) {
    console.error('❌ User 2 submission failed:', result2.error);
    process.exit(1);
  }

  if (!result2.isCompleted) {
    console.error('❌ Session should be completed after second user');
    process.exit(1);
  }

  console.log('✅ You-or-Me session completed successfully!');

  // 5. Check if LP was awarded
  const { data: coupleAfter } = await supabase
    .from('couples')
    .select('total_lp')
    .eq('id', couple.id)
    .single();

  const lpAwarded = (coupleAfter?.total_lp || 0) - startingLP;
  console.log(`\n📊 LP before: ${startingLP}`);
  console.log(`📊 LP after: ${coupleAfter?.total_lp}`);
  console.log(`📊 LP awarded: ${lpAwarded}`);

  if (lpAwarded === 30) {
    console.log('\n✅ SUCCESS: Exactly 30 LP was awarded!');
  } else if (lpAwarded === 60) {
    console.log('\n❌ FAILURE: 60 LP was awarded (double-counting bug!)');
    process.exit(1);
  } else if (lpAwarded === 0) {
    console.log('\n❌ FAILURE: No LP was awarded!');
    process.exit(1);
  } else {
    console.log(`\n⚠️ UNEXPECTED: ${lpAwarded} LP was awarded`);
  }

  // Cleanup
  await supabase.from('you_or_me_sessions').delete().eq('id', sessionId);
  console.log('\n🧹 Cleaned up test session');
}

main().catch(console.error);

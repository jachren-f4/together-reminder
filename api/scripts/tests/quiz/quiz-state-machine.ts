/**
 * Classic Quiz State Machine Tests
 *
 * API-level tests covering the quiz system:
 * 1. Start quiz - creates new match with questions
 * 2. Submit answers - user submits answer array
 * 3. Partner submits - partner answers same quiz
 * 4. Match percentage calculation - correct percentage
 * 5. LP awarded on completion - 30 LP when both answer
 * 6. LP awarded exactly once - no double-counting
 * 7. Game status polling - correct state reporting
 * 8. Already answered error - prevent duplicate submission
 * 9. One quiz per day per type - uniqueness constraint
 * 10. Partner sees same quiz - shared match
 * 11. Match percentage accuracy - 100%, 0%, partial
 *
 * Run: cd api && npx tsx scripts/tests/quiz/quiz-state-machine.ts
 */

import {
  TEST_CONFIG,
  QUIZ_CONFIG,
  QuizTestApi,
  resetTestData,
  createTestClients,
  getTodayDate,
  generateMatchingAnswers,
  generateNonMatchingAnswers,
  calculateMatchPercentage,
  assert,
  assertEqual,
  assertGte,
  runTest,
  printSummary,
  sleep,
} from '../../lib/quiz-test-helpers';

// Helper to create typed test clients
function createQuizTestClients() {
  return createTestClients(QuizTestApi);
}

// ============================================================================
// Test Suite
// ============================================================================

async function main() {
  console.log('📝 Classic Quiz State Machine Tests');
  console.log('====================================\n');

  const results: Array<{ name: string; passed: boolean; error?: string }> = [];

  // Reset data before running tests
  await resetTestData();
  await sleep(200);

  // Run all tests
  results.push(await runTest('1. Start quiz creates new match with questions', testStartQuiz));
  results.push(await runTest('2. User can submit answers', testSubmitAnswers));
  results.push(await runTest('3. Partner submits to same quiz', testPartnerSubmits));
  results.push(await runTest('4. Match percentage calculated correctly', testMatchPercentage));
  results.push(await runTest('5. LP awarded on completion (30 LP)', testLPAwardedOnCompletion));
  results.push(await runTest('6. LP awarded exactly once (no double-count)', testLPNoDoubleCount));
  results.push(await runTest('7. Game status polling returns correct state', testGameStatusPolling));
  results.push(await runTest('8. Already answered error on duplicate', testAlreadyAnsweredError));
  results.push(await runTest('9. One quiz per day per type constraint', testOneQuizPerDay));
  results.push(await runTest('10. Partner sees same quiz questions', testPartnerSameQuiz));
  results.push(await runTest('11. Match percentage accuracy (100%, 0%)', testMatchPercentageAccuracy));

  // Print summary
  printSummary(results);

  // Exit with appropriate code
  const failed = results.filter((r) => !r.passed).length;
  process.exit(failed > 0 ? 1 : 0);
}

// ============================================================================
// Test Implementations
// ============================================================================

async function testStartQuiz() {
  await resetTestData();
  await sleep(200);

  const { user } = createQuizTestClients();

  // Start a new classic quiz
  const response = await user.startQuiz('classic');

  assert(response.success === true, 'Start quiz should succeed');
  assert(response.match !== undefined, 'Should return match data');
  assert(response.quiz !== undefined, 'Should return quiz questions');
  assert(response.isNew === true, 'Should indicate new match');

  // Verify quiz structure
  assert(response.quiz!.questions.length > 0, 'Quiz should have questions');
  assert(response.quiz!.questions[0].choices.length > 0, 'Questions should have choices');

  console.log(`  ✓ Quiz started with ${response.quiz!.questions.length} questions`);
}

async function testSubmitAnswers() {
  await resetTestData();
  await sleep(200);

  const { user } = createQuizTestClients();

  // Start quiz
  const startResponse = await user.startQuiz('classic');
  const matchId = startResponse.match.id;
  const questionCount = startResponse.quiz!.questions.length;

  // Generate and submit answers
  const answers = generateMatchingAnswers(questionCount);
  const submitResponse = await user.submitAnswers('classic', matchId, answers);

  assert(submitResponse.success === true, 'Submit should succeed');
  assert(submitResponse.state.userAnswered === true, 'User should be marked as answered');
  assert(submitResponse.state.partnerAnswered === false, 'Partner not yet answered');
  // Check state.isCompleted (not top-level isCompleted which may be overwritten)
  assert(submitResponse.state.isCompleted === false, 'Should not be complete (partner pending)');

  console.log('  ✓ User answers submitted, waiting for partner');
}

async function testPartnerSubmits() {
  await resetTestData();
  await sleep(200);

  const { user, partner } = createQuizTestClients();

  // User starts and submits
  const startResponse = await user.startQuiz('classic');
  const matchId = startResponse.match.id;
  const questionCount = startResponse.quiz!.questions.length;
  const userAnswers = generateMatchingAnswers(questionCount);

  await user.submitAnswers('classic', matchId, userAnswers);

  // Partner gets the same quiz
  const partnerStart = await partner.startQuiz('classic');
  assertEqual(partnerStart.match.id, matchId, 'Partner should join same match');
  assertEqual(partnerStart.isNew, false, 'Should not be a new match for partner');

  // Partner submits answers
  const partnerAnswers = generateMatchingAnswers(questionCount);
  const partnerSubmit = await partner.submitAnswers('classic', matchId, partnerAnswers);

  assert(partnerSubmit.success === true, 'Partner submit should succeed');
  assert(partnerSubmit.bothAnswered === true, 'Both should be marked as answered');
  assert(partnerSubmit.isCompleted === true, 'Quiz should be complete');
  assert(partnerSubmit.result !== null, 'Should have result');

  console.log(`  ✓ Both answered, match percentage: ${partnerSubmit.result!.matchPercentage}%`);
}

async function testMatchPercentage() {
  await resetTestData();
  await sleep(200);

  const { user, partner } = createQuizTestClients();

  // Start quiz
  const startResponse = await user.startQuiz('classic');
  const matchId = startResponse.match.id;
  const questionCount = startResponse.quiz!.questions.length;

  // User submits [0, 0, 0, ...]
  const userAnswers = generateMatchingAnswers(questionCount);
  await user.submitAnswers('classic', matchId, userAnswers);

  // Partner submits same answers
  const partnerAnswers = [...userAnswers];
  const result = await partner.submitAnswers('classic', matchId, partnerAnswers);

  assert(result.result !== null, 'Should have result');
  assertEqual(result.result!.matchPercentage, 100, 'Same answers should give 100% match');

  console.log('  ✓ 100% match verified');
}

async function testLPAwardedOnCompletion() {
  await resetTestData();
  await sleep(200);

  const { user, partner } = createQuizTestClients();

  // Get initial LP
  const initialLP = await user.getCoupleLP();
  assertEqual(initialLP, 0, 'LP should start at 0 after reset');

  // Complete a quiz
  const startResponse = await user.startQuiz('classic');
  const matchId = startResponse.match.id;
  const questionCount = startResponse.quiz!.questions.length;
  const answers = generateMatchingAnswers(questionCount);

  await user.submitAnswers('classic', matchId, answers);
  const result = await partner.submitAnswers('classic', matchId, answers);

  // Verify LP was awarded in the response
  assert(result.result !== null, 'Should have result');
  assertEqual(result.result!.lpEarned, QUIZ_CONFIG.lpRewardOnCompletion, 'Should award 30 LP');

  // Wait a bit for LP update to propagate
  await sleep(100);

  // Verify couple LP increased
  const finalLP = await user.getCoupleLP();
  assertGte(finalLP, QUIZ_CONFIG.lpRewardOnCompletion, 'Couple LP should be at least 30');

  console.log(`  ✓ LP awarded: ${result.result!.lpEarned} LP`);
}

async function testLPNoDoubleCount() {
  await resetTestData();
  await sleep(200);

  const { user, partner } = createQuizTestClients();

  // Complete a quiz
  const startResponse = await user.startQuiz('classic');
  const matchId = startResponse.match.id;
  const questionCount = startResponse.quiz!.questions.length;
  const answers = generateMatchingAnswers(questionCount);

  await user.submitAnswers('classic', matchId, answers);
  await partner.submitAnswers('classic', matchId, answers);

  // Get LP after completion
  const lpAfterComplete = await user.getCoupleLP();

  // Try to "re-fetch" the match (shouldn't award more LP)
  await user.getMatchState('classic', matchId);
  await partner.getMatchState('classic', matchId);

  // LP should be the same
  const lpAfterRefetch = await user.getCoupleLP();
  assertEqual(lpAfterRefetch, lpAfterComplete, 'LP should not increase on re-fetch');

  // Both partners should see same LP
  const partnerLP = await partner.getCoupleLP();
  assertEqual(partnerLP, lpAfterComplete, 'Both partners should see same LP');

  console.log('  ✓ LP not double-counted');
}

async function testGameStatusPolling() {
  await resetTestData();
  await sleep(200);

  const { user, partner } = createQuizTestClients();

  // Initially no games
  const emptyStatus = await user.getGameStatus(getTodayDate(), 'classic');
  assert(emptyStatus.success === true, 'Status should succeed');

  // Start a quiz
  const startResponse = await user.startQuiz('classic');
  const matchId = startResponse.match.id;
  const questionCount = startResponse.quiz!.questions.length;

  // Check status - should show active quiz
  const activeStatus = await user.getGameStatus(getTodayDate(), 'classic');
  assert(activeStatus.games.length > 0, 'Should have active game');

  const game = activeStatus.games.find(g => g.matchId === matchId);
  assert(game !== undefined, 'Should find our match');
  assertEqual(game!.status, 'active', 'Status should be active');
  assertEqual(game!.userAnswered, false, 'User not yet answered');

  // Submit answers
  const answers = generateMatchingAnswers(questionCount);
  await user.submitAnswers('classic', matchId, answers);

  // Check status again
  const waitingStatus = await user.getGameStatus(getTodayDate(), 'classic');
  const waitingGame = waitingStatus.games.find(g => g.matchId === matchId);
  assertEqual(waitingGame!.userAnswered, true, 'User should be marked answered');
  assertEqual(waitingGame!.partnerAnswered, false, 'Partner not answered yet');

  // Partner submits
  await partner.submitAnswers('classic', matchId, answers);

  // Check final status
  const completedStatus = await user.getGameStatus(getTodayDate(), 'classic');
  const completedGame = completedStatus.games.find(g => g.matchId === matchId);
  assertEqual(completedGame!.status, 'completed', 'Status should be completed');
  assertEqual(completedGame!.isCompleted, true, 'isCompleted should be true');
  assert(completedGame!.matchPercentage !== undefined, 'Should have match percentage');

  console.log('  ✓ Status polling returns correct state at each stage');
}

async function testAlreadyAnsweredError() {
  await resetTestData();
  await sleep(200);

  const { user } = createQuizTestClients();

  // Start and submit
  const startResponse = await user.startQuiz('classic');
  const matchId = startResponse.match.id;
  const questionCount = startResponse.quiz!.questions.length;
  const answers = generateMatchingAnswers(questionCount);

  await user.submitAnswers('classic', matchId, answers);

  // Try to submit again
  try {
    await user.submitAnswers('classic', matchId, answers);
    throw new Error('Should have thrown error for duplicate submission');
  } catch (error: unknown) {
    const err = error as Error & { code?: string };
    // Error message is "Already submitted answers" (case-insensitive check)
    assert(
      err.code === 'ALREADY_ANSWERED' || err.message.toLowerCase().includes('already'),
      `Error should indicate already answered, got: ${err.code || err.message}`
    );
    console.log('  ✓ Duplicate submission correctly rejected');
  }
}

async function testOneQuizPerDay() {
  await resetTestData();
  await sleep(200);

  const { user, partner } = createQuizTestClients();

  // Complete first quiz
  const first = await user.startQuiz('classic');
  const matchId = first.match.id;
  const questionCount = first.quiz!.questions.length;
  const answers = generateMatchingAnswers(questionCount);

  await user.submitAnswers('classic', matchId, answers);
  await partner.submitAnswers('classic', matchId, answers);

  // Try to start another classic quiz same day
  const second = await user.startQuiz('classic');

  // Should return the same completed match, not a new one
  assertEqual(second.match.id, matchId, 'Should return same match (one per day)');
  assertEqual(second.match.status, 'completed', 'Match should be completed');
  assertEqual(second.isNew, false, 'Should not be a new match');

  console.log('  ✓ One quiz per day constraint enforced');
}

async function testPartnerSameQuiz() {
  await resetTestData();
  await sleep(200);

  const { user, partner } = createQuizTestClients();

  // User starts quiz
  const userStart = await user.startQuiz('classic');
  const userQuizId = userStart.quiz!.id;
  const userQuestions = userStart.quiz!.questions;

  // Partner starts (should get same quiz)
  const partnerStart = await partner.startQuiz('classic');
  const partnerQuizId = partnerStart.quiz!.id;
  const partnerQuestions = partnerStart.quiz!.questions;

  assertEqual(partnerQuizId, userQuizId, 'Partner should get same quiz ID');
  assertEqual(
    partnerQuestions.length,
    userQuestions.length,
    'Partner should have same number of questions'
  );

  // Verify questions are the same
  for (let i = 0; i < userQuestions.length; i++) {
    assertEqual(
      partnerQuestions[i].id,
      userQuestions[i].id,
      `Question ${i} should have same ID`
    );
    assertEqual(
      partnerQuestions[i].text,
      userQuestions[i].text,
      `Question ${i} should have same text`
    );
  }

  console.log(`  ✓ Partner sees same quiz: ${userQuizId}`);
}

async function testMatchPercentageAccuracy() {
  await resetTestData();
  await sleep(200);

  const { user, partner } = createQuizTestClients();

  // Start quiz
  const startResponse = await user.startQuiz('classic');
  const matchId = startResponse.match.id;
  const questionCount = startResponse.quiz!.questions.length;

  // Test 100% match - all same answers
  const userAnswers = generateMatchingAnswers(questionCount);
  await user.submitAnswers('classic', matchId, userAnswers);

  const sameResult = await partner.submitAnswers('classic', matchId, userAnswers);
  assertEqual(sameResult.result!.matchPercentage, 100, '100% match for identical answers');

  // Reset for 0% test
  await resetTestData();
  await sleep(200);

  // Start new quiz
  const start2 = await user.startQuiz('classic');
  const matchId2 = start2.match.id;
  const qCount2 = start2.quiz!.questions.length;

  // User answers all 0s
  const user2Answers = generateMatchingAnswers(qCount2);
  await user.submitAnswers('classic', matchId2, user2Answers);

  // Partner answers all different
  const partner2Answers = generateNonMatchingAnswers(user2Answers);
  const diffResult = await partner.submitAnswers('classic', matchId2, partner2Answers);

  // Should be 0% match
  assertEqual(diffResult.result!.matchPercentage, 0, '0% match for completely different answers');

  console.log('  ✓ Match percentage accuracy verified');
}

// Run the tests
main().catch((error) => {
  console.error('Test suite failed:', error);
  process.exit(1);
});

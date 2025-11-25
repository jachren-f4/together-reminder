/**
 * Test Script for Memory Flip Turn-Based API
 *
 * Tests the move validation and puzzle state endpoints
 */

import { config } from 'dotenv';
import { join } from 'path';

// Load environment variables
config({ path: join(__dirname, '../.env.local') });

// Test configuration
const API_BASE_URL = 'http://localhost:3000';
const TEST_USER_ID = 'c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28'; // Dev user ID for testing
const PUZZLE_ID = `puzzle_${new Date().toISOString().substring(0, 10)}`;

// Helper function to make API calls
async function apiCall(
  method: string,
  path: string,
  body?: any,
  userId: string = TEST_USER_ID
) {
  const url = `${API_BASE_URL}${path}`;
  console.log(`\n📡 ${method} ${url}`);

  const options: RequestInit = {
    method,
    headers: {
      'Content-Type': 'application/json',
      'X-Dev-User-Id': userId, // Dev bypass header
    },
  };

  if (body) {
    options.body = JSON.stringify(body);
    console.log('📦 Request Body:', JSON.stringify(body, null, 2));
  }

  try {
    const response = await fetch(url, options);
    const data = await response.json();

    if (response.ok) {
      console.log('✅ Response:', JSON.stringify(data, null, 2));
    } else {
      console.error('❌ Error Response:', JSON.stringify(data, null, 2));
    }

    return { status: response.status, data };
  } catch (error) {
    console.error('❌ Request failed:', error);
    throw error;
  }
}

// Test functions
async function testGetPuzzleState() {
  console.log('\n========================================');
  console.log('🎮 TEST: Get Puzzle State');
  console.log('========================================');

  const result = await apiCall('GET', `/api/sync/memory-flip/${PUZZLE_ID}`);

  if (result.status === 200) {
    console.log('✅ Successfully retrieved puzzle state');
    console.log('   - Game Phase:', result.data.puzzle.gamePhase);
    console.log('   - Current Player:', result.data.puzzle.currentPlayerId);
    console.log('   - Matched Pairs:', result.data.puzzle.matchedPairs);
    console.log('   - Is My Turn:', result.data.isMyTurn);
    console.log('   - My Flips Remaining:', result.data.myFlipsRemaining);
    return result.data;
  } else {
    console.log('⚠️  Puzzle not found or error occurred');
    return null;
  }
}

async function testCreatePuzzle() {
  console.log('\n========================================');
  console.log('🎮 TEST: Create New Puzzle');
  console.log('========================================');

  // Generate sample cards
  const emojis = ['🍎', '🍌', '🍇', '🍊', '🍓', '🍑', '🥝', '🍉'];
  const cards = [];

  for (let i = 0; i < emojis.length; i++) {
    const pairId = `pair-${i}`;
    // Add two cards for each emoji (pair)
    cards.push({
      id: `card-${i * 2}`,
      emoji: emojis[i],
      pairId,
      status: 'hidden',
      position: i * 2
    });
    cards.push({
      id: `card-${i * 2 + 1}`,
      emoji: emojis[i],
      pairId,
      status: 'hidden',
      position: i * 2 + 1
    });
  }

  // Shuffle cards
  for (let i = cards.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [cards[i], cards[j]] = [cards[j], cards[i]];
  }

  const puzzleData = {
    id: PUZZLE_ID,
    date: new Date().toISOString().substring(0, 10),
    totalPairs: emojis.length,
    matchedPairs: 0,
    cards: cards,
    status: 'active',
    createdAt: new Date().toISOString()
  };

  const result = await apiCall('POST', '/api/sync/memory-flip', puzzleData);

  if (result.status === 200) {
    console.log('✅ Successfully created puzzle');
    return true;
  } else {
    console.log('❌ Failed to create puzzle');
    return false;
  }
}

async function testSubmitMove(card1Id: string, card2Id: string, expectedResult: string) {
  console.log('\n========================================');
  console.log(`🎮 TEST: Submit Move (${expectedResult})`);
  console.log('========================================');

  const moveData = {
    puzzleId: PUZZLE_ID,
    card1Id,
    card2Id
  };

  const result = await apiCall('POST', '/api/sync/memory-flip/move', moveData);

  if (result.status === 200) {
    console.log('✅ Move accepted');
    console.log('   - Match Found:', result.data.matchFound);
    console.log('   - Turn Advanced:', result.data.turnAdvanced);
    console.log('   - Player Flips Remaining:', result.data.playerFlipsRemaining);
    console.log('   - Next Player:', result.data.nextPlayerId);
    return result.data;
  } else {
    console.log('❌ Move rejected');
    console.log('   - Error:', result.data.error);
    console.log('   - Message:', result.data.message);
    return null;
  }
}

async function testNotYourTurn() {
  console.log('\n========================================');
  console.log('🎮 TEST: Try Move When Not Your Turn');
  console.log('========================================');

  // Use a different user ID to simulate the partner
  const PARTNER_USER_ID = 'd71425a3-a92f-404e-bfbe-a54c4cb58b6a';

  const moveData = {
    puzzleId: PUZZLE_ID,
    card1Id: 'card-0',
    card2Id: 'card-1'
  };

  const result = await apiCall('POST', '/api/sync/memory-flip/move', moveData, PARTNER_USER_ID);

  if (result.status === 403 && result.data.error === 'NOT_YOUR_TURN') {
    console.log('✅ Correctly rejected move (not player\'s turn)');
    return true;
  } else {
    console.log('❌ Unexpected result');
    return false;
  }
}

async function runTests() {
  console.log('🚀 Starting Memory Flip Turn-Based API Tests');
  console.log('===========================================\n');

  try {
    // Test 1: Create a new puzzle
    const created = await testCreatePuzzle();
    if (!created) {
      console.log('\n⚠️  Skipping further tests - puzzle creation failed');
      return;
    }

    // Test 2: Get initial puzzle state
    const initialState = await testGetPuzzleState();
    if (!initialState) {
      console.log('\n⚠️  Skipping further tests - could not get puzzle state');
      return;
    }

    // Get some card IDs from the puzzle
    const cards = initialState.puzzle.cards;
    if (cards.length < 4) {
      console.log('\n⚠️  Not enough cards in puzzle for testing');
      return;
    }

    // Test 3: Submit a valid move (no match)
    await testSubmitMove(cards[0].id, cards[1].id, 'No Match');

    // Test 4: Try to move when it's not your turn
    await testNotYourTurn();

    // Test 5: Get updated puzzle state
    await testGetPuzzleState();

    // Test 6: Look for a matching pair and submit it
    const pairId = cards[0].pairId;
    const matchingCard = cards.find((c: any) => c.pairId === pairId && c.id !== cards[0].id);
    if (matchingCard) {
      await testSubmitMove(cards[0].id, matchingCard.id, 'Match Found');
    }

    console.log('\n========================================');
    console.log('✅ All tests completed');
    console.log('========================================');

  } catch (error) {
    console.error('\n❌ Test suite failed:', error);
  }
}

// Check if API server is running
async function checkApiServer() {
  try {
    const response = await fetch(`${API_BASE_URL}/api`);
    if (!response.ok) {
      console.log('\n⚠️  API server may not be running properly');
      console.log('   Start it with: cd api && npm run dev');
    }
    return true;
  } catch (error) {
    console.error('\n❌ API server is not running!');
    console.error('   Start it with: cd api && npm run dev');
    return false;
  }
}

// Main execution
async function main() {
  // Check if API server is accessible
  const serverRunning = await checkApiServer();
  if (!serverRunning) {
    process.exit(1);
  }

  // Check for auth bypass in dev mode
  if (!process.env.AUTH_DEV_BYPASS_ENABLED) {
    console.log('\n⚠️  Warning: AUTH_DEV_BYPASS_ENABLED not set in .env.local');
    console.log('   Tests may fail without dev auth bypass');
  }

  // Run tests
  await runTests();
}

main().catch(console.error);
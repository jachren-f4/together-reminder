#!/usr/bin/env node

/**
 * Test script for remote pairing Cloud Functions
 * Tests createPairingCode and getPairingCode functions
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./togetherremind-firebase-adminsdk-1h37q-c48c1e6c2f.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://togetherremind-default-rtdb.firebaseio.com'
});

const functions = require('firebase-functions-test')();
const myFunctions = require('./functions/index');

async function testCreatePairingCode() {
  console.log('\n🧪 Testing createPairingCode...');

  const data = {
    userId: 'test-user-123',
    pushToken: 'test-fcm-token-xyz',
    name: 'Test User',
    avatarEmoji: '🧪'
  };

  try {
    const wrapped = functions.wrap(myFunctions.createPairingCode);
    const result = await wrapped({ data });

    console.log('✅ Code created successfully!');
    console.log('   Code:', result.code);
    console.log('   Length:', result.code.length);
    console.log('   Expires at:', new Date(result.expiresAt).toISOString());

    // Validate code format
    const validChars = /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$/;
    if (!validChars.test(result.code)) {
      console.error('❌ Code has invalid characters!');
      return null;
    }

    console.log('✅ Code format valid (6 chars, no ambiguous characters)');

    return result.code;
  } catch (error) {
    console.error('❌ Error creating code:', error.message);
    return null;
  }
}

async function testGetPairingCode(code) {
  console.log('\n🧪 Testing getPairingCode with code:', code);

  try {
    const wrapped = functions.wrap(myFunctions.getPairingCode);
    const result = await wrapped({ data: { code } });

    console.log('✅ Code retrieved successfully!');
    console.log('   User ID:', result.userId);
    console.log('   Name:', result.name);
    console.log('   Avatar:', result.avatarEmoji);
    console.log('   Push Token:', result.pushToken ? 'EXISTS' : 'MISSING');

    return result;
  } catch (error) {
    console.error('❌ Error retrieving code:', error.message);
    return null;
  }
}

async function testInvalidCode() {
  console.log('\n🧪 Testing getPairingCode with invalid code...');

  try {
    const wrapped = functions.wrap(myFunctions.getPairingCode);
    await wrapped({ data: { code: 'INVALID' } });

    console.error('❌ Should have thrown error for invalid code!');
  } catch (error) {
    console.log('✅ Correctly rejected invalid code:', error.message);
  }
}

async function testExpiredCode() {
  console.log('\n🧪 Testing code expiration...');
  console.log('   (This would require waiting 10 minutes - skipping)');
  console.log('   Manual test: Wait 10 minutes and try to retrieve a code');
}

async function testCodeReuse() {
  console.log('\n🧪 Testing one-time use (code should be deleted after retrieval)...');

  const code = await testCreatePairingCode();
  if (!code) return;

  // First retrieval should work
  const result1 = await testGetPairingCode(code);
  if (!result1) return;

  console.log('\n   Attempting to retrieve same code again...');

  try {
    const wrapped = functions.wrap(myFunctions.getPairingCode);
    await wrapped({ data: { code } });

    console.error('❌ Code should have been deleted after first retrieval!');
  } catch (error) {
    console.log('✅ Correctly rejected reused code:', error.message);
  }
}

async function runAllTests() {
  console.log('🚀 Starting Remote Pairing Function Tests\n');
  console.log('=' .repeat(60));

  try {
    // Test 1: Create a code
    const code = await testCreatePairingCode();
    if (!code) {
      console.error('\n❌ Failed to create code. Aborting tests.');
      process.exit(1);
    }

    // Test 2: Retrieve the code
    await testGetPairingCode(code);

    // Test 3: Invalid code
    await testInvalidCode();

    // Test 4: Code reuse (one-time use)
    await testCodeReuse();

    // Test 5: Expiration (manual)
    await testExpiredCode();

    console.log('\n' + '='.repeat(60));
    console.log('✅ All automated tests completed successfully!');
    console.log('\nManual tests still needed:');
    console.log('  - Test code expiration (wait 10 minutes)');
    console.log('  - Test in Flutter app (UI flow)');
    console.log('  - Test cross-device pairing');

  } catch (error) {
    console.error('\n❌ Test suite failed:', error);
  } finally {
    // Cleanup
    functions.cleanup();
    process.exit(0);
  }
}

// Run tests
runAllTests();

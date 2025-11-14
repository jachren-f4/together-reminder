#!/usr/bin/env dart
/// Standalone test script for LP syncing
///
/// Usage: dart test_lp_sync.dart
///
/// This script:
/// 1. Initializes Firebase and Hive (using test directories)
/// 2. Creates two mock users (Alice and Bob)
/// 3. Simulates both users completing a quest
/// 4. Verifies LP awards are synced correctly via Firebase
/// 5. Checks both users have the same LP total

import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'lib/models/user.dart';
import 'lib/models/love_point_transaction.dart';
import 'lib/services/love_point_service.dart';
import 'lib/services/storage_service.dart';
import 'lib/firebase_options.dart';

// Test user IDs
const aliceId = 'alice-test-user-${DateTime.now().millisecondsSinceEpoch}';
const bobId = 'bob-test-user-${DateTime.now().millisecondsSinceEpoch}';

void main() async {
  print('🧪 LP Sync Test Starting...\n');

  try {
    // 1. Initialize Firebase
    print('1️⃣ Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('   ✅ Firebase initialized\n');

    // 2. Initialize Hive with test directory
    print('2️⃣ Initializing Hive (test mode)...');
    final testDir = Directory.systemTemp.createTempSync('lp_test_');
    await Hive.initFlutter(testDir.path);

    // Register adapters
    Hive.registerAdapter(UserAdapter());
    Hive.registerAdapter(LovePointTransactionAdapter());

    await StorageService.init();
    print('   ✅ Hive initialized at: ${testDir.path}\n');

    // 3. Create two users
    print('3️⃣ Creating test users...');
    final alice = await _createUser(aliceId, 'Alice');
    final bob = await _createUser(bobId, 'Bob');
    print('   ✅ Alice created: $aliceId (LP: ${alice.lovePoints})');
    print('   ✅ Bob created: $bobId (LP: ${bob.lovePoints})\n');

    // 4. Set up LP listeners (simulate both apps listening)
    print('4️⃣ Setting up LP award listeners...');
    LovePointService.startListeningForLPAwards(
      currentUserId: aliceId,
      partnerUserId: bobId,
    );
    LovePointService.startListeningForLPAwards(
      currentUserId: bobId,
      partnerUserId: aliceId,
    );
    print('   ✅ LP listeners initialized\n');

    // 5. Simulate quest completion - award LP to both users
    print('5️⃣ Simulating quest completion by both users...');
    print('   📤 Awarding 30 LP to both users via Firebase...');

    await LovePointService.awardPointsToBothUsers(
      userId1: aliceId,
      userId2: bobId,
      amount: 30,
      reason: 'daily_quest_test',
      relatedId: 'test-quest-123',
    );

    print('   ✅ LP award written to Firebase\n');

    // 6. Wait for Firebase listeners to process
    print('6️⃣ Waiting for LP awards to be applied...');
    await Future.delayed(Duration(seconds: 3));
    print('   ✅ Processing complete\n');

    // 7. Check results
    print('7️⃣ Checking final LP totals...');
    final storage = StorageService();
    final aliceAfter = storage.getUser();
    final bobAfter = storage.getPartner();

    print('   Alice LP: ${aliceAfter?.lovePoints ?? 'NULL'}');
    print('   Bob LP: ${bobAfter?.lovePoints ?? 'NULL'}\n');

    // 8. Verify results
    print('8️⃣ Verification:');
    if (aliceAfter == null || bobAfter == null) {
      print('   ❌ FAILED: Users not found in storage');
      exit(1);
    }

    if (aliceAfter.lovePoints == bobAfter.lovePoints) {
      print('   ✅ SUCCESS: Both users have the same LP (${aliceAfter.lovePoints})');
    } else {
      print('   ❌ FAILED: LP mismatch!');
      print('      Alice: ${aliceAfter.lovePoints}');
      print('      Bob: ${bobAfter.lovePoints}');
      exit(1);
    }

    if (aliceAfter.lovePoints >= 30) {
      print('   ✅ SUCCESS: LP was awarded (expected 30, got ${aliceAfter.lovePoints})');
    } else {
      print('   ❌ FAILED: LP not awarded correctly (expected 30, got ${aliceAfter.lovePoints})');
      exit(1);
    }

    // 9. Cleanup
    print('\n9️⃣ Cleaning up...');
    await _cleanupFirebase();
    await Hive.close();
    testDir.deleteSync(recursive: true);
    print('   ✅ Cleanup complete\n');

    print('🎉 All tests passed!');
    exit(0);

  } catch (e, stackTrace) {
    print('\n❌ Test failed with error:');
    print(e);
    print('\nStack trace:');
    print(stackTrace);
    exit(1);
  }
}

Future<User> _createUser(String userId, String name) async {
  final storage = StorageService();

  final user = User(
    id: userId,
    name: name,
    pushToken: userId, // Using ID as push token for test
    lovePoints: 0,
    arenaTier: 1,
    floor: 0,
  );

  await storage.saveUser(user);
  return user;
}

Future<void> _cleanupFirebase() async {
  try {
    final database = FirebaseDatabase.instance.ref();

    // Generate couple ID
    final sortedIds = [aliceId, bobId]..sort();
    final coupleId = '${sortedIds[0]}_${sortedIds[1]}';

    // Remove test data
    await database.child('lp_awards/$coupleId').remove();
    print('   ✅ Removed test data from Firebase');
  } catch (e) {
    print('   ⚠️  Firebase cleanup error (non-critical): $e');
  }
}

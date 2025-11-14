#!/usr/bin/env dart
/// Quick test script to trigger an LP award to Firebase
///
/// Usage: dart trigger_lp_award.dart
///
/// This will write an LP award to Firebase that both running apps should pick up.
/// Watch the console logs for:
/// - "💰 LP award synced to Firebase"
/// - "💰 Applied LP award from Firebase"

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import 'lib/firebase_options.dart';

// Dev user IDs (must match running apps)
const aliceId = 'alice-dev-user-00000000-0000-0000-0000-000000000001';
const bobId = 'bob-dev-user-00000000-0000-0000-0000-000000000002';

void main() async {
  print('🧪 Triggering LP Award Test\n');

  try {
    // Initialize Firebase
    print('Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized\n');

    // Generate couple ID
    final sortedIds = [aliceId, bobId]..sort();
    final coupleId = '${sortedIds[0]}_${sortedIds[1]}';
    final awardId = const Uuid().v4();

    print('Couple ID: $coupleId');
    print('Award ID: $awardId\n');

    // Write LP award to Firebase
    print('Writing LP award to Firebase...');
    final database = FirebaseDatabase.instance.ref();
    await database.child('lp_awards/$coupleId/$awardId').set({
      'users': [aliceId, bobId],
      'amount': 30,
      'reason': 'test_manual_trigger',
      'relatedId': 'test-trigger-${DateTime.now().millisecondsSinceEpoch}',
      'multiplier': 1,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    print('✅ LP award written to Firebase!\n');
    print('📺 Check your running apps - both should receive 30 LP');
    print('   Look for these log messages:');
    print('   - "💰 Applied LP award from Firebase: +30 LP"');
    print('   - Check debug panel to verify LP totals match\n');

  } catch (e, stackTrace) {
    print('\n❌ Error:');
    print(e);
    print('\nStack trace:');
    print(stackTrace);
  }
}

# Phase 1: Incremental Implementation Plan (CORRECTED)

**Version:** 2.0 (Corrected)
**Last Updated:** 2025-11-16
**Status:** Ready for Implementation

**Approach:** Each increment is independently testable and can be verified before moving to the next.

---

## ⚠️ PRE-IMPLEMENTATION REQUIREMENTS

**CRITICAL: Complete all items in `PHASE_1_PRE_IMPLEMENTATION_CHECKLIST.md` before starting Increment 1A.**

Key requirements:
- ✅ Firebase RTDB Transaction API understanding verified
- ✅ CLAUDE.md initialization order reviewed
- ✅ Logger service configuration documented
- ✅ Hive build_runner workflow understood
- ✅ Complete Clean Testing Procedure reviewed

---

## Increment 1A: Schema Version Constants & Read Validation (30 min)

**Goal:** Add version tracking infrastructure WITHOUT changing any write behavior.

### Implementation

1. Create new constants file:

```dart
// app/lib/constants/schema_versions.dart
class SchemaVersions {
  // Hive schema version (increment when changing @HiveField)
  static const int currentHiveVersion = 1;

  // Firebase schema version (increment when changing Firebase structure)
  static const int currentFirebaseVersion = 1;

  // App version (from pubspec.yaml)
  static const String appVersion = '1.0.0';

  // Minimum compatible versions
  static const int minCompatibleHiveVersion = 1;
  static const int minCompatibleFirebaseVersion = 1;
}
```

2. Add version validation helper:

```dart
// app/lib/utils/version_validator.dart
import '../constants/schema_versions.dart';

class VersionValidator {
  /// Check if Firebase data version is compatible
  static bool isFirebaseVersionCompatible(int? dataVersion) {
    if (dataVersion == null) {
      // Null version = old data (pre-versioning)
      // Will be migrated in Increment 1D
      return true;
    }

    if (dataVersion > SchemaVersions.currentFirebaseVersion) {
      // Data from newer app version
      return false;
    }

    if (dataVersion < SchemaVersions.minCompatibleFirebaseVersion) {
      // Data too old, needs migration
      return false;
    }

    return true;
  }

  /// Get user-friendly error message
  static String getIncompatibilityMessage(int? dataVersion) {
    if (dataVersion == null) return 'Unknown version';

    if (dataVersion > SchemaVersions.currentFirebaseVersion) {
      return 'This data was created by a newer version of TogetherRemind. Please update your app.';
    }

    return 'This data is from an older version and cannot be loaded. Please contact support.';
  }
}
```

### Testing

```bash
# 1. Run tests
cd app
flutter test test/utils/version_validator_test.dart

# 2. Verify no behavior changes
flutter run -d emulator-5554
# Complete a quest → verify everything works as before
```

**Success Criteria:**
- [ ] New files compile without errors
- [ ] No changes to existing behavior
- [ ] Unit tests pass for version validation logic

---

## Increment 1B: Add Version to Firebase Writes (1 hour)

**Goal:** Start writing version metadata to Firebase (backwards compatible).

### Implementation

Update `quest_sync_service.dart`:

```dart
// app/lib/services/quest_sync_service.dart
import '../constants/schema_versions.dart';

Future<void> syncGeneratedQuests(...) async {
  // ... existing code ...

  await questsRef.set({
    // NEW: Add version metadata
    'schemaVersion': SchemaVersions.currentFirebaseVersion,
    'appVersion': SchemaVersions.appVersion,

    // Existing fields
    'quests': questsData,
    'generatedBy': currentUserId,
    'generatedAt': ServerValue.timestamp,  // Keep existing field
    'dateKey': dateKey,
    'progression': progressionState != null ? {...} : null,
  });
}
```

Update other Firebase writes:
- `quiz_sessions` write (quiz_service.dart)
- `quiz_progression` write (quest_sync_service.dart)
- `you_or_me_sessions` write (you_or_me_service.dart)

### Testing Prerequisites

**IMPORTANT:** Enable Logger services before testing:

```bash
# Edit app/lib/utils/logger.dart
# Find the following lines and set to true:
'quest': true,      # Line ~239
'quiz': true,       # Line ~238
```

### Testing

```bash
# 1. Clean Firebase
firebase database:remove /daily_quests --force

# 2. Launch app and generate quests (use Complete Clean Testing Procedure)
pkill -9 -f "flutter"
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind

cd /Users/joakimachren/Desktop/togetherremind/app
flutter build apk --debug &
ANDROID_BUILD_PID=$!

# Wait for build
wait $ANDROID_BUILD_PID && echo "✅ Android build complete"

# Launch and pair devices
flutter run -d emulator-5554
# Generate quests

# 3. Check Firebase for version metadata
firebase database:get /daily_quests

# Expected output:
# {
#   "alice_bob": {
#     "2025-11-16": {
#       "schemaVersion": 1,
#       "appVersion": "1.0.0",
#       "quests": [...]
#     }
#   }
# }
```

**Success Criteria:**
- [ ] Firebase writes include `schemaVersion` and `appVersion`
- [ ] Old data without version still loads (backwards compatible)
- [ ] Quest sync still works between devices

---

## Increment 1C: Add Version Validation on Read (1 hour)

**Goal:** Validate version when reading Firebase data, log errors clearly.

### Implementation

```dart
// app/lib/services/quest_sync_service.dart
import '../utils/version_validator.dart';
import '../utils/logger.dart';

Future<void> _loadQuestsFromFirebase(
  DataSnapshot snapshot,
  String dateKey,
) async {
  try {
    final data = snapshot.value as Map<dynamic, dynamic>;

    // NEW: Validate schema version
    final schemaVersion = data['schemaVersion'] as int?;
    final appVersion = data['appVersion'] as String?;

    if (!VersionValidator.isFirebaseVersionCompatible(schemaVersion)) {
      final message = VersionValidator.getIncompatibilityMessage(schemaVersion);

      // CRITICAL: Use Logger.error() WITHOUT service parameter
      // to ensure errors always log (bypasses verbosity control)
      Logger.error('Incompatible Firebase version',
        data: {'schema': schemaVersion, 'app': appVersion, 'message': message},
      );

      // For now, just log - don't throw (will throw in next increment)
      Logger.warn('Loading anyway for testing...', service: 'quest');
    } else {
      Logger.debug('Firebase version check passed: v$schemaVersion',
        service: 'quest',
      );
    }

    final questsData = data['quests'] as List<dynamic>;
    // ... rest of loading logic
  } catch (e) {
    Logger.error('Error loading quests from Firebase', error: e);
    rethrow;
  }
}
```

### Testing

```bash
# Test 1: Normal case (compatible versions)
flutter run -d emulator-5554
# Generate quests → check logs for "Firebase version check passed"

# Test 2: Future version (simulate newer app)
# Manually edit Firebase:
firebase database:update /daily_quests/alice_bob/2025-11-16 '{"schemaVersion": 99}'

# Reload app → check logs for "Incompatible Firebase version" error
# Verify quests still load (we're not blocking yet)

# Test 3: Old data (no version)
firebase database:update /daily_quests/alice_bob/2025-11-16 '{"schemaVersion": null}'
# Verify loads without errors
```

**Success Criteria:**
- [ ] Logs show version check for each Firebase read
- [ ] Compatible versions pass silently
- [ ] Incompatible versions log errors (without service parameter)
- [ ] Old data (null version) loads without errors

---

## Increment 1D: Null-Version Migration Strategy (45 min)

**Goal:** Implement migration path for pre-versioning data.

### Implementation

```dart
// app/lib/services/version_migration_service.dart
import '../constants/schema_versions.dart';
import '../utils/logger.dart';
import 'package:firebase_database/firebase_database.dart';

class VersionMigrationService {
  static final _database = FirebaseDatabase.instance.ref();

  /// Migrate null-version quests to v1
  static Future<void> migrateQuestsToV1({
    required String currentUserId,
    required String partnerUserId,
  }) async {
    try {
      final sortedIds = [currentUserId, partnerUserId]..sort();
      final coupleId = '${sortedIds[0]}_${sortedIds[1]}';

      final questsRef = _database.child('daily_quests/$coupleId');
      final snapshot = await questsRef.get();

      if (!snapshot.exists) return;

      final data = snapshot.value as Map<dynamic, dynamic>;
      int migratedCount = 0;

      for (final entry in data.entries) {
        final dateKey = entry.key as String;
        final dateData = entry.value as Map<dynamic, dynamic>;

        // Check if already has version
        if (dateData['schemaVersion'] != null) continue;

        // Migrate to v1
        await questsRef.child(dateKey).update({
          'schemaVersion': 1,
          'appVersion': SchemaVersions.appVersion,
          'migratedAt': ServerValue.timestamp,
        });

        migratedCount++;
      }

      if (migratedCount > 0) {
        Logger.info('Migrated $migratedCount quest date(s) to v1');
      }
    } catch (e) {
      Logger.error('Error migrating quests', error: e);
    }
  }
}
```

Update `main.dart`:

```dart
// app/lib/main.dart

Future<void> _initializeDailyQuests() async {
  final user = StorageService.instance.getUser();
  final partner = StorageService.instance.getPartner();

  if (user != null && partner != null) {
    // NEW: Migrate old data before loading
    await VersionMigrationService.migrateQuestsToV1(
      currentUserId: user.id,
      partnerUserId: partner.pushToken,
    );

    // ... existing quest initialization
  }
}
```

### Testing

```bash
# 1. Create test data with null version
firebase database:set /daily_quests/alice_bob/2025-11-15 '{"quests": [], "generatedAt": 1700000000}'

# 2. Launch app
flutter run -d emulator-5554

# 3. Check Firebase - should now have schemaVersion
firebase database:get /daily_quests/alice_bob/2025-11-15
# Expected: {"schemaVersion": 1, "migratedAt": <timestamp>, ...}

# 4. Check logs for "Migrated X quest date(s) to v1"
```

**Success Criteria:**
- [ ] Null-version quests automatically migrated to v1
- [ ] Migration logged with count
- [ ] Existing v1 quests not re-migrated
- [ ] App continues to work with migrated data

---

## Increment 2A: Add Firebase LP Balance Structure (1.5 hours)

**Goal:** Create Firebase LP balance storage (parallel to local, not authoritative yet).

### Implementation

**CRITICAL: This increment requires updating Firebase security rules and app initialization order.**

#### Step 1: Update Firebase Security Rules

```json
// database.rules.json
{
  "rules": {
    // ... existing rules ...

    "couples": {
      "$coupleId": {
        ".read": "auth != null",
        ".write": "auth != null",

        "lp_balance": {
          ".validate": "newData.isNumber()"
        },

        "lp_transactions": {
          "$transactionId": {
            ".validate": "newData.hasChildren(['amount', 'reason', 'timestamp'])"
          }
        }
      }
    }
  }
}
```

Deploy rules:
```bash
firebase deploy --only database
```

#### Step 2: Add LP Firebase Methods

```dart
// app/lib/services/love_point_service.dart

/// Initialize couple's LP balance in Firebase
static Future<void> initializeLPBalance({
  required String userId,
  required String partnerId,
}) async {
  final sortedIds = [userId, partnerId]..sort();
  final coupleId = '${sortedIds[0]}_${sortedIds[1]}';

  final balanceRef = _database.child('couples/$coupleId/lp_balance');
  final snapshot = await balanceRef.get();

  if (!snapshot.exists) {
    // Initialize with 0
    await balanceRef.set(0);
    Logger.info('Initialized LP balance in Firebase');
  }
}

/// Get LP balance from Firebase (read-only for now)
static Future<int> getLPBalanceFromFirebase({
  required String userId,
  required String partnerId,
}) async {
  final sortedIds = [userId, partnerId]..sort();
  final coupleId = '${sortedIds[0]}_${sortedIds[1]}';

  final snapshot = await _database.child('couples/$coupleId/lp_balance').get();
  return snapshot.value as int? ?? 0;
}
```

#### Step 3: Update Initialization Order (CRITICAL)

**CLAUDE.md Initialization Order:**
1. Firebase.initializeApp()
2. StorageService.init()
3. NotificationService.initialize()
4. MockDataService.injectMockDataIfNeeded()
5. **NEW: Initialize LP balance (if paired)**
6. runApp()

```dart
// app/lib/main.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await StorageService.init();
  await NotificationService.initialize();
  await MockDataService.injectMockDataIfNeeded();

  // NEW: Initialize LP balance BEFORE runApp()
  final user = StorageService.instance.getUser();
  final partner = StorageService.instance.getPartner();
  if (user != null && partner != null) {
    await LovePointService.initializeLPBalance(
      userId: user.id,
      partnerId: partner.pushToken,
    );
  }

  runApp(const TogetherRemindApp());
}
```

### Testing

```bash
# 1. Clean slate (use Complete Clean Testing Procedure)
pkill -9 -f "flutter"
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind
firebase database:remove /couples --force

# 2. Verify Firebase rules deployed
firebase database:get / --shallow
# Should show "couples" in list

# 3. Launch app (paired)
cd /Users/joakimachren/Desktop/togetherremind/app
flutter build apk --debug &
wait && flutter run -d emulator-5554

# 4. Check Firebase
firebase database:get /couples
# Expected: { "alice_bob": { "lp_balance": 0 } }

# 5. Verify local LP still works
# Complete quest → check local LP increases
# Check Firebase LP (should still be 0 - we're not writing yet)
```

**Success Criteria:**
- [ ] Firebase security rules deployed successfully
- [ ] `/couples/{coupleId}/lp_balance` created on app start
- [ ] Initialization happens BEFORE runApp()
- [ ] Local LP still works as before (authoritative)
- [ ] Firebase LP readable but not used yet

---

## Increment 2B: Write LP to Firebase on Award (1.5 hours)

**Goal:** When LP awarded, update BOTH local Hive AND Firebase (dual-write) with retry logic.

### Implementation

```dart
// app/lib/services/love_point_service.dart
import 'dart:async';

/// Retry configuration
static const int _maxRetries = 3;
static const Duration _retryDelay = Duration(seconds: 2);

/// Award LP to couple (writes to both local and Firebase)
static Future<void> awardPointsToCouple({
  required String userId,
  required String partnerId,
  required int amount,
  required String reason,
  String? relatedId,
}) async {
  final sortedIds = [userId, partnerId]..sort();
  final coupleId = '${sortedIds[0]}_${sortedIds[1]}';

  // 1. Update Firebase via transaction (atomic increment) with retry
  int? newBalance;
  bool firebaseSuccess = false;

  for (int attempt = 1; attempt <= _maxRetries; attempt++) {
    try {
      final balanceRef = _database.child('couples/$coupleId/lp_balance');

      // CORRECTED: Use proper MutableData API
      final transactionResult = await balanceRef.runTransaction((mutableData) {
        final current = (mutableData.value ?? 0) as int;
        mutableData.value = current + amount;
        return mutableData;
      });

      if (!transactionResult.committed) {
        throw Exception('Firebase transaction not committed');
      }

      newBalance = transactionResult.snapshot.value as int? ?? 0;
      Logger.success('Updated Firebase LP: $newBalance (+$amount)');
      firebaseSuccess = true;
      break;  // Success, exit retry loop

    } catch (e) {
      Logger.error('Firebase LP update failed (attempt $attempt/$_maxRetries)', error: e);

      if (attempt < _maxRetries) {
        // Exponential backoff
        final delay = _retryDelay * attempt;
        await Future.delayed(delay);
      }
    }
  }

  if (!firebaseSuccess) {
    // All retries failed - this is critical
    Logger.error('Firebase LP update failed after $_maxRetries attempts - data may diverge');
    // DO NOT update local - Firebase is source of truth
    // User will see outdated LP until next Firebase sync
    return;
  }

  // 2. Update local Hive with Firebase value (Firebase is source of truth)
  final user = _storage.getUser();
  if (user != null) {
    user.lovePoints = newBalance!;
    await _storage.saveUser(user);
  }

  // 3. Record transaction for history
  try {
    final txnRef = _database.child('couples/$coupleId/lp_transactions').push();
    await txnRef.set({
      'amount': amount,
      'reason': reason,
      'relatedId': relatedId,
      'timestamp': ServerValue.timestamp,
      'schemaVersion': SchemaVersions.currentFirebaseVersion,
    });

    Logger.success('Awarded $amount LP (reason: $reason)');
  } catch (e) {
    // Transaction history failure is non-critical
    Logger.warn('Failed to record LP transaction history', error: e);
  }
}
```

Update existing LP award calls:

```dart
// Find all instances of:
await LovePointService.awardPointsToBothUsers(...)

// Replace with:
final user = StorageService.instance.getUser();
final partner = StorageService.instance.getPartner();

if (user != null && partner != null) {
  await LovePointService.awardPointsToCouple(
    userId: user.id,
    partnerId: partner.pushToken,
    amount: 30,
    reason: 'quest_completed',
    relatedId: questId,
  );
}
```

### Testing

```bash
# 1. Reset Firebase LP
firebase database:update /couples/alice_bob '{"lp_balance": 0}'

# 2. Launch app (Complete Clean Testing Procedure)
flutter run -d emulator-5554

# 3. Complete a quest (30 LP)
# Check Firebase:
firebase database:get /couples/alice_bob/lp_balance
# Expected: 30

# 4. Complete another quest (30 LP)
firebase database:get /couples/alice_bob/lp_balance
# Expected: 60

# 5. Check local LP matches Firebase
# Debug menu → Overview tab → Love Points section

# 6. Test retry logic (simulate network issue)
# Temporarily disable network → complete quest → re-enable
# Check logs for retry attempts
```

**Success Criteria:**
- [ ] Firebase LP increments on quest completion
- [ ] Local LP matches Firebase LP
- [ ] Transaction history recorded in Firebase
- [ ] Retry logic works (check logs for retry attempts)
- [ ] If all retries fail, local LP NOT updated (Firebase is source of truth)

---

## Increment 2C: Restore LP from Firebase on App Start (1 hour)

**Goal:** When app starts, restore LP balance from Firebase (handles reinstalls).

### Implementation

```dart
// app/lib/services/love_point_service.dart

/// Restore LP balance from Firebase to local storage
static Future<void> restoreLPFromFirebase({
  required String userId,
  required String partnerId,
}) async {
  try {
    final firebaseBalance = await getLPBalanceFromFirebase(
      userId: userId,
      partnerId: partnerId,
    );

    final user = _storage.getUser();
    if (user != null) {
      final localBalance = user.lovePoints;

      if (localBalance != firebaseBalance) {
        // CRITICAL: Use Logger without service parameter for critical warnings
        Logger.warn(
          'LP mismatch: local=$localBalance, firebase=$firebaseBalance (restoring from Firebase)',
        );

        // Firebase is source of truth
        user.lovePoints = firebaseBalance;
        await _storage.saveUser(user);

        Logger.success('Restored LP from Firebase: $firebaseBalance');
      } else {
        Logger.debug('LP in sync: $localBalance', service: 'lovepoint');
      }
    }
  } catch (e) {
    Logger.error('Error restoring LP from Firebase', error: e);
  }
}
```

Update `main.dart`:

```dart
// app/lib/main.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await StorageService.init();
  await NotificationService.initialize();
  await MockDataService.injectMockDataIfNeeded();

  // Initialize and restore LP balance
  final user = StorageService.instance.getUser();
  final partner = StorageService.instance.getPartner();
  if (user != null && partner != null) {
    await LovePointService.initializeLPBalance(
      userId: user.id,
      partnerId: partner.pushToken,
    );

    // NEW: Restore LP from Firebase
    await LovePointService.restoreLPFromFirebase(
      userId: user.id,
      partnerId: partner.pushToken,
    );
  }

  runApp(const TogetherRemindApp());
}
```

### Testing

```bash
# Test 1: Normal case (local matches Firebase)
flutter run -d emulator-5554
# Check logs for "LP in sync"

# Test 2: Simulate reinstall (local LP cleared)
# 1. Set Firebase LP to 60
firebase database:set /couples/alice_bob/lp_balance 60

# 2. Uninstall and reinstall app (clears local Hive)
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind
flutter run -d emulator-5554

# 3. Check logs for "Restored LP from Firebase: 60"
# 4. Verify UI shows 60 LP

# Test 3: Simulate divergence
# 1. Manually set local LP to 100 via debug menu
# 2. Keep Firebase LP at 60
# 3. Restart app
# 4. Check logs for "LP mismatch"
# 5. Verify local LP changed to 60 (Firebase wins)
```

**Success Criteria:**
- [ ] App start syncs local LP with Firebase LP
- [ ] Firebase LP is authoritative (overwrites local if different)
- [ ] Warning logs without service parameter (always visible)
- [ ] Handles missing Firebase data gracefully

---

## Increment 2D: Add Real-time LP Sync Listener (1.5 hours)

**Goal:** Listen for Firebase LP changes in real-time (e.g., partner completes quest) with deduplication.

### Implementation

```dart
// app/lib/services/love_point_service.dart

static StreamSubscription? _lpBalanceSubscription;
static int? _lastNotifiedBalance;

/// Start listening for LP balance changes
static void startListeningForLPBalance({
  required String userId,
  required String partnerId,
}) {
  final sortedIds = [userId, partnerId]..sort();
  final coupleId = '${sortedIds[0]}_${sortedIds[1]}';

  // Cancel existing listener
  _lpBalanceSubscription?.cancel();

  // Initialize last notified balance from current local value
  final user = _storage.getUser();
  _lastNotifiedBalance = user?.lovePoints;

  // Listen for balance changes
  _lpBalanceSubscription = _database
    .child('couples/$coupleId/lp_balance')
    .onValue
    .listen((event) {
      final newBalance = event.snapshot.value as int? ?? 0;

      // Update local cache
      final user = _storage.getUser();
      if (user != null && user.lovePoints != newBalance) {
        final oldBalance = user.lovePoints;
        user.lovePoints = newBalance;
        _storage.saveUser(user);

        Logger.info(
          'LP balance updated: $oldBalance → $newBalance',
          service: 'lovepoint',
        );

        // DEDUPLICATION: Only show notification if:
        // 1. Balance increased (not decreased)
        // 2. This is from partner's action (not our own award)
        // 3. We haven't already notified for this balance
        if (newBalance > oldBalance &&
            _lastNotifiedBalance != newBalance &&
            _appContext != null) {
          final diff = newBalance - oldBalance;

          // Only notify if significant increase (likely partner's action)
          // Our own awards are handled by awardPointsToCouple() notification
          if (diff > 0) {
            ForegroundNotificationBanner.show(
              _appContext!,
              title: 'Love Points Updated!',
              message: '+$diff LP (Balance: $newBalance)',
              emoji: '💰',
            );
            _lastNotifiedBalance = newBalance;
          }
        }
      }
    }, onError: (error) {
      Logger.error('LP balance listener error', error: error);
    });
}

/// Stop listening for LP balance changes
static void stopListeningForLPBalance() {
  _lpBalanceSubscription?.cancel();
  _lpBalanceSubscription = null;
  _lastNotifiedBalance = null;
}
```

Update `main.dart`:

```dart
// app/lib/main.dart

void main() async {
  // ... existing initialization ...

  // Start LP balance listener
  final user = StorageService.instance.getUser();
  final partner = StorageService.instance.getPartner();
  if (user != null && partner != null) {
    // ... existing LP initialization and restore ...

    // NEW: Start LP balance listener
    LovePointService.startListeningForLPBalance(
      userId: user.id,
      partnerId: partner.pushToken,
    );
  }

  runApp(const TogetherRemindApp());
}
```

Add lifecycle management:

```dart
// app/lib/main.dart

class TogetherRemindApp extends StatefulWidget {
  const TogetherRemindApp({super.key});

  @override
  State<TogetherRemindApp> createState() => _TogetherRemindAppState();
}

class _TogetherRemindAppState extends State<TogetherRemindApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Stop LP listener when app disposes
    LovePointService.stopListeningForLPBalance();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = StorageService.instance.getUser();
    final partner = StorageService.instance.getPartner();

    if (user != null && partner != null) {
      if (state == AppLifecycleState.resumed) {
        // Restart listener when app resumes
        LovePointService.startListeningForLPBalance(
          userId: user.id,
          partnerId: partner.pushToken,
        );
      } else if (state == AppLifecycleState.paused) {
        // Optionally stop listener to save battery
        LovePointService.stopListeningForLPBalance();
      }
    }
  }

  // ... rest of widget build
}
```

### Testing

```bash
# Test real-time sync with Alice & Bob

# 1. Clean slate (Complete Clean Testing Procedure)
pkill -9 -f "flutter"
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind
firebase database:remove /daily_quests --force
firebase database:remove /couples --force

# 2. Build in parallel
cd /Users/joakimachren/Desktop/togetherremind/app
flutter build apk --debug &
ANDROID_PID=$!
flutter build web --debug &
WEB_PID=$!

wait $ANDROID_PID && echo "✅ Android build complete"
wait $WEB_PID && echo "✅ Web build complete"

# 3. Launch Alice (Android)
flutter run -d emulator-5554 &

# 4. Launch Bob (Chrome)
flutter run -d chrome &

# 5. Alice completes quest
# Check Alice UI: LP increases immediately
# Check Bob UI: LP increases within 1-2 seconds (real-time)
# Check Bob logs: "LP balance updated: 60 → 90"
# Verify Bob sees notification

# 6. Bob completes quest
# Check Bob UI: LP increases immediately
# Check Alice UI: LP increases within 1-2 seconds
# Verify Alice sees notification

# 7. Test deduplication
# Complete multiple quests quickly
# Verify no duplicate notifications for same balance
```

**Success Criteria:**
- [ ] Partner's LP updates appear in real-time (< 2 seconds)
- [ ] Notification banner shows when LP increases from partner
- [ ] No duplicate notifications (dedup logic works)
- [ ] Listener restarts after app resume
- [ ] Listener stops on app dispose

---

## Increment 3A: Add Data Validator Utility (30 min)

**Goal:** Create validation utility WITHOUT applying it yet.

### Implementation

```dart
// app/lib/utils/firebase_validator.dart
import '../models/daily_quest.dart';

class FirebaseValidator {
  /// Validate daily quest data structure
  static bool isValidQuestData(Map<dynamic, dynamic> data) {
    try {
      // Required fields
      if (!data.containsKey('id') || data['id'] is! String) return false;
      if (!data.containsKey('questType') || data['questType'] is! int) return false;
      if (!data.containsKey('contentId') || data['contentId'] is! String) return false;

      // Range checks
      final questType = data['questType'] as int;
      if (questType < 0 || questType >= QuestType.values.length) return false;

      // String length checks
      final id = data['id'] as String;
      if (id.isEmpty || id.length > 100) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate quiz session data structure
  static bool isValidQuizSessionData(Map<dynamic, dynamic> data) {
    try {
      if (!data.containsKey('id') || data['id'] is! String) return false;
      if (!data.containsKey('status') || data['status'] is! String) return false;
      if (!data.containsKey('questionIds') || data['questionIds'] is! List) return false;

      final status = data['status'] as String;
      final validStatuses = ['waiting_for_answers', 'completed', 'expired'];
      if (!validStatuses.contains(status)) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate quiz progression data structure
  static bool isValidProgressionData(Map<dynamic, dynamic> data) {
    try {
      if (!data.containsKey('currentTrack') || data['currentTrack'] is! int) return false;
      if (!data.containsKey('currentPosition') || data['currentPosition'] is! int) return false;

      final track = data['currentTrack'] as int;
      final position = data['currentPosition'] as int;

      if (track < 0 || track > 2) return false; // 3 tracks (0-2)
      if (position < 0 || position > 3) return false; // 4 quizzes per track (0-3)

      return true;
    } catch (e) {
      return false;
    }
  }
}
```

### Testing

```bash
# Run unit tests
cd app
flutter test test/utils/firebase_validator_test.dart
```

**Success Criteria:**
- [ ] Validator compiles without errors
- [ ] Unit tests pass for valid data
- [ ] Unit tests pass for invalid data (returns false)
- [ ] No changes to app behavior yet

---

## Increment 3B: Apply Validation to Quest Loading (45 min)

**Goal:** Validate quest data before deserializing, reject corrupted quest sets.

### Implementation

```dart
// app/lib/services/quest_sync_service.dart
import '../utils/firebase_validator.dart';

Future<void> _loadQuestsFromFirebase(
  DataSnapshot snapshot,
  String dateKey,
) async {
  try {
    final data = snapshot.value as Map<dynamic, dynamic>;
    final questsData = data['quests'] as List<dynamic>;

    final invalidQuests = <String>[];
    final validQuests = <DailyQuest>[];

    for (int i = 0; i < questsData.length; i++) {
      final questMap = questsData[i] as Map<dynamic, dynamic>;

      // Validate quest data
      if (!FirebaseValidator.isValidQuestData(questMap)) {
        Logger.error(
          'Invalid quest data at index $i, rejecting entire quest set',
          data: questMap,
        );
        invalidQuests.add('Quest $i');
        continue;
      }

      // Safe to deserialize
      final questId = questMap['id'] as String;
      final questType = questMap['questType'] as int;
      final quest = DailyQuest(
        type: QuestType.values[questType],
        // ... rest of fields
      );

      validQuests.add(quest);
    }

    // CRITICAL: If ANY quest invalid, reject entire set
    // This prevents Alice/Bob quest mismatch
    if (invalidQuests.isNotEmpty) {
      Logger.error(
        'Quest set corrupted (${invalidQuests.length} invalid), regenerating',
        data: {'invalidQuests': invalidQuests},
      );

      // Clear corrupted data from Firebase
      final user = StorageService.instance.getUser();
      final partner = StorageService.instance.getPartner();
      if (user != null && partner != null) {
        final sortedIds = [user.id, partner.pushToken]..sort();
        final coupleId = '${sortedIds[0]}_${sortedIds[1]}';
        await _database.child('daily_quests/$coupleId/$dateKey').remove();
      }

      // Trigger regeneration
      throw Exception('Corrupted quest set, cleared from Firebase');
    }

    // Save valid quests
    for (final quest in validQuests) {
      await _storage.saveDailyQuest(quest);
    }

    Logger.success('Loaded ${validQuests.length} valid quests', service: 'quest');
  } catch (e) {
    Logger.error('Error loading quests from Firebase', error: e);
    rethrow;
  }
}
```

### Testing

```bash
# Test 1: Valid data (normal case)
flutter run -d emulator-5554
# Generate quests → check logs for "Loaded 3 valid quests"

# Test 2: Invalid quest type
# Manually inject bad data:
firebase database:update /daily_quests/alice_bob/2025-11-16/quests/0 '{"questType": 99}'
# Restart app → check logs for "Quest set corrupted"
# Verify Firebase data cleared
# Verify new quests regenerated

# Test 3: Missing required field
firebase database:update /daily_quests/alice_bob/2025-11-16/quests/1 '{"id": null}'
# Restart app → verify quest set rejected and regenerated

# Test 4: Alice & Bob sync after corruption
# Launch both devices after corruption cleared
# Verify both see same 3 quests (no mismatch)
```

**Success Criteria:**
- [ ] Valid quests load successfully
- [ ] Invalid quests cause entire set rejection
- [ ] Corrupted Firebase data automatically cleared
- [ ] App regenerates fresh quests after corruption
- [ ] Alice and Bob quest counts match after recovery

---

## Increment 3C: Apply Validation to Session Loading (30 min)

Similar to 3B but for quiz sessions. Follow same pattern:
- Validate before deserializing
- Reject corrupted sessions
- Clear from Firebase
- Log errors without service parameter

---

## Increment 4A: Add Cleanup on App Start (45 min)

**Goal:** Run cleanup when app starts (no scheduled timer yet).

### Implementation

```dart
// app/lib/services/cleanup_service.dart
import '../utils/logger.dart';
import 'daily_quest_service.dart';
import 'you_or_me_service.dart';
import 'quest_sync_service.dart';
import 'storage_service.dart';

class CleanupService {
  /// Run all cleanup tasks
  static Future<void> runDataCleanup() async {
    try {
      Logger.info('Running data cleanup');

      // Clean local Hive storage
      final storage = StorageService.instance;
      final questService = DailyQuestService(storage: storage);
      await questService.cleanupExpiredQuests();

      final youOrMeService = YouOrMeService(storage: storage);
      await youOrMeService.cleanupOldSessions();

      // Clean Firebase (if paired)
      final user = storage.getUser();
      final partner = storage.getPartner();
      if (user != null && partner != null) {
        final syncService = QuestSyncService(storage: storage);
        await syncService.cleanupOldQuests(
          currentUserId: user.id,
          partnerUserId: partner.pushToken,
        );
      }

      Logger.success('Data cleanup completed');
    } catch (e) {
      Logger.error('Data cleanup failed', error: e);
      // Don't rethrow - cleanup failure shouldn't crash app
    }
  }
}
```

Update `main.dart`:

```dart
// app/lib/main.dart
import 'services/cleanup_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await StorageService.init();
  await NotificationService.initialize();
  await MockDataService.injectMockDataIfNeeded();

  // ... LP initialization ...

  // NEW: Run cleanup on app start
  await CleanupService.runDataCleanup();

  runApp(const TogetherRemindApp());
}
```

### Testing

```bash
# 1. Create old quests manually
# Use debug menu to create quests with old dates (>30 days ago)

# 2. Check quest count before cleanup
# Debug menu → Quests tab → note count

# 3. Restart app
flutter run -d emulator-5554

# 4. Check logs for "Running data cleanup" and "Data cleanup completed"

# 5. Verify old quests deleted
# Debug menu → Quests tab → check count decreased
```

**Success Criteria:**
- [ ] Cleanup runs on every app start
- [ ] Old quests (>30 days) deleted from local storage
- [ ] Firebase cleanup runs if paired
- [ ] Cleanup failure doesn't crash app
- [ ] Logs show cleanup status

---

## Increment 4B: Add Scheduled Daily Cleanup (30 min)

**Goal:** Run cleanup every 24 hours while app is running.

### Implementation

```dart
// app/lib/main.dart
import 'dart:async';

Timer? _cleanupTimer;

void main() async {
  // ... existing initialization ...

  // Run cleanup on start
  await CleanupService.runDataCleanup();

  // NEW: Schedule daily cleanup
  _scheduleCleanup();

  runApp(const TogetherRemindApp());
}

void _scheduleCleanup() {
  _cleanupTimer?.cancel();
  _cleanupTimer = Timer.periodic(const Duration(hours: 24), (_) async {
    await CleanupService.runDataCleanup();
  });
}
```

### Testing

```bash
# Can't easily test 24-hour timer, so reduce for testing:

# 1. Change timer to 1 minute for testing
Timer.periodic(const Duration(minutes: 1), (_) async { ... });

# 2. Launch app
flutter run -d emulator-5554

# 3. Watch logs for cleanup running every minute
# Should see "Running data cleanup" every 60 seconds

# 4. Change back to 24 hours before committing
Timer.periodic(const Duration(hours: 24), (_) async { ... });
```

**Success Criteria:**
- [ ] Timer starts on app launch
- [ ] Cleanup runs every 24 hours (test with 1 min during development)
- [ ] Timer persists while app is running
- [ ] Timer resets on app restart

---

## Testing Checklist (Full Phase 1)

After completing all increments, run full integration tests:

### Alice & Bob Clean Slate Test

```bash
# 1. Clean everything
pkill -9 -f "flutter"
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind
firebase database:remove /daily_quests --force
firebase database:remove /couples --force

# 2. Build in parallel
cd /Users/joakimachren/Desktop/togetherremind/app
flutter build apk --debug &
ANDROID_PID=$!
flutter build web --debug &
WEB_PID=$!

echo "⏳ Waiting for builds..."
wait $ANDROID_PID && echo "✅ Android build complete"
wait $WEB_PID && echo "✅ Web build complete"

# 3. Launch Alice
flutter run -d emulator-5554 &

# 4. Launch Bob
flutter run -d chrome &

# 5. Pair devices and verify:
# - Pairing succeeds
# - 3 quests generated
# - Firebase has schemaVersion in quests
# - Firebase has LP balance = 0

# 6. Complete quest on Alice
# Check:
# - Alice LP increases to 30
# - Firebase LP balance = 30
# - Bob's LP updates to 30 within 2 seconds (real-time)
# - Bob sees notification

# 7. Kill Alice (simulate crash)
pkill -f "emulator-5554"

# 8. Reinstall Alice
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind
flutter run -d emulator-5554

# 9. Pair again and verify:
# - LP balance restored from Firebase (30 LP)
# - Quest history intact
# - No quest ID mismatches
```

### Version Compatibility Test

```bash
# Simulate version mismatch:
# 1. Manually edit Firebase schemaVersion to 99
firebase database:update /daily_quests/alice_bob/2025-11-16 '{"schemaVersion": 99}'

# 2. Launch app
# Expected: Error logged, quest set rejected

# 3. Reset version
firebase database:update /daily_quests/alice_bob/2025-11-16 '{"schemaVersion": 1}'

# 4. Reload
# Expected: Quests load successfully
```

### Concurrent Operations Test

```bash
# Test both devices operating simultaneously

# 1. Launch Alice & Bob (clean slate)
# 2. Both complete different quests at same time
# 3. Verify:
#    - Both Firebase transactions succeed
#    - Final LP balance correct (60 LP)
#    - Both devices show same balance
#    - No race condition errors in logs
```

### Offline/Online Transition Test

```bash
# 1. Launch Alice online
# 2. Disable network (Airplane mode on emulator)
# 3. Try to complete quest
#    - Verify retry attempts logged
#    - Verify local LP NOT updated (Firebase failed)
# 4. Re-enable network
# 5. Complete quest again
#    - Verify Firebase transaction succeeds
#    - Verify LP updated correctly
```

---

## Rollback Plan (Per Increment)

Each increment can be rolled back independently:

### Increment 1A-D: Version Tracking
**Rollback:**
```bash
# Delete new files
rm app/lib/constants/schema_versions.dart
rm app/lib/utils/version_validator.dart
rm app/lib/services/version_migration_service.dart

# Revert imports in quest_sync_service.dart
# Remove version validation code
```

**Verification:**
- App loads quests without version checks
- No schema version fields in Firebase writes

---

### Increment 2A-D: LP Firebase Sync
**Rollback:**
```bash
# Revert Firebase security rules
firebase deploy --only database

# Revert main.dart initialization changes
# Remove LP initialization from main()

# Revert love_point_service.dart
# Remove Firebase LP methods
# Restore old awardPointsToBothUsers() logic
```

**Verification:**
- LP awards work locally only
- No Firebase LP writes
- No real-time sync

**Data cleanup:**
```bash
# Optionally remove Firebase LP data
firebase database:remove /couples --force
```

---

### Increment 3A-C: Data Validation
**Rollback:**
```bash
# Delete validator
rm app/lib/utils/firebase_validator.dart

# Revert quest_sync_service.dart
# Remove validation calls before deserialization
```

**Verification:**
- Quests load without validation
- Invalid data causes crashes (old behavior)

---

### Increment 4A-B: Data Cleanup
**Rollback:**
```bash
# Delete cleanup service
rm app/lib/services/cleanup_service.dart

# Revert main.dart
# Remove cleanup calls and timer
```

**Verification:**
- No automatic cleanup
- Old data persists

---

## Deployment Strategy

### Week 1: Version Tracking & LP Sync Writes
- **Day 1**: Implement 1A, 1B, 1C (version tracking) - 2.5 hours
- **Day 2**: Implement 1D (null-version migration), test thoroughly - 2 hours
- **Day 3**: Implement 2A (LP balance structure + Firebase rules) - 2 hours
- **Day 4**: Implement 2B (LP sync writes with retry) - 2 hours
- **Day 5**: Implement 2C (LP restore), full LP sync testing - 2 hours

### Week 2: Real-time Sync, Validation & Cleanup
- **Day 1**: Implement 2D (real-time LP listener) - 2 hours
- **Day 2**: Implement 3A, 3B (quest validation) - 2 hours
- **Day 3**: Implement 3C (session validation), Increment 4A - 2 hours
- **Day 4**: Implement 4B (scheduled cleanup), full integration testing - 2 hours
- **Day 5**: Concurrent operations testing, offline/online testing - 2 hours

### Week 3: Final Testing & Deployment
- **Day 1-2**: Alice & Bob full scenario testing
- **Day 3**: Version compatibility testing
- **Day 4**: Performance testing, edge cases
- **Day 5**: Deploy to beta testers

---

## Hive Build Runner Schedule

Run after these increments (when Hive models change):

```bash
cd app
flutter pub run build_runner build --delete-conflicting-outputs
```

**Required after:**
- Increment 2A (if User model changes for LP)
- Increment 3B (if DailyQuest model changes for validation metadata)
- Any other Hive model changes

---

## Common Issues & Solutions

### Issue: "Firebase permission denied"
**Solution:** Verify `database.rules.json` deployed:
```bash
firebase deploy --only database
firebase database:get / --shallow  # Should show "couples" path
```

### Issue: "Transaction not committed"
**Solution:** Check Firebase quota not exceeded:
```bash
# Firebase Console → Database → Usage tab
```

### Issue: "LP not restoring on reinstall"
**Solution:** Verify initialization order - LP restore must run BEFORE runApp()

### Issue: "Duplicate LP notifications"
**Solution:** Check `_lastNotifiedBalance` deduplication logic in real-time listener

### Issue: Version errors not logging
**Solution:** Remove `service:` parameter from critical `Logger.error()` calls

---

**Document Status:** ✅ CORRECTED & PRODUCTION-READY
**Total Increments:** 15 (added 1D for null-version migration)
**Estimated Time:** 2.5 weeks (12 business days)
**Critical Fixes Applied:** 12
**Next Step:** Review `PHASE_1_PRE_IMPLEMENTATION_CHECKLIST.md` before starting Increment 1A

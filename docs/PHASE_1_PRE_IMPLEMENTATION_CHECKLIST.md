# Phase 1: Pre-Implementation Checklist

**CRITICAL: Complete ALL items before starting Increment 1A**

This checklist ensures you understand the 8 critical fixes applied to the original Phase 1 plan and prevents implementation errors.

---

## ✅ 1. Firebase RTDB Transaction API Understanding

### Verify Understanding

Read the Firebase RTDB Transaction documentation:
```bash
# Open in browser
https://firebase.google.com/docs/database/flutter/read-and-write#save_data_as_transactions
```

### Key Points to Verify

- [ ] **Understood:** Transactions use `MutableData` objects, NOT `Transaction.success()`
- [ ] **Understood:** Correct pattern:
  ```dart
  balanceRef.runTransaction((mutableData) {
    final current = (mutableData.value ?? 0) as int;
    mutableData.value = current + amount;
    return mutableData;
  });
  ```
- [ ] **Understood:** Incorrect pattern (will NOT compile):
  ```dart
  balanceRef.runTransaction((currentValue) {
    return Transaction.success(currentValue + amount); // ❌ WRONG
  });
  ```

### Verification Test

Write a simple test transaction:
```dart
// Test file: app/test/firebase_transaction_test.dart
test('Firebase transaction API', () async {
  final ref = FirebaseDatabase.instance.ref('test_counter');

  final result = await ref.runTransaction((mutableData) {
    final current = (mutableData.value ?? 0) as int;
    mutableData.value = current + 1;
    return mutableData;
  });

  expect(result.committed, true);
  expect(result.snapshot.value, isA<int>());
});
```

**Status:**
- [ ] Documentation read and understood
- [ ] Test written and passing
- [ ] Ready to implement Increment 2B

---

## ✅ 2. CLAUDE.md Initialization Order

### Review Required Section

Read CLAUDE.md section 1 (lines 35-48):
```bash
cat CLAUDE.md | sed -n '35,48p'
```

### Strict Initialization Order

**MUST FOLLOW THIS ORDER:**

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `Firebase.initializeApp()`
3. `StorageService.init()`
4. `NotificationService.initialize()`
5. `MockDataService.injectMockDataIfNeeded()`
6. **NEW:** Love Point initialization (if paired)
7. **NEW:** Love Point restore from Firebase (if paired)
8. **NEW:** Start LP balance listener (if paired)
9. **NEW:** Data cleanup
10. `runApp()`

### Critical Understanding

- [ ] **Understood:** LP initialization MUST happen BEFORE `runApp()`
- [ ] **Understood:** `_initializeDailyQuests()` runs AFTER `runApp()` (too late for critical init)
- [ ] **Understood:** Race conditions occur if LP init happens after UI renders

### Verification

Locate current initialization in main.dart:
```bash
grep -n "void main()" app/lib/main.dart
```

Check where `_initializeDailyQuests()` is called:
```bash
grep -n "_initializeDailyQuests" app/lib/main.dart
```

**Status:**
- [ ] CLAUDE.md section reviewed
- [ ] Current main.dart initialization order understood
- [ ] Ready to modify main.dart in Increment 2A

---

## ✅ 3. Firebase Security Rules

### Current Rules Review

Check existing `database.rules.json`:
```bash
cat database.rules.json | jq
```

### New Rules Required

Increment 2A adds `/couples` path. Required rules:
```json
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
```

### Deployment Command

```bash
firebase deploy --only database
```

### Verification Command

```bash
firebase database:get / --shallow
# Should show "couples" in output after deployment
```

**Status:**
- [ ] Current rules reviewed
- [ ] New rules structure understood
- [ ] Deployment command ready
- [ ] Verification method known

---

## ✅ 4. Logger Service Verbosity Control

### Review Logger Configuration

Read CLAUDE.md section 10 (lines 209-255):
```bash
cat CLAUDE.md | sed -n '209,255p'
```

### Check Current Service Configuration

```bash
grep -A 30 "_serviceVerbosity" app/lib/utils/logger.dart
```

### Critical Understanding

- [ ] **Understood:** Services are disabled by default
- [ ] **Understood:** Logs with `service:` parameter only show if service enabled
- [ ] **Understood:** Critical errors should use `Logger.error()` WITHOUT `service:` parameter
- [ ] **Understood:** Version validation errors must always log (bypass verbosity)

### Services to Enable for Phase 1

Before testing each increment, enable:
```dart
// app/lib/utils/logger.dart
static final Map<String, bool> _serviceVerbosity = {
  'quest': true,      // For Increments 1B, 1C, 3B
  'quiz': true,       // For Increment 1B
  'lovepoint': true,  // For Increments 2A-2D
  // Keep others false
};
```

### Pattern to Use

**Critical errors (always log):**
```dart
Logger.error('Incompatible Firebase version', data: {...});  // ✅ No service parameter
```

**Debug info (only if service enabled):**
```dart
Logger.debug('LP in sync: 60', service: 'lovepoint');  // ✅ Respects config
```

**Status:**
- [ ] CLAUDE.md section reviewed
- [ ] Current logger configuration checked
- [ ] Critical vs debug pattern understood
- [ ] Ready to enable services during testing

---

## ✅ 5. Hive Build Runner Workflow

### Review Requirement

Read CLAUDE.md section 2 (lines 51-68):
```bash
cat CLAUDE.md | sed -n '51,68p'
```

### When to Run Build Runner

After adding/modifying `@HiveField` annotations:
```bash
cd app
flutter pub run build_runner build --delete-conflicting-outputs
```

### Increments Requiring Build Runner

- [ ] **Increment 2A** (if User model changes for LP field)
- [ ] **Increment 3B** (if DailyQuest model changes)
- [ ] **After any `@HiveField` additions**

### Verification

Check for `*.g.dart` files:
```bash
find app/lib/models -name "*.g.dart"
```

### What Happens if Skipped

- Compilation errors: "type 'Null' is not a subtype"
- Missing adapters
- Hive read/write failures

**Status:**
- [ ] CLAUDE.md section reviewed
- [ ] Build runner command ready
- [ ] Increments requiring it identified
- [ ] Consequences of skipping understood

---

## ✅ 6. Complete Clean Testing Procedure

### Review Procedure

Read CLAUDE.md section "Complete Clean Testing Procedure" (lines 261-373):
```bash
cat CLAUDE.md | sed -n '261,373p'
```

### Full Cleanup Commands

```bash
# 1. Kill all Flutter processes
pkill -9 -f "flutter"

# 2. Uninstall Android app (clears Hive)
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind

# 3. Clean Firebase
firebase database:remove /daily_quests --force
firebase database:remove /couples --force
firebase database:remove /quiz_sessions --force

# 4. Build in parallel
cd /Users/joakimachren/Desktop/togetherremind/app
flutter build apk --debug &
ANDROID_PID=$!
flutter build web --debug &
WEB_PID=$!

wait $ANDROID_PID && echo "✅ Android build complete"
wait $WEB_PID && echo "✅ Web build complete"

# 5. Launch Alice then Bob
flutter run -d emulator-5554 &
flutter run -d chrome &
```

### Why Each Step Matters

- [ ] **Understood:** `pkill` prevents old processes interfering
- [ ] **Understood:** `adb uninstall` clears Hive storage (fresh install)
- [ ] **Understood:** Firebase cleanup ensures first device generates, second loads
- [ ] **Understood:** Parallel builds save ~10-15 seconds
- [ ] **Understood:** Launch order matters (Alice generates, Bob loads)

### When to Use

- [ ] Testing Increment 2C (LP restore - requires fresh install)
- [ ] Testing Increment 3B (quest validation after corruption)
- [ ] Any cross-device sync testing
- [ ] Verifying fresh install scenarios

**Status:**
- [ ] CLAUDE.md procedure reviewed
- [ ] All commands understood
- [ ] Rationale for each step clear
- [ ] Ready to use for testing

---

## ✅ 7. Listener Memory Management

### Pattern Required

```dart
// Declare subscription
static StreamSubscription? _lpBalanceSubscription;

// Start listening
static void startListeningForLPBalance(...) {
  _lpBalanceSubscription?.cancel();  // Cancel existing
  _lpBalanceSubscription = _database.child(...).onValue.listen(...);
}

// CRITICAL: Stop listening
static void stopListeningForLPBalance() {
  _lpBalanceSubscription?.cancel();
  _lpBalanceSubscription = null;
}
```

### Lifecycle Integration Required

```dart
class _TogetherRemindAppState extends State<TogetherRemindApp> with WidgetsBindingObserver {
  @override
  void dispose() {
    LovePointService.stopListeningForLPBalance();  // ✅ MUST CALL
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      LovePointService.stopListeningForLPBalance();  // ✅ Save battery
    } else if (state == AppLifecycleState.resumed) {
      LovePointService.startListeningForLPBalance(...);  // ✅ Reconnect
    }
  }
}
```

### Critical Understanding

- [ ] **Understood:** Listeners persist across app lifecycle without disposal
- [ ] **Understood:** Multiple listeners created if not cancelled
- [ ] **Understood:** Memory leak occurs without proper cleanup
- [ ] **Understood:** `dispose()` and `didChangeAppLifecycleState()` both needed

**Status:**
- [ ] Listener pattern understood
- [ ] Lifecycle integration pattern clear
- [ ] Ready to implement in Increment 2D

---

## ✅ 8. LP Notification Deduplication

### Problem

Without deduplication:
1. User completes quest → sees notification
2. Firebase LP updates → real-time listener fires → sees SECOND notification

### Solution

```dart
static int? _lastNotifiedBalance;

// In listener
if (newBalance > oldBalance &&
    _lastNotifiedBalance != newBalance &&  // ✅ Dedup check
    _appContext != null) {
  final diff = newBalance - oldBalance;

  ForegroundNotificationBanner.show(...);
  _lastNotifiedBalance = newBalance;  // ✅ Track what we showed
}
```

### Critical Understanding

- [ ] **Understood:** Own awards handled by `awardPointsToCouple()` notification
- [ ] **Understood:** Listener only notifies for partner's awards
- [ ] **Understood:** `_lastNotifiedBalance` prevents duplicate for same balance
- [ ] **Understood:** Must initialize from current LP when starting listener

**Status:**
- [ ] Deduplication pattern understood
- [ ] Distinction between own/partner awards clear
- [ ] Ready to implement in Increment 2D

---

## ✅ 9. Data Validation Strategy

### Pattern: Reject Entire Set, Not Individual Items

**Why:**
```
Alice: Generates 3 quests → Firebase
Firebase: Quest 2 corrupted
Bob: Loads quests → sees 2 quests (skips #2)
Result: Alice sees 3, Bob sees 2 → MISMATCH ❌
```

**Solution:**
```dart
if (invalidQuests.isNotEmpty) {
  // Clear corrupted data
  await _database.child('daily_quests/$coupleId/$dateKey').remove();
  // Trigger regeneration
  throw Exception('Corrupted quest set, cleared from Firebase');
}
```

### Critical Understanding

- [ ] **Understood:** Partial success creates Alice/Bob mismatch
- [ ] **Understood:** All-or-nothing prevents divergence
- [ ] **Understood:** Corrupted data auto-clears and regenerates
- [ ] **Understood:** Both devices eventually see same count

**Status:**
- [ ] Validation strategy understood
- [ ] Rejection pattern clear
- [ ] Ready to implement Increment 3B

---

## ✅ 10. Exponential Backoff Retry Logic

### Pattern for Firebase Operations

```dart
for (int attempt = 1; attempt <= _maxRetries; attempt++) {
  try {
    // Firebase operation
    break;  // Success, exit loop
  } catch (e) {
    Logger.error('Operation failed (attempt $attempt/$_maxRetries)', error: e);

    if (attempt < _maxRetries) {
      final delay = _retryDelay * attempt;  // ✅ Exponential backoff
      await Future.delayed(delay);
    }
  }
}

if (!firebaseSuccess) {
  // All retries failed - handle gracefully
  Logger.error('Operation failed after $_maxRetries attempts');
  // DO NOT update local if Firebase is source of truth
  return;
}
```

### Why NOT Fallback to Local

**Problem with fallback:**
```dart
catch (e) {
  user.lovePoints += amount;  // ❌ Creates divergence
  await _storage.saveUser(user);
}
```

**Result:**
- Local: 30 LP
- Firebase: 0 LP
- Next sync: Mismatch, unclear which is correct

**Correct approach:**
- Firebase is source of truth
- If Firebase fails, local NOT updated
- User sees outdated LP until Firebase succeeds

### Critical Understanding

- [ ] **Understood:** Exponential backoff prevents Firebase throttling
- [ ] **Understood:** Local fallback creates divergence
- [ ] **Understood:** Firebase is authoritative source
- [ ] **Understood:** Retry logic in Increment 2B

**Status:**
- [ ] Retry pattern understood
- [ ] Source of truth principle clear
- [ ] Ready to implement retry logic

---

## 📋 Final Pre-Implementation Checklist

### Knowledge Verification

- [ ] All 10 sections above completed
- [ ] All sub-checkboxes marked
- [ ] All verification tests passed
- [ ] All relevant CLAUDE.md sections reviewed

### Development Environment

- [ ] Firebase CLI installed and logged in
- [ ] Flutter SDK up to date
- [ ] Android emulator (Pixel 5) available
- [ ] Chrome browser installed
- [ ] `adb` accessible at `~/Library/Android/sdk/platform-tools/adb`

### Repository State

- [ ] On clean branch (e.g., `feature/phase-1-implementation`)
- [ ] No uncommitted changes
- [ ] PHASE_1_INCREMENTAL_IMPLEMENTATION.md (v2.0 Corrected) reviewed

### Documentation Ready

- [ ] PHASE_1_INCREMENTAL_IMPLEMENTATION.md open in editor
- [ ] CLAUDE.md accessible for reference
- [ ] PHASE_1_PRE_IMPLEMENTATION_CHECKLIST.md (this file) printed/accessible

### Testing Scripts Ready

- [ ] `/tmp/clear_firebase.sh` exists (if not, create from CLAUDE.md)
- [ ] `/tmp/debug_firebase.sh` exists (optional)
- [ ] Complete Clean Testing Procedure commands copied to notes

---

## 🚀 Ready to Start?

If ALL checkboxes above are marked, you are ready to begin **Increment 1A**.

If ANY checkbox is not marked:
1. Review the corresponding section
2. Complete the verification steps
3. Do NOT start implementation until ALL checks pass

---

**Checklist Version:** 1.0
**Last Updated:** 2025-11-16
**Status:** ✅ READY FOR USE

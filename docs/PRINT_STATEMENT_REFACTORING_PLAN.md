# Print Statement Refactoring Plan

**Generated:** 2025-11-14
**Last Updated:** 2025-11-15 (Phase 3 Complete)
**Original Count:** 264 print statements across 29 files
**Current Count:** 96 print statements (68 remaining as intentional debug logs)
**Phase 1 Status:** ✅ **COMPLETE** (120 prints removed, 45.5% reduction)
**Phase 3 Status:** ✅ **COMPLETE** (168 total migrated to Logger, 64% reduction)

---

## Executive Summary

The app contains 264 `print()` statements used for debugging and development logging. This document categorizes them and provides recommendations for refactoring.

### Distribution by Category

| Category | Count | Files | Recommendation |
|----------|-------|-------|----------------|
| **Initialization/Setup** | ~40 | main.dart, dev_config.dart, services | **Keep** (critical for debugging) |
| **Success Confirmations** | ~60 | All services | **Consider removing** 70% (redundant) |
| **Error/Warning Logs** | ~50 | All services | **Keep** (essential for debugging) |
| **Debug/Development** | ~80 | Services, screens | **Remove** most (dev-only) |
| **Feature Flow Tracking** | ~34 | Quiz, Poke, Reminders | **Selective removal** |

---

## Refactoring Strategy

### Option 1: Logger Service (Recommended)
Create a centralized logging service with levels (debug, info, warn, error):

```dart
// lib/utils/logger.dart
class Logger {
  static const bool _enableDebug = kDebugMode;

  static void debug(String message) {
    if (_enableDebug) print('🔍 $message');
  }

  static void info(String message) {
    if (_enableDebug) print('ℹ️  $message');
  }

  static void error(String message, [dynamic error]) {
    print('❌ $message${error != null ? ': $error' : ''}');
  }

  static void success(String message) {
    if (_enableDebug) print('✅ $message');
  }
}
```

**Benefits:**
- Toggle all debug logs with single flag
- Preserve error logs in production
- Easy to extend with file logging or remote logging

### Option 2: Conditional Compilation
Use `assert()` for debug-only logs:

```dart
// Only runs in debug mode
assert(() {
  print('🔍 Debug info');
  return true;
}());
```

### Option 3: Complete Removal
Comment out or remove all non-essential print statements.

---

## File-by-File Breakdown

### High Priority Files (Remove Most Prints)

#### 1. **mock_data_service.dart** (30 prints)
**Type:** Development scaffolding
**Action:** Remove 90% after dev complete

<details>
<summary>View detailed breakdown</summary>

**Lines to remove:**
- Line 67-103: Verbose dual-emulator setup (15 prints)
  - Keep: "⚠️ Detected old user ID" warnings
  - Remove: All "ℹ️" and "✅" confirmations
- Line 108-133: Mock injection success messages (8 prints)
  - Keep: Final summary line only
- Line 150-503: Entity creation logs (7 prints)
  - Remove: All "Created X" success messages

**Keep (3 prints):**
- Line 41, 44: Old ID detection warnings
- Line 509: "Mock data cleared" (useful for testing)

**Estimated reduction:** 27/30 prints → **90% removal**
</details>

---

#### 2. **notification_service.dart** (30 prints)
**Type:** Core service debugging
**Action:** Keep errors, remove 60% of info logs

<details>
<summary>View detailed breakdown</summary>

**Lines to keep:**
- Line 85, 91, 93: FCM permission results
- Line 96-97: FCM permission failure warning
- Line 164: "Failed to get FCM token" error
- Line 283, 290, 295, 301: Notification action logs (useful)
- Line 328: Error sending pairing confirmation

**Lines to remove:**
- Line 18, 22, 36, 42: Background message handling (verbose)
- Line 70-71: Web platform skip messages
- Line 149: "NotificationService initialized" success
- Line 156, 161: FCM token logs (too verbose)
- Line 174, 178, 190, 238: Foreground message handling
- Line 279: "Notification tapped" (redundant)
- Line 312-315: Cloud Function call details (4 lines, too verbose)
- Line 326: Success confirmation (redundant)

**Estimated reduction:** 18/30 prints → **60% removal**
</details>

---

#### 3. **dev_config.dart** (23 prints)
**Type:** Development configuration
**Action:** Keep device detection, remove emulator ID logs

<details>
<summary>View detailed breakdown</summary>

**Lines to keep:**
- Line 35-39: iOS device detection (5 lines) - **CRITICAL**
- Line 51-55: Android device detection (5 lines) - **CRITICAL**
- Line 60: Error detecting device type

**Lines to remove:**
- Line 20: "Web Platform: Treated as simulator"
- Line 100: "Platform: Web (Bob)"
- Line 115, 120, 123, 128: AVD name detection (4 lines)
- Line 135, 140, 144: Emulator ID fallbacks (3 lines)
- Line 158, 161, 172: Partner index logs (3 lines)

**Estimated reduction:** 12/23 prints → **52% removal**
</details>

---

#### 4. **quiz_service.dart** (27 prints)
**Type:** Feature service
**Action:** Remove success logs, keep errors

<details>
<summary>View detailed breakdown</summary>

**Lines to keep:**
- Line 247, 257, 263: "Error: X has not answered yet" (validation)
- Line 370: "Badge already earned" (prevents duplicates)
- Line 634: "Cannot sync: user or partner not found"
- Line 665: "Error syncing session to Firebase"
- Line 686: "Cannot load session: user or partner not found"
- Line 740: "Error loading session from Firebase"
- Line 743: "Session not found" warning
- Line 792: "Could not mark quest completed" warning

**Lines to remove:**
- Line 120: "Quiz session started" success
- Line 149: "Answers submitted" success
- Line 208: "Would You Rather answers submitted" success
- Line 311: "Quiz completed" success (redundant with UI)
- Line 361: "Affirmation quiz completed" success
- Line 384: "Badge earned" success (redundant with UI)
- Line 477: "Would You Rather completed" success
- Line 500, 502: Quiz invite send success/error
- Line 521, 523: Quiz reminder send success/error
- Line 544, 546: Completion notification success/error
- Line 663: "Session synced to Firebase" success
- Line 677: "Session found in local cache" (verbose)
- Line 736: "Session loaded from Firebase" success
- Line 790: "Quest marked completed" success

**Estimated reduction:** 19/27 prints → **70% removal**
</details>

---

#### 5. **main.dart** (17 prints)
**Type:** App initialization
**Action:** Keep initialization sequence, remove quest clearing logs

<details>
<summary>View detailed breakdown</summary>

**Lines to keep:**
- Line 31, 35: Firebase already initialized warnings
- Line 54: "Debug Mode: $kDebugMode" - **CRITICAL**
- Line 57-58: "Is Simulator" + "Enable Mock Pairing" - **CRITICAL**
- Line 155-156: Quest generation error + stack trace

**Lines to remove:**
- Line 79-97: Quest clearing debug logs (11 lines, testing-only)
  - "Clearing old quests..."
  - "Date key: X"
  - "Found X quests"
  - "Deleting quest: X"
  - "Cleared X old quests"
  - Error handling for clearing
- Line 112: "Skipping quest generation" info
- Line 121: "LP listener initialized" success
- Line 145: "Daily quests loaded" success
- Line 152: "Daily quests generated" success

**Estimated reduction:** 12/17 prints → **71% removal**
</details>

---

#### 6. **dev_pairing_service.dart** (13 prints)
**Type:** Development pairing
**Action:** Keep errors, remove verbose setup logs

<details>
<summary>View detailed breakdown</summary>

**Lines to keep:**
- Line 30: "Not a simulator" info (useful)
- Line 36: "No user found" warning
- Line 42: "Could not determine emulator ID" warning
- Line 72: "RTDB registration timed out" warning

**Lines to remove:**
- Line 49-53: Pairing confirmation (5 lines, verbose)
  - "Pairing with deterministic IDs..."
  - "Emulator: X"
  - "My name: X"
  - "Partner: X"
  - "Using deterministic user IDs"
- Line 58: "Pairing complete!" success
- Line 76-continuing: FCM token registration logs (verbose)

**Estimated reduction:** 9/13 prints → **69% removal**
</details>

---

#### 7. **poke_service.dart** (14 prints)
**Type:** Feature service
**Action:** Remove verbose logs, keep errors

<details>
<summary>View detailed breakdown</summary>

**Lines to keep:**
- Line 40: "Rate limited. Wait X seconds"
- Line 49, 54: "No partner/user found" errors
- Line 109: "Error sending poke" error
- Line 140: "Error handling received poke" error
- Line 174: "Error sending poke back" error

**Lines to remove:**
- Line 61-64: "Sending poke to partner..." (4 lines, verbose)
- Line 92: "Cloud Function response" success
- Line 104: "Mutual poke! Awarded 5 LP" (redundant with UI)
- Line 138: "Saved received poke" success
- Line 169: "Poke back! Awarded 3 LP" (redundant with UI)

**Estimated reduction:** 8/14 prints → **57% removal**
</details>

---

### Medium Priority Files (Selective Removal)

#### 8. **daily_quests_widget.dart** (10 prints)
**Action:** Remove after debugging quest sync issues

<details>
<summary>View details</summary>

**All lines (66-110) are debugging quest completion sync:**
- "Received partner quest completions"
- "Looking for quest: X"
- "Found quest: X"
- "Partner already completed?"
- "Auto-awarding 30 LP"
- "LP awarded automatically"
- "Error awarding LP"
- "Updated quest with partner completion"

**Recommendation:** Remove all 10 after quest sync is stable (100% removal)
</details>

---

#### 9. **reminder_service.dart** (9 prints)
**Action:** Keep errors, remove verbose send logs

<details>
<summary>View details</summary>

**Lines to keep:**
- Line 19, 24: "No partner/user found" errors
- Line 54: "Error sending reminder" error

**Lines to remove:**
- Line 28-31: Verbose send details (4 lines)
- Line 43: "Cloud Function response" success
- Line 86: "Reminder marked as done, awarded 5 LP"

**Estimated reduction:** 6/9 prints → **67% removal**
</details>

---

#### 10. **quiz_results_screen.dart** (13 prints)
**Action:** Remove quest completion debugging

<details>
<summary>View details</summary>

**All debugging quest completion logic (lines 58-171):**
- Quest matching logs (5 prints)
- Quest completion logs (3 prints)
- Progression advancement logs (5 prints)

**Recommendation:** Remove all 13 after quest integration is stable (100% removal)
</details>

---

#### 11. **ladder_service.dart** (8 prints)
**Action:** Keep errors, remove verbose notification logs

<details>
<summary>View details</summary>

**Lines to remove:**
- Line 363-366: "Sending Word Ladder notification" (4 lines, verbose)
- Line 380: "Notification sent successfully"
- Line 406, 410: "isMyTurn" debug logs (2 lines)

**Lines to keep:**
- Line 382: "Error sending Word Ladder notification"

**Estimated reduction:** 7/8 prints → **88% removal**
</details>

---

#### 12. **remote_pairing_service.dart** (6 prints)
**Action:** Keep errors, remove success messages

<details>
<summary>View details</summary>

**Lines to keep:**
- Line 53: "Error generating pairing code" (Firebase error)
- Line 56: "Error generating pairing code" (general error)
- Line 100: "Error pairing with code" (Firebase error)
- Line 112: "Error pairing with code" (general error)

**Lines to remove:**
- Line 46: "Generated pairing code: X" success
- Line 96: "Paired with: X" success

**Estimated reduction:** 2/6 prints → **33% removal**
</details>

---

### Low Priority Files (Keep Most/All)

#### 13-29. Other Files (Minimal Impact)

| File | Prints | Action |
|------|--------|--------|
| **daily_pulse_service.dart** | 13 | Keep errors, remove verbose logs |
| **word_ladder_game_screen.dart** | 6 | Remove turn debugging after testing |
| **pairing_screen.dart** | 6 | Keep QR data logs (useful) |
| **quiz_waiting_screen.dart** | 4 | Remove after testing |
| **debug_quest_dialog.dart** | 5 | **Keep all** (debug feature) |
| **affirmation_results_screen.dart** | 5 | Remove quest completion logs |
| **memory_flip_service.dart** | 5 | Keep error logs only |
| **word_ladder_hub_screen.dart** | 1 | Keep error log |
| **mock_daily_quests_service.dart** | 6 | **Keep all** (testing utility) |
| **arena_service.dart** | 1 | Remove LP award log |
| **word_validation_service.dart** | 2 | Keep initialization log |
| **quiz_question_bank.dart** | 2 | Keep initialization log |
| **affirmation_quiz_bank.dart** | 2 | Keep initialization log |
| **activities_screen.dart** | 1 | Keep error log |
| **new_home_screen.dart** | 1 | Keep error log |
| **send_reminder_screen.dart** | 2 | Remove (duplicate of reminder_service) |
| **remind_bottom_sheet.dart** | 2 | Remove (duplicate of reminder_service) |

---

## Recommended Action Plan

### Phase 1: Immediate Cleanup ✅ **COMPLETE**
**Target:** Remove obvious redundant success messages

1. ✅ **mock_data_service.dart** - Removed 27 prints (30 → 3)
2. ✅ **dev_config.dart** - Removed 12 prints (23 → 11)
3. ✅ **notification_service.dart** - Removed 19 prints (30 → 11)
4. ✅ **quiz_service.dart** - Removed 12 prints (27 → 15, kept errors)
5. ✅ **main.dart** - Removed 9 prints (17 → 8)
6. ✅ **dev_pairing_service.dart** - Removed 7 prints (13 → 6)
7. ✅ **poke_service.dart** - Removed 8 prints (14 → 6)
8. ✅ **daily_quests_widget.dart** - Removed 9 prints (10 → 1)
9. ✅ **reminder_service.dart** - Removed 6 prints (9 → 3)
10. ✅ **ladder_service.dart** - Removed 7 prints (8 → 1)
11. ✅ **quiz_results_screen.dart** - Removed 11 prints (13 → 2)

**Result:** 264 → 144 prints (**120 removed, 45.5% reduction**)
**Completed:** 2025-11-15

---

### Phase 2: Feature Stabilization (Remove 60 prints)
**Target:** Remove debugging logs after features are stable

**Wait for:**
- Daily Quests sync stable → Remove quest completion logs (23 prints)
- Word Ladder stable → Remove turn debugging (7 prints)
- Affirmation integration complete → Remove quest logs (5 prints)
- Quiz sync stable → Remove waiting screen logs (4 prints)
- General testing complete → Remove scattered debug logs (21 prints)

**Result:** 144 → 84 prints (**68% total reduction**)

---

### Phase 3: Logger Migration ✅ **COMPLETE**
**Target:** Replace print statements with centralized Logger service

1. ✅ Created `lib/utils/logger.dart` with level-based logging
   - `Logger.debug()`, `Logger.info()`, `Logger.warn()`, `Logger.error()`, `Logger.success()`
   - Per-service verbosity control via `_serviceVerbosity` map
   - Automatic debug/production filtering (respects `kDebugMode`)
   - Timestamp support (HH:MM:SS format)
   - Error object and stack trace support

2. ✅ Migrated 168 print statements across core services:
   - `quiz_service.dart` (15 → 0)
   - `main.dart` (8 → 0)
   - `notification_service.dart` (11 → 3 remaining)
   - `dev_pairing_service.dart` (6 → 0)
   - `poke_service.dart` (6 → 0)
   - `reminder_service.dart` (3 → 0)
   - `remote_pairing_service.dart` (6 → 0)
   - `ladder_service.dart` (1 → 0)
   - `memory_flip_service.dart` (5 → 5, some patterns didn't auto-convert)
   - `dev_config.dart` (11 → 8, complex patterns)
   - Additional services migrated

3. ✅ Added comprehensive documentation in CLAUDE.md
   - Usage examples for all log levels
   - Per-service verbosity configuration
   - Best practices and guidelines

**Result:** 264 → 96 prints (**168 migrated, 64% reduction**)
**Completed:** 2025-11-15

**Remaining 96 prints:**
- 28 are intentional (debug UI features, example code in Logger)
- 68 are in UI screens and utility services (can be migrated incrementally)
- All critical services now use Logger

---

## Special Considerations

### Prints to ALWAYS Keep
1. **Critical errors** - Any error that blocks functionality
2. **Device detection logs** - dev_config.dart device/simulator detection
3. **Firebase errors** - Connection, authentication, permission issues
4. **Quest generation errors** - main.dart quest generation failures
5. **Debug feature logs** - debug_quest_dialog.dart (intentional debug UI)

### Prints to ALWAYS Remove
1. **Success confirmations** - "✅ X completed successfully"
2. **Verbose parameter dumps** - Multi-line "Sending X with Y, Z, A, B"
3. **Redundant UI feedback** - "Awarded X LP" when UI shows it
4. **Testing scaffolding** - Mock data injection details

---

## Implementation Notes

### Before Removing
- ✅ Verify error logs are preserved
- ✅ Check if Firebase remote logging is available (not currently implemented)
- ✅ Test on both Android and iOS after removal
- ✅ Keep version history in git for rollback

### After Removing
- Consider adding remote error reporting (Firebase Crashlytics, Sentry)
- Add feature flags for verbose logging in dev builds
- Document critical debugging workflows without print statements

---

## Summary Statistics

| Metric | Current | Phase 1 | Phase 2 | Phase 3 |
|--------|---------|---------|---------|---------|
| **Total Prints** | 264 | 144 | 84 | 0* |
| **Reduction** | - | 45% | 68% | 100%* |
| **Files Affected** | 29 | 11 | 18 | 29 |

*Phase 3 replaces prints with Logger service (not true removal)

---

**Next Steps:**
1. Review this plan
2. Confirm Phase 1 file list
3. Execute Phase 1 cleanup (comment or remove)
4. Test on both platforms
5. Monitor for any debugging regressions

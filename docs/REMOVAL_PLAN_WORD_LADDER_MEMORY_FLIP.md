# Removal Plan: Word Ladder & Memory Flip Games

**Created:** 2025-11-28
**Completed:** 2025-11-28
**Status:** ✅ COMPLETED (Phases 1-6)
**Risk Level:** Medium (enum index changes require careful handling)

---

## Executive Summary

This plan removes Word Ladder and Memory Flip games from the TogetherRemind codebase. Both features are preserved in Git history if needed later.

**Total files affected:**
- **Delete:** ~45 files
- **Modify:** ~15 files
- **Documentation updates:** ~20 files

---

## ⚠️ Critical Risk: Hive Enum Index Changes

### The Problem

`QuestType` enum in `daily_quest.dart` is stored as an integer index in Hive:

```dart
enum QuestType {
  question,    // 0
  quiz,        // 1
  game,        // 2
  wordLadder,  // 3  ← REMOVING
  memoryFlip,  // 4  ← REMOVING
  youOrMe,     // 5  → becomes 3
  linked,      // 6  → becomes 4
  wordSearch,  // 7  → becomes 5
  steps,       // 8  → becomes 6
}
```

If we simply delete `wordLadder` and `memoryFlip`, existing quests with `questType: 5` (youOrMe) will incorrectly load as `wordLadder` (index 3).

### Solution: Keep Deprecated Placeholders

```dart
enum QuestType {
  question,           // 0
  quiz,               // 1
  game,               // 2
  deprecatedLadder,   // 3 - was wordLadder, kept for index stability
  deprecatedFlip,     // 4 - was memoryFlip, kept for index stability
  youOrMe,            // 5
  linked,             // 6
  wordSearch,         // 7
  steps,              // 8
}
```

This preserves index stability for existing Hive data.

### ActivityType Enum (Safe to Modify)

`ActivityType` in `activity_item.dart` is **not** stored in Hive - it's only used at runtime. Safe to remove values directly:

```dart
enum ActivityType {
  reminder,
  poke,
  question,
  quiz,
  affirmation,
  // wordLadder,  ← DELETE
  // memoryFlip,  ← DELETE
  wouldYouRather,
  dailyPulse,
}
```

---

## Phase 1: Delete Standalone Files

### 1.1 Word Ladder Files to Delete

**Flutter Screens:**
- `app/lib/screens/word_ladder_hub_screen.dart`
- `app/lib/screens/word_ladder_game_screen.dart`
- `app/lib/screens/word_ladder_completion_screen.dart`

**Services:**
- `app/lib/services/ladder_service.dart`
- `app/lib/services/word_pair_bank.dart`

**Models:**
- `app/lib/models/ladder_session.dart`
- `app/lib/models/ladder_session.g.dart`
- `app/lib/models/word_pair.dart`
- `app/lib/models/word_pair.g.dart`

**Assets:**
- `app/assets/brands/togetherremind/images/quests/word-ladder.png`
- `app/assets/brands/holycouples/images/quests/word-ladder.png`

**Documentation:**
- `WordLadder-ImplementationPlan.md`

**Mockups:**
- `mockups/wordladder/` (entire directory)
- `mockups/gameideas/word-ladder.html`

### 1.2 Memory Flip Files to Delete

**Flutter Screens:**
- `app/lib/screens/memory_flip_game_screen.dart`

**Services:**
- `app/lib/services/memory_flip_service.dart`

**Models:**
- `app/lib/models/memory_flip.dart`
- `app/lib/models/memory_flip.g.dart`

**Assets:**
- `app/assets/brands/togetherremind/images/quests/memory-flip.png`
- `app/assets/brands/holycouples/images/quests/memory-flip.png`

**Tests:**
- `app/test/memory_flip_service_test.dart`
- `app/test/memory_flip_api_integration_test.dart`

**API Routes:**
- `api/app/api/sync/memory-flip/` (entire directory)
- `api/app/api/dev/reset-memory-flip/route.ts`

**Database Migrations:**
- `api/supabase/migrations/009_memory_flip_turn_based.sql`

**Scripts:**
- `api/scripts/reset_memory_flip.sql`
- `api/scripts/test_memory_flip_api.sh`
- `api/scripts/test_memory_flip_turn_based.ts`
- `api/scripts/verify_memory_flip_sync.ts`
- `api/test_memory_api.sh`

**Documentation:**
- `docs/HANDOVER_2025_11_21_MEMORY_FLIP.md`
- `docs/MEMORY_FLIP_REFACTOR_COMPLETE.md`
- `docs/MEMORY_FLIP_SYNC_FIX.md`
- `docs/MEMORY_FLIP_TURN_BASED_SPEC.md`
- `memory_flip_implementation_plan.md`

---

## Phase 2: Modify Source Files

### 2.1 `app/lib/models/daily_quest.dart`

**Change:**
```dart
enum QuestType {
  question,
  quiz,
  game,
  deprecatedLadder,   // was wordLadder - kept for Hive index stability
  deprecatedFlip,     // was memoryFlip - kept for Hive index stability
  youOrMe,
  linked,
  wordSearch,
  steps,
}
```

**After change:** Run `flutter pub run build_runner build --delete-conflicting-outputs`

### 2.2 `app/lib/models/activity_item.dart`

**Remove from enum:**
```dart
enum ActivityType {
  reminder,
  poke,
  question,
  quiz,
  affirmation,
  // DELETE: wordLadder,
  // DELETE: memoryFlip,
  wouldYouRather,
  dailyPulse,
}
```

**Remove switch cases in `typeLabel` getter (lines 82-85):**
```dart
// DELETE these cases:
case ActivityType.wordLadder:
  return 'Game';
case ActivityType.memoryFlip:
  return 'Game';
```

**Remove switch cases in `displayEmoji` getter (lines 108-111):**
```dart
// DELETE these cases:
case ActivityType.wordLadder:
  return '🪜';
case ActivityType.memoryFlip:
  return '🎴';
```

### 2.3 `app/lib/services/storage_service.dart`

**Remove imports:**
```dart
// DELETE:
import '../models/ladder_session.dart';
import '../models/memory_flip.dart';
```

**Remove box constants:**
```dart
// DELETE:
static const String _ladderSessionsBox = 'ladder_sessions';
static const String _memoryFlipBox = 'memory_flip_puzzles';
```

**Remove Hive adapter registrations:**
```dart
// DELETE these lines:
if (!Hive.isAdapterRegistered(8)) Hive.registerAdapter(WordPairAdapter());
if (!Hive.isAdapterRegistered(9)) Hive.registerAdapter(LadderSessionAdapter());
if (!Hive.isAdapterRegistered(12)) Hive.registerAdapter(MemoryCardAdapter());
if (!Hive.isAdapterRegistered(13)) Hive.registerAdapter(MemoryPuzzleAdapter());
```

**Remove box opens:**
```dart
// DELETE:
await Hive.openBox<LadderSession>(_ladderSessionsBox);
await Hive.openBox<MemoryPuzzle>(_memoryFlipBox);
```

**Remove all ladder methods (~lines 336-403):**
- `ladderSessionsBox`
- `saveLadderSession()`
- `getAllLadderSessions()`
- `getActiveLadders()`
- `updateLadderSession()`
- `getLadderSession()`
- `getActiveLadderCount()`
- `getCompletedLadders()`

**Remove all memory flip methods:**
- `memoryFlipBox`
- `saveMemoryPuzzle()`
- `getMemoryPuzzle()`
- `getAllMemoryPuzzles()`
- `deleteMemoryPuzzle()`

### 2.4 `app/lib/screens/activities_screen.dart`

**Remove imports:**
```dart
// DELETE:
import '../services/ladder_service.dart';
import 'word_ladder_hub_screen.dart';
import '../services/memory_flip_service.dart';
import 'memory_flip_game_screen.dart';
```

**Remove service instances:**
```dart
// DELETE:
final LadderService _ladderService = LadderService();
final MemoryFlipService _memoryFlipService = MemoryFlipService();
```

**Remove initialization and counts for these games.**

**Remove navigation and UI sections for Word Ladder and Memory Flip.**

### 2.5 `app/lib/screens/activity_hub_screen.dart`

**Remove imports:**
```dart
// DELETE:
import 'word_ladder_hub_screen.dart';
import 'memory_flip_game_screen.dart';
```

**Remove case statements in navigation:**
```dart
// DELETE:
case ActivityType.wordLadder:
  Navigator.push(context, MaterialPageRoute(builder: (_) => WordLadderHubScreen()));
  break;
case ActivityType.memoryFlip:
  Navigator.push(context, MaterialPageRoute(builder: (_) => MemoryFlipGameScreen()));
  break;
```

### 2.6 `app/lib/services/activity_service.dart`

**Remove `_getMemoryFlips()` method and its call in the aggregation.**

**Remove any Word Ladder activity fetching.**

### 2.7 `app/lib/services/quest_sync_service.dart`

**Remove case statements:**
```dart
// DELETE:
case 'memory_flip':
  // ... handling code
case 'word_ladder':
  // ... handling code
```

### 2.8 `app/lib/config/dev_config.dart`

**Remove feature flag:**
```dart
// DELETE:
static const bool useSupabaseForMemoryFlip = true;
```

### 2.9 `app/lib/utils/logger.dart`

**Remove from service verbosity:**
```dart
// DELETE from _serviceVerbosity map:
'memory_flip': false,
'word_ladder': false,
'ladder': false,
```

### 2.10 `app/lib/widgets/debug/tabs/actions_tab.dart`

**Remove any Memory Flip or Word Ladder debug actions.**

### 2.11 `functions/index.js`

**Remove functions:**
- `sendWordLadderNotification`
- Any memory puzzle Firestore operations

### 2.12 `app/lib/services/quest_type_manager.dart`

**Update any references to wordLadder or memoryFlip quest types.**

---

## Phase 3: Regenerate Build Files

After all modifications:

```bash
cd app
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## Phase 4: Update pubspec.yaml

**Remove asset references:**
```yaml
# DELETE from assets section:
- assets/brands/togetherremind/images/quests/word-ladder.png
- assets/brands/holycouples/images/quests/word-ladder.png
- assets/brands/togetherremind/images/quests/memory-flip.png
- assets/brands/holycouples/images/quests/memory-flip.png
```

---

## Phase 5: Database Cleanup (Optional)

### Supabase

The migration `009_memory_flip_turn_based.sql` created tables. Options:
1. **Leave tables** - No harm, won't be used
2. **Create rollback migration** - Clean removal

Recommendation: Leave tables for now, clean up in future migration batch.

### Firebase RTDB

No specific paths to remove - data will naturally expire or can be manually cleaned.

---

## Phase 6: Update Documentation

### Files to Update (Remove Memory Flip/Word Ladder References)

1. `CLAUDE.md` - Remove sections 13 (Word Ladder) and Memory Flip references
2. `docs/APP_OVERVIEW.md`
3. `docs/BACKEND_SYNC_ARCHITECTURE.md`
4. `docs/FLUTTER_TESTING_GUIDE.md`
5. `docs/QUEST_SYSTEM_V2.md`
6. `docs/KNOWN_ISSUES.md`
7. `docs/MIGRATION_TO_NEXTJS_POSTGRES.md`

### Files to Delete (Memory Flip Specific Docs)

- `docs/HANDOVER_2025_11_21_MEMORY_FLIP.md`
- `docs/MEMORY_FLIP_REFACTOR_COMPLETE.md`
- `docs/MEMORY_FLIP_SYNC_FIX.md`
- `docs/MEMORY_FLIP_TURN_BASED_SPEC.md`

---

## Verification Checklist

After removal, verify:

- [ ] `flutter analyze` passes with no errors
- [ ] `flutter build apk --debug` succeeds
- [ ] `flutter build web --debug` succeeds
- [ ] App launches without crashes
- [ ] Activities screen loads without errors
- [ ] Existing quests still display correctly (youOrMe, linked, wordSearch)
- [ ] No orphaned imports cause compilation errors
- [ ] API starts without errors (`cd api && npm run dev`)

---

## Rollback Plan

If issues arise, revert using Git:

```bash
git checkout HEAD -- app/lib/models/daily_quest.dart
git checkout HEAD -- app/lib/models/activity_item.dart
# ... etc for each modified file
```

All deleted files are preserved in Git history and can be restored.

---

## Execution Order

1. **Phase 1:** Delete standalone files (safe, no dependencies)
2. **Phase 2:** Modify source files (careful order - models first, then services, then screens)
3. **Phase 3:** Regenerate build files
4. **Phase 4:** Update pubspec.yaml
5. **Phase 5:** Database cleanup (optional, can defer)
6. **Phase 6:** Update documentation
7. **Verify:** Run checklist

---

## Estimated Impact

- **Lines of code removed:** ~3,000+
- **Files deleted:** ~45
- **Files modified:** ~15
- **Build time:** Will decrease slightly
- **App size:** Will decrease by ~100KB (assets + code)

---

## Detailed Task List with Testing After Each Phase

### Phase 1: Delete Standalone Files (Low Risk)

These files have no other dependencies - safe to delete first.

#### Task 1.1: Delete Word Ladder Files
```bash
# Delete screens
rm app/lib/screens/word_ladder_hub_screen.dart
rm app/lib/screens/word_ladder_game_screen.dart
rm app/lib/screens/word_ladder_completion_screen.dart

# Delete services
rm app/lib/services/ladder_service.dart
rm app/lib/services/word_pair_bank.dart

# Delete models
rm app/lib/models/ladder_session.dart
rm app/lib/models/ladder_session.g.dart
rm app/lib/models/word_pair.dart
rm app/lib/models/word_pair.g.dart

# Delete assets
rm app/assets/brands/togetherremind/images/quests/word-ladder.png
rm app/assets/brands/holycouples/images/quests/word-ladder.png

# Delete documentation
rm WordLadder-ImplementationPlan.md

# Delete mockups
rm -rf mockups/wordladder/
rm mockups/gameideas/word-ladder.html
```

#### Task 1.2: Delete Memory Flip Files
```bash
# Delete screen
rm app/lib/screens/memory_flip_game_screen.dart

# Delete service
rm app/lib/services/memory_flip_service.dart

# Delete models
rm app/lib/models/memory_flip.dart
rm app/lib/models/memory_flip.g.dart

# Delete assets
rm app/assets/brands/togetherremind/images/quests/memory-flip.png
rm app/assets/brands/holycouples/images/quests/memory-flip.png

# Delete tests
rm app/test/memory_flip_service_test.dart
rm app/test/memory_flip_api_integration_test.dart

# Delete API routes
rm -rf api/app/api/sync/memory-flip/
rm api/app/api/dev/reset-memory-flip/route.ts

# Delete migration (keep for reference, but mark as deprecated)
# mv api/supabase/migrations/009_memory_flip_turn_based.sql api/supabase/migrations/009_memory_flip_turn_based.sql.deprecated

# Delete scripts
rm api/scripts/reset_memory_flip.sql
rm api/scripts/test_memory_flip_api.sh
rm api/scripts/test_memory_flip_turn_based.ts
rm api/scripts/verify_memory_flip_sync.ts
rm api/test_memory_api.sh

# Delete documentation
rm docs/HANDOVER_2025_11_21_MEMORY_FLIP.md
rm docs/MEMORY_FLIP_REFACTOR_COMPLETE.md
rm docs/MEMORY_FLIP_SYNC_FIX.md
rm docs/MEMORY_FLIP_TURN_BASED_SPEC.md
rm memory_flip_implementation_plan.md
```

#### ✅ Test After Phase 1
```bash
# Should FAIL - expected, we have broken imports
cd app
flutter analyze 2>&1 | head -50

# Expected errors:
# - "Target of URI doesn't exist: 'memory_flip_game_screen.dart'"
# - "Target of URI doesn't exist: 'word_ladder_hub_screen.dart'"
# - etc.

# This is expected! We'll fix these in Phase 2.
```

---

### Phase 2: Fix Model Files (Critical - Hive Compatibility)

#### Task 2.1: Update `daily_quest.dart` Enum
Edit `app/lib/models/daily_quest.dart`:

```dart
// BEFORE:
enum QuestType {
  question,
  quiz,
  game,
  wordLadder,
  memoryFlip,
  youOrMe,
  linked,
  wordSearch,
  steps,
}

// AFTER:
enum QuestType {
  question,
  quiz,
  game,
  deprecatedLadder,   // was wordLadder - kept for Hive index stability
  deprecatedFlip,     // was memoryFlip - kept for Hive index stability
  youOrMe,
  linked,
  wordSearch,
  steps,
}
```

#### Task 2.2: Update `activity_item.dart` Enum
Edit `app/lib/models/activity_item.dart`:

Remove from enum:
```dart
// DELETE these lines:
wordLadder,
memoryFlip,
```

Remove from `typeLabel` getter:
```dart
// DELETE:
case ActivityType.wordLadder:
  return 'Game';
case ActivityType.memoryFlip:
  return 'Game';
```

Remove from `displayEmoji` getter:
```dart
// DELETE:
case ActivityType.wordLadder:
  return '🪜';
case ActivityType.memoryFlip:
  return '🎴';
```

#### ✅ Test After Phase 2
```bash
cd app
flutter analyze 2>&1 | head -100

# Should now see FEWER errors - enum errors should be gone
# Remaining errors should be about missing imports in services/screens
```

---

### Phase 3: Fix Service Files

#### Task 3.1: Update `storage_service.dart`
Edit `app/lib/services/storage_service.dart`:

1. **Remove imports** (near top of file):
```dart
// DELETE:
import '../models/ladder_session.dart';
import '../models/memory_flip.dart';
```

2. **Remove box constants**:
```dart
// DELETE:
static const String _ladderSessionsBox = 'ladder_sessions';
static const String _memoryFlipBox = 'memory_flip_puzzles';
```

3. **Remove adapter registrations** in `init()`:
```dart
// DELETE:
if (!Hive.isAdapterRegistered(8)) Hive.registerAdapter(WordPairAdapter());
if (!Hive.isAdapterRegistered(9)) Hive.registerAdapter(LadderSessionAdapter());
if (!Hive.isAdapterRegistered(12)) Hive.registerAdapter(MemoryCardAdapter());
if (!Hive.isAdapterRegistered(13)) Hive.registerAdapter(MemoryPuzzleAdapter());
```

4. **Remove box opens**:
```dart
// DELETE:
await Hive.openBox<LadderSession>(_ladderSessionsBox);
await Hive.openBox<MemoryPuzzle>(_memoryFlipBox);
```

5. **Remove all ladder methods** (search for "ladder" to find them all):
- `ladderSessionsBox` getter
- `saveLadderSession()`
- `getAllLadderSessions()`
- `getActiveLadders()`
- `updateLadderSession()`
- `getLadderSession()`
- `getActiveLadderCount()`
- `getCompletedLadders()`

6. **Remove all memory flip methods**:
- `memoryFlipBox` getter
- `saveMemoryPuzzle()`
- `getMemoryPuzzle()`
- `getAllMemoryPuzzles()`
- `deleteMemoryPuzzle()`

#### Task 3.2: Update `activity_service.dart`
Edit `app/lib/services/activity_service.dart`:

1. Remove any imports related to memory flip or word ladder
2. Remove `_getMemoryFlips()` method entirely
3. Remove `_getWordLadders()` method if it exists
4. Remove calls to these methods in `getAllActivities()` or similar

#### Task 3.3: Update `quest_sync_service.dart`
Edit `app/lib/services/quest_sync_service.dart`:

Remove case statements:
```dart
// DELETE any cases like:
case 'memory_flip':
  // ... code
case 'word_ladder':
  // ... code
```

#### Task 3.4: Update `dev_config.dart`
Edit `app/lib/config/dev_config.dart`:

```dart
// DELETE:
static const bool useSupabaseForMemoryFlip = true;
```

#### Task 3.5: Update `logger.dart`
Edit `app/lib/utils/logger.dart`:

Remove from `_serviceVerbosity` map:
```dart
// DELETE:
'memory_flip': false,
'word_ladder': false,
'ladder': false,
```

#### Task 3.6: Update `quest_type_manager.dart`
Edit `app/lib/services/quest_type_manager.dart`:

Search for any references to `wordLadder` or `memoryFlip` and update/remove them.

#### ✅ Test After Phase 3
```bash
cd app
flutter analyze 2>&1 | head -100

# Should see fewer errors - service errors should be resolved
# Remaining errors should be about screen imports
```

---

### Phase 4: Fix Screen Files

#### Task 4.1: Update `activities_screen.dart`
Edit `app/lib/screens/activities_screen.dart`:

1. Remove imports:
```dart
// DELETE:
import '../services/ladder_service.dart';
import 'word_ladder_hub_screen.dart';
import '../services/memory_flip_service.dart';
import 'memory_flip_game_screen.dart';
```

2. Remove service instances:
```dart
// DELETE:
final LadderService _ladderService = LadderService();
final MemoryFlipService _memoryFlipService = MemoryFlipService();
```

3. Remove any UI sections showing Word Ladder or Memory Flip cards/buttons

#### Task 4.2: Update `activity_hub_screen.dart`
Edit `app/lib/screens/activity_hub_screen.dart`:

1. Remove imports:
```dart
// DELETE:
import 'word_ladder_hub_screen.dart';
import 'memory_flip_game_screen.dart';
```

2. Remove navigation cases:
```dart
// DELETE:
case ActivityType.wordLadder:
  // navigation code
case ActivityType.memoryFlip:
  // navigation code
```

#### ✅ Test After Phase 4
```bash
cd app
flutter analyze

# Should now show 0 errors!
# If still errors, check what's missing and fix
```

---

### Phase 5: Fix Debug & Cloud Functions

#### Task 5.1: Update `actions_tab.dart`
Edit `app/lib/widgets/debug/tabs/actions_tab.dart`:

Remove any debug buttons/actions for Memory Flip or Word Ladder.

#### Task 5.2: Update `functions/index.js`
Edit `functions/index.js`:

1. Remove `sendWordLadderNotification` function
2. Remove any memory puzzle Firestore operations (search for "memory")

#### ✅ Test After Phase 5
```bash
# Flutter should still analyze clean
cd app
flutter analyze

# Test Cloud Functions
cd functions
npm run lint
```

---

### Phase 6: Regenerate Build Files & Update Assets

#### Task 6.1: Regenerate Hive Adapters
```bash
cd app
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

#### Task 6.2: Update `pubspec.yaml`
Edit `app/pubspec.yaml`:

Remove any explicit asset references to deleted images (if they exist):
```yaml
# DELETE if present:
# - assets/brands/togetherremind/images/quests/word-ladder.png
# - assets/brands/holycouples/images/quests/word-ladder.png
# - assets/brands/togetherremind/images/quests/memory-flip.png
# - assets/brands/holycouples/images/quests/memory-flip.png
```

#### ✅ Test After Phase 6
```bash
cd app

# Full analysis
flutter analyze

# Build Android
flutter build apk --debug
echo "✅ Android build succeeded"

# Build Web
flutter build web --debug
echo "✅ Web build succeeded"

# Build iOS (if on Mac with Xcode)
flutter build ios --debug --no-codesign
echo "✅ iOS build succeeded"
```

---

### Phase 7: Runtime Testing

#### Task 7.1: Launch and Test App
```bash
# Launch on Chrome
cd app
flutter run -d chrome
```

**Manual Testing Checklist:**
- [ ] App launches without crash
- [ ] Home screen loads
- [ ] Daily quests display (if any exist)
- [ ] Activities screen opens without error
- [ ] Settings screen opens without error
- [ ] Debug menu opens (double-tap greeting)
- [ ] No console errors about "wordLadder" or "memoryFlip"

#### Task 7.2: Test Existing Quest Types
If you have existing quests in Hive storage:
- [ ] youOrMe quests still work
- [ ] linked quests still work
- [ ] wordSearch quests still work
- [ ] Quiz quests still work

#### ✅ Final Verification
```bash
# One final clean build to confirm everything works
cd app
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter analyze
flutter build apk --debug
flutter run -d chrome

# If all passes - removal is complete!
```

---

### Phase 8: Documentation Cleanup (Optional)

#### Task 8.1: Update CLAUDE.md
Remove sections mentioning Memory Flip and Word Ladder from `CLAUDE.md`.

#### Task 8.2: Update Other Docs
Review and update:
- `docs/APP_OVERVIEW.md`
- `docs/QUEST_SYSTEM_V2.md`
- `docs/BACKEND_SYNC_ARCHITECTURE.md`
- `docs/FLUTTER_TESTING_GUIDE.md`

#### ✅ Test After Phase 8
No code testing needed - just verify docs are accurate.

---

## Quick Reference: Complete File Deletion List

```bash
# Run this script to delete all files at once (after Phase 2+ modifications are done)
# WARNING: Make sure you've committed your changes first!

# Word Ladder
rm -f app/lib/screens/word_ladder_hub_screen.dart
rm -f app/lib/screens/word_ladder_game_screen.dart
rm -f app/lib/screens/word_ladder_completion_screen.dart
rm -f app/lib/services/ladder_service.dart
rm -f app/lib/services/word_pair_bank.dart
rm -f app/lib/models/ladder_session.dart
rm -f app/lib/models/ladder_session.g.dart
rm -f app/lib/models/word_pair.dart
rm -f app/lib/models/word_pair.g.dart
rm -f app/assets/brands/togetherremind/images/quests/word-ladder.png
rm -f app/assets/brands/holycouples/images/quests/word-ladder.png
rm -f WordLadder-ImplementationPlan.md
rm -rf mockups/wordladder/
rm -f mockups/gameideas/word-ladder.html

# Memory Flip
rm -f app/lib/screens/memory_flip_game_screen.dart
rm -f app/lib/services/memory_flip_service.dart
rm -f app/lib/models/memory_flip.dart
rm -f app/lib/models/memory_flip.g.dart
rm -f app/assets/brands/togetherremind/images/quests/memory-flip.png
rm -f app/assets/brands/holycouples/images/quests/memory-flip.png
rm -f app/test/memory_flip_service_test.dart
rm -f app/test/memory_flip_api_integration_test.dart
rm -rf api/app/api/sync/memory-flip/
rm -f api/app/api/dev/reset-memory-flip/route.ts
rm -f api/scripts/reset_memory_flip.sql
rm -f api/scripts/test_memory_flip_api.sh
rm -f api/scripts/test_memory_flip_turn_based.ts
rm -f api/scripts/verify_memory_flip_sync.ts
rm -f api/test_memory_api.sh
rm -f docs/HANDOVER_2025_11_21_MEMORY_FLIP.md
rm -f docs/MEMORY_FLIP_REFACTOR_COMPLETE.md
rm -f docs/MEMORY_FLIP_SYNC_FIX.md
rm -f docs/MEMORY_FLIP_TURN_BASED_SPEC.md
rm -f memory_flip_implementation_plan.md

echo "✅ All files deleted"
```

---

## Troubleshooting Common Issues

### Issue: "type 'Null' is not a subtype of type 'X'"
**Cause:** Hive enum index mismatch
**Fix:** Ensure you renamed enums to `deprecatedLadder`/`deprecatedFlip` instead of deleting

### Issue: "Target of URI doesn't exist"
**Cause:** Import pointing to deleted file
**Fix:** Search for the import and remove it

### Issue: "The method 'X' isn't defined"
**Cause:** Code calling deleted method
**Fix:** Search for the method name and remove/update the caller

### Issue: Build fails with asset errors
**Cause:** pubspec.yaml still references deleted assets
**Fix:** Remove asset references from pubspec.yaml

### Issue: Runtime crash on Activities screen
**Cause:** Navigation or service still referencing deleted screens
**Fix:** Check activities_screen.dart and activity_hub_screen.dart for remaining references

# Branching Content Architecture - Task List

## Overview

Implement per-activity branching content system with progression-based rotation for white-label couples app.

**Key Decisions:**
- Separate files in subfolders per branch
- Activity-specific branch names (lighthearted/deeper, emotional/practical, etc.)
- Selection: `questCount % branchCount`
- 100% separate content per brand
- **Sync: Hive (local) + Supabase via API (no Firebase RTDB)**

---

## Phase 1: Infrastructure (Dart Models & Storage) ✅ COMPLETE

### Tasks
- [x] Create `app/lib/models/branch_progression_state.dart`
  - [x] Define `BranchableActivityType` enum (classicQuiz, affirmation, youOrMe, linked, wordSearch)
  - [x] Define `BranchProgressionState` HiveType (typeId: 26)
  - [x] Add fields: coupleId, activityTypeIndex, currentBranch, totalCompletions, maxBranches
  - [x] Add `completeActivity()` method with mod logic
  - [x] Add `toJson()` / `fromJson()` for API sync

- [x] Run `flutter pub run build_runner build --delete-conflicting-outputs`

- [x] Update `app/lib/services/storage_service.dart`
  - [x] Add `_branchProgressionBox` constant
  - [x] Register `BranchProgressionStateAdapter` in `init()`
  - [x] Open branch progression box
  - [x] Add CRUD methods: `saveBranchProgressionState()`, `getBranchProgressionState()`, `getAllBranchProgressionStates()`

- [x] Create `app/lib/services/branch_progression_service.dart`
  - [x] Implement `getOrCreateState(coupleId, activityType)`
  - [x] Implement `getCurrentBranch(activityType)` returning folder name
  - [x] Implement `completeActivity(activityType)`
  - [x] Implement `syncFromApi(coupleId)` - load from Supabase on app open
  - [x] Implement `_saveToApi(state)` - persist to Supabase

- [x] Create Supabase migration `api/supabase/migrations/015_branch_progression.sql`
  - [x] Create `branch_progression` table (couple_id, activity_type, current_branch, total_completions, max_branches)
  - [x] Add indexes and RLS policies

- [x] Create API endpoint `api/app/api/sync/branch-progression/route.ts`
  - [x] GET: Fetch all branch states for couple
  - [x] POST: Upsert branch state after completion

- [ ] Apply migration: `cd api && supabase db push` (pending deployment)

### Phase 1 Testing
- [ ] Unit test: `BranchProgressionState.completeActivity()` cycles correctly (0→1→0 for 2 branches)
- [ ] Unit test: `toJson()`/`fromJson()` round-trip
- [ ] Integration test: Save/load from Hive storage
- [ ] API test: GET/POST branch-progression endpoints
- [ ] Integration test: Sync between devices via API (on app open)
- [ ] Verify: New couples start with currentBranch = 0

---

## Phase 2: Content Directory Structure ✅ COMPLETE

### Tasks
- [x] Create directory structure for TogetherRemind:
  ```
  app/assets/brands/togetherremind/data/
  ├── classic-quiz/
  │   ├── lighthearted/
  │   ├── deeper/
  │   └── manifest.json
  ├── affirmation/
  │   ├── emotional/
  │   ├── practical/
  │   └── manifest.json
  ├── you-or-me/
  │   ├── playful/
  │   ├── reflective/
  │   └── manifest.json
  └── _legacy/
  ```

- [x] Create manifest.json for each activity with branch metadata

- [x] Update `app/lib/config/brand/content_paths.dart`
  - [x] Add `getClassicQuizPath(String branch)`
  - [x] Add `getAffirmationPath(String branch)`
  - [x] Add `getYouOrMePath(String branch)`
  - [x] Add `getManifestPath(String activity)`
  - [x] Keep legacy paths for backward compatibility

- [x] Update `app/pubspec.yaml`
  - [x] Add new asset paths for branch folders

- [ ] Run `flutter clean && flutter pub get`

### Phase 2 Testing
- [ ] Verify: `flutter build` succeeds with new asset paths
- [ ] Verify: `ContentPaths.getClassicQuizPath('lighthearted')` returns correct path
- [ ] Verify: Legacy paths still work
- [ ] Verify: Manifest files load correctly via `rootBundle.loadString()`

---

## Phase 3: Content Bank Updates ✅ COMPLETE

### Tasks
- [x] Update `app/lib/services/quiz_question_bank.dart`
  - [x] Add `_currentBranch` field
  - [x] Add `initializeWithBranch(String branch)` method
  - [x] Update `_loadFromPath()` to use branch path
  - [x] Add fallback to legacy path if branch folder missing

- [x] Update `app/lib/services/affirmation_quiz_bank.dart`
  - [x] Add `_currentBranch` field
  - [x] Add `initializeWithBranch(String branch)` method
  - [x] Update loading to use branch path

- [x] Update `app/lib/services/you_or_me_service.dart`
  - [x] Add `_currentBranch` field
  - [x] Add `loadQuestionsWithBranch(String branch)` method
  - [x] Add `_loadFromPath()` helper
  - [x] Add fallback to legacy path

### Phase 3 Testing
- [ ] Unit test: `QuizQuestionBank.initializeWithBranch('lighthearted')` loads correct file
- [ ] Unit test: `QuizQuestionBank.initializeWithBranch('deeper')` loads different questions
- [ ] Unit test: Fallback to legacy works when branch folder missing
- [ ] Integration test: Questions from correct branch appear in quiz session

---

## Phase 4: Quest Generation Integration ✅ COMPLETE

### Tasks
- [x] Update `app/lib/services/quest_type_manager.dart`
  - [x] Add `BranchProgressionService` to QuestTypeManager
  - [x] Add `coupleId` parameter to QuestProvider interface

- [x] Update `QuizQuestProvider` in quest_type_manager.dart
  - [x] Inject `BranchProgressionService`
  - [x] Get current branch before generating quest (classic vs affirmation)
  - [x] Load content from branch via `QuizQuestionBank.initializeWithBranch()` or `AffirmationQuizBank.initializeWithBranch()`

- [x] Update `YouOrMeQuestProvider`
  - [x] Inject `BranchProgressionService`
  - [x] Load content from branch via `loadQuestionsWithBranch()`

- [x] Add `advanceBranchProgression()` method to QuestTypeManager
  - [x] Maps quest type to activity type
  - [x] Calls `branchService.completeActivity()` after completion

### Phase 4 Testing
- [ ] Integration test: First quest uses Branch A content
- [ ] Integration test: After completing quest, next quest uses Branch B
- [ ] Integration test: Partner device syncs branch state on app open (via API)
- [ ] Manual test: Complete 4 quests, verify A→B→A→B rotation
- [ ] Regression test: Existing `QuizProgressionState` still works alongside branches

---

## Phase 5: API Updates (Linked & Word Search) ✅ COMPLETE

### Tasks
- [x] Create API puzzle directory structure:
  ```
  api/data/puzzles/
  ├── linked/
  │   ├── casual/
  │   └── romantic/
  └── word-search/
      ├── everyday/
      └── passionate/
  ```

- [x] Update `api/app/api/sync/linked/route.ts`
  - [x] Add `loadPuzzle(puzzleId, branch)` with fallback
  - [x] Add `loadPuzzleOrder(branch)` with fallback
  - [x] Add `getCurrentBranch(coupleId)` that reads from `branch_progression` table
  - [x] Add `getBranchFolderName()` mapping
  - [x] Update `getNextPuzzleForCouple()` to return branch

- [x] Update `api/app/api/sync/word-search/route.ts`
  - [x] Same branch-aware puzzle loading pattern
  - [x] Add `getCurrentBranch()` for wordSearch activity type

### Phase 5 Testing
- [ ] API test: Linked API loads from correct branch path
- [ ] API test: Word Search API loads from correct branch path
- [ ] API test: Fallback to legacy path works
- [ ] Integration test: Puzzle completion advances branch state
- [ ] Manual test: Play Linked twice, verify casual→romantic rotation

---

## Phase 6: Content Migration ✅ COMPLETE

### Tasks
- [x] Split `quiz_questions.json` into branches:
  - [x] difficulty ≤2 → `lighthearted/questions.json` (156 questions)
  - [x] difficulty ≥2 → `deeper/questions.json` (133 questions)

- [x] Split `affirmation_quizzes.json` into branches:
  - [x] trust/emotional_support → `emotional/quizzes.json` (6 quizzes)
  - [x] All quizzes → `practical/quizzes.json` (6 quizzes)

- [x] Split `you_or_me_questions.json` into branches:
  - [x] First half → `playful/questions.json` (30 questions)
  - [x] Second half → `reflective/questions.json` (30 questions)

- [x] Keep original files in `_legacy/` folder for both brands

- [x] Create/update manifest.json files with accurate question counts

- [x] Apply same migrations to HolyCouples brand

### Phase 6 Testing
- [ ] Validation: Each branch has minimum required content
- [ ] Validation: JSON schema is correct for all files
- [ ] Integration test: App loads content from new structure
- [ ] Regression test: Legacy fallback still works

---

## Phase 7: Tooling & Documentation

### Tasks
- [ ] Create `scripts/validate-branch-content.sh`
  - [ ] Check manifest exists for each activity
  - [ ] Validate JSON schema per file
  - [ ] Check minimum question counts per branch
  - [ ] Report branch distribution statistics

- [ ] Create `scripts/scaffold-brand.sh`
  - [ ] Create full directory structure for new brand
  - [ ] Generate manifest templates
  - [ ] Copy placeholder assets

- [ ] Update `docs/WHITE_LABEL_GUIDE.md`
  - [ ] Add branch content section
  - [ ] Document content requirements per branch
  - [ ] Add AI content generation workflow

- [ ] Create content creator documentation
  - [ ] Spreadsheet template for questions
  - [ ] Branch naming guidelines
  - [ ] Quality checklist

### Phase 7 Testing
- [ ] Run `validate-branch-content.sh togetherremind` - should pass
- [ ] Run `scaffold-brand.sh testbrand` - verify structure created
- [ ] Review documentation for clarity

---

## Phase 8: HolyCouples Brand Content

### Tasks
- [ ] Run `scaffold-brand.sh holycouples`

- [ ] Generate HolyCouples content:
  - [ ] Classic Quiz: 90 lighthearted + 90 deeper (faith-themed)
  - [ ] Affirmation: 3 emotional + 3 practical quizzes
  - [ ] You-or-Me: 30 playful + 30 reflective questions

- [ ] Create HolyCouples puzzles:
  - [ ] Linked: 5 casual + 5 romantic (faith-themed)
  - [ ] Word Search: 4 everyday + 4 passionate

- [ ] Run validation: `validate-branch-content.sh holycouples`

- [ ] Update HolyCouples manifest files with counts

### Phase 8 Testing
- [ ] Build HolyCouples flavor: `flutter build apk --flavor holycouples --dart-define=BRAND=holyCouples`
- [ ] Manual test: Play through 4 quests, verify branch rotation
- [ ] Manual test: Content is faith-appropriate
- [ ] Manual test: No TogetherRemind content appears

---

## Final Validation Checklist

- [ ] Two-device test: Alice (Android) and Bob (Chrome) see same branch after app restart
- [ ] Branch sync: After Alice completes quest and Bob reopens app, Bob sees Branch B
- [ ] Legacy migration: Existing couples work without data loss
- [ ] Performance: Content loading time acceptable (<500ms)
- [ ] Memory: No memory leaks from branch switching
- [ ] Error handling: Graceful fallback if branch folder missing
- [ ] No Firebase: Verify no new Firebase RTDB paths were added

---

## Branch Names Reference

| Activity | Branch A | Branch B | Future C |
|----------|----------|----------|----------|
| Classic Quiz | `lighthearted` | `deeper` | `spicy` |
| Affirmation | `emotional` | `practical` | `spiritual` |
| You-or-Me | `playful` | `reflective` | `intimate` |
| Linked | `casual` | `romantic` | `adult` |
| Word Search | `everyday` | `passionate` | `naughty` |

---

## Content Volume Per Brand

| Activity | Per Branch | Total (2 branches) |
|----------|------------|-------------------|
| Classic Quiz | 90 questions | 180 |
| Affirmation | 3 quizzes (15 questions) | 6 quizzes (30 questions) |
| You-or-Me | 30 questions | 60 |
| Linked | 5 puzzles | 10 |
| Word Search | 4 puzzles | 8 |

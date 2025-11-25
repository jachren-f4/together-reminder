# Linked Game - Coding Agent Instructions

**Feature:** Turn-based arroword puzzle game for couples
**Scope:** Complete implementation from Side Quest card through game screen to completion
**Phases:** 13 implementation phases with continuous testing
**Expected Duration:** Multi-session implementation with testing at each phase

---

## 📋 Context Documents

**Primary Implementation Guide:**
- `docs/LINKED_IMPLEMENTATION_PLAN.md` (main implementation guide with all 13 phases)

**Supporting Specifications:**
- `docs/Linked_PRD.md` (product requirements and game mechanics)
- `docs/LINKED_GAME_DETAILED_SPEC.md` (detailed gameplay mechanics)
- `mockups/crossword/CROSSWORD_CARD_UI_SPEC.md` (UI card states specification)
- `docs/FLUTTER_TESTING_GUIDE.md` (test patterns and templates)

---

## 🎯 Your Task

Implement the **Linked game feature from Phases 1 through 13** in a continuous development process. This includes:

- **Phases 1-6**: Side Quest Card UI (home screen card with 5 states)
- **Phases 7-13**: Game Screen (grid, drag & drop, turn submission, completion)

Use **test-driven development** with patterns from the Flutter Testing Guide. Test each phase before moving to the next.

---

## 📐 Development Workflow

**For each phase (1→2→3→...→13):**

1. **Implement** the phase tasks from `LINKED_IMPLEMENTATION_PLAN.md`
2. **Write tests** using templates from `FLUTTER_TESTING_GUIDE.md`:
   - Dart API integration tests (`app/test/linked_api_integration_test.dart`)
   - Dart widget tests for UI components
   - Shell script tests (`api/scripts/test_linked_api.sh`)
3. **Run tests** to verify implementation:
   ```bash
   # Ensure API is running first
   cd api && npm run dev &

   # Run Flutter tests
   cd app && flutter test test/linked_api_integration_test.dart --reporter expanded

   # Run shell tests (for API phases)
   cd api && ./scripts/test_linked_api.sh
   ```
4. **Fix any failures** before moving to next phase
5. **Continue immediately** to next phase - do NOT stop between phases unless blocked

---

## ✅ Phase-by-Phase Implementation Guide

### **PART 1: Side Quest Card (Phases 1-6)**

| Phase | What to Build | What to Test |
|-------|---------------|--------------|
| **Phase 1: Data Layer** | Hive models with all card state fields, LinkedCardState enum | Model serialization/deserialization |
| **Phase 2: Service Layer** | API calls, state calculations, polling mechanism | API integration (match creation, state polling) |
| **Phase 3: UI Components** | Card widget, progress ring, badges, score row, countdown | Widget rendering for each component |
| **Phase 4: Card Renderers** | 5 card state builders with proper styling | All 5 states render correctly |
| **Phase 5: Integration** | Add to carousel, navigation, state transitions | End-to-end card behavior |
| **Phase 6: Visual Polish** | Border thickness, badge styling, animations | Visual verification, accessibility |

### **PART 2: Game Screen (Phases 7-13)**

| Phase | What to Build | What to Test |
|-------|---------------|--------------|
| **Phase 7: Grid Rendering** | Grid widget, 4 cell types (void, clue, answer, locked) | Cell rendering logic, grid layout |
| **Phase 8: Drag & Drop** | Rack widget, drag state management, 3 drag operations | Drag from rack→grid, grid→grid, grid→rack |
| **Phase 9: Turn Submission** | Action bar, submission flow, validation animations | Submit turn API, correct/incorrect animations |
| **Phase 10: Hint & Scoring** | Hint power-up, scoreboard, scoring logic | Hint API, score updates, word bonuses |
| **Phase 11: Completion** | Completion screen, confetti, stats display | Game completion trigger, LP award |
| **Phase 12: Polling & Partner** | 10s polling, partner's turn UI, state sync | Polling updates, turn switching |
| **Phase 13: Integration** | Add to Activities, navigation, full testing | End-to-end gameplay, full turn cycle |

---

## 🔑 Critical Success Criteria

### **After Phase 2 (Service Layer)**

Must pass these API tests:

```dart
// Test: GET /api/sync/linked/[matchId] returns correct data
test('Poll match state', () async {
  final response = await apiRequest('GET', '/api/sync/linked/$matchId', userId: aliceId);
  final data = jsonDecode(response.body);
  expect(data['currentTurnUserId'], isNotNull);
  expect(data['lockedCellCount'], isA<int>());
  expect(data['totalAnswerCells'], isA<int>());
});

// Test: Card state calculation logic
test('getCardState returns correct state', () {
  expect(service.getCardState(match: freshMatch, userId: aliceId),
    equals(LinkedCardState.yourTurnFresh));
  expect(service.getCardState(match: inProgressMatch, userId: aliceId),
    equals(LinkedCardState.partnerTurnInProgress));
});
```

### **After Phase 6 (Card Complete)**

Card integration test:

```dart
// Test: Full card polling cycle
test('Card updates when match state changes', () async {
  // 1. Create match (Alice's turn)
  // 2. Verify card shows "Your Turn (Fresh)"
  // 3. Alice makes move
  // 4. Verify card shows "Your Turn (In Progress)" with progress %
  // 5. Alice completes turn
  // 6. Verify card shows "Partner's Turn (In Progress)"
});
```

### **After Phase 9 (Turn Submission)**

Game screen test:

```dart
// Test: Submit turn with correct and incorrect placements
test('Submit turn validates placements', () async {
  final placements = [
    {'cellIndex': 8, 'letter': 'D'}, // Correct
    {'cellIndex': 9, 'letter': 'X'}, // Incorrect
  ];
  final response = await apiRequest('POST', '/api/sync/linked/submit',
    userId: aliceId, body: {'matchId': matchId, 'placements': placements});
  final data = jsonDecode(response.body);
  expect(data['results'][0]['correct'], isTrue);
  expect(data['results'][1]['correct'], isFalse);
});
```

### **After Phase 13 (Full Integration)**

Complete gameplay test:

```bash
# Shell script test: Full turn cycle
./api/scripts/test_linked_game.sh
# Expected output:
# ✓ Alice creates match
# ✓ Alice gets rack [D, R, I, P, M]
# ✓ Alice submits placements
# ✓ Bob polls, sees Alice's locked cells
# ✓ Bob's turn, gets new rack
# ✓ Full puzzle completion
# ✓ +30 LP awarded
```

---

## 📚 Reference Implementations to Follow

| Component | Reference File | What to Copy |
|-----------|----------------|--------------|
| **Hive Models** | `app/lib/models/memory_flip.dart` | TypeId pattern, field annotations, `@HiveField(defaultValue: ...)` |
| **Service (Card)** | `app/lib/services/memory_flip_service.dart` | Polling mechanism (10s), GameState enum, HTTP requests |
| **Service (Game)** | `app/lib/services/quiz_service.dart` | Local state management, session handling |
| **API Routes** | `api/app/api/sync/memory-flip/route.ts` | Auth middleware, error handling, transaction locking |
| **Drag & Drop** | Flutter docs + custom implementation | `Draggable<T>` and `DragTarget<T>` widgets |
| **Grid Layout** | Custom `Stack` widget | Positioned widgets for absolute cell placement |
| **API Tests** | `app/test/memory_flip_api_integration_test.dart` | HTTP helper, test structure, assertions |
| **Shell Tests** | `api/scripts/test_memory_flip_api.sh` | curl patterns, color output, pass/fail logic |
| **Animations** | Flutter `AnimatedContainer`, `AnimatedOpacity` | Correct/incorrect/completion animations |

---

## 🚫 Do NOT Stop For:

- ✅ Tests passing - Continue to next phase immediately
- ✅ Individual phase completion - Keep going
- ✅ Minor warnings - Fix and continue
- ✅ Linting issues - Fix and continue
- ✅ Small refactoring opportunities - Note for later, continue

---

## 🛑 DO Stop and Report If:

- ❌ API endpoint returns 500 errors consistently
- ❌ Tests fail after 3 fix attempts
- ❌ Missing critical dependencies (Supabase tables, puzzle JSON files)
- ❌ Blocking ambiguity in specifications
- ❌ Authentication/authorization issues with dev bypass
- ❌ Fundamental architecture questions

---

## 📝 Deliverables After Phase 13

### **Files Created (Flutter)**

```
app/lib/
├── models/
│   ├── linked.dart              # Hive models (LinkedMatch, LinkedPuzzle, etc.)
│   └── linked.g.dart            # Generated adapters
├── services/
│   └── linked_service.dart      # API calls, polling, state management
├── screens/
│   ├── linked_game_screen.dart  # Main game screen
│   └── linked_completion_screen.dart  # Completion overlay
└── widgets/
    ├── linked_card.dart         # Side quest card (5 states)
    └── linked/
        ├── linked_grid.dart     # Grid container (Stack)
        ├── clue_cell.dart       # Gray cell with clue text + arrow
        ├── answer_cell.dart     # DragTarget for letters (3 states)
        ├── void_cell.dart       # Black non-interactive cell
        ├── rack_widget.dart     # Draggable letter tiles
        ├── action_bar.dart      # Submit, Hint, Shuffle buttons
        ├── scoreboard.dart      # Score display with active indicator
        ├── progress_ring.dart   # Progress % overlay (card)
        ├── partner_badge.dart   # Partner initial + name (card)
        ├── completion_badge.dart # Checkmark badge (card)
        ├── score_row.dart       # Score row (card)
        └── countdown_timer.dart # Next puzzle countdown (card)
```

### **Files Created (API)**

```
api/
├── app/api/sync/linked/
│   ├── route.ts              # POST/GET match state
│   ├── [matchId]/route.ts    # GET specific match
│   ├── submit/route.ts       # POST turn submission
│   └── hint/route.ts         # POST hint power-up
├── data/puzzles/
│   └── arroword_test.json    # First puzzle (copied from docs/)
└── scripts/
    ├── test_linked_api.sh    # Shell script API test
    └── test_linked_game.sh   # Full gameplay test
```

### **Tests Created**

```
app/test/
├── linked_api_integration_test.dart  # API integration tests
├── linked_service_test.dart          # Service unit tests
├── linked_card_test.dart             # Card widget tests
└── linked_game_screen_test.dart      # Game screen widget tests
```

### **Database Migration**

```
api/supabase/migrations/
└── 011_linked_game.sql        # Creates linked_matches + linked_moves tables
```

### **Test Results**

```bash
✅ flutter test (all tests passing)
✅ ./scripts/test_linked_api.sh (all API tests passing)
✅ ./scripts/test_linked_game.sh (full gameplay test passing)
```

### **Feature Checklist**

- [x] Side Quest card displays in carousel with 5 states
- [x] Card polls every 10 seconds during partner's turn
- [x] Card shows progress %, scores, whose turn
- [x] Tap card navigates to game screen
- [x] Grid renders 63 cells (void, clue, answer types)
- [x] Drag letters from rack to grid
- [x] Rearrange draft letters on grid
- [x] Submit turn validates placements server-side
- [x] Correct letters lock (green), incorrect bounce back (shake animation)
- [x] Word completion bonus awarded (+word_length × 10)
- [x] Hint power-up highlights valid cells (2 per player)
- [x] Scores update with animation
- [x] Partner's turn shows read-only view
- [x] Polling updates grid during partner's turn
- [x] Completion screen shows with confetti
- [x] +30 Love Points awarded on completion
- [x] Winner/loser displayed with final scores
- [x] "Back to Home" returns to updated card

---

## 💡 Pro Tips for Implementation

### **Testing Strategy**

1. **Write tests BEFORE implementing features** (true TDD where possible)
2. **Copy test structure from Memory Flip** - already proven to work
3. **Use `--reporter expanded`** for detailed test output
4. **Test incrementally** - run tests after each major change
5. **Use dev user IDs** from `lib/config/dev_config.dart`:
   - Alice (Android): `c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28`
   - Bob (Chrome): `d71425a3-a92f-404e-bfbe-a54c4cb58b6a`

### **Development Workflow**

1. **Start API server FIRST**: `cd api && npm run dev`
2. **Verify dev bypass enabled**: Check `api/.env.local` has `AUTH_DEV_BYPASS_ENABLED=true`
3. **Run tests frequently**: Don't wait until phase end
4. **Use hot reload during UI development**: BUT increment version number to verify changes
5. **Check console logs**: Look for `Logger.debug()` output (service-specific verbosity in `lib/utils/logger.dart`)

### **Common Pitfalls to Avoid**

- ❌ **Don't send solution to client**: API must never include `grid` array in response
- ❌ **Don't forget `defaultValue` in Hive fields**: Causes "type 'Null' is not a subtype" crashes
- ❌ **Don't call Firebase APIs directly on web**: Use service wrappers
- ❌ **Don't skip transaction locking in API**: Use `FOR UPDATE` to prevent race conditions
- ❌ **Don't hardcode cell positions**: Calculate from `(row, col)` based on screen size
- ❌ **Don't forget to stop polling**: Clean up timers in `dispose()`

### **Debug Tools**

- **API logs**: Check terminal running `npm run dev`
- **Flutter console**: Look for Logger output (enable service in `lib/utils/logger.dart`)
- **Network inspector**: Use browser DevTools for API calls
- **Hive inspector**: Read boxes directly: `StorageService().getLinkedMatches()`
- **Version number**: Increment in `new_home_screen.dart` to verify hot reload

---

## 🎬 How to Start

1. **Read all context documents** listed at the top
2. **Confirm you understand the scope**:
   ```
   "I will implement Phases 1-13 of the Linked game feature:
   - Phases 1-6: Side Quest Card UI
   - Phases 7-13: Game Screen with drag & drop, turn submission, completion

   I will use test-driven development and NOT stop between phases
   unless I encounter blocking errors."
   ```
3. **Verify prerequisites**:
   - API server can start: `cd api && npm run dev`
   - Dev bypass works: `curl -H "X-Dev-User-Id: c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28" http://localhost:3000/api/dev/user-data`
   - Flutter can build: `cd app && flutter test --reporter compact`
4. **Begin Phase 1**: Create Hive models in `app/lib/models/linked.dart`

---

## 📊 Example Implementation Session

```bash
# ===== PHASE 1: Data Layer =====
Agent: "Creating Hive models in app/lib/models/linked.dart..."
Agent: "Adding LinkedMatch, LinkedPuzzle, LinkedCardState enum..."
Agent: "Running: flutter pub run build_runner build --delete-conflicting-outputs"
Agent: "✅ Phase 1 complete, all fields have defaultValue, models generated"

# ===== PHASE 2: Service Layer =====
Agent: "Creating LinkedService in app/lib/services/linked_service.dart..."
Agent: "Implementing getCardState(), getProgressPercentage(), polling mechanism..."
Agent: "Writing API integration test: app/test/linked_api_integration_test.dart"
Agent: "Running: flutter test test/linked_api_integration_test.dart --reporter expanded"
Agent: "✅ Phase 2 complete, 8 tests passing (match creation, state polling, calculations)"

# ===== PHASE 3: UI Components =====
Agent: "Creating linked_card.dart with stateful widget + polling lifecycle..."
Agent: "Creating progress_ring.dart, partner_badge.dart, score_row.dart..."
Agent: "Writing widget tests for each component..."
Agent: "✅ Phase 3 complete, all components render correctly"

# ===== PHASE 4-6: Card States & Integration =====
Agent: "Implementing 5 card state builders with proper borders/badges..."
Agent: "Adding LinkedCard to new_home_screen.dart carousel..."
Agent: "Testing state transitions with manual verification..."
Agent: "✅ Phases 4-6 complete, card functional with all 5 states"

# ===== PHASE 7: Grid Rendering =====
Agent: "Creating linked_grid.dart with Stack for absolute positioning..."
Agent: "Creating clue_cell.dart, answer_cell.dart, void_cell.dart..."
Agent: "Implementing two-layer rendering logic (gridnums → grid)..."
Agent: "✅ Phase 7 complete, grid renders 63 cells correctly"

# ===== PHASE 8: Drag & Drop =====
Agent: "Creating rack_widget.dart with Draggable tiles..."
Agent: "Implementing drag state management in linked_game_screen.dart..."
Agent: "Adding onAccept handlers for DragTarget in answer_cell.dart..."
Agent: "Testing: Drag from rack → grid (yellow), grid → grid (move), grid → rack (return)"
Agent: "✅ Phase 8 complete, all 3 drag operations working"

# ===== PHASE 9: Turn Submission =====
Agent: "Creating action_bar.dart with Submit/Hint buttons..."
Agent: "Implementing submitTurn() in linked_service.dart..."
Agent: "Creating API endpoint: api/app/api/sync/linked/submit/route.ts"
Agent: "Adding validation animations: green flash (correct), shake (incorrect)"
Agent: "Testing: Submit mixed placements, verify animations"
Agent: "✅ Phase 9 complete, turn submission working with animations"

# ===== PHASE 10-13: Hint, Completion, Polish =====
Agent: "Implementing hint API, scoreboard widget, completion screen..."
Agent: "Adding 10s polling during partner's turn..."
Agent: "Creating integration tests for full gameplay cycle..."
Agent: "Running: ./scripts/test_linked_game.sh"
Agent: "✅ Phases 10-13 complete! All tests passing."

# ===== FINAL SUMMARY =====
Agent: "🎉 Linked game implementation complete!

Deliverables:
- 25 Flutter files created (models, services, screens, widgets)
- 4 API endpoints implemented
- 1 database migration (linked_matches + linked_moves tables)
- 15 tests passing (API + widget + integration)
- 2 shell script tests passing

Feature complete:
✅ Side Quest card with 5 states, 10s polling
✅ Game screen with 7×9 grid, 4 cell types
✅ Drag & drop (rack ↔ grid, 3 operations)
✅ Turn submission with server validation
✅ Animations (correct/incorrect/word complete)
✅ Hint power-up (2 per player)
✅ Scoring (+10 letter, +word×10 bonus)
✅ Completion screen with confetti + stats
✅ +30 Love Points on completion
✅ Partner view with polling sync

Ready for manual QA and user testing!"
```

---

## 🆘 Getting Help

If you encounter issues:

1. **Check the specs**: Refer to `LINKED_IMPLEMENTATION_PLAN.md` for detailed task breakdowns
2. **Check reference files**: Look at Memory Flip implementation for patterns
3. **Check CLAUDE.md**: Project-wide conventions and critical rules
4. **Ask specific questions**: If specs are unclear, ask before guessing
5. **Report blockers**: Stop and report if fundamentally stuck (don't spin wheels)

---

**Good luck! 🚀 You have everything you need to build an amazing feature.**

---

**Document Version:** 1.0
**Last Updated:** 2025-11-25
**Status:** Ready for Agent Execution

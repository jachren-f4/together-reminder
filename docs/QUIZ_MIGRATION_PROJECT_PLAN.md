# Quiz Migration Project Plan

**Goal**: Migrate Classic Quiz, Affirmation Quiz, and You-or-Me to the Linked/WordSearch server-centric architecture.

**Estimated Duration**: 5 days

---

## Phase 1: Server Content Migration

Convert quiz content from Flutter assets to server-side JSON files (like Linked puzzles).

### Tasks

- [ ] **1.1** Create directory structure for quiz content
  ```
  api/data/puzzles/
  ├── classic-quiz/
  │   ├── lighthearted/
  │   ├── deep/
  │   └── spicy/
  ├── affirmation/
  │   ├── practical/
  │   ├── emotional/
  │   └── spiritual/
  └── you-or-me/
      ├── playful/
      ├── reflective/
      └── intimate/
  ```

- [ ] **1.2** Define JSON schema for Classic Quiz
  - 5 questions per quiz
  - Fields: quizId, title, branch, questions[]
  - Each question: id, text, choices[], category

- [ ] **1.3** Define JSON schema for Affirmation Quiz
  - 5 questions per quiz (5-point scale)
  - Fields: quizId, title, category, branch, description, questions[]
  - Each question: id, text, type="scale", scaleLabels[]

- [ ] **1.4** Define JSON schema for You-or-Me Quiz
  - 10 questions per quiz
  - Fields: quizId, title, branch, questions[]
  - Each question: id, prompt, content

- [ ] **1.5** Write migration script `api/scripts/migrate_quiz_content.ts`
  - Read from `assets/brands/togetherremind/data/quiz_questions.json`
  - Group questions by category
  - Generate pre-packaged quiz sets (5 questions each for classic)
  - Write to `api/data/puzzles/classic-quiz/{branch}/`

- [ ] **1.6** Run migration script for Classic Quiz content
  - Generate ~20 quiz files per branch
  - Create `quiz-order.json` for each branch

- [ ] **1.7** Run migration script for Affirmation Quiz content
  - Read from `affirmation_quizzes.json`
  - Generate quiz files per branch
  - Create `quiz-order.json` for each branch

- [ ] **1.8** Run migration script for You-or-Me content
  - Read from `you_or_me_questions.json`
  - Generate quiz files (10 questions each)
  - Create `quiz-order.json` for each branch

- [ ] **1.9** Copy quiz content to HolyCouples brand (if applicable)

### Phase 1 Testing

- [ ] **1.T1** Verify all JSON files are valid JSON (use `jq` or JSON validator)
- [ ] **1.T2** Verify quiz-order.json files reference existing quiz files
- [ ] **1.T3** Verify question counts: Classic=5, Affirmation=5, You-or-Me=10
- [ ] **1.T4** Verify all required fields are present in each quiz file
- [ ] **1.T5** Count total quizzes per branch (should have ~20 each)

---

## Phase 2: Database Schema

Create new `quiz_matches` table and prepare for fresh start.

### Tasks

- [ ] **2.1** Create migration file `api/supabase/migrations/023_quiz_matches.sql`
  ```sql
  CREATE TABLE quiz_matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id UUID NOT NULL REFERENCES couples(id),
    quiz_id TEXT NOT NULL,
    quiz_type TEXT NOT NULL,  -- 'classic' | 'affirmation' | 'you_or_me'
    branch TEXT NOT NULL,
    status TEXT DEFAULT 'active',
    player1_answers JSONB DEFAULT '[]',
    player2_answers JSONB DEFAULT '[]',
    player1_answer_count INT DEFAULT 0,
    player2_answer_count INT DEFAULT 0,
    current_turn_user_id UUID,
    turn_number INT DEFAULT 0,
    match_percentage INT,
    player1_score INT DEFAULT 0,
    player2_score INT DEFAULT 0,
    player1_id UUID NOT NULL,
    player2_id UUID NOT NULL,
    date DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    UNIQUE(couple_id, quiz_type, date)
  );

  CREATE INDEX idx_quiz_matches_couple ON quiz_matches(couple_id);
  CREATE INDEX idx_quiz_matches_date ON quiz_matches(date);
  ```

- [ ] **2.2** Run migration via Supabase CLI
  ```bash
  cd api && npx supabase db push
  ```

- [ ] **2.3** Verify table created in Supabase dashboard

- [ ] **2.4** Create migration file `api/supabase/migrations/024_drop_quiz_sessions.sql` (DO NOT RUN YET)
  - This will be run after Phase 6 testing is complete
  ```sql
  DROP TABLE IF EXISTS quiz_sessions;
  ```

### Phase 2 Testing

- [ ] **2.T1** Verify `quiz_matches` table exists in Supabase
- [ ] **2.T2** Verify all columns have correct types
- [ ] **2.T3** Verify UNIQUE constraint on (couple_id, quiz_type, date)
- [ ] **2.T4** Test inserting a sample row via SQL
- [ ] **2.T5** Test unique constraint prevents duplicate quiz per day

---

## Phase 3: API Routes

Create new API routes mirroring Linked/WordSearch pattern.

### Tasks

- [ ] **3.1** Create `api/app/api/sync/quiz-match/route.ts`
  - POST: Create or get existing match for today
  - GET: Poll match state by matchId
  - Load quiz from JSON file based on branch progression
  - Return: match + quiz + gameState

- [ ] **3.2** Create `api/app/api/sync/quiz-match/submit/route.ts`
  - POST: Submit all answers at once
  - Validate answers array length matches question count
  - Calculate match percentage when both users submit
  - Award 30 LP on completion

- [ ] **3.3** Create `api/app/api/sync/you-or-me-match/route.ts`
  - POST: Create or get existing match for today
  - GET: Poll match state
  - Load quiz from JSON file
  - Return: match + quiz + gameState

- [ ] **3.4** Create `api/app/api/sync/you-or-me-match/submit/route.ts`
  - POST: Submit single answer (incremental)
  - Track answer count per user
  - Award 30 LP when both users complete all 10

- [ ] **3.5** Add helper function to load quiz JSON files
  ```typescript
  async function loadQuizFromFile(quizType: string, branch: string, quizId: string)
  ```

- [ ] **3.6** Add helper function for branch progression
  - Reuse existing `branch_progression` table
  - Add 'classicQuiz', 'affirmation', 'youOrMe' as activity_type values

- [ ] **3.7** Deploy API routes to Vercel
  ```bash
  cd api && vercel --prod
  ```

### Phase 3 Testing

- [ ] **3.T1** Test POST /api/sync/quiz-match creates new match (curl)
  ```bash
  curl -X POST "https://togetherremind-api.vercel.app/api/sync/quiz-match" \
    -H "Content-Type: application/json" \
    -H "X-Dev-User-Id: c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28" \
    -d '{"localDate": "2025-11-28", "quizType": "classic"}'
  ```

- [ ] **3.T2** Test POST /api/sync/quiz-match returns same match for same day

- [ ] **3.T3** Test GET /api/sync/quiz-match/{matchId} returns match state

- [ ] **3.T4** Test POST /api/sync/quiz-match/submit with valid answers
  ```bash
  curl -X POST "https://togetherremind-api.vercel.app/api/sync/quiz-match/submit" \
    -H "Content-Type: application/json" \
    -H "X-Dev-User-Id: c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28" \
    -d '{"matchId": "...", "answers": [0, 1, 2, 3, 4]}'
  ```

- [ ] **3.T5** Test submit with wrong answer count returns error

- [ ] **3.T6** Test submit as second user calculates match percentage

- [ ] **3.T7** Test POST /api/sync/you-or-me-match creates match

- [ ] **3.T8** Test POST /api/sync/you-or-me-match/submit incremental answer

- [ ] **3.T9** Test You-or-Me completion after 10 answers each

- [ ] **3.T10** Verify LP awarded on completion (check user_love_points table)

---

## Phase 4: Flutter Services & Models

Create new Flutter services mirroring LinkedService pattern.

### Tasks

- [ ] **4.1** Create `lib/models/quiz_match.dart`
  ```dart
  @HiveType(typeId: 20)
  class QuizMatch { ... }

  @HiveType(typeId: 21)
  class QuizPuzzle { ... }

  class QuizMatchState { ... }
  class QuizGameState { ... }
  class QuizSubmitResult { ... }
  ```

- [ ] **4.2** Create `lib/models/you_or_me_match.dart`
  ```dart
  @HiveType(typeId: 22)
  class YouOrMeMatch { ... }

  @HiveType(typeId: 23)
  class YouOrMePuzzle { ... }

  class YouOrMeMatchState { ... }
  class YouOrMeSubmitResult { ... }
  ```

- [ ] **4.3** Run build_runner to generate Hive adapters
  ```bash
  flutter pub run build_runner build --delete-conflicting-outputs
  ```

- [ ] **4.4** Register new Hive adapters in `storage_service.dart`

- [ ] **4.5** Create `lib/services/quiz_match_service.dart`
  - `getOrCreateMatch(quizType, branch?)`
  - `pollMatchState(matchId)`
  - `submitAnswers(matchId, answers)`
  - `startPolling(matchId, onUpdate)` - 10s intervals
  - `stopPolling()`

- [ ] **4.6** Create `lib/services/you_or_me_match_service.dart`
  - `getOrCreateMatch(branch?)`
  - `pollMatchState(matchId)`
  - `submitAnswer(matchId, questionIndex, answer)`
  - `startPolling(matchId, onUpdate)`
  - `stopPolling()`

- [ ] **4.7** Add API request helper methods with auth headers

- [ ] **4.8** Add local caching for matches in Hive

### Phase 4 Testing

- [ ] **4.T1** Verify Hive adapters generated without errors
- [ ] **4.T2** Verify adapters registered in storage_service.dart
- [ ] **4.T3** Unit test: QuizMatchService.getOrCreateMatch() returns state
- [ ] **4.T4** Unit test: QuizMatchService.submitAnswers() returns result
- [ ] **4.T5** Unit test: YouOrMeMatchService incremental submission
- [ ] **4.T6** Verify polling starts and stops correctly
- [ ] **4.T7** Verify matches are cached in Hive after API calls

---

## Phase 5: Screen Updates

Update game screens to use new services.

### Tasks

- [ ] **5.1** Update `lib/screens/quiz_intro_screen.dart`
  - Use QuizMatchService instead of QuizService
  - Remove local session creation
  - Navigate to game screen with match data

- [ ] **5.2** Update `lib/screens/quiz_screen.dart` (Classic Quiz)
  - Load match via QuizMatchService.getOrCreateMatch()
  - Display questions from match.quiz.questions
  - Submit via QuizMatchService.submitAnswers()
  - Start polling if waiting for partner
  - Navigate to results when complete

- [ ] **5.3** Update `lib/screens/affirmation_intro_screen.dart`
  - Use QuizMatchService with quizType='affirmation'

- [ ] **5.4** Update `lib/screens/affirmation_question_screen.dart`
  - Same pattern as quiz_screen.dart
  - 5-point scale instead of multiple choice

- [ ] **5.5** Update `lib/screens/you_or_me_game_screen.dart`
  - Use YouOrMeMatchService
  - Submit answers incrementally (one at a time)
  - Poll for partner progress
  - Navigate to results when both complete all 10

- [ ] **5.6** Update results screens to use new match data structure
  - `quiz_results_screen.dart`
  - `affirmation_results_screen.dart`
  - `you_or_me_results_screen.dart`

- [ ] **5.7** Update `lib/services/quest_type_manager.dart`
  - Remove local QuizSession creation
  - Use simple contentId format: `classic:2025-11-28`
  - Remove denormalized quizName, formatType from quest

- [ ] **5.8** Update `lib/widgets/quest_card.dart`
  - Get title/metadata from API response, not local session

- [ ] **5.9** Update `lib/widgets/daily_quests_widget.dart`
  - Remove QuizSession lookups
  - Use quest type to determine display

- [ ] **5.10** Update `lib/services/quest_navigation_service.dart`
  - Navigate to quiz screens without local session parameter

### Phase 5 Testing

- [ ] **5.T1** Test Classic Quiz intro screen loads without errors
- [ ] **5.T2** Test Classic Quiz game screen displays questions
- [ ] **5.T3** Test Classic Quiz submission works
- [ ] **5.T4** Test Classic Quiz waiting screen shows while polling
- [ ] **5.T5** Test Classic Quiz results screen displays match %
- [ ] **5.T6** Test Affirmation Quiz full flow
- [ ] **5.T7** Test You-or-Me incremental answer submission
- [ ] **5.T8** Test You-or-Me completion flow
- [ ] **5.T9** Test daily quest card displays correct title
- [ ] **5.T10** Test quest navigation works from home screen

---

## Phase 6: Two-Device Integration Testing

Test complete flows on two physical devices.

### Tasks

- [ ] **6.1** Prepare test environment
  - Delete existing quiz_matches for test couple
  - Clear Firebase RTDB (if still used)
  - Build and deploy to both iPhones

- [ ] **6.2** Test Classic Quiz - Device A starts
  - Device A: Tap Classic Quiz quest
  - Device A: Answer 5 questions, submit
  - Device A: See "Waiting for partner" screen
  - Verify: Match created in Supabase with player1_answers

- [ ] **6.3** Test Classic Quiz - Device B completes
  - Device B: Tap same Classic Quiz quest
  - Device B: See same 5 questions
  - Device B: Answer and submit
  - Both devices: See results with match %
  - Verify: LP awarded to both users

- [ ] **6.4** Test Affirmation Quiz two-device flow
  - Same pattern as Classic Quiz
  - Verify 5-point scale works correctly

- [ ] **6.5** Test You-or-Me two-device flow
  - Device A: Answer question 1
  - Device B: Answer question 1
  - Continue alternating until both complete 10
  - Verify incremental progress visible
  - Verify LP awarded on completion

- [ ] **6.6** Test cooldown behavior
  - Try to start same quiz type again same day
  - Verify appropriate message shown

- [ ] **6.7** Test offline behavior
  - Start quiz while online
  - Go offline
  - Verify cached match is accessible (read-only)

- [ ] **6.8** Test quest completion tracking
  - Complete a quiz via daily quest
  - Verify quest shows as completed
  - Verify activity recorded for streaks

### Phase 6 Testing Checklist

- [ ] **6.T1** Classic Quiz: Both devices see same questions ✓/✗
- [ ] **6.T2** Classic Quiz: Match % calculated correctly ✓/✗
- [ ] **6.T3** Classic Quiz: LP awarded to both users ✓/✗
- [ ] **6.T4** Affirmation Quiz: Scale answers recorded correctly ✓/✗
- [ ] **6.T5** You-or-Me: Incremental answers work ✓/✗
- [ ] **6.T6** You-or-Me: Both complete all 10 ✓/✗
- [ ] **6.T7** Daily quest completion tracked ✓/✗
- [ ] **6.T8** No Firebase RTDB errors in console ✓/✗

---

## Phase 7: Cleanup

Remove old code and finalize migration.

### Tasks

- [ ] **7.1** Delete old Flutter services
  - `lib/services/quiz_service.dart`
  - `lib/services/quiz_api_service.dart`
  - `lib/services/quiz_question_bank.dart`
  - `lib/services/affirmation_quiz_bank.dart`
  - `lib/services/you_or_me_service.dart`

- [ ] **7.2** Delete old Flutter models
  - `lib/models/quiz_session.dart`
  - `lib/models/quiz_session.g.dart`

- [ ] **7.3** Delete old API routes
  - `api/app/api/sync/quiz/` (entire directory)
  - `api/app/api/sync/you-or-me/` (entire directory)

- [ ] **7.4** Run migration to drop old table
  ```bash
  cd api && npx supabase db push  # runs 024_drop_quiz_sessions.sql
  ```

- [ ] **7.5** Remove quiz assets from Flutter (OPTIONAL - can keep as backup)
  - `assets/brands/*/data/quiz_questions.json`
  - `assets/brands/*/data/affirmation_quizzes.json`
  - `assets/brands/*/data/you_or_me_questions.json`

- [ ] **7.6** Update pubspec.yaml to remove unused asset references

- [ ] **7.7** Update CLAUDE.md documentation
  - Remove references to old QuizSession pattern
  - Add documentation for new QuizMatch pattern
  - Update file locations reference

- [ ] **7.8** Clean up unused imports across codebase
  ```bash
  flutter analyze
  ```

- [ ] **7.9** Final build and deploy
  ```bash
  flutter build apk --release
  flutter build ios --release
  ```

### Phase 7 Testing

- [ ] **7.T1** Verify `flutter analyze` passes with no errors
- [ ] **7.T2** Verify app builds successfully for Android
- [ ] **7.T3** Verify app builds successfully for iOS
- [ ] **7.T4** Verify no references to deleted files in codebase
- [ ] **7.T5** Verify quiz_sessions table is dropped
- [ ] **7.T6** Final smoke test: Complete one quiz on both devices

---

## Summary

| Phase | Tasks | Testing Tasks | Estimated Time |
|-------|-------|---------------|----------------|
| 1. Server Content | 9 | 5 | 4 hours |
| 2. Database Schema | 4 | 5 | 1 hour |
| 3. API Routes | 7 | 10 | 4 hours |
| 4. Flutter Services | 8 | 7 | 4 hours |
| 5. Screen Updates | 10 | 10 | 6 hours |
| 6. Integration Testing | 8 | 8 | 4 hours |
| 7. Cleanup | 9 | 6 | 2 hours |
| **Total** | **55** | **51** | **~25 hours** |

---

## Rollback Plan

If critical issues are found during Phase 6 testing:

1. **Keep old API routes** until Phase 7 - they still work
2. **Keep quiz_sessions table** - don't drop until confirmed working
3. **Revert Flutter changes** via git if needed
4. **Quiz content in assets** still exists as backup

The parallel existence of old and new systems during Phases 3-6 provides a safety net.

---

## Success Criteria

- [ ] Both devices see identical quiz questions
- [ ] No "empty quiz" bugs on partner device
- [ ] Match percentage calculated correctly
- [ ] LP awarded on quiz completion
- [ ] Daily quest completion tracked
- [ ] No Firebase RTDB sync issues
- [ ] Consistent architecture with Linked/WordSearch

# Quiz Match System

## Quick Reference

| Item | Location |
|------|----------|
| Quiz Service | `lib/services/quiz_match_service.dart` |
| Unified Game Service | `lib/services/unified_game_service.dart` |
| Quiz Model | `lib/models/quiz_match.dart` |
| Game Screen | `lib/screens/quiz_match_game_screen.dart` |
| Waiting Screen | `lib/screens/quiz_match_waiting_screen.dart` |
| Results Screen | `lib/screens/quiz_match_results_screen.dart` |
| Intro Screens | `lib/screens/quiz_intro_screen.dart`, `affirmation_intro_screen.dart` |
| API Play Route | `api/app/api/sync/game/[type]/play/route.ts` |
| Game Handler | `api/lib/game/handler.ts` |
| Quiz Content | `api/data/quizzes/` |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      Quiz Match Types                            │
│                                                                  │
│   ┌──────────────────┐         ┌──────────────────┐             │
│   │  Classic Quiz    │         │ Affirmation Quiz │             │
│   │  (classic)       │         │  (affirmation)   │             │
│   └──────────────────┘         └──────────────────┘             │
│            │                            │                        │
│            └────────────┬───────────────┘                        │
│                         ▼                                        │
│              UnifiedGameService                                  │
│                         │                                        │
│                         ▼                                        │
│              POST /api/sync/game/{type}/play                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## Quiz Types

| Type | Slot | Questions | Content Source |
|------|------|-----------|----------------|
| Classic | 0 | 5 multiple choice | `api/data/quizzes/classic/{branch}/` |
| Affirmation | 1 | 5 multiple choice | `api/data/quizzes/affirmation/{branch}/` |

### Branches
Each quiz type has themed branches for progression:
- **Classic:** lighthearted, meaningful, connection, attachment, growth
- **Affirmation:** emotional, practical, connection, attachment, growth

---

## Data Flow

### Starting a Quiz
```
User taps Quest Card
         │
         ▼
QuizIntroScreen (or AffirmationIntroScreen)
         │
         ▼ (tap "Let's Play")
         │
QuizMatchGameScreen
         │
         ▼
_service.getOrCreateMatch(quizType)
         │
         ▼
POST /api/sync/game/{type}/play
  { localDate: "2024-12-16" }
         │
    ┌────┴────────────────────────┐
    ▼                             ▼
Match Exists                 Create New Match
(return existing)            (load quiz, store in DB)
    │                             │
    └─────────────┬───────────────┘
                  ▼
         Return GamePlayResponse
         (match + quiz questions)
```

### Submitting Answers
```
User answers all 5 questions
         │
         ▼
_service.submitAnswers(matchId, answers, quizType)
         │
         ▼
POST /api/sync/game/{type}/play
  { matchId: "uuid", answers: [0,1,2,1,0] }
         │
         ▼
Server stores answers
         │
    ┌────┴────────────────────────┐
    ▼                             ▼
Both Answered              Waiting for Partner
    │                             │
    ▼                             ▼
Mark Completed             Return waiting state
Award LP (30)                    │
    │                             ▼
    ▼                   QuizMatchWaitingScreen
QuizMatchResultsScreen
```

### Waiting Screen Polling
```
QuizMatchWaitingScreen
         │
         ▼
_service.startPolling(matchId, onUpdate, quizType)
         │
         ▼ (every 5 seconds)
         │
POST /api/sync/game/{type}/play
  { matchId: "uuid" }
         │
         ▼
Check if partner answered
         │
    ┌────┴────────────────────────┐
    ▼                             ▼
isCompleted = true          Still waiting
    │                             │
    ▼                             ▼
Navigate to Results         Continue polling
```

---

## Key Rules

### 1. Server-Centric Architecture
Server provides quiz content and manages matches:

```dart
// ✅ CORRECT - Server provides content
final gameState = await _service.getOrCreateMatch(quizType);
final questions = gameState.quiz?.questions;

// ❌ WRONG - Don't load content locally
final questions = await QuizQuestionBank().loadQuestions(branch);
```

### 2. Match Detection on Entry
Game screen checks if user already answered:

```dart
Future<void> _loadGameState() async {
  final gameState = await _service.getOrCreateMatch(widget.quizType);

  if (gameState.hasUserAnswered) {
    if (gameState.isCompleted) {
      // Go to results
      Navigator.of(context).pushReplacement(QuizMatchResultsScreen(...));
    } else {
      // Go to waiting
      Navigator.of(context).pushReplacement(QuizMatchWaitingScreen(...));
    }
    return;
  }
  // Otherwise show quiz
}
```

### 3. Singleton Callback Pattern
QuizMatchService is a singleton - callbacks must be protected:

```dart
// In startPolling:
_onStateUpdate = onUpdate;  // Set callback FIRST

// In stopPolling:
void stopPolling({String? matchId}) {
  final wasStopped = _unifiedService.stopPolling(matchId: matchId);
  if (wasStopped) {
    _onStateUpdate = null;  // Only clear if actually stopped
  }
}
```

### 4. Quiz Type Through Chain
Always pass `quizType` through the entire chain:

```dart
// Game screen
QuizMatchGameScreen(quizType: 'affirmation', questId: quest.id)

// Submit
await _service.submitAnswers(matchId: matchId, answers: answers, quizType: widget.quizType)

// Waiting screen
QuizMatchWaitingScreen(matchId: matchId, quizType: widget.quizType, questId: widget.questId)
```

### 5. LP Awards Server-Side
Never award LP locally - sync from server:

```dart
// ❌ WRONG - double counting
await _arenaService.awardLovePoints(30, 'quiz_complete');

// ✅ CORRECT - sync from server
await LovePointService.fetchAndSyncFromServer();
```

---

## Common Bugs & Fixes

### 1. Waiting Screen Stuck
**Symptom:** User on waiting screen, partner completes, but screen doesn't advance.

**Cause:** Callback cleared by game screen dispose.

**Fix:** Stop polling with matchId parameter:
```dart
@override
void dispose() {
  _service.stopPolling(matchId: widget.matchId);  // Pass matchId
  super.dispose();
}
```

### 2. Wrong Quiz Type on Results
**Symptom:** Results show "Classic Quiz" for Affirmation quiz.

**Cause:** `quizType` not preserved in match model.

**Fix:** Ensure match.quizType is set from server response:
```dart
final match = QuizMatch(
  quizType: response.match.quizType,  // Must come from server
  // ...
);
```

### 3. Answers Appear Swapped
**Symptom:** User sees their answers labeled as partner's.

**Cause:** player1Id mismatch.

**Fix:** Set player1Id to current user in game state conversion:
```dart
final match = QuizMatch(
  player1Id: userId,  // Set to current user
  player2Id: '',
  player1Answers: response.result?.userAnswers ?? [],
  player2Answers: response.result?.partnerAnswers ?? [],
  // ...
);
```

### 4. Quiz Not Advancing After Debug
**Symptom:** User returns from debug menu, sees same quiz.

**Cause:** Missing reload on route pop.

**Fix:** Implement `didPopNext()`:
```dart
@override
void didPopNext() {
  _reloadIfMatchChanged();
}
```

### 5. Unlock Not Triggering
**Symptom:** Complete both quizzes but You or Me stays locked.

**Cause:** Not passing quizType to unlock notification.

**Fix:**
```dart
await unlockService.notifyCompletion(
  UnlockTrigger.dailyQuiz,
  quizType: widget.match.quizType,  // Must pass quiz type
);
```

### 6. UI Freezes on Answer Submission
**Symptom:** After answering the last question, screen appears to freeze momentarily.

**Cause:** No loading indicator while waiting for server response.

**Fix:** Add loading overlay when `_isSubmitting` is true:
```dart
// Wrap body content in Stack
body: SafeArea(
  child: Stack(
    children: [
      Column(...),  // Main content

      // Loading overlay when submitting
      if (_isSubmitting)
        Container(
          color: EditorialStyles.ink.withValues(alpha: 0.3),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
    ],
  ),
),
```

---

## Debugging Tips

### Check Match State
```dart
final state = await _service.pollMatchState(matchId, quizType: 'classic');
debugPrint('Match: ${state.match.id}');
debugPrint('Status: ${state.match.status}');
debugPrint('UserAnswered: ${state.hasUserAnswered}');
debugPrint('PartnerAnswered: ${state.hasPartnerAnswered}');
debugPrint('Completed: ${state.isCompleted}');
```

### View Server Response
```bash
curl -X POST "https://api-joakim-achrens-projects.vercel.app/api/sync/game/classic/play" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"localDate": "2024-12-16"}'
```

### Force New Match
1. Delete from database: `DELETE FROM quiz_matches WHERE date = '2024-12-16'`
2. Restart app

### Enable Logging
```dart
Logger.debug('...', service: 'quiz');
```

---

## API Reference

### POST /api/sync/game/{type}/play

Unified endpoint for quiz operations.

**Path:** `type` = `classic` | `affirmation` | `you_or_me`

**Request Variants:**

1. **Start Game:**
```json
{ "localDate": "2024-12-16" }
```

2. **Submit Answers:**
```json
{ "matchId": "uuid", "answers": [0, 1, 2, 1, 0] }
```

3. **Check State:**
```json
{ "matchId": "uuid" }
```

**Response:**
```json
{
  "success": true,
  "match": {
    "id": "uuid",
    "quizId": "q_001",
    "quizType": "classic",
    "branch": "lighthearted",
    "status": "in_progress",
    "date": "2024-12-16"
  },
  "state": {
    "canSubmit": true,
    "userAnswered": false,
    "partnerAnswered": true,
    "isCompleted": false,
    "isMyTurn": true
  },
  "quiz": {
    "id": "q_001",
    "name": "Relationship Favorites",
    "questions": [...]
  },
  "result": null
}
```

**When Completed:**
```json
{
  "result": {
    "matchPercentage": 80,
    "lpEarned": 30,
    "userAnswers": [0, 1, 2, 1, 0],
    "partnerAnswers": [0, 1, 2, 0, 0]
  }
}
```

---

## Screen Flow

```
┌────────────────┐     ┌────────────────┐     ┌────────────────┐
│  Quest Card    │────>│  Intro Screen  │────>│  Game Screen   │
│  (tap)         │     │  (Let's Play)  │     │  (5 questions) │
└────────────────┘     └────────────────┘     └────────────────┘
                                                      │
                              ┌───────────────────────┤
                              ▼                       ▼
                       Partner Waiting         Already Answered
                              │                       │
                              ▼                       ▼
                    ┌────────────────┐     ┌────────────────┐
                    │ Waiting Screen │────>│ Results Screen │
                    │  (polling)     │     │  (% match, LP) │
                    └────────────────┘     └────────────────┘
                                                      │
                                                      ▼
                                                 Home Screen
```

---

## File Reference

| File | Purpose |
|------|---------|
| `quiz_match_service.dart` | Service layer wrapping UnifiedGameService |
| `unified_game_service.dart` | Generic game service for all game types |
| `quiz_match.dart` | Match and quiz models |
| `quiz_match_game_screen.dart` | Question UI with answer selection |
| `quiz_match_waiting_screen.dart` | Polling while partner answers |
| `quiz_match_results_screen.dart` | Match percentage and comparison |
| `quiz_intro_screen.dart` | Classic quiz intro |
| `affirmation_intro_screen.dart` | Affirmation quiz intro |
| `handler.ts` | Server-side game logic |
| `route.ts` | API endpoint handler |

---

## Changelog

| Date | Change |
|------|--------|
| 2025-12-16 | Added loading overlay to game screen during answer submission |
| 2025-12-16 | Changed waiting screen buttons to EditorialPrimaryButton (black bg) for consistency |
| 2025-12-16 | Initial documentation |

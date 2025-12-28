# You or Me Game

## Quick Reference

| Item | Location |
|------|----------|
| Service | `lib/services/you_or_me_match_service.dart` |
| Model | `lib/models/you_or_me_match.dart` |
| Game Screen | `lib/screens/you_or_me_match_game_screen.dart` |
| Waiting Screen | `lib/screens/you_or_me_match_waiting_screen.dart` |
| Results Screen | `lib/screens/you_or_me_match_results_screen.dart` |
| Intro Screen | `lib/screens/you_or_me_match_intro_screen.dart` |
| API Play Route | `api/app/api/sync/game/[type]/play/route.ts` |
| Game Handler | `api/lib/game/handler.ts` |
| Content | `api/data/quizzes/you_or_me/{branch}/` |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     You or Me Game                               │
│                                                                  │
│   "Who is more likely to...?" questions                         │
│                                                                  │
│   ┌──────────────┐         ┌──────────────┐                     │
│   │   Partner    │   or    │     You      │                     │
│   │   (you = 0)  │         │   (me = 1)   │                     │
│   └──────────────┘         └──────────────┘                     │
│                                                                  │
│   Bulk submission - answer all questions, then submit           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Game Mechanics

### Question Format
Each question asks "Who is more likely to [scenario]?" with two choices:
- **Partner's name** (e.g., "Alice") → Encodes as `0` ("you" from user's perspective)
- **"Me"** → Encodes as `1`

### Scoring
- **Match:** Both partners picked the same person
- **Mismatch:** Partners picked different people
- **Score:** Percentage of matching answers

### Branches
Themed question sets for progression:
- playful, reflective, connection, attachment, growth

---

## Critical: Answer Encoding

### Relative Encoding Pattern
Answers are encoded **relative to the user**, not as absolute values:

```
User taps "Partner" → sends 0 (means "you")
User taps "Me"      → sends 1 (means "me")
```

### Server-Side Inversion
The server inverts Player 2's answers before comparison to account for perspective:

```typescript
// In handler.ts:calculateMatchPercentage()
// Example: Both pick Player1 (Alice)
// - Alice sends: 1 (me)
// - Bob sends: 0 (you = Alice)
// After inversion: Bob's 0 → 1
// Now both = 1 → MATCH!

const compareP2 = gameType === 'you_or_me'
  ? p2.map(v => v === 0 ? 1 : 0)  // Invert: 0↔1
  : p2;
```

### Why This Matters
**DO NOT** invert answers on the Flutter side. The server handles it:

```dart
// ✅ CORRECT - Send raw relative values
final answerIndices = answers.map((a) => a == 'me' ? 1 : 0).toList();

// ❌ WRONG - Don't try to "fix" encoding
// The server already handles perspective conversion
```

---

## Data Flow

### Game Start
```
User taps Quest Card
         │
         ▼
YouOrMeMatchIntroScreen
         │
         ▼ (tap "Let's Play")
         │
YouOrMeMatchGameScreen
         │
         ▼
_service.getOrCreateMatch()
         │
         ▼
POST /api/sync/game/you_or_me/play
  { localDate: "2024-12-16" }
         │
         ▼
Return match + questions
```

### Answer Submission (Bulk)
```
User answers all 5 questions
         │
         ▼
_service.submitAllAnswers(matchId, answers)
         │
         ▼
Convert: ['you', 'me', 'you'] → [0, 1, 0]
         │
         ▼
POST /api/sync/game/you_or_me/play
  { matchId: "uuid", answers: [0, 1, 0, ...] }
         │
    ┌────┴────────────────────────┐
    ▼                             ▼
Both Answered              Waiting for Partner
    │                             │
    ▼                             ▼
Server inverts P2 answers    YouOrMeMatchWaitingScreen
Calculate match %                 │
Award LP (30)                     │ (polling)
    │                             │
    ▼                             ▼
YouOrMeMatchResultsScreen    (partner submits)
                                  │
                                  ▼
                          YouOrMeMatchResultsScreen
```

---

## Key Rules

### 1. Bulk Submission Only
Unlike turn-based games, all answers are submitted at once:

```dart
// User answers all questions locally
_selectedAnswers.add('you');
_selectedAnswers.add('me');
// ...

// Then submits all at once
await _service.submitAllAnswers(
  matchId: matchId,
  answers: _selectedAnswers,  // Full list
);
```

### 2. Don't Invert Client-Side
Trust the server to handle perspective:

```dart
// ✅ CORRECT - Raw string to index conversion
final answerIndices = answers.map((a) => a == 'me' ? 1 : 0).toList();

// ❌ WRONG - Trying to be "smart"
final answerIndices = answers.map((a) {
  // Don't do perspective conversions here!
  return a == 'me' ? 0 : 1;
}).toList();
```

### 3. Use Match Percentage from Server
Server calculates the match percentage after inverting:

```dart
// Server response includes correct percentage
return YouOrMeBulkSubmitResult(
  matchPercentage: response.result?.matchPercentage,  // Use directly
  // ...
);
```

### 4. Redirect If Already Answered
Check on game load if user has already submitted:

```dart
if (gameState.myAnswerCount > 0) {
  if (gameState.isCompleted) {
    // Go to results
    Navigator.of(context).pushReplacement(YouOrMeMatchResultsScreen(...));
  } else {
    // Go to waiting
    Navigator.of(context).pushReplacement(YouOrMeMatchWaitingScreen(...));
  }
  return;
}
```

---

## Common Bugs & Fixes

### 1. Wrong Match Percentage
**Symptom:** Match percentage seems inverted (low when should be high).

**Cause:** Client-side answer inversion or raw answer comparison.

**Fix:** Trust server's `matchPercentage`:
```dart
final percentage = response.result?.matchPercentage ?? 0;
// Don't recalculate locally
```

### 2. Waiting Screen Stuck
**Symptom:** Partner completes but screen doesn't advance.

**Cause:** Singleton callback pattern - game screen dispose clears the waiting screen's callback.

**Fix:** Apply singleton callback protection pattern:
```dart
// In YouOrMeMatchService.stopPolling()
void stopPolling({String? matchId}) {
  final wasStopped = _unifiedService.stopPolling(matchId: matchId);
  // Only clear callback if polling was actually stopped
  if (wasStopped) {
    _onStateUpdate = null;
  }
}

// In waiting screen dispose - pass matchId
@override
void dispose() {
  _service.stopPolling(matchId: widget.matchId);
  super.dispose();
}
```

This prevents the game screen from clearing the waiting screen's callback when it disposes.

### 3. "Already submitted" Error
**Symptom:** Submit fails with "Already submitted answers".

**Cause:** User somehow submitted twice.

**Fix:** Check answer count before showing game:
```dart
if (gameState.myAnswerCount > 0) {
  // Redirect to waiting/results
}
```

### 4. Questions Show Partner as "You"
**Symptom:** Choice buttons show wrong names.

**Cause:** Partner data not loaded.

**Fix:** Load partner from storage:
```dart
final partner = _storage.getPartner();
final partnerName = partner?.name ?? 'Partner';
// Use partnerName for the "partner" choice
```

---

## Debugging Tips

### Check Answer Encoding
```dart
debugPrint('Answers: $_selectedAnswers');
// Should be ['you', 'me', 'you', ...]

final indices = answers.map((a) => a == 'me' ? 1 : 0).toList();
debugPrint('Indices: $indices');
// Should be [0, 1, 0, ...]
```

### View Server Response
```bash
curl -X POST "https://api-joakim-achrens-projects.vercel.app/api/sync/game/you_or_me/play" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"matchId": "uuid"}'
```

### Check Match State
```dart
final state = await _service.pollMatchState(matchId);
debugPrint('MyAnswerCount: ${state.myAnswerCount}');
debugPrint('PartnerAnswerCount: ${state.partnerAnswerCount}');
debugPrint('IsCompleted: ${state.isCompleted}');
```

---

## API Reference

### POST /api/sync/game/you_or_me/play

**Request Variants:**

1. **Start Game:**
```json
{ "localDate": "2024-12-16" }
```

2. **Submit Answers:**
```json
{
  "matchId": "uuid",
  "answers": [0, 1, 0, 1, 1]
}
```

3. **Check State:**
```json
{ "matchId": "uuid" }
```

**Response (completed):**
```json
{
  "success": true,
  "match": {
    "id": "uuid",
    "quizId": "yom_001",
    "quizType": "you_or_me",
    "branch": "playful",
    "status": "completed"
  },
  "state": {
    "userAnswered": true,
    "partnerAnswered": true,
    "isCompleted": true
  },
  "result": {
    "matchPercentage": 70,
    "lpEarned": 30,
    "userAnswers": [0, 1, 0, 1, 1],
    "partnerAnswers": [0, 0, 0, 1, 1]
  }
}
```

---

## Screen Flow

```
┌────────────────┐     ┌────────────────┐     ┌────────────────┐
│  Quest Card    │────>│  Intro Screen  │────>│  Game Screen   │
│  (locked if    │     │  (Let's Play)  │     │  (5 questions) │
│  quizzes not   │     └────────────────┘     │  bulk submit   │
│  done)         │                            └────────────────┘
└────────────────┘                                    │
                              ┌───────────────────────┤
                              ▼                       ▼
                       Partner Waiting         Already Answered
                              │                       │
                              ▼                       ▼
                    ┌────────────────┐     ┌────────────────┐
                    │ Waiting Screen │────>│ Results Screen │
                    │  (polling)     │     │  (% match)     │
                    └────────────────┘     └────────────────┘
```

---

## Unlock Requirement

You or Me is **locked** until both quizzes are completed:
1. Complete Classic Quiz (both partners)
2. Complete Affirmation Quiz (both partners)
3. You or Me unlocks

See `docs/features/UNLOCK_SYSTEM.md` for details.

---

## File Reference

| File | Purpose |
|------|---------|
| `you_or_me_match_service.dart` | Service wrapping UnifiedGameService |
| `you_or_me_match.dart` | Match model and state |
| `you_or_me_match_game_screen.dart` | Card-based question UI |
| `you_or_me_match_waiting_screen.dart` | Polling while partner answers |
| `you_or_me_match_results_screen.dart` | Match percentage display |
| `you_or_me_match_intro_screen.dart` | Game introduction |
| `handler.ts:calculateMatchPercentage()` | Answer inversion logic |

---

## Changelog

| Date | Change |
|------|--------|
| 2025-12-16 | Fixed waiting screen stuck bug (singleton callback protection pattern) |
| 2025-12-16 | Changed waiting screen buttons to EditorialPrimaryButton (black bg) for consistency |
| 2025-12-16 | Initial documentation |

# You or Me Game - Version 2 Redesign Specification

**Date:** 2025-11-15
**Version:** 2.0 - Two-Session Architecture Redesign
**Status:** Implementation approved
**Purpose:** Redesign "You or Me" to use the same resilient two-session architecture as quiz games

---

## Executive Summary

### Problem

The current "You or Me" implementation uses a **single shared session** for both users, which creates a critical race condition:
- When both devices start simultaneously, both generate separate sessions
- Users end up answering different questions
- Comparison becomes meaningless
- Quest completion fails

### Root Cause

**Quizzes work** because they use **two separate sessions** (one per user):
- Race condition creates duplicates, but that's expected behavior
- Each user has their own session by design
- More resilient to timing and sync issues

**You or Me breaks** because it requires **one shared session**:
- Race condition creates duplicate sessions with different questions
- Users must answer the SAME questions for comparison to work
- Fragile synchronization requirements

### Solution

**Adopt the quiz pattern**: Use **two separate sessions** (one per user) but with the SAME questions in both sessions.

**Key insight**: Keep the current UI/UX ("Who's more likely...?" with "Me"/"You" buttons) but interpret answers based on session ownership.

---

## Design Overview

### Current Architecture (V1 - Broken)

```
Daily Quest Generation
    ↓
Generate ONE You or Me session
    ↓
Both users access SAME session
    ↓
Race condition → Two sessions created
    ↓
Different questions → Broken comparison
```

### New Architecture (V2 - Resilient)

```
Daily Quest Generation
    ↓
Generate TWO You or Me sessions (like quizzes)
    ├─ Alice's session (questions Q1-Q10)
    └─ Bob's session (SAME questions Q1-Q10)
    ↓
Each user answers their own session
    ├─ Alice answers in her session
    └─ Bob answers in his session
    ↓
Compare answers across sessions
    ↓
Calculate matches
```

---

## Game Mechanics (Unchanged)

The user experience remains identical:

**Question Format**:
- "Who's more likely to forget an anniversary?"
- "Who's more..." / "Who would..." / "Which of you..."

**Answer Options**:
- "Me" button
- "You" (partner) button

**Answer Interpretation** (NEW):
- **Current**: "Me" = me, "You" = partner (in same session)
- **New**: "Me" = me, "You" = partner (but each user has own session)

---

## Data Model Changes

### YouOrMeSession Model

**Add Fields** (to match QuizSession pattern):

```dart
@HiveType(typeId: 22)
class YouOrMeSession extends HiveObject {
  // Existing fields
  @HiveField(0) String id;
  @HiveField(1) String userId;
  @HiveField(2) String partnerId;
  @HiveField(3) String? questId;
  @HiveField(4) List<YouOrMeQuestion> questions;
  @HiveField(5) Map<String, List<YouOrMeAnswer>>? answers;
  @HiveField(6) String status;
  @HiveField(7) DateTime createdAt;
  @HiveField(8) DateTime? completedAt;
  @HiveField(9) int? lpEarned;
  @HiveField(10) String coupleId;

  // NEW FIELDS (matching QuizSession)
  @HiveField(11) String initiatedBy;    // Who created this session
  @HiveField(12) String subjectUserId;  // Who this session belongs to
}
```

### YouOrMeAnswer Model

**Change answerType from String to bool**:

```dart
// OLD
@HiveField(3) String answerType;  // "me" or "you"

// NEW
@HiveField(3) bool answerValue;  // true = "Me", false = "You"
```

---

## Firebase Structure

### Current (Single Session - Broken)

```
/you_or_me_sessions/
  /{coupleId}/
    ├─ youorme_123/  ← ONE session
        ├─ userId: "alice"
        ├─ partnerId: "bob"
        ├─ questions: [Q1, Q2, ..., Q10]
        └─ answers:
            ├─ alice: ["me", "you", "me", ...]
            └─ bob: ["you", "me", "me", ...]
```

### New (Two Sessions - Resilient)

```
/you_or_me_sessions/
  /{coupleId}/
    ├─ youorme_alice_123/  ← Alice's session
    │   ├─ userId: "alice"
    │   ├─ partnerId: "bob"
    │   ├─ initiatedBy: "alice"
    │   ├─ subjectUserId: "alice"
    │   ├─ questions: [Q1, Q2, ..., Q10]  ← SAME QUESTIONS
    │   └─ answers:
    │       ├─ alice: [true, false, true, ...]   ← Alice's answers
    │       └─ bob: [false, true, false, ...]    ← Bob's answers in Alice's session
    │
    └─ youorme_bob_456/  ← Bob's session
        ├─ userId: "bob"
        ├─ partnerId: "alice"
        ├─ initiatedBy: "bob"
        ├─ subjectUserId: "bob"
        ├─ questions: [Q1, Q2, ..., Q10]  ← SAME QUESTIONS as Alice's
        └─ answers:
            ├─ alice: [false, true, false, ...]  ← Alice's answers in Bob's session
            └─ bob: [true, false, true, ...]     ← Bob's answers
```

**Key Point**: Both sessions contain the SAME 10 questions.

---

## Comparison Logic

### Current Logic (Single Session)

```dart
// Simple string comparison
bool matches = (aliceAnswer == "me" && bobAnswer == "you") ||
               (aliceAnswer == "you" && bobAnswer == "me");
```

### New Logic (Two Sessions)

For each question, determine who each person thinks is more likely:

```dart
// Question: "Who's more likely to forget anniversaries?"

// Alice's session (Q1)
bool aliceAnswerInHerSession = true;   // "Me" = Alice
bool bobAnswerInAliceSession = false;  // "You" = Alice (the subject)

// Determine who each person thinks
String aliceThinks = aliceAnswerInHerSession ? "alice" : "bob";  // alice
String bobThinks = bobAnswerInAliceSession ? "alice" : "bob";    // alice

// Do they agree?
bool match = (aliceThinks == bobThinks);  // true!
```

### Detailed Comparison Algorithm

```dart
int calculateMatches(YouOrMeSession aliceSession, YouOrMeSession bobSession) {
  int matches = 0;

  for (int i = 0; i < 10; i++) {
    // Get answers from Alice's session
    bool aliceAnswer = aliceSession.answers['alice'][i].answerValue;
    bool bobAnswer = aliceSession.answers['bob'][i].answerValue;

    // Determine who each thinks is more likely
    String aliceThinks = aliceAnswer ? 'alice' : 'bob';
    String bobThinks = bobAnswer ? 'alice' : 'bob';

    // Match if they agree
    if (aliceThinks == bobThinks) {
      matches++;
    }
  }

  return matches;
}
```

**Note**: We only need to check ONE session (Alice's) since both have the same questions.

---

## Example Walkthrough

**Question**: "Who's more likely to forget an anniversary?"

### Alice's Perspective (in her session)

- Sees question: "Who's more likely to forget an anniversary?"
- Taps "Me" → `answerValue: true`
- Meaning: Alice thinks **Alice** is more likely

### Bob's Perspective (in his session)

- Sees SAME question: "Who's more likely to forget an anniversary?"
- Taps "Me" → `answerValue: true`
- Meaning: Bob thinks **Bob** is more likely

### Comparison

- Alice thinks: **Alice**
- Bob thinks: **Bob**
- **No match** (they disagree)

### Alternative Scenario

Bob taps "You" instead:
- Bob's answer: `false` (You = Alice, from Bob's perspective)
- Bob thinks: **Alice**
- Alice thinks: **Alice**
- **Match!** (they agree)

---

## Implementation Changes

### Phase 1: Model Updates

**File**: `lib/models/you_or_me.dart`

```dart
// Add new fields
@HiveField(11) String initiatedBy;
@HiveField(12) String subjectUserId;

// Change answer type
class YouOrMeAnswer {
  // OLD: String answerType
  // NEW: bool answerValue
  @HiveField(3) bool answerValue;
}
```

**Run**: `flutter pub run build_runner build --delete-conflicting-outputs`

### Phase 2: Service Changes

**File**: `lib/services/you_or_me_service.dart`

**Update `startSession()` to create TWO sessions**:

```dart
Future<Map<String, YouOrMeSession>> generateDualSessions({
  required String userId,
  required String partnerId,
  String? questId,
}) async {
  final coupleId = QuestUtilities.generateCoupleId(userId, partnerId);
  final questions = await getRandomQuestions(10, coupleId);

  // Alice's session
  final aliceSession = YouOrMeSession(
    id: 'youorme_alice_${DateTime.now().millisecondsSinceEpoch}',
    userId: userId,  // Alice
    partnerId: partnerId,  // Bob
    initiatedBy: userId,  // Alice
    subjectUserId: userId,  // About Alice
    questId: questId,
    questions: questions,  // SAME questions
    answers: {},
    status: 'in_progress',
    createdAt: DateTime.now(),
    coupleId: coupleId,
  );

  // Bob's session (SAME questions!)
  final bobSession = YouOrMeSession(
    id: 'youorme_bob_${DateTime.now().millisecondsSinceEpoch}',
    userId: partnerId,  // Bob
    partnerId: userId,  // Alice
    initiatedBy: partnerId,  // Bob
    subjectUserId: partnerId,  // About Bob
    questId: questId,
    questions: questions,  // SAME questions
    answers: {},
    status: 'in_progress',
    createdAt: DateTime.now(),
    coupleId: coupleId,
  );

  // Save both sessions
  await _storage.saveYouOrMeSession(aliceSession);
  await _storage.saveYouOrMeSession(bobSession);

  // Sync both to Firebase
  await _syncSessionToRTDB(aliceSession);
  await _syncSessionToRTDB(bobSession);

  return {
    'alice': aliceSession,
    'bob': bobSession,
  };
}
```

**Update comparison logic**:

```dart
Map<String, dynamic> calculateResults(YouOrMeSession session) {
  // Load partner's session to compare
  final partnerSession = _storage.getYouOrMeSessionByUserId(session.partnerId);

  int matches = 0;
  for (int i = 0; i < session.questions.length; i++) {
    final myAnswer = session.answers[session.userId][i].answerValue;
    final partnerAnswer = session.answers[session.partnerId][i].answerValue;

    // Determine who each thinks is more likely
    final iThink = myAnswer ? session.userId : session.partnerId;
    final partnerThinks = partnerAnswer ? session.partnerId : session.userId;

    if (iThink == partnerThinks) {
      matches++;
    }
  }

  return {
    'matches': matches,
    'agreementPercentage': (matches / 10 * 100).round(),
  };
}
```

### Phase 3: Quest Generation Changes

**File**: `main.dart` (quest generation)

```dart
// Generate TWO sessions (like quizzes)
final sessions = await YouOrMeService().generateDualSessions(
  userId: currentUserId,
  partnerId: partnerUserId,
  questId: questId,
);

// Quest points to user's OWN session
final quest = DailyQuest(
  id: questId,
  contentId: sessions[currentUserId]!.id,  // Each user gets their own session
  questType: QuestType.youOrMe,
  formatType: 'you_or_me',
  quizName: 'You or Me',
  // ...
);
```

### Phase 4: UI Changes (Minimal)

**File**: `lib/screens/you_or_me_game_screen.dart`

Update answer submission to use `bool` instead of `String`:

```dart
// OLD
void _handleAnswer(String answerType) {
  final answer = YouOrMeAnswer(
    questionId: currentQuestion.id,
    answerType: answerType,  // "me" or "you"
    answeredAt: DateTime.now(),
  );
}

// NEW
void _handleAnswer(bool answerValue) {
  final answer = YouOrMeAnswer(
    questionId: currentQuestion.id,
    answerValue: answerValue,  // true or false
    answeredAt: DateTime.now(),
  );
}

// Button callbacks
onTap: () => _handleAnswer(true),   // "Me" button
onTap: () => _handleAnswer(false),  // "You" button
```

---

## Benefits

### Architecture
- ✅ **Unified system** - Same architecture as quizzes
- ✅ **Resilient** - Race condition doesn't break anything
- ✅ **Maintainable** - One pattern for all couple games
- ✅ **Scalable** - Easy to add new game types

### Reliability
- ✅ No timing dependencies
- ✅ No session sync issues
- ✅ Each user can complete independently
- ✅ No "waiting for partner" blocking during generation

### User Experience
- ✅ **No UI changes** - looks exactly the same
- ✅ **No learning curve** - works as expected
- ✅ More reliable quest completion
- ✅ Faster response times (no sync delays)

---

## Migration Strategy

### Backward Compatibility

**Old sessions** (single-session format):
- Keep existing data readable
- Add detection in `getSession()` to handle both formats
- Show message: "This is an old You or Me game"

**New sessions** (two-session format):
- All new games use two-session format
- Old sessions can still be viewed (read-only)

### Cleanup
- After 30 days, old single-session data auto-deletes
- No manual migration needed

---

## Implementation Checklist

### Phase 1: Data Model Updates ✅
- [ ] Add `initiatedBy` and `subjectUserId` fields to `YouOrMeSession`
- [ ] Change `answerType: String` to `answerValue: bool` in `YouOrMeAnswer`
- [ ] Run Hive build_runner
- [ ] Update Firebase rules (already using couple ID paths)

### Phase 2: Session Generation ✅
- [ ] Create `generateDualSessions()` method in `YouOrMeService`
- [ ] Ensure both sessions use SAME question IDs
- [ ] Update session ID format to include subject (e.g., `youorme_alice_123`)
- [ ] Save both sessions to Hive
- [ ] Sync both sessions to Firebase

### Phase 3: Session Loading ✅
- [ ] Update quest card tap to load user's OWN session
- [ ] Modify navigation based on `subjectUserId`
- [ ] Ensure correct session selected for current user

### Phase 4: Answer Submission ✅
- [ ] Update "Me" button to submit `true`
- [ ] Update "You" button to submit `false`
- [ ] Modify Firebase sync to store boolean values
- [ ] Update Hive storage to store boolean values

### Phase 5: Results Comparison ✅
- [ ] Implement new comparison logic
- [ ] Load BOTH sessions for comparison
- [ ] Calculate matches using new algorithm
- [ ] Update results screen

### Phase 6: Testing ✅
- [ ] Test with clean Firebase data
- [ ] Test race condition scenario (both start simultaneously)
- [ ] Verify duplicates don't break anything
- [ ] Test answer submission and sync
- [ ] Test results calculation

---

## Technical Notes

### Why This Works

The key insight: Even though each user has their own session, they're answering the SAME questions.

**Comparison works because**:
1. Both sessions have identical question IDs (Q1-Q10)
2. Answers are boolean (true/false)
3. We determine who each person thinks based on:
   - Answer value (true = me, false = you)
   - Session owner (whose session is being answered)

### Example: Agreement Detection

**Question**: "Who's more likely to forget an anniversary?"

**Alice's Session**:
- Alice answers: `true` ("Me" = Alice is more likely)
- Bob answers: `false` ("You" = Alice is more likely, from Bob's perspective)
- Interpretation: Alice thinks Alice, Bob thinks Alice → **Match!**

**Bob's Session**:
- Bob answers: `false` ("You" = Alice is more likely, from Bob's perspective)
- Alice answers: `false` ("You" = Bob is not more likely = Alice is more likely)
- Interpretation: Bob thinks Alice, Alice thinks Alice → **Match!**

Both sessions show the same match because the underlying truth is the same.

---

## References

- See `lib/services/quiz_service.dart` for quiz session generation pattern
- See `lib/models/quiz.dart` for QuizSession model structure
- See `database.rules.json` for couple ID path security rules
- See `YOU_OR_ME_GAME_SPEC_V1_OLD.md` for original single-session design

---

**Version**: 2.0
**Date**: 2025-11-15
**Status**: Ready for implementation
**Estimated Time**: 6-8 hours (model changes, service updates, testing)

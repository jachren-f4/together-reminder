# Unlock System

## Quick Reference

| Item | Location |
|------|----------|
| Unlock Service | `lib/services/unlock_service.dart` |
| Celebration Widget | `lib/widgets/unlock_celebration.dart` |
| LP Intro Overlay | `lib/widgets/lp_intro_overlay.dart` |
| API Unlock Route | `api/app/api/unlocks/route.ts` |
| API Complete Route | `api/app/api/unlocks/complete/route.ts` |
| DB Table | `couple_unlocks` |

---

## Unlock Chain

**NOTE:** No LP is awarded for unlocking features. LP only comes from completing games.

```
Pairing Complete
       │
       ▼
┌──────────────────┐
│  Welcome Quiz    │  (Always available)
└──────────────────┘
       │ completes
       ▼
┌──────────────────┐     ┌──────────────────┐
│  Classic Quiz    │     │ Affirmation Quiz │
│  (Daily Slot 0)  │     │  (Daily Slot 1)  │
└──────────────────┘     └──────────────────┘
       │ completes              │ completes
       └──────────┬─────────────┘
                  │ BOTH must complete
                  ▼
         ┌──────────────────┐
         │    You or Me     │
         │  (Daily Slot 2)  │
         └──────────────────┘
                  │ completes
                  ▼
         ┌──────────────────┐
         │     Linked       │
         │   (Side Quest)   │
         └──────────────────┘
                  │ completes
                  ▼
         ┌──────────────────┐
         │   Word Search    │
         │   (Side Quest)   │
         └──────────────────┘
                  │ completes
                  ▼
         ┌──────────────────┐
         │ Steps Together   │
         │   (Side Quest)   │
         └──────────────────┘
```

---

## Data Model

### UnlockState
```dart
class UnlockState {
  final String coupleId;
  final bool welcomeQuizCompleted;
  final bool classicQuizUnlocked;
  final bool classicQuizCompleted;
  final bool affirmationQuizUnlocked;
  final bool affirmationQuizCompleted;
  final bool youOrMeUnlocked;
  final bool linkedUnlocked;
  final bool wordSearchUnlocked;
  final bool stepsUnlocked;
  final bool onboardingCompleted;
  final bool lpIntroShown;
}
```

### UnlockTrigger
```dart
enum UnlockTrigger {
  welcomeQuiz,   // Unlocks classic + affirmation
  dailyQuiz,     // Unlocks you_or_me (when BOTH quizzes complete)
  youOrMe,       // Unlocks linked
  linked,        // Unlocks word_search
  wordSearch,    // Unlocks steps
}
```

---

## Key Rules

### 1. Both Quizzes Required for You or Me
You or Me only unlocks when BOTH Classic AND Affirmation are completed:

```typescript
// In unlocks/complete/route.ts
case 'daily_quiz':
  if (quizType === 'classic' && !current.classic_quiz_completed) {
    await client.query(`UPDATE couple_unlocks SET classic_quiz_completed = true...`);
    // Check if BOTH are now done
    if (afterClassic.rows[0].affirmation_quiz_completed && !current.you_or_me_unlocked) {
      await client.query(`UPDATE couple_unlocks SET you_or_me_unlocked = true...`);
      newlyUnlocked.push('you_or_me');
    }
  }
  // Similar for affirmation...
```

### 2. Pass Quiz Type to Unlock Notification
When notifying completion, include the quiz type:

```dart
// In quiz_match_results_screen.dart
await unlockService.notifyCompletion(
  UnlockTrigger.dailyQuiz,
  quizType: widget.match.quizType,  // 'classic' or 'affirmation'
);
```

### 3. Server-Only State (No Hive)
Unlock state is stored only on server and in memory:

```dart
// In unlock_service.dart
UnlockState? _cachedState;  // In-memory cache only

Future<UnlockState?> getUnlockState({bool forceRefresh = false}) async {
  if (_cachedState != null && !forceRefresh) {
    return _cachedState;
  }
  // Fetch from server...
}
```

### 4. Celebration Per-User Tracking
Each partner sees celebration once, tracked locally:

```dart
Future<bool> shouldShowYouOrMeCelebration() async {
  final box = await Hive.openBox('celebrations_seen');
  return box.get('you_or_me') != true;
}

Future<void> markCelebrationSeen(String feature) async {
  final box = await Hive.openBox('celebrations_seen');
  await box.put(feature, true);
}
```

### 5. Unlock Callback for UI Updates
Register callback to refresh UI when unlocks happen:

```dart
// In daily_quests_widget.dart
@override
void initState() {
  _unlockService.setOnUnlockChanged(_onUnlockChanged);
}

void _onUnlockChanged() {
  if (mounted) {
    final updatedState = _unlockService.cachedState;
    setState(() => _unlockState = updatedState);
  }
}
```

### 6. Guidance Hand with Pending Results
If a user kills the app while on a waiting screen and has pending results, the guidance hand
stays on that quest until they view results:

```dart
// In daily_quests_widget.dart _getGuidanceState()
// Check for pending results BEFORE checking normal guidance target
String? pendingContentType;
if (quest.type == QuestType.quiz) {
  pendingContentType = quest.formatType == 'affirmation' ? 'affirmation_quiz' : 'classic_quiz';
} else if (quest.type == QuestType.youOrMe) {
  pendingContentType = 'you_or_me';
}
if (pendingContentType != null && StorageService().hasPendingResults(pendingContentType)) {
  return (showGuidance: true, guidanceText: 'Continue Here');
}
```

This ensures users complete the "RESULTS ARE READY!" screen before moving on to the next activity.

---

## Common Bugs & Fixes

### 1. You or Me Unlocks After One Quiz
**Symptom:** You or Me unlocks after Classic but before Affirmation.

**Cause:** Server not tracking both quiz completions separately.

**Fix:** Use separate tracking columns:
```sql
ALTER TABLE couple_unlocks
ADD COLUMN classic_quiz_completed BOOLEAN DEFAULT FALSE,
ADD COLUMN affirmation_quiz_completed BOOLEAN DEFAULT FALSE;
```

### 2. Celebration Not Showing
**Symptom:** Feature unlocks but no celebration overlay.

**Cause:** `shouldShowYouOrMeCelebration()` returns false.

**Fix:** Check Hive `celebrations_seen` box:
```dart
final box = await Hive.openBox('celebrations_seen');
debugPrint('Seen: ${box.get('you_or_me')}');
```

### 3. Feature Still Locked
**Symptom:** Feature should be unlocked but shows locked.

**Cause:** Cached state not refreshed.

**Fix:** Force refresh:
```dart
await _unlockService.getUnlockState(forceRefresh: true);
```

### 4. Unlock Criteria Text Wrong
**Symptom:** Card shows wrong requirement text.

**Cause:** `getUnlockCriteria()` returning old text.

**Fix:** Update in `UnlockState`:
```dart
case UnlockableFeature.youOrMe:
  return 'Complete quizzes first';  // Updated from "Complete a quest first"
```

### 5. Celebration Dark Background Doesn't Fill Screen
**Symptom:** Unlock celebration overlay has visible gaps at top/bottom (notch, home indicator areas).

**Cause:** `showDialog` adds padding constraints even with `useSafeArea: false`.

**Fix:** Use `showGeneralDialog` for true fullscreen + `SizedBox.expand`:
```dart
// In show() method - use showGeneralDialog instead of showDialog
return showGeneralDialog(
  context: context,
  barrierDismissible: false,
  barrierColor: Colors.transparent,
  barrierLabel: 'Unlock Celebration',
  transitionDuration: Duration.zero,
  pageBuilder: (context, animation, secondaryAnimation) {
    return UnlockCelebrationOverlay(...);
  },
);

// In build() - wrap with SizedBox.expand
return Material(
  color: Colors.transparent,
  child: AnimatedBuilder(
    builder: (context, child) {
      return SizedBox.expand(  // Forces fullscreen
        child: Container(
          color: Colors.black.withOpacity(0.95),  // Background edge-to-edge
          child: SafeArea(  // Content stays in safe area
            child: ...,
          ),
        ),
      );
    },
  ),
);
```

---

## API Reference

### GET /api/unlocks
Get current unlock state for couple.

**Response:**
```json
{
  "success": true,
  "unlockState": {
    "coupleId": "uuid",
    "welcomeQuizCompleted": true,
    "classicQuizUnlocked": true,
    "classicQuizCompleted": true,
    "affirmationQuizCompleted": true,
    "youOrMeUnlocked": true,
    "linkedUnlocked": false,
    "wordSearchUnlocked": false,
    "stepsUnlocked": false
  }
}
```

### POST /api/unlocks/complete
Notify server of feature completion.

**Request:**
```json
{
  "trigger": "daily_quiz",
  "quizType": "classic"
}
```

**Response:**
```json
{
  "success": true,
  "lpAwarded": 5,
  "newlyUnlocked": ["you_or_me"],
  "unlockState": { ... }
}
```

---

## Screen Flow

### Welcome Quiz → Home with LP Intro
```
WelcomeQuizResultsScreen
         │
         ▼
Check for unlocks (classic + affirmation)
         │
         ▼
Show unlock celebration
         │
         ▼
Navigate to HomeScreen(showLpIntro: true)
         │
         ▼
LPIntroOverlay shows first-time LP explanation
```

### Daily Quiz → You or Me Unlock
```
QuizMatchResultsScreen
         │
         ▼
notifyCompletion(dailyQuiz, quizType: 'classic')
         │
         ▼
Server checks: both quizzes complete?
         │
    ┌────┴────────────────────────┐
    ▼                             ▼
No (wait for other)         Yes (unlock!)
    │                             │
    │                             ▼
    │                   Award 5 LP
    │                   Mark you_or_me_unlocked
    │                             │
    │                             ▼
    │                   shouldShowYouOrMeCelebration()
    │                             │
    └─────────────────────────────┘
                  │
                  ▼
         Show celebration overlay (if applicable)
```

---

## File Reference

| File | Purpose |
|------|---------|
| `unlock_service.dart` | API communication, state caching |
| `unlock_celebration.dart` | Celebration overlay animations |
| `lp_intro_overlay.dart` | First-time LP introduction |
| `route.ts` (unlocks) | Get unlock state |
| `route.ts` (complete) | Process unlock triggers |

---

## Changelog

| Date | Change |
|------|--------|
| 2025-12-17 | Guidance hand stays on quest with pending results until user views results screen |
| 2025-12-16 | Removed LP awarding for unlocks - LP only comes from game completion now |
| 2025-12-16 | Fixed celebration overlay dark background not filling screen edges (showGeneralDialog + SizedBox.expand) |
| 2025-12-16 | Initial documentation |

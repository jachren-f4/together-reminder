# Known Issues & Solutions

This document tracks known issues, bugs, and their solutions to prevent regression and aid future debugging.

---

## Quest Card Not Updating After Completion

**Date Discovered:** 2025-11-17
**Status:** ✅ FIXED
**Severity:** Medium (UX issue, no data loss)

### Symptom

After completing a quest (e.g., "You or Me"), the quest card on the home screen continues to show "YOUR TURN" instead of updating to "Waiting for partner". However, tapping the card correctly shows the waiting screen, indicating the data layer is working correctly.

### Root Cause

The issue was caused by incorrect navigation flow using `Navigator.pushReplacement()` instead of `Navigator.push()` when navigating from the quest intro screen to the game screen.

**Navigation Flow (BROKEN):**
```
Home → Quest Intro (push) → Quest Game (pushReplacement)
                ↑                          |
                |                          |
                ← ← ← ← ← ← ← ← ← ← ← ← ← ←
                     (back button bypasses intro screen)
```

When using `pushReplacement`, the intro screen is removed from the navigation stack. When the user presses back from the game screen, they return directly to the home screen, **bypassing** the return handler in `daily_quests_widget.dart` that calls `setState()` to refresh the UI.

**Navigation Flow (FIXED):**
```
Home → Quest Intro (push) → Quest Game (push)
                ↑                       |
                |← ← Intro ← ← ← ← ← ← ←
                |      ↑
                ← ← ← ←
      (setState triggered here)
```

With `push`, the intro screen remains in the stack, ensuring the return flow goes through: Game → Intro → Home, which properly triggers the `setState()` call.

### Why Classic/Affirmation Quizzes Worked But You or Me Didn't

Classic and Affirmation quizzes always used `Navigator.push()` throughout their navigation flow, so the return handler was always triggered. You or Me was the only quest type using `pushReplacement`, which broke the UI refresh mechanism.

### Solution

**File:** `app/lib/screens/you_or_me_intro_screen.dart`
**Line:** 96

**Change:**
```dart
// BEFORE (BROKEN)
Navigator.of(context).pushReplacement(
  MaterialPageRoute(
    builder: (context) => YouOrMeGameScreen(session: session),
  ),
);

// AFTER (FIXED)
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => YouOrMeGameScreen(session: session),
  ),
);
```

### Prevention

**Rule for Quest Screens:**
Always use `Navigator.push()` for quest navigation unless there is a specific, documented reason to use `pushReplacement`. The navigation stack must remain intact for the home screen's `setState()` callback to be triggered when returning from quest completion.

**Files to Check:**
- `daily_quests_widget.dart` - Contains the `setState()` callback at line ~360 that refreshes quest cards
- Quest intro screens (`*_intro_screen.dart`) - Should use `push`, not `pushReplacement`

### Testing Checklist

When adding new quest types:
- [ ] Complete the quest on one device
- [ ] Verify quest card updates to show "Waiting for partner" immediately upon returning to home screen
- [ ] Do NOT rely on app restart or manual refresh to see the update
- [ ] Check that navigation uses `push`, not `pushReplacement`

### Related Files

- `app/lib/screens/you_or_me_intro_screen.dart:96` - Fixed navigation call
- `app/lib/widgets/daily_quests_widget.dart:360` - setState() callback location
- `app/lib/widgets/quest_card.dart:328-368` - "Waiting for partner" badge logic

---

## Duplicate Love Points Award for You or Me Quest

**Date Discovered:** 2025-11-17
**Status:** ✅ FIXED
**Severity:** Medium (incorrect LP rewards, no data loss)

### Symptom

When both users complete "You or Me" quest, they each receive **60 LP** instead of the expected **30 LP**. This same bug previously affected Classic and Affirmation quizzes but was fixed for those quest types.

### Root Cause

The issue was caused by **duplicate LP awards** at two different layers:

1. **YouOrMeService._completeSession()** (line 424-430) awarded 30 LP when both users submitted answers
2. **DailyQuestService.completeQuestForUser()** (line 117-123) awarded another 30 LP when the quest was marked as completed by both users

**Why DailyQuestService awarded LP:**

DailyQuestService checks `if (quest.type != QuestType.quiz)` before awarding LP. Since "You or Me" uses `QuestType.youOrMe` (not `QuestType.quiz`), the condition was TRUE and LP was awarded.

**Result:** 30 LP + 30 LP = 60 LP (duplicate!)

### Why This Bug Kept Recurring

After unifying "You or Me" to use the same single-session architecture as Classic and Affirmation quizzes, the YouOrMeService still contained its own LP award logic from the old dual-session implementation. This created the duplicate award.

**Pattern:** Classic and Affirmation quizzes rely on DailyQuestService for LP awards. You or Me should follow the same pattern but didn't until now.

### Solution

**File:** `app/lib/services/you_or_me_service.dart`
**Line:** 416-440

**Change:** Removed LP award call from `_completeSession()` method

```dart
// BEFORE (BROKEN - awarded duplicate LP)
Future<void> _completeSession(YouOrMeSession session) async {
  Logger.info('Completing session: ${session.id}', service: 'you_or_me');

  const lpEarned = 30;

  // Award LP to both users (DUPLICATE!)
  await LovePointService.awardPointsToBothUsers(
    userId1: session.userId,
    userId2: session.partnerId,
    amount: lpEarned,
    reason: 'you_or_me_completion',
    relatedId: session.id,
  );

  session.lpEarned = lpEarned;
  session.status = 'completed';
  session.completedAt = DateTime.now();

  await session.save();
  await _syncSessionToRTDB(session);

  Logger.success('Session completed, 30 LP awarded to both users', service: 'you_or_me');
}

// AFTER (FIXED - LP awarded only by DailyQuestService)
/// Complete session when both users have submitted answers
///
/// NOTE: LP is awarded by DailyQuestService.completeQuestForUser(), not here.
/// This prevents duplicate LP awards (issue: You or Me was awarding 60 LP instead of 30).
Future<void> _completeSession(YouOrMeSession session) async {
  Logger.info('Completing session: ${session.id}', service: 'you_or_me');

  const lpEarned = 30; // Standard quest reward

  // DO NOT award LP here - DailyQuestService handles it
  // (This prevents duplicate LP awards: 30 + 30 = 60 bug)
  // LP is awarded via DailyQuestService.completeQuestForUser() when quest is marked completed

  session.lpEarned = lpEarned;
  session.status = 'completed';
  session.completedAt = DateTime.now();

  await session.save();
  await _syncSessionToRTDB(session);

  Logger.success('Session completed (LP awarded via DailyQuestService)', service: 'you_or_me');
}
```

### Prevention

**Rule for Quest Services:**

All quest types should follow the **centralized LP award pattern** implemented in `DailyQuestService.completeQuestForUser()`. Individual quest services (QuizService, YouOrMeService, etc.) should NOT award LP directly.

**LP Award Flow:**
1. User completes content (quiz, game, etc.)
2. Quest service marks quest as completed via `DailyQuestService.completeQuestForUser()`
3. **DailyQuestService** awards LP when both users have completed (line 117-123)
4. Quest service tracks `session.lpEarned` for display purposes only (not for actual awarding)

**Exception:** Quiz-type quests (`QuestType.quiz`) are excluded from DailyQuestService LP awards and handle LP in QuizService instead.

**Files to Check When Adding New Quest Types:**
- `app/lib/services/daily_quest_service.dart:111` - Check if quest type needs LP award exclusion
- New quest service file - Do NOT call `LovePointService.awardPointsToBothUsers()` directly
- `app/lib/models/daily_quest.dart` - Verify quest type enum value

### Testing Checklist

When adding new quest types or modifying quest completion:
- [ ] Complete quest with both users
- [ ] Check LP awarded = exactly 30 LP per user (not 60)
- [ ] Verify LP award appears in debug logs only ONCE
- [ ] Check both users' LP balances match expected total
- [ ] Ensure `LovePointService.awardPointsToBothUsers()` is called only from DailyQuestService
- [ ] Search quest service code for any direct LP award calls

### Related Files

- `app/lib/services/you_or_me_service.dart:416-440` - Fixed _completeSession() method
- `app/lib/services/daily_quest_service.dart:111-130` - Centralized LP award logic
- `app/lib/services/love_point_service.dart:224-275` - awardPointsToBothUsers() implementation
- `app/lib/models/daily_quest.dart` - QuestType enum definitions

---

## Template for New Issues

```markdown
## [Issue Title]

**Date Discovered:** YYYY-MM-DD
**Status:** 🐛 OPEN / 🔍 INVESTIGATING / ✅ FIXED
**Severity:** Low / Medium / High / Critical

### Symptom
[What the user experiences]

### Root Cause
[Technical explanation of why it happens]

### Solution
[How it was fixed, with code examples]

### Prevention
[Rules or practices to avoid this in the future]

### Testing Checklist
- [ ] Step 1
- [ ] Step 2

### Related Files
- `path/to/file.dart:line` - Description
```

---

**Last Updated:** 2025-11-17 (Added duplicate LP award fix)

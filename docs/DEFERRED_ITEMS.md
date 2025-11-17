# Quest Unification - Deferred Items

**Status:** To be addressed in future iterations
**Created:** 2025-11-17
**Review Date:** After Phase 6 completion
**Related:** QUEST_UNIFICATION_PLAN_V2.md

---

## Overview

During the planning phase for quest screen unification, we identified several potential issues and enhancements. The items below were consciously deferred to keep the initial implementation focused and achievable. Each can be addressed in future iterations if monitoring shows they're needed.

---

## Items Deferred from Initial Implementation

### 4. Backwards Compatibility - In-Progress Quests

**Issue:** Users with active quests during deployment may have navigation stack referencing old screens.

**Scenario:**
1. Alice starts Classic quiz on v1.0 (uses old `QuizWaitingScreen`)
2. App auto-updates to v2.0 while she's on waiting screen
3. Navigation stack references deleted class
4. Potential crash: "Class not found: QuizWaitingScreen"

**Why Deferred:**
- Low probability - most quests complete within 5-10 minutes
- Current app update strategy doesn't force-quit running apps
- Navigation state typically resets on app restart
- Testing overhead high for rare edge case

**Mitigation:**
- Phased rollout reduces risk (not all users update simultaneously)
- Most sessions expire within 24 hours anyway
- Users can restart app if issues occur

**Future Action (if needed):**
```dart
// In main.dart initialization
Future<void> _migrateActiveSessions() async {
  final storage = StorageService();
  final activeSessions = storage.getAllActiveSessions();

  for (final session in activeSessions) {
    if (session.isOldVersion) {
      // Clear navigation state
      session.clearNavigationStack();
    }
  }
}
```

**Monitoring:**
- Watch crash reports for navigation-related errors
- Track "session not found" errors after deployments

---

### 5. Auto-Polling Resource Impact

**Issue:** Multiple simultaneous waiting screens polling Firebase.

**Scenario:**
- User has 3 quests in waiting state
- 3 timers running simultaneously:
  - Affirmation 1: Polling every 5s
  - Affirmation 2: Polling every 5s
  - You or Me: Polling every 3s
- **~20 Firebase reads per minute per user**
- Multiplied by hundreds/thousands of users = cost spike

**Why Deferred:**
- Current user base small enough for free tier
- Most users complete quests sequentially (not simultaneously)
- Can monitor and optimize later if needed
- Premature optimization

**Current Mitigation:**
- Timers dispose properly when screens unmount
- Polling only happens on waiting screen (not background)
- Auto-polling has built-in intervals (not continuous)

**Future Optimizations (if costs spike):**

1. **Shared Polling Service**
   ```dart
   class GlobalPollService {
     // Single timer for all waiting screens
     // Notifies all active screens on interval
   }
   ```

2. **Exponential Backoff**
   ```dart
   // Start: Poll every 3s
   // After 30s: Poll every 10s
   // After 2min: Poll every 30s
   ```

3. **Push Notifications** (best solution)
   - Eliminate polling entirely
   - Firebase Cloud Function sends push when partner completes
   - Instant notification + zero polling cost

**Monitoring:**
- Firebase console: Daily read operations
- Cost per month
- Average concurrent waiting screens per user

**Threshold:** If monthly Firebase costs exceed $50, prioritize optimization.

---

### 11. Version Mismatch Between Partners

**Issue:** Alice on v2.0 (unified screens), Bob on v1.0 (old screens), potential incompatibility.

**Scenario:**
1. Alice updates app to v2.0
2. Bob hasn't updated yet (still on v1.0)
3. Both complete same quiz
4. Different code paths write to Firebase
5. Potential data format mismatch

**Why Deferred:**
- Firebase data structure NOT changing (only UI/navigation)
- Session models remain identical
- Both versions write same data format
- Partners typically update around same time (shared device notifications)

**Validation:**
- Session models backward compatible (no new required fields)
- Firebase RTDB paths unchanged
- Quest completion logic identical
- LP award logic identical

**Future Action (if issues arise):**
```dart
// Add version field to sessions
class QuizSession {
  @HiveField(15, defaultValue: 1)
  int schemaVersion;

  // Graceful degradation
  Map<String, dynamic> toFirebase() {
    if (schemaVersion == 1) {
      return legacyFormat();
    }
    return modernFormat();
  }
}
```

**Mitigation:**
- App store release notes: "Both partners should update for best experience"
- No breaking changes to data models
- Extensive cross-version testing in Phase 6

**Monitoring:**
- Partner sync failures
- "Quest data corrupted" errors
- Mismatched LP awards

---

### 12. App State Transitions

**Issue:** Timer/navigation state when app backgrounded, minimized, or killed.

**Scenarios:**
1. **App Backgrounded:** User switches to another app mid-wait
2. **App Minimized:** User presses home button
3. **App Killed:** OS kills app to free memory
4. **Screen Locked:** Phone locks during waiting

**Why Deferred:**
- Flutter handles basic lifecycle automatically
- Timers pause/resume on their own
- User can manually refresh if stuck
- Edge case doesn't break core functionality

**Current Behavior:**
- Auto-polling pauses when app backgrounded (Flutter default)
- Manual refresh button still works
- Navigation stack preserved by Flutter
- No data loss (session stored in Hive)

**Future Enhancements (if users report issues):**

```dart
class UnifiedWaitingScreen extends StatefulWidget {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Force refresh on resume
      _checkSessionStatus();
    }
  }
}
```

**Testing:**
- Manual testing in Phase 6 includes app backgrounding
- If no issues observed, no action needed

**Monitoring:**
- User reports of "stuck on waiting screen"
- Timer-related bugs

---

### 13. LP Notification Banner Integration

**Issue:** Plan doesn't explicitly verify banner integration in unified results screen.

**Why Deferred:**
- `LovePointService` already handles this automatically
- Banner triggers on LP award regardless of calling screen
- Existing architecture doesn't require changes
- Already tested in Classic/Affirmation/You or Me flows

**How It Works (Current):**
```dart
// LovePointService automatically shows banner
await LovePointService.awardPoints(
  userId: userId,
  amount: 30,
  reason: 'Quest completed',
);
// Banner appears via global overlay (foreground_notification_banner.dart)
```

**Validation:**
- Phase 3-5 test checklists include: "Verify +30 LP banner appears"
- If broken, debug `LovePointService.setAppContext` integration
- No code changes expected

**What to Watch:**
- Banner doesn't appear after quest completion
- Banner shows wrong amount
- Multiple banners stacking

**Quick Fix (if needed):**
```dart
// In UnifiedResultsScreen._checkQuestCompletion()
// After LP award
await Future.delayed(Duration(milliseconds: 500));
// Ensure banner has time to appear
```

---

### 16. Analytics & Success Metrics

**Issue:** No tracking for quest completion rates, drop-off, user behavior.

**Why Deferred:**
- No analytics infrastructure currently in app
- Would require new dependency (Firebase Analytics, Mixpanel, etc.)
- Out of scope for unification project
- Can add later without affecting unification

**What We'd Want to Track:**
- Quest start rate (how many users tap quests)
- Quest completion rate (start → both partners complete)
- Drop-off at waiting screen (abandon before partner completes)
- Average time on waiting screen
- LP award success rate
- Navigation errors

**Future Enhancement:**

```dart
// Firebase Analytics example
await analytics.logEvent(
  name: 'quest_started',
  parameters: {
    'quest_type': 'classic',
    'quest_id': quest.id,
  },
);

await analytics.logEvent(
  name: 'quest_completed',
  parameters: {
    'quest_type': 'classic',
    'duration_seconds': duration,
    'lp_earned': 30,
  },
);
```

**Current Workaround:**
- Manual testing with Alice/Bob validates functionality
- Firebase console shows session/quest data (requires manual queries)
- User feedback via GitHub issues
- Logger service tracks events in development

**When to Add:**
- After unification is stable
- When user base grows (analytics more valuable)
- When data-driven optimization needed

---

### 17. Rollback Strategy Flaw

**Issue:** Plan says "delete old files in Phase 6" but also claims individual quest type rollback is possible.

**Contradiction:**
- Can't rollback to old screen if file deleted
- Git history has it, but requires code changes to restore
- Not a "quick rollback"

**Why Deferred:**
- Careful phased testing makes rollback unlikely
- Each quest type validated before moving to next
- Can restore from git if absolutely needed
- Don't want to maintain duplicate code paths

**Improved Strategy:**

**Original Plan:** Delete files in Phase 6
**Enhanced Plan:**
1. Phase 6: Mark files as deprecated (comment at top)
2. Production validation period: 1-2 weeks
3. If stable, delete in follow-up PR
4. Keep git tags for easy restoration

**Implementation:**
```dart
// OLD FILE: quiz_waiting_screen.dart
// ⚠️ DEPRECATED - Replaced by unified_waiting_screen.dart
// DO NOT USE - Will be deleted after production validation
// See: docs/QUEST_UNIFICATION_PLAN_V2.md

@Deprecated('Use UnifiedWaitingScreen instead')
class QuizWaitingScreen extends StatefulWidget {
  // ... keep code for safety
}
```

**Alternative: Feature Flags**
```dart
// If rollback risk is high
if (FeatureFlags.useUnifiedScreens) {
  return UnifiedWaitingScreen(...);
} else {
  return QuizWaitingScreen(...);  // Old screen
}
```

**Decision:** Keep old files until production validated, then delete safely.

---

### 18. Error Logging & Debugging

**Issue:** No centralized error tracking for production debugging.

**Why Deferred:**
- Logger service already exists (`lib/utils/logger.dart`)
- Development testing catches most errors
- Can add Sentry/Crashlytics in separate project
- Not blocking core functionality

**Current Error Handling:**
```dart
try {
  await _checkSessionStatus();
} catch (e) {
  Logger.error('Failed to check session', error: e, service: 'unified');
  // Show error to user
}
```

**Future Enhancements:**

1. **Error Boundaries**
   ```dart
   ErrorBoundary(
     onError: (error, stackTrace) {
       // Log to remote service
       Sentry.captureException(error, stackTrace);
     },
     child: UnifiedWaitingScreen(...),
   )
   ```

2. **Session State Dumps**
   ```dart
   Logger.error('Navigation failed', error: e, metadata: {
     'session': session.toJson(),
     'user_id': userId,
     'quest_id': questId,
   });
   ```

3. **Production Error Tracking**
   - Sentry for crash reporting
   - Firebase Crashlytics
   - Custom logging endpoint

**Immediate Action:**
- Use `Logger.error()` for all exception catches
- Enable logging for `unified`, `navigation` services during development
- Production: Only errors log (debug/info disabled)

**Monitoring:**
- GitHub issues from users
- Console errors during manual testing
- Logger output in debug builds

---

### 20. Hive Migration for New Fields

**Issue:** If session models get new fields later, need proper migration strategy.

**Why Deferred:**
- No session model changes planned in this refactor
- Existing models already have all needed fields
- Not relevant to unification work
- Standard practice we already follow

**Reminder for Future:**

If adding fields to `QuizSession` or `YouOrMeSession`:

```dart
class QuizSession {
  // Existing fields...

  // NEW FIELD - Must have defaultValue!
  @HiveField(15, defaultValue: 'default_value')
  String newField;
}
```

**Required Steps:**
1. Add `defaultValue` to `@HiveField`
2. Run build_runner: `flutter pub run build_runner build --delete-conflicting-outputs`
3. Test with existing Hive data (don't wipe storage)
4. Verify no "type 'Null' is not a subtype" crashes

**Reference:** CLAUDE.md Section 2 - "Hive Data Migration"

**Not Needed for This Project:** Session models unchanged.

---

## Summary: Why Deferred Items Are Safe

All deferred items share these characteristics:

| Criterion | Explanation |
|-----------|-------------|
| **Low Probability** | Unlikely to occur in normal usage |
| **Easy to Fix** | Not architectural changes, can patch later |
| **Observable** | Will show up in monitoring or user reports |
| **Not Blocking** | Core functionality works without them |
| **High Test Cost** | Would add significant complexity to test |

The enhanced plan focuses on **high-probability, high-impact** issues that could break core functionality or cause bad UX.

---

## Review Checklist

**After Phase 6 completion, review this list:**

- [ ] Any crash reports related to navigation state?
- [ ] Firebase usage costs within acceptable range?
- [ ] Partner version mismatch reports?
- [ ] Users reporting stuck waiting screens?
- [ ] LP notification banner working correctly?
- [ ] Analytics data would be valuable now?
- [ ] Production stable enough to delete old files?
- [ ] Error tracking sufficient for debugging?

**If YES to any question, prioritize addressing the related deferred item.**

---

## Appendix: Decision Matrix

**How we decided what to defer:**

```
                        Probability    Impact    Test Cost
Item 4 (Compat)         Low           High       High        → DEFER
Item 5 (Polling)        Medium        Low        Low         → DEFER
Item 11 (Version)       Low           Medium     Medium      → DEFER
Item 12 (Lifecycle)     Low           Low        High        → DEFER
Item 13 (Banner)        N/A           N/A        Low         → DEFER (already works)
Item 16 (Analytics)     N/A           Low        Medium      → DEFER (out of scope)
Item 17 (Rollback)      Low           High       N/A         → DEFER (strategy change)
Item 18 (Errors)        N/A           Medium     Low         → DEFER (already handled)
Item 20 (Hive)          N/A           N/A        N/A         → DEFER (not needed)
```

**Items NOT deferred (in enhanced plan):**

```
Item 1 (Type Safety)    High          Critical   Medium      → PHASE 0
Item 2 (Content Builder) High         Critical   Medium      → PHASE 2
Item 3 (Config Timing)  High          Critical   Low         → PHASE 0
Item 6 (Session-Quest)  High          High       Low         → PHASE 0
Item 7 (Affirmation UX) High          Medium     Low         → PHASE 4
Item 8 (Back Button)    Medium        Medium     Low         → PHASE 1
Item 9 (Loading States) Medium        Medium     Low         → PHASE 1
Item 10 (Race Condition) Medium       Critical   Medium      → PHASE 0
```

---

## Contact

**Questions about deferred items?**
- Review: docs/QUEST_UNIFICATION_PLAN_V2.md
- Reference: CLAUDE.md
- Create issue: Flag for future sprint

**Priority Changed?**
- Move item from deferred to active
- Add to appropriate phase in plan
- Update test strategy accordingly

---

**End of Document**

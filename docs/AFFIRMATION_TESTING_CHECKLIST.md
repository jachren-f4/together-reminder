# Affirmation Integration Testing Checklist

**Last Updated:** 2025-11-14
**Status:** Ready for Testing

---

## Pre-Testing Setup

### Complete Clean Testing Procedure

Use this procedure to ensure a fresh start with no stale data.

```bash
# 1. Uninstall Android app (clears Hive local storage)
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind2

# 2. Kill Flutter processes
pkill -9 -f "flutter"

# 3. Clean Firebase RTDB
cd /Users/joakimachren/Desktop/togetherremind
firebase database:remove /daily_quests --force
firebase database:remove /quiz_sessions --force
firebase database:remove /lp_awards --force
firebase database:remove /quiz_progression --force

# 4. Launch Alice (Android) - generates fresh quests
cd /Users/joakimachren/Desktop/togetherremind/app
flutter run -d emulator-5554 &

# 5. Launch Bob (Chrome) - loads from Firebase
flutter run -d chrome &
```

---

## Phase 4 Testing Tasks

### ✅ Test 1: Affirmation Quest Generation

**Objective:** Verify affirmations appear at positions 1 and 3 in each track

**Steps:**
1. Launch Alice (Android emulator)
2. Wait for "✅ Daily quests generated: 3 quests" in console
3. Open debug menu (double-tap greeting text)
4. Tap "View Firebase RTDB Data"
5. Check quest data

**Expected Results:**
- Day 1 should have at least 1 affirmation quest
- Check `formatType` field in Firebase data:
  - Position 1 quest should have `formatType: "affirmation"`
  - Categories should be `trust` or `emotional_support`
- Verify `quizName` and `category` fields are populated

**Pass Criteria:**
- [ ] At least 1 affirmation appears in day 1 quests
- [ ] Affirmation quest has `formatType: "affirmation"`
- [ ] Quest has `quizName` (e.g., "Gentle Beginnings")
- [ ] Quest has `category` (e.g., "trust")

---

### ✅ Test 2: End-to-End Affirmation Quiz Flow

**Objective:** Test complete user journey through affirmation quiz

**Steps:**
1. On Alice, tap an affirmation quest card
2. Verify **AffirmationIntroScreen** appears
3. Read Goal, Research, and "How it works" sections
4. Tap "Get Started"
5. Verify **QuizQuestionScreen** with 5-point heart scale
6. Answer all 5 questions (tap hearts to select)
7. Submit answers
8. Verify **AffirmationResultsScreen** appears

**Expected Results:**
- **Intro Screen:**
  - Shows quiz name (e.g., "Gentle Beginnings")
  - Shows "QUIZ" badge
  - Shows goal, research context, how it works
  - Has "Get Started" button

- **Question Screen:**
  - Shows 5-point heart scale (not multiple choice)
  - Hearts fill from left to right when selected
  - "Strongly disagree" / "Strongly agree" labels visible
  - No role indicator badge (hidden for affirmations)
  - Progress bar shows 1/5, 2/5, etc.

- **Results Screen:**
  - Shows individual score as percentage (0-100%)
  - Shows circular progress indicator
  - Shows "Awaiting [partner]'s answers" if partner hasn't completed
  - Lists all questions with heart ratings

**Pass Criteria:**
- [x] Intro screen displays correctly with quiz metadata ✅ VERIFIED (2025-11-14)
- [x] 5-point heart scale renders correctly ✅ VERIFIED (2025-11-14)
- [x] Can select answers (hearts fill properly) ✅ VERIFIED (2025-11-14)
- [x] Can navigate through all questions ✅ VERIFIED (2025-11-14)
- [ ] Results screen shows individual score
- [ ] Questions display with heart icons (1-5)

---

### ✅ Test 3: Firebase Sync Across Devices

**Objective:** Verify affirmation quizzes sync correctly between partners

**Steps:**
1. **Alice completes affirmation:**
   - Tap affirmation quest
   - Complete all questions
   - Submit answers
2. **Check Firebase console:**
   - Navigate to `/quiz_sessions/{sessionId}`
   - Verify Alice's answers are stored
3. **Bob loads quest:**
   - Wait 10 seconds for sync
   - Refresh home screen
   - Tap same affirmation quest
4. **Bob completes affirmation:**
   - Complete all questions
   - Submit answers
5. **Check both devices:**
   - Verify both see results
   - Verify LP awards appear

**Expected Results:**
- Firebase `/quiz_sessions/{sessionId}` contains:
  - `formatType: "affirmation"`
  - `quizName: "Gentle Beginnings"` (or similar)
  - `category: "trust"` (or "emotional_support")
  - `answers: { "alice-id": [2, 3, 4, 1, 3], "bob-id": [3, 4, 3, 2, 4] }`
  - `predictionScores: { "alice-id": 65, "bob-id": 80 }` (individual scores)
  - `status: "completed"`
  - `lpEarned: 30`

**Pass Criteria:**
- [ ] Alice's answers sync to Firebase
- [x] Bob can load same quiz session ✅ VERIFIED (2025-11-14 - AffirmationQuizBank fallback)
- [x] Questions load correctly when not in local storage ✅ VERIFIED (2025-11-14)
- [ ] Bob's answers sync to Firebase
- [ ] Both receive completion notification
- [ ] Session marked as completed

**Note:** Bug fix implemented (2025-11-14) - QuizService now extracts quiz ID from question IDs and uses AffirmationQuizBank.getQuizById() for fallback loading.

---

### ✅ Test 4: Love Points Award (30 LP)

**Objective:** Verify 30 LP awarded when both partners complete affirmation

**Steps:**
1. **Check LP before quiz:**
   - Note Alice's current LP
   - Note Bob's current LP
2. **Complete affirmation (both users):**
   - Alice completes first
   - Bob completes second
3. **Check LP after quiz:**
   - Verify Alice received +30 LP
   - Verify Bob received +30 LP
4. **Check LP transaction records:**
   - Open debug menu → "View Local Hive Data"
   - Find `LovePointTransaction` entries
   - Verify reason: `'affirmation_completed'`
   - Verify amount: 30

**Expected Results:**
- Both users receive +30 LP notification banner
- LP counter updates on next screen rebuild
- Transaction records created in Hive storage
- Firebase `/lp_awards/{coupleId}` updated

**Pass Criteria:**
- [ ] Alice receives +30 LP
- [ ] Bob receives +30 LP
- [ ] LP notification banner appears ("+30 LP 💰")
- [ ] Transaction reason is `'affirmation_completed'`

---

### ✅ Test 5: Quest Completion Tracking

**Objective:** Verify quest marked as completed after both finish

**Steps:**
1. **Alice completes affirmation**
2. **Check quest status:**
   - Quest should show partial completion (Alice done, Bob waiting)
3. **Bob completes affirmation**
4. **Check quest status:**
   - Quest should show green checkmark
   - Quest status: `'completed'`
   - Both users marked as completed

**Expected Results:**
- Before Bob completes:
  - Quest shows Alice completed
  - Quest NOT marked as fully completed
- After Bob completes:
  - Quest shows green checkmark
  - Quest marked as completed in Firebase
  - Both users have completed flags set

**Pass Criteria:**
- [ ] Quest tracks individual completion
- [ ] Quest shows green checkmark after both complete
- [ ] Firebase `/daily_quests/{coupleId}/{dateKey}` updated correctly

---

### ✅ Test 6: Daily Affirmation Distribution (50%)

**Objective:** Verify at least 1 affirmation appears every day

**Steps:**
1. **Day 1:**
   - Check 3 daily quests
   - Count affirmations (should be 1-2)
2. **Complete all Day 1 quests**
3. **Advance to Day 2:**
   - Clear Firebase: `firebase database:remove /daily_quests --force`
   - Restart apps to generate Day 2 quests
4. **Check Day 2 quests:**
   - Count affirmations (should be 1-2)
5. **Repeat for Days 3-4**

**Expected Distribution:**
- **Day 1:** Quest 2 (Position 1) = Affirmation
- **Day 2:** Quest 1 (Position 3) = Affirmation, Quest 3 (Position 1) = Affirmation
- **Day 3:** Quest 2 (Position 3) = Affirmation
- **Day 4:** Quest 1 (Position 1) = Affirmation, Quest 3 (Position 3) = Affirmation

**Pass Criteria:**
- [ ] Every day has 1-2 affirmations
- [ ] Affirmations appear at positions 1 and 3
- [ ] Categories rotate: trust, emotional_support

---

### ✅ Test 7: Quest Tap Routing

**Objective:** Verify correct screen navigation for affirmations

**Test 7a: First Tap (User Hasn't Answered)**

**Steps:**
1. Tap affirmation quest (user hasn't answered)
2. Verify route

**Expected:**
- Routes to **AffirmationIntroScreen**
- NOT QuizIntroScreen (classic quiz intro)

**Pass Criteria:**
- [ ] Shows AffirmationIntroScreen
- [ ] Has "Get Started" button

---

**Test 7b: After User Answers (Waiting for Partner)**

**Steps:**
1. Complete affirmation as Alice
2. Tap same quest again
3. Verify route

**Expected:**
- Routes to **AffirmationResultsScreen**
- Shows "Awaiting [partner]'s answers"
- Shows Alice's individual score

**Pass Criteria:**
- [ ] Shows AffirmationResultsScreen
- [ ] Shows waiting message for partner
- [ ] Shows Alice's score

---

**Test 7c: After Both Complete**

**Steps:**
1. Complete affirmation as both users
2. Tap quest
3. Verify route

**Expected:**
- Routes to **AffirmationResultsScreen**
- Shows both individual scores
- Shows completed status

**Pass Criteria:**
- [ ] Shows AffirmationResultsScreen
- [ ] Shows both scores
- [ ] Shows completed state (no "awaiting" message)

---

## Debugging Tools

### In-App Debug Menu

**Access:** Double-tap greeting text ("Good morning" / "Good afternoon")

**Features:**
- View Firebase RTDB data for daily quests
- View local Hive storage quest data
- Copy data to clipboard
- **"Clear Local Storage & Reload"** - Clears Hive (NOT Firebase)

### Helper Scripts

Located in `/tmp/` (if available):

| Script | Purpose |
|--------|---------|
| `clear_firebase.sh` | DELETE ALL Firebase RTDB data |
| `debug_firebase.sh` | Inspect current Firebase RTDB data |

### Firebase Console

Direct paths to check:
- `/daily_quests/{coupleId}/{dateKey}` - Quest data
- `/quiz_sessions/{sessionId}` - Quiz session data
- `/quiz_progression/{coupleId}` - Progression state
- `/lp_awards/{coupleId}` - Love Point transactions

---

## Known Issues & Limitations

### Expected Behavior (Not Bugs)

1. **LP Counter Delay**
   - LP counter does NOT auto-update when LP is awarded
   - Notification banner shows "+30 LP 💰" immediately
   - Counter updates on next screen rebuild (navigation, app restart)
   - **This is by design** (see CLAUDE.md:8)

2. **Chrome Storage**
   - Must clear Chrome storage manually in DevTools
   - F12 → Application tab → Storage → Clear site data
   - OR close Chrome entirely and restart

3. **iOS Simulator**
   - Xcode 26.1 beta has compatibility issues
   - Use physical iOS device or Xcode 16.x stable

### Potential Issues to Watch

1. **"Quiz Session Not Found" Error** ✅ FIXED (2025-11-14)
   - **Cause:** Second device hasn't synced quiz session from Firebase, questions not in local storage
   - **Solution:** Implemented AffirmationQuizBank fallback in `QuizService.getSessionQuestions()`
   - **Status:** ✅ Fixed - Extracts quiz ID from question IDs and uses `AffirmationQuizBank.getQuizById()`
   - **Files Modified:**
     - `app/lib/services/quiz_service.dart:125-157` - Added fallback logic
     - `app/lib/screens/quiz_question_screen.dart:47-48` - Fixed substring bounds checking

2. **Version Compatibility**
   - **Risk:** One partner updates app, other doesn't
   - **Mitigation:** Defensive checks for `questionType` field
   - **Status:** Implemented in `QuizQuestionScreen`

3. **Question Count Mismatch**
   - **Expected:** 5 questions per affirmation quiz
   - **If 6:** Update affirmation_quizzes.json to trim to 5
   - **Current:** All quizzes have 5 questions ✓

---

## Success Criteria Summary

### Functional Requirements ✅

- [ ] At least one affirmation quiz appears every day starting from day 1
- [ ] Affirmation quizzes appear at positions 1 and 3 in each track (50% distribution)
- [ ] Affirmation questions display 5-point heart scale (not multiple choice)
- [ ] Individual scores calculated correctly (average of 1-5 scale → 0-100%)
- [ ] Results screen shows individual score, not match percentage
- [ ] Both partners receive 30 LP when both complete
- [ ] Firebase sync works (second device loads quiz from first device)
- [ ] Quest completion tracking works (checkmark appears, quest status updates)

### Non-Functional Requirements ✅

- [ ] No code duplication (reuses existing quest infrastructure)
- [ ] No breaking changes (existing classic quizzes continue to work)
- [ ] Backward compatible (existing data migrates safely)
- [ ] Performance (no additional latency vs classic quizzes)

---

## Testing Sign-Off

| Test | Status | Notes | Tester | Date |
|------|--------|-------|--------|------|
| Quest Generation | ⬜ Pending | | | |
| End-to-End Flow | 🟡 Partial | Question loading verified, results pending | Claude | 2025-11-14 |
| Firebase Sync | 🟡 Partial | Question fallback verified, completion pending | Claude | 2025-11-14 |
| LP Awards | ⬜ Pending | | | |
| Quest Completion | ⬜ Pending | | | |
| Daily Distribution | ⬜ Pending | | | |
| Tap Routing | ⬜ Pending | | | |

---

**Last Updated:** 2025-11-14
**Ready for Testing:** ✅ YES

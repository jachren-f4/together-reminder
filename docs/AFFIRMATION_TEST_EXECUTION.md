# Affirmation Integration Test Execution Guide

**Using Logger Service for Clean, Filtered Debugging**

**Last Updated:** 2025-11-15
**Status:** Ready for Testing

---

## Quick Start

### Step 1: Run Complete Clean Testing Procedure

```bash
# 1. Kill existing Flutter processes
pkill -9 -f "flutter"

# 2. Uninstall Android app (clears Hive storage)
~/Library/Android/sdk/platform-tools/adb uninstall com.togetherremind.togetherremind

# 3. Clean Firebase RTDB
cd /Users/joakimachren/Desktop/togetherremind
firebase database:remove /daily_quests --force
firebase database:remove /quiz_sessions --force
firebase database:remove /lp_awards --force
firebase database:remove /quiz_progression --force

# 4. Launch Alice (Android) - generates fresh quests
cd /Users/joakimachren/Desktop/togetherremind/app
flutter run -d emulator-5554 &

# Wait for "✅ Daily quests generated" in console before continuing

# 5. Launch Bob (Chrome) - loads from Firebase
flutter run -d chrome &
```

---

## Logger-Based Test Execution

### Key Logger Statements to Watch

The following Logger statements will appear during affirmation testing:

| Log Statement | Service | When It Appears | What It Means |
|---------------|---------|-----------------|---------------|
| `✅ Loaded 6 affirmation quizzes (30 total questions)` | `affirmation` | App startup | AffirmationQuizBank initialized successfully |
| `ℹ️ Creating affirmation quiz: [Name] (category: [Category])` | `affirmation` | User taps affirmation quest | Affirmation quiz session created |
| `🔍 User [ID] affirmation score: [X]%` | `affirmation` | After user submits answers | Individual score calculated |
| `✅ Affirmation quiz "[Name]" completed - Scores: [X, Y]%, +30 LP awarded` | `affirmation` | Both users complete | Quiz completed, LP awarded |

### Expected Log Output (End-to-End Test)

```
# Alice launches (Android)
✅ 14:32:01 Loaded 6 affirmation quizzes (30 total questions)
# ... app initialization logs ...

# Alice taps affirmation quest
ℹ️  14:32:18 Creating affirmation quiz: Gentle Beginnings (category: trust)

# Alice completes all 5 questions and submits
🔍 14:32:45 User alice-id affirmation score: 76%

# Bob launches (Chrome)
✅ 14:33:02 Loaded 6 affirmation quizzes (30 total questions)

# Bob taps same affirmation quest (loads from Firebase)
# ... questions load via AffirmationQuizBank fallback ...

# Bob completes all 5 questions and submits
🔍 14:33:28 User bob-id affirmation score: 82%
✅ 14:33:28 Affirmation quiz "Gentle Beginnings" completed - Scores: 76, 82%, +30 LP awarded
```

---

## Test Case 1: Quest Generation

**Objective:** Verify affirmations appear at positions 1 and 3

### Expected Logger Output

```bash
# When Alice launches and quests are generated
✅ [Time] Loaded 6 affirmation quizzes (30 total questions)
# ... quest generation logs ...
```

### Verification Steps

1. Open debug menu (double-tap greeting text)
2. Tap "View Firebase RTDB Data"
3. Look for quest with `formatType: "affirmation"`
4. Verify position is 1 or 3

**✅ PASS:** At least 1 affirmation in 3 daily quests
**❌ FAIL:** No affirmations or wrong position

---

## Test Case 2: End-to-End Flow (Complete Quiz)

**Objective:** Complete affirmation quiz as both users

### Alice's Flow

```bash
# 1. Alice taps affirmation quest
# Expected log:
ℹ️  [Time] Creating affirmation quiz: [Name] (category: [Category])

# 2. Intro screen shows (no specific log)

# 3. Alice answers all 5 questions and submits
# Expected log:
🔍 [Time] User alice-id affirmation score: [X]%
```

### Bob's Flow

```bash
# 1. Bob taps same affirmation quest (loads from Firebase)
# No creation log (session already exists)

# 2. Bob answers all 5 questions and submits
# Expected logs:
🔍 [Time] User bob-id affirmation score: [Y]%
✅ [Time] Affirmation quiz "[Name]" completed - Scores: [X, Y]%, +30 LP awarded
```

### What to Check

- [ ] Intro screen displays correctly
- [ ] 5-point heart scale renders (not multiple choice)
- [ ] Can select answers (hearts fill from left to right)
- [ ] Results screen shows individual score
- [ ] Both users see "Quest completed" checkmark

**✅ PASS:** All steps complete, both see results
**❌ FAIL:** Error at any step, see troubleshooting below

---

## Test Case 3: LP Awards

**Objective:** Verify 30 LP awarded to both users

### Expected Logger Output

```bash
# After both users complete affirmation
✅ [Time] Affirmation quiz "[Name]" completed - Scores: [X, Y]%, +30 LP awarded
```

### Verification Steps

1. Note Alice's LP before quiz
2. Note Bob's LP before quiz
3. Both complete affirmation
4. Look for success log with "+30 LP awarded"
5. Verify notification banner appears (**"+30 LP 💰"**)
6. Check LP counter on next screen (updates on rebuild)

**✅ PASS:** Both users +30 LP, notification appears
**❌ FAIL:** No LP awarded or wrong amount

---

## Test Case 4: Firebase Sync

**Objective:** Second device loads quiz from first device

### Expected Logger Output

```bash
# Alice completes quiz
🔍 [Time] User alice-id affirmation score: 76%

# Bob loads same quiz (no errors expected)
# Bob completes quiz
🔍 [Time] User bob-id affirmation score: 82%
✅ [Time] Affirmation quiz "Gentle Beginnings" completed - Scores: 76, 82%, +30 LP awarded
```

### What to Check

- [ ] Bob can open same quiz Alice started
- [ ] Questions load correctly (via AffirmationQuizBank fallback)
- [ ] No "Failed to load questions" error
- [ ] Completion syncs to Firebase

**✅ PASS:** Both complete, no sync errors
**❌ FAIL:** "Quiz session not found" or "Failed to load questions"

---

## Troubleshooting with Logger

### Problem: No Affirmation Quizzes Loaded

**Symptom:**
```bash
❌ [Time] Error loading affirmation quizzes: [error message]
```

**Cause:** Asset file not found or malformed JSON

**Fix:**
1. Verify `app/assets/data/affirmation_quizzes.json` exists
2. Check `pubspec.yaml` includes `assets/data/` path
3. Run `flutter clean && flutter pub get`

---

### Problem: Affirmation Quiz Not Created

**Symptom:** No log for "Creating affirmation quiz"

**Cause:** Quest generation didn't select affirmation format

**Fix:**
1. Check quest position (should be 1 or 3 in each track)
2. Verify `quest_type_manager.dart` has affirmation configs
3. Clear Firebase and regenerate quests

---

### Problem: Wrong Score Calculation

**Symptom:**
```bash
🔍 [Time] User alice-id affirmation score: 0%
# Or score doesn't match expected value
```

**Cause:** Answers stored incorrectly or scoring logic bug

**Fix:**
1. Check answers in Firebase `/quiz_sessions/{sessionId}`
2. Verify answers are 0-4 (representing 1-5 scale)
3. Check `_calculateAffirmationScores` logic in `quiz_service.dart:320-366`

---

### Problem: LP Not Awarded

**Symptom:** No success log showing "+30 LP awarded"

**Cause:** Completion detection failed or user/partner not found

**Fix:**
1. Verify both users answered (check Firebase session)
2. Check `session.status` is "completed"
3. Verify user and partner exist in storage
4. Check `LovePointService.awardPointsToBothUsers` is called

---

## Advanced: Filtering Logs by Service

### Focus on Affirmation Logs Only

Edit `app/lib/utils/logger.dart`:

```dart
static const Map<String, bool> _serviceVerbosity = {
  'quiz': false,           // Disable classic quiz logs
  'notification': false,   // Disable notification logs
  'poke': false,          // Disable poke logs
  'affirmation': true,    // Enable affirmation logs (keep)
  'quest': true,          // Enable quest logs (related)
  'lovepoint': true,      // Enable LP logs (related)
  // ... disable others
};
```

Now only affirmation-related logs appear, making debugging much cleaner.

---

## Success Criteria Checklist

Use Logger output to verify each criterion:

### Functional Requirements

- [ ] `✅ Loaded 6 affirmation quizzes` appears on app startup
- [ ] `ℹ️ Creating affirmation quiz: [Name]` appears when tapping quest
- [ ] `🔍 User [ID] affirmation score: [X]%` appears after each user submits
- [ ] `✅ Affirmation quiz "[Name]" completed - Scores: [X, Y]%, +30 LP awarded` appears after both complete
- [ ] At least 1 affirmation quest in daily 3 quests
- [ ] Individual scores display correctly in results screen
- [ ] Both users receive +30 LP notification

### Non-Functional Requirements

- [ ] No `❌ Error` logs during affirmation flow
- [ ] No crashes or freezes
- [ ] Questions load within 2 seconds
- [ ] Results appear within 1 second of second user completing

---

## Quick Test Script (Copy & Paste)

Run this after clean testing procedure:

```bash
# Watch both consoles for Logger output
# Alice console: Look for "Creating affirmation quiz"
# Bob console: Look for "affirmation score" and "completed"

# Expected timeline:
# T+0s:  Alice launches, sees affirmation quest
# T+10s: Alice completes quiz, sees individual score
# T+20s: Bob launches, sees same quest
# T+30s: Bob completes quiz
# T+30s: Both see "+30 LP awarded" log
# T+31s: Both see notification banner
```

**Total test time:** ~2 minutes per complete flow

---

## Common Logger Patterns

### ✅ Test Passed
```bash
✅ [Time] Loaded 6 affirmation quizzes (30 total questions)
ℹ️  [Time] Creating affirmation quiz: Gentle Beginnings (category: trust)
🔍 [Time] User alice-id affirmation score: 76%
🔍 [Time] User bob-id affirmation score: 82%
✅ [Time] Affirmation quiz "Gentle Beginnings" completed - Scores: 76, 82%, +30 LP awarded
```

### ❌ Test Failed - Quiz Not Found
```bash
❌ [Time] Quiz session not found
```

### ❌ Test Failed - Loading Error
```bash
❌ [Time] Error loading affirmation quizzes: [error]
```

### ❌ Test Failed - Scoring Error
```bash
❌ [Time] Subject has not answered yet
# Or missing score calculation logs
```

---

## Next Steps After Testing

1. **All tests pass:** Mark checklist items complete in `AFFIRMATION_TESTING_CHECKLIST.md`
2. **Some tests fail:** Use Logger output to identify root cause
3. **Ready for production:** Disable verbose logging by setting `_serviceVerbosity` for production

---

**Last Updated:** 2025-11-15
**Related Docs:**
- `AFFIRMATION_INTEGRATION_PLAN.md` - Implementation details
- `AFFIRMATION_TESTING_CHECKLIST.md` - Complete test cases
- `LOGGER_SERVICE.md` - Logger service documentation

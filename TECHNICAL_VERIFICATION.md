# Technical Verification - Love Points & Quiz System

This document outlines technical verification tests for the Love Points (LP) and Quiz systems.

## Test 1: Love Point Calculations

### LP Award Amounts (verify in love_point_service.dart:43-89)
- ✅ Reminder completed: +10 LP
- ✅ Quiz perfect match (100%): +50 LP
- ✅ Quiz great match (80-99%): +30 LP
- ✅ Quiz good match (60-79%): +20 LP
- ✅ Quiz participation (<60%): +10 LP
- ✅ Mutual poke: +15 LP (both partners within 2-minute window)

### Arena Tier Thresholds (verify in love_point_service.dart:10-40)
| Tier | Arena Name          | Emoji | Min LP | Max LP   | Floor LP |
|------|---------------------|-------|--------|----------|----------|
| 1    | Cozy Cabin          | 🏕️    | 0      | 1,000    | 0        |
| 2    | Beach Villa         | 🏖️    | 1,000  | 2,500    | 1,000    |
| 3    | Yacht Getaway       | ⛵     | 2,500  | 5,000    | 2,500    |
| 4    | Mountain Penthouse  | 🏔️    | 5,000  | 10,000   | 5,000    |
| 5    | Castle Retreat      | 🏰    | 10,000 | ∞        | 10,000   |

### Tier Upgrade Logic (verify in love_point_service.dart:74-83)
- User should upgrade to next tier when LP total reaches the tier's minimum
- Floor protection prevents LP from dropping below current tier minimum
- Example: User at 2,500 LP (Tier 3) cannot drop below 2,500 LP

---

## Test 2: Quiz Scoring Algorithm

### Match Percentage Calculation (verify in quiz_service.dart:105-156)
- Quiz has 5 questions
- Each matching answer = 1 point
- Match percentage = (matches / 5) × 100
- Example: 4/5 correct = 80% match

### LP Rewards Based on Match Percentage
- **100% match**: +50 LP + "Perfect Sync" badge 🎯
- **80-99% match**: +30 LP
- **60-79% match**: +20 LP
- **<60% match**: +10 LP (participation)

### Quiz Session States (verify in quiz_service.dart:22-102)
- `waiting_for_answers`: Created, waiting for first person to answer
- `expired`: Quiz expired after 3 hours (see quiz_service.dart:48)
- `completed`: Both partners answered, results calculated

---

## Test 3: Badge Unlocks

### Quiz Badge (verify in quiz_service.dart:159-179)
- **Name**: Perfect Sync
- **Emoji**: 🎯
- **Condition**: Achieve 100% match on a quiz
- **Category**: quiz
- **One-time award**: Badge should only be earned once

---

## Test 4: Firebase RTDB Sync

### Quiz Session Sync (verify in quiz_service.dart:295-408)
- Quiz sessions sync to RTDB path: `quiz_sessions/{emulatorId}/{sessionId}`
- Synced data includes:
  - Session ID, question IDs, timestamps
  - Status, answers, match percentage, LP earned
- Partner listener watches opposite emulator ID:
  - Alice (emulator-5554) listens for Bob (web-bob)
  - Bob (web-bob) listens for Alice (emulator-5554)

### Sync Triggers
- Session syncs when created (quiz_service.dart:61)
- Session syncs when answers submitted (quiz_service.dart:93)
- Partner receives updates via RTDB listeners (quiz_service.dart:326-408)

---

## Test 5: Quiz Flow Verification

### Expected Flow (verify in quiz_service.dart)
1. Bob starts quiz → creates session with status "waiting_for_answers"
2. Bob answers 5 questions → session saves Bob's answers, syncs to RTDB
3. Alice receives session via RTDB listener → session appears in Alice's local storage
4. Alice opens quiz → sees Bob's questions
5. Alice answers 5 questions → saves Alice's answers
6. Both answered → calculates match percentage → awards LP → updates session to "completed"
7. Results shown to both partners

### Session Data Structure
```dart
{
  'id': String,
  'questionIds': List<String>,
  'createdAt': int (milliseconds since epoch),
  'expiresAt': int (3 hours from creation),
  'status': String ('waiting_for_answers' | 'completed' | 'expired'),
  'initiatedBy': String (user ID),
  'answers': Map<String, List<int>>,
  'matchPercentage': int?,
  'lpEarned': int?,
  'completedAt': int?
}
```

---

## Manual Verification Steps

### Step 1: Verify LP Calculations
1. Check Bob's current LP total
2. Have Bob complete a reminder → verify +10 LP added
3. Check transaction history for "reminder_completed" entry
4. Verify new LP total = old total + 10

### Step 2: Verify Quiz Scoring
1. Bob starts quiz, answers all 5 questions
2. Alice answers same quiz with specific pattern:
   - Test A: Match all 5 answers → expect +50 LP + Perfect Sync badge
   - Test B: Match 4/5 answers → expect +30 LP, 80% match
   - Test C: Match 3/5 answers → expect +20 LP, 60% match
   - Test D: Match 2/5 answers → expect +10 LP, 40% match
3. Verify LP calculation matches expected amount
4. Check badge storage for "Perfect Sync" badge after 100% match

### Step 3: Verify RTDB Sync
1. Open Firebase Console → Realtime Database
2. Navigate to `/quiz_sessions/web-bob/` (Bob's sessions)
3. Navigate to `/quiz_sessions/emulator-5554/` (Alice's sessions)
4. Verify session data appears after Bob creates quiz
5. Verify session updates after Alice submits answers
6. Check logs for:
   - "✅ Quiz session synced to RTDB: {sessionId}"
   - "👂 Listening for partner quiz sessions: {partnerId}"
   - "✅ Received new quiz session from partner: {sessionId}"

### Step 4: Verify Tier Upgrades
1. Note current tier and LP total
2. Award enough LP to cross next tier threshold
3. Verify tier upgrade message in logs: "🎉 Tier upgraded to {arena}!"
4. Verify floor LP updated to new tier's minimum
5. Verify UI shows new arena name and emoji

---

## Expected Log Output

### Quiz Creation (Bob)
```
✅ Quiz session started: {sessionId}
✅ Quiz session synced to RTDB: {sessionId}
❌ Error sending quiz invite: Invalid or expired push token
```

### Quiz Received (Alice)
```
👂 Listening for partner quiz sessions: web-bob
✅ Received new quiz session from partner: {sessionId}
```

### Quiz Completion (Alice)
```
✅ Answers submitted for user {userId}
✅ Quiz session synced to RTDB: {sessionId}
✅ Quiz completed: 80% match, +30 LP earned
💰 Awarded 30 LP for quiz_completed (Total: {newTotal})
```

### Badge Unlock (on 100% match)
```
🏆 Badge earned: Perfect Sync
```

---

## Common Issues to Check

### Issue 1: Alice doesn't receive Bob's quiz
- **Check**: RTDB listener logs for "👂 Listening for partner quiz sessions"
- **Check**: Firebase Console for session data at `/quiz_sessions/web-bob/{sessionId}`
- **Check**: DevConfig.partnerIndex returns correct index (0 for Alice, 1 for Bob)

### Issue 2: LP not awarded after quiz
- **Check**: Both partners have answered (quiz_service.dart:92)
- **Check**: Session status is "completed"
- **Check**: LP transaction created with reason "quiz_completed"
- **Check**: User.save() called after LP update

### Issue 3: Badge not unlocking on 100% match
- **Check**: Match percentage is exactly 100 (quiz_service.dart:125)
- **Check**: Badge doesn't already exist (quiz_service.dart:163)
- **Check**: Badge saved to storage (quiz_service.dart:177)

---

## Files to Monitor

- **Quiz Logic**: `/Users/joakimachren/Desktop/togetherremind/app/lib/services/quiz_service.dart`
- **LP Logic**: `/Users/joakimachren/Desktop/togetherremind/app/lib/services/love_point_service.dart`
- **Storage**: `/Users/joakimachren/Desktop/togetherremind/app/lib/services/storage_service.dart`
- **Dev Config**: `/Users/joakimachren/Desktop/togetherremind/app/lib/config/dev_config.dart`
- **RTDB Sync**: Added in quiz_service.dart:295-408

---

## Next Steps

After verifying these technical aspects work correctly:
1. Rebuild both apps with new RTDB sync code
2. Test quiz flow end-to-end (Bob creates → Alice receives → both answer)
3. Test UX aspects (animations, UI feedback, result displays)
4. Test edge cases (quiz expiration, duplicate answers, network issues)

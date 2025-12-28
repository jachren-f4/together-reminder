# Reset Scripts

Scripts for resetting the database with test data at specific game states. Useful for testing features without manually playing through the entire game flow.

---

## Quick Reference

| Script | State | LP | Use Case |
|--------|-------|-----|----------|
| `reset_test_couple_quizzes_done.ts` | You or Me ready | 90 | Test You or Me from fresh start |
| `reset_test_couple_youorme_ready.ts` | Pertsa answered You or Me | 90 | Test You or Me results |
| `reset_test_couple_linked_ready.ts` | Linked just unlocked | 120 | Test Linked from fresh start |
| `reset_test_couple_wordsearch_ready.ts` | Word Search in progress | 150 | Test Word Search mid-game |

---

## Available Scripts

### `reset_test_couple_quizzes_done.ts`

Creates test couple ready to play You or Me for the first time.

```bash
npx tsx scripts/reset_test_couple_quizzes_done.ts
```

**State:**
- Welcome Quiz: completed
- Classic Quiz: completed (both users)
- Affirmation Quiz: completed (both users)
- You or Me: **unlocked, ready to start**
- Linked: locked
- Word Search: locked
- LP: 90

---

### `reset_test_couple_linked_ready.ts`

Creates test couple ready to play Linked for the first time.

```bash
npx tsx scripts/reset_test_couple_linked_ready.ts
```

**State:**
- Welcome Quiz: completed
- Classic Quiz: completed (both users)
- Affirmation Quiz: completed (both users)
- You or Me: completed (both users)
- Linked: **unlocked, ready to play**
- Word Search: locked
- LP: 120

---

### `reset_test_couple_wordsearch_ready.ts`

Creates test couple mid-way through Word Search puzzle.

```bash
npx tsx scripts/reset_test_couple_wordsearch_ready.ts
```

**State:**
- Welcome Quiz: completed
- Classic Quiz: completed (both users)
- Affirmation Quiz: completed (both users)
- You or Me: completed (both users)
- Linked: completed (puzzle_001)
- Word Search: **in progress** (Kilu found WALK, GRIN - Pertsa's turn)
- LP: 150

---

## Test Users

All scripts create the same test couple:

| User | Email | Password |
|------|-------|----------|
| Pertsa | `test7001@dev.test` | `DevPass_6354844221f1_2024!` |
| Kilu | `test8001@dev.test` | `DevPass_92556dc3ec04_2024!` |

**Couple ID:** `d9ffe5a8-325b-43b1-8819-11c6d8fa8e98`

Passwords use deterministic format: `DevPass_{sha256(email).substring(0,12)}_2024!`

---

## How Scripts Work

### 1. Wipe All Data

Scripts delete ALL existing data in this order (respecting foreign keys):

```
quest_completions → daily_quests → quiz_progression → branch_progression →
you_or_me_progression → quiz_answers → quiz_sessions → quiz_matches →
you_or_me_answers → you_or_me_sessions → linked_moves → linked_matches →
word_search_moves → word_search_matches → memory_moves → memory_puzzles →
steps_daily → steps_rewards → steps_connections → love_point_awards →
love_point_transactions → user_love_points → couple_leaderboard →
couple_unlocks → welcome_quiz_answers → reminders → pairing_codes →
push_tokens → user_push_tokens → couple_invites → user_couples → couples
```

Then deletes all `auth.users` via Supabase Admin API.

### 2. Create Test Users

Uses Supabase Admin API to create users with:
- Email confirmed
- Deterministic password (for easy login)
- `full_name` in user_metadata

### 3. Create Test Data

Within a transaction, creates:

1. **`couples`** - The couple record with LP total
2. **`couple_unlocks`** - Which features are unlocked
3. **`daily_quests`** - Today's quests (marked completed)
4. **`quest_completions`** - Completion records for both users
5. **`welcome_quiz_answers`** - Welcome quiz responses
6. **`quiz_matches`** - Completed quiz matches (classic, affirmation, you_or_me)
7. **`linked_matches`** - Linked game state (if applicable)
8. **`word_search_matches`** - Word Search game state (if applicable)
9. **`love_point_transactions`** - LP history records
10. **`branch_progression`** - Puzzle branch tracking (if applicable)

---

## Creating New Scripts

### Template

```typescript
import { query, getClient } from '../lib/db/pool';
import { createClient } from '@supabase/supabase-js';
import { createHash } from 'crypto';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.join(__dirname, '..', '.env.local') });

const supabaseUrl = process.env.SUPABASE_URL!;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;
const supabase = createClient(supabaseUrl, supabaseServiceKey);

const TEST_USERS = {
  pertsa: { email: 'test7001@dev.test', username: 'Pertsa' },
  kilu: { email: 'test9472@dev.test', username: 'Kilu' },
};

const TEST_COUPLE_ID = 'd9ffe5a8-325b-43b1-8819-11c6d8fa8e98';

function getDevPassword(email: string): string {
  const hash = createHash('sha256').update(email).digest('hex');
  return `DevPass_${hash.substring(0, 12)}_2024!`;
}

// ... rest of implementation
```

### Key Patterns

**PostgreSQL Arrays:**
```typescript
// Wrong - causes "malformed array literal" error
JSON.stringify([])

// Correct - PostgreSQL array format
'{}'                           // empty array
'{"item1","item2"}'           // array with items
```

**Board State (JSON):**
```typescript
const boardState = { "8": "T", "10": "H" };
JSON.stringify(boardState)  // Store as JSONB
```

**Dates:**
```typescript
const today = new Date();
today.setUTCHours(0, 0, 0, 0);
const todayStr = today.toISOString().split('T')[0];  // "2024-12-19"
```

---

## Usage Tips

### Before Running Scripts

1. **Stop the app** on all devices/emulators
2. **Clear app data** (Hive storage persists between logins)
   - Android: Settings → Apps → TogetherRemind → Clear Data
   - iOS: Delete and reinstall app
   - Chrome: DevTools → Application → Clear site data

### After Running Scripts

1. Enable `skipOtpVerificationInDev=true` in `lib/config/dev_config.dart`
2. Login with test user emails
3. Passwords are printed in script output

### Quick Commands

```bash
# Linked testing
cd api && npx tsx scripts/reset_test_couple_linked_ready.ts

# Word Search testing
cd api && npx tsx scripts/reset_test_couple_wordsearch_ready.ts

# Uninstall Android app
adb uninstall com.togetherremind.togetherremind
```

---

## Troubleshooting

### "Database error loading user"

Safe to ignore. Occurs when deleting users that were partially created or already deleted.

### "malformed array literal"

PostgreSQL arrays need `'{}'` format, not JSON `[]`. Use:
```typescript
// For text[] columns
'{}' or '{"a","b","c"}'

// With explicit cast if needed
$1::text[]
```

### Transaction Rollback

If script fails mid-way, the transaction rolls back. Just fix the issue and re-run - no partial data will remain.

### Foreign Key Violations

Delete tables in correct order (child tables before parent tables). See deletion order above.

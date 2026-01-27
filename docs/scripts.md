# Database Scripts Guide

This document explains how to create and modify database scripts for testing purposes. Use this as a reference when creating new test data scripts.

## Overview

Scripts live in `api/scripts/` and are run with:
```bash
cd api
npx tsx scripts/<script-name>.ts
```

## Script Structure

Every script follows this pattern:

```typescript
// 1. Imports
import { query, getClient } from '../lib/db/pool';
import { createClient } from '@supabase/supabase-js';
import { createHash } from 'crypto';
import * as dotenv from 'dotenv';
import * as path from 'path';

// 2. Load environment
dotenv.config({ path: path.join(__dirname, '..', '.env.local') });

// 3. Initialize Supabase admin client
const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

// 4. Define test data constants
const TEST_USERS = { ... };
const COUPLE_ID = 'uuid-here';

// 5. Helper functions
// 6. Cleanup functions
// 7. Data creation functions
// 8. Main function with transaction
```

## Key Imports

| Import | Purpose |
|--------|---------|
| `query` | Execute single SQL queries |
| `getClient` | Get pooled client for transactions |
| `createClient` (Supabase) | Admin API for auth operations |
| `createHash` | Generate deterministic passwords |

## Helper Functions

### Password Generation

Use deterministic passwords so you can log in without looking them up:

```typescript
function getDevPassword(email: string): string {
  const hash = createHash('sha256').update(email).digest('hex');
  return `DevPass_${hash.substring(0, 12)}_2024!`;
}
```

### Date Helpers

```typescript
// Returns Date object for timestamps
function daysAgo(days: number): Date {
  const date = new Date();
  date.setDate(date.getDate() - days);
  date.setUTCHours(12, 0, 0, 0);
  return date;
}

// Returns string for DATE columns (YYYY-MM-DD)
function daysAgoDateStr(days: number): string {
  const date = new Date();
  date.setDate(date.getDate() - days);
  return date.toISOString().split('T')[0];
}
```

**Important:** Use `daysAgoDateStr()` for `DATE` columns, `daysAgo()` for `TIMESTAMP` columns.

## Creating Users

Use Supabase admin API to create auth users:

```typescript
const { data, error } = await supabase.auth.admin.createUser({
  email: 'test@dev.test',
  password: getDevPassword('test@dev.test'),
  email_confirm: true,  // Skip email verification
  user_metadata: { full_name: 'Test User' },
});

const userId = data.user!.id;  // UUID from Supabase
```

## Deleting Users

Delete in correct order to respect foreign keys:

```typescript
// 1. Find users by email
const usersResult = await query(
  'SELECT id, email FROM auth.users WHERE email = ANY($1)',
  [['test1@dev.test', 'test2@dev.test']]
);

// 2. Find their couples
const couplesResult = await query(
  'SELECT id FROM couples WHERE user1_id = ANY($1) OR user2_id = ANY($1)',
  [userIds]
);

// 3. Delete related data (order matters!)
const tables = [
  'us_profile_cache',
  'conversation_starters',
  'daily_quests',
  'quiz_matches',
  'linked_matches',
  'word_search_matches',
  'steps_daily',
  'steps_rewards',
  'love_point_awards',
  'couple_unlocks',
  'user_couples',
  'couples',  // Last!
];

for (const table of tables) {
  await query(`DELETE FROM ${table} WHERE couple_id = ANY($1)`, [coupleIds]);
}

// 4. Delete auth users via Supabase admin
for (const user of users) {
  await supabase.auth.admin.deleteUser(user.id);
}
```

## Using Transactions

Wrap data creation in transactions for atomicity:

```typescript
const client = await getClient();
try {
  await client.query('BEGIN');

  // All inserts use client.query(), not query()
  await client.query('INSERT INTO couples ...', [...]);
  await client.query('INSERT INTO quiz_matches ...', [...]);

  await client.query('COMMIT');
} catch (error) {
  await client.query('ROLLBACK');
  throw error;
} finally {
  client.release();  // Always release!
}
```

## Table Schemas

### couples

```sql
INSERT INTO couples (
  id, user1_id, user2_id, brand_id, total_lp,
  subscription_status, subscription_user_id, subscription_started_at,
  subscription_expires_at, subscription_product_id,
  created_at, updated_at
) VALUES ($1, $2, $3, 'togetherremind', 2800,
  'active', $2, $4, $5, 'us2_yearly_premium', $4, NOW())
```

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | Use fixed UUID for predictability |
| `user1_id` | UUID | First user (from Supabase) |
| `user2_id` | UUID | Second user (from Supabase) |
| `brand_id` | TEXT | `'togetherremind'` |
| `total_lp` | INT | Love points (see thresholds below) |
| `subscription_status` | TEXT | `'active'`, `'trial'`, `'expired'`, `'none'` |
| `subscription_user_id` | UUID | Who subscribed |
| `subscription_expires_at` | TIMESTAMP | When subscription ends |

**LP Magnet Thresholds:** 600, 1300, 2100, 3000, 4000

### couple_unlocks

```sql
INSERT INTO couple_unlocks (
  couple_id, welcome_quiz_completed, classic_quiz_unlocked, affirmation_quiz_unlocked,
  you_or_me_unlocked, linked_unlocked, word_search_unlocked, steps_unlocked,
  onboarding_completed, lp_intro_shown, classic_quiz_completed, affirmation_quiz_completed,
  created_at, updated_at
) VALUES ($1, true, true, true, true, true, true, true, true, true, true, true, $2, NOW())
```

Set all to `true` to unlock everything.

### quiz_matches

```sql
INSERT INTO quiz_matches (
  id, couple_id, quiz_id, quiz_type, branch, status,
  player1_answers, player2_answers, player1_answer_count, player2_answer_count,
  match_percentage, player1_score, player2_score,
  player1_id, player2_id, date, created_at, completed_at
) VALUES (
  gen_random_uuid(), $1, $2, $3, $4, 'completed',
  $5, $6, 5, 5, $7, $8, $8, $9, $10, $11, $12, $12
)
```

| Column | Type | Notes |
|--------|------|-------|
| `quiz_type` | TEXT | `'classic'`, `'affirmation'`, `'you_or_me'` |
| `branch` | TEXT | `'connection'`, `'attachment'`, `'growth'`, `'playful'` |
| `player1_answers` | JSONB | `'[0, 1, 2, 0, 1]'` - array of answer indices |
| `match_percentage` | INT | 0-100 |
| `date` | DATE | Use `daysAgoDateStr()` |
| `created_at` | TIMESTAMP | Use `daysAgo()` |

### linked_matches

```sql
INSERT INTO linked_matches (
  couple_id, puzzle_id, branch, status, board_state, current_rack,
  current_turn_user_id, turn_number, player1_score, player2_score,
  player1_vision, player2_vision, locked_cell_count, total_answer_cells,
  player1_id, player2_id, created_at, completed_at
) VALUES (
  $1, $2, $3, 'completed', '{}'::jsonb, ARRAY[]::text[],
  $4, 10, 5, 5, 5, 5, 10, 10, $5, $6, $7, $7
)
```

| Column | Type | Notes |
|--------|------|-------|
| `branch` | TEXT | `'casual'`, `'romantic'`, `'adult'` |
| `board_state` | JSONB | `'{}'` for completed |
| `current_rack` | TEXT[] | `ARRAY[]::text[]` for completed |

### word_search_matches

```sql
INSERT INTO word_search_matches (
  couple_id, puzzle_id, branch, status, found_words,
  current_turn_user_id, turn_number, words_found_this_turn,
  player1_words_found, player2_words_found,
  player1_hints, player2_hints,
  player1_id, player2_id, created_at, completed_at
) VALUES (
  $1, $2, $3, 'completed', '["LOVE", "HEART", "KISS", "HUG"]',
  $4, 8, 0, 4, 4, 1, 1, $5, $6, $7, $7
)
```

| Column | Type | Notes |
|--------|------|-------|
| `branch` | TEXT | `'everyday'`, `'passionate'`, `'naughty'` |
| `found_words` | TEXT (JSON) | JSON array as string |

### steps_daily

```sql
INSERT INTO steps_daily (couple_id, user_id, date_key, steps, last_sync_at, updated_at)
VALUES ($1, $2, $3, $4, $5, $5)
```

| Column | Type | Notes |
|--------|------|-------|
| `date_key` | TEXT | `'YYYY-MM-DD'` format |
| `steps` | INT | Step count |

### steps_rewards

```sql
INSERT INTO steps_rewards (couple_id, date_key, combined_steps, lp_earned, claimed_by)
VALUES ($1, $2, $3, 15, $4)
```

### us_profile_cache

```sql
INSERT INTO us_profile_cache (
  couple_id, user1_insights, user2_insights, couple_insights,
  total_quizzes_completed, created_at, updated_at
) VALUES ($1, $2, $3, $4, $5, $6, NOW())
```

All insights columns are JSONB. See script for structure.

### conversation_starters

```sql
INSERT INTO conversation_starters (couple_id, trigger_type, data, dismissed, discussed, created_at)
VALUES ($1, $2, $3, false, false, $4)
```

| Column | Type | Notes |
|--------|------|-------|
| `trigger_type` | TEXT | `'value'`, `'discovery'`, `'dimension'`, `'love_language'` |
| `data` | JSONB | Contains `triggerData`, `promptText`, `contextText` |

## Existing Scripts

| Script | Purpose |
|--------|---------|
| `setup_app_store_couple.ts` | Creates Johnny & Julia with 7 days of usage for screenshots |
| `reset_couple_progress.ts` | Resets a specific couple's progress |
| `reset_two_test_couples.ts` | Creates two contrasting couples for testing |
| `wipe_all_accounts.ts` | Nuclear option - deletes all test data |

## Tips

1. **Use fixed UUIDs** for couples so you can reference them predictably
2. **Email pattern:** Use `test####@dev.test` to easily identify test accounts
3. **Scoped deletion:** Only delete YOUR test users, not all users
4. **Console output:** Use emoji prefixes for visual scanning (`✓`, `⚠️`, `❌`)
5. **Error handling:** Catch and log errors but continue cleanup when possible
6. **Transactions:** Always use transactions for multi-table inserts

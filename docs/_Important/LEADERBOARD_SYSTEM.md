# Leaderboard System Technical Guide

**Last Updated:** 2025-11-27

---

## Overview

The leaderboard displays couple rankings based on Love Points (LP). It supports:
- **Global leaderboard** - All couples ranked by total LP
- **Country leaderboard** - Couples ranked within user's country

Privacy: Only displays initials (e.g., "T & J"), not full names.

---

## Architecture

### Database Tables

#### `couple_leaderboard` (Pre-computed cache)
```sql
CREATE TABLE couple_leaderboard (
  couple_id UUID PRIMARY KEY REFERENCES couples(id),
  user1_initial CHAR(1),
  user2_initial CHAR(1),
  total_lp INT DEFAULT 0,
  global_rank INT,
  user1_country CHAR(2),
  user2_country CHAR(2),
  user1_country_rank INT,
  user2_country_rank INT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### `user_love_points.country_code`
```sql
ALTER TABLE user_love_points ADD COLUMN country_code CHAR(2);
```

### Data Flow

```
User earns LP → user_love_points UPDATE
                     ↓
              Trigger fires
                     ↓
         update_couple_leaderboard_lp()
                     ↓
         couple_leaderboard UPSERT
                     ↓
         recalculate_leaderboard_ranks() (periodic)
```

---

## Trigger Function

The trigger automatically updates `couple_leaderboard` when `user_love_points` changes.

### Key Design Decisions

1. **Shared Pool Model**: Both users in a couple have identical LP. We use `NEW.total_points` directly, not a sum.

2. **Separate Queries for Initials**: The original nested subquery approach failed silently. Using separate `SELECT INTO` statements works reliably.

3. **Simple Trigger Definition**: Using `AFTER INSERT OR UPDATE ON user_love_points` without column-specific filters (`OF total_points, country_code`) is more reliable.

4. **SECURITY DEFINER**: Required for the function to access `auth.users` table.

### Working Trigger Function

```sql
CREATE OR REPLACE FUNCTION update_couple_leaderboard_lp()
RETURNS TRIGGER AS $$
DECLARE
  v_couple_id UUID;
  v_user1_id UUID;
  v_user2_id UUID;
  v_user1_initial CHAR(1);
  v_user2_initial CHAR(1);
BEGIN
  -- Find couple for this user
  SELECT c.id, c.user1_id, c.user2_id INTO v_couple_id, v_user1_id, v_user2_id
  FROM couples c
  WHERE c.user1_id = NEW.user_id OR c.user2_id = NEW.user_id
  LIMIT 1;

  -- If user not in a couple, exit
  IF v_couple_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Get initials from auth.users (separate queries to avoid nested subquery issues)
  SELECT
    UPPER(SUBSTRING(COALESCE(raw_user_meta_data->>'full_name', 'A') FROM 1 FOR 1))
  INTO v_user1_initial
  FROM auth.users WHERE id = v_user1_id;

  SELECT
    UPPER(SUBSTRING(COALESCE(raw_user_meta_data->>'full_name', 'B') FROM 1 FOR 1))
  INTO v_user2_initial
  FROM auth.users WHERE id = v_user2_id;

  -- Upsert leaderboard entry (shared pool model: use triggering user's total_points)
  INSERT INTO couple_leaderboard (
    couple_id, user1_initial, user2_initial, total_lp,
    user1_country, user2_country, updated_at
  )
  VALUES (
    v_couple_id,
    COALESCE(v_user1_initial, 'A'),
    COALESCE(v_user2_initial, 'B'),
    NEW.total_points,
    (SELECT country_code FROM user_love_points WHERE user_id = v_user1_id),
    (SELECT country_code FROM user_love_points WHERE user_id = v_user2_id),
    NOW()
  )
  ON CONFLICT (couple_id) DO UPDATE SET
    total_lp = EXCLUDED.total_lp,
    user1_initial = EXCLUDED.user1_initial,
    user2_initial = EXCLUDED.user2_initial,
    user1_country = EXCLUDED.user1_country,
    user2_country = EXCLUDED.user2_country,
    updated_at = NOW();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger definition (fires on any INSERT or UPDATE)
DROP TRIGGER IF EXISTS trg_update_couple_leaderboard ON user_love_points;
CREATE TRIGGER trg_update_couple_leaderboard
  AFTER INSERT OR UPDATE ON user_love_points
  FOR EACH ROW
  EXECUTE FUNCTION update_couple_leaderboard_lp();
```

### Rank Recalculation Function

Called periodically (e.g., every 5 minutes via cron) to update rankings:

```sql
CREATE OR REPLACE FUNCTION recalculate_leaderboard_ranks()
RETURNS void AS $$
BEGIN
  -- Update global ranks
  UPDATE couple_leaderboard cl
  SET global_rank = ranks.rank
  FROM (
    SELECT couple_id, ROW_NUMBER() OVER (ORDER BY total_lp DESC) as rank
    FROM couple_leaderboard
    WHERE total_lp > 0
  ) ranks
  WHERE cl.couple_id = ranks.couple_id;

  -- Update user1 country ranks
  UPDATE couple_leaderboard cl
  SET user1_country_rank = ranks.rank
  FROM (
    SELECT couple_id, ROW_NUMBER() OVER (PARTITION BY user1_country ORDER BY total_lp DESC) as rank
    FROM couple_leaderboard
    WHERE user1_country IS NOT NULL AND total_lp > 0
  ) ranks
  WHERE cl.couple_id = ranks.couple_id;

  -- Update user2 country ranks
  UPDATE couple_leaderboard cl
  SET user2_country_rank = ranks.rank
  FROM (
    SELECT couple_id, ROW_NUMBER() OVER (PARTITION BY user2_country ORDER BY total_lp DESC) as rank
    FROM couple_leaderboard
    WHERE user2_country IS NOT NULL AND total_lp > 0
  ) ranks
  WHERE cl.couple_id = ranks.couple_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## Troubleshooting

### Trigger Not Firing

**Symptoms:** LP updates in `user_love_points` but `couple_leaderboard` doesn't change.

**Debug Steps:**

1. **Check if trigger exists and is enabled:**
```sql
SELECT tgname, tgenabled
FROM pg_trigger
WHERE tgrelid = 'user_love_points'::regclass;
-- tgenabled should be 'O' (origin-enabled)
```

2. **Check if function exists:**
```sql
SELECT routine_name
FROM information_schema.routines
WHERE routine_name = 'update_couple_leaderboard_lp';
```

3. **Check if user is in a couple:**
```sql
SELECT * FROM couples
WHERE user1_id = '<user_id>' OR user2_id = '<user_id>';
```
**This was the root cause in our debugging session** - the user ID wasn't in the `couples` table.

4. **Test with a simple hardcoded trigger:**
```sql
CREATE OR REPLACE FUNCTION test_leaderboard_trigger()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE couple_leaderboard
  SET total_lp = NEW.total_points, updated_at = NOW()
  WHERE couple_id = '<hardcoded_couple_id>';
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### RLS (Row Level Security) Issues

The `user_love_points` table has RLS enabled:
```sql
-- Check RLS policies
SELECT * FROM pg_policies WHERE tablename = 'user_love_points';
```

The trigger function uses `SECURITY DEFINER` to bypass RLS when updating `couple_leaderboard`.

### Initials Showing as "A & B"

Users need `full_name` in their `auth.users.raw_user_meta_data`:
```sql
UPDATE auth.users
SET raw_user_meta_data = raw_user_meta_data || '{"full_name": "TestiY"}'::jsonb
WHERE id = '<user_id>';

-- Trigger leaderboard update to refresh initials
UPDATE user_love_points SET total_points = total_points WHERE user_id = '<user_id>';
```

---

## API Endpoints

### GET /api/leaderboard

**Query Parameters:**
- `view`: `global` (default) or `country`
- `limit`: Number of entries (default 50)

**Response:**
```json
{
  "view": "global",
  "entries": [
    {
      "couple_id": "uuid",
      "initials": "T & J",
      "total_lp": 1200,
      "rank": 1,
      "is_current_user": false
    }
  ],
  "user_rank": 2,
  "user_total_lp": 800,
  "total_couples": 2,
  "updated_at": "2025-11-27T12:25:36.726Z"
}
```

### GET /api/user/country

Returns user's saved country code.

### POST /api/user/country

**Body:** `{"country_code": "US"}`

Sets user's country code (ISO 3166-1 alpha-2).

---

## Files Reference

| File | Purpose |
|------|---------|
| `api/supabase/migrations/016_leaderboard.sql` | Database migration |
| `api/app/api/leaderboard/route.ts` | Leaderboard API endpoint |
| `api/app/api/user/country/route.ts` | Country API endpoint |
| `app/lib/services/leaderboard_service.dart` | Flutter service (30s cache) |
| `app/lib/services/country_service.dart` | Country detection & flags |
| `app/lib/widgets/leaderboard_bottom_sheet.dart` | UI component |

---

## Test Users Setup

### Create Test Users (John & Jane)
```sql
-- Create in auth.users
INSERT INTO auth.users (
  id, instance_id, email, encrypted_password, email_confirmed_at,
  raw_user_meta_data, created_at, updated_at, role, aud
)
VALUES (
  'aaaaaaaa-1111-1111-1111-111111111111',
  '00000000-0000-0000-0000-000000000000',
  'john@test.local',
  crypt('password123', gen_salt('bf')),
  NOW(),
  '{"full_name": "John Test"}'::jsonb,
  NOW(), NOW(), 'authenticated', 'authenticated'
);

-- Create couple
INSERT INTO couples (id, user1_id, user2_id, created_at, updated_at)
VALUES (
  'cccccccc-1111-1111-1111-111111111111',
  'aaaaaaaa-1111-1111-1111-111111111111',
  'aaaaaaaa-2222-2222-2222-222222222222',
  NOW(), NOW()
);

-- Create LP entries (both must have same value for shared pool)
INSERT INTO user_love_points (user_id, total_points, country_code)
VALUES
  ('aaaaaaaa-1111-1111-1111-111111111111', 1200, 'US'),
  ('aaaaaaaa-2222-2222-2222-222222222222', 1200, 'US');

-- Recalculate ranks
SELECT recalculate_leaderboard_ranks();
```

### Update Dev Users to Match Couple
If your dev users aren't appearing on the leaderboard, ensure they're in the `couples` table:
```sql
UPDATE couples
SET user1_id = 'c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28',
    user2_id = 'd71425a3-a92f-404e-bfbe-a54c4cb58b6a'
WHERE id = '11111111-1111-1111-1111-111111111111';
```

---

## Debugging Session Summary (2025-11-27)

### Problem
Trigger was not updating `couple_leaderboard` when `user_love_points` changed.

### Root Cause
The user ID being updated (`c7f42ec5-...`) was NOT in the `couples` table. The couple existed with different user IDs.

### Solution
Updated the `couples` table to use the correct dev user IDs.

### Lessons Learned
1. Always verify the user is in a couple before debugging trigger logic
2. Use simple hardcoded triggers to isolate problems
3. Column-specific triggers (`UPDATE OF col1, col2`) can be unreliable - use simple `UPDATE` triggers
4. Nested subqueries in PL/pgSQL can fail silently - use separate `SELECT INTO` statements

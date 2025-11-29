-- LP Single Source of Truth Migration
-- Migration: 025 - Move LP from per-user to couple-level
--
-- Problem: LP is stored per-user in user_love_points.total_points
--          Both users must be updated atomically, but bugs cause divergence
--          Example: Jokke: 240 LP, TestiY: 1160 LP (MISMATCH!)
--
-- Solution: Store LP at couple level in couples.total_lp
--           All awardLP functions update couples.total_lp (one row, atomic)
--           Both users see the same LP total

-- ============================================================================
-- PHASE 1: Add total_lp column to couples table
-- ============================================================================

-- Add the new column (single source of truth for LP)
ALTER TABLE couples
ADD COLUMN IF NOT EXISTS total_lp INT DEFAULT 0 CHECK (total_lp >= 0);

-- Comment for documentation
COMMENT ON COLUMN couples.total_lp IS 'Single source of truth for couple LP. Replaces per-user user_love_points.total_points.';

-- ============================================================================
-- PHASE 2: Migrate existing LP data
-- ============================================================================

-- Use GREATEST to pick the higher value (handles existing mismatches)
UPDATE couples c
SET total_lp = GREATEST(
  COALESCE((SELECT total_points FROM user_love_points WHERE user_id = c.user1_id), 0),
  COALESCE((SELECT total_points FROM user_love_points WHERE user_id = c.user2_id), 0)
)
WHERE c.total_lp = 0 OR c.total_lp IS NULL;

-- ============================================================================
-- PHASE 3: Create new trigger on couples.total_lp
-- ============================================================================

-- New trigger function that fires when couples.total_lp changes
CREATE OR REPLACE FUNCTION update_leaderboard_on_couple_lp_change()
RETURNS TRIGGER AS $$
DECLARE
  v_user1_initial CHAR(1);
  v_user2_initial CHAR(1);
BEGIN
  -- Only proceed if total_lp actually changed
  IF OLD.total_lp = NEW.total_lp THEN
    RETURN NEW;
  END IF;

  -- Get initials from auth.users
  SELECT
    UPPER(SUBSTRING(COALESCE(raw_user_meta_data->>'full_name', 'A') FROM 1 FOR 1))
  INTO v_user1_initial
  FROM auth.users WHERE id = NEW.user1_id;

  SELECT
    UPPER(SUBSTRING(COALESCE(raw_user_meta_data->>'full_name', 'B') FROM 1 FOR 1))
  INTO v_user2_initial
  FROM auth.users WHERE id = NEW.user2_id;

  -- Upsert leaderboard entry
  INSERT INTO couple_leaderboard (
    couple_id,
    user1_initial,
    user2_initial,
    total_lp,
    user1_country,
    user2_country,
    updated_at
  )
  VALUES (
    NEW.id,
    COALESCE(v_user1_initial, 'A'),
    COALESCE(v_user2_initial, 'B'),
    NEW.total_lp,
    (SELECT country_code FROM user_love_points WHERE user_id = NEW.user1_id),
    (SELECT country_code FROM user_love_points WHERE user_id = NEW.user2_id),
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

-- Create trigger on couples table
DROP TRIGGER IF EXISTS trg_update_leaderboard_on_couple_lp ON couples;
CREATE TRIGGER trg_update_leaderboard_on_couple_lp
  AFTER UPDATE OF total_lp ON couples
  FOR EACH ROW
  EXECUTE FUNCTION update_leaderboard_on_couple_lp_change();

-- ============================================================================
-- PHASE 4: Sync leaderboard with migrated data
-- ============================================================================

-- Update couple_leaderboard to match couples.total_lp
UPDATE couple_leaderboard cl
SET total_lp = c.total_lp,
    updated_at = NOW()
FROM couples c
WHERE cl.couple_id = c.id;

-- Recalculate ranks
SELECT recalculate_leaderboard_ranks();

-- ============================================================================
-- PHASE 5: Deprecation notice (do NOT drop old trigger yet)
-- ============================================================================

-- The old trigger on user_love_points still exists for backward compatibility
-- It will be removed in a future migration (Phase 7 cleanup) after verification
-- COMMENT: trg_update_couple_leaderboard on user_love_points is DEPRECATED

-- Add deprecation comment to user_love_points.total_points
COMMENT ON COLUMN user_love_points.total_points IS 'DEPRECATED: Use couples.total_lp instead. This column will be removed in a future migration.';

-- ============================================================================
-- DONE
-- ============================================================================

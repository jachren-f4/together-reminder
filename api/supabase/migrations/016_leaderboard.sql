-- TogetherRemind Leaderboard Feature
-- Migration: 016 - Leaderboard tables and functions

-- ============================================================================
-- USER COUNTRY TRACKING
-- ============================================================================

-- Add country_code to user_love_points (ISO 3166-1 alpha-2)
ALTER TABLE user_love_points
ADD COLUMN IF NOT EXISTS country_code CHAR(2);

-- Index for country-based queries
CREATE INDEX IF NOT EXISTS idx_user_lp_country ON user_love_points(country_code);

-- ============================================================================
-- COUPLE LEADERBOARD (Pre-computed for performance)
-- ============================================================================

-- Couple leaderboard cache table
CREATE TABLE IF NOT EXISTS couple_leaderboard (
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE PRIMARY KEY,

  -- Couple display info (denormalized)
  user1_initial CHAR(1),
  user2_initial CHAR(1),

  -- Total LP (sum of both users)
  total_lp INT DEFAULT 0,

  -- Global rank (updated by cron)
  global_rank INT,

  -- Country data (each user may have different country)
  user1_country CHAR(2),
  user2_country CHAR(2),

  -- Country ranks (NULL if no country set)
  user1_country_rank INT,
  user2_country_rank INT,

  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Indexes for leaderboard queries
CREATE INDEX IF NOT EXISTS idx_leaderboard_global_rank ON couple_leaderboard(global_rank) WHERE global_rank IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_leaderboard_total_lp ON couple_leaderboard(total_lp DESC);
CREATE INDEX IF NOT EXISTS idx_leaderboard_user1_country ON couple_leaderboard(user1_country, user1_country_rank) WHERE user1_country IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_leaderboard_user2_country ON couple_leaderboard(user2_country, user2_country_rank) WHERE user2_country IS NOT NULL;

-- ============================================================================
-- FUNCTION: Update couple LP total when user LP changes
-- ============================================================================

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
    couple_id,
    user1_initial,
    user2_initial,
    total_lp,
    user1_country,
    user2_country,
    updated_at
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

-- Trigger on user_love_points changes (fires on any INSERT or UPDATE)
DROP TRIGGER IF EXISTS trg_update_couple_leaderboard ON user_love_points;
CREATE TRIGGER trg_update_couple_leaderboard
  AFTER INSERT OR UPDATE ON user_love_points
  FOR EACH ROW
  EXECUTE FUNCTION update_couple_leaderboard_lp();

-- ============================================================================
-- FUNCTION: Recalculate all ranks (called by cron every 5 minutes)
-- ============================================================================

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

-- ============================================================================
-- FUNCTION: Get global leaderboard with user context
-- ============================================================================

CREATE OR REPLACE FUNCTION get_global_leaderboard(
  p_user_id UUID,
  p_limit INT DEFAULT 50
)
RETURNS TABLE (
  couple_id UUID,
  initials TEXT,
  total_lp INT,
  global_rank INT,
  is_current_user BOOLEAN
) AS $$
DECLARE
  v_couple_id UUID;
  v_user_rank INT;
BEGIN
  -- Find user's couple
  SELECT c.id INTO v_couple_id
  FROM couples c
  WHERE c.user1_id = p_user_id OR c.user2_id = p_user_id
  LIMIT 1;

  -- Get user's rank
  SELECT cl.global_rank INTO v_user_rank
  FROM couple_leaderboard cl
  WHERE cl.couple_id = v_couple_id;

  -- Return top N plus user's context if not in top N
  RETURN QUERY
  WITH top_entries AS (
    SELECT
      cl.couple_id,
      cl.user1_initial || ' & ' || cl.user2_initial as initials,
      cl.total_lp,
      cl.global_rank,
      cl.couple_id = v_couple_id as is_current_user
    FROM couple_leaderboard cl
    WHERE cl.global_rank IS NOT NULL AND cl.global_rank <= p_limit
    ORDER BY cl.global_rank
  ),
  user_context AS (
    -- Get entries around user if not in top N
    SELECT
      cl.couple_id,
      cl.user1_initial || ' & ' || cl.user2_initial as initials,
      cl.total_lp,
      cl.global_rank,
      cl.couple_id = v_couple_id as is_current_user
    FROM couple_leaderboard cl
    WHERE cl.global_rank IS NOT NULL
      AND v_user_rank IS NOT NULL
      AND v_user_rank > p_limit
      AND cl.global_rank BETWEEN v_user_rank - 1 AND v_user_rank + 1
    ORDER BY cl.global_rank
  )
  SELECT * FROM top_entries
  UNION ALL
  SELECT * FROM user_context
  WHERE NOT EXISTS (SELECT 1 FROM top_entries WHERE top_entries.couple_id = user_context.couple_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: Get country leaderboard for a specific user
-- ============================================================================

CREATE OR REPLACE FUNCTION get_country_leaderboard(
  p_user_id UUID,
  p_limit INT DEFAULT 50
)
RETURNS TABLE (
  couple_id UUID,
  initials TEXT,
  total_lp INT,
  country_rank INT,
  country_code CHAR(2),
  is_current_user BOOLEAN
) AS $$
DECLARE
  v_couple_id UUID;
  v_user_country CHAR(2);
  v_user_rank INT;
  v_is_user1 BOOLEAN;
BEGIN
  -- Find user's couple and position
  SELECT c.id, c.user1_id = p_user_id INTO v_couple_id, v_is_user1
  FROM couples c
  WHERE c.user1_id = p_user_id OR c.user2_id = p_user_id
  LIMIT 1;

  -- Get user's country
  SELECT country_code INTO v_user_country
  FROM user_love_points
  WHERE user_id = p_user_id;

  -- If no country set, return empty
  IF v_user_country IS NULL THEN
    RETURN;
  END IF;

  -- Get user's country rank
  SELECT
    CASE WHEN v_is_user1 THEN cl.user1_country_rank ELSE cl.user2_country_rank END
  INTO v_user_rank
  FROM couple_leaderboard cl
  WHERE cl.couple_id = v_couple_id;

  -- Return entries for user's country
  RETURN QUERY
  WITH country_entries AS (
    SELECT
      cl.couple_id,
      cl.user1_initial || ' & ' || cl.user2_initial as initials,
      cl.total_lp,
      CASE WHEN v_is_user1 THEN cl.user1_country_rank ELSE cl.user2_country_rank END as country_rank,
      v_user_country as country_code,
      cl.couple_id = v_couple_id as is_current_user
    FROM couple_leaderboard cl
    WHERE (v_is_user1 AND cl.user1_country = v_user_country)
       OR (NOT v_is_user1 AND cl.user2_country = v_user_country)
  ),
  top_entries AS (
    SELECT * FROM country_entries
    WHERE country_rank IS NOT NULL AND country_rank <= p_limit
  ),
  user_context AS (
    SELECT * FROM country_entries
    WHERE country_rank IS NOT NULL
      AND v_user_rank IS NOT NULL
      AND v_user_rank > p_limit
      AND country_rank BETWEEN v_user_rank - 1 AND v_user_rank + 1
  )
  SELECT * FROM top_entries
  UNION ALL
  SELECT * FROM user_context
  WHERE NOT EXISTS (SELECT 1 FROM top_entries WHERE top_entries.couple_id = user_context.couple_id)
  ORDER BY country_rank;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE couple_leaderboard ENABLE ROW LEVEL SECURITY;

-- Everyone can read the leaderboard (it's public data)
CREATE POLICY leaderboard_read_all ON couple_leaderboard
  FOR SELECT USING (true);

-- Only system can write (via triggers/functions)
CREATE POLICY leaderboard_write_system ON couple_leaderboard
  FOR ALL USING (false)
  WITH CHECK (false);

-- ============================================================================
-- INITIAL POPULATION (run once to populate existing data)
-- ============================================================================

-- Populate leaderboard from existing couples and LP data
-- NOTE: Both users in a couple have identical LP (shared pool), so we use MAX not SUM
INSERT INTO couple_leaderboard (couple_id, user1_initial, user2_initial, total_lp, user1_country, user2_country)
SELECT
  c.id,
  UPPER(SUBSTRING(COALESCE(
    (SELECT raw_user_meta_data->>'full_name' FROM auth.users WHERE id = c.user1_id),
    'A'
  ) FROM 1 FOR 1)),
  UPPER(SUBSTRING(COALESCE(
    (SELECT raw_user_meta_data->>'full_name' FROM auth.users WHERE id = c.user2_id),
    'B'
  ) FROM 1 FOR 1)),
  -- Use MAX since both users should have identical LP (shared pool)
  GREATEST(
    COALESCE((SELECT total_points FROM user_love_points WHERE user_id = c.user1_id), 0),
    COALESCE((SELECT total_points FROM user_love_points WHERE user_id = c.user2_id), 0)
  ),
  (SELECT country_code FROM user_love_points WHERE user_id = c.user1_id),
  (SELECT country_code FROM user_love_points WHERE user_id = c.user2_id)
FROM couples c
ON CONFLICT (couple_id) DO UPDATE SET
  total_lp = EXCLUDED.total_lp,
  user1_country = EXCLUDED.user1_country,
  user2_country = EXCLUDED.user2_country,
  updated_at = NOW();

-- Calculate initial ranks
SELECT recalculate_leaderboard_ranks();

-- ============================================================================
-- DONE
-- ============================================================================

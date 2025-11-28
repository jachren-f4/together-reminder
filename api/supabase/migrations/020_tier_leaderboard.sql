-- TogetherRemind Tier-Based Leaderboard
-- Migration: 020 - Add tier tracking to couple_leaderboard

-- ============================================================================
-- ADD TIER COLUMNS TO COUPLE_LEADERBOARD
-- ============================================================================

-- Add arena_tier column (1-5, matching Flutter's LovePointService.arenas)
ALTER TABLE couple_leaderboard
ADD COLUMN IF NOT EXISTS arena_tier INT DEFAULT 1 CHECK (arena_tier BETWEEN 1 AND 5);

-- Add tier_rank column (rank within the tier)
ALTER TABLE couple_leaderboard
ADD COLUMN IF NOT EXISTS tier_rank INT;

-- ============================================================================
-- INDEXES FOR TIER-BASED QUERIES
-- ============================================================================

-- Index for tier-based ranking queries
CREATE INDEX IF NOT EXISTS idx_leaderboard_tier_rank
ON couple_leaderboard(arena_tier, tier_rank)
WHERE arena_tier IS NOT NULL;

-- Index for tier filtering with LP ordering
CREATE INDEX IF NOT EXISTS idx_leaderboard_tier_lp
ON couple_leaderboard(arena_tier, total_lp DESC);

-- ============================================================================
-- HELPER FUNCTION: Calculate tier from LP
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_arena_tier(lp INT)
RETURNS INT AS $$
BEGIN
  -- Tier thresholds (must match Flutter's LovePointService.arenas):
  -- Tier 1: Cozy Cabin (0-999)
  -- Tier 2: Beach Villa (1000-2499)
  -- Tier 3: Yacht Getaway (2500-4999)
  -- Tier 4: Mountain Penthouse (5000-9999)
  -- Tier 5: Castle Retreat (10000+)
  IF lp >= 10000 THEN RETURN 5;
  ELSIF lp >= 5000 THEN RETURN 4;
  ELSIF lp >= 2500 THEN RETURN 3;
  ELSIF lp >= 1000 THEN RETURN 2;
  ELSE RETURN 1;
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- UPDATE TRIGGER: Set arena_tier when LP changes
-- ============================================================================

CREATE OR REPLACE FUNCTION update_couple_leaderboard_lp()
RETURNS TRIGGER AS $$
DECLARE
  v_couple_id UUID;
  v_user1_id UUID;
  v_user2_id UUID;
  v_user1_initial CHAR(1);
  v_user2_initial CHAR(1);
  v_arena_tier INT;
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

  -- Calculate arena tier from LP
  v_arena_tier := calculate_arena_tier(NEW.total_points);

  -- Upsert leaderboard entry (shared pool model: use triggering user's total_points)
  INSERT INTO couple_leaderboard (
    couple_id,
    user1_initial,
    user2_initial,
    total_lp,
    arena_tier,
    user1_country,
    user2_country,
    updated_at
  )
  VALUES (
    v_couple_id,
    COALESCE(v_user1_initial, 'A'),
    COALESCE(v_user2_initial, 'B'),
    NEW.total_points,
    v_arena_tier,
    (SELECT country_code FROM user_love_points WHERE user_id = v_user1_id),
    (SELECT country_code FROM user_love_points WHERE user_id = v_user2_id),
    NOW()
  )
  ON CONFLICT (couple_id) DO UPDATE SET
    total_lp = EXCLUDED.total_lp,
    arena_tier = EXCLUDED.arena_tier,
    user1_initial = EXCLUDED.user1_initial,
    user2_initial = EXCLUDED.user2_initial,
    user1_country = EXCLUDED.user1_country,
    user2_country = EXCLUDED.user2_country,
    updated_at = NOW();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- UPDATE RANK FUNCTION: Add tier_rank calculation
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

  -- Update tier ranks (within each tier, by LP desc)
  UPDATE couple_leaderboard cl
  SET tier_rank = ranks.rank
  FROM (
    SELECT couple_id, ROW_NUMBER() OVER (PARTITION BY arena_tier ORDER BY total_lp DESC) as rank
    FROM couple_leaderboard
    WHERE total_lp > 0 AND arena_tier IS NOT NULL
  ) ranks
  WHERE cl.couple_id = ranks.couple_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: Get tier leaderboard for a user
-- ============================================================================

CREATE OR REPLACE FUNCTION get_tier_leaderboard(
  p_user_id UUID,
  p_limit INT DEFAULT 50
)
RETURNS TABLE (
  couple_id UUID,
  initials TEXT,
  total_lp INT,
  tier_rank INT,
  arena_tier INT,
  is_current_user BOOLEAN
) AS $$
DECLARE
  v_couple_id UUID;
  v_user_tier INT;
  v_user_rank INT;
BEGIN
  -- Find user's couple
  SELECT c.id INTO v_couple_id
  FROM couples c
  WHERE c.user1_id = p_user_id OR c.user2_id = p_user_id
  LIMIT 1;

  -- Get user's tier
  SELECT cl.arena_tier, cl.tier_rank INTO v_user_tier, v_user_rank
  FROM couple_leaderboard cl
  WHERE cl.couple_id = v_couple_id;

  -- If no tier found, default to tier 1
  IF v_user_tier IS NULL THEN
    v_user_tier := 1;
  END IF;

  -- Return top N in user's tier plus user's context if not in top N
  RETURN QUERY
  WITH top_entries AS (
    SELECT
      cl.couple_id,
      cl.user1_initial || ' & ' || cl.user2_initial as initials,
      cl.total_lp,
      cl.tier_rank,
      cl.arena_tier,
      cl.couple_id = v_couple_id as is_current_user
    FROM couple_leaderboard cl
    WHERE cl.arena_tier = v_user_tier
      AND cl.tier_rank IS NOT NULL
      AND cl.tier_rank <= p_limit
    ORDER BY cl.tier_rank
  ),
  user_context AS (
    -- Get entries around user if not in top N
    SELECT
      cl.couple_id,
      cl.user1_initial || ' & ' || cl.user2_initial as initials,
      cl.total_lp,
      cl.tier_rank,
      cl.arena_tier,
      cl.couple_id = v_couple_id as is_current_user
    FROM couple_leaderboard cl
    WHERE cl.arena_tier = v_user_tier
      AND cl.tier_rank IS NOT NULL
      AND v_user_rank IS NOT NULL
      AND v_user_rank > p_limit
      AND cl.tier_rank BETWEEN v_user_rank - 1 AND v_user_rank + 1
    ORDER BY cl.tier_rank
  )
  SELECT * FROM top_entries
  UNION ALL
  SELECT * FROM user_context
  WHERE NOT EXISTS (SELECT 1 FROM top_entries WHERE top_entries.couple_id = user_context.couple_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- INITIAL POPULATION: Set arena_tier for existing entries
-- ============================================================================

UPDATE couple_leaderboard
SET arena_tier = calculate_arena_tier(total_lp)
WHERE arena_tier IS NULL OR arena_tier != calculate_arena_tier(total_lp);

-- Recalculate all ranks including tier_rank
SELECT recalculate_leaderboard_ranks();

-- ============================================================================
-- DONE
-- ============================================================================

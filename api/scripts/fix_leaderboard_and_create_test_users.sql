-- PART 1: Fix the trigger function
CREATE OR REPLACE FUNCTION update_couple_leaderboard_lp()
RETURNS TRIGGER AS $$
DECLARE
  v_couple_id UUID;
  v_user1_initial CHAR(1);
  v_user2_initial CHAR(1);
  v_user1_id UUID;
  v_user2_id UUID;
BEGIN
  SELECT c.id, c.user1_id, c.user2_id INTO v_couple_id, v_user1_id, v_user2_id
  FROM couples c
  WHERE c.user1_id = NEW.user_id OR c.user2_id = NEW.user_id
  LIMIT 1;

  IF v_couple_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT
    UPPER(SUBSTRING(COALESCE(
      (SELECT raw_user_meta_data->>'full_name' FROM auth.users WHERE id = v_user1_id),
      'A'
    ) FROM 1 FOR 1)),
    UPPER(SUBSTRING(COALESCE(
      (SELECT raw_user_meta_data->>'full_name' FROM auth.users WHERE id = v_user2_id),
      'B'
    ) FROM 1 FOR 1))
  INTO v_user1_initial, v_user2_initial;

  INSERT INTO couple_leaderboard (
    couple_id, user1_initial, user2_initial, total_lp,
    user1_country, user2_country, updated_at
  )
  VALUES (
    v_couple_id,
    v_user1_initial,
    v_user2_initial,
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

-- PART 2: Update existing leaderboard data
UPDATE couple_leaderboard cl
SET total_lp = GREATEST(
  COALESCE((SELECT total_points FROM user_love_points WHERE user_id = c.user1_id), 0),
  COALESCE((SELECT total_points FROM user_love_points WHERE user_id = c.user2_id), 0)
)
FROM couples c
WHERE cl.couple_id = c.id;

-- PART 3: Recalculate ranks
SELECT recalculate_leaderboard_ranks();

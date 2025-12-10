-- Migration: 027 - User Couples Lookup Table
-- Purpose: Optimize couple lookup queries by replacing OR-based queries with direct index lookup
--
-- Problem: Current query "WHERE user1_id = $1 OR user2_id = $1" can't efficiently use indexes
-- Solution: Denormalized lookup table with primary key on user_id for O(1) lookups
--
-- See: docs/plans/DATABASE_SCALABILITY_PLAN.md (Phase 1)

-- ============================================================================
-- LOOKUP TABLE
-- ============================================================================

-- Create lookup table for O(1) user → couple mapping
CREATE TABLE IF NOT EXISTS user_couples (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Index for reverse lookups (get all users in a couple)
CREATE INDEX IF NOT EXISTS idx_user_couples_couple_id ON user_couples(couple_id);

-- ============================================================================
-- POPULATE FROM EXISTING DATA
-- ============================================================================

-- Insert existing couple relationships
INSERT INTO user_couples (user_id, couple_id)
SELECT user1_id, id FROM couples
UNION ALL
SELECT user2_id, id FROM couples
ON CONFLICT (user_id) DO NOTHING;

-- ============================================================================
-- TRIGGER TO KEEP IN SYNC
-- ============================================================================

-- Function to sync user_couples when couples table changes
CREATE OR REPLACE FUNCTION sync_user_couples()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- New couple: add both users to lookup table
    INSERT INTO user_couples (user_id, couple_id)
    VALUES (NEW.user1_id, NEW.id)
    ON CONFLICT (user_id) DO UPDATE SET couple_id = EXCLUDED.couple_id;

    INSERT INTO user_couples (user_id, couple_id)
    VALUES (NEW.user2_id, NEW.id)
    ON CONFLICT (user_id) DO UPDATE SET couple_id = EXCLUDED.couple_id;

  ELSIF TG_OP = 'UPDATE' THEN
    -- Couple updated: handle user changes (rare but possible)
    IF OLD.user1_id != NEW.user1_id THEN
      DELETE FROM user_couples WHERE user_id = OLD.user1_id;
      INSERT INTO user_couples (user_id, couple_id)
      VALUES (NEW.user1_id, NEW.id)
      ON CONFLICT (user_id) DO UPDATE SET couple_id = EXCLUDED.couple_id;
    END IF;

    IF OLD.user2_id != NEW.user2_id THEN
      DELETE FROM user_couples WHERE user_id = OLD.user2_id;
      INSERT INTO user_couples (user_id, couple_id)
      VALUES (NEW.user2_id, NEW.id)
      ON CONFLICT (user_id) DO UPDATE SET couple_id = EXCLUDED.couple_id;
    END IF;

  ELSIF TG_OP = 'DELETE' THEN
    -- Couple deleted: remove both users from lookup table
    DELETE FROM user_couples WHERE couple_id = OLD.id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_sync_user_couples ON couples;
CREATE TRIGGER trigger_sync_user_couples
AFTER INSERT OR UPDATE OR DELETE ON couples
FOR EACH ROW EXECUTE FUNCTION sync_user_couples();

-- ============================================================================
-- RLS POLICIES
-- ============================================================================

-- Enable RLS
ALTER TABLE user_couples ENABLE ROW LEVEL SECURITY;

-- Users can only see their own mapping
CREATE POLICY user_couples_select ON user_couples
  FOR SELECT USING (user_id = auth.uid());

-- Only system can insert/update/delete (via trigger)
CREATE POLICY user_couples_system ON user_couples
  FOR ALL USING (false)
  WITH CHECK (false);

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Verify data integrity (run manually after migration)
-- SELECT
--   (SELECT COUNT(*) FROM couples) * 2 AS expected_rows,
--   (SELECT COUNT(*) FROM user_couples) AS actual_rows,
--   CASE
--     WHEN (SELECT COUNT(*) FROM couples) * 2 = (SELECT COUNT(*) FROM user_couples)
--     THEN 'OK'
--     ELSE 'MISMATCH'
--   END AS status;

-- TogetherRemind Steps Together Feature
-- Migration: 018 - Steps data tables for dual-write
--
-- This migration creates tables for the Steps Together feature which tracks
-- daily step counts from both partners and awards LP based on combined totals.
--
-- Currently, this data is stored in Firebase RTDB at /steps_data/{coupleId}/
-- This migration enables dual-write to Supabase for eventual Firebase removal.

-- ============================================================================
-- STEPS CONNECTION STATUS
-- ============================================================================

-- Tracks whether each user has connected HealthKit/Health Connect
CREATE TABLE IF NOT EXISTS steps_connections (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,

  -- Connection status
  is_connected BOOLEAN DEFAULT FALSE NOT NULL,
  connected_at TIMESTAMPTZ,

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_steps_connections_couple ON steps_connections(couple_id);
CREATE INDEX IF NOT EXISTS idx_steps_connections_connected ON steps_connections(is_connected) WHERE is_connected = TRUE;

-- ============================================================================
-- DAILY STEPS DATA
-- ============================================================================

-- Stores daily step counts for each user
CREATE TABLE IF NOT EXISTS steps_daily (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,

  -- Date this record is for (YYYY-MM-DD format stored as DATE)
  date_key DATE NOT NULL,

  -- Step count from HealthKit/Health Connect
  steps INT DEFAULT 0 NOT NULL,

  -- Last sync timestamp from device
  last_sync_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,

  -- One record per user per day
  UNIQUE(user_id, date_key)
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_steps_daily_couple_date ON steps_daily(couple_id, date_key);
CREATE INDEX IF NOT EXISTS idx_steps_daily_user_date ON steps_daily(user_id, date_key DESC);
CREATE INDEX IF NOT EXISTS idx_steps_daily_date ON steps_daily(date_key);

-- ============================================================================
-- STEPS REWARDS (CLAIM TRACKING)
-- ============================================================================

-- Tracks claimed step rewards to prevent double-claiming
CREATE TABLE IF NOT EXISTS steps_rewards (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,

  -- Which day's steps this reward is for
  date_key DATE NOT NULL,

  -- Combined steps at time of claim
  combined_steps INT NOT NULL,

  -- LP amount earned (calculated from tier)
  lp_earned INT NOT NULL,

  -- Who claimed (either partner can claim)
  claimed_by UUID REFERENCES auth.users(id) NOT NULL,
  claimed_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,

  -- Prevent double-claiming: one reward per couple per day
  UNIQUE(couple_id, date_key)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_steps_rewards_couple ON steps_rewards(couple_id);
CREATE INDEX IF NOT EXISTS idx_steps_rewards_date ON steps_rewards(date_key);
CREATE INDEX IF NOT EXISTS idx_steps_rewards_claimed_by ON steps_rewards(claimed_by);

-- ============================================================================
-- HELPER FUNCTION: Calculate LP from combined steps
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_steps_lp(combined_steps INT)
RETURNS INT AS $$
BEGIN
  -- LP tier system (matches Flutter StepsDay.calculateLP)
  IF combined_steps >= 20000 THEN RETURN 30;
  ELSIF combined_steps >= 18000 THEN RETURN 27;
  ELSIF combined_steps >= 16000 THEN RETURN 24;
  ELSIF combined_steps >= 14000 THEN RETURN 21;
  ELSIF combined_steps >= 12000 THEN RETURN 18;
  ELSIF combined_steps >= 10000 THEN RETURN 15;
  ELSE RETURN 0; -- Below 10K threshold
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- VIEW: Combined daily steps for couples
-- ============================================================================

CREATE OR REPLACE VIEW steps_daily_combined AS
SELECT
  sd.couple_id,
  sd.date_key,
  SUM(sd.steps) as combined_steps,
  MAX(sd.last_sync_at) as last_sync_at,
  calculate_steps_lp(SUM(sd.steps)::INT) as potential_lp,
  COUNT(DISTINCT sd.user_id) as users_synced,
  EXISTS(
    SELECT 1 FROM steps_rewards sr
    WHERE sr.couple_id = sd.couple_id AND sr.date_key = sd.date_key
  ) as is_claimed
FROM steps_daily sd
GROUP BY sd.couple_id, sd.date_key;

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE steps_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE steps_daily ENABLE ROW LEVEL SECURITY;
ALTER TABLE steps_rewards ENABLE ROW LEVEL SECURITY;

-- steps_connections: Users can read/write their own connection status
CREATE POLICY steps_connections_own ON steps_connections
  FOR ALL USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- steps_connections: Users can read partner's connection status
CREATE POLICY steps_connections_partner_read ON steps_connections
  FOR SELECT USING (
    couple_id IN (
      SELECT id FROM couples WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

-- steps_daily: Users can read/write their own daily steps
CREATE POLICY steps_daily_own ON steps_daily
  FOR ALL USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- steps_daily: Users can read partner's daily steps (for combined view)
CREATE POLICY steps_daily_partner_read ON steps_daily
  FOR SELECT USING (
    couple_id IN (
      SELECT id FROM couples WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

-- steps_rewards: Users can read/write rewards for their couple
CREATE POLICY steps_rewards_couple ON steps_rewards
  FOR ALL USING (
    couple_id IN (
      SELECT id FROM couples WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  )
  WITH CHECK (
    couple_id IN (
      SELECT id FROM couples WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

-- ============================================================================
-- DONE
-- ============================================================================

-- ============================================================================
-- MIGRATION 024: Love Point Transactions Table
-- ============================================================================
-- Creates the love_point_transactions table for tracking LP history.
-- This is needed by quiz-match/submit API to record LP awards.
-- ============================================================================

-- Love point transaction history
CREATE TABLE IF NOT EXISTS love_point_transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  amount INT NOT NULL,
  source VARCHAR(50) NOT NULL, -- 'quiz_complete', 'game_complete', 'streak_bonus', etc.
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Index for querying user's transaction history
CREATE INDEX IF NOT EXISTS idx_lp_transactions_user_id ON love_point_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_lp_transactions_created_at ON love_point_transactions(created_at DESC);

-- RLS
ALTER TABLE love_point_transactions ENABLE ROW LEVEL SECURITY;

-- Users can view their own transactions
CREATE POLICY lp_transactions_select ON love_point_transactions
  FOR SELECT USING (user_id = auth.uid());

-- Only system can insert (via service role or dev bypass)
CREATE POLICY lp_transactions_insert ON love_point_transactions
  FOR INSERT WITH CHECK (true);

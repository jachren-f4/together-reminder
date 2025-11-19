-- Migration 004: Enhanced Row Level Security Policies
-- Complete RLS policies for all tables

-- ============================================================================
-- YOU OR ME SYSTEM
-- ============================================================================

-- You or Me sessions: Users can see sessions for their couple
CREATE POLICY you_or_me_session_access ON you_or_me_sessions
  FOR ALL USING (
    couple_id IN (
      SELECT id FROM couples
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

-- You or Me answers: Users can see answers for their couple's sessions
CREATE POLICY you_or_me_answer_access ON you_or_me_answers
  FOR ALL USING (
    session_id IN (
      SELECT yom.id FROM you_or_me_sessions yom
      JOIN couples c ON yom.couple_id = c.id
      WHERE c.user1_id = auth.uid() OR c.user2_id = auth.uid()
    )
  );

-- You or Me progression: Users can see progression for their couple
CREATE POLICY you_or_me_progression_access ON you_or_me_progression
  FOR ALL USING (
    couple_id IN (
      SELECT id FROM couples
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

-- ============================================================================
-- MEMORY FLIP SYSTEM
-- ============================================================================

-- Memory puzzles: Users can see puzzles for their couple
CREATE POLICY memory_puzzle_access ON memory_puzzles
  FOR ALL USING (
    couple_id IN (
      SELECT id FROM couples
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

-- ============================================================================
-- LOVE POINTS SYSTEM
-- ============================================================================

-- LP awards: Users can see awards for their couple
CREATE POLICY lp_award_access ON love_point_awards
  FOR ALL USING (
    couple_id IN (
      SELECT id FROM couples
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

-- User LP totals: Users can see their own totals
CREATE POLICY user_lp_access ON user_love_points
  FOR ALL USING (
    user_id = auth.uid()
  );

-- ============================================================================
-- QUIZ PROGRESSION
-- ============================================================================

-- Quiz progression: Users can see progression for their couple
CREATE POLICY quiz_progression_access ON quiz_progression
  FOR ALL USING (
    couple_id IN (
      SELECT id FROM couples
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

-- ============================================================================
-- FUNCTIONS FOR RLS HELPERS
-- ============================================================================

-- Helper function: Check if user is part of a couple
CREATE OR REPLACE FUNCTION is_couple_member(couple_uuid UUID)
RETURNS BOOLEAN
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM couples
    WHERE id = couple_uuid
    AND (user1_id = auth.uid() OR user2_id = auth.uid())
  );
$$;

-- Helper function: Get user's couple ID
CREATE OR REPLACE FUNCTION get_user_couple_id()
RETURNS UUID
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id FROM couples
  WHERE user1_id = auth.uid() OR user2_id = auth.uid()
  LIMIT 1;
$$;

COMMENT ON FUNCTION is_couple_member IS 'Checks if current user is member of specified couple';
COMMENT ON FUNCTION get_user_couple_id IS 'Returns the couple ID for the current user';

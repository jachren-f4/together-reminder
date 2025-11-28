-- Migration: 021_quiz_api_migration.sql
-- Description: Enhance quiz and you_or_me tables for full API support (replacing Firebase RTDB)
-- Created: 2025-11-28
-- Goal: Match the Linked/Word Search pattern for server-authoritative sync

-- ============================================================================
-- QUIZ SESSIONS - Add missing columns from Flutter model
-- ============================================================================

-- Add subject_user_id (who the quiz is ABOUT in knowledge test model)
ALTER TABLE quiz_sessions
ADD COLUMN IF NOT EXISTS subject_user_id UUID REFERENCES auth.users(id);

-- Add initiated_by (who started the quiz)
ALTER TABLE quiz_sessions
ADD COLUMN IF NOT EXISTS initiated_by UUID REFERENCES auth.users(id);

-- Add daily_quest_id for linking back to daily quest
ALTER TABLE quiz_sessions
ADD COLUMN IF NOT EXISTS daily_quest_id UUID;

-- Add answers as JSONB (userId -> [answer indices]) - matches Flutter model
ALTER TABLE quiz_sessions
ADD COLUMN IF NOT EXISTS answers JSONB DEFAULT '{}';

-- Add predictions for Would You Rather format
ALTER TABLE quiz_sessions
ADD COLUMN IF NOT EXISTS predictions JSONB DEFAULT '{}';

-- Add match_percentage (calculated after both submit)
ALTER TABLE quiz_sessions
ADD COLUMN IF NOT EXISTS match_percentage INT;

-- Add lp_earned
ALTER TABLE quiz_sessions
ADD COLUMN IF NOT EXISTS lp_earned INT;

-- Add alignment_matches for Would You Rather
ALTER TABLE quiz_sessions
ADD COLUMN IF NOT EXISTS alignment_matches INT DEFAULT 0;

-- Add prediction_scores for Would You Rather
ALTER TABLE quiz_sessions
ADD COLUMN IF NOT EXISTS prediction_scores JSONB DEFAULT '{}';

-- Add branch for content branching (future use)
ALTER TABLE quiz_sessions
ADD COLUMN IF NOT EXISTS branch TEXT;

-- Add date for daily quest lookup
ALTER TABLE quiz_sessions
ADD COLUMN IF NOT EXISTS date DATE;

-- ============================================================================
-- YOU OR ME SESSIONS - Add missing columns from Flutter model
-- ============================================================================

-- Add creator/partner IDs
ALTER TABLE you_or_me_sessions
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

ALTER TABLE you_or_me_sessions
ADD COLUMN IF NOT EXISTS partner_id UUID REFERENCES auth.users(id);

-- Add quest_id for daily quest linking
ALTER TABLE you_or_me_sessions
ADD COLUMN IF NOT EXISTS quest_id UUID;

-- Add answers as JSONB (userId -> [YouOrMeAnswer objects])
ALTER TABLE you_or_me_sessions
ADD COLUMN IF NOT EXISTS answers JSONB DEFAULT '{}';

-- Add status
ALTER TABLE you_or_me_sessions
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'in_progress'
CHECK (status IN ('in_progress', 'completed'));

-- Add completed_at
ALTER TABLE you_or_me_sessions
ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

-- Add lp_earned
ALTER TABLE you_or_me_sessions
ADD COLUMN IF NOT EXISTS lp_earned INT;

-- Add initiated_by
ALTER TABLE you_or_me_sessions
ADD COLUMN IF NOT EXISTS initiated_by UUID REFERENCES auth.users(id);

-- Add subject_user_id
ALTER TABLE you_or_me_sessions
ADD COLUMN IF NOT EXISTS subject_user_id UUID REFERENCES auth.users(id);

-- Add date for daily quest lookup
ALTER TABLE you_or_me_sessions
ADD COLUMN IF NOT EXISTS date DATE;

-- Add branch for content branching
ALTER TABLE you_or_me_sessions
ADD COLUMN IF NOT EXISTS branch TEXT;

-- ============================================================================
-- INDEXES for API queries
-- ============================================================================

-- Quiz sessions: lookup by couple + date (daily quest pattern)
CREATE INDEX IF NOT EXISTS idx_quiz_sessions_couple_date
ON quiz_sessions(couple_id, date);

-- Quiz sessions: lookup by couple + format_type + date
CREATE INDEX IF NOT EXISTS idx_quiz_sessions_couple_format_date
ON quiz_sessions(couple_id, format_type, date);

-- You or Me sessions: lookup by couple + date
CREATE INDEX IF NOT EXISTS idx_you_or_me_sessions_couple_date
ON you_or_me_sessions(couple_id, date);

-- You or Me sessions: lookup by couple
CREATE INDEX IF NOT EXISTS idx_you_or_me_sessions_couple
ON you_or_me_sessions(couple_id);

-- ============================================================================
-- UNIQUE CONSTRAINTS for "get or create" pattern
-- ============================================================================

-- Quiz: One session per couple per format_type per date
-- (allows multiple format types on same day, e.g., classic + affirmation)
CREATE UNIQUE INDEX IF NOT EXISTS idx_quiz_sessions_unique_daily
ON quiz_sessions(couple_id, format_type, date)
WHERE date IS NOT NULL;

-- You or Me: One session per couple per date
CREATE UNIQUE INDEX IF NOT EXISTS idx_you_or_me_sessions_unique_daily
ON you_or_me_sessions(couple_id, date)
WHERE date IS NOT NULL;

-- ============================================================================
-- RLS POLICIES for you_or_me tables (complete the missing ones from 001)
-- ============================================================================

-- Drop existing policies if they exist (to recreate cleanly)
DROP POLICY IF EXISTS you_or_me_session_access ON you_or_me_sessions;
DROP POLICY IF EXISTS you_or_me_answer_access ON you_or_me_answers;
DROP POLICY IF EXISTS you_or_me_progression_access ON you_or_me_progression;

-- You or Me sessions: Users can only see sessions for their couple
CREATE POLICY you_or_me_session_access ON you_or_me_sessions
  FOR ALL USING (
    couple_id IN (
      SELECT id FROM couples
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

-- You or Me answers: Users can only see answers for their couple's sessions
CREATE POLICY you_or_me_answer_access ON you_or_me_answers
  FOR ALL USING (
    session_id IN (
      SELECT yom.id FROM you_or_me_sessions yom
      JOIN couples c ON yom.couple_id = c.id
      WHERE c.user1_id = auth.uid() OR c.user2_id = auth.uid()
    )
  );

-- You or Me progression: Users can only access their couple's progression
CREATE POLICY you_or_me_progression_access ON you_or_me_progression
  FOR ALL USING (
    couple_id IN (
      SELECT id FROM couples
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

-- ============================================================================
-- COMMENTS for documentation
-- ============================================================================

COMMENT ON TABLE quiz_sessions IS 'Quiz game sessions - supports classic, affirmation, speed_round, would_you_rather formats';
COMMENT ON COLUMN quiz_sessions.subject_user_id IS 'In knowledge test model: who the quiz is ABOUT (predictor guesses their answers)';
COMMENT ON COLUMN quiz_sessions.answers IS 'JSONB: {userId: [answerIndices]} - each users submitted answers';
COMMENT ON COLUMN quiz_sessions.predictions IS 'JSONB: {userId: [predictedIndices]} - for Would You Rather format';
COMMENT ON COLUMN quiz_sessions.date IS 'Date for daily quest lookup - enables get-or-create pattern';

COMMENT ON TABLE you_or_me_sessions IS 'You or Me game sessions - 10 questions per session';
COMMENT ON COLUMN you_or_me_sessions.answers IS 'JSONB: {userId: [YouOrMeAnswer objects]} - partial answers supported';
COMMENT ON COLUMN you_or_me_sessions.date IS 'Date for daily quest lookup - enables get-or-create pattern';

-- ============================================================================
-- DONE
-- ============================================================================

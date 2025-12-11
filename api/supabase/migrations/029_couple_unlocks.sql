-- Migration: 029_couple_unlocks
-- Description: Tracks feature unlock state for guided onboarding
-- Each couple progresses through features sequentially after pairing

-- Create the couple_unlocks table
CREATE TABLE IF NOT EXISTS couple_unlocks (
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE PRIMARY KEY,

  -- Welcome Quiz state
  welcome_quiz_completed BOOLEAN DEFAULT FALSE,

  -- Feature unlocks (unlocked after completing previous feature)
  classic_quiz_unlocked BOOLEAN DEFAULT FALSE,
  affirmation_quiz_unlocked BOOLEAN DEFAULT FALSE,
  you_or_me_unlocked BOOLEAN DEFAULT FALSE,
  linked_unlocked BOOLEAN DEFAULT FALSE,
  word_search_unlocked BOOLEAN DEFAULT FALSE,
  steps_unlocked BOOLEAN DEFAULT FALSE,

  -- Track if onboarding is fully complete (all features unlocked)
  onboarding_completed BOOLEAN DEFAULT FALSE,

  -- LP intro shown flag (per-couple, shown when first landing on home)
  lp_intro_shown BOOLEAN DEFAULT FALSE,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_couple_unlocks_couple_id ON couple_unlocks(couple_id);

-- Add trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_couple_unlocks_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_couple_unlocks_updated_at ON couple_unlocks;
CREATE TRIGGER trigger_couple_unlocks_updated_at
  BEFORE UPDATE ON couple_unlocks
  FOR EACH ROW
  EXECUTE FUNCTION update_couple_unlocks_updated_at();

-- Welcome Quiz answers table (stores each user's answers)
CREATE TABLE IF NOT EXISTS welcome_quiz_answers (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,

  -- Store answers as JSONB array: [{"questionId": "q1", "answer": "A"}, ...]
  answers JSONB NOT NULL DEFAULT '[]',

  completed_at TIMESTAMPTZ DEFAULT NOW(),

  -- Each user can only have one answer set per couple
  UNIQUE(couple_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_welcome_quiz_answers_couple ON welcome_quiz_answers(couple_id);
CREATE INDEX IF NOT EXISTS idx_welcome_quiz_answers_user ON welcome_quiz_answers(user_id);

-- Function to check if both partners have completed the welcome quiz
CREATE OR REPLACE FUNCTION check_welcome_quiz_completion(p_couple_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  answer_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO answer_count
  FROM welcome_quiz_answers
  WHERE couple_id = p_couple_id;

  RETURN answer_count >= 2;
END;
$$ LANGUAGE plpgsql;

-- Function to get welcome quiz results (both partners' answers for comparison)
CREATE OR REPLACE FUNCTION get_welcome_quiz_results(p_couple_id UUID)
RETURNS TABLE (
  question_id TEXT,
  user1_id UUID,
  user1_answer TEXT,
  user2_id UUID,
  user2_answer TEXT,
  is_match BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  WITH answers_expanded AS (
    SELECT
      wqa.user_id,
      (elem->>'questionId') as q_id,
      (elem->>'answer') as answer
    FROM welcome_quiz_answers wqa,
         jsonb_array_elements(wqa.answers) as elem
    WHERE wqa.couple_id = p_couple_id
  ),
  user_list AS (
    SELECT DISTINCT user_id
    FROM answers_expanded
    ORDER BY user_id
    LIMIT 2
  ),
  user_numbered AS (
    SELECT user_id, ROW_NUMBER() OVER (ORDER BY user_id) as user_num
    FROM user_list
  ),
  u1_answers AS (
    SELECT ae.q_id, ae.user_id, ae.answer
    FROM answers_expanded ae
    JOIN user_numbered un ON ae.user_id = un.user_id
    WHERE un.user_num = 1
  ),
  u2_answers AS (
    SELECT ae.q_id, ae.user_id, ae.answer
    FROM answers_expanded ae
    JOIN user_numbered un ON ae.user_id = un.user_id
    WHERE un.user_num = 2
  )
  SELECT
    u1.q_id as question_id,
    u1.user_id as user1_id,
    u1.answer as user1_answer,
    u2.user_id as user2_id,
    u2.answer as user2_answer,
    (u1.answer = u2.answer) as is_match
  FROM u1_answers u1
  JOIN u2_answers u2 ON u1.q_id = u2.q_id
  ORDER BY u1.q_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add RLS policies
ALTER TABLE couple_unlocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE welcome_quiz_answers ENABLE ROW LEVEL SECURITY;

-- Users can read their couple's unlock state
CREATE POLICY couple_unlocks_select ON couple_unlocks
  FOR SELECT
  USING (
    couple_id IN (
      SELECT c.id FROM couples c
      WHERE c.user1_id = auth.uid() OR c.user2_id = auth.uid()
    )
  );

-- Users can insert/update their couple's unlock state (via API)
CREATE POLICY couple_unlocks_insert ON couple_unlocks
  FOR INSERT
  WITH CHECK (
    couple_id IN (
      SELECT c.id FROM couples c
      WHERE c.user1_id = auth.uid() OR c.user2_id = auth.uid()
    )
  );

CREATE POLICY couple_unlocks_update ON couple_unlocks
  FOR UPDATE
  USING (
    couple_id IN (
      SELECT c.id FROM couples c
      WHERE c.user1_id = auth.uid() OR c.user2_id = auth.uid()
    )
  );

-- Users can read/write their own quiz answers
CREATE POLICY welcome_quiz_answers_select ON welcome_quiz_answers
  FOR SELECT
  USING (
    couple_id IN (
      SELECT c.id FROM couples c
      WHERE c.user1_id = auth.uid() OR c.user2_id = auth.uid()
    )
  );

CREATE POLICY welcome_quiz_answers_insert ON welcome_quiz_answers
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY welcome_quiz_answers_update ON welcome_quiz_answers
  FOR UPDATE
  USING (user_id = auth.uid());

-- Grant access to service role for API operations
GRANT ALL ON couple_unlocks TO service_role;
GRANT ALL ON welcome_quiz_answers TO service_role;
GRANT EXECUTE ON FUNCTION check_welcome_quiz_completion TO service_role;
GRANT EXECUTE ON FUNCTION get_welcome_quiz_results TO service_role;

-- Migration 023: Create quiz_matches table
-- Part of Quiz Migration to Linked/WordSearch architecture

-- Create quiz_matches table (unified table for classic, affirmation, you_or_me quizzes)
CREATE TABLE IF NOT EXISTS quiz_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID NOT NULL REFERENCES couples(id),
  quiz_id TEXT NOT NULL,              -- "quiz_001" from JSON file
  quiz_type TEXT NOT NULL,            -- 'classic' | 'affirmation' | 'you_or_me'
  branch TEXT NOT NULL,               -- 'lighthearted' | 'emotional' | 'playful' etc.
  status TEXT DEFAULT 'active',       -- 'active' | 'completed'

  -- Answer storage (like Linked boardState)
  player1_answers JSONB DEFAULT '[]', -- [0, 2, 1, 3, 4] (answer indices)
  player2_answers JSONB DEFAULT '[]',

  -- For You-or-Me: incremental answers
  player1_answer_count INT DEFAULT 0,
  player2_answer_count INT DEFAULT 0,

  -- Turn management (for You-or-Me)
  current_turn_user_id UUID,
  turn_number INT DEFAULT 0,

  -- Results (computed on completion)
  match_percentage INT,               -- Classic/Affirmation: alignment %
  player1_score INT DEFAULT 0,
  player2_score INT DEFAULT 0,

  -- Player tracking
  player1_id UUID NOT NULL,
  player2_id UUID NOT NULL,

  -- Timestamps
  date DATE NOT NULL,                 -- For daily uniqueness
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,

  -- One quiz per type per day per couple
  UNIQUE(couple_id, quiz_type, date)
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_quiz_matches_couple ON quiz_matches(couple_id);
CREATE INDEX IF NOT EXISTS idx_quiz_matches_date ON quiz_matches(date);
CREATE INDEX IF NOT EXISTS idx_quiz_matches_status ON quiz_matches(status);
CREATE INDEX IF NOT EXISTS idx_quiz_matches_type ON quiz_matches(quiz_type);

-- Add comment for documentation
COMMENT ON TABLE quiz_matches IS 'Unified quiz match table for classic, affirmation, and you-or-me quizzes. Uses server-centric architecture matching Linked/WordSearch pattern.';

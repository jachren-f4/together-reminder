-- TogetherRemind Initial Database Schema
-- Migration: 001 - Core Tables and RLS

-- ============================================================================
-- COUPLES & USERS
-- ============================================================================

-- Users table is created automatically by Supabase Auth

-- Couples table (main relationship table)
CREATE TABLE IF NOT EXISTS couples (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user1_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  user2_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,

  -- Users must be different
  CONSTRAINT different_users CHECK (user1_id != user2_id),
  
  -- Unique pairing (prevents duplicate relationships)
  CONSTRAINT unique_couple UNIQUE(user1_id, user2_id)
);

-- ============================================================================
-- DAILY QUESTS
-- ============================================================================

-- Daily quests (server-generated, client-synced)
CREATE TABLE IF NOT EXISTS daily_quests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,
  date DATE NOT NULL,
  quest_type TEXT NOT NULL, -- 'quiz', 'you_or_me', etc.
  content_id UUID NOT NULL, -- References quiz_sessions, you_or_me_sessions, etc.
  sort_order INT NOT NULL,
  is_side_quest BOOLEAN DEFAULT FALSE,

  -- Metadata (denormalized for fast reads)
  metadata JSONB DEFAULT '{}'::jsonb,

  generated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,

  -- Ensure one set of quests per couple per day
  CONSTRAINT unique_quest_per_day UNIQUE(couple_id, date, quest_type, sort_order)
);

-- Quest completions (track individual progress)
CREATE TABLE IF NOT EXISTS quest_completions (
  quest_id UUID REFERENCES daily_quests(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  completed_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,

  PRIMARY KEY(quest_id, user_id)
);

-- ============================================================================
-- QUIZ SYSTEM
-- ============================================================================

-- Quiz sessions
CREATE TABLE IF NOT EXISTS quiz_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,
  created_by UUID REFERENCES auth.users(id) NOT NULL,

  format_type TEXT NOT NULL, -- 'classic', 'affirmation', 'speed_round'
  category TEXT,
  difficulty INT,

  status TEXT DEFAULT 'waiting_for_answers', -- 'waiting_for_answers', 'completed'

  -- Questions (stored as JSONB)
  questions JSONB NOT NULL,

  -- Denormalized metadata
  quiz_name TEXT,
  is_daily_quest BOOLEAN DEFAULT FALSE,

  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  expires_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
);

-- Quiz answers
CREATE TABLE IF NOT EXISTS quiz_answers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES quiz_sessions(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  question_id TEXT NOT NULL, -- ID from questions JSONB
  selected_index INT NOT NULL,
  is_correct BOOLEAN NOT NULL,
  answered_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,

  UNIQUE(session_id, user_id, question_id)
);

-- Quiz progression (tracks couple's progress through quiz tracks)
CREATE TABLE IF NOT EXISTS quiz_progression (
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE PRIMARY KEY,
  current_track INT DEFAULT 0,
  current_position INT DEFAULT 0,
  total_quizzes_completed INT DEFAULT 0,
  completed_quizzes JSONB DEFAULT '[]'::jsonb,
  has_completed_all_tracks BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================================================
-- YOU OR ME GAME
-- ============================================================================

-- You or Me sessions
CREATE TABLE IF NOT EXISTS you_or_me_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,

  -- Questions (stored as JSONB)
  questions JSONB NOT NULL,

  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  expires_at TIMESTAMPTZ
);

-- You or Me answers
CREATE TABLE IF NOT EXISTS you_or_me_answers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES you_or_me_sessions(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  question_id TEXT NOT NULL, -- ID from questions JSONB
  answer TEXT NOT NULL, -- 'you', 'me', 'both'
  answered_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,

  UNIQUE(session_id, user_id, question_id)
);

-- You or Me progression (track used questions per couple)
CREATE TABLE IF NOT EXISTS you_or_me_progression (
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE PRIMARY KEY,
  used_question_ids JSONB DEFAULT '[]'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================================================
-- MEMORY FLIP GAME
-- ============================================================================

-- Memory puzzles
CREATE TABLE IF NOT EXISTS memory_puzzles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,
  date DATE NOT NULL,

  -- Puzzle configuration
  total_pairs INT NOT NULL,
  matched_pairs INT DEFAULT 0,

  -- Cards (stored as JSONB)
  cards JSONB NOT NULL,

  status TEXT DEFAULT 'active', -- 'active', 'completed'
  completion_quote TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  completed_at TIMESTAMPTZ,

  UNIQUE(couple_id, date) -- One puzzle per couple per day
);

-- ============================================================================
-- LOVE POINTS
-- ============================================================================

-- LP awards (deduplication via related_id)
CREATE TABLE IF NOT EXISTS love_point_awards (
  id UUID PRIMARY KEY, -- Client-generated for idempotency
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,
  amount INT NOT NULL CHECK (amount > 0),
  reason TEXT NOT NULL,
  related_id UUID, -- e.g., quest_id, session_id (for deduplication)
  multiplier INT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,

  -- Prevent duplicate awards for same activity
  CONSTRAINT unique_related_award UNIQUE(couple_id, related_id)
);

-- User LP totals (materialized for performance)
CREATE TABLE IF NOT EXISTS user_love_points (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  total_points INT DEFAULT 0 CHECK (total_points >= 0),
  arena_tier INT DEFAULT 1 CHECK (arena_tier BETWEEN 1 AND 5),
  floor INT DEFAULT 0 CHECK (floor >= 0),
  last_activity_date TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Couples
CREATE INDEX IF NOT EXISTS idx_couples_user1 ON couples(user1_id);
CREATE INDEX IF NOT EXISTS idx_couples_user2 ON couples(user2_id);

-- Daily quests
CREATE INDEX IF NOT EXISTS idx_daily_quests_couple_date ON daily_quests(couple_id, date);
CREATE INDEX IF NOT EXISTS idx_daily_quests_expires ON daily_quests(expires_at);

-- Quest completions
CREATE INDEX IF NOT EXISTS idx_quest_completions_user ON quest_completions(user_id);

-- Quiz sessions
CREATE INDEX IF NOT EXISTS idx_quiz_sessions_couple ON quiz_sessions(couple_id);
CREATE INDEX IF NOT EXISTS idx_quiz_sessions_status ON quiz_sessions(status);

-- LP awards
CREATE INDEX IF NOT EXISTS idx_lp_awards_couple ON love_point_awards(couple_id);
CREATE INDEX IF NOT EXISTS idx_lp_awards_created ON love_point_awards(created_at DESC);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE couples ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_quests ENABLE ROW LEVEL SECURITY;
ALTER TABLE quest_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_progression ENABLE ROW LEVEL SECURITY;
ALTER TABLE you_or_me_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE you_or_me_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE you_or_me_progression ENABLE ROW LEVEL SECURITY;
ALTER TABLE memory_puzzles ENABLE ROW LEVEL SECURITY;
ALTER TABLE love_point_awards ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_love_points ENABLE ROW LEVEL SECURITY;

-- Couples: Users can only see/modify couples they're part of
CREATE POLICY couple_access ON couples
  FOR ALL USING (
    user1_id = auth.uid() OR user2_id = auth.uid()
  );

-- Daily quests: Users can only see quests for their couple
CREATE POLICY quest_access ON daily_quests
  FOR ALL USING (
    couple_id IN (
      SELECT id FROM couples
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

-- Quest completions: Users can only see completions for their couple's quests
CREATE POLICY completion_access ON quest_completions
  FOR ALL USING (
    quest_id IN (
      SELECT dq.id FROM daily_quests dq
      JOIN couples c ON dq.couple_id = c.id
      WHERE c.user1_id = auth.uid() OR c.user2_id = auth.uid()
    )
  );

-- Quiz sessions: Users can only see sessions for their couple
CREATE POLICY quiz_session_access ON quiz_sessions
  FOR ALL USING (
    couple_id IN (
      SELECT id FROM couples
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

-- Quiz answers: Users can only see answers for their couple's sessions
CREATE POLICY quiz_answer_access ON quiz_answers
  FOR ALL USING (
    session_id IN (
      SELECT qs.id FROM quiz_sessions qs
      JOIN couples c ON qs.couple_id = c.id
      WHERE c.user1_id = auth.uid() OR c.user2_id = auth.uid()
    )
  );

-- Apply similar RLS policies to other tables (you_or_me, memory, LP)

-- ============================================================================
-- DONE
-- ============================================================================

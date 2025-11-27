-- White-Label Support: Add brand_id to all tables
-- Migration: 014 - Multi-brand support
--
-- This migration adds brand_id column to enable white-label apps
-- to share the same database during development while keeping
-- data logically separated.
--
-- Strategy:
-- - All existing data defaults to 'togetherremind'
-- - New brands use their brand identifier (e.g., 'holycouples')
-- - RLS policies can be updated later for strict enforcement
-- - Indexes added for efficient brand-filtered queries

-- ============================================================================
-- CORE TABLES
-- ============================================================================

-- Couples table - the foundation of all relationships
ALTER TABLE couples
ADD COLUMN IF NOT EXISTS brand_id TEXT NOT NULL DEFAULT 'togetherremind';

CREATE INDEX IF NOT EXISTS idx_couples_brand
ON couples(brand_id);

-- Couple invites - pairing codes
ALTER TABLE couple_invites
ADD COLUMN IF NOT EXISTS brand_id TEXT NOT NULL DEFAULT 'togetherremind';

CREATE INDEX IF NOT EXISTS idx_couple_invites_brand
ON couple_invites(brand_id);

-- ============================================================================
-- QUEST SYSTEM
-- ============================================================================

-- Daily quests
ALTER TABLE daily_quests
ADD COLUMN IF NOT EXISTS brand_id TEXT NOT NULL DEFAULT 'togetherremind';

CREATE INDEX IF NOT EXISTS idx_daily_quests_brand
ON daily_quests(brand_id);

-- Composite index for brand + date queries (common pattern)
CREATE INDEX IF NOT EXISTS idx_daily_quests_brand_date
ON daily_quests(brand_id, date);

-- Quest completions (inherits brand from quest, but add for direct queries)
ALTER TABLE quest_completions
ADD COLUMN IF NOT EXISTS brand_id TEXT NOT NULL DEFAULT 'togetherremind';

CREATE INDEX IF NOT EXISTS idx_quest_completions_brand
ON quest_completions(brand_id);

-- ============================================================================
-- QUIZ SYSTEM
-- ============================================================================

-- Quiz sessions
ALTER TABLE quiz_sessions
ADD COLUMN IF NOT EXISTS brand_id TEXT NOT NULL DEFAULT 'togetherremind';

CREATE INDEX IF NOT EXISTS idx_quiz_sessions_brand
ON quiz_sessions(brand_id);

-- Quiz answers (inherits brand from session)
ALTER TABLE quiz_answers
ADD COLUMN IF NOT EXISTS brand_id TEXT NOT NULL DEFAULT 'togetherremind';

CREATE INDEX IF NOT EXISTS idx_quiz_answers_brand
ON quiz_answers(brand_id);

-- Quiz progression
ALTER TABLE quiz_progression
ADD COLUMN IF NOT EXISTS brand_id TEXT NOT NULL DEFAULT 'togetherremind';

CREATE INDEX IF NOT EXISTS idx_quiz_progression_brand
ON quiz_progression(brand_id);

-- ============================================================================
-- YOU OR ME GAME
-- ============================================================================

-- You or Me sessions
ALTER TABLE you_or_me_sessions
ADD COLUMN IF NOT EXISTS brand_id TEXT NOT NULL DEFAULT 'togetherremind';

CREATE INDEX IF NOT EXISTS idx_you_or_me_sessions_brand
ON you_or_me_sessions(brand_id);

-- You or Me answers
ALTER TABLE you_or_me_answers
ADD COLUMN IF NOT EXISTS brand_id TEXT NOT NULL DEFAULT 'togetherremind';

CREATE INDEX IF NOT EXISTS idx_you_or_me_answers_brand
ON you_or_me_answers(brand_id);

-- You or Me progression
ALTER TABLE you_or_me_progression
ADD COLUMN IF NOT EXISTS brand_id TEXT NOT NULL DEFAULT 'togetherremind';

CREATE INDEX IF NOT EXISTS idx_you_or_me_progression_brand
ON you_or_me_progression(brand_id);

-- ============================================================================
-- MEMORY FLIP GAME
-- ============================================================================

ALTER TABLE memory_puzzles
ADD COLUMN IF NOT EXISTS brand_id TEXT NOT NULL DEFAULT 'togetherremind';

CREATE INDEX IF NOT EXISTS idx_memory_puzzles_brand
ON memory_puzzles(brand_id);

-- ============================================================================
-- LOVE POINTS
-- ============================================================================

-- LP awards
ALTER TABLE love_point_awards
ADD COLUMN IF NOT EXISTS brand_id TEXT NOT NULL DEFAULT 'togetherremind';

CREATE INDEX IF NOT EXISTS idx_love_point_awards_brand
ON love_point_awards(brand_id);

-- User LP totals
ALTER TABLE user_love_points
ADD COLUMN IF NOT EXISTS brand_id TEXT NOT NULL DEFAULT 'togetherremind';

CREATE INDEX IF NOT EXISTS idx_user_love_points_brand
ON user_love_points(brand_id);

-- ============================================================================
-- REMINDERS & POKES
-- ============================================================================

-- Check if tables exist before altering (these may be optional)
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE tablename = 'reminders') THEN
    ALTER TABLE reminders
    ADD COLUMN IF NOT EXISTS brand_id TEXT NOT NULL DEFAULT 'togetherremind';

    CREATE INDEX IF NOT EXISTS idx_reminders_brand ON reminders(brand_id);
  END IF;

  IF EXISTS (SELECT FROM pg_tables WHERE tablename = 'pokes') THEN
    ALTER TABLE pokes
    ADD COLUMN IF NOT EXISTS brand_id TEXT NOT NULL DEFAULT 'togetherremind';

    CREATE INDEX IF NOT EXISTS idx_pokes_brand ON pokes(brand_id);
  END IF;
END $$;

-- ============================================================================
-- LINKED GAME
-- ============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE tablename = 'linked_puzzles') THEN
    ALTER TABLE linked_puzzles
    ADD COLUMN IF NOT EXISTS brand_id TEXT NOT NULL DEFAULT 'togetherremind';

    CREATE INDEX IF NOT EXISTS idx_linked_puzzles_brand ON linked_puzzles(brand_id);
  END IF;
END $$;

-- ============================================================================
-- WORD SEARCH GAME
-- ============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE tablename = 'word_search_puzzles') THEN
    ALTER TABLE word_search_puzzles
    ADD COLUMN IF NOT EXISTS brand_id TEXT NOT NULL DEFAULT 'togetherremind';

    CREATE INDEX IF NOT EXISTS idx_word_search_puzzles_brand ON word_search_puzzles(brand_id);
  END IF;

  IF EXISTS (SELECT FROM pg_tables WHERE tablename = 'word_search_scores') THEN
    ALTER TABLE word_search_scores
    ADD COLUMN IF NOT EXISTS brand_id TEXT NOT NULL DEFAULT 'togetherremind';

    CREATE INDEX IF NOT EXISTS idx_word_search_scores_brand ON word_search_scores(brand_id);
  END IF;
END $$;

-- ============================================================================
-- HELPER FUNCTION: Get brand for current request
-- ============================================================================

-- Function to get brand_id from request headers (for RLS policies)
-- Can be set via: SET LOCAL app.brand_id = 'holycouples';
CREATE OR REPLACE FUNCTION get_current_brand_id()
RETURNS TEXT AS $$
BEGIN
  RETURN COALESCE(
    current_setting('app.brand_id', true),
    'togetherremind'
  );
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- VALIDATION
-- ============================================================================

-- Verify brand_id columns exist on key tables
DO $$
DECLARE
  tables_without_brand TEXT[];
  required_tables TEXT[] := ARRAY[
    'couples',
    'couple_invites',
    'daily_quests',
    'quiz_sessions',
    'love_point_awards'
  ];
  t TEXT;
BEGIN
  FOREACH t IN ARRAY required_tables LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_name = t AND column_name = 'brand_id'
    ) THEN
      tables_without_brand := array_append(tables_without_brand, t);
    END IF;
  END LOOP;

  IF array_length(tables_without_brand, 1) > 0 THEN
    RAISE WARNING 'Tables missing brand_id: %', tables_without_brand;
  ELSE
    RAISE NOTICE 'All required tables have brand_id column';
  END IF;
END $$;

-- ============================================================================
-- USAGE NOTES
-- ============================================================================
--
-- To filter by brand in API queries:
--   SELECT * FROM couples WHERE brand_id = 'holycouples';
--
-- To set brand for RLS (if policies are updated):
--   SET LOCAL app.brand_id = 'holycouples';
--
-- To create test data for a brand:
--   INSERT INTO couples (user1_id, user2_id, brand_id)
--   VALUES ('uuid1', 'uuid2', 'holycouples');
--
-- Migration is safe to re-run (IF NOT EXISTS on all operations)
-- ============================================================================

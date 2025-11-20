-- TogetherRemind Migration: Fix Quest ID Types
-- Migration: 006 - Change daily_quests.id from UUID to TEXT
--
-- REASON: Flutter generates quest IDs as strings (e.g., "quest_1763618460006_quiz")
-- but the schema expects UUID format. This breaks dual-write sync.

-- ============================================================================
-- DROP RLS POLICIES FIRST (they depend on columns being altered)
-- ============================================================================

DROP POLICY IF EXISTS quest_access ON daily_quests;
DROP POLICY IF EXISTS completion_access ON quest_completions;

-- ============================================================================
-- DROP FOREIGN KEY CONSTRAINT
-- ============================================================================

-- quest_completions references daily_quests(id)
ALTER TABLE quest_completions DROP CONSTRAINT IF EXISTS quest_completions_quest_id_fkey;

-- ============================================================================
-- ALTER DAILY_QUESTS TABLE
-- ============================================================================

-- Change id column from UUID to TEXT
ALTER TABLE daily_quests ALTER COLUMN id TYPE TEXT USING id::TEXT;

-- Remove default since client generates IDs
ALTER TABLE daily_quests ALTER COLUMN id DROP DEFAULT;

-- Change content_id from UUID to TEXT (also uses client-generated IDs)
ALTER TABLE daily_quests ALTER COLUMN content_id TYPE TEXT USING content_id::TEXT;

-- ============================================================================
-- ALTER QUEST_COMPLETIONS TABLE
-- ============================================================================

-- Change quest_id column from UUID to TEXT to match daily_quests.id
ALTER TABLE quest_completions ALTER COLUMN quest_id TYPE TEXT USING quest_id::TEXT;

-- Re-add foreign key constraint
ALTER TABLE quest_completions
  ADD CONSTRAINT quest_completions_quest_id_fkey
  FOREIGN KEY (quest_id) REFERENCES daily_quests(id) ON DELETE CASCADE;

-- ============================================================================
-- RECREATE RLS POLICIES
-- ============================================================================

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

-- ============================================================================
-- DONE
-- ============================================================================

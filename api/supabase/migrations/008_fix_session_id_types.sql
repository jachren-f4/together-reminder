/**
 * Fix ID types for you_or_me_sessions and memory_puzzles
 *
 * Flutter generates text IDs like "youorme_1763622554709" and "puzzle_2024-01-15"
 * but the database expects UUIDs. Change to TEXT to match Flutter's format.
 */

-- Fix you_or_me_sessions and related foreign keys
-- Must drop RLS policy that depends on session_id column first
DROP POLICY IF EXISTS you_or_me_answer_access ON you_or_me_answers;
ALTER TABLE you_or_me_answers DROP CONSTRAINT IF EXISTS you_or_me_answers_session_id_fkey;
ALTER TABLE you_or_me_answers ALTER COLUMN session_id TYPE TEXT;
ALTER TABLE you_or_me_sessions ALTER COLUMN id TYPE TEXT;
ALTER TABLE you_or_me_answers
  ADD CONSTRAINT you_or_me_answers_session_id_fkey
  FOREIGN KEY (session_id) REFERENCES you_or_me_sessions(id) ON DELETE CASCADE;

-- Fix memory_puzzles ID type
ALTER TABLE memory_puzzles ALTER COLUMN id TYPE TEXT;

-- Recreate the RLS policy (was dropped to allow column type change)
CREATE POLICY you_or_me_answer_access ON you_or_me_answers
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM you_or_me_sessions s
      JOIN couples c ON s.couple_id = c.id
      WHERE s.id = you_or_me_answers.session_id
      AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
    )
  );

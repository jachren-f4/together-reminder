/**
 * Fix ID types for you_or_me_sessions and memory_puzzles
 *
 * Flutter generates text IDs like "youorme_1763622554709" and "puzzle_2024-01-15"
 * but the database expects UUIDs. Change to TEXT to match Flutter's format.
 */

-- Fix you_or_me_sessions and related foreign keys
ALTER TABLE you_or_me_answers DROP CONSTRAINT IF EXISTS you_or_me_answers_session_id_fkey;
ALTER TABLE you_or_me_answers ALTER COLUMN session_id TYPE TEXT;
ALTER TABLE you_or_me_sessions ALTER COLUMN id TYPE TEXT;
ALTER TABLE you_or_me_answers
  ADD CONSTRAINT you_or_me_answers_session_id_fkey
  FOREIGN KEY (session_id) REFERENCES you_or_me_sessions(id) ON DELETE CASCADE;

-- Fix memory_puzzles ID type
ALTER TABLE memory_puzzles ALTER COLUMN id TYPE TEXT;

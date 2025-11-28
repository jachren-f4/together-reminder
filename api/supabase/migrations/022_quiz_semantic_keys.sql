-- Migration: Change daily_quest_id to TEXT for semantic key support
-- The semantic key format is "quiz:{formatType}:{dateKey}" (e.g., "quiz:classic:2025-11-28")
-- This allows both partners to reference the same quiz session without UUID coordination

-- Change daily_quest_id from UUID to TEXT
ALTER TABLE quiz_sessions
ALTER COLUMN daily_quest_id TYPE TEXT;

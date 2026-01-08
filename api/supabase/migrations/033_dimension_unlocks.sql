-- Migration: Add dimension_unlocks tracking to couples table
-- Tracks when each dimension was first unlocked for a couple

ALTER TABLE couples ADD COLUMN IF NOT EXISTS dimension_unlocks JSONB DEFAULT '{}';

-- Example data structure:
-- {
--   "social_energy": "2026-01-01T12:00:00Z",
--   "daily_rhythm": "2026-01-07T15:30:00Z"
-- }

COMMENT ON COLUMN couples.dimension_unlocks IS 'Tracks when each dimension was first unlocked (first had data points). Key = dimension_id, value = ISO timestamp.';

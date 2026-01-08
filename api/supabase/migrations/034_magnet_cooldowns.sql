-- ============================================
-- MAGNET COLLECTION SYSTEM: Cooldown Tracking
-- ============================================
--
-- Magnets are calculated from couples.total_lp (no new table needed).
-- This migration only adds cooldown tracking.
--
-- Each activity type has SEPARATE cooldown (2 plays each, then 8hr wait):
-- - classic_quiz
-- - affirmation_quiz
-- - you_or_me
-- - linked
-- - wordsearch

ALTER TABLE couples ADD COLUMN IF NOT EXISTS cooldowns JSONB DEFAULT '{}';

-- Example cooldowns structure:
-- {
--   "classic_quiz": { "batch_count": 2, "cooldown_until": "2025-01-07T18:00:00Z" },
--   "affirmation_quiz": { "batch_count": 1, "cooldown_until": null },
--   "you_or_me": { "batch_count": 0, "cooldown_until": null },
--   "linked": { "batch_count": 2, "cooldown_until": "2025-01-07T18:00:00Z" },
--   "wordsearch": { "batch_count": 1, "cooldown_until": null }
-- }

COMMENT ON COLUMN couples.cooldowns IS 'Per-activity cooldown tracking: 2 plays per type, then 8hr wait. JSONB with batch_count and cooldown_until per activity.';

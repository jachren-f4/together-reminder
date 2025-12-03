-- Migration: 026 - Add anniversary_date to couples
-- Allows couples to track their relationship start date

ALTER TABLE couples ADD COLUMN IF NOT EXISTS anniversary_date DATE;

-- Add comment for documentation
COMMENT ON COLUMN couples.anniversary_date IS 'User-entered relationship start date for "Together For" display';

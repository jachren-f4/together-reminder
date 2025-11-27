-- Migration: Update branch_progression to support 3 branches by default
-- This changes the default max_branches from 2 to 3

-- Update the default value for new rows
ALTER TABLE branch_progression ALTER COLUMN max_branches SET DEFAULT 3;

-- Update existing rows that have max_branches = 2 to use 3
UPDATE branch_progression SET max_branches = 3 WHERE max_branches = 2;

-- Update comment to reflect new default
COMMENT ON COLUMN branch_progression.max_branches IS 'Maximum branches (default 3 for A/B/C branches)';

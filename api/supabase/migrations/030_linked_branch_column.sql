-- Migration: 030_linked_branch_column.sql
-- Description: Add branch column to linked_matches to store puzzle branch
-- Created: 2025-12-27

-- Add branch column to linked_matches (nullable for backwards compatibility)
ALTER TABLE linked_matches ADD COLUMN IF NOT EXISTS branch TEXT;

-- Add comment for documentation
COMMENT ON COLUMN linked_matches.branch IS 'Branch folder name (casual/romantic/adult) the puzzle was loaded from';

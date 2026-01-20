-- Migration: 036_word_search_branch.sql
-- Store the branch used when a word search match was created
-- This fixes a bug where the server would load the wrong puzzle if the branch changed

-- Add branch column to word_search_matches
-- Default to 'casual' which is the first branch in the word search rotation
ALTER TABLE word_search_matches
ADD COLUMN IF NOT EXISTS branch TEXT NOT NULL DEFAULT 'casual';

-- Also add to linked_matches for consistency (same issue exists there)
ALTER TABLE linked_matches
ADD COLUMN IF NOT EXISTS branch TEXT NOT NULL DEFAULT 'casual';

-- Migration: Add first_player_id to couples table
-- Purpose: Store global preference for which partner goes first in new turn-based content
-- Default behavior: NULL defaults to user2_id (latest joiner) at runtime

-- Add first_player_id column to couples table
ALTER TABLE couples
ADD COLUMN first_player_id UUID REFERENCES auth.users(id);

-- Add comment for documentation
COMMENT ON COLUMN couples.first_player_id IS 'User who goes first in new turn-based games. NULL defaults to user2_id.';

-- Create index for efficient lookups
CREATE INDEX idx_couples_first_player ON couples(first_player_id);

-- Add constraint to ensure first_player_id is one of the couple members
ALTER TABLE couples
ADD CONSTRAINT valid_first_player CHECK (
  first_player_id IS NULL OR
  first_player_id = user1_id OR
  first_player_id = user2_id
);

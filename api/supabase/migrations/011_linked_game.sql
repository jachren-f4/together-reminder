-- Migration: 011_linked_game.sql
-- Description: Create tables for Linked (arroword puzzle) game
-- Created: 2025-11-25

-- Create linked_matches table
CREATE TABLE IF NOT EXISTS linked_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,
  puzzle_id TEXT NOT NULL,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed')),
  board_state JSONB DEFAULT '{}',
  current_rack TEXT[] DEFAULT '{}',
  current_turn_user_id UUID,
  turn_number INT DEFAULT 1,
  player1_score INT DEFAULT 0,
  player2_score INT DEFAULT 0,
  player1_vision INT DEFAULT 2,
  player2_vision INT DEFAULT 2,
  locked_cell_count INT DEFAULT 0,
  total_answer_cells INT NOT NULL,
  player1_id UUID,
  player2_id UUID,
  winner_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  UNIQUE(couple_id, puzzle_id)
);

-- Create linked_moves table for move history
CREATE TABLE IF NOT EXISTS linked_moves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID REFERENCES linked_matches(id) ON DELETE CASCADE NOT NULL,
  player_id UUID NOT NULL,
  placements JSONB NOT NULL,
  points_earned INT NOT NULL DEFAULT 0,
  words_completed JSONB DEFAULT '[]',
  turn_number INT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_linked_matches_couple ON linked_matches(couple_id);
CREATE INDEX IF NOT EXISTS idx_linked_matches_status ON linked_matches(status);
CREATE INDEX IF NOT EXISTS idx_linked_moves_match ON linked_moves(match_id);
CREATE INDEX IF NOT EXISTS idx_linked_moves_player ON linked_moves(player_id);

-- Add comments for documentation
COMMENT ON TABLE linked_matches IS 'Stores active and completed Linked (arroword) game matches between couples';
COMMENT ON TABLE linked_moves IS 'Audit trail of all moves made in Linked games';
COMMENT ON COLUMN linked_matches.board_state IS 'JSON object mapping cell index to locked letter';
COMMENT ON COLUMN linked_matches.current_rack IS 'Array of letters available to the current player';
COMMENT ON COLUMN linked_matches.player1_vision IS 'Number of hint power-ups remaining for player 1';
COMMENT ON COLUMN linked_matches.player2_vision IS 'Number of hint power-ups remaining for player 2';

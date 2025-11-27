-- Migration: 012_word_search_game.sql
-- Word Search turn-based puzzle game

-- Main matches table
CREATE TABLE word_search_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  puzzle_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed')),

  -- Game state
  found_words JSONB NOT NULL DEFAULT '[]',
  current_turn_user_id UUID,
  turn_number INT NOT NULL DEFAULT 1,
  words_found_this_turn INT NOT NULL DEFAULT 0,

  -- Scores (words found count)
  player1_words_found INT NOT NULL DEFAULT 0,
  player2_words_found INT NOT NULL DEFAULT 0,

  -- Hints
  player1_hints INT NOT NULL DEFAULT 3,
  player2_hints INT NOT NULL DEFAULT 3,

  -- Players (denormalized for query efficiency)
  player1_id UUID NOT NULL,
  player2_id UUID NOT NULL,

  -- Completion
  winner_id UUID,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,

  -- Constraints
  UNIQUE(couple_id, puzzle_id)
);

-- Move audit trail
CREATE TABLE word_search_moves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES word_search_matches(id) ON DELETE CASCADE,
  player_id UUID NOT NULL,
  word TEXT NOT NULL,
  positions JSONB NOT NULL,
  turn_number INT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_word_search_matches_couple ON word_search_matches(couple_id);
CREATE INDEX idx_word_search_matches_status ON word_search_matches(status);
CREATE INDEX idx_word_search_moves_match ON word_search_moves(match_id);

-- RLS Policies
ALTER TABLE word_search_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE word_search_moves ENABLE ROW LEVEL SECURITY;

-- Users can read matches they're part of
CREATE POLICY "Users can read own matches"
  ON word_search_matches FOR SELECT
  USING (
    auth.uid() = player1_id OR
    auth.uid() = player2_id
  );

-- Users can insert matches for their couple
CREATE POLICY "Users can create matches"
  ON word_search_matches FOR INSERT
  WITH CHECK (
    auth.uid() = player1_id OR
    auth.uid() = player2_id
  );

-- Users can update matches they're part of
CREATE POLICY "Users can update own matches"
  ON word_search_matches FOR UPDATE
  USING (
    auth.uid() = player1_id OR
    auth.uid() = player2_id
  );

-- Move policies
CREATE POLICY "Users can read moves for own matches"
  ON word_search_moves FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM word_search_matches m
      WHERE m.id = match_id
      AND (m.player1_id = auth.uid() OR m.player2_id = auth.uid())
    )
  );

CREATE POLICY "Users can insert moves for own matches"
  ON word_search_moves FOR INSERT
  WITH CHECK (
    auth.uid() = player_id AND
    EXISTS (
      SELECT 1 FROM word_search_matches m
      WHERE m.id = match_id
      AND (m.player1_id = auth.uid() OR m.player2_id = auth.uid())
    )
  );

-- Updated_at trigger function (create if not exists)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Updated_at trigger
CREATE TRIGGER update_word_search_matches_updated_at
  BEFORE UPDATE ON word_search_matches
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

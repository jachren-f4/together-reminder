-- Migration 009: Memory Flip Turn-Based System
-- Date: 2025-11-21
-- Purpose: Convert Memory Flip from real-time to turn-based gameplay

-- ========================================
-- 1. Add turn-based columns to memory_puzzles
-- ========================================

-- Add turn state columns
ALTER TABLE memory_puzzles ADD COLUMN IF NOT EXISTS
  current_player_id UUID REFERENCES auth.users(id);

ALTER TABLE memory_puzzles ADD COLUMN IF NOT EXISTS
  turn_number INT DEFAULT 0;

ALTER TABLE memory_puzzles ADD COLUMN IF NOT EXISTS
  turn_started_at TIMESTAMPTZ;

ALTER TABLE memory_puzzles ADD COLUMN IF NOT EXISTS
  turn_expires_at TIMESTAMPTZ;

-- Add scoring columns
ALTER TABLE memory_puzzles ADD COLUMN IF NOT EXISTS
  player1_pairs INT DEFAULT 0;

ALTER TABLE memory_puzzles ADD COLUMN IF NOT EXISTS
  player2_pairs INT DEFAULT 0;

-- Add game phase
ALTER TABLE memory_puzzles ADD COLUMN IF NOT EXISTS
  game_phase TEXT DEFAULT 'waiting';

-- Add flip allowances (stored per puzzle for consistency)
ALTER TABLE memory_puzzles ADD COLUMN IF NOT EXISTS
  player1_flips_remaining INT DEFAULT 6;

ALTER TABLE memory_puzzles ADD COLUMN IF NOT EXISTS
  player1_flips_reset_at TIMESTAMPTZ;

ALTER TABLE memory_puzzles ADD COLUMN IF NOT EXISTS
  player2_flips_remaining INT DEFAULT 6;

ALTER TABLE memory_puzzles ADD COLUMN IF NOT EXISTS
  player2_flips_reset_at TIMESTAMPTZ;

-- ========================================
-- 2. Create indexes for performance
-- ========================================

-- Index for finding puzzles by current player
CREATE INDEX IF NOT EXISTS idx_memory_puzzles_current_player
  ON memory_puzzles(couple_id, current_player_id);

-- Index for finding expired turns
CREATE INDEX IF NOT EXISTS idx_memory_puzzles_turn_expires
  ON memory_puzzles(turn_expires_at)
  WHERE game_phase = 'active';

-- ========================================
-- 3. Create memory_moves audit table
-- ========================================

CREATE TABLE IF NOT EXISTS memory_moves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  puzzle_id TEXT REFERENCES memory_puzzles(id) ON DELETE CASCADE,
  player_id UUID REFERENCES auth.users(id),

  -- Move details
  card1_id VARCHAR NOT NULL,
  card2_id VARCHAR NOT NULL,
  card1_position INT NOT NULL,
  card2_position INT NOT NULL,
  match_found BOOLEAN NOT NULL,
  pair_id VARCHAR,  -- If match found

  -- Metadata
  turn_number INT NOT NULL,
  flips_remaining_after INT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Prevent duplicate moves
  UNIQUE(puzzle_id, turn_number)
);

-- Index for efficient move queries
CREATE INDEX IF NOT EXISTS idx_memory_moves_puzzle
  ON memory_moves(puzzle_id, created_at DESC);

-- ========================================
-- 4. Enable Row Level Security (RLS)
-- ========================================

ALTER TABLE memory_puzzles ENABLE ROW LEVEL SECURITY;
ALTER TABLE memory_moves ENABLE ROW LEVEL SECURITY;

-- ========================================
-- 5. Create RLS Policies for memory_puzzles
-- ========================================

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS memory_puzzle_view ON memory_puzzles;
DROP POLICY IF EXISTS memory_puzzle_turn_update ON memory_puzzles;
DROP POLICY IF EXISTS memory_puzzle_create ON memory_puzzles;

-- View policy: Both players can see puzzle
CREATE POLICY memory_puzzle_view ON memory_puzzles
  FOR SELECT
  USING (
    couple_id IN (
      SELECT id FROM couples
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

-- Update policy: Only current player during their turn
CREATE POLICY memory_puzzle_turn_update ON memory_puzzles
  FOR UPDATE
  USING (
    current_player_id = auth.uid()
    AND game_phase = 'active'
    AND (turn_expires_at IS NULL OR turn_expires_at > NOW())
  )
  WITH CHECK (
    current_player_id = auth.uid()
    AND game_phase = 'active'
    AND (turn_expires_at IS NULL OR turn_expires_at > NOW())
  );

-- Insert policy: Either player can create
CREATE POLICY memory_puzzle_create ON memory_puzzles
  FOR INSERT
  WITH CHECK (
    couple_id IN (
      SELECT id FROM couples
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

-- Delete policy: No one can delete puzzles (historical data)
-- No DELETE policy means deletion is blocked

-- ========================================
-- 6. Create RLS Policies for memory_moves
-- ========================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS memory_moves_insert ON memory_moves;
DROP POLICY IF EXISTS memory_moves_view ON memory_moves;

-- Insert policy: Only current player can insert moves
CREATE POLICY memory_moves_insert ON memory_moves
  FOR INSERT
  WITH CHECK (
    player_id = auth.uid()
    AND puzzle_id IN (
      SELECT id FROM memory_puzzles
      WHERE current_player_id = auth.uid()
        AND game_phase = 'active'
        AND (turn_expires_at IS NULL OR turn_expires_at > NOW())
    )
  );

-- View policy: Both players can view moves
CREATE POLICY memory_moves_view ON memory_moves
  FOR SELECT
  USING (
    puzzle_id IN (
      SELECT mp.id FROM memory_puzzles mp
      JOIN couples c ON mp.couple_id = c.id
      WHERE c.user1_id = auth.uid() OR c.user2_id = auth.uid()
    )
  );

-- Update policy: No one can update moves (audit trail is immutable)
-- No UPDATE policy means updates are blocked

-- Delete policy: No one can delete moves (audit trail is immutable)
-- No DELETE policy means deletion is blocked

-- ========================================
-- 7. Create helper function for turn advancement
-- ========================================

CREATE OR REPLACE FUNCTION advance_memory_flip_turn(p_puzzle_id TEXT)
RETURNS void AS $$
DECLARE
  v_couple_id UUID;
  v_current_player_id UUID;
  v_user1_id UUID;
  v_user2_id UUID;
  v_next_player_id UUID;
BEGIN
  -- Get puzzle and couple information
  SELECT mp.couple_id, mp.current_player_id, c.user1_id, c.user2_id
  INTO v_couple_id, v_current_player_id, v_user1_id, v_user2_id
  FROM memory_puzzles mp
  JOIN couples c ON mp.couple_id = c.id
  WHERE mp.id = p_puzzle_id;

  -- Determine next player
  IF v_current_player_id = v_user1_id THEN
    v_next_player_id := v_user2_id;
  ELSE
    v_next_player_id := v_user1_id;
  END IF;

  -- Update puzzle with new turn
  UPDATE memory_puzzles
  SET
    current_player_id = v_next_player_id,
    turn_number = turn_number + 1,
    turn_started_at = NOW(),
    turn_expires_at = NOW() + INTERVAL '5 hours'
  WHERE id = p_puzzle_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- 8. Create function to check and recharge flips
-- ========================================

CREATE OR REPLACE FUNCTION check_and_recharge_flips(
  p_puzzle_id TEXT,
  p_player_id UUID
)
RETURNS INT AS $$
DECLARE
  v_flips_remaining INT;
  v_flips_reset_at TIMESTAMPTZ;
  v_is_player1 BOOLEAN;
BEGIN
  -- Determine if player is player1 or player2
  SELECT
    CASE
      WHEN c.user1_id = p_player_id THEN true
      ELSE false
    END INTO v_is_player1
  FROM memory_puzzles mp
  JOIN couples c ON mp.couple_id = c.id
  WHERE mp.id = p_puzzle_id;

  -- Get current flips and reset time
  IF v_is_player1 THEN
    SELECT player1_flips_remaining, player1_flips_reset_at
    INTO v_flips_remaining, v_flips_reset_at
    FROM memory_puzzles
    WHERE id = p_puzzle_id;
  ELSE
    SELECT player2_flips_remaining, player2_flips_reset_at
    INTO v_flips_remaining, v_flips_reset_at
    FROM memory_puzzles
    WHERE id = p_puzzle_id;
  END IF;

  -- Check if recharge is needed
  IF v_flips_remaining = 0 AND v_flips_reset_at IS NOT NULL AND v_flips_reset_at <= NOW() THEN
    -- Recharge flips
    v_flips_remaining := 6;

    -- Update puzzle
    IF v_is_player1 THEN
      UPDATE memory_puzzles
      SET
        player1_flips_remaining = 6,
        player1_flips_reset_at = NULL
      WHERE id = p_puzzle_id;
    ELSE
      UPDATE memory_puzzles
      SET
        player2_flips_remaining = 6,
        player2_flips_reset_at = NULL
      WHERE id = p_puzzle_id;
    END IF;
  END IF;

  RETURN v_flips_remaining;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- 9. Grant necessary permissions
-- ========================================

-- Grant usage on functions to authenticated users
GRANT EXECUTE ON FUNCTION advance_memory_flip_turn(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION check_and_recharge_flips(TEXT, UUID) TO authenticated;

-- ========================================
-- 10. Add comments for documentation
-- ========================================

COMMENT ON TABLE memory_puzzles IS 'Turn-based Memory Flip puzzles with individual flip allowances';
COMMENT ON TABLE memory_moves IS 'Audit trail of all Memory Flip moves';
COMMENT ON COLUMN memory_puzzles.current_player_id IS 'Player whose turn it is';
COMMENT ON COLUMN memory_puzzles.turn_expires_at IS 'When current turn expires (5 hours)';
COMMENT ON COLUMN memory_puzzles.player1_flips_remaining IS 'Number of flips remaining for player 1 (recharges every 5 hours)';
COMMENT ON COLUMN memory_puzzles.player2_flips_remaining IS 'Number of flips remaining for player 2 (recharges every 5 hours)';
COMMENT ON COLUMN memory_puzzles.game_phase IS 'Game state: waiting, active, or completed';
COMMENT ON COLUMN memory_moves.match_found IS 'Whether this move resulted in a match';
COMMENT ON COLUMN memory_moves.pair_id IS 'ID of the matched pair if match was found';

-- ========================================
-- End of Migration 009
-- ========================================
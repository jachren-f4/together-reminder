-- Reset Memory Flip game data for test users
-- This deletes all Memory Flip puzzles and moves for the test couple

-- First, find the couple ID for the test users
-- User 1: c7f42ec5-7c6d-4dc4-90f2-2aae6ede4d28 (Testix)
-- User 2: d71425a3-a92f-404e-bfbe-a54c4cb58b6a (Joakim)

-- Delete all memory moves for this couple's puzzles
DELETE FROM memory_moves
WHERE puzzle_id IN (
    SELECT id FROM memory_puzzles
    WHERE couple_id = '09c1566c-3fa9-4562-acc8-79bd203010c2'
);

-- Delete all memory puzzles for this couple
DELETE FROM memory_puzzles
WHERE couple_id = '09c1566c-3fa9-4562-acc8-79bd203010c2';

-- Verify deletion
SELECT 'Deleted Memory Flip data for test couple' as result;
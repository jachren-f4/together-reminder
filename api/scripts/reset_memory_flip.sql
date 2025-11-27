-- Reset Memory Flip game data for test users (Jokke & TestiY)
-- This deletes all Memory Flip puzzles and moves for the test couple
--
-- Test users:
-- User 1 (Android): e2ecabb7-43ee-422c-b49c-f0636d57e6d2 (TestiY)
-- User 2 (Chrome):  634e2af3-1625-4532-89c0-2d0900a2690a (Jokke)
-- Couple ID: 11111111-1111-1111-1111-111111111111
--
-- Usage: cd api && psql $DATABASE_URL -f scripts/reset_memory_flip.sql

-- Delete all memory moves for this couple's puzzles
DELETE FROM memory_moves
WHERE puzzle_id IN (
    SELECT id FROM memory_puzzles
    WHERE couple_id = '11111111-1111-1111-1111-111111111111'
);

-- Delete all memory puzzles for this couple
DELETE FROM memory_puzzles
WHERE couple_id = '11111111-1111-1111-1111-111111111111';

-- Verify deletion
SELECT 'Deleted Memory Flip data for Jokke & TestiY couple' as result;
-- Migration: 013_word_search_scores.sql
-- Add point-based scoring to Word Search (10 points per letter)

-- Add score columns
ALTER TABLE word_search_matches
ADD COLUMN player1_score INT NOT NULL DEFAULT 0,
ADD COLUMN player2_score INT NOT NULL DEFAULT 0;

-- Backfill existing matches: calculate scores from found_words
-- Each word's score = word length * 10
UPDATE word_search_matches
SET
  player1_score = COALESCE((
    SELECT SUM(LENGTH(fw->>'word') * 10)
    FROM jsonb_array_elements(found_words) AS fw
    WHERE fw->>'foundBy' = player1_id::text
  ), 0),
  player2_score = COALESCE((
    SELECT SUM(LENGTH(fw->>'word') * 10)
    FROM jsonb_array_elements(found_words) AS fw
    WHERE fw->>'foundBy' = player2_id::text
  ), 0);

-- Migration: 028 - Composite Indexes for Common Query Patterns
-- Purpose: Add composite indexes for multi-column queries that are frequently used
--
-- See: docs/plans/DATABASE_SCALABILITY_PLAN.md (Phase 2)

-- ============================================================================
-- BRANCH PROGRESSION
-- ============================================================================

-- Query pattern: WHERE couple_id = $1 AND activity_type = $2
-- Used in: lib/game/handler.ts, lib/puzzle/loader.ts
CREATE UNIQUE INDEX IF NOT EXISTS idx_branch_progression_couple_activity
ON branch_progression(couple_id, activity_type);

-- ============================================================================
-- QUIZ MATCHES
-- ============================================================================

-- Query pattern: WHERE couple_id = $1 AND quiz_type = $2 AND date = $3
-- Used in: lib/game/handler.ts for finding active matches
CREATE INDEX IF NOT EXISTS idx_quiz_matches_couple_type_date
ON quiz_matches(couple_id, quiz_type, date);

-- Query pattern: WHERE couple_id = $1 AND status = 'active'
-- Used in: finding active matches for a couple
CREATE INDEX IF NOT EXISTS idx_quiz_matches_couple_status
ON quiz_matches(couple_id, status);

-- ============================================================================
-- LINKED MATCHES
-- ============================================================================

-- Query pattern: WHERE couple_id = $1 AND status = $2
-- Used in: lib/puzzle/loader.ts for finding active/completed matches
CREATE INDEX IF NOT EXISTS idx_linked_matches_couple_status
ON linked_matches(couple_id, status);

-- ============================================================================
-- WORD SEARCH MATCHES
-- ============================================================================

-- Query pattern: WHERE couple_id = $1 AND status = $2
-- Used in: lib/puzzle/loader.ts for finding active/completed matches
CREATE INDEX IF NOT EXISTS idx_word_search_matches_couple_status
ON word_search_matches(couple_id, status);

-- ============================================================================
-- YOU OR ME SESSIONS
-- ============================================================================

-- Query pattern: WHERE couple_id = $1 AND date = $2
-- Used in: finding sessions for a specific day
CREATE INDEX IF NOT EXISTS idx_you_or_me_sessions_couple_date_composite
ON you_or_me_sessions(couple_id, date);

-- Query pattern: WHERE couple_id = $1 AND status = $2
-- Used in: finding active sessions
CREATE INDEX IF NOT EXISTS idx_you_or_me_sessions_couple_status
ON you_or_me_sessions(couple_id, status);

-- ============================================================================
-- DAILY QUESTS
-- ============================================================================

-- Query pattern: WHERE couple_id = $1 AND date = $2 AND is_side_quest = $3
-- Used in: fetching daily or side quests for a specific day
CREATE INDEX IF NOT EXISTS idx_daily_quests_couple_date_side
ON daily_quests(couple_id, date, is_side_quest);

-- ============================================================================
-- LOVE POINT TRANSACTIONS
-- ============================================================================

-- Query pattern: WHERE user_id = $1 ORDER BY created_at DESC
-- Already has separate indexes, but composite is more efficient
CREATE INDEX IF NOT EXISTS idx_lp_transactions_user_created
ON love_point_transactions(user_id, created_at DESC);

-- ============================================================================
-- VERIFICATION QUERIES (run manually after migration)
-- ============================================================================

-- Check index usage:
-- SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
-- FROM pg_stat_user_indexes
-- WHERE schemaname = 'public'
-- ORDER BY idx_scan DESC;

-- Check index sizes:
-- SELECT
--   tablename,
--   indexname,
--   pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
-- FROM pg_stat_user_indexes
-- WHERE schemaname = 'public'
-- ORDER BY pg_relation_size(indexrelid) DESC;

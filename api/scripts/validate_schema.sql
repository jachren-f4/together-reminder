-- Schema Validation Script
-- Validates that all tables, indexes, and constraints are properly created

\echo '🔍 Validating Database Schema...\n'

-- ============================================================================
-- VALIDATE TABLES EXIST
-- ============================================================================

\echo '📋 Checking Core Tables...'

SELECT 
  CASE 
    WHEN COUNT(*) = 12 THEN '✅ All 12 core tables exist'
    ELSE '❌ Missing tables: ' || (12 - COUNT(*))::text
  END as table_check
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN (
  'couples',
  'couple_invites',
  'daily_quests',
  'quest_completions',
  'quiz_sessions',
  'quiz_answers',
  'quiz_progression',
  'you_or_me_sessions',
  'you_or_me_answers',
  'you_or_me_progression',
  'memory_puzzles',
  'love_point_awards',
  'user_love_points'
);

-- ============================================================================
-- VALIDATE CRITICAL CONSTRAINTS
-- ============================================================================

\echo '\n🔒 Checking Critical Constraints...'

-- Duplicate LP prevention constraint
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_constraint
      WHERE conname = 'unique_related_award'
      AND conrelid = 'love_point_awards'::regclass
    ) THEN '✅ LP duplicate prevention constraint exists'
    ELSE '❌ Missing: unique_related_award on love_point_awards'
  END as lp_constraint;

-- Duplicate puzzle prevention constraint
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_constraint
      WHERE conrelid = 'memory_puzzles'::regclass
      AND contype = 'u'
      AND conkey = (
        SELECT ARRAY[attnum] FROM pg_attribute 
        WHERE attrelid = 'memory_puzzles'::regclass 
        AND attname IN ('couple_id', 'date')
      )
    ) THEN '✅ Memory puzzle duplicate prevention exists'
    ELSE '❌ Missing: UNIQUE(couple_id, date) on memory_puzzles'
  END as puzzle_constraint;

-- Unique couple constraint
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_constraint
      WHERE conname = 'unique_couple'
      AND conrelid = 'couples'::regclass
    ) THEN '✅ Couple uniqueness constraint exists'
    ELSE '❌ Missing: unique_couple constraint'
  END as couple_constraint;

-- ============================================================================
-- VALIDATE INDEXES
-- ============================================================================

\echo '\n📑 Checking Performance Indexes...'

SELECT 
  COUNT(*) || ' indexes created' as index_count
FROM pg_indexes
WHERE schemaname = 'public'
AND indexname LIKE 'idx_%';

-- Check critical indexes
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_indexes 
      WHERE indexname = 'idx_daily_quests_couple_date'
    ) THEN '✅ Daily quests index exists'
    ELSE '❌ Missing: idx_daily_quests_couple_date'
  END as quest_index;

SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_indexes 
      WHERE indexname = 'idx_lp_awards_couple'
    ) THEN '✅ LP awards index exists'
    ELSE '❌ Missing: idx_lp_awards_couple'
  END as lp_index;

-- ============================================================================
-- VALIDATE ROW LEVEL SECURITY
-- ============================================================================

\echo '\n🛡️ Checking Row Level Security...'

SELECT 
  table_name,
  CASE 
    WHEN row_security = 'YES' THEN '✅ Enabled'
    ELSE '❌ Disabled'
  END as rls_status
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_type = 'BASE TABLE'
AND table_name IN (
  'couples',
  'daily_quests',
  'quest_completions',
  'quiz_sessions',
  'quiz_answers',
  'love_point_awards',
  'user_love_points'
)
ORDER BY table_name;

-- Count RLS policies
SELECT 
  COUNT(*) || ' RLS policies created' as policy_count
FROM pg_policies
WHERE schemaname = 'public';

-- ============================================================================
-- VALIDATE FOREIGN KEY RELATIONSHIPS
-- ============================================================================

\echo '\n🔗 Checking Foreign Key Relationships...'

SELECT 
  COUNT(*) || ' foreign key constraints' as fk_count
FROM information_schema.table_constraints
WHERE constraint_schema = 'public'
AND constraint_type = 'FOREIGN KEY';

-- ============================================================================
-- CHECK DATABASE STATS
-- ============================================================================

\echo '\n📊 Database Statistics...'

SELECT 
  schemaname,
  COUNT(*) as table_count,
  SUM(pg_total_relation_size(quote_ident(schemaname) || '.' || quote_ident(tablename))) as total_size_bytes
FROM pg_tables
WHERE schemaname = 'public'
GROUP BY schemaname;

-- ============================================================================
-- CONNECTION POOL CAPACITY
-- ============================================================================

\echo '\n🔌 Connection Pool Capacity...'

SELECT 
  setting as max_connections,
  CASE 
    WHEN setting::int >= 60 THEN '✅ Sufficient for 60 concurrent'
    ELSE '⚠️  May need adjustment'
  END as capacity_status
FROM pg_settings
WHERE name = 'max_connections';

-- ============================================================================
-- FINAL SUMMARY
-- ============================================================================

\echo '\n' || '=' * 60
\echo '✅ Schema Validation Complete\n'
\echo 'Review the results above for any ❌ errors'
\echo '=' * 60

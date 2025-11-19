# Database Schema Documentation

**Issue #4: INFRA-102**

Complete PostgreSQL schema for TogetherRemind migration with performance optimizations and bug fixes.

---

## 📋 Schema Overview

### Core Tables (13 total)

| Table | Purpose | Key Constraints |
|-------|---------|-----------------|
| `couples` | User relationships | UNIQUE(user1_id, user2_id) |
| `couple_invites` | Pairing invite codes | UNIQUE(code), 6-digit format |
| `daily_quests` | Quest records | UNIQUE(couple_id, date, type, order) |
| `quest_completions` | Completion tracking | PK(quest_id, user_id) |
| `quiz_sessions` | Quiz data | RLS by couple |
| `quiz_answers` | Answer responses | UNIQUE(session, user, question) |
| `quiz_progression` | Track progress | PK(couple_id) |
| `you_or_me_sessions` | Game sessions | RLS by couple |
| `you_or_me_answers` | Game responses | UNIQUE(session, user, question) |
| `you_or_me_progression` | Used questions | PK(couple_id) |
| `memory_puzzles` | Puzzle state | **UNIQUE(couple_id, date)** |
| `love_point_awards` | LP transactions | **UNIQUE(couple_id, related_id)** |
| `user_love_points` | LP totals | PK(user_id) |

### Monitoring Tables (3 total)

| Table | Purpose |
|-------|---------|
| `connection_pool_metrics` | Track connection usage |
| `api_performance_metrics` | Track API latency |
| `sync_metrics` | Track sync operations |

---

## 🐛 Bug Fixes in Schema

### 1. Duplicate LP Awards (60 LP Bug)

**Problem:** `YouOrMeService` and `DailyQuestService` both awarding LP for same quest

**Solution:**
```sql
CREATE UNIQUE INDEX ON love_point_awards(couple_id, related_id);
```

**How it works:** `related_id` references the quest/session that triggered the award. Database rejects duplicate awards for same `related_id`.

### 2. Memory Flip Sync Issues

**Problem:** Duplicate puzzles created on sync conflicts

**Solution:**
```sql
CREATE UNIQUE INDEX ON memory_puzzles(couple_id, date);
```

**How it works:** Only one puzzle per couple per day allowed. Sync conflicts resolved by database atomically.

### 3. Race Conditions

**Problem:** Multiple simultaneous requests creating duplicate records

**Solution:** All critical tables have UNIQUE constraints + database-level atomicity

---

## 🚀 Performance Optimizations

### Critical Indexes

```sql
-- Fast couple lookups (for every request)
CREATE INDEX idx_couples_user1 ON couples(user1_id);
CREATE INDEX idx_couples_user2 ON couples(user2_id);

-- Fast quest queries (daily sync)
CREATE INDEX idx_daily_quests_couple_date ON daily_quests(couple_id, date);
CREATE INDEX idx_daily_quests_expires ON daily_quests(expires_at);

-- Fast LP queries (leaderboard, totals)
CREATE INDEX idx_lp_awards_couple ON love_point_awards(couple_id);
CREATE INDEX idx_lp_awards_created ON love_point_awards(created_at DESC);

-- Fast quiz lookups
CREATE INDEX idx_quiz_sessions_couple ON quiz_sessions(couple_id);
CREATE INDEX idx_quiz_sessions_status ON quiz_sessions(status);
```

### Query Performance Targets

| Query Type | Target | Index Used |
|------------|--------|------------|
| Get couple by user | <5ms | idx_couples_user1/2 |
| Get daily quests | <10ms | idx_daily_quests_couple_date |
| Get LP total | <5ms | user_love_points PK |
| Get quiz sessions | <10ms | idx_quiz_sessions_couple |

---

## 🛡️ Row Level Security (RLS)

### Security Model

All tables have RLS enabled. Users can only access data for their couple.

### Key Policies

```sql
-- Couples: Users see only couples they're in
CREATE POLICY couple_access ON couples
  FOR ALL USING (
    user1_id = auth.uid() OR user2_id = auth.uid()
  );

-- Daily quests: Users see only their couple's quests
CREATE POLICY quest_access ON daily_quests
  FOR ALL USING (
    couple_id IN (
      SELECT id FROM couples
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

-- Similar policies for all other tables
```

### Helper Functions

```sql
-- Check if user is in couple
SELECT is_couple_member('couple-uuid');

-- Get user's couple ID
SELECT get_user_couple_id();
```

---

## 📊 Connection Pooling

### Configuration

- **Strategy:** Single connection per Vercel worker
- **Max Total:** 60 connections (Supabase limit)
- **Per Worker:** 1 connection
- **Reuse:** Connection persists across requests

### Monitoring

```sql
-- Check active connections
SELECT count(*) FROM pg_stat_activity 
WHERE datname = 'postgres';

-- View connection pool metrics
SELECT * FROM connection_pool_metrics 
ORDER BY timestamp DESC 
LIMIT 10;
```

### Alert Thresholds

| Level | Connections | Action |
|-------|-------------|--------|
| ✅ Normal | <50 | No action |
| ⚠️ Warning | 50-55 | Monitor closely |
| 🚨 Critical | >55 | Investigate leaks |

---

## 🚀 Deployment

### Initial Setup

```bash
# 1. Link to Supabase project
cd api
supabase link --project-ref your-project-ref

# 2. Apply all migrations
supabase db push

# 3. Validate schema
supabase db query < scripts/validate_schema.sql

# 4. Test connection limits
npm run test:connections
```

### Migration Order

Migrations run in sequence:

1. `001_initial_schema.sql` - Core tables, indexes, base RLS
2. `002_couple_invites.sql` - Invite code system
3. `003_monitoring_tables.sql` - Performance tracking
4. `004_enhanced_rls_policies.sql` - Complete RLS coverage

### Rollback Plan

```bash
# Reset entire database (development only!)
supabase db reset

# Or revert specific migration
supabase migration down <migration-name>
```

---

## 🧪 Testing

### Connection Limit Test

```bash
# Run load test (tests 10, 25, 50, 60 concurrent connections)
npm run test:connections

# Expected output:
# ✅ PASS 10 connections: 10 max, 0 errors
# ✅ PASS 25 connections: 25 max, 0 errors
# ✅ PASS 50 connections: 50 max, 0 errors
# ✅ PASS 60 connections: 60 max, 0 errors
```

### Schema Validation

```bash
# Validate all tables, indexes, constraints
supabase db query < scripts/validate_schema.sql

# Expected output:
# ✅ All 12 core tables exist
# ✅ LP duplicate prevention constraint exists
# ✅ Memory puzzle duplicate prevention exists
# ✅ All RLS policies enabled
```

### Manual Testing

```sql
-- Test couple creation
INSERT INTO couples (user1_id, user2_id) 
VALUES ('uuid1', 'uuid2');

-- Test duplicate prevention (should fail)
INSERT INTO couples (user1_id, user2_id) 
VALUES ('uuid1', 'uuid2'); -- ERROR: duplicate key

-- Test LP deduplication (should fail second insert)
INSERT INTO love_point_awards (id, couple_id, related_id, amount, reason)
VALUES (gen_random_uuid(), 'couple-uuid', 'quest-123', 30, 'Quest completion');

INSERT INTO love_point_awards (id, couple_id, related_id, amount, reason)
VALUES (gen_random_uuid(), 'couple-uuid', 'quest-123', 30, 'Quest completion');
-- ERROR: duplicate key value violates unique constraint "unique_related_award"
```

---

## 📈 Monitoring Queries

### Health Checks

```sql
-- Connection usage
SELECT 
  count(*) as active_connections,
  CASE 
    WHEN count(*) < 50 THEN 'healthy'
    WHEN count(*) < 55 THEN 'warning'
    ELSE 'critical'
  END as status
FROM pg_stat_activity 
WHERE datname = 'postgres';

-- Table sizes
SELECT 
  table_name,
  pg_size_pretty(pg_total_relation_size(quote_ident(table_name))) as size
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY pg_total_relation_size(quote_ident(table_name)) DESC;

-- Recent sync operations
SELECT 
  sync_type,
  success,
  COUNT(*) as count,
  AVG(duration_ms) as avg_duration
FROM sync_metrics
WHERE timestamp > NOW() - INTERVAL '1 hour'
GROUP BY sync_type, success;
```

---

## 🔧 Maintenance

### Vacuum & Analyze

```sql
-- Run after large data migrations
VACUUM ANALYZE;

-- Check bloat
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### Index Maintenance

```sql
-- Find unused indexes
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
AND indexrelname NOT LIKE 'pg_%';

-- Reindex if needed
REINDEX TABLE tablename;
```

---

## 📚 Related Documentation

- [Migration Plan](../docs/MIGRATION_TO_NEXTJS_POSTGRES.md)
- [API README](README.md)
- [Monitoring Guide](MONITORING.md)
- [Codex Review](../docs/CODEX_ROUND_2_REVIEW_SUMMARY.md)

---

**Issue #4 Status:** ✅ Complete - Schema ready for production deployment

# Database Scalability Plan

**Created:** 2025-12-09
**Updated:** 2025-12-09
**Status:** Phase 1 & 2 Implemented - Pending Migration Execution
**Goal:** Prepare database layer for 1000+ concurrent users

---

## Executive Summary

Current bottlenecks identified during code review:
1. **OR query in couple lookup** — runs on every API call, can't use indexes efficiently
2. **Missing composite indexes** — common query patterns not optimized
3. **No caching layer** — every request hits database
4. **Single connection per worker** — limits throughput

This plan addresses these in phases, with testing gates between each.

---

## Phase 1: Optimize Couple Lookup Query (P0)

**Problem:** Every API request runs this query:
```sql
SELECT id FROM couples WHERE user1_id = $1 OR user2_id = $1 LIMIT 1
```

PostgreSQL can't efficiently use separate indexes for OR conditions.

### Solution: Create `user_couples` lookup table

A denormalized table that maps user → couple directly.

### 1.1 Create Migration

```sql
-- api/supabase/migrations/027_user_couples_lookup.sql

-- Lookup table for O(1) user → couple mapping
CREATE TABLE IF NOT EXISTS user_couples (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE
);

-- Index for reverse lookups (get all users in a couple)
CREATE INDEX idx_user_couples_couple_id ON user_couples(couple_id);

-- Populate from existing data
INSERT INTO user_couples (user_id, couple_id)
SELECT user1_id, id FROM couples
UNION ALL
SELECT user2_id, id FROM couples
ON CONFLICT (user_id) DO NOTHING;

-- Trigger to keep in sync when couples are created
CREATE OR REPLACE FUNCTION sync_user_couples()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO user_couples (user_id, couple_id) VALUES (NEW.user1_id, NEW.id);
    INSERT INTO user_couples (user_id, couple_id) VALUES (NEW.user2_id, NEW.id);
  ELSIF TG_OP = 'DELETE' THEN
    DELETE FROM user_couples WHERE couple_id = OLD.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_sync_user_couples
AFTER INSERT OR DELETE ON couples
FOR EACH ROW EXECUTE FUNCTION sync_user_couples();
```

### 1.2 Update `lib/couple/utils.ts`

```typescript
// New optimized query
export async function getCoupleId(
  userId: string,
  client?: PoolClient
): Promise<string | null> {
  const queryFn = client ? client.query.bind(client) : query;

  const result = await queryFn(
    `SELECT couple_id FROM user_couples WHERE user_id = $1`,
    [userId]
  );

  return result.rows.length > 0 ? result.rows[0].couple_id : null;
}

// Update getCoupleBasic to use JOIN
export async function getCoupleBasic(
  userId: string,
  client?: PoolClient
): Promise<CoupleBasicInfo | null> {
  const queryFn = client ? client.query.bind(client) : query;

  const result = await queryFn(
    `SELECT c.id, c.user1_id, c.user2_id
     FROM user_couples uc
     JOIN couples c ON c.id = uc.couple_id
     WHERE uc.user_id = $1`,
    [userId]
  );

  if (result.rows.length === 0) return null;

  const row = result.rows[0];
  const isPlayer1 = userId === row.user1_id;

  return {
    coupleId: row.id,
    user1Id: row.user1_id,
    user2Id: row.user2_id,
    isPlayer1,
    partnerId: isPlayer1 ? row.user2_id : row.user1_id,
  };
}
```

### 1.3 Testing Gate

- [ ] Run migration on local/staging Supabase
- [ ] Verify `user_couples` populated correctly: `SELECT COUNT(*) FROM user_couples` = 2× couples count
- [ ] Test couple creation flow — verify trigger populates lookup table
- [ ] Test couple deletion — verify cascade works
- [ ] Run `EXPLAIN ANALYZE` on new query — should show Index Scan, not Seq Scan
- [ ] Load test: 100 concurrent requests to `/api/sync/daily-quests`
- [ ] Compare response times before/after

**Success Criteria:**
- Query uses index (EXPLAIN shows `Index Scan on user_couples`)
- p95 latency reduced by 50%+ on couple lookup

---

## Phase 2: Add Missing Composite Indexes (P1)

**Problem:** Common multi-column queries don't have composite indexes.

### 2.1 Create Migration

```sql
-- api/supabase/migrations/028_composite_indexes.sql

-- branch_progression: queried by (couple_id, activity_type)
CREATE UNIQUE INDEX IF NOT EXISTS idx_branch_progression_couple_activity
ON branch_progression(couple_id, activity_type);

-- quiz_matches: queried by (couple_id, quiz_type, date)
CREATE INDEX IF NOT EXISTS idx_quiz_matches_couple_type_date
ON quiz_matches(couple_id, quiz_type, date);

-- linked_matches: queried by (couple_id, status)
CREATE INDEX IF NOT EXISTS idx_linked_matches_couple_status
ON linked_matches(couple_id, status);

-- word_search_matches: queried by (couple_id, status)
CREATE INDEX IF NOT EXISTS idx_word_search_matches_couple_status
ON word_search_matches(couple_id, status);

-- you_or_me_sessions: queried by (couple_id, date)
CREATE INDEX IF NOT EXISTS idx_you_or_me_sessions_couple_date_v2
ON you_or_me_sessions(couple_id, date);
```

### 2.2 Testing Gate

- [ ] Run migration
- [ ] Run `EXPLAIN ANALYZE` on key queries in `lib/game/handler.ts` and `lib/puzzle/loader.ts`
- [ ] Verify new indexes are used
- [ ] Check index bloat isn't excessive: `SELECT pg_size_pretty(pg_indexes_size('branch_progression'))`

**Success Criteria:**
- All multi-column queries show `Index Scan` in EXPLAIN
- No significant increase in write latency

---

## Phase 3: Remove Transaction Wrapper for Read-Only Operations (P3)

**Problem:** Single-read operations wrapped in transactions add overhead.

### 3.1 Identify Read-Only Routes

Routes that only SELECT and don't need transactions:
- `GET /api/sync/daily-quests` — reads quests
- `GET /api/sync/love-points` — reads LP
- `GET /api/sync/couple-preferences` — reads preferences
- `GET /api/sync/quiz/[sessionId]` — reads quiz session
- `GET /api/sync/linked/[matchId]` — reads match state

### 3.2 Update Pattern

```typescript
// Before: Unnecessary transaction
export const GET = withAuthOrDevBypass(async (req, userId) => {
  return withTransactionResult(async (client) => {
    const couple = await getCoupleBasic(userId, client);
    // ... single read ...
  });
});

// After: Direct query
export const GET = withAuthOrDevBypass(async (req, userId) => {
  const couple = await getCoupleBasic(userId);
  if (!couple) {
    return NextResponse.json({ error: 'No couple found' }, { status: 404 });
  }
  // ... single read using query() directly ...
});
```

### 3.3 Testing Gate

- [ ] Audit all GET routes for transaction usage
- [ ] Update routes that only do reads
- [ ] Run integration tests
- [ ] Measure latency improvement (expect 2-5ms reduction per request)

**Success Criteria:**
- All read-only routes use direct `query()` instead of `withTransaction`
- No regressions in functionality

---

## Phase 4: Add Caching Layer (P1) — Future

**Problem:** Couple data rarely changes but is fetched on every request.

### 4.1 Options

| Option | Pros | Cons |
|--------|------|------|
| **Redis (Upstash)** | Persistent, shared across workers | Additional service, cost |
| **In-memory LRU** | Simple, no external deps | Lost on worker recycle, not shared |
| **Vercel KV** | Integrated with Vercel | Cost at scale |

### 4.2 Recommended: Upstash Redis

```typescript
// lib/cache/couple-cache.ts
import { Redis } from '@upstash/redis';

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_URL,
  token: process.env.UPSTASH_REDIS_TOKEN,
});

const COUPLE_CACHE_TTL = 300; // 5 minutes

export async function getCachedCoupleId(userId: string): Promise<string | null> {
  const cacheKey = `couple:${userId}`;

  // Try cache first
  const cached = await redis.get<string>(cacheKey);
  if (cached) return cached;

  // Miss: fetch from DB
  const coupleId = await getCoupleIdFromDb(userId);
  if (coupleId) {
    await redis.set(cacheKey, coupleId, { ex: COUPLE_CACHE_TTL });
  }

  return coupleId;
}

export async function invalidateCoupleCache(coupleId: string, user1Id: string, user2Id: string) {
  await redis.del(`couple:${user1Id}`, `couple:${user2Id}`);
}
```

### 4.3 Testing Gate

- [ ] Set up Upstash Redis (free tier: 10k requests/day)
- [ ] Implement cache with proper invalidation on couple changes
- [ ] Load test: verify cache hit rate >90%
- [ ] Monitor Redis latency (should be <5ms)

**Success Criteria:**
- Cache hit rate >90% after warm-up
- Database queries reduced by 80%+

---

## Phase 5: Connection Pool Tuning (P2) — Future

**Problem:** `max: 1` connection per worker limits throughput.

### 5.1 Current Setup

```typescript
// Using Supabase connection pooler (pgBouncer)
DATABASE_POOL_URL=postgresql://...pooler.supabase.com:6543/postgres
```

### 5.2 Recommended Changes

```typescript
// pool.ts
pool = new Pool({
  connectionString: process.env.DATABASE_POOL_URL,
  max: 3,  // Allow 3 connections per worker (pgBouncer handles actual pooling)
  idleTimeoutMillis: 10000,  // Reduce idle timeout
  connectionTimeoutMillis: 5000,
});
```

### 5.3 Supabase Limits to Monitor

| Tier | Max Connections | Recommended max per worker |
|------|-----------------|---------------------------|
| Free | 60 | 1-2 |
| Pro | 200 | 3-5 |
| Enterprise | 500+ | 5-10 |

### 5.4 Testing Gate

- [ ] Increase `max` to 2, monitor connection usage
- [ ] Check Supabase dashboard for connection saturation
- [ ] Load test with 500 concurrent users
- [ ] If stable, try `max: 3`

**Success Criteria:**
- No connection pool exhaustion errors
- Improved throughput under load

---

## Implementation Order

```
Phase 1 (Couple Lookup)     ████████████████  HIGH IMPACT, MEDIUM EFFORT
     ↓
Phase 2 (Indexes)           ████████          MEDIUM IMPACT, LOW EFFORT
     ↓
Phase 3 (Transaction Trim)  ████              LOW IMPACT, LOW EFFORT
     ↓
Phase 4 (Caching)           ████████████████  HIGH IMPACT, MEDIUM EFFORT
     ↓
Phase 5 (Pool Tuning)       ████████          MEDIUM IMPACT, LOW EFFORT
```

**Recommended start:** Phase 1 + Phase 2 together (can be done in parallel)

---

## Metrics to Track

Before starting, baseline these metrics:

1. **p50/p95/p99 latency** on `/api/sync/daily-quests`
2. **Database query time** for `getCoupleBasic()`
3. **Connection pool utilization** in Supabase dashboard
4. **Queries per minute** to `couples` table

After each phase, compare against baseline.

---

## Rollback Plan

Each phase is independent and can be rolled back:

- **Phase 1:** Drop `user_couples` table, revert `lib/couple/utils.ts`
- **Phase 2:** Drop indexes (won't break functionality, just slower)
- **Phase 3:** Re-add transaction wrappers
- **Phase 4:** Bypass cache, query DB directly
- **Phase 5:** Reduce `max` back to 1

---

---

## Implementation Status

### Phase 1: User Couples Lookup Table
**Status:** ✅ Implemented

**Files created/modified:**
- `api/supabase/migrations/027_user_couples_lookup.sql` - New lookup table with trigger
- `api/lib/couple/utils.ts` - Updated all three functions to use new table

**To deploy:**
```bash
# Run migration on Supabase
cd api
supabase db push
# Or apply manually in Supabase SQL editor
```

**Verification after deploy:**
```sql
-- Check row count matches
SELECT
  (SELECT COUNT(*) FROM couples) * 2 AS expected_rows,
  (SELECT COUNT(*) FROM user_couples) AS actual_rows;

-- Test query plan (should show Index Scan)
EXPLAIN ANALYZE
SELECT couple_id FROM user_couples WHERE user_id = 'some-uuid';
```

### Phase 2: Composite Indexes
**Status:** ✅ Implemented

**Files created:**
- `api/supabase/migrations/028_composite_indexes.sql` - 9 new composite indexes

**To deploy:**
```bash
# Run migration on Supabase
cd api
supabase db push
```

**Verification after deploy:**
```sql
-- Check indexes exist
SELECT indexname FROM pg_indexes
WHERE schemaname = 'public'
AND indexname LIKE 'idx_%_couple_%';
```

### Phase 3-5: Future
**Status:** Not started (see plan sections above)

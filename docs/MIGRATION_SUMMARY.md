# Migration to Next.js + PostgreSQL: Executive Summary

**Date:** 2025-11-18
**Status:** Proposed Architecture
**Audience:** Technical review, architectural feedback

---

## TL;DR

**Current:** Firebase Realtime Database (RTDB) with client-side sync logic
**Proposed:** Next.js + PostgreSQL (Supabase) with server-authoritative architecture
**Why:** We don't need real-time features, and client-side complexity is causing recurring bugs
**Impact:** Eliminates entire classes of bugs, improves security, enables future scaling

---

## The Core Problem

Our app is a couples app (2 devices syncing data: daily quests, love points, game states). Current architecture has client devices coordinating directly via Firebase RTDB.

### Known Issues This Causes

From `docs/KNOWN_ISSUES.md`:

1. **Duplicate Love Points (60 LP instead of 30 LP)** - Multiple services/listeners award LP simultaneously
2. **Memory Flip sync failure (11 attempts to fix)** - Non-deterministic ID generation, race conditions
3. **Complex coordination bugs** - "First device creates, second loads" pattern fragile
4. **Silent failures** - Missing Firebase security rules, permission denied swallowed

**Pattern:** Every major bug is caused by client-side complexity (ID generation, coordination logic, listener management).

---

## Key Insight: We Don't Actually Need Real-Time

| Feature | Current (RTDB) | Actual Need | What Changes |
|---------|----------------|-------------|--------------|
| Daily Quests | Real-time listeners | Generated once/day | Poll every 30s |
| Quest Completions | Real-time updates | Partner sees within 30s | Poll + push notification |
| LP Awards | Real-time listeners | Instant feedback | Poll + push notification |
| Memory Flip | Deliberately no real-time | No real-time | Sync on next load (no change) |
| You or Me | Session-based | No real-time | Fetch on load (no change) |

**Conclusion:** 30-second polling is sufficient. Real-time adds complexity without UX benefit.

---

## Architecture Comparison

### Current: Client-Driven

```
Device A                    Firebase RTDB                    Device B
├─ Generates IDs           ├─ Shared JSON data              ├─ Listens for changes
├─ Coordinates via RTDB    ├─ Weak security rules           ├─ Generates duplicate IDs
├─ Manages listeners       ├─ No validation                 ├─ Race conditions
└─ Complex deduplication   └─ No server logic               └─ Silent failures
```

**Problems:**
- Clients generate IDs → ID mismatches (different on each device)
- Clients coordinate → race conditions, duplicates
- Clients manage listeners → duplicate listener bugs
- No server validation → data corruption possible

### Proposed: Server-Authoritative

```
Device A                    Next.js API                      PostgreSQL
├─ Optimistic UI update    ├─ Authenticate                  ├─ Source of truth
├─ Queue sync request      ├─ Validate                      ├─ ACID guarantees
└─ Poll every 30s          ├─ Generate IDs (server-side)    ├─ Constraints prevent duplicates
                           ├─ Enforce business logic        └─ Relational data
                           └─ Return full state
```

**Benefits:**
- Server generates IDs → deterministic, no mismatches
- Server validates → data integrity guaranteed
- Database constraints → atomic operations, no race conditions
- Simple polling → no listener management bugs

---

## How This Fixes Known Issues

### Issue: Duplicate LP Awards (Service Layer)

**Current bug:** `YouOrMeService` awards 30 LP, `DailyQuestService` awards 30 LP → 60 LP total

**After migration:**
- Only server endpoint can award LP
- Database constraint: `UNIQUE(couple_id, related_id)` prevents duplicates
- **Result: Impossible** - only one place awards LP, constraint blocks duplicates

### Issue: Duplicate LP Awards (Listener Duplication)

**Current bug:** Multiple Firebase listeners created → `onChildAdded` fires twice → 60 LP

**After migration:**
- No Firebase listeners (polling model)
- Server tracks applied awards in database
- **Result: Impossible** - listeners eliminated entirely

### Issue: Memory Flip Sync Failure (11 Attempts)

**Current bugs:**
- Non-deterministic couple ID (`user.pushToken` different on each device)
- Non-deterministic puzzle ID (random UUIDs)
- Race condition (both devices generate simultaneously)

**After migration:**
- Server generates couple ID from database (deterministic)
- Server uses date-based puzzle ID: `puzzle_2025-11-18` (deterministic)
- Database constraint: `UNIQUE(couple_id, date)` prevents duplicates
- **Result: Impossible** - server controls all IDs, constraint handles races

### Pattern Recognition

All documented bugs share root cause: **client-side complexity**.

| Root Cause | Current | After Migration |
|------------|---------|-----------------|
| Non-deterministic IDs | Client generates | Server generates |
| Duplicate logic | Multiple services | Single endpoint |
| Race conditions | Client coordination | Database constraints |
| Listener bugs | Firebase listeners | Polling (no listeners) |

**Migration eliminates the patterns that caused bugs, not just the symptoms.**

---

## Benefits Summary

| Category | Improvement |
|----------|-------------|
| **Bug Prevention** | 11-attempt debugging sessions become impossible (server controls IDs, constraints prevent races) |
| **Security** | Supabase Row Level Security >> Firebase RTDB path rules. Proper auth >> FCM tokens. |
| **Data Integrity** | Server validates all writes, database constraints enforce rules |
| **Debuggability** | SQL queries >> RTDB path navigation. Distributed tracing for end-to-end visibility. |
| **Scalability** | PostgreSQL relations + indexes >> denormalized JSON |
| **Maintainability** | RESTful endpoints >> Firebase listeners with deduplication hacks |

---

## Major Risks Identified

### High Priority (Must Address Before Launch)

| Risk | Issue | Mitigation |
|------|-------|------------|
| **Bandwidth cost 10x higher** | Polling = 158 GB/month not 900 MB. Exceeds free tier. | Adaptive polling, compression, batch endpoints |
| **Database fills in 2 weeks** | 10K couples = 1.67 GB/month. 500 MB limit exceeded fast. | Aggressive retention (30 days), archive old data |
| **Token refresh failures** | Supabase tokens expire hourly, quest completion could fail mid-operation | Auto-refresh 5min before expiry, retry on 401 |
| **Data migration complexity** | Existing users have RTDB data, no migration plan | Incremental migration script, 1000 users/day |
| **No load testing** | Don't know if API handles 10K users | Required before launch |

### Medium Priority (Monitor in Production)

| Risk | Issue | Mitigation |
|------|-------|------------|
| **Multi-region latency** | Supabase single-region, couple in US+EU = 200-300ms latency | Read replicas ($25/month) or edge caching |
| **Polling delay perception** | 30s delay vs RTDB's 1-2s might feel slow | Push notifications supplement, optimistic UI |
| **Observability gaps** | No distributed tracing, hard to debug | Trace IDs in headers, Sentry/Datadog |

### Cost Reality Check

**Original estimate:** Free tier sufficient up to 50K couples

**Revised estimate:**
- **Bandwidth:** Need paid tier at 10K users (~$12/month)
- **Database:** Need Pro tier at 5K couples ($25/month)
- **Total:** ~$37/month at 10K users (still reasonable, but not free)

---

## What We're NOT Changing

- **Local-first philosophy:** Hive storage remains, optimistic UI updates
- **Offline support:** Sync queue with retry logic
- **Device pairing:** Still simple QR code flow (now with anonymous auth)
- **Push notifications:** Still using FCM for instant alerts
- **Flutter app:** Same frontend framework

**Only changing:** Backend data sync mechanism (RTDB → PostgreSQL + API)

---

## Key Architectural Decisions

### 1. Polling vs Real-Time

**Decision:** 30-second polling instead of real-time listeners

**Rationale:**
- Current "real-time" features don't benefit from sub-second updates
- Partner seeing quest completion in 30s vs 2s is imperceptible
- Eliminates entire class of listener management bugs
- Push notifications provide instant alerts when needed

**Trade-off:** Slightly slower partner visibility (acceptable given UX context)

### 2. Server-Side ID Generation

**Decision:** Server generates all IDs (couple IDs, quest IDs, puzzle IDs)

**Rationale:**
- Client-generated IDs caused 11-attempt debugging sessions
- Server has database, can ensure uniqueness
- Database constraints provide atomic guarantees

**Trade-off:** None - strictly better than client generation

### 3. Database Constraints Over Application Logic

**Decision:** Use PostgreSQL `UNIQUE` constraints, foreign keys, transactions

**Rationale:**
- Constraints are atomic (no race conditions)
- Work even if application has bugs
- Self-documenting (schema enforces rules)

**Trade-off:** Schema changes require migrations (acceptable)

### 4. Anonymous Auth for Seamless Pairing

**Decision:** Supabase anonymous auth, optional email later

**Rationale:**
- Current pairing is instant (no email required)
- Forcing email = user churn
- Anonymous accounts work, email only for recovery

**Trade-off:** Users without email can't recover account (same as current)

---

## Questions for Review

### Architecture

1. **Is server-authoritative the right approach for this use case?** (2 devices, couples only)
2. **Is PostgreSQL overkill, or appropriate for relational data?** (couples, quests, completions)
3. **Are we underestimating any scaling challenges?** (Database size, query performance, connection pooling)

### Sync Strategy

4. **Is 30-second polling acceptable, or should we use Server-Sent Events?** (Battery vs UX)
5. **Are our offline sync patterns sound?** (Queue, priority, operation ordering)
6. **How should we handle dual-write consistency during migration?** (RTDB + API simultaneously)

### Security

7. **Is Supabase Row Level Security sufficient?** (vs custom authorization logic)
8. **Should we add rate limiting from day 1?** (Prevent abuse, accidental DoS)
9. **Is anonymous auth secure enough?** (No email = no recovery, acceptable?)

### Cost & Operations

10. **Are our cost estimates realistic?** (Bandwidth, database size, paid tier timing)
11. **What observability tools do we need?** (Distributed tracing, alerting, session replay)
12. **Should we plan for multi-region from the start?** (Latency for international couples)

### Migration Execution

13. **Is incremental migration the right approach?** (vs big-bang cutover)
14. **How do we migrate existing user data?** (RTDB → PostgreSQL, LP history, quiz sessions)
15. **What's the rollback plan if migration fails?** (Feature flags, circuit breakers, RTDB backup)

---

## Alternatives Considered

### Keep Firebase RTDB

**Pros:** No migration cost, proven to work
**Cons:** Security vulnerabilities, documented bugs persist, technical debt accumulates
**Verdict:** Short-term safe, long-term risky

### Hybrid (Firebase real-time + PostgreSQL structured data)

**Pros:** Best of both worlds
**Cons:** Double complexity, two databases to maintain, higher cost
**Verdict:** Overkill for our scale

### GraphQL Instead of REST

**Pros:** More efficient for mobile, built-in type safety
**Cons:** Learning curve, tooling complexity
**Verdict:** Defer until needed

### Edge Database (PlanetScale, Cloudflare D1)

**Pros:** Global distribution, lower latency
**Cons:** More expensive, less mature than Supabase
**Verdict:** Good future option if multi-region needed

---

## Recommendation

**Proceed with migration** for the following reasons:

### 1. Addresses Root Cause of All Documented Bugs

Not just fixing symptoms - eliminates the architectural patterns that caused 11-attempt debugging sessions.

### 2. Security Is Currently Vulnerable

FCM tokens as identity, weak RTDB rules. This is a time bomb. Migration fixes it.

### 3. Tech Debt Is Accumulating

Every workaround for RTDB limitations adds complexity. Migration pays down debt.

### 4. Cost Is Manageable

~$37/month at 10K users is reasonable. Free tier works for MVP and early growth.

### 5. Future-Proofs Architecture

Server-authoritative model enables features impossible with current architecture:
- Leaderboards (efficient queries)
- Achievements (server validates, can't cheat)
- Analytics (SQL queries vs RTDB exports)
- Admin tools (direct database access)

### Risks Are Mitigatable

High-priority risks (bandwidth, database size, token refresh) have clear mitigations. None are blockers.

---

## Next Steps for Reviewer

**To provide feedback:**

1. **Review architectural decisions** (polling vs real-time, server-authoritative, database constraints)
2. **Assess risk mitigations** (bandwidth, database size, token refresh, observability)
3. **Validate cost estimates** (are we missing hidden costs?)
4. **Challenge assumptions** (is 30s polling really acceptable? Is PostgreSQL the right choice?)
5. **Suggest alternatives** (different database, different sync pattern, keep RTDB?)

**Feedback format:**

- 👍 **Approve:** Architecture is sound, proceed with migration
- 🤔 **Approve with concerns:** Proceed but address specific risks first
- ⚠️ **Revise:** Major architectural flaw, need significant changes
- ❌ **Reject:** Migration not justified, stay with Firebase RTDB

---

## Additional Documentation

For deeper technical details:

- **Full migration plan:** `docs/MIGRATION_TO_NEXTJS_POSTGRES.md` (2,500 lines with code, schemas, timelines)
- **Current architecture:** `docs/BACKEND_SYNC_ARCHITECTURE.md` (existing Firebase RTDB patterns)
- **Known issues:** `docs/KNOWN_ISSUES.md` (11-attempt debugging sessions, all documented bugs)

---

**Questions or concerns?** This summary omits implementation details for readability. See full plan for database schemas, API endpoints, sync queue implementation, migration roadmap, etc.

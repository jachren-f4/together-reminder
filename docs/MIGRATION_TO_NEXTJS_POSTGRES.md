# Migration Strategy: Firebase RTDB → Next.js + PostgreSQL

**Version:** 1.0
**Date:** 2025-11-18
**Status:** Proposed Architecture

---

## Executive Summary

This document outlines the migration from Firebase Realtime Database (RTDB) to a Next.js + PostgreSQL architecture using Vercel and Supabase.

**Key Decision:** We don't actually need real-time features. A local-first architecture with server-authoritative sync endpoints is simpler, more secure, and more scalable.

**Timeline:** ~1 month (2-3 weeks development + 1 week migration)
**Risk:** Low (incremental migration with feature flags)
**Impact:** High (better security, proper auth, server-side validation, SQL flexibility)

---

## Table of Contents

1. [Why Migrate?](#why-migrate)
2. [How This Fixes Known Issues](#how-this-fixes-known-issues)
3. [Architecture Comparison](#architecture-comparison)
4. [Proposed Architecture](#proposed-architecture)
5. [Database Schema](#database-schema)
6. [Sync Endpoint Design](#sync-endpoint-design)
7. [Offline-First Implementation](#offline-first-implementation)
8. [Migration Roadmap](#migration-roadmap)
9. [Feature-Specific Strategies](#feature-specific-strategies)
10. [Security Model](#security-model)
11. [Conflict Resolution](#conflict-resolution)
12. [Concerns & Solutions](#concerns--solutions)

---

## Why Migrate?

### Reality Check: We Don't Need Real-Time

| Feature | Current (RTDB) | Actual Need | Proposed Solution |
|---------|----------------|-------------|-------------------|
| Daily Quests | Real-time listeners | Generated once/day | 30s polling |
| Quest Completions | Real-time updates | Nice to have | 30s polling + push notification |
| LP Awards | Real-time listeners | Instant feedback | 30s polling + push notification |
| Memory Flip | Deliberate no real-time | No real-time | Sync on next load |
| You or Me | Session-based | No real-time | Fetch on session load |

**Conclusion:** Real-time is solving a problem we don't have.

### What We Actually Gain

| Benefit | Current Pain | After Migration |
|---------|-------------|-----------------|
| **Security** | RTDB rules are weak, FCM tokens as identity | Supabase RLS + proper auth |
| **Data Integrity** | Client generates quests, can cheat | Server validates all writes |
| **Debuggability** | RTDB path navigation is opaque | SQL queries are transparent |
| **Scalability** | Denormalized JSON, limited queries | PostgreSQL relations, powerful queries |
| **Testing** | Firebase emulator is clunky | Local PostgreSQL + seed data |
| **Auth** | FCM tokens pretending to be users | Supabase Auth (magic links, OAuth) |
| **Cost** | Firebase pricing unpredictable | Supabase/Vercel free tiers sufficient |

---

## How This Fixes Known Issues

This migration directly addresses every issue documented in `docs/KNOWN_ISSUES.md`. The current architecture's client-side complexity is the root cause of all sync bugs. Moving to server-authoritative architecture eliminates these patterns entirely.

**Reference:** See `docs/KNOWN_ISSUES.md` for detailed bug histories and 11-attempt debugging sessions.

### Issue 1: Quest Card Not Updating After Completion ✅

**Current Bug:** Navigation stack management causes UI refresh failures
**Root Cause:** Complex Firebase listener callbacks + Flutter navigation state

**How Migration Helps:**
- **Simpler client code** - Polling model eliminates complex listener lifecycle management
- **Fewer moving parts** - No Firebase listeners → fewer setState() callback chains
- **Clearer data flow** - Fetch endpoint → update Hive → update UI (linear, predictable)

**Verdict:** Reduces architectural complexity that causes similar UI refresh bugs

### Issue 2: Duplicate LP Awards (Service Layer) ✅

**Current Bug:** 60 LP awarded instead of 30 LP
**Root Cause:** Multiple services awarding LP (`YouOrMeService` + `DailyQuestService`)

**How Migration Eliminates This:**

```typescript
// SERVER-SIDE: Single source of truth
POST /api/sync/love-points
{
  id: "award_quest_123",      // Client-generated UUID (idempotency)
  related_id: "quest_123",    // Quest ID for deduplication
  amount: 30
}

// DATABASE: Enforces deduplication
INSERT INTO love_point_awards (id, couple_id, related_id, amount)
VALUES (...)
ON CONFLICT (couple_id, related_id) DO NOTHING;
-- ✅ Second insert with same related_id = silently skipped
```

**Why this is impossible after migration:**
1. ✅ Server owns LP logic (not multiple client services)
2. ✅ Database constraint prevents duplicates: `UNIQUE(couple_id, related_id)`
3. ✅ Idempotent operations (same request twice = same result)
4. ✅ Client services can't award LP directly (only server can)

**From KNOWN_ISSUES.md:**
> "YouOrMeService awarded 30 LP, DailyQuestService awarded another 30 LP = 60 LP"

**After migration:** **Impossible.** Only one endpoint awards LP, database prevents duplicates.

### Issue 3: Duplicate LP Awards (Listener Duplication) ✅

**Current Bug:** 60 LP awarded when multiple Firebase listeners created
**Root Cause:** `startListeningForLPAwards()` called from multiple screens

**How Migration Eliminates This:**

```dart
// CURRENT (BROKEN): Firebase listeners
LovePointService.startListeningForLPAwards(...); // main.dart
LovePointService.startListeningForLPAwards(...); // home_screen.dart
// Result: onChildAdded fires twice → _handleLPAward() called twice → 60 LP

// AFTER MIGRATION: Simple polling, no listeners
Timer.periodic(Duration(seconds: 30), (_) async {
  final response = await http.post('/api/sync/love-points',
    body: { last_sync_timestamp: _lastSync }
  );

  // Server returns only NEW awards since last sync
  for (final award in response['new_awards']) {
    await _applyLPLocally(award);
  }
});
```

**Why this is impossible after migration:**
1. ✅ No Firebase listeners at all (polling model)
2. ✅ Server tracks applied awards in database
3. ✅ `last_sync_timestamp` prevents re-processing old awards
4. ✅ Simple stateless polling (no lifecycle management bugs)

**From KNOWN_ISSUES.md:**
> "Listener #1 fires → 30 LP, Listener #2 fires → another 30 LP = 60 LP"

**After migration:** **Impossible.** No listeners exist. Polling fetches new awards once.

### Issue 4: Memory Flip Cross-Device Sync Failure ✅

**Current Bug:** 11 attempts to fix sync (Alice and Bob see different puzzles)
**Root Causes:**
- Non-deterministic couple ID (`user.pushToken` different on each device)
- Non-deterministic puzzle ID (random UUIDs instead of date-based)
- "First device creates, second loads" race conditions

**How Migration Eliminates This:**

```typescript
// SERVER-SIDE: Deterministic ID generation + atomic operations
POST /api/sync/memory-flip
{ date: "2025-11-18" }

async function handler(req) {
  // 1. Server controls couple ID (from database, always deterministic)
  const couple = await db
    .select()
    .from('couples')
    .where(or(
      eq('user1_id', userId),
      eq('user2_id', userId)
    ))
    .first();

  // 2. Server uses date-based puzzle ID (deterministic)
  const puzzleId = `puzzle_${req.body.date}`;

  // 3. Database constraint handles race condition atomically
  let puzzle = await db
    .select()
    .from('memory_puzzles')
    .where({ couple_id: couple.id, date: req.body.date })
    .first();

  if (!puzzle) {
    // Generate server-side
    puzzle = await generatePuzzle(couple.id, req.body.date);

    // Database UNIQUE constraint prevents duplicates
    await db.insert('memory_puzzles').values(puzzle);
    // If both devices insert simultaneously, second fails gracefully
    // and refetches the first device's puzzle
  }

  return { puzzle };
}

// DATABASE: Enforces uniqueness
CREATE UNIQUE INDEX ON memory_puzzles(couple_id, date);
-- ✅ Second insert with same (couple_id, date) = constraint violation → refetch
```

**Why this is impossible after migration:**
1. ✅ Server generates couple ID (no client-side mistakes with `user.pushToken`)
2. ✅ Server uses date-based puzzle ID (no random UUIDs)
3. ✅ Database constraint prevents duplicate puzzles atomically
4. ✅ No "wait 2 seconds for first device" logic needed
5. ✅ No cascade dependency bugs (server controls all IDs)

**From KNOWN_ISSUES.md (11 attempts):**
> "Attempt 10: Alice generates `fab12448-...`, Bob generates `d287f99e-...` → Different puzzles"
> "Attempt 11: Fixed couple ID → revealed puzzle ID bug → finally working"

**After migration:** **Impossible.** Server generates all IDs deterministically. Database prevents duplicates.

**Specific fixes for Memory Flip cascade bugs:**

| Bug Layer | Current (11 Attempts) | After Migration |
|-----------|----------------------|-----------------|
| Couple ID | Client uses `user.pushToken` (different on each device) | Server uses database relationship (deterministic) |
| Puzzle ID | Client generates random UUID | Server uses `puzzle_YYYY-MM-DD` (deterministic) |
| Race condition | "First device creates" with 2-second wait | Database `UNIQUE` constraint (atomic) |
| Debugging | 11 attempts, manual Firebase inspection | Server logs show exact SQL queries |

### Issue 5: HealthKit Step Sync (Future Feature Prevention) ✅

**Current Concerns:** All documented pitfalls could occur:
- Duplicate LP awards (both devices detect goal completion)
- ID mismatches (couple ID generation bugs)
- Race conditions (simultaneous goal completion)
- Silent failures (missing Firebase security rules)

**How Migration Prevents All Pitfalls:**

```typescript
// SERVER-SIDE: Atomic goal completion with transaction
POST /api/sync/steps
{
  date: "2025-11-18",
  my_steps: 13000  // Alice just walked from 5k to 13k
}

async function handler(req) {
  const couple = await getCoupleForUser(userId);
  const dateKey = req.body.date;

  // 1. Update user's step count (partitioned, no conflicts)
  await db
    .update('step_goals')
    .set({ [`${userId}_steps`]: req.body.my_steps })
    .where({ couple_id: couple.id, date: dateKey });

  // 2. Fetch combined total
  const goal = await db.query.stepGoals.findFirst({
    where: and(
      eq('couple_id', couple.id),
      eq('date', dateKey)
    )
  });

  const combined = goal.alice_steps + goal.bob_steps;

  // 3. Check goal completion with ATOMIC TRANSACTION
  if (combined >= 20000 && !goal.lp_awarded) {
    await db.transaction(async (trx) => {
      // Atomic check-and-set (prevents duplicate awards)
      const result = await trx
        .update('step_goals')
        .set({ lp_awarded: true, completed_at: new Date() })
        .where(and(
          eq('couple_id', couple.id),
          eq('date', dateKey),
          eq('lp_awarded', false)  // CRITICAL: Only if not already awarded
        ))
        .returning();

      if (result.length > 0) {
        // Transaction succeeded - we won the race, award LP
        await awardLovePoints(couple.id, 30, 'step_goal_completion');
      } else {
        // Transaction failed - another device already awarded
        // Do nothing (no duplicate award)
      }
    });
  }

  return { goal: await refreshGoal(couple.id, dateKey) };
}
```

**Why all documented pitfalls are prevented:**

| Pitfall (from KNOWN_ISSUES.md) | How Migration Prevents |
|---------------------------------|------------------------|
| **Duplicate LP awards** | Database transaction: `lp_awarded: false → true` is atomic. Second device's transaction fails gracefully. |
| **ID determinism** | Server generates couple ID from database, date-based goal ID. No client-side generation = no mistakes. |
| **Race conditions** | Database transaction handles simultaneous requests. Only one succeeds, others see `lp_awarded = true`. |
| **Cascade dependency bugs** | Server owns all logic. No hidden client-side bugs to discover after first fix. |
| **Silent failures** | API returns HTTP errors. Client retries with exponential backoff. Server logs show exact SQL failures. |
| **Timing issues** | No "wait for partner" logic. Server is always source of truth. Clients just poll. |
| **Listener duplication** | No listeners. Polling model eliminates entire class of bugs. |

**From KNOWN_ISSUES.md:**
> "Alice hits 20k combined → Awards 30 LP, Bob's device delayed → Awards another 30 LP = 60 LP"

**After migration:** **Impossible.** Database transaction ensures exactly one LP award.

---

### Pattern Recognition: Root Causes Eliminated

All documented issues share common architectural problems that the migration systematically eliminates:

| Root Cause | Current Architecture | After Migration | Issues Fixed |
|------------|---------------------|-----------------|--------------|
| **Non-deterministic IDs** | Client generates (`user.pushToken`, random UUIDs) | Server generates (database relationships, date-based) | Memory Flip (11 attempts) |
| **Duplicate logic** | Multiple services can award LP | Single server endpoint owns LP logic | Duplicate LP (service layer) |
| **Race conditions** | "First device creates" with delays | Database constraints handle atomically | Memory Flip, Step Sync |
| **Listener duplication** | Firebase `onChildAdded` listeners | Polling (no listeners at all) | Duplicate LP (listeners) |
| **Complex coordination** | Clients coordinate via Firebase paths | Server is single source of truth | All sync issues |
| **Silent failures** | Permission denied errors swallowed | Server validates, returns HTTP errors | Quest sync, Memory Flip |

### The Core Insight

**Every documented issue is caused by client-side complexity:**
- Clients generating IDs → ID mismatches
- Clients coordinating logic → Duplicate awards
- Clients managing listeners → Listener bugs
- Clients detecting completion → Race conditions

**Migration eliminates client-side complexity:**
- ✅ Server generates all IDs (deterministic, no mistakes)
- ✅ Server controls all business logic (single authority)
- ✅ Server uses database constraints (atomic operations)
- ✅ Clients just poll endpoints (simple, stateless)

**Result:** The architectural patterns that caused 11-attempt debugging sessions become impossible.

---

## Architecture Comparison

### Current: Firebase RTDB (Client-Driven)

```
Device A (Alice)                    Firebase RTDB                    Device B (Bob)
┌─────────────┐                   ┌──────────────┐                 ┌─────────────┐
│             │                   │              │                 │             │
│  Generate   │ ──── write ────> │  Shared      │ <─── listen ─── │  Listen     │
│  quests     │                   │  Data        │                 │  for quests │
│  (client)   │                   │  (JSON)      │                 │  (client)   │
│             │ <─── listen ───── │              │ ──── write ───> │             │
│  Hive       │                   │ No validation│                 │  Hive       │
│  (local)    │                   │ Weak rules   │                 │  (local)    │
└─────────────┘                   └──────────────┘                 └─────────────┘
```

**Problems:**
- ❌ Client generates content (can cheat)
- ❌ Weak security (RTDB rules are path-based)
- ❌ No server-side validation
- ❌ Race conditions (both devices generate)
- ❌ Complex deduplication logic
- ❌ FCM tokens as identity (no proper auth)

### Proposed: Next.js + PostgreSQL (Server-Authoritative)

```
Device A (Alice)              Next.js API (Vercel)           PostgreSQL (Supabase)
┌─────────────┐              ┌─────────────────┐            ┌──────────────┐
│             │              │                 │            │              │
│ Optimistic  │ ── sync ──> │  Authenticate   │ ──query──> │ Source of    │
│ UI update   │              │  Validate       │            │ Truth        │
│             │              │  Merge logic    │            │              │
│ Hive        │ <── state ── │  Generate       │ <──write── │ PostgreSQL   │
│ (local)     │              │  (server-side)  │            │ (relational) │
│             │              │                 │            │              │
│ Sync queue  │              │  Supabase Auth  │            │ Supabase RLS │
│ (offline)   │              │  (proper auth)  │            │ (security)   │
└─────────────┘              └─────────────────┘            └──────────────┘
```

**Benefits:**
- ✅ Server generates content (authoritative)
- ✅ Strong security (Supabase RLS + auth)
- ✅ Server-side validation
- ✅ No race conditions (database constraints)
- ✅ Simple deduplication (UNIQUE constraints)
- ✅ Proper authentication (Supabase Auth)

---

## Proposed Architecture

### Tech Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Frontend** | Flutter 3.16+ | Mobile app (iOS/Android) |
| **Local Storage** | Hive | Offline-first, optimistic updates |
| **API** | Next.js 14+ (App Router) | RESTful sync endpoints |
| **Hosting** | Vercel | Edge functions, auto-scaling |
| **Database** | PostgreSQL 15+ | Relational data, source of truth |
| **DB Hosting** | Supabase | Managed PostgreSQL + RLS |
| **Connection Pooling** | Supabase PgBouncer | Efficient connection management |
| **DB Client** | Drizzle ORM | Type-safe queries with connection pooling |
| **Auth** | Supabase Auth | Magic links, OAuth, session management |

### Client-Server Sync Model

```
┌─────────────────────────┐         ┌──────────────────────────┐
│  Flutter App            │         │  Next.js API             │
├─────────────────────────┤         ├──────────────────────────┤
│ User Action             │         │                          │
│   ↓                     │         │                          │
│ 1. Optimistic update    │         │                          │
│    (instant UI)         │         │                          │
│   ↓                     │         │                          │
│ 2. Write to Hive        │         │                          │
│    (local storage)      │         │                          │
│   ↓                     │         │                          │
│ 3. Queue sync request   │──sync──▶│ 1. Authenticate user     │
│    (background)         │         │    (Supabase Auth)       │
│   ↓                     │         │   ↓                      │
│ 4. Pull server state    │◀────────│ 2. Validate request      │
│   ↓                     │         │   ↓                      │
│ 5. Merge conflicts      │         │ 3. Query PostgreSQL      │
│    (if any)             │         │   ↓                      │
│   ↓                     │         │ 4. Merge client data     │
│ 6. Update Hive          │         │   ↓                      │
│   ↓                     │         │ 5. Write to database     │
│ 7. Update UI            │         │   ↓                      │
│                         │         │ 6. Return new state      │
└─────────────────────────┘         └──────────────────────────┘
                                              │
                                    ┌─────────▼──────────┐
                                    │ PostgreSQL         │
                                    │ (Supabase)         │
                                    │                    │
                                    │ - Row Level Sec.   │
                                    │ - ACID guarantees  │
                                    │ - Relational data  │
                                    └────────────────────┘
```

---

## Database Schema

### Core Tables

```sql
-- ============================================================================
-- USERS & COUPLES
-- ============================================================================

-- Users table (managed by Supabase Auth)
-- id, email, created_at automatically handled

-- Couples table
CREATE TABLE couples (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user1_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  user2_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,

  -- Ensure unique pairing (sorted user IDs)
  CONSTRAINT unique_couple UNIQUE(user1_id, user2_id),
  CONSTRAINT different_users CHECK (user1_id != user2_id)
);

-- Couple invite codes (for pairing flow)
CREATE TABLE couple_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  inviter_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  invite_code TEXT UNIQUE NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ,
  used_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================================================
-- DAILY QUESTS
-- ============================================================================

-- Daily quests (server-generated, one set per couple per day)
CREATE TABLE daily_quests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,
  date DATE NOT NULL,
  quest_type TEXT NOT NULL, -- 'quiz', 'you_or_me', etc.
  content_id UUID NOT NULL, -- References quiz_sessions, you_or_me_sessions, etc.
  sort_order INT NOT NULL,
  is_side_quest BOOLEAN DEFAULT FALSE,

  -- Metadata (denormalized for fast reads)
  metadata JSONB DEFAULT '{}'::jsonb, -- { formatType, quizName, category, etc. }

  generated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,

  -- Ensure one set of quests per couple per day
  CONSTRAINT unique_quest_per_day UNIQUE(couple_id, date, quest_type, sort_order)
);

-- Quest completions (track individual progress)
CREATE TABLE quest_completions (
  quest_id UUID REFERENCES daily_quests(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  completed_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,

  PRIMARY KEY(quest_id, user_id)
);

-- ============================================================================
-- QUIZ SYSTEM
-- ============================================================================

-- Quiz sessions
CREATE TABLE quiz_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,
  created_by UUID REFERENCES auth.users(id) NOT NULL,

  format_type TEXT NOT NULL, -- 'classic', 'affirmation', 'speed_round'
  category TEXT,
  difficulty INT,

  status TEXT DEFAULT 'waiting_for_answers', -- 'waiting_for_answers', 'completed'

  -- Questions (stored as JSONB)
  questions JSONB NOT NULL, -- [{ id, text, choices, correctIndex, ... }]

  -- Denormalized metadata
  quiz_name TEXT,
  is_daily_quest BOOLEAN DEFAULT FALSE,

  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  expires_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
);

-- Quiz answers
CREATE TABLE quiz_answers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES quiz_sessions(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  question_id TEXT NOT NULL, -- ID from questions JSONB
  selected_index INT NOT NULL,
  is_correct BOOLEAN NOT NULL,
  answered_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,

  UNIQUE(session_id, user_id, question_id)
);

-- Quiz progression (tracks couple's progress through quiz tracks)
CREATE TABLE quiz_progression (
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE PRIMARY KEY,
  current_track INT DEFAULT 0,
  current_position INT DEFAULT 0,
  total_quizzes_completed INT DEFAULT 0,
  completed_quizzes JSONB DEFAULT '[]'::jsonb, -- [quiz_id, quiz_id, ...]
  has_completed_all_tracks BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================================================
-- YOU OR ME GAME
-- ============================================================================

-- You or Me sessions
CREATE TABLE you_or_me_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,

  -- Questions (stored as JSONB)
  questions JSONB NOT NULL, -- [{ id, text, category }]

  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  expires_at TIMESTAMPTZ
);

-- You or Me answers
CREATE TABLE you_or_me_answers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES you_or_me_sessions(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  question_id TEXT NOT NULL, -- ID from questions JSONB
  answer TEXT NOT NULL, -- 'you', 'me', 'both'
  answered_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,

  UNIQUE(session_id, user_id, question_id)
);

-- You or Me progression (track used questions per couple)
CREATE TABLE you_or_me_progression (
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE PRIMARY KEY,
  used_question_ids JSONB DEFAULT '[]'::jsonb, -- [question_id, ...]
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================================================
-- MEMORY FLIP GAME
-- ============================================================================

-- Memory puzzles
CREATE TABLE memory_puzzles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,
  date DATE NOT NULL,

  -- Puzzle configuration
  total_pairs INT NOT NULL,
  matched_pairs INT DEFAULT 0,

  -- Cards (stored as JSONB)
  cards JSONB NOT NULL, -- [{ id, position, emoji, pairId, status, matchedBy, ... }]

  status TEXT DEFAULT 'active', -- 'active', 'completed'
  completion_quote TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  completed_at TIMESTAMPTZ,

  UNIQUE(couple_id, date) -- One puzzle per couple per day
);

-- ============================================================================
-- LOVE POINTS
-- ============================================================================

-- LP awards (deduplication via related_id)
CREATE TABLE love_point_awards (
  id UUID PRIMARY KEY, -- Client-generated for idempotency
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,
  amount INT NOT NULL CHECK (amount > 0),
  reason TEXT NOT NULL,
  related_id UUID, -- e.g., quest_id, session_id (for deduplication)
  multiplier INT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,

  -- Prevent duplicate awards for same activity
  CONSTRAINT unique_related_award UNIQUE(couple_id, related_id)
);

-- User LP totals (materialized for performance)
CREATE TABLE user_love_points (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  total_points INT DEFAULT 0 CHECK (total_points >= 0),
  arena_tier INT DEFAULT 1 CHECK (arena_tier BETWEEN 1 AND 5),
  floor INT DEFAULT 0 CHECK (floor >= 0),
  last_activity_date TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Couples
CREATE INDEX idx_couples_user1 ON couples(user1_id);
CREATE INDEX idx_couples_user2 ON couples(user2_id);

-- Daily quests
CREATE INDEX idx_daily_quests_couple_date ON daily_quests(couple_id, date);
CREATE INDEX idx_daily_quests_expires ON daily_quests(expires_at);

-- Quest completions
CREATE INDEX idx_quest_completions_user ON quest_completions(user_id);

-- Quiz sessions
CREATE INDEX idx_quiz_sessions_couple ON quiz_sessions(couple_id);
CREATE INDEX idx_quiz_sessions_status ON quiz_sessions(status);

-- LP awards
CREATE INDEX idx_lp_awards_couple ON love_point_awards(couple_id);
CREATE INDEX idx_lp_awards_created ON love_point_awards(created_at DESC);
```

### Row Level Security (RLS)

```sql
-- Enable RLS on all tables
ALTER TABLE couples ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_quests ENABLE ROW LEVEL SECURITY;
ALTER TABLE quest_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE love_point_awards ENABLE ROW LEVEL SECURITY;
-- ... (enable for all tables)

-- Couples: Users can only see/modify couples they're part of
CREATE POLICY couple_access ON couples
  FOR ALL USING (
    user1_id = auth.uid() OR user2_id = auth.uid()
  );

-- Daily quests: Users can only see quests for their couple
CREATE POLICY quest_access ON daily_quests
  FOR ALL USING (
    couple_id IN (
      SELECT id FROM couples
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

-- Quest completions: Users can only see completions for their couple's quests
CREATE POLICY completion_access ON quest_completions
  FOR ALL USING (
    quest_id IN (
      SELECT dq.id FROM daily_quests dq
      JOIN couples c ON dq.couple_id = c.id
      WHERE c.user1_id = auth.uid() OR c.user2_id = auth.uid()
    )
  );

-- Apply similar policies to all other tables
```

---

## Sync Endpoint Design

### Endpoint Pattern: Feature-Based, Batched Operations

**Philosophy:** One endpoint per feature, batches reads/writes, returns full state.

### JWT Validation Middleware

```typescript
// lib/auth-middleware.ts
import { createClient } from '@/lib/supabase/server';
import { NextRequest, NextResponse } from 'next/server';

export async function validateRequest(req: NextRequest): Promise<{ userId: string } | NextResponse> {
  try {
    // Extract JWT from Authorization header
    const authHeader = req.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return NextResponse.json({ error: 'No authorization header' }, { status: 401 });
    }

    const token = authHeader.split(' ')[1];
    
    // Verify JWT with Supabase
    const supabase = createClient();
    const { data: { user }, error } = await supabase.auth.getUser(token);

    if (error || !user) {
      return NextResponse.json({ error: 'Invalid token' }, { status: 401 });
    }

    return { userId: user.id };
  } catch (error) {
    return NextResponse.json({ error: 'Authentication failed' }, { status: 401 });
  }
}
```

### Updated Daily Quests Sync

```typescript
// app/api/sync/daily-quests/route.ts

import { validateRequest } from '@/lib/auth-middleware';
import { NextRequest, NextResponse } from 'next/server';

export async function POST(req: NextRequest) {
  try {
    // 1. Authenticate user via JWT
    const authResult = await validateRequest(req);
    if (authResult instanceof NextResponse) {
      return authResult; // Error response
    }

    const { userId } = authResult;

    // 2. Parse request body
    const { date, completions } = await req.json();

    // 3. Get user's couple
    const { data: couple } = await supabase
      .from('couples')
      .select('id')
      .or(`user1_id.eq.${user.id},user2_id.eq.${user.id}`)
      .single();

    if (!couple) {
      return NextResponse.json({ error: 'No couple found' }, { status: 404 });
    }

    // 4. Get or generate quests for this date
    let { data: quests } = await supabase
      .from('daily_quests')
      .select('*')
      .eq('couple_id', couple.id)
      .eq('date', date);

    if (!quests || quests.length === 0) {
      // Generate quests server-side
      quests = await generateQuestsForCouple(couple.id, date);

      // Insert into database
      const { data: insertedQuests } = await supabase
        .from('daily_quests')
        .insert(quests)
        .select();

      quests = insertedQuests || [];
    }

    // 5. Merge completions from client
    if (completions && Object.keys(completions).length > 0) {
      const completionInserts = Object.entries(completions).map(([questId, data]: any) => ({
        quest_id: questId,
        user_id: user.id,
        completed_at: data.completed_at || new Date().toISOString(),
      }));

      // Upsert completions (idempotent)
      await supabase
        .from('quest_completions')
        .upsert(completionInserts, {
          onConflict: 'quest_id,user_id',
          ignoreDuplicates: false,
        });
    }

    // 6. Fetch all completions for these quests
    const { data: allCompletions } = await supabase
      .from('quest_completions')
      .select('quest_id, user_id, completed_at')
      .in('quest_id', quests.map(q => q.id));

    // 7. Format response
    const completionsMap: Record<string, any> = {};
    allCompletions?.forEach(comp => {
      if (!completionsMap[comp.quest_id]) {
        completionsMap[comp.quest_id] = {};
      }
      completionsMap[comp.quest_id][comp.user_id] = {
        completed_at: comp.completed_at,
      };
    });

    // 8. Return full state
    return NextResponse.json({
      quests,
      completions: completionsMap,
      synced_at: new Date().toISOString(),
    });

  } catch (error) {
    console.error('Sync error:', error);
    return NextResponse.json({ error: 'Sync failed' }, { status: 500 });
  }
}

// Helper: Generate quests for couple on given date
async function generateQuestsForCouple(coupleId: string, date: string) {
  // Load progression state
  const progression = await loadProgressionState(coupleId);

  // Generate 4 quests based on progression
  const quests = [];

  // Quest 1-3: Quiz quests
  for (let i = 0; i < 3; i++) {
    const config = getTrackConfig(progression.currentTrack, progression.currentPosition + i);
    const session = await generateQuizSession(coupleId, config);

    quests.push({
      couple_id: coupleId,
      date,
      quest_type: 'quiz',
      content_id: session.id,
      sort_order: i,
      is_side_quest: false,
      metadata: {
        formatType: config.formatType,
        quizName: session.quiz_name,
        category: config.categoryFilter,
      },
      expires_at: new Date(`${date}T23:59:59Z`),
    });
  }

  // Quest 4: You or Me
  const youOrMeSession = await generateYouOrMeSession(coupleId);
  quests.push({
    couple_id: coupleId,
    date,
    quest_type: 'you_or_me',
    content_id: youOrMeSession.id,
    sort_order: 3,
    is_side_quest: false,
    metadata: { formatType: 'you_or_me' },
    expires_at: new Date(`${date}T23:59:59Z`),
  });

  return quests;
}
```

### Example: Love Points Sync

```typescript
// app/api/sync/love-points/route.ts

export async function POST(req: NextRequest) {
  const supabase = createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const { awards, last_sync_timestamp } = await req.json();

  // Get user's couple
  const { data: couple } = await supabase
    .from('couples')
    .select('id')
    .or(`user1_id.eq.${user.id},user2_id.eq.${user.id}`)
    .single();

  if (!couple) {
    return NextResponse.json({ error: 'No couple found' }, { status: 404 });
  }

  // 1. Insert new awards from client (idempotent with client-generated UUIDs)
  if (awards && awards.length > 0) {
    const awardsToInsert = awards.map((award: any) => ({
      id: award.id, // Client-generated UUID
      couple_id: couple.id,
      amount: award.amount,
      reason: award.reason,
      related_id: award.related_id,
      multiplier: award.multiplier || 1,
    }));

    // Upsert (will skip if ID already exists due to UNIQUE constraint)
    const { error } = await supabase
      .from('love_point_awards')
      .upsert(awardsToInsert, {
        onConflict: 'id',
        ignoreDuplicates: true,
      });
  }

  // 2. Fetch new awards since last sync
  const { data: newAwards } = await supabase
    .from('love_point_awards')
    .select('*')
    .eq('couple_id', couple.id)
    .gt('created_at', last_sync_timestamp || new Date(0).toISOString())
    .order('created_at', { ascending: true });

  // 3. Calculate current totals
  const { data: userPoints } = await supabase
    .from('user_love_points')
    .select('*')
    .eq('user_id', user.id)
    .single();

  return NextResponse.json({
    new_awards: newAwards || [],
    current_total: userPoints?.total_points || 0,
    arena_tier: userPoints?.arena_tier || 1,
    synced_at: new Date().toISOString(),
  });
}
```

### Endpoint Summary

| Endpoint | Method | Purpose | Request | Response |
|----------|--------|---------|---------|----------|
| `/api/sync/daily-quests` | POST | Sync daily quests + completions | `{ date, completions }` | `{ quests, completions }` |
| `/api/sync/love-points` | POST | Sync LP awards | `{ awards, last_sync_timestamp }` | `{ new_awards, current_total }` |
| `/api/sync/memory-flip` | POST | Sync puzzle state + matches | `{ puzzle_id, matches }` | `{ puzzle, cards }` |
| `/api/sync/quiz-session` | POST | Sync quiz answers | `{ session_id, answers }` | `{ session, all_answers }` |
| `/api/sync/you-or-me` | POST | Sync session answers | `{ session_id, answers }` | `{ session, all_answers }` |

---

## Database Connection Strategy

### Connection Pooling Architecture

```typescript
// lib/db/pool.ts
import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import * as schema from './schema';

// Singleton connection pool for all API routes
class ConnectionPool {
  private static instance: ReturnType<typeof drizzle>;
  
  static getInstance() {
    if (!ConnectionPool.instance) {
      // Use Supabase connection pooling URL
      const connectionString = process.env.DATABASE_POOL_URL || 
        'postgresql://postgres.abc123:password@aws-0-us-east-1.pooler.supabase.com:5432/postgres';
      
      // Configure connection pooling
      const pg = postgres(connectionString, {
        max: 20,        // Max connections in pool
        idle_timeout: 20, // Close idle connections after 20s
        max_lifetime: 60 * 30, // Recycle connections every 30min
        prepare: false,   // Disable prepared statements for pooling efficiency
      });

      ConnectionPool.instance = drizzle(pg, { schema });
    }
    
    return ConnectionPool.instance;
  }
}

// Export singleton instance
export const db = ConnectionPool.getInstance();
```

### API Route Pattern with Pooled Connections

```typescript
// app/api/sync/love-points/route.ts
import { db } from '@/lib/db/pool';
import { validateRequest } from '@/lib/auth-middleware';
import { lovePointAwards, userLovePoints } from '@/lib/db/schema';
import { eq, and, gt } from 'drizzle-orm';

export async function POST(req: NextRequest) {
  const authResult = await validateRequest(req);
  if (authResult instanceof NextResponse) return authResult;
  
  const { userId } = authResult;
  const { awards, last_sync_timestamp } = await req.json();

  try {
    // Use pooled connection - no DB open/close per request
    const userLP = await db.select()
      .from(userLovePoints)
      .where(eq(userLovePoints.user_id, userId))
      .limit(1);

    const newAwards = await db.select()
      .from(lovePointAwards)
      .where(and(
        eq(lovePointAwards.couple_id, coupleId),
        gt(lovePointAwards.created_at, last_sync_timestamp)
      ))
      .orderBy(lovePointAwards.created_at)
      .limit(50);

    return NextResponse.json({
      new_awards: newAwards,
      current_total: userLP[0]?.total_points || 0,
    });

  } catch (error) {
    console.error('LP sync error:', error);
    return NextResponse.json({ error: 'Sync failed' }, { status: 500 });
  }
}
```

### Connection Pool Monitoring

```typescript
// lib/db/monitor.ts
export class ConnectionMonitor {
  static async getPoolStats() {
    const pool = ConnectionPool.getInstance() as any;
    return {
      totalConnections: pool.$client.totalCount || 0,
      idleConnections: pool.$client.idleCount || 0,
      waitingRequests: pool.$client.waitingCount || 0,
    };
  }

  static async healthCheck() {
    try {
      await db.select().from(userLovePoints).limit(1);
      return { status: 'healthy' };
    } catch (error) {
      return { status: 'unhealthy', error: error.message };
    }
  }
}

// Add to health endpoint
// app/api/health/route.ts
export async function GET() {
  const poolStats = await ConnectionMonitor.getPoolStats();
  const dbHealth = await ConnectionMonitor.healthCheck();
  
  return NextResponse.json({
    status: 'ok',
    database: dbHealth,
    connections: poolStats,
    timestamp: new Date().toISOString(),
  });
}
```

## Cold Start Mitigation Strategies

### 1. Supabase Edge Functions for Critical Paths

```typescript
// Supabase Edge Functions for time-sensitive operations
// supabase/functions/quest-generation/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  // Edge functions have persistent connections
  // No cold start latency for quest generation
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  const { coupleId, date } = await req.json();
  const quests = await generateQuests(coupleId, date, supabase);
  
  return new Response(JSON.stringify({ quests }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
```

### 2. Warming Strategy

```typescript
// lib/warmup.ts
export class ServerWarmup {
  static timer: NodeJS.Timeout;
  
  static start(intervalMinutes: number = 5) {
    // Send request every 5 minutes to keep serverless warm
    this.timer = setInterval(async () => {
      try {
        await fetch(`${process.env.NEXT_PUBLIC_BASE_URL}/api/health`);
      } catch (error) {
        // Ignore failed warmup attempts
      }
    }, intervalMinutes * 60 * 1000);
  }
  
  static stop() {
    if (this.timer) clearInterval(this.timer);
  }
}

// Enable in app/layout.tsx
// ServerWarmup.start(5);
```

---

## Offline-First Implementation

### Sync Queue Service (Flutter)

```dart
// lib/services/sync_queue_service.dart

class SyncQueueService {
  final _storage = StorageService();
  final _httpClient = HttpClient();

  // Singleton
  static final SyncQueueService _instance = SyncQueueService._internal();
  factory SyncQueueService() => _instance;
  SyncQueueService._internal();

  // Sync queue processing state
  bool _isProcessing = false;
  Timer? _retryTimer;

  /// Queue a sync operation
  Future<void> queueSync(SyncOperation op) async {
    await _storage.addToSyncQueue(op);
    Logger.debug('Queued sync: ${op.type}', service: 'sync');

    // Trigger immediate processing (fire and forget)
    _processSyncQueue();
  }

  /// Process pending sync operations
  Future<void> _processSyncQueue() async {
    if (_isProcessing) return; // Already processing
    if (!await _isOnline()) return; // Offline, will retry later

    _isProcessing = true;

    try {
      final pending = await _storage.getPendingSyncs();
      Logger.debug('Processing ${pending.length} pending syncs', service: 'sync');

      for (final op in pending) {
        try {
          // Attempt sync
          await _syncToServer(op);

          // Mark as complete
          await _storage.markSyncComplete(op.id);
          Logger.success('Synced: ${op.type}', service: 'sync');

        } catch (e) {
          // Increment retry count
          await _storage.incrementRetryCount(op.id);

          final retryCount = await _storage.getRetryCount(op.id);
          final backoffSeconds = _calculateBackoff(retryCount);

          Logger.warn(
            'Sync failed (retry $retryCount in ${backoffSeconds}s): ${op.type}',
            service: 'sync',
          );

          // Schedule retry with exponential backoff
          _scheduleRetry(backoffSeconds);
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Sync operation to server
  Future<void> _syncToServer(SyncOperation op) async {
    switch (op.type) {
      case 'daily_quests':
        await _syncDailyQuests(op.data);
        break;
      case 'love_points':
        await _syncLovePoints(op.data);
        break;
      case 'quest_completion':
        await _syncQuestCompletion(op.data);
        break;
      // ... other sync types
    }
  }

  /// Calculate exponential backoff
  int _calculateBackoff(int retryCount) {
    // 5s, 10s, 20s, 40s, 80s, max 120s
    return min(5 * pow(2, retryCount).toInt(), 120);
  }

  /// Schedule retry with backoff
  void _scheduleRetry(int seconds) {
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: seconds), () {
      _processSyncQueue();
    });
  }

  /// Check network connectivity
  Future<bool> _isOnline() async {
    final result = await InternetAddress.lookup('example.com');
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  }

  /// Sync daily quests
  Future<void> _syncDailyQuests(Map<String, dynamic> data) async {
    final response = await _httpClient.post(
      '/api/sync/daily-quests',
      body: data,
    );

    // Update local storage with server state
    final serverQuests = response['quests'] as List;
    final serverCompletions = response['completions'] as Map;

    // Merge server state into Hive
    await _mergeDailyQuests(serverQuests, serverCompletions);
  }
}
```

### Sync Flow Example: Quest Completion

```dart
// User completes quest - instant UI update, background sync

### Flutter Auth Client Implementation

```dart
// lib/services/auth_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final _storage = FlutterSecureStorage();
  final _baseUrl = 'https://your-app.vercel.app/api';

  String? _accessToken;
  String? _refreshToken;

  // Store tokens after Supabase auth
  Future<void> storeSession(Map<String, dynamic> session) async {
    _accessToken = session['access_token'];
    _refreshToken = session['refresh_token'];
    
    await _storage.write(key: 'access_token', value: _accessToken);
    await _storage.write(key: 'refresh_token', value: _refreshToken);
  }

  // Get current access token (with refresh if needed)
  Future<String?> getAccessToken() async {
    if (_accessToken == null) {
      _accessToken = await _storage.read(key: 'access_token');
      _refreshToken = await _storage.read(key: 'refresh_token');
    }

    // Check if token needs refresh
    if (_accessToken != null && _isTokenExpired(_accessToken!)) {
      await _refreshToken();
    }

    return _accessToken;
  }

  // Helper: Create authenticated HTTP request
  Future<http.Response> authenticatedRequest(String endpoint, Map<String, dynamic> body) async {
    final token = await getAccessToken();
    if (token == null) {
      throw AuthException('Not authenticated');
    }

    return await http.post(
      Uri.parse('$_baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
  }

  // Refresh access token
  Future<void> _refreshToken() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) throw AuthException('No refresh token');

    final response = await http.post(
      Uri.parse('$_baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await storeSession(data);
    } else {
      throw AuthException('Token refresh failed');
    }
  }
}
```

### Updated Sync Flow Example: Quest Completion

```dart
Future<void> completeQuest(String questId) async {
  final quest = await _storage.getDailyQuest(questId);
  final user = _storage.getUser()!;

  // 1. Optimistic update (instant UI feedback)
  quest.markCompleted(user.id);
  await _storage.updateDailyQuest(quest);

  // Trigger UI rebuild
  setState(() {});

  // 2. Queue sync operation (background) - now with JWT auth
  await SyncQueueService().queueSync(SyncOperation(
    id: Uuid().v4(),
    type: 'quest_completion',
    endpoint: '/sync/daily-quests',
    data: {
      'date': DateTime.now().toIso8601String().split('T')[0],
      'completions': {
        questId: {
          'user_id': user.id,
          'completed_at': DateTime.now().toIso8601String(),
        }
      }
    },
    createdAt: DateTime.now(),
    retryCount: 0,
  ));

  // 3. Sync runs in background with authenticated requests
  //    - AuthService adds Bearer token to all requests
  //    - Server validates JWT and extracts user_id
  //    - Server updates database using user_id from JWT
  //    - Server returns full state (including partner's completions)
  //    - Client merges server state into Hive
  //    - UI updates if partner also completed
}
```

### Adaptive Polling & Push Strategy

```dart
// lib/services/adaptive_sync_service.dart

class AdaptiveSyncService {
  Timer? _pollTimer;
  Duration _currentInterval = Duration(seconds: 30);
  int _consecutiveEmptyPolls = 0;
  DateTime? _lastActivityTime;
  bool _isHighPriorityMode = false;

  void startAdaptivePolling() {
    _scheduleNextPoll();
  }

  void _scheduleNextPoll() {
    _pollTimer?.cancel();
    
    // Adaptive interval based on activity and usage patterns
    final interval = _calculateOptimalInterval();
    
    _pollTimer = Timer(interval, () async {
      await _performScheduledSync();
      _scheduleNextPoll(); // Schedule next with updated interval
    });
  }

  Duration _calculateOptimalInterval() {
    final now = DateTime.now();
    final timeSinceActivity = _lastActivityTime != null 
      ? now.difference(_lastActivityTime!) 
      : Duration(hours: 1);

    // High priority mode (user just interacted)
    if (_isHighPriorityMode || timeSinceActivity < Duration(minutes: 2)) {
      _isHighPriorityMode = false; // Reset after using
      return Duration(seconds: 10);
    }

    // Recently active (last 10 minutes) - fast polling
    if (timeSinceActivity < Duration(minutes: 10)) {
      return Duration(seconds: 20);
    }

    // Moderate activity (last hour) - normal polling
    if (timeSinceActivity < Duration(hours: 1)) {
      return Duration(seconds: 45);
    }

    // Low activity (few hours) - slow polling
    if (timeSinceActivity < Duration(hours: 4)) {
      return Duration(minutes: 2);
    }

    // Very low activity (long time) - very slow polling
    return Duration(minutes: 5);
  }

  Future<void> _performScheduledSync() async {
    try {
      // Check server hint for polling frequency
      final serverHint = await _getServerSyncHint();
      
      // Adjust based on server response
      switch (serverHint.nextSyncIn) {
        case 'immediate':
          _currentInterval = Duration(seconds: 5);
          break;
        case 'fast':
          _currentInterval = Duration(seconds: 15);
          break;
        case 'normal':
          _currentInterval = Duration(seconds: 30);
          break;
        case 'slow':
          _currentInterval = Duration(minutes: 1);
          break;
      }

      // Perform sync
      final results = await _syncAll();
      
      // Track consecutive empty responses to slow down
      if (results.every((r) => r.hasNewData == false)) {
        _consecutiveEmptyPolls++;
        if (_consecutiveEmptyPolls >= 10) {
          _currentInterval = Duration(
            seconds: (_currentInterval.inSeconds * 1.5).round()
          ).clamp(Duration(seconds: 10), Duration(minutes: 5));
        }
      } else {
        _consecutiveEmptyPolls = 0;
        // Speed up when there's new data
        _currentInterval = Duration(seconds: 15);
      }

    } catch (error) {
      // On network errors, back off exponentially
      _currentInterval = Duration(
        seconds: (_currentInterval.inSeconds * 1.5).round()
      ).clamp(Duration(seconds: 30), Duration(minutes: 10));
    }
  }

  // Trigger fast polling after user actions
  void triggerHighPrioritySync() {
    _isHighPriorityMode = true;
    _lastActivityTime = DateTime.now();
    _scheduleNextPoll();
  }

  Future<SyncHint> _getServerSyncHint() async {
    try {
      final response = await AuthService.instance.authenticatedRequest(
        '/sync/hint', 
        {}
      );
      
      return SyncHint.fromJson(jsonDecode(response.body));
    } catch (e) {
      return SyncHint(nextSyncIn: 'normal'); // Fallback
    }
  }
}
```

### Server-Side Sync Hints API

```typescript
// app/api/sync/hint/route.ts
export async function POST(req: NextRequest) {
  const authResult = await validateRequest(req);
  if (authResult instanceof NextResponse) return authResult;
  
  const { userId } = authResult;

  // Check for pending changes that need immediate sync
  const couple = await getCoupleForUser(userId);
  
  // Check if partner has recent activity
  const partnerActivity = await db.query.questCompletions.findFirst({
    where: and(
      eq('user_id', couple.partner_id),
      gte('completed_at', new Date(Date.now() - 5 * 60 * 1000)) // Last 5 min
    )
  });

  // Check for new LP awards
  const newLP = await db.query.lovePointAwards.findFirst({
    where: and(
      eq('couple_id', couple.id),
      gte('created_at', new Date(Date.now() - 2 * 60 * 1000)) // Last 2 min
    )
  });

  // Return hint based on activity
  let nextSyncIn: 'immediate' | 'fast' | 'normal' = 'normal';
  if (partnerActivity || newLP) {
    nextSyncIn = 'fast'; // 15 seconds
  }

  // Check time of day - slower polling overnight
  const hour = new Date().getHours();
  if (hour >= 1 && hour <= 6) {
    nextSyncIn = 'slow'; // 1 minute
  }

  return NextResponse.json({
    nextSyncIn,
    partnerActivity: !!partnerActivity,
    newLP: !!newLP,
  });
}
```

### Push Notification Integration

```dart
// lib/services/push_sync_service.dart
class PushSyncService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  void initializePushSync() {
    // Handle push notifications that trigger immediate sync
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['type'] == 'sync_trigger') {
        _handlePushSync(message.data);
      }
    });

    // Handle push when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data['type'] == 'sync_trigger') {
        _handlePushSync(message.data);
      }
    });
  }

  Future<void> _handlePushSync(Map<String, dynamic> data) async {
    final syncType = data['syncType']; // 'quest_completion', 'lp_award', etc.
    
    switch (syncType) {
      case 'quest_completion':
        await _syncDailyQuests();
        break;
      case 'lp_award':
        await _syncLovePoints();
        break;
      case 'all':
        await _syncAllFeatures();
        break;
    }

    // Show notification to user
    _showSyncNotification(data['title'], data['body']);
  }
}
```

### Server-Side Push Triggers

```typescript
// lib/push-trigger.ts
export class PushTriggerService {
  static async triggerSyncForCouple(
    coupleId: string, 
    triggerType: 'quest_completion' | 'lp_award' | 'memory_flip'
  ) {
    // Get partner's FCM tokens
    const couple = await db.query.couples.findFirst({
      where: eq('id', coupleId)
    });

    if (!couple) return;

    // Send push notification to partner
    await this.sendPushNotification({
      to: couple.partner_fcm_token,
      data: {
        type: 'sync_trigger',
        syncType: triggerType,
        coupleId,
      },
      notification: {
        title: this.getNotificationTitle(triggerType),
        body: this.getNotificationBody(triggerType),
      }
    });
  }

  static getNotificationTitle(type: string): string {
    switch (type) {
      case 'quest_completion':
        return 'New Quest Complete!';
      case 'lp_award':
        return 'Love Points Awarded!';
      case 'memory_flip':
        return 'Memory Game Updated!';
      default:
        return 'TogetherRemind Update';
    }
  }

  static getNotificationBody(type: string): string {
    switch (type) {
      case 'quest_completion':
        return 'Your partner completed a quest!';
      case 'lp_award':
        return 'You earned Love Points!';
      case 'memory_flip':
        return 'Memory puzzle has new matches!';
      default:
        return 'Something new happened!';
    }
  }
}

// Integrate with sync endpoints
// In love-points sync route:
await PushTriggerService.triggerSyncForCouple(couple.id, 'lp_award');
```
```

---

## Migration Roadmap

## Updated Timeline: 10-12 Weeks (Realistic)

### Phase 1: Infrastructure & Authentication (3 weeks)

**Week 1: Foundational Setup**
- [ ] Create Vercel project, deploy Next.js boilerplate
- [ ] Create Supabase project, set up PostgreSQL database
- [ ] Run migration SQL to create all tables with proper indexes
- [ ] Set up connection pooling (PgBouncer/Drizzle ORM)
- [ ] Configure environment variables and secrets
- [ ] Setup monitoring & alerting (Sentry, health endpoints)

**Week 2: Authentication System**
- [ ] Implement Supabase Auth integration
- [ ] Build JWT validation middleware for Next.js API
- [ ] Create Flutter auth service with secure token storage
- [ ] Build token refresh mechanism
- [ ] Add auth error handling and recovery
- [ ] Test auth flow across multiple devices

**Week 3: Pilot Feature (Daily Quests)**
- [ ] Build `/api/sync/daily-quests` endpoint with pooled DB connections
- [ ] Implement server-side quest generation
- [ ] Build adaptive sync queue service in Flutter
- [ ] Add sync hints API for adaptive polling
- [ ] Implement push notification triggers
- [ ] End-to-end testing with offline/online scenarios

**Milestone Checks:**
- ✅ Authentication flow working (JWT validation, token refresh)
- ✅ Database connection pooling stable (no connection leaks)
- ✅ Daily Quests working via new API with adaptive polling
- ✅ Monitoring and alerting operational

### Phase 2: Dual-Write System & Data Validation (2 weeks)

**Week 4: Dual-Write Implementation**
- [ ] Implement dual-write: Write to both RTDB and new API simultaneously
- [ ] Add data comparison service (RTDB vs API consistency checker)
- [ ] Build detailed sync logging and error tracking
- [ ] Add rollback mechanism to dual-write mode
- [ ] Create data validation dashboard
- [ ] Load testing with 1K+ simulated couples

**Week 5: Data Consistency Validation**
- [ ] Run dual-write for 7 days with 100% test accounts
- [ ] Automated consistency checks between RTDB and PostgreSQL
- [ ] Address any discovered drift or sync issues
- [ ] Performance testing of adaptive polling vs fixed polling
- [ ] Battery usage testing on real devices
- [ ] Network resilience testing (poor connectivity scenarios)

**Milestone Checks:**
- ✅ Zero data loss in dual-write mode for 48+ hours
- ✅ Performance metrics within targets (API latency < 200ms)
- ✅ Battery usage acceptable (adaptive polling reduces usage by 40%+)
- ✅ All edge cases handled (token expiry, network failures)

### Phase 3: Authentication Migration (2 weeks)

**Week 6: Account Migration Strategy**
- [ ] Build anonymous account migration flow
- [ ] Create email enrollment system (optional, with skip option)
- [ ] Implement magic link authentication for existing users
- [ ] Build account recovery mechanism
- [ ] Add multi-device support for migrated accounts
- [ ] Create migration monitoring dashboard

**Week 7: Authentication Rollout**
- [ ] Test migration flow with 100 beta users
- [ ] Monitor authentication success rates
- [ ] Fix any migration issues discovered
- [ ] Create user communication plan for migration
- [ ] Prepare rollback to anonymous access if needed
- [ ] Document authentication flow for support team

**Rollout Strategy:**
1. **Day 1-3: 5% migration**
   - Enable migration prompt for 5% of users
   - Monitor migration completion rates (>80% success)
   - Support team on standby for migration issues

2. **Day 4-7: 20% migration**
   - Increase migration prompt to 20% of users
   - Monitor authentication error rates (<2%)
   - Collect user feedback on migration experience

3. **Day 8-10: 100% migration**
   - Enable migration for all users
   - Maintain anonymous access for users who decline migration
   - Monitor overall auth metrics

**Milestone Checks:**
- ✅ >95% of users successfully migrated to Supabase Auth
- ✅ Authentication error rate < 1% for new system
- ✅ No regressions in user onboarding flow

### Phase 4: Feature Migration (3 weeks)

**Week 8: Love Points & Gamification**
- [ ] Build `/api/sync/love-points` endpoint
- [ ] Migrate LP awards system with deduplication
- [ ] Update LP calculation logic to server-side
- [ ] Test LP award accuracy across scenarios
- [ ] Implement push notifications for LP awards
- [ ] Dual-write testing for LP system

**Week 9: Games & Interactive Features**
- [ ] Build `/api/sync/memory-flip` endpoint
- [ ] Implement deterministic puzzle generation
- [ ] Build `/api/sync/quiz-session` endpoint
- [ ] Migrate You or Me game system
- [ ] Test all games with dual-write enabled
- [ ] Verify cross-device sync for all games

**Week 10: Comprehensive Testing**
- [ ] Load testing with 10K+ simulated couples
- [ ] Full system integration testing
- [ ] Performance optimization (query tuning, connection pooling)
- [ ] Security audit of authentication and data access
- [ ] Backup and disaster recovery testing

### Phase 5: Production Cutover (2 weeks)

**Week 11: Gradual API Migration**
- [ ] 10% production users on new API (with read-only backup from RTDB)
- [ ] 25% production users on new API
- [ ] 50% production users on new API
- [ ] 75% production users on new API
- [ ] Monitor at each stage (error rates, latency, user complaints)
- [ ] Maintain ability to rollback to RTDB at any point

**Week 12: Full Migration & Cleanup**
- [ ] 100% of users on new API
- [ ] Disable RTDB writes (keep for 7 days as emergency rollback)
- [ ] Final data validation between systems
- [ ] Remove RTDB code from Flutter app
- [ ] Document final architecture and operations
- [ ] Archive RTDB data (30-day retention)

### Phase 6: Post-Migration Optimization (Optional, Week 13+)

**Week 13+: Performance & Scalability**
- [ ] Analyze production performance metrics
- [ ] Optimize database queries and indexes based on real usage
- [ ] Implement additional caching layers if needed
- [ ] Add comprehensive monitoring dashboards
- [ ] Document operational procedures

## Critical Success Factors

### Stage Gates & Rollback Criteria

**Before progressing from each phase:**
1. **Data Integrity:** 100% consistency between old and new systems
2. **Performance:** API latency < 200ms (p95), error rate < 1%
3. **User Experience:** No user complaints about sync or authentication
4. **Monitoring:** All health checks green, alerts configured

**Rollback Triggers:**
- >1% sync failures across 1-hour window
- Authentication error rate >2%
- User complaint spike (>5 complaints per day)
- Database performance degradation (query latency > 500ms)

### Resource Allocation

**Team Composition:**
- 1 Backend Developer (Next.js/PostgreSQL/Supabase)
- 1 Frontend Developer (Flutter/Mobile)
- 1 DevOps Engineer (Monitoring/Infrastructure)
- 1 QA Engineer (Testing/Validation)
- 1 Project Manager (Coordination/Rollouts)

**Contingency Buffers:**
- 2 weeks buffer built into timeline for unexpected issues
- Rollback procedures documented for each phase
- Hotfix process for critical production issues

### Risk Mitigation

**Technical Risks:**
- Connection pool exhaustion → Monitoring + auto-scaling
- Authentication migration friction → Optional migration + rollback
- Data sync inconsistencies → Dual-write validation period
- Performance degradation → Load testing before each rollout

**Operational Risks:**
- User resistance to auth changes → Gradual migration + clear communication
- Extended downtime during cutover → Blue-green deployment approach
- Team capacity constraints → External contingency for critical issues

## Timeline Summary

| Phase | Duration | Key Deliverables | Risk Level |
|-------|----------|------------------|------------|
| Phase 1: Infrastructure | 3 weeks | Auth + API + Monitoring | Medium |
| Phase 2: Dual-Write | 2 weeks | Data consistency validation | Low |
| Phase 3: Auth Migration | 2 weeks | 95%+ users migrated | Medium |
| Phase 4: Feature Migration | 3 weeks | All features on new API | Medium |
| Phase 5: Production Cutover | 2 weeks | 100% users migrated | Low |
| **Total** | **12 weeks** | **Complete migration** | **Medium** |

The original "~1 month" timeline was unrealistic. This 12-week plan includes proper buffers, validation phases, and rollback capabilities to ensure a successful, low-risk migration.

---

## Feature-Specific Strategies

### Daily Quests

**Current:** Client-side generation with "first device creates" pattern
**New:** Server-side generation with database UNIQUE constraint

**Migration:**
- Server generates quests on first request of the day
- Client calls `/api/sync/daily-quests` with date
- Server checks database, generates if not exists
- No race condition (database constraint handles conflicts)

### Love Points

**Current:** Firebase child key deduplication with `onChildAdded` listener
**New:** Server-side deduplication with `related_id` UNIQUE constraint

**Migration:**
- Client generates UUID for award, includes `related_id` (quest ID)
- Server inserts with `ON CONFLICT (couple_id, related_id) DO NOTHING`
- Client polls for new awards since `last_sync_timestamp`

**Benefits:**
- ✅ No duplicate listeners bug
- ✅ Server enforces deduplication
- ✅ Simpler client code

### Memory Flip

**Current:** First device generates, second device loads from Firebase
**New:** Server-side generation with database UNIQUE constraint on (couple_id, date)

**Migration:**
- Client requests puzzle for date
- Server generates if not exists (guaranteed unique by database)
- Client syncs matches back to server
- Server merges match state

### Quiz Sessions & You or Me

**Current:** Client creates session, syncs to Firebase
**New:** Client requests session generation from server

**Migration:**
- Server generates quiz questions, stores in database
- Client fetches session, plays locally
- Client syncs answers to server
- Server calculates results

---

## Security Model

### Authentication Flow

**Old (RTDB):**
```
User opens app → FCM token generated → Token is user identity → No login
```

**New (Supabase Auth + Next.js API):**
```
User opens app → Sign in with magic link/OAuth → Supabase session → 
                    ↓
           JWT access_token + refresh_token
                    ↓
   Flutter stores tokens in secure storage (Flutter Secure Storage)
                    ↓
   API calls include: Authorization: Bearer <access_token>
                    ↓
   Next.js API validates JWT using Supabase JWT verification
                    ↓
   API extracts user_id from JWT for database operations
```

**Migration:**
1. Add auth screen (only shown to new users)
2. Existing users: Auto-create account with email prompt
3. Send magic link → User clicks → Account created
4. Couple pairing: Send invite link, partner signs up and accepts

### Couple Pairing Flow

**Old:**
```
Alice: Generate QR with FCM token
Bob: Scan QR, save Alice's FCM token
Bob: Send pairing confirmation with Bob's FCM token
```

**New:**
```
Alice: Create invite (generates UUID invite code)
Server: Creates row in couple_invites table
Alice: Generate QR with invite URL
Bob: Scan QR, opens app with invite code
Bob: Signs in/up with Supabase Auth
Server: Creates couple relationship (alice.id, bob.id)
```

### Row Level Security

**All tables protected by RLS:**

```sql
-- Example: Users can only see their couple's data
CREATE POLICY couple_data ON daily_quests
  FOR ALL USING (
    couple_id IN (
      SELECT id FROM couples
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );
```

**Benefits:**
- ✅ Database enforces security (not client)
- ✅ Impossible to access other couples' data
- ✅ Works even if client code has bugs

---

## Conflict Resolution

### Quest Completions

**Scenario:** Both devices complete quest offline, sync later

**Resolution:** Last-write-wins with earliest timestamp

```sql
INSERT INTO quest_completions (quest_id, user_id, completed_at)
VALUES ($1, $2, $3)
ON CONFLICT (quest_id, user_id) DO UPDATE
  SET completed_at = LEAST(EXCLUDED.completed_at, quest_completions.completed_at);
```

### LP Awards

**Scenario:** Both devices award LP for same quest

**Resolution:** Server deduplicates via `related_id`

```sql
INSERT INTO love_point_awards (id, couple_id, related_id, amount, reason)
VALUES ($1, $2, $3, $4, $5)
ON CONFLICT (couple_id, related_id) DO NOTHING;
```

### Memory Flip Matches

**Scenario:** Both devices match same pair offline

**Resolution:** First write wins (database update)

```typescript
// Server checks: Are these cards already matched?
const cards = await db.query('SELECT status FROM cards WHERE id IN ($1, $2)');

if (cards.every(c => c.status === 'hidden')) {
  // Not matched yet, update
  await db.update('cards')
    .set({ status: 'matched', matched_by: userId })
    .where({ id: [card1, card2] });
  return { success: true, matched_by: userId };
} else {
  // Already matched by partner
  return { success: false, matched_by: cards[0].matched_by };
}
```

---

## Concerns & Solutions

### Concern: "What if server is down?"

**Solution:** Offline queue + retry with exponential backoff

- Client queues all operations locally
- Retries with backoff: 5s, 10s, 20s, 40s, 80s, max 120s
- User can continue playing offline
- Sync happens when server is back

### Concern: "What if both devices complete quest offline?"

**Solution:** Server merges both completions (idempotent)

- Both devices queue completion locally
- Both show "completed" optimistically
- When online, both sync to server
- Server accepts both (idempotent INSERT with ON CONFLICT)
- No data loss, no conflicts

### Concern: "Migration complexity?"

**Solution:** Gradual rollout with feature flags

- Dual-write phase catches inconsistencies early
- 10% → 50% → 100% rollout reduces risk
- Can rollback at any stage
- RTDB kept as backup for 7 days

### Concern: "What about real-time features in the future?"

**Solution:** Supabase Realtime (PostgreSQL CDC)

If we ever need real-time, Supabase has it built-in:

```dart
supabase
  .channel('public:quest_completions')
  .on(
    RealtimeListenTypes.postgresChanges,
    ChangeFilter(event: 'INSERT', schema: 'public', table: 'quest_completions'),
    (payload) => handleNewCompletion(payload),
  )
  .subscribe();
```

But for now, 30s polling is sufficient.

### Concern: "Authentication friction?"

**Solution:** Passwordless auth (magic links)

- Email → Receive link → Click → Logged in
- Or: Apple/Google Sign-In (one tap)
- Minimal friction, proper security

### Concern: "Cost at scale?"

**Solution:** Free tiers cover our scale

**Supabase Free Tier:**
- 500 MB database (we use ~90 MB/month for 10K couples)
- 2 GB bandwidth (we use ~900 MB/month)
- 50,000 monthly active users
- **Conclusion: Free tier sufficient up to ~50K couples**

**Vercel Free Tier:**
- 100 GB bandwidth
- 100 GB-Hours serverless execution
- **Conclusion: Free tier sufficient**

---

## Summary

### Why This Migration is Worth It

| Benefit | Impact |
|---------|--------|
| **Bug Prevention** | Eliminates all documented sync issues (see [How This Fixes Known Issues](#how-this-fixes-known-issues)). 11-attempt debugging sessions become impossible. |
| **Security** | Supabase RLS >> RTDB rules. Proper auth >> FCM tokens. |
| **Reliability** | Server-side validation prevents client bugs from corrupting data. |
| **Debuggability** | SQL queries >> RTDB path navigation. |
| **Scalability** | PostgreSQL relational model >> denormalized JSON. |
| **Maintainability** | RESTful endpoints >> Firebase listeners with deduplication hacks. |
| **Cost** | Predictable, free tier sufficient >> Firebase pricing surprises. |

### Issues Fixed from KNOWN_ISSUES.md

The migration **systematically eliminates** all documented bugs:

- ✅ **Duplicate LP Awards (Service Layer)** - Server-side deduplication via `UNIQUE(couple_id, related_id)` constraint
- ✅ **Duplicate LP Awards (Listener Duplication)** - No Firebase listeners (polling model)
- ✅ **Memory Flip Sync Failure (11 attempts)** - Server-side ID generation + database constraints
- ✅ **HealthKit Step Sync Prevention** - Atomic transactions prevent all documented pitfalls

**Root cause eliminated:** Client-side complexity. Server-authoritative architecture makes ID mismatches, race conditions, and duplicate logic impossible.

See [How This Fixes Known Issues](#how-this-fixes-known-issues) for detailed analysis.

### Timeline

- **Week 1:** Infrastructure setup
- **Week 2-3:** Daily Quests pilot feature
- **Week 4:** Dual-write testing + gradual rollout
- **Week 5-7:** Migrate remaining features
- **Total: ~7 weeks** for complete migration

### Risk Assessment

- **Technical Risk:** Low (proven architecture, incremental migration)
- **Data Loss Risk:** Minimal (dual-write phase, RTDB backup)
- **User Impact:** None (seamless migration, feature flags)

### Recommendation

**✅ Proceed with migration.**

The benefits far outweigh the costs. The current RTDB architecture has security vulnerabilities and technical debt. The new architecture is simpler, more secure, and more scalable.

---

## Next Steps

1. **Review this document** with team/stakeholders
2. **Set up infrastructure** (Vercel + Supabase projects)
3. **Run database migration** (create tables, RLS policies)
4. **Implement Daily Quests sync** (pilot feature)
5. **Test thoroughly** with two devices
6. **Begin gradual rollout**

---

## Potential Blind Spots & Risks

This section documents overlooked concerns, edge cases, and challenges that emerged from deep analysis. Addressing these proactively prevents costly surprises during migration.

### 1. Performance & Scalability

#### Database Query Performance at Scale

**Overlooked:**
- Plan assumes PostgreSQL "scales better" without specifics
- No index strategy defined
- No query performance benchmarks

**Risks:**
- At 100K couples: Query to fetch daily quests scans 100K rows
- Leaderboard queries could timeout without proper indexes
- Connection pooling limits (Supabase free tier: 60 connections)

**Mitigation:**
```sql
-- Critical indexes not mentioned in schema
CREATE INDEX idx_daily_quests_lookup ON daily_quests(couple_id, date);
CREATE INDEX idx_quest_completions_lookup ON quest_completions(quest_id, user_id);
CREATE INDEX idx_lp_awards_sync ON love_point_awards(couple_id, created_at DESC);

-- Partial index for active quests only
CREATE INDEX idx_active_quests ON daily_quests(couple_id, date)
  WHERE date >= CURRENT_DATE - INTERVAL '7 days';
```

**Testing required:**
- Load test with 100K couples, 1M quests
- Query performance benchmarks (p50, p95, p99 latency)
- Connection pool exhaustion scenarios

#### Mobile Bandwidth & Battery Impact

**Overlooked:**
- Polling every 30s = 2,880 requests/day per user
- Bandwidth calculation: 2KB response × 2,880 = 5.76 MB/day
- With 10K users: 57.6 GB/day = 1.7 TB/month (not 900 MB!)

**Risks:**
- Users on metered mobile data
- Battery drain from constant network activity
- Vercel bandwidth costs exceed free tier quickly

**Mitigation:**
- **Adaptive polling:** 30s when app active, 5min when backgrounded
- **Exponential backoff:** If no changes for 10 polls, reduce to 2min
- **Batch endpoints:** Single `/api/sync/all` returns all updates
- **Consider Server-Sent Events (SSE):** Keep connection open, server pushes when data changes (lower battery drain than polling)

**Better approach:**
```dart
// Adaptive polling based on app state
Timer _syncTimer;

void _startAdaptivePolling() {
  final interval = _appState == AppLifecycleState.resumed
    ? Duration(seconds: 30)  // Active
    : Duration(minutes: 5);   // Backgrounded

  _syncTimer = Timer.periodic(interval, (_) => _syncAll());
}
```

#### Multi-Region Latency

**Overlooked:**
- Supabase database is single-region (e.g., US East)
- Couple in US + Europe: 200-300ms latency for European user
- Vercel edge functions are global, but database is not

**Risks:**
- Poor UX for international couples
- Timeout errors on slow networks

**Mitigation:**
- **Read replicas:** Supabase paid tier supports read replicas
- **Caching:** Add Redis/Upstash for frequently read data (current daily quests)
- **Edge database:** Consider PlanetScale (multi-region) or Cloudflare D1

**Cost implication:** Read replicas = $25+/month

### 2. Offline Sync Complexity

#### Sync Queue Growth & Ordering

**Overlooked:**
- User offline for a week = queue grows to 20K+ operations
- Hive storage limits for sync queue not defined
- Operation ordering matters (must complete quest before awarding LP)

**Risks:**
- Sync queue fills device storage
- Out-of-order sync corrupts data (LP awarded before quest marked complete)
- App crashes with massive sync queue

**Mitigation:**
```dart
// Priority-based queue with size limits
class SyncQueue {
  static const MAX_QUEUE_SIZE = 1000;

  enum Priority { critical, normal, low }

  Future<void> queueSync(SyncOperation op) async {
    final queue = await _storage.getSyncQueue();

    // Drop low-priority ops if queue full
    if (queue.length >= MAX_QUEUE_SIZE) {
      queue.removeWhere((op) => op.priority == Priority.low);
    }

    // Sort by timestamp to maintain order
    queue.add(op);
    queue.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    await _storage.saveSyncQueue(queue);
  }
}
```

**Dependencies handling:**
```typescript
// Server validates operation order
if (req.body.type === 'lp_award') {
  const quest = await db.query.dailyQuests.findFirst({
    where: eq('id', req.body.related_id)
  });

  if (quest.status !== 'completed') {
    return res.status(400).json({
      error: 'Cannot award LP for incomplete quest',
      retry_after_completing: quest.id
    });
  }
}
```

#### Network Transition Handling

**Overlooked:**
- WiFi → cellular → offline → WiFi transitions are frequent
- Exponential backoff could delay sync for 2+ minutes during transitions
- iOS kills background network after 30s

**Risks:**
- User completes quest on WiFi, goes offline, comes back online 5min later
- Exponential backoff delays sync, partner doesn't see completion
- iOS backgrounding stops all sync until app reopened

**Mitigation:**
- **Reset backoff on network state change:**
  ```dart
  connectivityStream.listen((result) {
    if (result == ConnectivityResult.mobile || result == ConnectivityResult.wifi) {
      _resetBackoff();  // Network back, retry immediately
      _processSyncQueue();
    }
  });
  ```
- **iOS background fetch:** Register for background app refresh
- **Push notifications wake app:** Server sends silent push when partner acts

### 3. Authentication & Session Management

#### Token Refresh Edge Cases

**Overlooked:**
- Supabase tokens expire after 1 hour
- What if token expires during critical operation (completing quest)?
- Refresh token might fail (network error, revoked)

**Risks:**
- User completes quest, sync fails with 401 Unauthorized
- Optimistic update shown but never synced
- User doesn't realize their action didn't save

**Mitigation:**
```dart
// Automatic token refresh before expiry
class AuthService {
  Timer? _refreshTimer;

  void _scheduleTokenRefresh(Duration expiresIn) {
    // Refresh 5 minutes before expiry
    final refreshAt = expiresIn - Duration(minutes: 5);

    _refreshTimer = Timer(refreshAt, () async {
      try {
        await supabase.auth.refreshSession();
        Logger.info('Token refreshed successfully');
      } catch (e) {
        // Token refresh failed, force re-login
        Logger.error('Token refresh failed', error: e);
        await _handleAuthFailure();
      }
    });
  }
}

// Retry with token refresh on 401
Future<Response> _apiCall(Request req) async {
  var response = await http.post(req);

  if (response.statusCode == 401) {
    // Token expired, refresh and retry once
    await supabase.auth.refreshSession();
    response = await http.post(req);
  }

  return response;
}
```

#### Account Migration for Existing Users

**Overlooked:**
- Current users have no accounts (just FCM tokens)
- How do we migrate them to Supabase Auth?
- Can't force email input (friction)

**Risks:**
- User updates app, can't access their data (no account)
- Forcing account creation = user churn
- Users with multiple devices need account linking

**Mitigation:**
```dart
// Seamless account creation flow
Future<void> _migrateToAuth() async {
  final currentUser = _storage.getUser();

  if (currentUser != null && currentUser.email == null) {
    // Anonymous account creation (no email required initially)
    final response = await supabase.auth.signInAnonymously();

    // Link anonymous account to device
    await _linkDeviceToAccount(response.user.id);

    // Prompt for email later (optional, for account recovery)
    _showOptionalEmailPrompt();
  }
}
```

**Alternative: Magic link transition:**
```dart
// Show modal: "Secure your account with email"
// Benefits: Multi-device access, account recovery
// Skip button (can do later)
```

### 4. Migration Execution Risks

#### Dual-Write Consistency

**Overlooked:**
- Plan says "write to both RTDB and API"
- What if PostgreSQL write succeeds but RTDB fails (or vice versa)?
- Retry logic could create duplicates

**Risks:**
- Data inconsistency between systems
- Impossible to know which is "source of truth"
- Debug nightmare during migration

**Mitigation:**
```dart
// Write-ahead log pattern
Future<void> _dualWrite(Quest quest) async {
  // 1. Write to local Hive first (source of truth during migration)
  await _storage.saveDailyQuest(quest);

  try {
    // 2. Try new API first (future system)
    await _apiClient.post('/api/sync/daily-quests', quest);

    // 3. If successful, write to RTDB (legacy system)
    await _firebaseDB.child('daily_quests/...').set(quest.toJson());
  } catch (e) {
    // Queue for retry, don't block user
    await _syncQueue.queueRetry('dual_write', quest);
  }
}

// Reconciliation job (runs nightly)
Future<void> _reconcileData() async {
  final rtdbQuests = await _fetchRTDBQuests();
  final apiQuests = await _fetchAPIQuests();

  final discrepancies = _findDiscrepancies(rtdbQuests, apiQuests);

  if (discrepancies.isNotEmpty) {
    Logger.error('Data inconsistency detected: ${discrepancies.length} items');
    // Alert developers, manual review needed
  }
}
```

#### Feature Flag Failure Modes

**Overlooked:**
- 10% → 50% → 100% rollout requires feature flag service
- What if Firebase Remote Config fails to fetch?
- Default to old or new system?

**Risks:**
- Flag service down = all users stuck on one version
- Gradual rollout becomes "all or nothing"
- Can't rollback if issues found

**Mitigation:**
```dart
// Fail-safe feature flag with local cache
class FeatureFlags {
  static const DEFAULT_USE_NEW_API = false; // Safe default

  Future<bool> shouldUseNewAPI() async {
    try {
      // Try remote config
      await FirebaseRemoteConfig.instance.fetchAndActivate();
      final useNewAPI = FirebaseRemoteConfig.instance.getBool('use_new_api');

      // Cache locally
      await _storage.saveFlag('use_new_api', useNewAPI);

      return useNewAPI;
    } catch (e) {
      // Remote config failed, use cached value or default
      Logger.warn('Feature flag fetch failed, using cached value');
      return await _storage.getFlag('use_new_api') ?? DEFAULT_USE_NEW_API;
    }
  }
}
```

**Circuit breaker pattern:**
```dart
// Auto-rollback if error rate spikes
class MigrationCircuitBreaker {
  int _errorCount = 0;
  DateTime _lastReset = DateTime.now();

  Future<void> recordError() async {
    _errorCount++;

    // If 10 errors in 1 minute, auto-rollback
    if (_errorCount > 10 && DateTime.now().difference(_lastReset).inMinutes < 1) {
      Logger.error('Circuit breaker tripped! Auto-rollback to RTDB');
      await FeatureFlags.forceDisableNewAPI();

      // Alert developers
      await _sendAlert('Migration circuit breaker tripped');
    }
  }
}
```

#### Data Migration for Existing Users

**Overlooked:**
- Plan focuses on new data flow
- What about existing couples with years of RTDB data?
- LP history, quiz sessions, completed quests

**Risks:**
- Existing users lose history
- Can't see old quiz results
- LP totals don't match

**Mitigation:**
```typescript
// One-time migration script
// Run BEFORE enabling new API for users

async function migrateExistingUserData(userId: string) {
  // 1. Fetch all RTDB data for user
  const rtdbData = await admin.database()
    .ref(`users/${userId}`)
    .once('value');

  // 2. Transform to PostgreSQL schema
  const pgData = transformRTDBtoPostgres(rtdbData.val());

  // 3. Insert with conflict handling
  await db.insert(users).values(pgData).onConflictDoNothing();

  // 4. Migrate LP transactions
  await migrateLPTransactions(userId);

  // 5. Migrate quiz history (last 30 days only)
  await migrateRecentQuizzes(userId);

  // 6. Mark user as migrated
  await db.insert(migrationStatus).values({
    user_id: userId,
    migrated_at: new Date(),
    rtdb_data_archived: true
  });
}

// Incremental migration (run for 1000 users/day)
async function incrementalMigration() {
  const unmigrated = await getUnmigratedUsers(1000);

  for (const user of unmigrated) {
    try {
      await migrateExistingUserData(user.id);
    } catch (e) {
      Logger.error(`Migration failed for ${user.id}`, e);
      // Continue with others, retry later
    }
  }
}
```

### 5. Operational & Observability Gaps

#### Distributed Tracing

**Overlooked:**
- User action spans: Flutter app → API → Database → back to app
- No way to correlate logs across systems
- Can't trace "why did this quest not sync?"

**Risks:**
- Debugging is guesswork
- Can't find root cause of user issues
- No visibility into end-to-end latency

**Mitigation:**
```dart
// Generate trace ID in Flutter
final traceId = Uuid().v4();

await http.post('/api/sync/quests',
  headers: {'X-Trace-ID': traceId},
  body: data
);

Logger.debug('Quest sync started', metadata: {'trace_id': traceId});
```

```typescript
// Server logs with trace ID
export async function POST(req: Request) {
  const traceId = req.headers.get('X-Trace-ID');

  logger.info('Quest sync request', {
    trace_id: traceId,
    user_id: userId
  });

  try {
    const result = await syncQuests(userId);
    logger.info('Quest sync success', { trace_id: traceId });
    return Response.json(result);
  } catch (e) {
    logger.error('Quest sync failed', {
      trace_id: traceId,
      error: e
    });
    throw e;
  }
}
```

**Recommended tools:**
- Sentry (error tracking with breadcrumbs)
- LogRocket (session replay for web)
- Datadog or Grafana (metrics & traces)

#### Alerting & Monitoring

**Overlooked:**
- No mention of when/how to detect issues
- Silent degradation (sync success rate drops from 99% to 95%)
- Database slow queries not noticed until users complain

**Critical metrics missing:**
```typescript
// Metrics to track
const metrics = {
  // Sync health
  'sync.success_rate': 0.99,        // Alert if < 95%
  'sync.p95_latency': 500,          // Alert if > 1000ms
  'sync.queue_size': 100,           // Alert if > 1000

  // Database health
  'db.connection_pool_usage': 0.7,  // Alert if > 90%
  'db.slow_queries': 5,             // Alert if > 20/min
  'db.size_mb': 450,                // Alert approaching limit

  // API health
  'api.error_rate': 0.01,           // Alert if > 5%
  'api.p99_latency': 1000,          // Alert if > 2000ms

  // Business metrics
  'daily_active_couples': 8500,     // Alert if drops > 20%
  'quest_completion_rate': 0.65,    // Alert if < 50%
};
```

**Alerting setup:**
```typescript
// Example: Vercel + Axiom integration
import { Logger } from 'next-axiom';

export async function POST(req: Request) {
  const log = new Logger();

  try {
    const startTime = Date.now();
    const result = await syncQuests(userId);

    log.info('sync.success', {
      latency: Date.now() - startTime,
      user_id: userId
    });

    return Response.json(result);
  } catch (e) {
    log.error('sync.failed', { error: e, user_id: userId });
    throw e;
  } finally {
    await log.flush();
  }
}

// Axiom alert: If sync.failed > 50 events in 5min, send PagerDuty
```

#### Database Maintenance

**Overlooked:**
- PostgreSQL needs regular maintenance (VACUUM, ANALYZE)
- Indexes fragment over time
- Query plans become stale

**Risks:**
- Database performance degrades gradually
- Queries that were fast become slow
- Connection pool exhaustion during peak

**Mitigation:**
```sql
-- Scheduled maintenance (run nightly during low traffic)

-- 1. Update statistics for query planner
ANALYZE;

-- 2. Reclaim space from deleted rows
VACUUM ANALYZE daily_quests;
VACUUM ANALYZE quest_completions;
VACUUM ANALYZE love_point_awards;

-- 3. Rebuild fragmented indexes (weekly)
REINDEX INDEX idx_daily_quests_lookup;

-- 4. Check for bloat
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

**Supabase provides some automation, but verify:**
- Auto-vacuum is enabled (should be default)
- Statistics collection frequency
- Index maintenance schedule

### 6. Cost Surprises

#### Bandwidth Cost Explosion

**Overlooked:**
- Free tier calculation assumed 900 MB/month
- Reality: HTTP overhead, failed requests, retries = 3-5x
- Actual bandwidth: 3-4.5 GB/month even at 10K users

**Risks:**
- Exceed Vercel free tier (100 GB/month) faster than expected
- Each retry doubles bandwidth
- Image uploads (future feature) = massive bandwidth

**Calculation error in plan:**
```
WRONG: 10K couples × 3KB/day = 30 MB/day = 900 MB/month

RIGHT:
- 10K couples × 2 users = 20K users
- 20K users × 2,880 polls/day = 57.6M requests/month
- 57.6M requests × 2KB response = 115 GB/month (response only)
- Add HTTP headers (~500 bytes) = 144 GB/month
- Add failed requests/retries (10%) = 158 GB/month
- Exceed free tier by 58 GB = $11.60/month in bandwidth
```

**Mitigation:**
- Compression (gzip responses)
- Conditional requests (304 Not Modified)
- Batch endpoints (reduce request count)
- CDN for static data (cached at edge)

#### Database Size Growth

**Overlooked:**
- 500 MB limit fills faster than expected
- Quiz sessions with questions stored as JSONB
- LP transactions accumulate forever
- No data retention policy

**Growth projection:**
```
Per couple per month:
- Daily quests: 30 days × 4 quests × 500 bytes = 60 KB
- Quest completions: 30 × 4 × 2 users × 100 bytes = 24 KB
- LP awards: 30 × 3 awards × 200 bytes = 18 KB
- Quiz sessions: 10 sessions × 5 KB = 50 KB
- You or Me sessions: 5 sessions × 3 KB = 15 KB
Total: ~167 KB/couple/month

10K couples: 1.67 GB/month
500 MB limit exceeded in: ~2 weeks
```

**Mitigation:**
```sql
-- Aggressive data retention policy
DELETE FROM daily_quests WHERE date < CURRENT_DATE - INTERVAL '30 days';
DELETE FROM quest_completions WHERE completed_at < NOW() - INTERVAL '30 days';
DELETE FROM love_point_awards WHERE created_at < NOW() - INTERVAL '90 days';

-- Archive old quiz sessions to cold storage (S3)
-- Keep only session metadata in PostgreSQL
```

**Paid tier required sooner:**
- Free tier: 500 MB
- Pro tier: 8 GB ($25/month)
- Likely need Pro tier at 5K couples, not 50K

### 7. User Experience Edge Cases

#### First-Time Pairing Flow

**Overlooked:**
- Current: Scan QR → Paired instantly
- New: Scan QR → Create account → Pair → Wait for email verification?

**Risks:**
- Onboarding friction increases 5x
- Users drop off before completing pairing
- Email verification required? Adds delay

**Mitigation:**
```dart
// Passwordless pairing (no email required initially)
Future<void> _newPairingFlow() async {
  // 1. Anonymous account creation (instant)
  final user = await supabase.auth.signInAnonymously();

  // 2. Generate invite link
  final inviteCode = generateInviteCode();
  await db.insert(invites).values({
    inviter_id: user.id,
    invite_code: inviteCode,
    expires_at: DateTime.now().add(Duration(minutes: 15))
  });

  // 3. Show QR with invite link
  showQRCode('https://app.togetherremind.com/pair/$inviteCode');

  // 4. Partner scans, creates anonymous account, accepts invite
  // 5. Couple relationship created

  // 6. LATER: Optional email for account recovery
  showDialog('Add email for multi-device support?');
}
```

**Skip email verification:**
- Users can pair without email
- Email only required for:
  - Password reset
  - Multi-device access
  - Account recovery

#### Polling Delay Perception

**Overlooked:**
- 30-second polling = partner sees update in up to 30s
- Current RTDB: ~1-2 seconds
- UX degradation might be noticeable

**Risks:**
- Users complain "app is slow"
- Confusion: "Did my partner see my completion?"
- Negative reviews

**Mitigation:**
1. **Optimistic UI** (already planned)
2. **Push notification supplement:**
   ```dart
   // Send push when partner completes quest
   await sendPushNotification(
     partnerId,
     title: 'Quest completed!',
     body: '${userName} finished "You or Me"'
   );
   ```
3. **Visual feedback:**
   ```dart
   // Show syncing indicator
   'Your completion is syncing...' (0-5s)
   'Waiting for partner...' (5s+)
   ```
4. **Faster polling when action pending:**
   ```dart
   // After user completes quest, poll every 5s for 1 minute
   await _tempFastPolling(duration: Duration(minutes: 1));
   ```

### 8. Testing Gaps

#### Load Testing

**Overlooked:**
- No mention of load testing
- How many concurrent users can API handle?
- Database connection pool limits

**Risks:**
- Launch with 10K users → API crashes
- Database connections exhausted
- Queries timeout under load

**Required tests:**
```bash
# Load test with k6 or Artillery
artillery quick --count 100 --num 50 https://api.togetherremind.com/sync/quests

# Scenarios to test:
# 1. 1000 concurrent users polling
# 2. 500 users completing quests simultaneously
# 3. Database connection pool exhaustion
# 4. Slow query under load (100K quests in DB)
```

#### Chaos Engineering

**Overlooked:**
- What if Supabase goes down for 1 hour?
- What if Vercel has regional outage?
- What if user's token refresh fails?

**Required chaos tests:**
```dart
// Inject failures in test environment
class ChaosMiddleware {
  Future<Response> call(Request req) async {
    if (_shouldInjectFailure()) {
      switch (_randomFailureType()) {
        case FailureType.timeout:
          await Future.delayed(Duration(seconds: 30));
          throw TimeoutException();
        case FailureType.serverError:
          throw HttpException(500);
        case FailureType.unauthorized:
          throw HttpException(401);
        case FailureType.networkError:
          throw SocketException('Network unreachable');
      }
    }

    return await next(req);
  }
}
```

**Scenarios:**
- Database connection timeout
- Token refresh 401
- Sync queue at max capacity
- Network flapping (online/offline/online)

### 9. Compliance & Legal

#### GDPR Data Deletion

**Overlooked:**
- User requests data deletion
- Need to delete from PostgreSQL, Supabase Auth, and any backups
- Cascade deletes might not work as expected

**Risks:**
- GDPR violation if data not fully deleted
- Fines up to 4% of revenue
- Reputation damage

**Mitigation:**
```sql
-- Ensure cascade deletes configured
ALTER TABLE daily_quests
  DROP CONSTRAINT IF EXISTS fk_couple,
  ADD CONSTRAINT fk_couple
    FOREIGN KEY (couple_id)
    REFERENCES couples(id)
    ON DELETE CASCADE;

-- GDPR deletion procedure
CREATE PROCEDURE delete_user_data(user_id_param UUID)
LANGUAGE plpgsql AS $$
BEGIN
  -- 1. Delete from couples (cascades to all related data)
  DELETE FROM couples
  WHERE user1_id = user_id_param OR user2_id = user_id_param;

  -- 2. Delete Supabase auth user
  -- (Must be done via Supabase API, not SQL)

  -- 3. Log deletion for audit
  INSERT INTO deletion_log (user_id, deleted_at, deleted_by)
  VALUES (user_id_param, NOW(), current_user);

  COMMIT;
END;
$$;
```

**Backup retention:**
- Supabase keeps backups for 7 days
- Deleted user data still in backups
- Document in privacy policy

#### Data Residency

**Overlooked:**
- Supabase database region (US East by default)
- GDPR requires EU data stay in EU
- Users in EU + US couple = data in US

**Risks:**
- GDPR violation for EU users
- Requires multi-region setup (expensive)

**Mitigation:**
- Document in privacy policy where data is stored
- For EU users, deploy separate Supabase instance in EU region
- Or: Use PlanetScale (multi-region by default)

### 10. Long-Term Maintenance

#### API Versioning Strategy

**Overlooked:**
- Plan shows `/api/sync/quests` endpoints
- What about v2 API when schema changes?
- How to support old app versions?

**Risks:**
- Breaking changes force users to upgrade
- Old app versions stop working
- Can't iterate API without breaking users

**Mitigation:**
```typescript
// Version in URL
/api/v1/sync/quests  // Current
/api/v2/sync/quests  // Future (breaking changes)

// Or: Version in header
headers: { 'API-Version': '2024-11-18' }

// Support multiple versions for 6 months
if (apiVersion === 'v1') {
  return handleV1Request(req);
} else if (apiVersion === 'v2') {
  return handleV2Request(req);
}
```

**Deprecation strategy:**
```typescript
// Announce deprecation 3 months in advance
if (apiVersion === 'v1') {
  res.headers.set('Deprecation', 'true');
  res.headers.set('Sunset', '2025-03-01');
  res.headers.set('Link', '<https://docs.../migration-guide>; rel="deprecation"');
}

// Force upgrade after sunset date
if (apiVersion === 'v1' && Date.now() > new Date('2025-03-01')) {
  return res.status(410).json({
    error: 'API v1 is deprecated. Please upgrade app.'
  });
}
```

#### Vendor Lock-In (Supabase)

**Overlooked:**
- Moving from Firebase lock-in to Supabase lock-in
- What if Supabase pricing changes 10x?
- What if Supabase shuts down (unlikely but possible)?

**Risks:**
- Expensive migration away from Supabase
- Supabase-specific features (RLS, Auth) not portable
- No exit strategy

**Mitigation:**
```typescript
// Abstract database layer
interface DatabaseAdapter {
  findQuests(coupleId: string, date: string): Promise<Quest[]>;
  insertQuest(quest: Quest): Promise<void>;
  updateQuest(questId: string, updates: Partial<Quest>): Promise<void>;
}

class SupabaseAdapter implements DatabaseAdapter {
  async findQuests(coupleId, date) {
    return await supabase.from('daily_quests')...;
  }
}

class PostgresAdapter implements DatabaseAdapter {
  async findQuests(coupleId, date) {
    return await pg.query('SELECT * FROM daily_quests...');
  }
}

// Swap adapters if needed
const db: DatabaseAdapter = USE_SUPABASE
  ? new SupabaseAdapter()
  : new PostgresAdapter();
```

**Exit strategy:**
- Keep SQL portable (avoid Supabase-specific SQL)
- Abstract RLS behind application logic
- Use Supabase Auth via OIDC (portable to other providers)

---

## Risk Mitigation Summary

### High Priority (Address Before Launch)

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Bandwidth cost explosion** | High (10x cost estimate) | High | Compression, batch endpoints, adaptive polling |
| **Database size exceeded** | High (app breaks) | High | Aggressive retention policy, archive old data |
| **Token refresh failures** | High (users locked out) | Medium | Auto-refresh before expiry, graceful re-auth |
| **Dual-write inconsistency** | High (data corruption) | Medium | Write-ahead log, reconciliation job |
| **Load testing** | High (launch crash) | Medium | Required before production launch |

### Medium Priority (Monitor in Production)

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Multi-region latency** | Medium (poor UX) | Medium | Read replicas, edge caching |
| **Sync queue overflow** | Medium (data loss) | Low | Queue size limits, priority-based drop |
| **Data migration incomplete** | Medium (user confusion) | Medium | Incremental migration, user communication |
| **Observability gaps** | Medium (blind debugging) | High | Distributed tracing, alerting setup |

### Low Priority (Document & Defer)

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **GDPR compliance** | Low (if documented) | Low | Privacy policy, deletion procedure |
| **API versioning** | Low (future problem) | Medium | Version strategy from day 1 |
| **Vendor lock-in** | Low (long-term) | Low | Abstraction layer, portable SQL |

---

**Questions?**
- See `docs/BACKEND_SYNC_ARCHITECTURE.md` for current architecture details
- See `docs/KNOWN_ISSUES.md` for documented bugs this migration fixes (11-attempt debugging sessions and all)

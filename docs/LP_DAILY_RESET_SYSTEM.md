# LP Daily Reset System - Implementation Plan

**Status:** Implemented (Core)
**Created:** 2025-12-17
**Author:** Claude Code

### Implementation Status

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 1: Database & Core Utilities | Complete | Migration 031, grant-service.ts, daily-reset.ts |
| Phase 2: Game Endpoints | Complete | handler.ts, linked, word-search updated |
| Phase 3: Quest Card UI | Complete | Removed +30 LP badge |
| Phase 4: Result Screens | Partial | Models updated, UI pending |
| Phase 5: Documentation | Complete | CLAUDE.md updated |

---

## Overview

This document outlines the implementation plan for changing the Love Points (LP) reward system from per-match awards to a daily-capped system where couples can play unlimited content but only receive LP once per content type per day.

### Goals

1. **Unlimited content access** - Remove artificial gates after match completion
2. **Daily LP cap per content type** - 30 LP max per content type per day per couple
3. **Configurable reset time** - Easy to adjust for development/testing
4. **Clear user feedback** - Show when LP was earned and countdown to reset

### Key Design Decisions

| Question | Decision |
|----------|----------|
| LP tracking level | **Per-couple** (not per-user) |
| When LP awarded | When **both partners complete** match (current behavior) |
| Concurrent matches | **Not allowed** - must complete current match before starting new one |
| Content selection | **Keep current system** - daily quests pick next content in rotation |
| Unlocks vs LP | **Separate** - completion triggers unlocks regardless of LP |
| Multi-day games | LP awarded on **completion day only** |
| LP day calculation | Based on **match completion time** |
| Offline play | **Not supported** |

### Content Types

| Content Type | LP per Day | Notes |
|--------------|------------|-------|
| `classic_quiz` | 30 LP | Daily quiz format |
| `affirmation_quiz` | 30 LP | Affirmation format |
| `you_or_me` | 30 LP | You or Me game |
| `linked` | 30 LP | Crossword puzzle |
| `word_search` | 30 LP | Word search puzzle |
| `steps` | 15-30 LP | **Unchanged** - keeps existing "claim yesterday" pattern |

**Max daily LP:** 150 LP (games) + 15-30 LP (steps) = 165-180 LP

---

## Configuration

### Environment Variables

```env
# api/.env and api/.env.local

# Hour in UTC when daily LP resets (0-23, or negative for previous day)
LP_RESET_HOUR_UTC=0

# Whether to allow unlimited content after LP is earned
# true = can play more content, just won't earn LP again
# false = blocked from new content until reset (original behavior)
LP_ALLOW_UNLIMITED_CONTENT=true
```

### LP Reset Hour

| Value | Reset Time | Equivalent |
|-------|------------|------------|
| `0` | 00:00 UTC | UTC midnight |
| `7` | 07:00 UTC | UTC+7 midnight (Bangkok/Jakarta) |
| `-5` | 19:00 UTC (prev day) | UTC-5 midnight (EST) |
| `12` | 12:00 UTC | UTC+12 midnight (Auckland) |

### Content Access Mode

| `LP_ALLOW_UNLIMITED_CONTENT` | Behavior |
|------------------------------|----------|
| `true` | Users can play unlimited content, LP only awarded once per day |
| `false` | Users blocked from new content after earning LP (must wait for reset) |

**Use `false` to preserve current gated behavior while still using daily LP tracking.**

### How It Works

The "LP day" is calculated by subtracting the reset hour offset from the current UTC time:

```typescript
function getLpDay(timestamp: Date = new Date()): string {
  const resetHour = parseInt(process.env.LP_RESET_HOUR_UTC || '0');
  const adjusted = new Date(timestamp.getTime() - (resetHour * 60 * 60 * 1000));
  return adjusted.toISOString().split('T')[0]; // "2025-12-17"
}

function getTimeUntilReset(): number {
  const resetHour = parseInt(process.env.LP_RESET_HOUR_UTC || '0');
  const now = new Date();
  const nextReset = new Date(now);
  nextReset.setUTCHours(resetHour, 0, 0, 0);
  if (nextReset <= now) {
    nextReset.setUTCDate(nextReset.getUTCDate() + 1);
  }
  return nextReset.getTime() - now.getTime(); // milliseconds
}
```

---

## Database Schema

### New Table: `daily_lp_grants`

Tracks LP grants at the **couple level** (not per-user). This ensures a couple can only earn 30 LP per content type per day, regardless of which partner triggers the completion.

```sql
CREATE TABLE daily_lp_grants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  content_type TEXT NOT NULL,  -- 'classic_quiz', 'affirmation_quiz', 'you_or_me', 'linked', 'word_search'
  lp_day DATE NOT NULL,        -- The "LP day" (adjusted for reset hour)
  lp_amount INT NOT NULL DEFAULT 30,
  match_id TEXT,               -- Optional: reference to the match that triggered this
  granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- One LP grant per couple per content type per day
  UNIQUE(couple_id, content_type, lp_day)
);

-- Index for quick lookups
CREATE INDEX idx_daily_lp_grants_couple_day ON daily_lp_grants(couple_id, lp_day);
```

### Cleanup Strategy

Records are deleted after they've been applied to `couples.total_lp`. Since the unique constraint prevents duplicates, we can safely delete old records:

```sql
-- Run periodically (e.g., daily cron job)
DELETE FROM daily_lp_grants WHERE lp_day < CURRENT_DATE - INTERVAL '7 days';
```

Or delete immediately after grant (simpler, implemented in grant service).

### Migration Script

**File:** `api/scripts/migrations/create_daily_lp_grants.sql`

---

## Architecture

### LP Award Flow (New)

```
Both partners complete match
    │
    ▼
┌─────────────────────────────────────┐
│ Check daily_lp_grants table         │
│ WHERE couple_id = ? AND content_type│
│ = ? AND lp_day = getCurrentLpDay()  │
└──────────────┬──────────────────────┘
               │
       ┌───────┴───────┐
       │               │
       ▼               ▼
┌─────────────┐  ┌─────────────────┐
│ NOT FOUND   │  │ FOUND           │
│ Award 30 LP │  │ Skip LP award   │
│ Insert row  │  │ Return status   │
│ (optional:  │  │                 │
│  delete row │  │                 │
│  after)     │  │                 │
└─────────────┘  └─────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ Return to client:                   │
│ - lpAwarded: true/false             │
│ - lpAmount: 30 or 0                 │
│ - alreadyGrantedToday: true/false   │
│ - resetInMs: milliseconds to reset  │
└─────────────────────────────────────┘
```

### Client UI Flow

```
Game completion → Results screen
    │
    ├─── LP awarded ─────────────────────────┐
    │    Show: "+30 LP" (existing behavior)  │
    │                                        │
    └─── LP already granted today ───────────┤
         Show: "You've already earned LP     │
         for this today.                     │
         Resets in 5h 23min"                 │
                                             │
                                             ▼
                                    [Continue] button
```

### What Stays the Same

- Match creation logic (one active match per content type)
- Content selection (daily quest system picks next in rotation)
- Waiting screens (partner must complete before new match)
- Unlock system (triggers on completion, separate from LP)
- Quest cards on home screen (remove +30 badge, keep COMPLETED text)
- LP polling/fetching (existing system)

---

## Implementation Phases

---

## Phase 1: Database & Core Utilities

**Goal:** Set up database table and shared LP utilities

### 1.1 Create Migration Script

**File:** `api/scripts/migrations/create_daily_lp_grants.sql`

```sql
-- Create daily_lp_grants table
CREATE TABLE IF NOT EXISTS daily_lp_grants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  content_type TEXT NOT NULL,
  lp_day DATE NOT NULL,
  lp_amount INT NOT NULL DEFAULT 30,
  match_id TEXT,
  granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(user_id, content_type, lp_day)
);

CREATE INDEX IF NOT EXISTS idx_daily_lp_grants_user_day ON daily_lp_grants(user_id, lp_day);
CREATE INDEX IF NOT EXISTS idx_daily_lp_grants_couple_day ON daily_lp_grants(couple_id, lp_day);

-- Add comment
COMMENT ON TABLE daily_lp_grants IS 'Tracks daily LP grants per user per content type. LP resets based on LP_RESET_HOUR_UTC env var.';
```

### 1.2 Create LP Day Utility

**File:** `api/lib/lp/daily-reset.ts`

```typescript
/**
 * LP Daily Reset System
 *
 * Handles calculation of "LP days" based on configurable reset hour.
 * LP_RESET_HOUR_UTC env var controls when the daily reset occurs.
 */

export const LP_CONTENT_TYPES = [
  'classic_quiz',
  'affirmation_quiz',
  'you_or_me',
  'linked',
  'word_search',
] as const;

export type LpContentType = typeof LP_CONTENT_TYPES[number];

/**
 * Get the configured LP reset hour (0-23, can be negative for previous day)
 */
export function getLpResetHour(): number {
  return parseInt(process.env.LP_RESET_HOUR_UTC || '0', 10);
}

/**
 * Check if unlimited content is allowed after LP is earned
 * If false, users are blocked from new content until reset
 */
export function isUnlimitedContentAllowed(): boolean {
  return process.env.LP_ALLOW_UNLIMITED_CONTENT !== 'false';
}

/**
 * Get the "LP day" for a given timestamp.
 * The LP day is determined by subtracting the reset hour offset.
 *
 * Example: If LP_RESET_HOUR_UTC=7, then:
 * - 2025-12-17 06:59 UTC → LP day is "2025-12-16"
 * - 2025-12-17 07:00 UTC → LP day is "2025-12-17"
 */
export function getLpDay(timestamp: Date = new Date()): string {
  const resetHour = getLpResetHour();
  const adjusted = new Date(timestamp.getTime() - (resetHour * 60 * 60 * 1000));
  return adjusted.toISOString().split('T')[0];
}

/**
 * Get milliseconds until next LP reset
 */
export function getTimeUntilReset(now: Date = new Date()): number {
  const resetHour = getLpResetHour();
  const nextReset = new Date(now);

  // Set to today's reset time
  nextReset.setUTCHours(resetHour, 0, 0, 0);

  // If we're past today's reset, move to tomorrow
  if (nextReset <= now) {
    nextReset.setUTCDate(nextReset.getUTCDate() + 1);
  }

  return nextReset.getTime() - now.getTime();
}

/**
 * Format milliseconds as "Xh Ymin" string
 */
export function formatTimeUntilReset(ms: number): string {
  const hours = Math.floor(ms / (1000 * 60 * 60));
  const minutes = Math.floor((ms % (1000 * 60 * 60)) / (1000 * 60));

  if (hours > 0) {
    return `${hours}h ${minutes}min`;
  }
  return `${minutes}min`;
}
```

### 1.3 Create LP Grant Service

**File:** `api/lib/lp/grant-service.ts`

```typescript
import { PoolClient } from 'pg';
import { getLpDay, getTimeUntilReset, LpContentType } from './daily-reset';

export interface LpGrantResult {
  granted: boolean;
  lpAmount: number;
  alreadyGrantedToday: boolean;
  resetInMs: number;
  canPlayMore: boolean;  // false if LP_ALLOW_UNLIMITED_CONTENT=false and already earned
}

/**
 * Check if LP was already granted today for a couple + content type
 */
export async function hasLpGrantToday(
  client: PoolClient,
  coupleId: string,
  contentType: LpContentType
): Promise<boolean> {
  const lpDay = getLpDay();

  const result = await client.query(
    `SELECT 1 FROM daily_lp_grants
     WHERE couple_id = $1 AND content_type = $2 AND lp_day = $3`,
    [coupleId, contentType, lpDay]
  );

  return result.rows.length > 0;
}

/**
 * Try to award LP - returns whether it was granted or already claimed today
 *
 * Uses INSERT ... ON CONFLICT to atomically check and grant in one operation.
 * This prevents race conditions if both partners complete simultaneously.
 */
export async function tryAwardDailyLp(
  client: PoolClient,
  coupleId: string,
  contentType: LpContentType,
  matchId?: string
): Promise<LpGrantResult> {
  const lpDay = getLpDay();
  const resetInMs = getTimeUntilReset();
  const unlimitedAllowed = isUnlimitedContentAllowed();

  // Try to insert grant record - will fail silently if already exists
  const insertResult = await client.query(
    `INSERT INTO daily_lp_grants (couple_id, content_type, lp_day, lp_amount, match_id)
     VALUES ($1, $2, $3, 30, $4)
     ON CONFLICT (couple_id, content_type, lp_day) DO NOTHING
     RETURNING id`,
    [coupleId, contentType, lpDay, matchId]
  );

  // If insert succeeded (returned a row), we're the first today - award LP
  if (insertResult.rows.length > 0) {
    await client.query(
      `UPDATE couples SET total_lp = total_lp + 30 WHERE id = $1`,
      [coupleId]
    );

    return {
      granted: true,
      lpAmount: 30,
      alreadyGrantedToday: false,
      resetInMs,
      canPlayMore: unlimitedAllowed,  // Can play more if unlimited mode
    };
  }

  // Insert failed (conflict) - LP already granted today
  return {
    granted: false,
    lpAmount: 0,
    alreadyGrantedToday: true,
    resetInMs,
    canPlayMore: unlimitedAllowed,  // If false, client should block new content
  };
}

/**
 * Check if couple can start new content for a given type
 * Returns false if LP_ALLOW_UNLIMITED_CONTENT=false and LP already earned today
 */
export async function canStartNewContent(
  client: PoolClient,
  coupleId: string,
  contentType: LpContentType
): Promise<{ allowed: boolean; resetInMs: number }> {
  const unlimitedAllowed = isUnlimitedContentAllowed();

  // If unlimited mode, always allow
  if (unlimitedAllowed) {
    return { allowed: true, resetInMs: getTimeUntilReset() };
  }

  // Check if LP was already granted today
  const alreadyGranted = await hasLpGrantToday(client, coupleId, contentType);

  return {
    allowed: !alreadyGranted,
    resetInMs: getTimeUntilReset(),
  };
}

/**
 * Get LP status for all content types for a couple
 */
export async function getLpStatusForCouple(
  client: PoolClient,
  coupleId: string
): Promise<Map<LpContentType, boolean>> {
  const lpDay = getLpDay();

  const result = await client.query(
    `SELECT content_type FROM daily_lp_grants
     WHERE couple_id = $1 AND lp_day = $2`,
    [coupleId, lpDay]
  );

  const grantedTypes = new Map<LpContentType, boolean>();
  for (const row of result.rows) {
    grantedTypes.set(row.content_type as LpContentType, true);
  }

  return grantedTypes;
}
```

### 1.4 Update Environment Files

**File:** `api/.env.example` (add)

```env
# LP Reset Configuration
# Hour in UTC when daily LP resets (0-23, or negative for previous day)
# 0 = midnight UTC, 7 = midnight UTC+7, -5 = midnight EST
LP_RESET_HOUR_UTC=0
```

### Phase 1 Testing

- [ ] Run migration on Supabase
- [ ] Verify table created with correct schema
- [ ] Unit test `getLpDay()` with various reset hours:
  - `LP_RESET_HOUR_UTC=0`: 23:59 UTC → same day, 00:00 UTC → new day
  - `LP_RESET_HOUR_UTC=7`: 06:59 UTC → previous day, 07:00 UTC → new day
- [ ] Unit test `getTimeUntilReset()` returns correct countdown
- [ ] Test `tryAwardDailyLp()` grants on first call, rejects on second

---

## Phase 2: Update Game Endpoints

**Goal:** Modify all game submit endpoints to use daily LP system

### 2.1 Update Quiz Match Submit

**File:** `api/app/api/sync/quiz-match/submit/route.ts`

**Changes:**
1. Import LP grant utilities
2. Determine content type from quiz format (`classic` or `affirmation`)
3. Replace direct LP award with `tryAwardDailyLp()`
4. Return LP status in response

**Key code change:**

```typescript
import { tryAwardDailyLp, LpContentType } from '@/lib/lp/grant-service';
import { getTimeUntilReset } from '@/lib/lp/daily-reset';

// In the completion handler, after both users have answered:

// Determine content type from quiz format
const contentType: LpContentType = match.format_type === 'affirmation'
  ? 'affirmation_quiz'
  : 'classic_quiz';

// Try to award LP (will check if already granted today)
const lpResult = await tryAwardDailyLp(
  client,
  userId,
  coupleId,
  contentType,
  matchId
);

// Return in response
return NextResponse.json({
  success: true,
  // ... existing fields
  lpAwarded: lpResult.granted,
  lpAmount: lpResult.lpAmount,
  alreadyGrantedToday: lpResult.alreadyGrantedToday,
  resetInMs: lpResult.resetInMs,
});
```

### 2.2 Update You or Me Submit

**File:** `api/app/api/sync/you-or-me-match/submit/route.ts`

**Changes:** Same pattern as quiz, with `contentType = 'you_or_me'`

### 2.3 Update Linked Submit

**File:** `api/app/api/sync/linked/submit/route.ts`

**Changes:** Same pattern, with `contentType = 'linked'`

**Note:** Linked has turn-based completion. LP should be awarded when the puzzle is fully solved, not per turn.

### 2.4 Update Word Search Submit

**File:** `api/app/api/sync/word-search/submit/route.ts`

**Changes:** Same pattern, with `contentType = 'word_search'`

### 2.5 Create LP Status Endpoint

**File:** `api/app/api/sync/lp-status/route.ts`

```typescript
import { NextRequest, NextResponse } from 'next/server';
import { pool } from '@/lib/db';
import { getLpStatusForUser } from '@/lib/lp/grant-service';
import { getTimeUntilReset, getLpResetHour } from '@/lib/lp/daily-reset';
import { authenticateRequest } from '@/lib/auth';

export async function GET(req: NextRequest) {
  const authResult = await authenticateRequest(req);
  if (!authResult.success) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const client = await pool.connect();
  try {
    const status = await getLpStatusForUser(client, authResult.userId);

    return NextResponse.json({
      success: true,
      resetInMs: getTimeUntilReset(),
      resetHourUtc: getLpResetHour(),
      contentTypes: status,
    });
  } finally {
    client.release();
  }
}
```

### Phase 2 Testing

- [ ] **Quiz endpoint:** Complete a classic quiz → verify LP granted
- [ ] **Quiz endpoint:** Complete another classic quiz same day → verify LP NOT granted, response shows `alreadyGrantedToday: true`
- [ ] **Quiz endpoint:** Complete affirmation quiz → verify LP granted (different content type)
- [ ] **You or Me endpoint:** Same pattern testing
- [ ] **Linked endpoint:** Complete puzzle → LP granted once
- [ ] **Word Search endpoint:** Complete puzzle → LP granted once
- [ ] **LP Status endpoint:** Returns correct status for all content types
- [ ] **Cross-day test:** Change `LP_RESET_HOUR_UTC`, verify LP grants reset

---

## Phase 3: Quest Card UI Updates

**Goal:** Remove +30 LP badge from quest cards (LP is now conditional)

### 3.1 Review Current Quest Cards

The current quest cards show a "+30" badge. Since LP is now only awarded once per day, this badge could be misleading on subsequent plays.

**Decision:** Remove the +30 badge entirely. The COMPLETED text already shows completion status.

### 3.2 Update Quest Card Widget

**File:** `app/lib/widgets/quest_card.dart` (or wherever the +30 badge is rendered)

**Changes:**
1. Remove the "+30" LP badge from quest cards
2. Keep COMPLETED text/indicator as-is
3. No other changes needed - existing match flow handles everything

### 3.3 Verify Existing Behavior

The current system already:
- Prevents starting new match until current one is complete (keep this)
- Uses daily quest system for content selection (keep this)
- Shows waiting screens (keep this)

**No changes needed to these behaviors.**

### Phase 3 Testing

- [ ] Quest cards no longer show "+30" badge
- [ ] COMPLETED indicator still shows correctly
- [ ] Can still navigate to games from quest cards
- [ ] Match flow unchanged (still requires both partners to complete)

---

## Phase 4: Flutter UI Updates

**Goal:** Update result screens to show "already earned" message when LP not awarded

### 4.1 Update API Response Parsing

All result screens need to parse new fields from submit API responses:

```dart
// New fields in API response
final lpAwarded = response['lpAwarded'] as bool? ?? true;
final alreadyGrantedToday = response['alreadyGrantedToday'] as bool? ?? false;
final resetInMs = response['resetInMs'] as int? ?? 0;
final canPlayMore = response['canPlayMore'] as bool? ?? true;
```

### 4.2 Add "Already Earned" Message Widget

**File:** `app/lib/widgets/lp_already_earned_banner.dart`

```dart
import 'package:flutter/material.dart';
import '../config/brand/brand_loader.dart';
import '../theme/app_theme.dart';

/// Banner shown when LP was already earned today for this content type
class LpAlreadyEarnedBanner extends StatelessWidget {
  final int resetInMs;

  const LpAlreadyEarnedBanner({
    super.key,
    required this.resetInMs,
  });

  String get _resetText {
    final hours = resetInMs ~/ (1000 * 60 * 60);
    final minutes = (resetInMs % (1000 * 60 * 60)) ~/ (1000 * 60);
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '${minutes}min';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: BrandLoader().colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: BrandLoader().colors.borderLight,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            'You\'ve already earned LP for this today.',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 14,
              color: BrandLoader().colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Resets in $_resetText',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 12,
              color: BrandLoader().colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
```

### 4.3 Update Result Screens

Update each result screen to conditionally show the banner:

**Files:**
- `app/lib/screens/quiz_match_results_screen.dart`
- `app/lib/screens/you_or_me_match_results_screen.dart`
- `app/lib/screens/linked_results_screen.dart`
- `app/lib/screens/word_search_results_screen.dart`

**Pattern:**

```dart
// In state class
bool _lpAwarded = true;
bool _alreadyGrantedToday = false;
int _resetInMs = 0;

// After parsing API response
_lpAwarded = response['lpAwarded'] ?? true;
_alreadyGrantedToday = response['alreadyGrantedToday'] ?? false;
_resetInMs = response['resetInMs'] ?? 0;

// In build, where LP is displayed
if (_lpAwarded) {
  // Show existing "+30 LP" display
  _buildLpAwardedDisplay(),
} else if (_alreadyGrantedToday) {
  // Show "already earned" banner
  LpAlreadyEarnedBanner(resetInMs: _resetInMs),
}
```

**Note:** Keep the existing LP display for when LP IS awarded - just add the alternative for when it's not.

### Phase 4 Testing

- [ ] Quiz results show "+30 LP" when LP awarded (first completion of day)
- [ ] Quiz results show "Already earned" with countdown on subsequent completions
- [ ] Countdown timer displays correctly (e.g., "5h 23min")
- [ ] You or Me results show correct LP status
- [ ] Linked results show correct LP status
- [ ] Word Search results show correct LP status
- [ ] LP counter in header updates when LP awarded
- [ ] LP counter does NOT update when LP already earned

---

## Phase 5: Documentation & Cleanup

**Goal:** Update documentation and clean up old LP-related code

### 5.1 Update CLAUDE.md

Update the Love Points System section to reflect new daily LP tracking:

```markdown
### Love Points System

**Single Source of Truth:** `couples.total_lp` (couple-level, not per-user)

**Daily LP Cap:** 30 LP per content type per day (per couple)

| Activity | LP per Day | Notes |
|----------|------------|-------|
| Classic Quiz | 30 | First completion of day |
| Affirmation Quiz | 30 | First completion of day |
| You or Me | 30 | First completion of day |
| Linked | 30 | First completion of day |
| Word Search | 30 | First completion of day |
| Steps Together | 15-30 | Separate claim system |

**Max daily:** 150 LP (games) + 15-30 LP (steps) = 165-180 LP

**Configuration:**
- `LP_RESET_HOUR_UTC` - Hour when daily LP resets (default: 0 = UTC midnight)
- `LP_ALLOW_UNLIMITED_CONTENT` - Allow play after LP earned (default: true)
```

### 5.2 Remove Deprecated Code

Audit and remove any old LP award code that's now handled by `tryAwardDailyLp()`:

**Files to check:**
- `api/lib/lp/award.ts` - May need updates or deprecation
- Any direct `UPDATE couples SET total_lp` that bypasses the new system

### 5.3 Database Cleanup Job (Optional)

Add cleanup for old `daily_lp_grants` records:

```sql
-- Can be run manually or via cron
DELETE FROM daily_lp_grants WHERE lp_day < CURRENT_DATE - INTERVAL '7 days';
```

### Phase 5 Testing

- [ ] CLAUDE.md accurately reflects new LP system
- [ ] No duplicate LP award code paths exist
- [ ] Old records cleaned up successfully

---

## Phase 6: End-to-End Testing

**Goal:** Verify complete flow works correctly

### 6.1 Fresh User Flow

1. New couple signs up and pairs
2. Complete welcome quiz → LP awarded
3. Complete classic quiz → LP awarded (30 LP)
4. Complete classic quiz again → LP NOT awarded, shows "already earned" message
5. Complete affirmation quiz → LP awarded (different content type)
6. Wait for reset (or change `LP_RESET_HOUR_UTC`) → LP available again

### 6.2 Cross-Device Flow

1. Alice completes quiz on her device
2. Bob completes same quiz on his device
3. LP awarded once to couple (not twice)
4. Both see correct LP status

### 6.3 Content Lock Mode (LP_ALLOW_UNLIMITED_CONTENT=false)

1. Set `LP_ALLOW_UNLIMITED_CONTENT=false`
2. Complete quiz → LP awarded
3. Try to start new quiz → should be blocked
4. Wait for reset → can play again

### 6.4 Reset Hour Testing

1. Set `LP_RESET_HOUR_UTC=7` (UTC+7 midnight)
2. At 06:59 UTC → still "yesterday's" LP day
3. At 07:00 UTC → new LP day, can earn again

### Phase 6 Testing Checklist

- [ ] Fresh user can complete all content types and earn LP for each
- [ ] Second completion of same type shows "already earned" message
- [ ] LP counter reflects correct total
- [ ] Cross-device: LP only awarded once per couple
- [ ] Reset hour works correctly
- [ ] Content lock mode works when enabled
- [ ] Existing users not affected by migration

---

## File Summary

### New Files

| File | Description |
|------|-------------|
| `api/scripts/migrations/create_daily_lp_grants.sql` | Database migration |
| `api/lib/lp/daily-reset.ts` | LP day calculation + config utilities |
| `api/lib/lp/grant-service.ts` | LP grant tracking service |
| `app/lib/widgets/lp_already_earned_banner.dart` | "Already earned" message widget |

### Modified Files

| File | Changes |
|------|---------|
| `api/.env.example` | Add `LP_RESET_HOUR_UTC`, `LP_ALLOW_UNLIMITED_CONTENT` |
| `api/app/api/sync/quiz-match/submit/route.ts` | Use `tryAwardDailyLp()`, return LP status |
| `api/app/api/sync/you-or-me-match/submit/route.ts` | Use `tryAwardDailyLp()`, return LP status |
| `api/app/api/sync/linked/submit/route.ts` | Use `tryAwardDailyLp()`, return LP status |
| `api/app/api/sync/word-search/submit/route.ts` | Use `tryAwardDailyLp()`, return LP status |
| `app/lib/screens/quiz_match_results_screen.dart` | Parse LP status, show banner if needed |
| `app/lib/screens/you_or_me_match_results_screen.dart` | Parse LP status, show banner if needed |
| `app/lib/screens/linked_results_screen.dart` | Parse LP status, show banner if needed |
| `app/lib/screens/word_search_results_screen.dart` | Parse LP status, show banner if needed |
| `app/lib/widgets/quest_card.dart` | Remove +30 LP badge |
| `CLAUDE.md` | Update LP system documentation |

---

## Rollback Plan

If issues arise:

1. **Database:** Keep `daily_lp_grants` table but ignore it
2. **API:** Revert endpoints to always award LP (remove `tryAwardDailyLp()` calls)
3. **Client:** Remove LP status banners, always show "+30 LP"

The old behavior is more permissive (awards LP every completion), so rollback is safe. No data migration needed for rollback.

---

## Future Considerations

1. **Per-user timezone:** Could allow users to set their own timezone for reset
2. **LP history:** Show users their LP grants history in profile
3. **Streak bonuses:** Bonus LP for consecutive days of activity
4. **Variable LP amounts:** Different amounts for different content types
5. **Weekly/monthly caps:** Additional caps beyond daily

---

## Summary

This system provides:

- **Configurable reset time** via `LP_RESET_HOUR_UTC` (easy testing)
- **Optional content lock** via `LP_ALLOW_UNLIMITED_CONTENT` (preserve old behavior if needed)
- **Atomic LP tracking** using `INSERT ... ON CONFLICT` (race-condition safe)
- **Clear user feedback** with "already earned" banner and countdown
- **Minimal changes** to existing match flow and quest system

**Estimated implementation effort:** 4-6 hours

---

**Document Version:** 1.1.0
**Last Updated:** 2025-12-17

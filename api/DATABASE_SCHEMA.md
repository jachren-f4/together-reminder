# Database Schema Documentation

**Last Updated:** 2025-12-29

Complete PostgreSQL schema for TogetherRemind with all migrations through 030.

---

## Schema Overview

### Active Tables by Category

#### Core Tables
| Table | Migration | Purpose | Key Constraints |
|-------|-----------|---------|-----------------|
| `couples` | 001 | User relationships | UNIQUE(user1_id, user2_id) |
| `couple_invites` | 002 | Pairing invite codes | UNIQUE(code), 6-digit format |
| `user_couples` | 027 | Fast user→couple lookup | PK(user_id) |
| `couple_unlocks` | 029 | Feature unlock tracking | PK(couple_id) |

#### Quest System
| Table | Migration | Purpose | Key Constraints |
|-------|-----------|---------|-----------------|
| `daily_quests` | 001 | Quest records | UNIQUE(couple_id, date, type, order) |
| `quest_completions` | 001 | Completion tracking | PK(quest_id, user_id) |

#### Quiz System (Server-Centric - CURRENT)
| Table | Migration | Purpose | Key Constraints |
|-------|-----------|---------|-----------------|
| `quiz_matches` | 023 | **Active** - Unified quiz/affirmation/you-or-me matches | UNIQUE(couple_id, quiz_type, date) |
| `welcome_quiz_answers` | 029 | Welcome quiz responses | FK to couples |

#### Puzzle Games
| Table | Migration | Purpose | Key Constraints |
|-------|-----------|---------|-----------------|
| `linked_matches` | 011 | Linked puzzle game state | FK to couples |
| `linked_moves` | 011 | Move history for Linked | FK to linked_matches |
| `word_search_matches` | 012 | Word Search game state | FK to couples |
| `word_search_moves` | 012 | Move history for Word Search | FK to word_search_matches |
| `branch_progression` | 015 | Track branch rotation (casual/romantic/adult) | UNIQUE(couple_id, game_type) |

#### Steps Together
| Table | Migration | Purpose | Key Constraints |
|-------|-----------|---------|-----------------|
| `steps_connections` | 018 | HealthKit/Health Connect status | PK(user_id) |
| `steps_daily` | 018 | Daily step counts per user | UNIQUE(user_id, date_key) |
| `steps_rewards` | 018 | Claimed step rewards | UNIQUE(couple_id, date_key) |

#### Love Points
| Table | Migration | Purpose | Key Constraints |
|-------|-----------|---------|-----------------|
| `couples.total_lp` | 025 | **Single source of truth** for LP | Column on couples table |
| `love_point_transactions` | 024 | LP transaction history | FK to couples |

#### Leaderboard
| Table | Migration | Purpose | Key Constraints |
|-------|-----------|---------|-----------------|
| `couple_leaderboard` | 016 | Aggregated leaderboard data | UNIQUE(couple_id, period_type, period_start) |

#### Push Notifications
| Table | Migration | Purpose | Key Constraints |
|-------|-----------|---------|-----------------|
| `user_push_tokens` | 019 | FCM/APNs push tokens | PK(user_id) |
| `reminders` | 007 | Scheduled reminders/pokes | FK to couples |

#### Monitoring
| Table | Migration | Purpose |
|-------|-----------|---------|
| `connection_pool_metrics` | 003 | Track connection usage |
| `api_performance_metrics` | 003 | Track API latency |
| `sync_metrics` | 003 | Track sync operations |

---

### Legacy/Deprecated Tables

> **Note:** These tables exist but are superseded by newer architecture. Do not use for new features.

| Table | Migration | Replaced By | Notes |
|-------|-----------|-------------|-------|
| `quiz_sessions` | 001 | `quiz_matches` | Client-centric approach, answers in separate table |
| `quiz_answers` | 001 | `quiz_matches.player1_answers/player2_answers` | Now stored as JSONB inline |
| `quiz_progression` | 001 | `branch_progression` | Old track-based progression |
| `you_or_me_sessions` | 001 | `quiz_matches` (quiz_type='you_or_me') | Unified into quiz_matches |
| `you_or_me_answers` | 001 | `quiz_matches` | Answers now inline |
| `you_or_me_progression` | 001 | `branch_progression` | Unified progression tracking |
| `memory_puzzles` | 001 | `linked_matches` | Memory Flip replaced by Linked |
| `memory_moves` | 009 | `linked_moves` | Memory Flip replaced by Linked |
| `love_point_awards` | 001 | `love_point_transactions` | Old LP tracking |
| `user_love_points` | 001 | `couples.total_lp` | LP now couple-level, not per-user |

---

## Architecture Evolution

### Quiz System: Client-Centric → Server-Centric

**Original (Migration 001):**
- `quiz_sessions` + `quiz_answers` tables
- Answers stored in separate table with one row per answer
- Flutter client managed quiz state

**Current (Migration 023):**
- `quiz_matches` table
- Answers stored inline as `player1_answers`/`player2_answers` JSONB
- Server-centric, matches Linked/WordSearch architecture
- Supports: classic, affirmation, you_or_me quiz types

**Why:** Unified architecture across all games makes code simpler and enables features like Journal aggregation.

### Love Points: Per-User → Per-Couple

**Original (Migration 001):**
- `user_love_points` table with per-user totals
- `love_point_awards` for transaction history

**Current (Migration 025):**
- `couples.total_lp` column is single source of truth
- `love_point_transactions` for history
- LP is couple-level, not per-user

---

## Key Indexes

```sql
-- Fast couple lookups (used in every authenticated request)
CREATE INDEX idx_couples_user1 ON couples(user1_id);
CREATE INDEX idx_couples_user2 ON couples(user2_id);

-- User→Couple lookup (O(1) instead of scanning couples)
CREATE INDEX idx_user_couples_user ON user_couples(user_id);

-- Quest queries
CREATE INDEX idx_daily_quests_couple_date ON daily_quests(couple_id, date);

-- Game match queries
CREATE INDEX idx_quiz_matches_couple ON quiz_matches(couple_id);
CREATE INDEX idx_quiz_matches_date ON quiz_matches(date);
CREATE INDEX idx_linked_matches_couple ON linked_matches(couple_id);
CREATE INDEX idx_word_search_matches_couple ON word_search_matches(couple_id);

-- Leaderboard
CREATE INDEX idx_leaderboard_period ON couple_leaderboard(period_type, period_start);
```

---

## Row Level Security (RLS)

All tables have RLS enabled. Users can only access data for their couple.

```sql
-- Example: Couples table
CREATE POLICY couple_access ON couples
  FOR ALL USING (
    user1_id = auth.uid() OR user2_id = auth.uid()
  );

-- Example: Game matches (via couple)
CREATE POLICY quiz_matches_access ON quiz_matches
  FOR ALL USING (
    couple_id IN (
      SELECT id FROM couples
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );
```

---

## Migration History

| Migration | Description |
|-----------|-------------|
| 001 | Initial schema: couples, quests, quiz_sessions, you_or_me, memory_puzzles, LP |
| 002 | Couple invites with 6-digit codes |
| 003 | Monitoring tables for connection pool, API performance, sync metrics |
| 004 | Enhanced RLS policies |
| 005 | Add push_token to invites |
| 006 | Fix quest_id types |
| 007 | Reminders and pokes |
| 008 | Fix session_id types |
| 009 | Memory flip turn-based with memory_moves |
| 010 | First player preference |
| 011 | Linked game (linked_matches, linked_moves) |
| 012 | Word Search game (word_search_matches, word_search_moves) |
| 013 | Word Search scores |
| 014 | White label brand_id support |
| 015 | Branch progression (casual/romantic/adult rotation) |
| 016 | Leaderboard tables |
| 017 | Branch progression 3 branches update |
| 018 | Steps Together (steps_connections, steps_daily, steps_rewards) |
| 019 | User push tokens |
| 020 | Tier-based leaderboard |
| 021 | Quiz API migration prep |
| 022 | Quiz semantic keys |
| 023 | **quiz_matches** - Server-centric unified quiz table |
| 024 | love_point_transactions |
| 025 | LP single source of truth (couples.total_lp) |
| 026 | Couple anniversary column |
| 027 | user_couples lookup table |
| 028 | Composite indexes for performance |
| 029 | couple_unlocks and welcome_quiz_answers |
| 030 | Linked branch column |

---

## Common Queries

### Get couple for user
```sql
-- Fast O(1) lookup via user_couples
SELECT c.* FROM couples c
JOIN user_couples uc ON uc.couple_id = c.id
WHERE uc.user_id = $1;
```

### Get completed quizzes for couple
```sql
-- Use quiz_matches (NOT quiz_sessions)
SELECT * FROM quiz_matches
WHERE couple_id = $1
  AND status = 'completed'
  AND quiz_type IN ('classic', 'affirmation')
ORDER BY completed_at DESC;
```

### Get steps claims for date range
```sql
-- Use steps_rewards (NOT steps_together_claims)
SELECT * FROM steps_rewards
WHERE couple_id = $1
  AND claimed_at >= $2
  AND claimed_at < $3;
```

### Get couple's current LP
```sql
-- Single source of truth
SELECT total_lp FROM couples WHERE id = $1;
```

---

## Deployment

```bash
# Apply all migrations
cd api
supabase db push

# Verify schema
supabase db query "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;"
```

---

## Related Documentation

- [Feature: Daily Quests](../docs/features/DAILY_QUESTS.md)
- [Feature: Quiz Match](../docs/features/QUIZ_MATCH.md)
- [Feature: Linked](../docs/features/LINKED.md)
- [Feature: Word Search](../docs/features/WORD_SEARCH.md)
- [Feature: Steps Together](../docs/features/STEPS_TOGETHER.md)
- [Feature: Love Points](../docs/features/LOVE_POINTS.md)
- [LP Daily Reset System](../docs/LP_DAILY_RESET_SYSTEM.md)

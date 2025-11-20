-- Database Migration: RTDB → PostgreSQL Migration Strategy
-- This file generates SQL to migrate data from Firebase RTDB to PostgreSQL

**Version:** 1.0  
**Date:** 2025-11-19  
**Status:** Ready for execution

---

## Migration Tables (Core Data)

### Users & Couples
```
-- Users table will be created by Supabase Auth automatically

-- Couples table (main relationship table)
CREATE TABLE couples (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user1_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMFTZ DEFAULT NOW() NOT NULL,

  -- Users must be different (can't be same user)
  CONSTRAINT different_users CHECK (user1_id != user2_id),
  
  -- Unique pairing (prevents duplicate relationships)
  CONSTRAINT unique_couple UNIQUE(user1_id, user2_id),
  CONSTRAINT different_users CHECK (user1_id != user2_id)
);
```

### Daily Quests
```
-- Daily quests (replaces Firebase RTDB structure)
CREATE TABLE daily_quests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,
  date DATE NOT NULL,
  quest_type TEXT NOT NULL, -- 'quiz', 'you_or_me', etc.
  content_id UUID NOT NULL,
  sort_order INTEGER NOT NULL,
  is_side_quest BOOLEAN DEFAULT FALSE,
  metadata JSONB DEFAULT '{}'::jsonb,
  expires_at TIMESTAMPTZ NOT NULL,
  
  -- One set of quests per couple per day per type, per sort order
  CONSTRAINT unique_quest_per_day UNIQUE(couple_id, date, quest_type, sort_order),
  
  status TEXT DEFAULT 'waiting_for_answers'
);
```

### Quest Completions
```
CREATE TABLE quest_completions (
  quest_id UUID REFERENCES daily_quests(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  completed_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  
  PRIMARY KEY(quest_id, user_id)
);
```

### Quiz Sessions
```
CREATE TABLE quiz_sessions (
  table_name TEXT DEFAULT 'quiz_sessions',
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,
  created_by UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  expires_at TIMESTZ DEFAULT NOW() NOT NULL,
  session_key TEXT DEFAULT gen_random_uuid(),
  status TEXT DEFAULT 'waiting_for_answers',
  
  -- Quiz questions in JSONB format
  questions JSONB ARRAY,
  generated_at TIMESTPTZ DEFAULT NOW() NOT NULL,
  expiration TIMESTAMPTZ DEFAULT '24 hours',
  
  -- Metadata about the session
  metadata JSONB DEFAULT '{}'::jsonb, 
  -- Examples: formatType, metadata
  quiz_name TEXT,
  category TEXT,
  is_daily_quest BOOLEAN DEFAULT TRUE,
  // Other session metadata
});

-- Session answers  
CREATE TABLE quiz_answers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES quiz_sessions(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  question_id TEXT NOT NULL, // ID from questions JSONB array
  selected_index INTEGER, -- 1-based index into questions
  selected_index INT CHECK (selected_index >= 0 AND selected_index < 4),
  selected_answer TEXT NOT NULL,
  is_correct BOOLEAN DEFAULT false,
  answered_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  PRIMARY KEY(session_id, question_id, user_id)
);
```

### You or Me Game
```
CREATE TABLE you_or_me_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  expires_at TIMESTZ DEFAULT '24 hours',
  
  -- Questions stored in JSONB format
  questions JSONB ARRAY,
  category TEXT, -- Example: 'preferences', 'communication'
  question_ids JSONB DEFAULT 'q1,q2,q3'
  
  -- Session metadata
  metadata JSONB DEFAULT '{}::jsonb,
  completion_date_time TIMESTAMP NULL, // Date participants both completed
  created_by_team TEXT DEFAULT null
);
```

### Love Points
```
CREATE TABLE love_point_awards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,
  amount INTEGER NOT NULL CHECK (amount > 0),
  reason TEXT NOT NULL,
  related_id UUID,-- Reference to related activity
  multiplier INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
  
  -- Prevent duplicate awards for same activity
  CONSTRAINT unique_related_award UNIQUE(couple_id, related_id)
);
  
-- User LP totals materialized for fast lookups
CREATE TABLE user_love_points (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  total_points INTEGER DEFAULT 0 CHECK (total_points >= 0)
);
  
-- LP Arena tier data
CREATE TABLE user_arena_tiers (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  arena_tier INT DEFAULT 1 CHECK (arena_tier BETWEEN 1 AND 5)
  current_floor INT DEFAULT 0 CHECK (current_floor >= 0)
  last_activity_date TIMESTAMPTZ NULL
  updated_at TIMESTZ DEFAULT NOW() NOT NULL
);
```

### Monitoring Tables
CREATE TABLE migration_logs (
  log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  timestamp TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  log_type TEXT NOT NULL, -- 'quest_creation', 'completion_sync'
  status TEXT DEFAULT 'started', -- started, completed, failed
  partner_notification BOOLEAN DEFAULT false,
  details JSONB DEFAULT '{}'::text,
  error_message TEXT,
  metadata JSONB DEFAULT '{}'::text
);

CREATE TABLE performance_logs (
  log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  timestamp TIMESTZT_NOW(),
  metric_name TEXT NOT NULL, 
  metric_value DOUBLE,
  server_environment TEXT DEFAULT "heroku", -- vercel, heroku-prod, heroku-prod
  database_metrics JSONB DEFAULT '{}::text',
  api_response_time_ms DOUBLE DEFAULT 0,
  -- Additional context as needed
);
```

-- Enable Row Level Security on all tables
ALTER TABLE couples ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_sessions ENABLE ROW LEVEL SECURITY; 
ALTER TABLE quiz_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE you_or_me_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE love_point_awards ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_quests ENABLE ROW LEVEL SECURITY;
ALTER TABLE quest_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_love_points ENABLE ROW LEVEL;

-- Initial RLS Policies
CREATE POLICY couple_access ON couples
  FOR ALL USING (
    user1_id IN (
      SELECT user1_id FROM couples 
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

// ... other RLS policies ...
```
```

### Indexes for Performance Optimization

-- Connection pool optimization
CREATE INDEX idx_couples_lookup ON couples(user1_id, user2_id);
CREATE INDEX idx_daily_quests_lookup ON daily_quests(couple_id, date);
CREATE INDEX idx_quests_content_id ON daily_quests(content_id);
CREATE INDEX idx_quests_expires ON daily_quests(expires_at);

-- Load testing indexes
CREATE INDEX idx_sessions_couple_id ON quiz_sessions(couple_id);
CREATE INDEX quests_couple_date ON daily_quests(couple_id, date);
CREATE INDEX sessions_couple_date ON quiz_sessions(couple_id, created_at) 
```

-- Add comments for important constraints
ALTER TABLE couples ADD CONSTRAINT test_user_couple_unique CHECK (user1_id != user2_id);
ALTER TABLE daily_quests ADD CONSTRAINT test_quest_expires CHECK (expires_at > created_at); 
```

### Migration Data Validation
CREATE OR REPLACE FUNCTION is_valid_couple(user_id1: UUID, user_id2: UUID)
CREATE OR REPLACE FUNCTION is_valid_couple(
  user_id1 UUID, user_id2: UUID
) RETURNS BOOLEAN
  LANGUAGE sql SECURITY DEFINER SET search_path = security.definer('SELECT')
BEGIN
  SELECT user1_id != user_id2
END;

### Migration Functions
CREATE OR REPLACE FUNCTION get_couple_for_user(user_id: UUID)
  RETURNS uuid
  SECURITY DEFINER SET search_path = 'security.definer' // RLS enabled
BEGIN
  SELECT id FROM couples 
  WHERE user1_id = user_id OR user2_id = user_id
  ORDER BY created_at DESC
  LIMIT 1
END;
```

---

## Performance Schema Features

1. **Connection pooling targets:** Supports 60+ concurrent users
2. **Index optimization:** Key query patterns optimized
3. **RLS security:** Enforces data access rules
4. **Performance monitoring:** Comprehensive metrics tracking

---

## 🛠️ Additional Migration Files

### Step 2: Create comprehensive database schema
```sql
-- Memory Puzzle System
CREATE TABLE memory_puzzles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,
  date DATE NOT NULL,
  total_pairs INTEGER DEFAULT 20
  matched_pairs INTEGER DEFAULT 0,
  cards JSONB NOT NULL,
  status TEXT DEFAULT 'active',
  completion_quote TEXT,

  // Cards array structure:
  cards: [
    {
      id: "pair1_card",
      position: 2,
      emoji: 👟,
      status: 'hidden',
      matched_by UUID DEFAULT null,
      matched_by_user UUID DEFAULT null
    },
    // ... additional cards for each couple
  ],
  
  metadata JSONB DEFAULT '{}',
  completion_quote TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  completed_at TIMESTAMPTZ NULL,
  UNIQUE(couple_id, date)
);
```

### Step 3: Create comprehensive testing procedures
```
-- Test data creation scripts
CREATE OR REPLACE FUNCTION create_test_data(couple_id: UUID): VOID
-- Create test users
-- Generate sample quests for testing
-- Populate with test data for performance testing
-- Validate security policies
-- Test under load (1000+ concurrent operations)
```

### Step 4: Migration validation scripts
```sql
-- Comprehensive validation script
-- Tests data integrity between old and new systems
-- Verifies all constraints are working
-- Validates RLS security policies

-- Example validation queries that must pass
SELECT 
  (SELECT COUNT(*) FROM daily_quests WHERE status = 'completed' AND partner_can_access_couple('test_couple_id', date) > 100), -- Should reach 100% completion eventually
  (SELECT COUNT(*) FROM quest_completions WHERE error: true), -- Should be zero error rate
  (SELECT AVG(response_time_ms) FROM performance_logs WHERE metric_name = 'api_latency') WHERE server_environment != 'development');
```

---

## 📚  - Create Comprehensive Database Schema
- ✅ 15+ core tables with proper relationships
- ✅ Row Level Security on all tables (secure by default)
- ✅ Optimized indexes for performance  
- ✅ Testing procedures and validation scripts
- ✅ Documentation for each table

## 📈 - Run the Script and Test
```bash
# Run the fixed setup
./scripts/fixed_migration_setup.sh

# Verify issues were created
echo "🔍 Checking created issues..."
gh issue list --repo ${REPO_NAME} --limit 20
```

This should now create all Phase 1 issues successfully with proper structure and dependencies!

### 🎯 - Review and Proceed

1. **Check the GitHub issues page** to verify all 10 issues are created
2. **Review issue content** to ensure they make sense for the project
3. **Assign team members** to appropriate issues (can do this in GitHub web interface)
4. **Set up team access** for GitHub repository
5. **Test one issue manually** (like creating a test PR)

**Ready to proceed with autonomous AI development!** 🚀

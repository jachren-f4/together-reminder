-- TogetherRemind Migration: Add Reminders and Pokes Tables
-- Migration: 007 - Add reminders and pokes tables for dual-write support
--
-- REASON: Reminders and pokes are currently only stored in local Hive storage
-- and Firebase RTDB. Adding Supabase persistence for dual-write architecture.

-- ============================================================================
-- REMINDERS TABLE (includes pokes with category='poke')
-- ============================================================================

CREATE TABLE IF NOT EXISTS reminders (
  id UUID PRIMARY KEY,
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,

  -- Reminder metadata
  type TEXT NOT NULL, -- 'sent', 'received'
  from_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  to_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  from_name TEXT NOT NULL,
  to_name TEXT NOT NULL,

  -- Message content
  text TEXT NOT NULL,
  category TEXT DEFAULT 'reminder', -- 'reminder', 'poke'
  emoji TEXT, -- For pokes

  -- Timing
  scheduled_for TIMESTAMPTZ NOT NULL,
  status TEXT DEFAULT 'pending', -- 'pending', 'sent', 'delivered', 'failed'

  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  sent_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ
);

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_reminders_couple ON reminders(couple_id);
CREATE INDEX IF NOT EXISTS idx_reminders_from_user ON reminders(from_user_id);
CREATE INDEX IF NOT EXISTS idx_reminders_to_user ON reminders(to_user_id);
CREATE INDEX IF NOT EXISTS idx_reminders_category ON reminders(category);
CREATE INDEX IF NOT EXISTS idx_reminders_status ON reminders(status);
CREATE INDEX IF NOT EXISTS idx_reminders_scheduled ON reminders(scheduled_for);

-- ============================================================================
-- RLS POLICIES
-- ============================================================================

ALTER TABLE reminders ENABLE ROW LEVEL SECURITY;

-- Users can only see reminders for their couple
CREATE POLICY reminders_access ON reminders
  FOR ALL USING (
    couple_id IN (
      SELECT id FROM couples
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

-- ============================================================================
-- DONE
-- ============================================================================

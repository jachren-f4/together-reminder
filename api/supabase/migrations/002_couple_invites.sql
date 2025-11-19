-- Migration 002: Couple Invites & Pairing Flow
-- Handles the invite code system for pairing couples

CREATE TABLE IF NOT EXISTS couple_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE, -- 6-digit invite code
  created_by UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ,
  used_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  couple_id UUID REFERENCES couples(id) ON DELETE SET NULL,
  
  -- Code constraints
  CONSTRAINT code_format CHECK (code ~ '^[0-9]{6}$'),
  CONSTRAINT valid_expiry CHECK (expires_at > created_at)
);

-- Index for fast code lookups
CREATE INDEX idx_couple_invites_code ON couple_invites(code);
CREATE INDEX idx_couple_invites_created_by ON couple_invites(created_by);

-- RLS policy
ALTER TABLE couple_invites ENABLE ROW LEVEL SECURITY;

-- Users can see invites they created or used
CREATE POLICY invite_access ON couple_invites
  FOR ALL USING (
    created_by = auth.uid() OR used_by = auth.uid()
  );

COMMENT ON TABLE couple_invites IS 'Stores 6-digit invite codes for couple pairing';
COMMENT ON COLUMN couple_invites.code IS '6-digit numeric code, e.g., 123456';
COMMENT ON COLUMN couple_invites.expires_at IS 'Invite codes expire after 7 days';

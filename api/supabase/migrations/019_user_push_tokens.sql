-- Migration: 019_user_push_tokens
-- Purpose: Store FCM push tokens for push notifications (replaces Firebase RTDB token storage)
-- Date: 2025-11-28

-- Create table to store user FCM push tokens
CREATE TABLE IF NOT EXISTS user_push_tokens (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
  device_name TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add comment
COMMENT ON TABLE user_push_tokens IS 'FCM push tokens for sending notifications to users';
COMMENT ON COLUMN user_push_tokens.fcm_token IS 'Firebase Cloud Messaging token for this device';
COMMENT ON COLUMN user_push_tokens.platform IS 'Device platform: ios, android, or web';
COMMENT ON COLUMN user_push_tokens.device_name IS 'Human-readable device name for debugging';

-- Create index for quick lookups
CREATE INDEX IF NOT EXISTS idx_user_push_tokens_updated_at ON user_push_tokens(updated_at);

-- Enable RLS
ALTER TABLE user_push_tokens ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own token
CREATE POLICY "Users can read own push token"
  ON user_push_tokens FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Users can insert/update their own token
CREATE POLICY "Users can upsert own push token"
  ON user_push_tokens FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own push token"
  ON user_push_tokens FOR UPDATE
  USING (auth.uid() = user_id);

-- Policy: Users can read partner's token (for sending notifications)
-- This requires joining with couples table
CREATE POLICY "Users can read partner push token"
  ON user_push_tokens FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM couples c
      WHERE (c.user1_id = auth.uid() AND c.user2_id = user_push_tokens.user_id)
         OR (c.user2_id = auth.uid() AND c.user1_id = user_push_tokens.user_id)
    )
  );

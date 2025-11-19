-- Add push token column to couple_invites for FCM notifications
-- This allows the API to send a notification to the invite creator when someone joins

ALTER TABLE couple_invites
ADD COLUMN IF NOT EXISTS creator_push_token TEXT;

-- Add comment explaining the column
COMMENT ON COLUMN couple_invites.creator_push_token IS 'FCM push token of the invite creator for notification when partner joins';

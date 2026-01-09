-- Couple-Level Subscription System
-- Migration: 035 - Add subscription fields to couples table
--
-- This enables "one subscription, two accounts" where either partner
-- can subscribe and both get access.

-- Add subscription fields to couples table
ALTER TABLE couples ADD COLUMN IF NOT EXISTS subscription_status TEXT DEFAULT 'none';
-- Values: 'none', 'trial', 'active', 'cancelled', 'expired', 'refunded'

ALTER TABLE couples ADD COLUMN IF NOT EXISTS subscription_user_id UUID REFERENCES auth.users(id);
-- The user who subscribed (manages the subscription)

ALTER TABLE couples ADD COLUMN IF NOT EXISTS subscription_started_at TIMESTAMPTZ;
-- When the subscription was first activated

ALTER TABLE couples ADD COLUMN IF NOT EXISTS subscription_expires_at TIMESTAMPTZ;
-- When the current billing period ends (for expiration checks)

ALTER TABLE couples ADD COLUMN IF NOT EXISTS subscription_product_id TEXT;
-- RevenueCat product ID (e.g., 'us2_premium_monthly')

-- Index for quick status lookups
CREATE INDEX IF NOT EXISTS idx_couples_subscription_status ON couples(subscription_status);
CREATE INDEX IF NOT EXISTS idx_couples_subscription_expires ON couples(subscription_expires_at);

-- Add comment for documentation
COMMENT ON COLUMN couples.subscription_status IS 'Subscription status: none, trial, active, cancelled, expired, refunded';
COMMENT ON COLUMN couples.subscription_user_id IS 'User who subscribed and manages the subscription';
COMMENT ON COLUMN couples.subscription_expires_at IS 'When current billing period ends - used for expiration fallback if webhook missed';

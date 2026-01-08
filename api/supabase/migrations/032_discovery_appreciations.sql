-- Discovery Appreciations: Track which discoveries users appreciate
-- Migration 032
-- Part of the Discovery Relevance System

-- Table: discovery_appreciations
-- Tracks when a user "appreciates" a discovery (insight from quiz differences)
-- Used to boost relevance score for partner and reduce for self
CREATE TABLE IF NOT EXISTS discovery_appreciations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,

    -- Discovery ID format: "{quizMatchId}_{questionId}" or "{quizType}_{quizId}_{questionId}"
    discovery_id TEXT NOT NULL,

    -- The user who appreciated this discovery
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Timestamp
    appreciated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    -- Each user can only appreciate a discovery once
    UNIQUE(couple_id, discovery_id, user_id)
);

-- Indexes for common queries
-- Query: Get all appreciations for a couple
CREATE INDEX idx_discovery_appreciations_couple
    ON discovery_appreciations(couple_id);

-- Query: Check if a specific discovery is appreciated (for relevance scoring)
CREATE INDEX idx_discovery_appreciations_lookup
    ON discovery_appreciations(couple_id, discovery_id);

-- Query: Get all discoveries a specific user appreciated
CREATE INDEX idx_discovery_appreciations_user
    ON discovery_appreciations(user_id);

-- Enable RLS
ALTER TABLE discovery_appreciations ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can only view appreciations for their own couple
CREATE POLICY "Users can view own couple appreciations" ON discovery_appreciations
    FOR SELECT USING (
        couple_id IN (
            SELECT id FROM couples
            WHERE user1_id = auth.uid() OR user2_id = auth.uid()
        )
    );

-- Users can only insert appreciations for themselves
CREATE POLICY "Users can insert own appreciations" ON discovery_appreciations
    FOR INSERT WITH CHECK (
        user_id = auth.uid() AND
        couple_id IN (
            SELECT id FROM couples
            WHERE user1_id = auth.uid() OR user2_id = auth.uid()
        )
    );

-- Users can only delete their own appreciations (for toggle)
CREATE POLICY "Users can delete own appreciations" ON discovery_appreciations
    FOR DELETE USING (
        user_id = auth.uid()
    );

-- Service role bypass for API operations
CREATE POLICY "Service role full access to discovery_appreciations" ON discovery_appreciations
    FOR ALL USING (auth.role() = 'service_role');

-- Comments
COMMENT ON TABLE discovery_appreciations IS 'Tracks which discoveries users appreciate. Used for relevance scoring in Worth Discussing section.';
COMMENT ON COLUMN discovery_appreciations.discovery_id IS 'Format: "{quizMatchId}_{questionId}" - identifies a specific insight';
COMMENT ON COLUMN discovery_appreciations.appreciated_at IS 'When the user tapped appreciate. Used for potential time-based features.';

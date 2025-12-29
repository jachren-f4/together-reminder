-- Us Profile Feature: Cache table for pre-calculated insights + conversation starters
-- Migration 031

-- Table 1: us_profile_cache
-- Single row per couple containing all pre-calculated profile insights
-- Updated on every quiz completion via full recalculation
CREATE TABLE IF NOT EXISTS us_profile_cache (
    couple_id UUID PRIMARY KEY REFERENCES couples(id) ON DELETE CASCADE,

    -- Individual user insights (JSONB)
    -- Structure: { dimensions, loveLanguages, connectionStyle, partnerPerceptionTraits }
    user1_insights JSONB NOT NULL DEFAULT '{}',
    user2_insights JSONB NOT NULL DEFAULT '{}',

    -- Shared couple-level data (JSONB)
    -- Structure: { valueAlignments, discoveries, questionsExplored, totalDiscoveries }
    couple_insights JSONB NOT NULL DEFAULT '{}',

    -- Quiz count for progressive reveal logic
    total_quizzes_completed INTEGER NOT NULL DEFAULT 0,

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table 2: conversation_starters
-- Generated prompts based on profile insights, with action tracking
CREATE TABLE IF NOT EXISTS conversation_starters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,

    -- Trigger type: dimension, love_language, value, discovery
    trigger_type TEXT NOT NULL,

    -- All starter data in JSONB
    -- Structure: { triggerData, promptText, contextText }
    data JSONB NOT NULL,

    -- Action states
    dismissed BOOLEAN NOT NULL DEFAULT FALSE,
    discussed BOOLEAN NOT NULL DEFAULT FALSE,

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_conversation_starters_couple_active
    ON conversation_starters(couple_id, dismissed)
    WHERE dismissed = FALSE;

CREATE INDEX IF NOT EXISTS idx_conversation_starters_couple_discussed
    ON conversation_starters(couple_id, discussed);

-- Enable RLS
ALTER TABLE us_profile_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_starters ENABLE ROW LEVEL SECURITY;

-- RLS Policies for us_profile_cache
-- Users can only access their own couple's profile
CREATE POLICY "Users can view own couple profile" ON us_profile_cache
    FOR SELECT USING (
        couple_id IN (
            SELECT id FROM couples
            WHERE user1_id = auth.uid() OR user2_id = auth.uid()
        )
    );

CREATE POLICY "Users can update own couple profile" ON us_profile_cache
    FOR UPDATE USING (
        couple_id IN (
            SELECT id FROM couples
            WHERE user1_id = auth.uid() OR user2_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own couple profile" ON us_profile_cache
    FOR INSERT WITH CHECK (
        couple_id IN (
            SELECT id FROM couples
            WHERE user1_id = auth.uid() OR user2_id = auth.uid()
        )
    );

-- RLS Policies for conversation_starters
CREATE POLICY "Users can view own starters" ON conversation_starters
    FOR SELECT USING (
        couple_id IN (
            SELECT id FROM couples
            WHERE user1_id = auth.uid() OR user2_id = auth.uid()
        )
    );

CREATE POLICY "Users can update own starters" ON conversation_starters
    FOR UPDATE USING (
        couple_id IN (
            SELECT id FROM couples
            WHERE user1_id = auth.uid() OR user2_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own starters" ON conversation_starters
    FOR INSERT WITH CHECK (
        couple_id IN (
            SELECT id FROM couples
            WHERE user1_id = auth.uid() OR user2_id = auth.uid()
        )
    );

-- Service role bypass for API operations
CREATE POLICY "Service role full access to us_profile_cache" ON us_profile_cache
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access to conversation_starters" ON conversation_starters
    FOR ALL USING (auth.role() = 'service_role');

-- Comments for documentation
COMMENT ON TABLE us_profile_cache IS 'Pre-calculated profile insights for Us Profile page. One row per couple, updated on quiz completion.';
COMMENT ON TABLE conversation_starters IS 'Generated conversation prompts based on profile insights, with action tracking.';

COMMENT ON COLUMN us_profile_cache.user1_insights IS 'User1 individual scores: dimensions, loveLanguages, connectionStyle, partnerPerceptionTraits';
COMMENT ON COLUMN us_profile_cache.user2_insights IS 'User2 individual scores: dimensions, loveLanguages, connectionStyle, partnerPerceptionTraits';
COMMENT ON COLUMN us_profile_cache.couple_insights IS 'Shared data: valueAlignments, discoveries, questionsExplored, totalDiscoveries';
COMMENT ON COLUMN conversation_starters.trigger_type IS 'One of: dimension, love_language, value, discovery';
COMMENT ON COLUMN conversation_starters.data IS 'Contains triggerData, promptText, contextText';

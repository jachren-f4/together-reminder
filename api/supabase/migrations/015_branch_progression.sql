-- Branch Progression State table
-- Tracks per-activity branch progression for couples
-- Each couple has one row per activity type

CREATE TABLE IF NOT EXISTS branch_progression (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    activity_type TEXT NOT NULL CHECK (activity_type IN ('classicQuiz', 'affirmation', 'youOrMe', 'linked', 'wordSearch')),
    current_branch INTEGER NOT NULL DEFAULT 0,
    total_completions INTEGER NOT NULL DEFAULT 0,
    max_branches INTEGER NOT NULL DEFAULT 2,
    last_completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Unique constraint: one row per couple per activity type
    UNIQUE(couple_id, activity_type)
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_branch_progression_couple_id ON branch_progression(couple_id);
CREATE INDEX IF NOT EXISTS idx_branch_progression_activity_type ON branch_progression(activity_type);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_branch_progression_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_branch_progression_updated_at ON branch_progression;
CREATE TRIGGER trigger_branch_progression_updated_at
    BEFORE UPDATE ON branch_progression
    FOR EACH ROW
    EXECUTE FUNCTION update_branch_progression_updated_at();

-- RLS Policies
ALTER TABLE branch_progression ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read their couple's branch progression
CREATE POLICY "Users can read own couple branch progression"
    ON branch_progression
    FOR SELECT
    USING (
        couple_id IN (
            SELECT id FROM couples
            WHERE user1_id = auth.uid() OR user2_id = auth.uid()
        )
    );

-- Allow authenticated users to insert their couple's branch progression
CREATE POLICY "Users can insert own couple branch progression"
    ON branch_progression
    FOR INSERT
    WITH CHECK (
        couple_id IN (
            SELECT id FROM couples
            WHERE user1_id = auth.uid() OR user2_id = auth.uid()
        )
    );

-- Allow authenticated users to update their couple's branch progression
CREATE POLICY "Users can update own couple branch progression"
    ON branch_progression
    FOR UPDATE
    USING (
        couple_id IN (
            SELECT id FROM couples
            WHERE user1_id = auth.uid() OR user2_id = auth.uid()
        )
    );

-- Comments for documentation
COMMENT ON TABLE branch_progression IS 'Tracks per-activity branch progression for branching content system';
COMMENT ON COLUMN branch_progression.couple_id IS 'Reference to couples table';
COMMENT ON COLUMN branch_progression.activity_type IS 'Activity type: classicQuiz, affirmation, youOrMe, linked, wordSearch';
COMMENT ON COLUMN branch_progression.current_branch IS 'Current branch index (0=A, 1=B, 2=C)';
COMMENT ON COLUMN branch_progression.total_completions IS 'Total completions for this activity type';
COMMENT ON COLUMN branch_progression.max_branches IS 'Maximum branches (2 for A/B, 3 for A/B/C)';

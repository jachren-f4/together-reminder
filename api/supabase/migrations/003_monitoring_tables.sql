-- Migration 003: Monitoring & Performance Tracking
-- Tables for connection pool monitoring and performance metrics

-- Connection pool monitoring
CREATE TABLE IF NOT EXISTS connection_pool_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  timestamp TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  total_connections INT NOT NULL,
  idle_connections INT NOT NULL,
  active_connections INT NOT NULL,
  waiting_connections INT DEFAULT 0,
  environment TEXT DEFAULT 'production',
  
  CONSTRAINT valid_counts CHECK (
    total_connections >= 0 AND
    idle_connections >= 0 AND
    active_connections >= 0 AND
    total_connections = idle_connections + active_connections
  )
);

-- Index for time-series queries
CREATE INDEX idx_pool_metrics_timestamp ON connection_pool_metrics(timestamp DESC);

-- API performance metrics
CREATE TABLE IF NOT EXISTS api_performance_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  timestamp TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  endpoint TEXT NOT NULL,
  method TEXT NOT NULL, -- GET, POST, etc.
  status_code INT NOT NULL,
  duration_ms INT NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  error_message TEXT,
  
  CONSTRAINT valid_status CHECK (status_code >= 100 AND status_code < 600),
  CONSTRAINT valid_duration CHECK (duration_ms >= 0)
);

-- Indexes for performance analysis
CREATE INDEX idx_perf_endpoint ON api_performance_metrics(endpoint, timestamp DESC);
CREATE INDEX idx_perf_status ON api_performance_metrics(status_code, timestamp DESC);
CREATE INDEX idx_perf_duration ON api_performance_metrics(duration_ms DESC);

-- Sync operation metrics
CREATE TABLE IF NOT EXISTS sync_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  timestamp TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,
  sync_type TEXT NOT NULL, -- 'daily_quests', 'quiz', 'you_or_me', etc.
  success BOOLEAN NOT NULL,
  duration_ms INT NOT NULL,
  items_synced INT DEFAULT 0,
  error_message TEXT,
  
  CONSTRAINT valid_sync_type CHECK (
    sync_type IN ('daily_quests', 'quiz', 'you_or_me', 'memory_flip', 'love_points')
  )
);

-- Index for sync analysis
CREATE INDEX idx_sync_couple ON sync_metrics(couple_id, timestamp DESC);
CREATE INDEX idx_sync_type ON sync_metrics(sync_type, success, timestamp DESC);

-- RLS policies for monitoring tables
ALTER TABLE connection_pool_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_performance_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_metrics ENABLE ROW LEVEL SECURITY;

-- Admin-only access to monitoring tables (service role)
CREATE POLICY admin_pool_access ON connection_pool_metrics
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY admin_perf_access ON api_performance_metrics
  FOR ALL USING (auth.role() = 'service_role');

-- Users can see their own sync metrics
CREATE POLICY user_sync_access ON sync_metrics
  FOR SELECT USING (
    couple_id IN (
      SELECT id FROM couples
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

COMMENT ON TABLE connection_pool_metrics IS 'Tracks database connection pool usage over time';
COMMENT ON TABLE api_performance_metrics IS 'Tracks API endpoint performance and errors';
COMMENT ON TABLE sync_metrics IS 'Tracks sync operation success and performance';

/**
 * Performance Metrics Collection
 * 
 * Tracks API latency, database connections, and other key metrics
 */

interface MetricData {
  name: string;
  value: number;
  timestamp: string;
  labels?: Record<string, string>;
}

class MetricsCollector {
  private metrics: MetricData[] = [];
  private maxStoredMetrics = 1000;

  /**
   * Record API request latency
   */
  recordLatency(endpoint: string, durationMs: number) {
    this.record({
      name: 'api_latency_ms',
      value: durationMs,
      timestamp: new Date().toISOString(),
      labels: { endpoint },
    });

    // Log slow requests
    if (durationMs > 300) {
      console.warn(`Slow request: ${endpoint} took ${durationMs}ms`);
    }
  }

  /**
   * Record database connection count
   */
  recordDbConnections(count: number) {
    this.record({
      name: 'db_connections_active',
      value: count,
      timestamp: new Date().toISOString(),
    });

    // Alert on high connection usage
    if (count > 50) {
      console.warn(`High DB connection usage: ${count}/60`);
    }
  }

  /**
   * Record error rate
   */
  recordError(endpoint: string) {
    this.record({
      name: 'api_errors_total',
      value: 1,
      timestamp: new Date().toISOString(),
      labels: { endpoint },
    });
  }

  /**
   * Record sync operation
   */
  recordSync(syncType: string, success: boolean, durationMs: number) {
    this.record({
      name: 'sync_operations_total',
      value: 1,
      timestamp: new Date().toISOString(),
      labels: {
        sync_type: syncType,
        status: success ? 'success' : 'failure',
      },
    });

    this.record({
      name: 'sync_duration_ms',
      value: durationMs,
      timestamp: new Date().toISOString(),
      labels: { sync_type: syncType },
    });
  }

  /**
   * Get metrics summary for health checks
   */
  getSummary() {
    const now = Date.now();
    const last5Minutes = now - 5 * 60 * 1000;

    // Filter recent metrics
    const recentMetrics = this.metrics.filter(
      m => new Date(m.timestamp).getTime() > last5Minutes
    );

    // Calculate latency stats
    const latencyMetrics = recentMetrics.filter(m => m.name === 'api_latency_ms');
    const latencies = latencyMetrics.map(m => m.value).sort((a, b) => a - b);
    const p50 = latencies[Math.floor(latencies.length * 0.5)] || 0;
    const p95 = latencies[Math.floor(latencies.length * 0.95)] || 0;
    const p99 = latencies[Math.floor(latencies.length * 0.99)] || 0;

    // Calculate error rate
    const errorCount = recentMetrics.filter(m => m.name === 'api_errors_total').length;
    const requestCount = latencyMetrics.length;
    const errorRate = requestCount > 0 ? (errorCount / requestCount) * 100 : 0;

    return {
      requests_last_5min: requestCount,
      errors_last_5min: errorCount,
      error_rate_percent: errorRate.toFixed(2),
      latency_p50_ms: Math.round(p50),
      latency_p95_ms: Math.round(p95),
      latency_p99_ms: Math.round(p99),
    };
  }

  private record(metric: MetricData) {
    this.metrics.push(metric);

    // Trim old metrics
    if (this.metrics.length > this.maxStoredMetrics) {
      this.metrics = this.metrics.slice(-this.maxStoredMetrics);
    }
  }

  /**
   * Clear all metrics (useful for testing)
   */
  clear() {
    this.metrics = [];
  }
}

// Singleton instance
export const metrics = new MetricsCollector();

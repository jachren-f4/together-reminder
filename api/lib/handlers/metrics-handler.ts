/**
 * Metrics Handler - Handles /api/metrics requests
 */

import { NextRequest, NextResponse } from 'next/server';
import { metrics } from '@/lib/monitoring/metrics';

/**
 * Metrics Endpoint - Prometheus-compatible format
 *
 * Provides performance metrics for monitoring dashboards
 */
export async function handleMetricsGET(req: NextRequest): Promise<NextResponse> {
  try {
    const summary = metrics.getSummary();

    // Return metrics in both JSON and Prometheus format
    const metricsData = {
      // Request metrics
      http_requests_total: summary.requests_last_5min,
      http_errors_total: summary.errors_last_5min,
      http_error_rate_percent: parseFloat(summary.error_rate_percent),

      // Latency metrics (milliseconds)
      http_request_duration_p50_ms: summary.latency_p50_ms,
      http_request_duration_p95_ms: summary.latency_p95_ms,
      http_request_duration_p99_ms: summary.latency_p99_ms,

      // Timestamp
      timestamp: new Date().toISOString(),
    };

    return NextResponse.json(metricsData);
  } catch (error) {
    console.error('Metrics endpoint error:', error);
    return NextResponse.json(
      { error: 'Failed to retrieve metrics' },
      { status: 500 }
    );
  }
}

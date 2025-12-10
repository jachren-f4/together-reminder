/**
 * Health Handler - Handles /api/health requests
 */

import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { getPool } from '@/lib/db/pool';
import { metrics } from '@/lib/monitoring/metrics';

interface HealthStatus {
  status: 'healthy' | 'degraded' | 'unhealthy';
  checks: {
    database: {
      status: 'pass' | 'fail';
      response_time_ms?: number;
      connections?: number;
      error?: string;
    };
    api: {
      status: 'pass';
      uptime_seconds: number;
    };
  };
  metrics?: {
    requests_last_5min: number;
    errors_last_5min: number;
    error_rate_percent: string;
    latency_p95_ms: number;
  };
  system: {
    timestamp: string;
    environment: string;
    version?: string;
    node_version: string;
  };
}

export async function handleHealthGET(req: NextRequest): Promise<NextResponse> {
  const startTime = Date.now();
  const health: HealthStatus = {
    status: 'healthy',
    checks: {
      database: { status: 'pass' },
      api: {
        status: 'pass',
        uptime_seconds: Math.floor(process.uptime()),
      },
    },
    system: {
      timestamp: new Date().toISOString(),
      environment: process.env.NODE_ENV || 'development',
      version: process.env.VERCEL_GIT_COMMIT_SHA?.slice(0, 7),
      node_version: process.version,
    },
  };

  try {
    // Check Supabase connection
    const supabase = createClient();
    const dbCheckStart = Date.now();

    const { data, error } = await supabase
      .from('_health_check')
      .select('*')
      .limit(1);

    const dbResponseTime = Date.now() - dbCheckStart;

    if (error && error.code !== 'PGRST116') {
      // PGRST116 = table doesn't exist (OK for initial setup)
      health.checks.database = {
        status: 'fail',
        response_time_ms: dbResponseTime,
        error: error.message,
      };
      health.status = 'degraded';
    } else {
      health.checks.database = {
        status: 'pass',
        response_time_ms: dbResponseTime,
      };

      // Get database connection count
      try {
        const pool = getPool();
        health.checks.database.connections = pool.totalCount;

        // Alert on high connection usage (approaching limit of 60)
        if (pool.totalCount > 50) {
          health.status = 'degraded';
          console.warn(`High DB connection usage: ${pool.totalCount}/60`);
        }
      } catch (poolError) {
        console.warn('Could not get pool stats:', poolError);
      }
    }

    // Add metrics summary
    try {
      const metricsSummary = metrics.getSummary();
      health.metrics = metricsSummary;

      // Check if error rate is too high
      const errorRate = parseFloat(metricsSummary.error_rate_percent);
      if (errorRate > 5) {
        health.status = 'degraded';
      }

      // Check if latency is too high
      if (metricsSummary.latency_p95_ms > 300) {
        health.status = 'degraded';
      }
    } catch (metricsError) {
      console.warn('Could not get metrics summary:', metricsError);
    }

    const statusCode = health.status === 'healthy' ? 200 : 503;

    return NextResponse.json(health, { status: statusCode });
  } catch (error) {
    console.error('Health check failed:', error);

    return NextResponse.json(
      {
        status: 'unhealthy',
        checks: {
          database: {
            status: 'fail',
            error: 'Health check exception',
          },
          api: {
            status: 'pass',
            uptime_seconds: Math.floor(process.uptime()),
          },
        },
        system: {
          timestamp: new Date().toISOString(),
          environment: process.env.NODE_ENV || 'development',
          node_version: process.version,
        },
        error: error instanceof Error ? error.message : 'Unknown error',
      },
      { status: 500 }
    );
  }
}

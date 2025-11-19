/**
 * Monitoring Middleware for Next.js API Routes
 * 
 * Automatically tracks latency and errors for all API requests
 */

import { NextRequest, NextResponse } from 'next/server';
import { metrics } from './metrics';
import { captureError } from './sentry';

/**
 * Wrap API route handler with monitoring
 */
export function withMonitoring(
  handler: (req: NextRequest) => Promise<NextResponse>,
  options?: { routeName?: string }
) {
  return async (req: NextRequest): Promise<NextResponse> => {
    const startTime = Date.now();
    const routeName = options?.routeName || req.nextUrl.pathname;

    try {
      const response = await handler(req);
      const duration = Date.now() - startTime;

      // Record metrics
      metrics.recordLatency(routeName, duration);

      // Add performance headers
      response.headers.set('X-Response-Time', `${duration}ms`);
      response.headers.set('X-Request-ID', crypto.randomUUID());

      return response;
    } catch (error) {
      const duration = Date.now() - startTime;

      // Record error
      metrics.recordError(routeName);
      captureError(error as Error, {
        route: routeName,
        duration_ms: duration,
        method: req.method,
      });

      console.error(`Error in ${routeName}:`, error);

      // Return error response
      return NextResponse.json(
        {
          error: 'Internal server error',
          message: error instanceof Error ? error.message : 'Unknown error',
          request_id: crypto.randomUUID(),
        },
        { status: 500 }
      );
    }
  };
}

/**
 * Middleware for database query monitoring
 */
export function withDbMonitoring<T>(
  queryFn: () => Promise<T>,
  queryName: string
): Promise<T> {
  const startTime = Date.now();

  return queryFn()
    .then(result => {
      const duration = Date.now() - startTime;
      
      if (duration > 100) {
        console.warn(`Slow database query: ${queryName} took ${duration}ms`);
      }

      return result;
    })
    .catch(error => {
      const duration = Date.now() - startTime;
      
      captureError(error as Error, {
        query_name: queryName,
        duration_ms: duration,
      });

      throw error;
    });
}

/**
 * Rate Limiting Middleware
 * 
 * Prevents abuse by limiting request frequency
 * - Auth endpoints: 60 requests/minute per IP
 * - Sync endpoints: 120 requests/minute per user
 */

import { NextRequest, NextResponse } from 'next/server';

interface RateLimitEntry {
  count: number;
  resetAt: number;
}

// In-memory rate limit store (use Redis in production for multi-instance)
const rateLimitStore = new Map<string, RateLimitEntry>();

// Clean up expired entries every 5 minutes
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of rateLimitStore.entries()) {
    if (entry.resetAt < now) {
      rateLimitStore.delete(key);
    }
  }
}, 5 * 60 * 1000);

export interface RateLimitConfig {
  maxRequests: number;
  windowMs: number; // Time window in milliseconds
  keyGenerator?: (req: NextRequest) => string;
}

/**
 * Default rate limit configurations
 */
export const RateLimitPresets = {
  // Auth endpoints: 60 requests/minute per IP
  auth: {
    maxRequests: 60,
    windowMs: 60 * 1000,
    keyGenerator: (req: NextRequest) => {
      // Use IP address or x-forwarded-for
      const ip = req.headers.get('x-forwarded-for') || 
                 req.headers.get('x-real-ip') || 
                 'unknown';
      return `auth:${ip}`;
    },
  },

  // Sync endpoints: 120 requests/minute per user
  sync: {
    maxRequests: 120,
    windowMs: 60 * 1000,
    keyGenerator: (req: NextRequest) => {
      // Requires userId to be attached by auth middleware
      const userId = (req as any).userId || 'anonymous';
      return `sync:${userId}`;
    },
  },

  // Strict rate limit for sensitive operations
  strict: {
    maxRequests: 10,
    windowMs: 60 * 1000,
    keyGenerator: (req: NextRequest) => {
      const ip = req.headers.get('x-forwarded-for') || 'unknown';
      return `strict:${ip}`;
    },
  },
};

/**
 * Check rate limit for a request
 * 
 * @param req - Next.js request
 * @param config - Rate limit configuration
 * @returns true if request is within limit, false if exceeded
 */
export function checkRateLimit(
  req: NextRequest,
  config: RateLimitConfig
): { allowed: boolean; remaining: number; resetAt: number } {
  const key = config.keyGenerator 
    ? config.keyGenerator(req)
    : req.nextUrl.pathname;

  const now = Date.now();
  const entry = rateLimitStore.get(key);

  // No entry or expired - allow request
  if (!entry || entry.resetAt < now) {
    rateLimitStore.set(key, {
      count: 1,
      resetAt: now + config.windowMs,
    });

    return {
      allowed: true,
      remaining: config.maxRequests - 1,
      resetAt: now + config.windowMs,
    };
  }

  // Entry exists and not expired
  if (entry.count >= config.maxRequests) {
    // Rate limit exceeded
    return {
      allowed: false,
      remaining: 0,
      resetAt: entry.resetAt,
    };
  }

  // Increment count
  entry.count++;
  rateLimitStore.set(key, entry);

  return {
    allowed: true,
    remaining: config.maxRequests - entry.count,
    resetAt: entry.resetAt,
  };
}

/**
 * Rate limit middleware wrapper
 * 
 * Usage:
 * ```typescript
 * export const POST = withRateLimit(
 *   RateLimitPresets.auth,
 *   async (req) => {
 *     // Your route logic
 *   }
 * );
 * ```
 */
export function withRateLimit(
  config: RateLimitConfig,
  handler: (req: NextRequest) => Promise<NextResponse>
) {
  return async (req: NextRequest): Promise<NextResponse> => {
    const result = checkRateLimit(req, config);

    if (!result.allowed) {
      const retryAfter = Math.ceil((result.resetAt - Date.now()) / 1000);

      return NextResponse.json(
        {
          error: 'Rate limit exceeded',
          retryAfter: retryAfter,
          resetAt: new Date(result.resetAt).toISOString(),
        },
        {
          status: 429,
          headers: {
            'Retry-After': retryAfter.toString(),
            'X-RateLimit-Limit': config.maxRequests.toString(),
            'X-RateLimit-Remaining': '0',
            'X-RateLimit-Reset': result.resetAt.toString(),
          },
        }
      );
    }

    // Add rate limit headers to successful responses
    const response = await handler(req);
    
    response.headers.set('X-RateLimit-Limit', config.maxRequests.toString());
    response.headers.set('X-RateLimit-Remaining', result.remaining.toString());
    response.headers.set('X-RateLimit-Reset', result.resetAt.toString());

    return response;
  };
}

/**
 * Combine auth + rate limiting
 * 
 * Usage:
 * ```typescript
 * export const POST = withAuthAndRateLimit(
 *   RateLimitPresets.sync,
 *   async (req, userId) => {
 *     // Authenticated and rate-limited route logic
 *   }
 * );
 * ```
 */
export function withAuthAndRateLimit(
  config: RateLimitConfig,
  handler: (req: NextRequest, userId: string) => Promise<NextResponse>
) {
  return withRateLimit(config, async (req: NextRequest) => {
    // Import here to avoid circular dependency
    const { authenticate } = await import('./middleware');
    const authResult = authenticate(req);

    if (authResult instanceof NextResponse) {
      return authResult; // Auth error
    }

    // Attach userId for rate limit key generation
    (req as any).userId = authResult.userId;

    return handler(req, authResult.userId);
  });
}

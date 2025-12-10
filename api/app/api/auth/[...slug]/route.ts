/**
 * Consolidated Auth Routes
 *
 * Handles:
 * - verify → GET verify auth token
 *
 * Usage:
 * curl -H "Authorization: Bearer <token>" https://api.example.com/api/auth/verify
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuth } from '@/lib/auth/middleware';
import { RateLimitPresets, withRateLimit } from '@/lib/auth/rate-limit';

export const dynamic = 'force-dynamic';

/**
 * GET handler for auth routes
 */
export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ slug: string[] }> }
) {
  const { slug } = await params;
  const path = slug?.join('/') || '';

  // Route: verify
  if (path === 'verify') {
    return withRateLimit(
      RateLimitPresets.auth,
      withAuth(async (req, userId, email) => {
        return NextResponse.json({
          authenticated: true,
          userId,
          email,
          timestamp: new Date().toISOString(),
        });
      })
    )(req);
  }

  return NextResponse.json({ error: 'Not found' }, { status: 404 });
}

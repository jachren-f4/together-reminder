/**
 * Auth Router - Routes /api/auth/* requests
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuth } from '@/lib/auth/middleware';
import { RateLimitPresets, withRateLimit } from '@/lib/auth/rate-limit';

/**
 * Route GET requests for auth endpoints
 */
export function routeAuthGET(req: NextRequest, subPath: string[]): Promise<NextResponse> {
  const path = subPath.join('/');

  switch (path) {
    case 'verify':
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
    default:
      return Promise.resolve(
        NextResponse.json({ error: `Unknown auth route: ${path}` }, { status: 404 })
      );
  }
}

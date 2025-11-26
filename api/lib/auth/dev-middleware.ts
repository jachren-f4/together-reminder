/**
 * Development Authentication Bypass Middleware
 *
 * SECURITY: Only active when NODE_ENV=development AND AUTH_DEV_BYPASS_ENABLED=true
 *
 * Allows skipping JWT email authentication during development to improve
 * developer productivity while maintaining production security.
 */

import { NextRequest, NextResponse } from 'next/server';
import { AuthenticatedRequest, RouteContext, withAuth } from './middleware';

/**
 * Check if development bypass is enabled
 *
 * Requirements:
 * 1. NODE_ENV must be 'development'
 * 2. AUTH_DEV_BYPASS_ENABLED must be explicitly 'true'
 *
 * This dual-check prevents accidental bypass in production
 */
function isDevBypassEnabled(): boolean {
  return (
    process.env.NODE_ENV === 'development' &&
    process.env.AUTH_DEV_BYPASS_ENABLED === 'true'
  );
}

/**
 * Get development user credentials from request or environment
 *
 * Priority:
 * 1. X-Dev-User-Id header (for per-device user IDs)
 * 2. AUTH_DEV_USER_ID from .env.local
 * 3. Fallback to default test value
 *
 * This allows two devices to test as different users:
 * - Android: Send X-Dev-User-Id: user1_id
 * - Chrome: Send X-Dev-User-Id: user2_id
 */
function getDevCredentials(req: NextRequest): { userId: string; email: string } {
  // Check for per-device user ID in header
  const headerUserId = req.headers.get('X-Dev-User-Id');

  const userId = headerUserId || process.env.AUTH_DEV_USER_ID || 'dev-test-user-id';

  return {
    userId,
    email: process.env.AUTH_DEV_USER_EMAIL || 'dev@togetherremind.local',
  };
}

/**
 * Development-friendly auth wrapper
 *
 * In development with bypass enabled:
 * - Skips JWT verification
 * - Uses test userId from environment variables
 * - Logs bypass activation for visibility
 *
 * In production or when bypass disabled:
 * - Falls back to normal JWT authentication
 * - Same security as withAuth()
 *
 * Usage:
 * ```typescript
 * export const POST = withAuthOrDevBypass(async (req, userId, email, context) => {
 *   // Works in dev without JWT, requires JWT in prod
 *   const { matchId } = await context.params;
 *   return NextResponse.json({ userId, matchId });
 * });
 * ```
 */
export function withAuthOrDevBypass(
  handler: (req: AuthenticatedRequest, userId: string, email?: string, context?: RouteContext) => Promise<NextResponse>
) {
  return async (req: NextRequest, context?: RouteContext): Promise<NextResponse> => {
    // Check if dev bypass is enabled
    if (isDevBypassEnabled()) {
      const credentials = getDevCredentials(req);

      const headerUserId = req.headers.get('X-Dev-User-Id');
      const source = headerUserId ? 'X-Dev-User-Id header' : '.env.local';

      // Log bypass activation (warn level for visibility)
      console.warn(
        `[DEV AUTH BYPASS] Active for userId: ${credentials.userId} (from ${source}) | ` +
        `Email: ${credentials.email} | ` +
        `Endpoint: ${req.nextUrl.pathname}`
      );

      // Attach dev credentials to request
      const authenticatedReq = req as AuthenticatedRequest;
      authenticatedReq.userId = credentials.userId;
      authenticatedReq.userEmail = credentials.email;

      // Call handler with dev credentials and context (for dynamic route params)
      const response = await handler(authenticatedReq, credentials.userId, credentials.email, context);

      // Add CORS headers for dev mode (browser requests from Flutter web)
      response.headers.set('Access-Control-Allow-Origin', '*');
      response.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Dev-User-Id');

      return response;
    }

    // Production or bypass disabled: use normal JWT auth
    return withAuth(handler)(req, context);
  };
}

/**
 * Export for testing/debugging
 */
export const _internal = {
  isDevBypassEnabled,
};

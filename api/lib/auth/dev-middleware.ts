/**
 * Authentication Middleware Wrapper
 *
 * This module provides withAuthOrDevBypass which is an alias for withAuth.
 * All API routes use JWT authentication via Supabase.
 */

import { withAuth } from './middleware';

/**
 * Auth wrapper for API routes.
 *
 * This is an alias for withAuth - all requests require valid JWT authentication.
 *
 * Usage:
 * ```typescript
 * export const POST = withAuthOrDevBypass(async (req, userId, email, context) => {
 *   const { matchId } = await context.params;
 *   return NextResponse.json({ userId, matchId });
 * });
 * ```
 */
export const withAuthOrDevBypass = withAuth;

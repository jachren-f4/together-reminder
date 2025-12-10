/**
 * Authentication Middleware for Next.js API Routes
 * 
 * Provides JWT verification with sub-millisecond performance
 */

import { NextRequest, NextResponse } from 'next/server';
import { verifyToken, extractToken } from './jwt';
import { metrics } from '../monitoring/metrics';

export interface AuthenticatedRequest extends NextRequest {
  userId?: string;
  userEmail?: string;
}

/**
 * Context type for dynamic route parameters
 * Supports both regular dynamic routes (string) and catch-all routes (string[])
 */
export interface RouteContext {
  params: Promise<Record<string, string | string[]>> | Record<string, string | string[]>;
}

/**
 * Authenticate request using JWT token
 * 
 * @param req - Next.js request object
 * @returns Authenticated user info or error response
 */
export function authenticate(
  req: NextRequest
): { userId: string; email?: string } | NextResponse {
  const authHeader = req.headers.get('Authorization');
  const token = extractToken(authHeader);

  if (!token) {
    return NextResponse.json(
      { error: 'No authorization token provided' },
      { status: 401 }
    );
  }

  const startTime = performance.now();
  const result = verifyToken(token);
  const verificationTime = performance.now() - startTime;

  // Track JWT verification performance
  if (verificationTime > 1) {
    console.warn(`JWT verification took ${verificationTime.toFixed(2)}ms`);
  }

  if (!result.valid) {
    metrics.recordError(req.nextUrl.pathname);
    
    return NextResponse.json(
      { error: result.error || 'Invalid token' },
      { status: 401 }
    );
  }

  return {
    userId: result.userId!,
    email: result.email,
  };
}

/**
 * Wrap API route handler with authentication
 *
 * Usage:
 * ```typescript
 * export const GET = withAuth(async (req, userId, email, context) => {
 *   // Your authenticated route logic
 *   const { matchId } = await context.params;
 *   return NextResponse.json({ userId, matchId });
 * });
 * ```
 */
export function withAuth(
  handler: (req: AuthenticatedRequest, userId: string, email?: string, context?: RouteContext) => Promise<NextResponse>
) {
  return async (req: NextRequest, context?: RouteContext): Promise<NextResponse> => {
    const authResult = authenticate(req);

    // If authResult is a NextResponse, it's an error
    if (authResult instanceof NextResponse) {
      return authResult;
    }

    // Attach user info to request
    const authenticatedReq = req as AuthenticatedRequest;
    authenticatedReq.userId = authResult.userId;
    authenticatedReq.userEmail = authResult.email;

    // Call the actual handler with context (for dynamic route params)
    return handler(authenticatedReq, authResult.userId, authResult.email, context);
  };
}

/**
 * Optional authentication - doesn't fail if no token provided
 * 
 * Useful for endpoints that work for both authenticated and anonymous users
 */
export function withOptionalAuth(
  handler: (req: AuthenticatedRequest, userId?: string, email?: string) => Promise<NextResponse>
) {
  return async (req: NextRequest): Promise<NextResponse> => {
    const authHeader = req.headers.get('Authorization');
    const token = extractToken(authHeader);

    let userId: string | undefined;
    let email: string | undefined;

    // Try to authenticate if token provided
    if (token) {
      const result = verifyToken(token);
      if (result.valid) {
        userId = result.userId;
        email = result.email;
      }
    }

    // Attach user info if authenticated
    const authenticatedReq = req as AuthenticatedRequest;
    if (userId) {
      authenticatedReq.userId = userId;
      authenticatedReq.userEmail = email;
    }

    return handler(authenticatedReq, userId, email);
  };
}

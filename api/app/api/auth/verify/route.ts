/**
 * Auth Verification Endpoint
 * 
 * Example endpoint demonstrating JWT authentication
 * 
 * Usage:
 * curl -H "Authorization: Bearer <token>" https://api.example.com/api/auth/verify
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuth } from '@/lib/auth/middleware';
import { RateLimitPresets, withRateLimit } from '@/lib/auth/rate-limit';

export const dynamic = 'force-dynamic';

/**
 * Verify JWT token and return user info
 * 
 * Rate limited to 60 requests/minute per IP
 */
export const GET = withRateLimit(
  RateLimitPresets.auth,
  withAuth(async (req, userId, email) => {
    return NextResponse.json({
      authenticated: true,
      userId,
      email,
      timestamp: new Date().toISOString(),
    });
  })
);

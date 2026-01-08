/**
 * Dev Endpoint: Award LP directly
 *
 * POST /api/dev/award-lp
 *
 * Awards LP to a couple for testing purposes.
 * Useful for testing magnet unlocks without completing games.
 *
 * Supports both:
 * - JWT auth (Authorization: Bearer <token>)
 * - Dev bypass (X-Dev-User-Id header)
 *
 * Request body:
 * {
 *   amount?: number  // Default: 30
 * }
 *
 * Response:
 * {
 *   success: true,
 *   newTotal: number,
 *   awarded: number
 * }
 */

import { NextRequest, NextResponse } from 'next/server';
import { awardLP } from '@/lib/lp/award';
import { getCoupleId } from '@/lib/couple/utils';
import { randomUUID } from 'crypto';
import { verifyToken, extractToken } from '@/lib/auth/jwt';

export const dynamic = 'force-dynamic';

// Only allow in dev mode
const IS_DEV = process.env.NODE_ENV === 'development';

export async function POST(req: NextRequest) {
  // Security: Only allow in development
  if (!IS_DEV) {
    return NextResponse.json(
      { error: 'Dev endpoints disabled in production' },
      { status: 403 }
    );
  }

  try {
    // Try to get userId from JWT first, then fall back to X-Dev-User-Id
    let userId: string | null = null;

    // Check for JWT token
    const authHeader = req.headers.get('Authorization');
    const token = extractToken(authHeader);
    if (token) {
      const result = verifyToken(token);
      if (result.valid && result.userId) {
        userId = result.userId;
      }
    }

    // Fall back to dev bypass header
    if (!userId) {
      userId = req.headers.get('X-Dev-User-Id');
    }

    if (!userId) {
      return NextResponse.json(
        { error: 'Authorization required (JWT or X-Dev-User-Id header)' },
        { status: 401 }
      );
    }

    const body = await req.json().catch(() => ({}));
    const amount = body.amount ?? 30;

    if (amount <= 0 || amount > 1000) {
      return NextResponse.json(
        { error: 'Amount must be between 1 and 1000' },
        { status: 400 }
      );
    }

    // Get couple ID
    const coupleId = await getCoupleId(userId);
    if (!coupleId) {
      return NextResponse.json(
        { error: `User ${userId} not in a couple` },
        { status: 404 }
      );
    }

    // Award LP with unique ID to avoid idempotency issues
    const uniqueId = `dev_award_${randomUUID().slice(0, 8)}`;
    const result = await awardLP(coupleId, amount, 'dev_award', uniqueId);

    return NextResponse.json({
      success: true,
      newTotal: result.newTotal,
      awarded: result.awarded,
    });
  } catch (error) {
    console.error('Error awarding LP:', error);
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Unknown error' },
      { status: 500 }
    );
  }
}

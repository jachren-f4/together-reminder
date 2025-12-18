/**
 * LP Status Endpoint
 *
 * Returns LP grant status for all content types.
 * Used by intro screens to show whether LP can be earned.
 *
 * GET /api/sync/lp/status
 *
 * Response:
 * {
 *   success: true,
 *   status: {
 *     classic_quiz: { alreadyGrantedToday: false, canPlayMore: true },
 *     affirmation_quiz: { alreadyGrantedToday: true, canPlayMore: true },
 *     you_or_me: { alreadyGrantedToday: false, canPlayMore: true },
 *     linked: { alreadyGrantedToday: true, canPlayMore: true },
 *     word_search: { alreadyGrantedToday: false, canPlayMore: true },
 *   },
 *   resetInMs: 43200000,  // Time until LP resets (same for all)
 *   resetAt: "2025-12-18T00:00:00.000Z"  // ISO timestamp of reset
 * }
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { getLpDay, getTimeUntilReset, isUnlimitedContentAllowed, LpContentType } from '@/lib/lp/daily-reset';

export const dynamic = 'force-dynamic';

const CONTENT_TYPES: LpContentType[] = [
  'classic_quiz',
  'affirmation_quiz',
  'you_or_me',
  'linked',
  'word_search',
];

export const GET = withAuthOrDevBypass(async (req: NextRequest, userId: string) => {
  try {
    // Get couple ID
    const coupleResult = await query(
      `SELECT id FROM couples WHERE user1_id = $1 OR user2_id = $1 LIMIT 1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json(
        { error: 'User is not part of a couple' },
        { status: 404 }
      );
    }

    const coupleId = coupleResult.rows[0].id;
    const lpDay = getLpDay();
    const resetInMs = getTimeUntilReset();
    const canPlayMore = isUnlimitedContentAllowed();

    // Get all grants for today
    const grantsResult = await query(
      `SELECT content_type FROM daily_lp_grants
       WHERE couple_id = $1 AND lp_day = $2`,
      [coupleId, lpDay]
    );

    const grantedTypes = new Set(grantsResult.rows.map(r => r.content_type));

    // Build status for each content type
    const status: Record<string, { alreadyGrantedToday: boolean; canPlayMore: boolean }> = {};
    for (const contentType of CONTENT_TYPES) {
      status[contentType] = {
        alreadyGrantedToday: grantedTypes.has(contentType),
        canPlayMore,
      };
    }

    // Calculate reset timestamp
    const now = new Date();
    const resetAt = new Date(now.getTime() + resetInMs);

    return NextResponse.json({
      success: true,
      status,
      resetInMs,
      resetAt: resetAt.toISOString(),
      lpDay,
    });
  } catch (error) {
    console.error('Error in LP status endpoint:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
});

/**
 * Us Profile API
 *
 * GET /api/us-profile - Get framed profile for the user's couple
 * POST /api/us-profile - Force recalculate profile cache
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { getCoupleBasic } from '@/lib/couple/utils';
import {
  getFramedProfile,
  recalculateAndCacheProfile,
  getActiveConversationStarters,
} from '@/lib/us-profile';

export const dynamic = 'force-dynamic';

/**
 * GET /api/us-profile
 *
 * Get framed profile for the authenticated user's couple.
 * Includes all insights, discoveries, and conversation starters.
 */
export const GET = withAuthOrDevBypass(async (req, userId) => {
  try {
    // Get couple info
    const couple = await getCoupleBasic(userId);
    if (!couple) {
      return NextResponse.json(
        { error: 'User is not part of a couple' },
        { status: 404 }
      );
    }

    // Get framed profile (from cache or fresh calculation)
    const profile = await getFramedProfile(couple.coupleId);

    // Get active conversation starters
    const starters = await getActiveConversationStarters(couple.coupleId);

    // Determine which user is user1 vs user2 for the client
    const userRole = couple.isPlayer1 ? 'user1' : 'user2';

    return NextResponse.json({
      success: true,
      profile,
      starters,
      userRole,
    });
  } catch (error) {
    console.error('Error fetching Us Profile:', error);
    return NextResponse.json(
      { error: 'Failed to fetch profile' },
      { status: 500 }
    );
  }
});

/**
 * POST /api/us-profile
 *
 * Force recalculation of profile cache.
 * Useful for manual refresh or after bulk operations.
 */
export const POST = withAuthOrDevBypass(async (req, userId) => {
  try {
    // Get couple info
    const couple = await getCoupleBasic(userId);
    if (!couple) {
      return NextResponse.json(
        { error: 'User is not part of a couple' },
        { status: 404 }
      );
    }

    // Force recalculation
    const rawProfile = await recalculateAndCacheProfile(couple.coupleId);

    // Get framed profile
    const profile = await getFramedProfile(couple.coupleId);

    // Get active conversation starters
    const starters = await getActiveConversationStarters(couple.coupleId);

    // Determine which user is user1 vs user2 for the client
    const userRole = couple.isPlayer1 ? 'user1' : 'user2';

    return NextResponse.json({
      success: true,
      recalculated: true,
      profile,
      starters,
      userRole,
    });
  } catch (error) {
    console.error('Error recalculating Us Profile:', error);
    return NextResponse.json(
      { error: 'Failed to recalculate profile' },
      { status: 500 }
    );
  }
});

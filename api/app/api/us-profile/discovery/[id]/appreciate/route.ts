/**
 * Discovery Appreciation API
 *
 * POST /api/us-profile/discovery/{id}/appreciate - Toggle appreciation for a discovery
 *
 * This endpoint allows users to "appreciate" discoveries, which:
 * - Signals to their partner that this insight resonated with them
 * - Affects relevance scoring (appreciated discoveries are boosted for partners)
 * - Creates a social dynamic within the couple's profile
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { RouteContext } from '@/lib/auth/middleware';
import { getCoupleBasic } from '@/lib/couple/utils';
import { toggleAppreciation, getDiscoveryAppreciations } from '@/lib/us-profile/relevance';

export const dynamic = 'force-dynamic';

/**
 * POST /api/us-profile/discovery/{id}/appreciate
 *
 * Toggle appreciation state for a discovery.
 * Returns the new appreciation state.
 */
export const POST = withAuthOrDevBypass(async (
  req: NextRequest,
  userId: string,
  email?: string,
  context?: RouteContext
) => {
  try {
    const params = context?.params;
    const resolvedParams = params instanceof Promise ? await params : params;
    const rawId = resolvedParams?.id;
    const discoveryId = Array.isArray(rawId) ? rawId[0] : rawId;

    if (!discoveryId) {
      return NextResponse.json(
        { error: 'Discovery ID is required' },
        { status: 400 }
      );
    }

    // Get couple info
    const couple = await getCoupleBasic(userId);
    if (!couple) {
      return NextResponse.json(
        { error: 'User is not part of a couple' },
        { status: 404 }
      );
    }

    // Toggle appreciation
    const isAppreciated = await toggleAppreciation(
      couple.coupleId,
      discoveryId,
      userId
    );

    // Get updated appreciation state for this discovery
    const { user1Id, user2Id } = await getCoupleUserIds(couple.coupleId);
    const appreciationsMap = await getDiscoveryAppreciations(
      couple.coupleId,
      user1Id,
      user2Id
    );

    const appreciation = appreciationsMap[discoveryId];
    const isUser1 = userId === user1Id;

    // Build response with full appreciation state
    const userAppreciated = isUser1
      ? (appreciation?.user1Appreciated ?? false)
      : (appreciation?.user2Appreciated ?? false);
    const partnerAppreciated = isUser1
      ? (appreciation?.user2Appreciated ?? false)
      : (appreciation?.user1Appreciated ?? false);

    // Get partner name for label
    const partnerName = await getPartnerName(couple.coupleId, userId);

    return NextResponse.json({
      success: true,
      appreciated: isAppreciated,
      discovery: {
        id: discoveryId,
        appreciation: {
          userAppreciated,
          partnerAppreciated,
          partnerAppreciatedLabel: partnerAppreciated
            ? `${partnerName} appreciates this insight`
            : null,
          mutualAppreciation: userAppreciated && partnerAppreciated,
        },
      },
    });
  } catch (error) {
    console.error('Error toggling discovery appreciation:', error);
    return NextResponse.json(
      { error: 'Failed to toggle appreciation' },
      { status: 500 }
    );
  }
});

/**
 * Helper: Get user IDs for a couple
 */
async function getCoupleUserIds(coupleId: string): Promise<{ user1Id: string; user2Id: string }> {
  const { query } = await import('@/lib/db/pool');
  const result = await query(
    `SELECT user1_id, user2_id FROM couples WHERE id = $1`,
    [coupleId]
  );

  if (result.rows.length === 0) {
    throw new Error('Couple not found');
  }

  return {
    user1Id: result.rows[0].user1_id,
    user2Id: result.rows[0].user2_id,
  };
}

/**
 * Helper: Get partner's name
 */
async function getPartnerName(coupleId: string, userId: string): Promise<string> {
  const { query } = await import('@/lib/db/pool');
  const result = await query(
    `SELECT
       CASE WHEN c.user1_id = $2
         THEN COALESCE(u2.raw_user_meta_data->>'full_name', 'Partner')
         ELSE COALESCE(u1.raw_user_meta_data->>'full_name', 'Partner')
       END as partner_name
     FROM couples c
     JOIN auth.users u1 ON c.user1_id = u1.id
     JOIN auth.users u2 ON c.user2_id = u2.id
     WHERE c.id = $1`,
    [coupleId, userId]
  );

  if (result.rows.length === 0) {
    return 'Partner';
  }

  return result.rows[0].partner_name || 'Partner';
}

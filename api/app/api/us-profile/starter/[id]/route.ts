/**
 * Conversation Starter Actions API
 *
 * POST /api/us-profile/starter/{id} - Update starter state (dismiss/discussed)
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { RouteContext } from '@/lib/auth/middleware';
import { getCoupleBasic } from '@/lib/couple/utils';
import { query } from '@/lib/db/pool';

export const dynamic = 'force-dynamic';

/**
 * POST /api/us-profile/starter/{id}
 *
 * Update a conversation starter's state.
 *
 * Body: {
 *   action: 'dismiss' | 'discussed'
 * }
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
    const starterId = resolvedParams?.id;

    if (!starterId) {
      return NextResponse.json(
        { error: 'Missing starter ID' },
        { status: 400 }
      );
    }

    const body = await req.json();
    const { action } = body;

    if (!action || !['dismiss', 'discussed'].includes(action)) {
      return NextResponse.json(
        { error: 'Invalid action. Must be "dismiss" or "discussed"' },
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

    // Verify starter belongs to this couple
    const starterResult = await query(
      `SELECT id, couple_id FROM conversation_starters WHERE id = $1`,
      [starterId]
    );

    if (starterResult.rows.length === 0) {
      return NextResponse.json(
        { error: 'Starter not found' },
        { status: 404 }
      );
    }

    if (starterResult.rows[0].couple_id !== couple.coupleId) {
      return NextResponse.json(
        { error: 'Starter does not belong to this couple' },
        { status: 403 }
      );
    }

    // Update starter based on action
    if (action === 'dismiss') {
      await query(
        `UPDATE conversation_starters SET dismissed = TRUE WHERE id = $1`,
        [starterId]
      );
    } else if (action === 'discussed') {
      await query(
        `UPDATE conversation_starters SET discussed = TRUE WHERE id = $1`,
        [starterId]
      );
    }

    return NextResponse.json({
      success: true,
      action,
      starterId,
    });
  } catch (error) {
    console.error('Error updating conversation starter:', error);
    return NextResponse.json(
      { error: 'Failed to update starter' },
      { status: 500 }
    );
  }
});

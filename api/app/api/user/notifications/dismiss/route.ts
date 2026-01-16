/**
 * Dismiss Notification Endpoint
 *
 * POST /api/user/notifications/dismiss
 * Marks a notification as read
 *
 * Body: { notificationId: string }
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuth } from '@/lib/auth/middleware';
import { getPool } from '@/lib/db/pool';

export const dynamic = 'force-dynamic';

export const POST = withAuth(async (req: NextRequest, userId) => {
  try {
    const body = await req.json();
    const { notificationId } = body;

    if (!notificationId) {
      return NextResponse.json(
        { error: 'notificationId is required' },
        { status: 400 }
      );
    }

    // Mark as read (only if it belongs to this user)
    const pool = getPool();
    const result = await pool.query(
      `UPDATE user_notifications
       SET read_at = NOW()
       WHERE id = $1 AND user_id = $2 AND read_at IS NULL
       RETURNING id`,
      [notificationId, userId]
    );

    if (result.rowCount === 0) {
      return NextResponse.json(
        { error: 'Notification not found or already dismissed' },
        { status: 404 }
      );
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('[Notifications] Error dismissing notification:', error);
    return NextResponse.json(
      { error: 'Failed to dismiss notification' },
      { status: 500 }
    );
  }
});

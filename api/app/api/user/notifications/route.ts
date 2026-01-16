/**
 * User Notifications Endpoint
 *
 * GET /api/user/notifications
 * Returns unread notifications for the authenticated user
 */

import { NextResponse } from 'next/server';
import { withAuth } from '@/lib/auth/middleware';
import { getPool } from '@/lib/db/pool';

export const dynamic = 'force-dynamic';

export const GET = withAuth(async (req, userId) => {
  try {
    const pool = getPool();
    const result = await pool.query(
      `SELECT id, type, message, created_at
       FROM user_notifications
       WHERE user_id = $1 AND read_at IS NULL
       ORDER BY created_at DESC`,
      [userId]
    );

    return NextResponse.json({
      notifications: result.rows.map(row => ({
        id: row.id,
        type: row.type,
        message: row.message,
        createdAt: row.created_at,
      })),
    });
  } catch (error) {
    console.error('[Notifications] Error fetching notifications:', error);
    return NextResponse.json(
      { error: 'Failed to fetch notifications' },
      { status: 500 }
    );
  }
});

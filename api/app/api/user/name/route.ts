/**
 * User Name Update Endpoint
 *
 * Updates the user's display name in auth.users metadata.
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuth } from '@/lib/auth/middleware';
import { RateLimitPresets, withRateLimit } from '@/lib/auth/rate-limit';
import { query } from '@/lib/db/pool';

export const dynamic = 'force-dynamic';

// Handle CORS preflight
export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    },
  });
}

/**
 * Update user's display name
 *
 * PATCH /api/user/name
 * Body: { name: string }
 *
 * Returns: { user: { id, email, name, updatedAt } }
 */
export const PATCH = withRateLimit(
  RateLimitPresets.sync,
  withAuth(async (req, userId, email) => {
    try {
      const body = await req.json();
      const { name } = body;

      // Validate name
      if (!name || typeof name !== 'string') {
        return NextResponse.json(
          { error: 'Name is required' },
          { status: 400 }
        );
      }

      const trimmedName = name.trim();
      if (trimmedName.length === 0) {
        return NextResponse.json(
          { error: 'Name cannot be empty' },
          { status: 400 }
        );
      }

      if (trimmedName.length > 50) {
        return NextResponse.json(
          { error: 'Name is too long (max 50 characters)' },
          { status: 400 }
        );
      }

      // Update name in auth.users metadata
      const result = await query(
        `UPDATE auth.users
         SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || $1::jsonb,
             updated_at = NOW()
         WHERE id = $2
         RETURNING id, email, updated_at, raw_user_meta_data`,
        [JSON.stringify({ full_name: trimmedName }), userId]
      );

      if (result.rows.length === 0) {
        return NextResponse.json(
          { error: 'User not found' },
          { status: 404 }
        );
      }

      const updatedUser = result.rows[0];

      console.log(`[UserName] User ${userId} updated name to: ${trimmedName}`);

      return NextResponse.json({
        user: {
          id: updatedUser.id,
          email: updatedUser.email,
          name: trimmedName,
          updatedAt: updatedUser.updated_at,
        },
      });
    } catch (error) {
      console.error('Error updating user name:', error);
      return NextResponse.json(
        { error: 'Failed to update name' },
        { status: 500 }
      );
    }
  })
);

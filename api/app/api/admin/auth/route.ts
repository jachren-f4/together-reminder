/**
 * Admin Authentication API
 *
 * POST - Login with email
 * GET - Validate current session
 * DELETE - Logout
 */

import { NextRequest, NextResponse } from 'next/server';
import {
  isAllowedEmail,
  createSessionToken,
  setAdminSession,
  getAdminSession,
  clearAdminSession,
} from '@/lib/admin/auth';

export const dynamic = 'force-dynamic';

/**
 * POST /api/admin/auth
 * Login with email - checks allowlist and sets session cookie
 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { email } = body;

    if (!email || typeof email !== 'string') {
      return NextResponse.json(
        { error: 'Email is required' },
        { status: 400 }
      );
    }

    const normalizedEmail = email.trim().toLowerCase();

    if (!isAllowedEmail(normalizedEmail)) {
      return NextResponse.json(
        { error: 'This email is not authorized to access the admin dashboard' },
        { status: 403 }
      );
    }

    // Create session token and set cookie
    const token = createSessionToken(normalizedEmail);
    await setAdminSession(token);

    return NextResponse.json({
      success: true,
      email: normalizedEmail,
    });
  } catch (error) {
    console.error('Admin auth error:', error);
    return NextResponse.json(
      { error: 'Authentication failed' },
      { status: 500 }
    );
  }
}

/**
 * GET /api/admin/auth
 * Validate current session and return user info
 */
export async function GET() {
  try {
    const session = await getAdminSession();

    if (!session) {
      return NextResponse.json(
        { authenticated: false },
        { status: 401 }
      );
    }

    return NextResponse.json({
      authenticated: true,
      email: session.email,
      expiresAt: new Date(session.exp * 1000).toISOString(),
    });
  } catch (error) {
    console.error('Admin auth check error:', error);
    return NextResponse.json(
      { authenticated: false, error: 'Session check failed' },
      { status: 500 }
    );
  }
}

/**
 * DELETE /api/admin/auth
 * Logout - clears session cookie
 */
export async function DELETE() {
  try {
    await clearAdminSession();

    return NextResponse.json({
      success: true,
      message: 'Logged out successfully',
    });
  } catch (error) {
    console.error('Admin logout error:', error);
    return NextResponse.json(
      { error: 'Logout failed' },
      { status: 500 }
    );
  }
}

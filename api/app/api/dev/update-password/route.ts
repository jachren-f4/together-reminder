/**
 * Development Only: Update user password via admin API for dev sign-in
 *
 * This endpoint allows updating a user's password when they were created via OTP
 * but dev mode needs password-based sign-in.
 *
 * Security: Only active when AUTH_DEV_BYPASS_ENABLED=true
 */

import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.SUPABASE_URL!;
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

/**
 * POST /api/dev/update-password
 * Body: { email: string, password: string }
 *
 * Updates the user's password using admin API, allowing dev sign-in to work
 * for users who were originally created via OTP.
 */
export async function POST(request: NextRequest) {
  // Only allow when dev bypass is explicitly enabled
  if (process.env.AUTH_DEV_BYPASS_ENABLED !== 'true') {
    return NextResponse.json(
      { error: 'Dev endpoints disabled in production' },
      { status: 403 }
    );
  }

  try {
    const body = await request.json();
    const { email, password } = body;

    if (!email || !password) {
      return NextResponse.json(
        { error: 'email and password are required' },
        { status: 400 }
      );
    }

    console.log(`[DEV] Updating password for: ${email}`);

    // Create Supabase admin client
    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // 1. Find user by email
    const { data: users, error: listError } = await supabase.auth.admin.listUsers();

    if (listError) {
      console.error('[DEV] Error listing users:', listError);
      return NextResponse.json(
        { error: 'Failed to list users', details: listError.message },
        { status: 500 }
      );
    }

    const user = users.users.find(u => u.email?.toLowerCase() === email.toLowerCase());

    if (!user) {
      console.log(`[DEV] User not found: ${email}`);
      return NextResponse.json(
        { error: 'User not found', email },
        { status: 404 }
      );
    }

    console.log(`[DEV] Found user: ${user.id}`);

    // 2. Update user's password using admin API
    const { data: updatedUser, error: updateError } = await supabase.auth.admin.updateUserById(
      user.id,
      {
        password,
        email_confirm: true, // Also confirm email to ensure sign-in works
      }
    );

    if (updateError) {
      console.error('[DEV] Error updating password:', updateError);
      return NextResponse.json(
        { error: 'Failed to update password', details: updateError.message },
        { status: 500 }
      );
    }

    console.log(`[DEV] Password updated successfully for: ${email}`);

    return NextResponse.json({
      success: true,
      userId: updatedUser.user.id,
      email: updatedUser.user.email,
      message: 'Password updated - you can now sign in',
    });

  } catch (error: any) {
    console.error('[DEV] Error in /api/dev/update-password:', error);
    return NextResponse.json(
      { error: 'Internal server error', details: error.message },
      { status: 500 }
    );
  }
}

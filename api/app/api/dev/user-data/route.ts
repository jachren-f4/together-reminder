/**
 * Development Only: Fetch user and couple data for dev auth bypass
 *
 * This endpoint allows the Flutter app to load real user data without going
 * through the email auth flow during development.
 *
 * Security: Only active when AUTH_DEV_BYPASS_ENABLED=true
 */

import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.SUPABASE_URL!;
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

/**
 * GET /api/dev/user-data?userId=<uuid>
 *
 * Returns user data and partner data for local storage initialization
 */
export async function GET(request: NextRequest) {
  // Only allow in development mode
  if (process.env.NODE_ENV !== 'development' || process.env.AUTH_DEV_BYPASS_ENABLED !== 'true') {
    return NextResponse.json(
      { error: 'Dev endpoints disabled in production' },
      { status: 403 }
    );
  }

  try {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get('userId');

    if (!userId) {
      return NextResponse.json(
        { error: 'userId query parameter required' },
        { status: 400 }
      );
    }

    // Create Supabase admin client
    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // 1. Get user data from Supabase Auth
    const { data: authUser, error: authError } = await supabase.auth.admin.getUserById(userId);

    if (authError || !authUser) {
      return NextResponse.json(
        { error: `User not found: ${userId}` },
        { status: 404 }
      );
    }

    // 2. Get couple relationship
    const { data: couples, error: coupleError } = await supabase
      .from('couples')
      .select('*')
      .or(`user1_id.eq.${userId},user2_id.eq.${userId}`)
      .limit(1);

    if (coupleError) {
      console.error('Error fetching couple:', coupleError);
    }

    let partnerData = null;
    let coupleData = null;

    if (couples && couples.length > 0) {
      coupleData = couples[0];
      const partnerId = coupleData.user1_id === userId ? coupleData.user2_id : coupleData.user1_id;

      // 3. Get partner's data
      const { data: partner, error: partnerError } = await supabase.auth.admin.getUserById(partnerId);

      if (partner && !partnerError) {
        partnerData = {
          id: partner.user.id,
          email: partner.user.email,
          name: partner.user.user_metadata?.full_name || partner.user.email?.split('@')[0] || 'Partner',
          avatarEmoji: partner.user.user_metadata?.avatar_emoji || '👤',
          createdAt: partner.user.created_at,
        };
      }
    }

    // 4. Return formatted data for Flutter app
    return NextResponse.json({
      user: {
        id: authUser.user.id,
        email: authUser.user.email,
        name: authUser.user.user_metadata?.full_name || authUser.user.email?.split('@')[0] || 'User',
        avatarEmoji: authUser.user.user_metadata?.avatar_emoji || '👤',
        createdAt: authUser.user.created_at,
      },
      partner: partnerData,
      couple: coupleData ? {
        id: coupleData.id,
        user1Id: coupleData.user1_id,
        user2Id: coupleData.user2_id,
        createdAt: coupleData.created_at,
      } : null,
    });

  } catch (error: any) {
    console.error('Error in /api/dev/user-data:', error);
    return NextResponse.json(
      { error: 'Internal server error', details: error.message },
      { status: 500 }
    );
  }
}

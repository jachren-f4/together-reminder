/**
 * Development Only: Reset game data for a couple
 *
 * This endpoint deletes all quiz_matches and you_or_me_sessions for a couple,
 * allowing fresh test runs without stale data.
 *
 * Security: Only active when AUTH_DEV_BYPASS_ENABLED=true
 */

import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.SUPABASE_URL!;
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

/**
 * POST /api/dev/reset-games
 *
 * Body: { coupleId?: string, userId?: string }
 * - If userId is provided, looks up couple ID from user
 * - If coupleId is provided, uses that directly
 *
 * Returns: { success: true, deleted: { quizMatches: number, youOrMeMatches: number } }
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
    let { coupleId } = body;
    const { userId } = body;

    // Create Supabase admin client
    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // If userId provided, look up couple ID
    if (userId && !coupleId) {
      const { data: couple, error: coupleError } = await supabase
        .from('couples')
        .select('id')
        .or(`user1_id.eq.${userId},user2_id.eq.${userId}`)
        .single();

      if (coupleError || !couple) {
        return NextResponse.json(
          { error: 'No couple found for userId', userId },
          { status: 404 }
        );
      }
      coupleId = couple.id;
      console.log(`[reset-games] Looked up couple ID ${coupleId} from userId ${userId}`);
    }

    if (!coupleId) {
      return NextResponse.json(
        { error: 'Either coupleId or userId is required in request body' },
        { status: 400 }
      );
    }

    // Delete quiz_matches for this couple
    const { data: deletedQuizMatches, error: quizError } = await supabase
      .from('quiz_matches')
      .delete()
      .eq('couple_id', coupleId)
      .select('id');

    if (quizError) {
      console.error('Error deleting quiz_matches:', quizError);
    }

    // Delete you_or_me_sessions for this couple
    const { data: deletedYomSessions, error: yomError } = await supabase
      .from('you_or_me_sessions')
      .delete()
      .eq('couple_id', coupleId)
      .select('id');

    if (yomError) {
      console.error('Error deleting you_or_me_sessions:', yomError);
    }

    const quizCount = deletedQuizMatches?.length ?? 0;
    const yomCount = deletedYomSessions?.length ?? 0;

    console.log(`[reset-games] Deleted ${quizCount} quiz matches and ${yomCount} you-or-me sessions for couple ${coupleId}`);

    return NextResponse.json({
      success: true,
      coupleId,
      deleted: {
        quizMatches: quizCount,
        youOrMeSessions: yomCount,
      },
    });

  } catch (error: any) {
    console.error('Error in /api/dev/reset-games:', error);
    return NextResponse.json(
      { error: 'Internal server error', details: error.message },
      { status: 500 }
    );
  }
}

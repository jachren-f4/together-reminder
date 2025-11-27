/**
 * Leaderboard API Endpoint
 *
 * GET /api/leaderboard - Get global and country leaderboard data
 * Query params:
 *   - view: 'global' | 'country' (default: 'global')
 *   - limit: number (default: 50, max: 100)
 */

import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { NextRequest, NextResponse } from 'next/server';

interface LeaderboardEntry {
  couple_id: string;
  initials: string;
  total_lp: number;
  rank: number;
  is_current_user: boolean;
}

interface LeaderboardResponse {
  view: 'global' | 'country';
  country_code?: string;
  country_name?: string;
  entries: LeaderboardEntry[];
  user_rank?: number;
  user_total_lp?: number;
  total_couples: number;
  updated_at: string;
}

// Country code to name mapping (common ones)
const COUNTRY_NAMES: Record<string, string> = {
  'US': 'United States',
  'GB': 'United Kingdom',
  'DE': 'Germany',
  'FR': 'France',
  'ES': 'Spain',
  'IT': 'Italy',
  'CA': 'Canada',
  'AU': 'Australia',
  'NL': 'Netherlands',
  'SE': 'Sweden',
  'NO': 'Norway',
  'DK': 'Denmark',
  'FI': 'Finland',
  'PL': 'Poland',
  'BR': 'Brazil',
  'MX': 'Mexico',
  'JP': 'Japan',
  'KR': 'South Korea',
  'IN': 'India',
  'SG': 'Singapore',
};

export const GET = withAuthOrDevBypass(async (req: NextRequest, userId: string) => {
  try {
    const url = new URL(req.url);
    const view = url.searchParams.get('view') || 'global';
    const limit = Math.min(parseInt(url.searchParams.get('limit') || '50'), 100);

    // 1. Find user's couple
    const coupleResult = await query(
      `SELECT id, user1_id, user2_id FROM couples
       WHERE user1_id = $1 OR user2_id = $1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json({ error: 'Couple not found' }, { status: 404 });
    }

    const couple = coupleResult.rows[0];
    const coupleId = couple.id;
    const isUser1 = couple.user1_id === userId;

    // 2. Get user's country
    const userCountryResult = await query(
      `SELECT country_code FROM user_love_points WHERE user_id = $1`,
      [userId]
    );
    const userCountry = userCountryResult.rows[0]?.country_code || null;

    // 3. Get leaderboard data based on view
    let response: LeaderboardResponse;

    if (view === 'country') {
      if (!userCountry) {
        // No country set - return empty with message
        return NextResponse.json({
          view: 'country',
          country_code: null,
          country_name: null,
          entries: [],
          user_rank: null,
          user_total_lp: null,
          total_couples: 0,
          updated_at: new Date().toISOString(),
          message: 'Country not set. Update your country to see local rankings.'
        });
      }

      response = await getCountryLeaderboard(userId, coupleId, isUser1, userCountry, limit);
    } else {
      response = await getGlobalLeaderboard(userId, coupleId, limit);
    }

    // Add cache headers (60s server, 30s client as per plan)
    const res = NextResponse.json(response);
    res.headers.set('Cache-Control', 'public, s-maxage=60, stale-while-revalidate=30');
    return res;

  } catch (error) {
    console.error('Error fetching leaderboard:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
});

async function getGlobalLeaderboard(
  userId: string,
  coupleId: string,
  limit: number
): Promise<LeaderboardResponse> {
  // Get top N entries
  const topResult = await query(
    `SELECT
       couple_id,
       user1_initial || ' & ' || user2_initial as initials,
       total_lp,
       global_rank as rank,
       couple_id = $1 as is_current_user
     FROM couple_leaderboard
     WHERE global_rank IS NOT NULL AND global_rank <= $2
     ORDER BY global_rank`,
    [coupleId, limit]
  );

  // Get user's position if not in top N
  const userResult = await query(
    `SELECT
       couple_id,
       user1_initial || ' & ' || user2_initial as initials,
       total_lp,
       global_rank as rank,
       true as is_current_user
     FROM couple_leaderboard
     WHERE couple_id = $1`,
    [coupleId]
  );

  const userEntry = userResult.rows[0];
  const userRank = userEntry?.rank;
  const userTotalLp = userEntry?.total_lp || 0;

  // Get entries around user if not in top N
  let contextEntries: LeaderboardEntry[] = [];
  if (userRank && userRank > limit) {
    const contextResult = await query(
      `SELECT
         couple_id,
         user1_initial || ' & ' || user2_initial as initials,
         total_lp,
         global_rank as rank,
         couple_id = $1 as is_current_user
       FROM couple_leaderboard
       WHERE global_rank IS NOT NULL
         AND global_rank BETWEEN $2 AND $3
       ORDER BY global_rank`,
      [coupleId, userRank - 1, userRank + 1]
    );
    contextEntries = contextResult.rows;
  }

  // Get total count
  const countResult = await query(
    `SELECT COUNT(*) as count FROM couple_leaderboard WHERE total_lp > 0`
  );
  const totalCouples = parseInt(countResult.rows[0].count);

  // Combine entries (top + context if needed)
  let entries = topResult.rows as LeaderboardEntry[];
  if (contextEntries.length > 0) {
    // Add separator marker (rank -1)
    entries = [
      ...entries,
      ...contextEntries
    ];
  }

  return {
    view: 'global',
    entries,
    user_rank: userRank,
    user_total_lp: userTotalLp,
    total_couples: totalCouples,
    updated_at: new Date().toISOString()
  };
}

async function getCountryLeaderboard(
  userId: string,
  coupleId: string,
  isUser1: boolean,
  countryCode: string,
  limit: number
): Promise<LeaderboardResponse> {
  // Determine which country rank to use based on user position in couple
  const rankColumn = isUser1 ? 'user1_country_rank' : 'user2_country_rank';
  const countryColumn = isUser1 ? 'user1_country' : 'user2_country';

  // Get top N entries for user's country
  const topResult = await query(
    `SELECT
       couple_id,
       user1_initial || ' & ' || user2_initial as initials,
       total_lp,
       ${rankColumn} as rank,
       couple_id = $1 as is_current_user
     FROM couple_leaderboard
     WHERE ${countryColumn} = $2
       AND ${rankColumn} IS NOT NULL
       AND ${rankColumn} <= $3
     ORDER BY ${rankColumn}`,
    [coupleId, countryCode, limit]
  );

  // Get user's position
  const userResult = await query(
    `SELECT
       couple_id,
       user1_initial || ' & ' || user2_initial as initials,
       total_lp,
       ${rankColumn} as rank,
       true as is_current_user
     FROM couple_leaderboard
     WHERE couple_id = $1`,
    [coupleId]
  );

  const userEntry = userResult.rows[0];
  const userRank = userEntry?.rank;
  const userTotalLp = userEntry?.total_lp || 0;

  // Get entries around user if not in top N
  let contextEntries: LeaderboardEntry[] = [];
  if (userRank && userRank > limit) {
    const contextResult = await query(
      `SELECT
         couple_id,
         user1_initial || ' & ' || user2_initial as initials,
         total_lp,
         ${rankColumn} as rank,
         couple_id = $1 as is_current_user
       FROM couple_leaderboard
       WHERE ${countryColumn} = $2
         AND ${rankColumn} IS NOT NULL
         AND ${rankColumn} BETWEEN $3 AND $4
       ORDER BY ${rankColumn}`,
      [coupleId, countryCode, userRank - 1, userRank + 1]
    );
    contextEntries = contextResult.rows;
  }

  // Get total count for this country
  const countResult = await query(
    `SELECT COUNT(*) as count FROM couple_leaderboard
     WHERE ${countryColumn} = $1 AND total_lp > 0`,
    [countryCode]
  );
  const totalCouples = parseInt(countResult.rows[0].count);

  // Combine entries
  let entries = topResult.rows as LeaderboardEntry[];
  if (contextEntries.length > 0) {
    entries = [...entries, ...contextEntries];
  }

  return {
    view: 'country',
    country_code: countryCode,
    country_name: COUNTRY_NAMES[countryCode] || countryCode,
    entries,
    user_rank: userRank,
    user_total_lp: userTotalLp,
    total_couples: totalCouples,
    updated_at: new Date().toISOString()
  };
}

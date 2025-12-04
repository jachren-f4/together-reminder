/**
 * Leaderboard API Endpoint
 *
 * GET /api/leaderboard - Get global, country, or tier leaderboard data
 * Query params:
 *   - view: 'global' | 'country' | 'tier' (default: 'global')
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
  view: 'global' | 'country' | 'tier';
  country_code?: string;
  country_name?: string;
  // Tier-specific fields
  tier?: number;
  tier_name?: string;
  tier_emoji?: string;
  tier_min_lp?: number;
  tier_max_lp?: number;
  total_in_tier?: number;
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

// Tier definitions (must match Flutter's LovePointService.arenas)
const TIER_INFO: Record<number, { name: string; emoji: string; min: number; max: number }> = {
  1: { name: 'Cozy Cabin', emoji: '🏕️', min: 0, max: 1000 },
  2: { name: 'Beach Villa', emoji: '🏖️', min: 1000, max: 2500 },
  3: { name: 'Yacht Getaway', emoji: '⛵', min: 2500, max: 5000 },
  4: { name: 'Mountain Penthouse', emoji: '🏔️', min: 5000, max: 10000 },
  5: { name: 'Castle Retreat', emoji: '🏰', min: 10000, max: 999999 },
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

    if (view === 'tier') {
      response = await getTierLeaderboard(userId, coupleId, limit);
    } else if (view === 'country') {
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
  // Ensure user's couple exists in leaderboard (create if missing)
  await ensureLeaderboardEntry(coupleId);

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
  // Ensure user's couple exists in leaderboard (create if missing)
  await ensureLeaderboardEntry(coupleId);

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

async function getTierLeaderboard(
  userId: string,
  coupleId: string,
  limit: number
): Promise<LeaderboardResponse> {
  // Ensure user's couple exists in leaderboard (create if missing)
  await ensureLeaderboardEntry(coupleId);

  // Get user's tier info
  const userTierResult = await query(
    `SELECT
       couple_id,
       user1_initial || ' & ' || user2_initial as initials,
       total_lp,
       tier_rank as rank,
       arena_tier,
       true as is_current_user
     FROM couple_leaderboard
     WHERE couple_id = $1`,
    [coupleId]
  );

  const userEntry = userTierResult.rows[0];
  const userTier = userEntry?.arena_tier || 1;
  const userRank = userEntry?.rank;
  const userTotalLp = userEntry?.total_lp || 0;
  const tierInfo = TIER_INFO[userTier] || TIER_INFO[1];

  // Get top N entries for user's tier
  const topResult = await query(
    `SELECT
       couple_id,
       user1_initial || ' & ' || user2_initial as initials,
       total_lp,
       tier_rank as rank,
       couple_id = $1 as is_current_user
     FROM couple_leaderboard
     WHERE arena_tier = $2
       AND tier_rank IS NOT NULL
       AND tier_rank <= $3
     ORDER BY tier_rank`,
    [coupleId, userTier, limit]
  );

  // Get entries around user if not in top N
  let contextEntries: LeaderboardEntry[] = [];
  if (userRank && userRank > limit) {
    const contextResult = await query(
      `SELECT
         couple_id,
         user1_initial || ' & ' || user2_initial as initials,
         total_lp,
         tier_rank as rank,
         couple_id = $1 as is_current_user
       FROM couple_leaderboard
       WHERE arena_tier = $2
         AND tier_rank IS NOT NULL
         AND tier_rank BETWEEN $3 AND $4
       ORDER BY tier_rank`,
      [coupleId, userTier, userRank - 1, userRank + 1]
    );
    contextEntries = contextResult.rows;
  }

  // Get total count for this tier
  const countResult = await query(
    `SELECT COUNT(*) as count FROM couple_leaderboard
     WHERE arena_tier = $1 AND total_lp > 0`,
    [userTier]
  );
  const totalInTier = parseInt(countResult.rows[0].count);

  // Get global total for consistency
  const globalCountResult = await query(
    `SELECT COUNT(*) as count FROM couple_leaderboard WHERE total_lp > 0`
  );
  const totalCouples = parseInt(globalCountResult.rows[0].count);

  // Combine entries
  let entries = topResult.rows as LeaderboardEntry[];
  if (contextEntries.length > 0) {
    entries = [...entries, ...contextEntries];
  }

  return {
    view: 'tier',
    tier: userTier,
    tier_name: tierInfo.name,
    tier_emoji: tierInfo.emoji,
    tier_min_lp: tierInfo.min,
    tier_max_lp: tierInfo.max,
    total_in_tier: totalInTier,
    entries,
    user_rank: userRank,
    user_total_lp: userTotalLp,
    total_couples: totalCouples,
    updated_at: new Date().toISOString()
  };
}

/**
 * Ensures a couple has an entry in the leaderboard table.
 * Creates one if missing, using data from couples and users tables.
 * Also ensures the entry has a global_rank (required for visibility).
 */
async function ensureLeaderboardEntry(coupleId: string): Promise<void> {
  // Check if entry exists with a rank
  const existsResult = await query(
    `SELECT global_rank FROM couple_leaderboard WHERE couple_id = $1`,
    [coupleId]
  );

  if (existsResult.rows.length > 0 && existsResult.rows[0].global_rank !== null) {
    return; // Entry exists with rank, nothing to do
  }

  if (existsResult.rows.length === 0) {
    // Entry doesn't exist, create it from couples table
    await query(
      `INSERT INTO couple_leaderboard (
         couple_id,
         user1_initial,
         user2_initial,
         total_lp,
         arena_tier,
         updated_at
       )
       SELECT
         c.id,
         UPPER(SUBSTRING(COALESCE(u1.raw_user_meta_data->>'full_name', 'A') FROM 1 FOR 1)),
         UPPER(SUBSTRING(COALESCE(u2.raw_user_meta_data->>'full_name', 'B') FROM 1 FOR 1)),
         COALESCE(c.total_lp, 0),
         1,
         NOW()
       FROM couples c
       LEFT JOIN auth.users u1 ON u1.id = c.user1_id
       LEFT JOIN auth.users u2 ON u2.id = c.user2_id
       WHERE c.id = $1
       ON CONFLICT (couple_id) DO NOTHING`,
      [coupleId]
    );
  }

  // Calculate and set the global rank for this couple
  // Rank is based on total_lp descending
  await query(
    `UPDATE couple_leaderboard cl
     SET global_rank = (
       SELECT COUNT(*) + 1
       FROM couple_leaderboard cl2
       WHERE cl2.total_lp > cl.total_lp
     ),
     tier_rank = (
       SELECT COUNT(*) + 1
       FROM couple_leaderboard cl2
       WHERE cl2.arena_tier = cl.arena_tier AND cl2.total_lp > cl.total_lp
     )
     WHERE cl.couple_id = $1`,
    [coupleId]
  );
}

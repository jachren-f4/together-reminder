/**
 * User Router
 *
 * Exports route functions for the user domain.
 * Handlers are extracted from the user catch-all route.
 *
 * Routes:
 * - POST /api/user/complete-signup - Complete user signup and return full state
 * - GET /api/user/profile - Get user profile with full state
 * - PATCH /api/user/name - Update user's display name
 * - GET /api/user/country - Get user's country code
 * - POST /api/user/country - Update user's country code
 * - GET /api/user/push-token - Get user's push token
 * - POST /api/user/push-token - Update user's push token
 */

import { NextRequest, NextResponse } from 'next/server';
import { withAuth } from '@/lib/auth/middleware';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { RateLimitPresets, withRateLimit } from '@/lib/auth/rate-limit';
import { query } from '@/lib/db/pool';

// Valid ISO 3166-1 alpha-2 country codes (common ones for validation)
const VALID_COUNTRY_CODES = new Set([
  'AF', 'AL', 'DZ', 'AD', 'AO', 'AG', 'AR', 'AM', 'AU', 'AT', 'AZ',
  'BS', 'BH', 'BD', 'BB', 'BY', 'BE', 'BZ', 'BJ', 'BT', 'BO', 'BA', 'BW', 'BR', 'BN', 'BG', 'BF', 'BI',
  'KH', 'CM', 'CA', 'CV', 'CF', 'TD', 'CL', 'CN', 'CO', 'KM', 'CG', 'CD', 'CR', 'CI', 'HR', 'CU', 'CY', 'CZ',
  'DK', 'DJ', 'DM', 'DO',
  'EC', 'EG', 'SV', 'GQ', 'ER', 'EE', 'ET',
  'FJ', 'FI', 'FR',
  'GA', 'GM', 'GE', 'DE', 'GH', 'GR', 'GD', 'GT', 'GN', 'GW', 'GY',
  'HT', 'HN', 'HU',
  'IS', 'IN', 'ID', 'IR', 'IQ', 'IE', 'IL', 'IT',
  'JM', 'JP', 'JO',
  'KZ', 'KE', 'KI', 'KP', 'KR', 'KW', 'KG',
  'LA', 'LV', 'LB', 'LS', 'LR', 'LY', 'LI', 'LT', 'LU',
  'MK', 'MG', 'MW', 'MY', 'MV', 'ML', 'MT', 'MH', 'MR', 'MU', 'MX', 'FM', 'MD', 'MC', 'MN', 'ME', 'MA', 'MZ', 'MM',
  'NA', 'NR', 'NP', 'NL', 'NZ', 'NI', 'NE', 'NG', 'NO',
  'OM',
  'PK', 'PW', 'PA', 'PG', 'PY', 'PE', 'PH', 'PL', 'PT',
  'QA',
  'RO', 'RU', 'RW',
  'KN', 'LC', 'VC', 'WS', 'SM', 'ST', 'SA', 'SN', 'RS', 'SC', 'SL', 'SG', 'SK', 'SI', 'SB', 'SO', 'ZA', 'SS', 'ES', 'LK', 'SD', 'SR', 'SZ', 'SE', 'CH', 'SY',
  'TW', 'TJ', 'TZ', 'TH', 'TL', 'TG', 'TO', 'TT', 'TN', 'TR', 'TM', 'TV',
  'UG', 'UA', 'AE', 'GB', 'US', 'UY', 'UZ',
  'VU', 'VA', 'VE', 'VN',
  'YE',
  'ZM', 'ZW'
]);

// ========================================
// INTERNAL HANDLERS
// ========================================

/**
 * Get user profile with full state
 *
 * GET /api/user/profile
 *
 * Returns: {
 *   user: { id, email, name, createdAt },
 *   couple: { id, createdAt } | null,
 *   partner: { id, name, email, avatarEmoji } | null
 * }
 */
const handleGetProfile = withRateLimit(
  RateLimitPresets.sync,
  withAuth(async (req, userId, email) => {
    try {
      // Get user info from auth.users
      const userResult = await query(
        `SELECT u.id, u.email, u.created_at, u.raw_user_meta_data,
                pt.fcm_token as push_token, pt.platform
         FROM auth.users u
         LEFT JOIN user_push_tokens pt ON pt.user_id = u.id
         WHERE u.id = $1`,
        [userId]
      );

      if (userResult.rows.length === 0) {
        return NextResponse.json(
          { error: 'User not found' },
          { status: 404 }
        );
      }

      const userRow = userResult.rows[0];
      const metadata = userRow.raw_user_meta_data as Record<string, any> | null;
      const userName = metadata?.full_name || metadata?.name || null;

      // Check if user is in a couple
      const coupleResult = await query(
        `SELECT
           c.id as couple_id,
           c.created_at as couple_created_at,
           CASE
             WHEN c.user1_id = $1 THEN c.user2_id
             ELSE c.user1_id
           END as partner_id
         FROM couples c
         WHERE c.user1_id = $1 OR c.user2_id = $1`,
        [userId]
      );

      let couple = null;
      let partner = null;

      if (coupleResult.rows.length > 0) {
        const coupleRow = coupleResult.rows[0];
        couple = {
          id: coupleRow.couple_id,
          createdAt: coupleRow.couple_created_at,
        };

        // Get partner info
        const partnerResult = await query(
          `SELECT u.id, u.email, u.raw_user_meta_data,
                  pt.fcm_token as push_token
           FROM auth.users u
           LEFT JOIN user_push_tokens pt ON pt.user_id = u.id
           WHERE u.id = $1`,
          [coupleRow.partner_id]
        );

        if (partnerResult.rows.length > 0) {
          const partnerRow = partnerResult.rows[0];
          const partnerMetadata = partnerRow.raw_user_meta_data as Record<string, any> | null;
          const partnerName = partnerMetadata?.full_name ||
                             partnerMetadata?.name ||
                             partnerRow.email?.split('@')[0] ||
                             'Partner';

          partner = {
            id: partnerRow.id,
            name: partnerName,
            email: partnerRow.email,
            pushToken: partnerRow.push_token || null,
            avatarEmoji: '💕',
          };
        }
      }

      // Build response
      const response = {
        user: {
          id: userId,
          email: userRow.email,
          name: userName,
          pushToken: userRow.push_token || null,
          platform: userRow.platform || null,
          createdAt: userRow.created_at,
        },
        couple,
        partner,
      };

      return NextResponse.json(response);
    } catch (error) {
      console.error('Error fetching user profile:', error);
      return NextResponse.json(
        { error: 'Failed to fetch profile' },
        { status: 500 }
      );
    }
  })
);

/**
 * Get user's country code
 *
 * GET /api/user/country
 *
 * Returns: { country_code: string | null }
 */
const handleGetCountry = withAuthOrDevBypass(async (req: NextRequest, userId: string) => {
  try {
    const result = await query(
      `SELECT country_code FROM user_love_points WHERE user_id = $1`,
      [userId]
    );

    const countryCode = result.rows[0]?.country_code || null;

    return NextResponse.json({
      country_code: countryCode
    });

  } catch (error) {
    console.error('Error fetching country:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
});

/**
 * Get user's push token
 *
 * GET /api/user/push-token
 *
 * Returns: { token: string, platform: string } | { token: null }
 */
const handleGetPushToken = withRateLimit(
  RateLimitPresets.sync,
  withAuth(async (req, userId, email) => {
    try {
      const result = await query(
        `SELECT fcm_token, platform, device_name, updated_at
         FROM user_push_tokens
         WHERE user_id = $1`,
        [userId]
      );

      if (result.rows.length === 0) {
        return NextResponse.json({ token: null });
      }

      const row = result.rows[0];
      return NextResponse.json({
        token: row.fcm_token,
        platform: row.platform,
        deviceName: row.device_name,
        updatedAt: row.updated_at,
      });
    } catch (error) {
      console.error('Error fetching push token:', error);
      return NextResponse.json(
        { error: 'Failed to fetch push token' },
        { status: 500 }
      );
    }
  })
);

/**
 * Complete user signup and return full state
 *
 * POST /api/user/complete-signup
 * Body: { pushToken?: string, platform?: string, name?: string }
 *
 * Returns: {
 *   user: { id, email, name, createdAt },
 *   couple: { id, createdAt } | null,
 *   partner: { id, name, email, avatarEmoji } | null
 * }
 */
const handleCompleteSignup = withRateLimit(
  RateLimitPresets.auth,
  withAuth(async (req, userId, email) => {
    try {
      // Parse optional body
      let pushToken: string | null = null;
      let platform: string | null = null;
      let name: string | null = null;

      try {
        const body = await req.json();
        pushToken = body.pushToken || null;
        platform = body.platform || null;
        name = body.name || null;
      } catch {
        // Body is optional, ignore parse errors
      }

      // Get user info from auth.users
      const userResult = await query(
        `SELECT id, email, created_at, raw_user_meta_data
         FROM auth.users
         WHERE id = $1`,
        [userId]
      );

      if (userResult.rows.length === 0) {
        return NextResponse.json(
          { error: 'User not found' },
          { status: 404 }
        );
      }

      const userRow = userResult.rows[0];
      const metadata = userRow.raw_user_meta_data as Record<string, any> | null;
      const userName = metadata?.full_name || metadata?.name || null;

      // If name provided in request and different from stored, update it
      if (name && name !== userName) {
        await query(
          `UPDATE auth.users
           SET raw_user_meta_data = raw_user_meta_data || $1::jsonb,
               updated_at = NOW()
           WHERE id = $2`,
          [JSON.stringify({ full_name: name }), userId]
        );
      }

      // Save push token if provided
      if (pushToken && platform) {
        await query(
          `INSERT INTO user_push_tokens (user_id, fcm_token, platform, updated_at)
           VALUES ($1, $2, $3, NOW())
           ON CONFLICT (user_id)
           DO UPDATE SET fcm_token = $2, platform = $3, updated_at = NOW()`,
          [userId, pushToken, platform]
        );
      }

      // Check if user is in a couple
      const coupleResult = await query(
        `SELECT
           c.id as couple_id,
           c.created_at as couple_created_at,
           CASE
             WHEN c.user1_id = $1 THEN c.user2_id
             ELSE c.user1_id
           END as partner_id
         FROM couples c
         WHERE c.user1_id = $1 OR c.user2_id = $1`,
        [userId]
      );

      let couple = null;
      let partner = null;

      if (coupleResult.rows.length > 0) {
        const coupleRow = coupleResult.rows[0];
        couple = {
          id: coupleRow.couple_id,
          createdAt: coupleRow.couple_created_at,
        };

        // Get partner info
        const partnerResult = await query(
          `SELECT u.id, u.email, u.raw_user_meta_data,
                  pt.fcm_token as push_token
           FROM auth.users u
           LEFT JOIN user_push_tokens pt ON pt.user_id = u.id
           WHERE u.id = $1`,
          [coupleRow.partner_id]
        );

        if (partnerResult.rows.length > 0) {
          const partnerRow = partnerResult.rows[0];
          const partnerMetadata = partnerRow.raw_user_meta_data as Record<string, any> | null;
          const partnerName = partnerMetadata?.full_name ||
                             partnerMetadata?.name ||
                             partnerRow.email?.split('@')[0] ||
                             'Partner';

          partner = {
            id: partnerRow.id,
            name: partnerName,
            email: partnerRow.email,
            pushToken: partnerRow.push_token || null,
            avatarEmoji: '💕',
          };
        }
      }

      // Build response
      const response = {
        user: {
          id: userId,
          email: userRow.email,
          name: name || userName,
          createdAt: userRow.created_at,
        },
        couple,
        partner,
      };

      console.log(`[CompleteSignup] User ${userId} completed signup. Couple: ${couple ? 'yes' : 'no'}`);

      return NextResponse.json(response);
    } catch (error) {
      console.error('Error in complete-signup:', error);
      return NextResponse.json(
        { error: 'Failed to complete signup' },
        { status: 500 }
      );
    }
  })
);

/**
 * Update user's country code
 *
 * POST /api/user/country
 * Body: { country_code: string } (ISO 3166-1 alpha-2)
 *
 * Returns: { success: true, country_code: string }
 */
const handlePostCountry = withAuthOrDevBypass(async (req: NextRequest, userId: string) => {
  try {
    const body = await req.json();
    const { country_code } = body;

    // Validate country code
    if (!country_code) {
      return NextResponse.json({ error: 'country_code is required' }, { status: 400 });
    }

    const normalizedCode = country_code.toUpperCase();

    if (normalizedCode.length !== 2) {
      return NextResponse.json({ error: 'country_code must be 2 characters' }, { status: 400 });
    }

    if (!VALID_COUNTRY_CODES.has(normalizedCode)) {
      return NextResponse.json({ error: 'Invalid country code' }, { status: 400 });
    }

    // Update user's country code in user_love_points
    // Upsert in case the user doesn't have an entry yet
    await query(
      `INSERT INTO user_love_points (user_id, country_code, total_points)
       VALUES ($1, $2, 0)
       ON CONFLICT (user_id) DO UPDATE
       SET country_code = $2,
           updated_at = NOW()`,
      [userId, normalizedCode]
    );

    // The trigger will automatically update the couple_leaderboard table

    return NextResponse.json({
      success: true,
      country_code: normalizedCode
    });

  } catch (error) {
    console.error('Error updating country:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
});

/**
 * Update user's push token
 *
 * POST /api/user/push-token
 * Body: { token: string, platform: 'ios' | 'android' | 'web', deviceName?: string }
 *
 * Returns: { success: true }
 */
const handlePostPushToken = withRateLimit(
  RateLimitPresets.sync,
  withAuth(async (req, userId, email) => {
    try {
      const body = await req.json();
      const { token, platform, deviceName } = body;

      // Validate token
      if (!token || typeof token !== 'string') {
        return NextResponse.json(
          { error: 'Token is required' },
          { status: 400 }
        );
      }

      // Validate platform
      const validPlatforms = ['ios', 'android', 'web'];
      if (!platform || !validPlatforms.includes(platform)) {
        return NextResponse.json(
          { error: 'Platform must be ios, android, or web' },
          { status: 400 }
        );
      }

      // Upsert push token
      await query(
        `INSERT INTO user_push_tokens (user_id, fcm_token, platform, device_name, updated_at)
         VALUES ($1, $2, $3, $4, NOW())
         ON CONFLICT (user_id)
         DO UPDATE SET
           fcm_token = $2,
           platform = $3,
           device_name = COALESCE($4, user_push_tokens.device_name),
           updated_at = NOW()`,
        [userId, token, platform, deviceName || null]
      );

      console.log(`[PushToken] User ${userId} updated push token for ${platform}`);

      return NextResponse.json({ success: true });
    } catch (error) {
      console.error('Error updating push token:', error);
      return NextResponse.json(
        { error: 'Failed to update push token' },
        { status: 500 }
      );
    }
  })
);

/**
 * Update user's display name
 *
 * PATCH /api/user/name
 * Body: { name: string }
 *
 * Returns: { user: { id, email, name, updatedAt } }
 */
const handlePatchName = withRateLimit(
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

// ========================================
// EXPORTED ROUTER FUNCTIONS
// ========================================

/**
 * Routes GET requests for the user domain
 */
export async function routeUserGET(req: NextRequest, subPath: string[]): Promise<NextResponse> {
  const path = subPath[0];

  switch (path) {
    case 'profile':
      return handleGetProfile(req);
    case 'country':
      return handleGetCountry(req);
    case 'push-token':
      return handleGetPushToken(req);
    default:
      return NextResponse.json({ error: 'Not found' }, { status: 404 });
  }
}

/**
 * Routes POST requests for the user domain
 */
export async function routeUserPOST(req: NextRequest, subPath: string[]): Promise<NextResponse> {
  const path = subPath[0];

  switch (path) {
    case 'complete-signup':
      return handleCompleteSignup(req);
    case 'country':
      return handlePostCountry(req);
    case 'push-token':
      return handlePostPushToken(req);
    default:
      return NextResponse.json({ error: 'Not found' }, { status: 404 });
  }
}

/**
 * Routes PATCH requests for the user domain
 */
export async function routeUserPATCH(req: NextRequest, subPath: string[]): Promise<NextResponse> {
  const path = subPath[0];

  switch (path) {
    case 'name':
      return handlePatchName(req);
    default:
      return NextResponse.json({ error: 'Not found' }, { status: 404 });
  }
}

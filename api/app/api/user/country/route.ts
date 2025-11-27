/**
 * User Country API Endpoint
 *
 * POST /api/user/country - Update user's country code
 * Body: { country_code: string } (ISO 3166-1 alpha-2)
 *
 * GET /api/user/country - Get user's current country code
 */

import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import { NextRequest, NextResponse } from 'next/server';

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

export const POST = withAuthOrDevBypass(async (req: NextRequest, userId: string) => {
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

export const GET = withAuthOrDevBypass(async (req: NextRequest, userId: string) => {
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

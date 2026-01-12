/**
 * Debug Cooldown API Endpoint
 *
 * For testing cooldown functionality in development/TestFlight.
 * POST: Set or clear cooldown for an activity type
 * GET: Get current cooldown status for all activities
 */

import { NextResponse } from 'next/server';
import { withAuthOrDevBypass } from '@/lib/auth/dev-middleware';
import { query } from '@/lib/db/pool';
import {
  getCooldownStatus,
  getAllCooldownStatuses,
  resetCooldown,
  ActivityType,
  COOLDOWN_HOURS,
  BATCH_WINDOW_HOURS,
  CooldownsMap,
} from '@/lib/magnets/cooldowns';

export const dynamic = 'force-dynamic';

/**
 * GET /api/debug/cooldown
 *
 * Get cooldown status for all activity types
 */
export const GET = withAuthOrDevBypass(async (req, userId) => {
  try {
    // Get couple ID
    const coupleResult = await query(
      `SELECT id FROM couples WHERE user1_id = $1 OR user2_id = $1 LIMIT 1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json(
        { error: 'No couple found for user' },
        { status: 404 }
      );
    }

    const coupleId = coupleResult.rows[0].id;

    // Get all cooldown statuses
    const statuses = await getAllCooldownStatuses(coupleId);

    return NextResponse.json({
      success: true,
      coupleId,
      config: {
        batchSize: 2,
        cooldownHours: COOLDOWN_HOURS,
        batchWindowHours: BATCH_WINDOW_HOURS,
      },
      cooldowns: statuses,
    });
  } catch (error) {
    console.error('Error getting cooldown status:', error);
    return NextResponse.json(
      { error: 'Failed to get cooldown status' },
      { status: 500 }
    );
  }
});

/**
 * POST /api/debug/cooldown
 *
 * Set or clear cooldown for an activity type
 *
 * Body:
 * - activityType: 'linked' | 'wordsearch' | 'classic_quiz' | etc.
 * - action: 'set' | 'clear'
 * - cooldownMinutes?: number (default: 480 = 8 hours, only for 'set')
 */
export const POST = withAuthOrDevBypass(async (req, userId) => {
  try {
    const body = await req.json();
    const { activityType, action, cooldownMinutes } = body;

    // Validate activity type
    const validTypes: ActivityType[] = [
      'classic_quiz',
      'affirmation_quiz',
      'you_or_me',
      'linked',
      'wordsearch',
    ];

    if (!validTypes.includes(activityType)) {
      return NextResponse.json(
        { error: `Invalid activityType. Must be one of: ${validTypes.join(', ')}` },
        { status: 400 }
      );
    }

    // Validate action
    if (!['set', 'clear'].includes(action)) {
      return NextResponse.json(
        { error: 'Invalid action. Must be "set" or "clear"' },
        { status: 400 }
      );
    }

    // Get couple ID
    const coupleResult = await query(
      `SELECT id, cooldowns FROM couples WHERE user1_id = $1 OR user2_id = $1 LIMIT 1`,
      [userId]
    );

    if (coupleResult.rows.length === 0) {
      return NextResponse.json(
        { error: 'No couple found for user' },
        { status: 404 }
      );
    }

    const coupleId = coupleResult.rows[0].id;
    const cooldowns: CooldownsMap = coupleResult.rows[0].cooldowns || {};

    if (action === 'clear') {
      // Clear cooldown using existing function
      await resetCooldown(coupleId, activityType);

      return NextResponse.json({
        success: true,
        message: `Cooldown cleared for ${activityType}`,
        activityType,
        status: await getCooldownStatus(coupleId, activityType),
      });
    } else {
      // Set cooldown
      const minutes = cooldownMinutes ?? COOLDOWN_HOURS * 60;
      const now = new Date();
      const cooldownEnd = new Date(now.getTime() + minutes * 60 * 1000);

      cooldowns[activityType] = {
        batch_count: 2, // Max batch = on cooldown
        cooldown_until: cooldownEnd.toISOString(),
        last_play_at: now.toISOString(),
      };

      await query(
        'UPDATE couples SET cooldowns = $1, updated_at = NOW() WHERE id = $2',
        [JSON.stringify(cooldowns), coupleId]
      );

      return NextResponse.json({
        success: true,
        message: `Cooldown set for ${activityType} (${minutes} minutes)`,
        activityType,
        cooldownEndsAt: cooldownEnd.toISOString(),
        cooldownMinutes: minutes,
        status: await getCooldownStatus(coupleId, activityType),
      });
    }
  } catch (error) {
    console.error('Error setting cooldown:', error);
    return NextResponse.json(
      { error: 'Failed to set cooldown' },
      { status: 500 }
    );
  }
});
